import 'dart:convert';

import 'package:android_otp_kit/android_otp_kit.dart';
import 'package:android_otp_kit/src/app_hash.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('extractOtp', () {
    test('finds a 4-8 digit code by default', () {
      expect(extractOtp('<#> 482913 is your code. FA+9qCX9VSu'), '482913');
      expect(extractOtp('Your OTP: 1234'), '1234');
    });

    test(
      'respects length and ignores digits inside words or longer numbers',
      () {
        const sms = 'Order A12345 ref 9876543210. Code 5566. Hash ab12cd34';
        expect(extractOtp(sms, length: 4), '5566');
        expect(extractOtp('Call 18001234567', length: 6), isNull);
      },
    );

    test('uses custom pattern group', () {
      expect(
        extractOtp('Code: G-771234', pattern: RegExp(r'G-(\d{6})')),
        '771234',
      );
    });
  });

  group('computeAppHash', () {
    final der = List<int>.generate(64, (i) => i * 7 % 256);

    test('is 11 url-unsafe base64 chars and deterministic', () {
      final hash = computeAppHash('com.example.app', der);
      expect(hash, hasLength(11));
      expect(hash, computeAppHash('com.example.app', der));
      expect(hash, isNot(computeAppHash('com.example.other', der)));
    });

    test('PEM and DER inputs give the same hash', () {
      final pem =
          '-----BEGIN CERTIFICATE-----\n'
          '${base64.encode(der)}\n'
          '-----END CERTIFICATE-----\n';
      expect(decodeCertificate(utf8.encode(pem)), der);
      expect(decodeCertificate(der), der);
    });
  });

  group('AndroidOtpKit on Android', () {
    const methods = MethodChannel('android_otp_kit');
    const events = EventChannel('android_otp_kit/sms');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockStreamHandler(events, null);
    });

    test('requestPhoneNumberHint returns the picked number', () async {
      messenger.setMockMethodCallHandler(methods, (call) async {
        expect(call.method, 'requestPhoneNumberHint');
        return '+919876543210';
      });
      expect(await AndroidOtpKit.requestPhoneNumberHint(), '+919876543210');
    });

    test('listenForSms sends mode and maps events', () async {
      Object? sentArgs;
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (args, sink) {
            sentArgs = args;
            sink.success({'type': 'sms', 'message': '<#> 123456 is your code'});
            sink.endOfStream();
          },
        ),
      );

      final event = await AndroidOtpKit.waitForSms(
        mode: SmsListenMode.userConsent,
        senderPhoneNumber: '+911234567890',
      );

      expect(sentArgs, {
        'mode': 'userConsent',
        'senderPhoneNumber': '+911234567890',
      });
      expect(event, isA<SmsReceived>().having((e) => e.code, 'code', '123456'));
    });

    test('denied and timeout events', () async {
      for (final (type, matcher) in [
        ('denied', isA<SmsConsentDenied>()),
        ('timeout', isA<SmsTimeout>()),
      ]) {
        messenger.setMockStreamHandler(
          events,
          MockStreamHandler.inline(
            onListen: (_, sink) {
              sink.success({'type': type});
            },
          ),
        );
        expect(await AndroidOtpKit.waitForSms(), matcher);
      }
    });
  });

  test('is a no-op off Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await AndroidOtpKit.requestPhoneNumberHint(), isNull);
    expect(await AndroidOtpKit.getAppSignatures(), isEmpty);
    expect(await AndroidOtpKit.listenForSms().isEmpty, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });
}
