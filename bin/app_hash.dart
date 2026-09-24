// Prints the SMS Retriever app hash for a keystore or certificate.
//
//   dart run android_otp_kit:app_hash --package com.example.app
//   dart run android_otp_kit:app_hash --package com.example.app \
//       --keystore upload.jks --alias upload --storepass secret
//   dart run android_otp_kit:app_hash --package com.example.app \
//       --cert deployment_cert.der   # Play Console > App signing certificate
import 'dart:io';

import 'package:android_otp_kit/src/app_hash.dart';

const _usage = '''
Usage: dart run android_otp_kit:app_hash --package <applicationId> [options]

Options:
  --package    Android applicationId (required)
  --cert       Certificate file (.der or .pem). Use the "App signing key
               certificate" from Play Console for Play Store builds.
  --keystore   Keystore to read instead (default: ~/.android/debug.keystore)
  --alias      Key alias (default: androiddebugkey)
  --storepass  Keystore password (default: android)
  --keytool    Path to keytool (default: JAVA_HOME, PATH, then Android Studio's JBR)
''';

Future<void> main(List<String> arguments) async {
  final args = _parse(arguments);
  final packageName = args['package'];
  if (packageName == null || args.containsKey('help')) {
    stdout.write(_usage);
    exit(packageName == null && !args.containsKey('help') ? 64 : 0);
  }

  final List<int> der;
  if (args['cert'] case final certPath?) {
    der = decodeCertificate(await File(certPath).readAsBytes());
  } else {
    final keystore = args['keystore'] ?? _defaultDebugKeystore();
    final keytool = args['keytool'] ?? _findKeytool();
    final result = await Process.run(keytool, [
      '-exportcert',
      '-keystore',
      keystore,
      '-alias',
      args['alias'] ?? 'androiddebugkey',
      '-storepass',
      args['storepass'] ?? 'android',
    ], stdoutEncoding: null);
    if (result.exitCode != 0) {
      stderr.writeln('keytool failed:\n${result.stderr}');
      exit(1);
    }
    der = result.stdout as List<int>;
  }

  stdout.writeln(computeAppHash(packageName, der));
}

Map<String, String> _parse(List<String> arguments) {
  final out = <String, String>{};
  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    if (!arg.startsWith('--')) continue;
    final eq = arg.indexOf('=');
    if (eq != -1) {
      out[arg.substring(2, eq)] = arg.substring(eq + 1);
    } else if (i + 1 < arguments.length && !arguments[i + 1].startsWith('--')) {
      out[arg.substring(2)] = arguments[++i];
    } else {
      out[arg.substring(2)] = '';
    }
  }
  return out;
}

String _defaultDebugKeystore() {
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
  return '$home${Platform.pathSeparator}.android${Platform.pathSeparator}debug.keystore';
}

String _findKeytool() {
  final exe = Platform.isWindows ? 'keytool.exe' : 'keytool';
  final candidates = [
    if (Platform.environment['JAVA_HOME'] case final javaHome?)
      '$javaHome/bin/$exe',
    if (Platform.isWindows) ...[
      r'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe',
      '${Platform.environment['LOCALAPPDATA']}\\Programs\\Android Studio\\jbr\\bin\\keytool.exe',
    ],
    if (Platform.isMacOS)
      '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool',
    if (Platform.isLinux) '/opt/android-studio/jbr/bin/keytool',
  ];
  return candidates.firstWhere((p) => File(p).existsSync(), orElse: () => exe);
}
