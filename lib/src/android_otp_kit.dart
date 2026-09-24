import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'otp_extractor.dart';
import 'sms_event.dart';

/// Android OTP helpers: Phone Number Hint, SMS Retriever, SMS User Consent
/// and app signature hashes.
///
/// Every method is a safe no-op on other platforms, so it can be called from
/// shared code without platform checks.
abstract final class AndroidOtpKit {
  static const _methods = MethodChannel('android_otp_kit');
  static const _events = EventChannel('android_otp_kit/sms');

  /// Whether the native APIs are available (Android only).
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Shows Google's Phone Number Hint picker and returns the chosen number
  /// in E.164 format (e.g. `+919876543210`), or null if the user dismissed it.
  ///
  /// Throws a [PlatformException] with code `HINT_UNAVAILABLE` when the
  /// device has no numbers to offer (e.g. no SIM).
  static Future<String?> requestPhoneNumberHint() async {
    if (!isSupported) return null;
    return _methods.invokeMethod<String>('requestPhoneNumberHint');
  }

  /// Listens for a single OTP SMS. Start listening *before* your server sends
  /// the SMS. The stream emits one [SmsEvent] and then closes; cancelling the
  /// subscription stops listening.
  ///
  /// [otpLength] and [otpPattern] control how [SmsReceived.code] is extracted
  /// (see [extractOtp]). [senderPhoneNumber] only applies to
  /// [SmsListenMode.userConsent] and restricts which sender is accepted.
  static Stream<SmsEvent> listenForSms({
    SmsListenMode mode = SmsListenMode.retriever,
    String? senderPhoneNumber,
    int? otpLength,
    RegExp? otpPattern,
  }) {
    if (!isSupported) return const Stream.empty();
    return _events
        .receiveBroadcastStream({
          'mode': mode.name,
          'senderPhoneNumber': senderPhoneNumber,
        })
        .map((raw) {
          final event = Map<String, Object?>.from(raw as Map);
          return switch (event['type']) {
            'sms' => _received(
              event['message'] as String? ?? '',
              otpLength,
              otpPattern,
            ),
            'denied' => const SmsConsentDenied(),
            _ => const SmsTimeout(),
          };
        });
  }

  /// Convenience for `listenForSms(...).first`, with [SmsTimeout] if the
  /// stream closes without an event.
  static Future<SmsEvent> waitForSms({
    SmsListenMode mode = SmsListenMode.retriever,
    String? senderPhoneNumber,
    int? otpLength,
    RegExp? otpPattern,
  }) {
    return listenForSms(
      mode: mode,
      senderPhoneNumber: senderPhoneNumber,
      otpLength: otpLength,
      otpPattern: otpPattern,
    ).firstWhere((_) => true, orElse: () => const SmsTimeout());
  }

  /// The app hash(es) your OTP SMS must end with for [SmsListenMode.retriever],
  /// one per signing certificate of the *running* build.
  ///
  /// Debug, release and Play-signed builds have different hashes. For the
  /// Play Store hash, use `dart run android_otp_kit:app_hash` with the app
  /// signing certificate from Play Console.
  static Future<List<String>> getAppSignatures() async {
    if (!isSupported) return const [];
    final hashes = await _methods.invokeListMethod<String>('getAppSignatures');
    return hashes ?? const [];
  }

  static SmsReceived _received(String message, int? length, RegExp? pattern) =>
      SmsReceived(
        message,
        extractOtp(message, length: length, pattern: pattern),
      );
}
