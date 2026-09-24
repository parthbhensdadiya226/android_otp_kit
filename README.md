# android_otp_kit

[![pub package](https://img.shields.io/pub/v/android_otp_kit.svg)](https://pub.dev/packages/android_otp_kit)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/parthbhensdadiya226/android_otp_kit/blob/main/LICENSE)

A Flutter plugin for building OTP login screens on Android. It lets users pick their phone number from the SIM, reads the verification SMS automatically without any SMS permissions, and comes with a pin-style OTP field that fills in the code by itself.

It wraps Google's Phone Number Hint, SMS Retriever and SMS User Consent APIs, and includes a small command-line tool to generate the app hash that the SMS Retriever needs.

<img src="https://raw.githubusercontent.com/parthbhensdadiya226/android_otp_kit/main/doc/otp_field_styles.png" alt="OtpTextField in the outlined, circle, filled and custom styles" width="480">

## Features

- **Phone number hint.** Shows Google's picker with the numbers on the device, so users don't have to type their number.
- **Automatic SMS reading.** Uses the SMS Retriever API to read the OTP with no user interaction.
- **User consent fallback.** Uses the SMS User Consent API when you can't control the SMS text, for example with a third-party OTP provider. The user taps "Allow" once.
- **App hash helper.** Get the hash on the device, or from your machine with `dart run android_otp_kit:app_hash`. This works for debug keys, your own release keystore and Google Play app signing.
- **`OtpTextField` widget.** A pin-style input with one box per digit. It fills itself from the SMS, users can tap any box to correct a digit, and you can change every part of how it looks.
- **`extractOtp()` helper.** Pulls the code out of an SMS by length or with your own regular expression.

No runtime permissions and no changes to `AndroidManifest.xml` are needed.

### Platform support

| Feature | Android | iOS, web and desktop |
|---|---|---|
| Phone number hint | ✅ | Returns `null` |
| SMS Retriever and User Consent | ✅ | Empty stream |
| App hash | ✅ | Empty list |
| `OtpTextField` | ✅ Fills itself from the SMS | ✅ Works as a normal OTP field. On iOS the keyboard suggests the code from Messages |

You can call every method from shared code without checking the platform.

## Getting started

### Requirements

- Flutter 3.32 or later
- Android `minSdk` 24 or later
- A device with Google Play services

The phone number picker also needs a SIM. For SMS testing, an emulator with a Google Play system image works too, since you can send it fake SMS messages (see [Testing without a backend](#testing-without-a-backend)).

### Installation

```bash
flutter pub add android_otp_kit
```

Then import it:

```dart
import 'package:android_otp_kit/android_otp_kit.dart';
```

## Usage

### A complete login screen

Here's the whole flow in one widget: pick the number, request the OTP from your backend, and let the field fill itself.

```dart
import 'package:android_otp_kit/android_otp_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  bool _otpRequested = false;
  String? _error;

  Future<void> _pickNumber() async {
    try {
      final number = await AndroidOtpKit.requestPhoneNumberHint();
      if (number != null) _phone.text = number;
    } on PlatformException {
      // No SIM or no numbers on the device: the user types it instead.
    }
  }

  Future<void> _requestOtp() async {
    // Show the OTP field first so it's already listening when the SMS arrives.
    setState(() => _otpRequested = true);
    await myBackend.sendOtp(_phone.text);
  }

  Future<void> _verify(String code) async {
    final ok = await myBackend.verifyOtp(_phone.text, code);
    setState(() => _error = ok ? null : 'That code is not right');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
            onTap: () {
              if (_phone.text.isEmpty) _pickNumber();
            },
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _requestOtp, child: const Text('Send OTP')),
          if (_otpRequested) ...[
            const SizedBox(height: 32),
            OtpTextField(
              length: 6,
              errorText: _error,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onCompleted: _verify,
            ),
          ],
        ],
      ),
    );
  }
}
```

The sections below explain each part.

### Picking the phone number

```dart
try {
  final phone = await AndroidOtpKit.requestPhoneNumberHint();
  if (phone != null) {
    phoneController.text = phone; // e.g. +919876543210
  }
} on PlatformException catch (e) {
  // HINT_UNAVAILABLE means no SIM or no numbers on the device.
  // Let the user type the number instead.
}
```

It returns the number in international format, or `null` when the user closes the picker. A good place to call it is when the phone field gets focus while it's still empty.

Some SIMs, common in India, store the number without a `+`. On a phone set to US English, Google's API then returns it with a wrong `+1` in front. The package detects this and corrects it using the SIM's country, so you get `+91…` rather than `+1 91…`.

### The OTP field

Show `OtpTextField` once you've requested the OTP:

```dart
OtpTextField(
  length: 6,
  onCompleted: (code) => verifyOtp(code),
)
```

It starts listening for the SMS when it's built and stops when it's removed. `onCompleted` is called when every box is filled, whether the code came from the SMS, the keyboard or a paste.

#### Editing

The active box always shows a blinking cursor. Users can tap any filled box to change it:

- **Typing** fills the active box and moves to the next empty one. On a filled box it replaces just that digit.
- **Backspace** clears the active box. If the active box is already empty, it clears the one before it. Other boxes never shift.
- **Tapping an empty box** moves to the first empty box, so no gaps are left behind.
- **Long-pressing** a box shows a "Paste" option.

If a box in the middle is cleared, `controller.text` and `onChanged` give you the digits that are still filled, joined together. `onCompleted` only fires once every box is filled again.

#### Resending the OTP

To listen again, for example after "Resend OTP", give the field a new key. That starts a fresh listener. If you pass your own `controller`, call `controller.clear()` as well to empty the boxes:

```dart
OtpTextField(
  key: ValueKey(resendCount),
  onCompleted: verifyOtp,
)
```

Restarting straight away is safe. The package ignores the timeout of the previous, abandoned request, so it won't stop the new one.

#### Changing the look

Each box has a theme for every state: `defaultTheme`, `focusedTheme`, `filledTheme`, `errorTheme` and `disabledTheme`. You only need to set the ones you want to change. The rest are worked out from `defaultTheme` and your app's colors.

There are four presets to start from:

```dart
final base = OtpBoxTheme.outlined(borderColor: Colors.grey.shade300);
// or OtpBoxTheme.circle(), .underlined(), .filled()

OtpTextField(
  defaultTheme: base,
  focusedTheme: base.copyBorderWith(color: Colors.indigo, width: 2),
  filledTheme: base.copyWith(
    decoration: base.decoration!.copyWith(color: Colors.indigo.shade50),
  ),
  errorTheme: base.copyBorderWith(color: Colors.red),
)
```

`OtpBoxTheme` takes a `width`, `height`, `textStyle`, `decoration` (any `BoxDecoration`: color, border, radius, shadows, gradient), `padding` and `margin`.

Other options:

```dart
OtpTextField(
  length: 4,
  spacing: 16,                        // gap between boxes
  separatorBuilder: (i) => i == 1 ? const Text('-') : null,
  obscureText: true,                  // hide digits
  obscuringCharacter: '*',            // or obscuringWidget: Icon(...)
  hintCharacter: '0',                 // shown in empty boxes
  cursorColor: Colors.indigo,         // or a whole widget: cursor: ...
  animationDuration: Duration.zero,   // turn animations off
  hapticFeedback: false,
)
```

If the boxes don't fit the screen width, the field scales down instead of overflowing.

For something completely different, build each box yourself. `OtpBoxState` tells you the box's index, value, and whether it's focused, filled, in error or disabled. Use the package's `OtpCursor` to show which box is active:

```dart
OtpTextField(
  boxBuilder: (context, box) => CircleAvatar(
    backgroundColor: box.isFocused
        ? Colors.indigo.shade100
        : box.isFilled
            ? Colors.indigo
            : Colors.grey.shade200,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(box.value),
        if (box.isFocused) const OtpCursor(height: 18),
      ],
    ),
  ),
)
```

#### Errors

Pass `errorText` to show a message under the boxes and switch them to `errorTheme`, for example after your server rejects the code. Or use `validator`, which runs when every box is filled:

```dart
OtpTextField(
  validator: (code) => code.startsWith('0') ? 'Codes never start with 0' : null,
  errorText: serverError, // shown until you set it back to null
)
```

In the error state the border, the digits and the cursor all use the theme's error color (`colorScheme.error`), matching the message.

A `validator` error clears as soon as the user edits the code. `errorText` stays until you set it back to `null`, so clear it in `onChanged` if it should disappear while the user corrects the code. Use `forceErrorState` for the error colors without a message.

#### All options

| Option | Default | Description |
|---|---|---|
| `length` | `6` | Number of boxes |
| `controller`, `focusNode` | internal | Read or clear the value, control focus |
| `onChanged`, `onCompleted`, `onSubmitted` | | Callbacks |
| `listenForSms` | `true` | Listen for the SMS while the field is shown |
| `mode` | `retriever` | `SmsListenMode.retriever` or `userConsent` |
| `senderPhoneNumber` | | Only accept this sender (user consent only) |
| `otpPattern` | | Custom `RegExp` to find the code in the SMS |
| `onSmsEvent` | | Every SMS result, including timeouts |
| `defaultTheme`, `focusedTheme`, `filledTheme`, `errorTheme`, `disabledTheme` | from your `ColorScheme` | Box look per state |
| `boxBuilder` | | Build each box yourself |
| `spacing` | `10` | Gap between boxes |
| `separatorBuilder` | | Widget between two boxes |
| `showCursor`, `cursor`, `cursorColor` | `true`, blinking bar, primary | Cursor in the active box |
| `obscureText`, `obscuringCharacter`, `obscuringWidget` | `false`, `●` | Hide the digits |
| `hintCharacter`, `hintStyle` | | Shown in empty boxes |
| `errorText`, `validator`, `forceErrorState` | | Error state |
| `errorTextStyle`, `errorBuilder` | | How the error message looks |
| `enabled`, `readOnly`, `autofocus` | `true`, `false`, `false` | |
| `keyboardType`, `inputFormatters` | number pad, digits only | Pass `inputFormatters: []` to allow letters |
| `textInputAction` | `done` | Keyboard action button |
| `closeKeyboardWhenCompleted` | `true` | Hide the keyboard once the code is complete |
| `hapticFeedback` | `true` | Light vibration on each key press |
| `animationDuration`, `animationCurve` | 180 ms, `easeOut` | Box and digit animations |
| `enableInteractiveSelection` | `true` | Long-press "Paste" menu |
| `mainAxisAlignment` | `center` | Horizontal alignment of the boxes and the error message |

### Listening for the SMS yourself

If you're using your own input field, call `waitForSms`:

```dart
final event = await AndroidOtpKit.waitForSms(otpLength: 6);

switch (event) {
  case SmsReceived(:final code):
    if (code != null) verifyOtp(code);
  case SmsTimeout():
    showResendButton(); // nothing arrived within 5 minutes
  case SmsConsentDenied():
    // the user tapped "Deny" in the consent dialog
}
```

Or use `listenForSms` when you need to cancel it, for example when the user leaves the screen:

```dart
final subscription = AndroidOtpKit.listenForSms().listen(handleEvent);

// later
await subscription.cancel();
```

The stream gives you one event and then closes.

> Start listening **before** your backend sends the SMS. Messages that arrive earlier are not picked up.

### Choosing a mode

There are two ways to read the SMS:

**`SmsListenMode.retriever`** (default) is fully automatic, but the SMS must end with your app's 11-character hash:

```
Your MyApp verification code is 482913.

FA+9qCX9VSu
```

**`SmsListenMode.userConsent`** works with any SMS that contains a code (4–10 characters with at least one digit). Android asks the user to allow reading that one message. Use this when you can't add the hash to the SMS, for example with Firebase or another OTP provider.

```dart
OtpTextField(mode: SmsListenMode.userConsent)

// or, with your own field:
AndroidOtpKit.listenForSms(
  mode: SmsListenMode.userConsent,
  senderPhoneNumber: '+911234567890', // optional, only accept this sender
);
```

User Consent doesn't trigger for senders saved in the user's contacts.

### Getting the app hash

The hash depends on your package name and the key the app is signed with. So debug builds, your own release builds and apps installed from Google Play each have a different hash.

To see the hash of the build that's running:

```dart
final hashes = await AndroidOtpKit.getAppSignatures();
print(hashes); // [FA+9qCX9VSu]
```

To generate it on your computer, run this from your app's folder:

```bash
# debug keystore
dart run android_otp_kit:app_hash --package com.example.app

# your own keystore
dart run android_otp_kit:app_hash --package com.example.app \
  --keystore android/app/upload-keystore.jks --alias upload --storepass <password>

# Google Play app signing
dart run android_otp_kit:app_hash --package com.example.app --cert deployment_cert.der
```

If your app uses Play app signing, users' devices see Google's certificate, not your upload key. Download it from Play Console under **Test and release → App integrity → App signing** ("App signing key certificate"), and use the hash from that file in your production SMS template.

The tool finds `keytool` through `JAVA_HOME` or Android Studio's bundled JDK. If it can't, pass `--keytool <path>`, or use `--cert` to skip keytool entirely.

### Extracting the code

`SmsReceived.code` is filled in using `extractOtp`, which you can also call directly:

```dart
extractOtp('482913 is your code');                          // 482913
extractOtp('Order A12345, code 5566', length: 4);           // 5566
extractOtp('Code: G-771234', pattern: RegExp(r'G-(\d{6})')); // 771234
```

By default it returns the first standalone number with 4 to 8 digits. Digits that are part of a word or a longer number are skipped. If no code is found, `code` is `null`, but the full `message` is still available.

## Testing without a backend

You don't need a server or an SMS provider to try it out. Any SMS that reaches the phone while the app is listening will do:

- **From another phone:** send the test message to the device.
- **To yourself:** send the SMS from the device to its own number. Most carriers deliver it straight back.
- **On an emulator:** use an emulator with a **Google Play** system image and send a fake SMS from your computer. Nothing leaves your machine:

  ```bash
  adb emu sms send 5551234 "Your OTP is 482913 FA+9qCX9VSu"
  ```

It has to be a real **SMS**. If Google Messages shows "RCS chat" in the conversation, the message is sent over the internet as a chat message, and the OTP APIs never see it. Turn off RCS chats in Messages while testing, or check that the conversation says "SMS/MMS".

For **retriever mode**, the message must end with your app hash (use `getAppSignatures()` on the same build). For **user consent mode**, any message with a code works. An easy real-world test is to request a login OTP from any app or website for that phone number while your app is listening.

The [example app](https://github.com/parthbhensdadiya226/android_otp_kit/tree/main/example) shows the test message to send, with a copy button.

## Error codes

Errors come as a `PlatformException`, either thrown by `requestPhoneNumberHint` or delivered on the `listenForSms` stream.

| Code | Meaning |
|---|---|
| `HINT_UNAVAILABLE` | No SIM or phone numbers on the device, or Play services is unavailable |
| `HINT_FAILED` | The picker couldn't be opened or didn't return a number |
| `ALREADY_ACTIVE` | The picker is already open |
| `NO_ACTIVITY` | Called before the app's activity was ready |
| `START_FAILED` | Play services couldn't start listening for the SMS |
| `SMS_FAILED` | SMS retrieval failed for another reason |
| `CONSENT_UNAVAILABLE` | The consent dialog couldn't be shown |

## Troubleshooting

**The SMS is never picked up in retriever mode.** Almost always the hash doesn't match. Compare the hash at the end of the SMS with `getAppSignatures()` on the same build, and remember that Play Store installs need the Play signing hash. Also check that the hash is the last thing in the message, that the SMS is at most 140 bytes, and that you started listening before it was sent.

**Nothing happens in either mode.** Check that the message really arrived as an SMS and not as an RCS chat message (see [Testing without a backend](#testing-without-a-backend)). Real OTP services always send SMS.

**The consent dialog doesn't appear.** Check that the sender isn't in the phone's contacts, and that `senderPhoneNumber` matches the real sender. Alphanumeric sender IDs like `VM-MYAPP` won't match a phone number, so pass `null` in that case.

**The picked number starts with `+1`.** Update to the latest version. The package corrects numbers from SIMs that store them without a `+`.

**Nothing happens on iOS or web.** These APIs only exist on Android. On iOS, `OtpTextField` still gets the keyboard's one-time code suggestion from Messages.

## Additional information

- **Example:** a complete demo app is in the [`example`](https://github.com/parthbhensdadiya226/android_otp_kit/tree/main/example) folder. It lets you try every field style and both SMS modes.
- **Issues and feature requests:** please open them on [GitHub](https://github.com/parthbhensdadiya226/android_otp_kit/issues).
- **Contributing:** pull requests are welcome. Please run `flutter analyze` and `flutter test` before submitting.
- **License:** MIT. See [LICENSE](https://github.com/parthbhensdadiya226/android_otp_kit/blob/main/LICENSE).
