# android_otp_kit example

A single-screen OTP login demo:

1. Tap the phone field (or the SIM icon) to open the **Phone Number Hint** picker.
2. Choose **Retriever** or **User consent**.
3. Tap **Send OTP**. The OTP field appears and starts listening for the SMS.
4. The code fills in automatically when the SMS arrives.

The bottom of the screen shows the **app hash** for this build.

## Run

```bash
flutter run
```

Use a real Android device with Google Play services and a SIM (the hint picker and SMS APIs don't work on most emulators).

## Test the SMS

**Retriever mode:** from another phone, send an SMS that ends with the hash shown in the app:

```
<#> 123456 is your code.
<app-hash-from-screen>
```

**User consent mode:** send any SMS that contains a 6-digit code, for example `Your OTP is 123456`. Tap **Allow** in the dialog that appears.

Both modes stop listening after 5 minutes. After that you'll see `SmsTimeout`.
