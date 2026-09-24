## 0.1.0

- Phone Number Hint (`requestPhoneNumberHint`). Numbers that come back with a wrong `+1` prefix (SIM stores the number without `+` on a US-locale phone) are corrected using the SIM's country.
- SMS Retriever and SMS User Consent via `listenForSms` / `waitForSms`. A timeout left over from an earlier, abandoned request no longer ends a new one (for example after "Resend OTP").
- App hash on device (`getAppSignatures`) and via `dart run android_otp_kit:app_hash`.
- `OtpTextField`: pin-style field with per-state `OtpBoxTheme`s (outlined, circle, underlined and filled presets), blinking cursor in the active box, tap-to-edit any box, backspace that clears only the active box, paste menu, separators, obscuring, hint character, validator and error display, custom `boxBuilder` with the public `OtpCursor`, and automatic SMS fill.
- `extractOtp` helper.
