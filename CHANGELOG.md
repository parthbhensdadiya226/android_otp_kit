## 0.1.0

- Phone Number Hint (`requestPhoneNumberHint`). Numbers that come back with a wrong country code (the SIM stores the number without `+`, and Play services reads it using the phone's language region, e.g. `+1` on English (US) or `+44` on English (UK)) are corrected using the SIM's country. Valid numbers are never changed.
- SMS Retriever and SMS User Consent via `listenForSms` / `waitForSms`. A timeout left over from an earlier, abandoned request no longer ends a new one (for example after "Resend OTP").
- App hash on device (`getAppSignatures`) and via `dart run android_otp_kit:app_hash`.
- `OtpTextField`: pin-style field with per-state `OtpBoxTheme`s (outlined, circle, underlined and filled presets), blinking cursor in the active box, tap-to-edit any box, backspace that clears only the active box, paste menu, separators, obscuring, hint character, validator and error display, custom `boxBuilder` with the public `OtpCursor`, and automatic SMS fill.
- `extractOtp` helper.
