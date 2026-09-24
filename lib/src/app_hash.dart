import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Computes the 11-character SMS Retriever app hash for [packageName] signed
/// with the certificate whose DER-encoded bytes are [certificateDer].
///
/// This matches what `AndroidOtpKit.getAppSignatures()` returns on device, so
/// it can be used on a dev machine or CI (see `dart run android_otp_kit:app_hash`).
String computeAppHash(String packageName, List<int> certificateDer) {
  final certHex = certificateDer
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  final digest = sha256.convert(utf8.encode('$packageName $certHex')).bytes;
  return base64.encode(digest.sublist(0, 9)).substring(0, 11);
}

/// Decodes a certificate file that is either raw DER or PEM
/// (`-----BEGIN CERTIFICATE-----`).
List<int> decodeCertificate(List<int> bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  const begin = '-----BEGIN CERTIFICATE-----';
  final start = text.indexOf(begin);
  if (start == -1) return bytes;
  final end = text.indexOf('-----END CERTIFICATE-----', start);
  final body = text.substring(start + begin.length, end == -1 ? null : end);
  return base64.decode(body.replaceAll(RegExp(r'\s'), ''));
}
