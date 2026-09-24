/// How to listen for the incoming OTP SMS.
enum SmsListenMode {
  /// SMS Retriever API: zero taps, no permissions. The SMS must end with your
  /// app hash (see `AndroidOtpKit.getAppSignatures`). Waits up to 5 minutes.
  retriever,

  /// SMS User Consent API: the user taps "Allow" once. Works with any OTP SMS
  /// (no app hash needed), so use it when you don't control the SMS template.
  userConsent,
}

/// Result of listening for an OTP SMS.
sealed class SmsEvent {
  /// Base constructor for the event types.
  const SmsEvent();
}

/// An SMS arrived. [code] is the OTP extracted from [message], if one was found.
final class SmsReceived extends SmsEvent {
  /// Creates the event for a received [message].
  const SmsReceived(this.message, this.code);

  /// The full text of the SMS.
  final String message;

  /// The OTP found in [message], or null if none matched.
  final String? code;

  @override
  String toString() => 'SmsReceived(code: $code)';
}

/// No matching SMS arrived within 5 minutes.
final class SmsTimeout extends SmsEvent {
  /// Creates a timeout event.
  const SmsTimeout();

  @override
  String toString() => 'SmsTimeout()';
}

/// The user declined the SMS User Consent dialog.
final class SmsConsentDenied extends SmsEvent {
  /// Creates a consent-denied event.
  const SmsConsentDenied();

  @override
  String toString() => 'SmsConsentDenied()';
}
