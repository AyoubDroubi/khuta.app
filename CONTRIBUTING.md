# Contributing to Khuta

Bug reports, fixes, translations and documentation are welcome. Khuta is licensed GPL-3.0-only with the additional term in `ADDITIONAL_TERMS.md`; by contributing you agree your work is released under the same terms.

## Before you start

- **Bugs and ideas:** open an issue and describe what you expected, what happened, the app version and your Android version. For a larger change, discuss it in an issue first.
- **Translations:** see [TRANSLATING.md](TRANSLATING.md). Arabic and English are the reference languages.
- **Security problems:** do not open an issue, see [SECURITY.md](SECURITY.md).

## Principles

- Local-first: all data stays on the device; no network code, no account, no analytics, no new permission without a strong reason.
- Arabic-first: every screen must work right-to-left; use directional layout values; digits stay 0–9.
- Stored data changes are additive, or come with a tested migration; every new thing the user creates must be part of the backup and restore round trip (`mobile/test/backup_complete_test.dart`).
- Keep the three UI styles (Classic, Minimal, Express) consistent; check light and dark.
- Accessibility: semantic labels, readable contrast, tap targets of at least 24 dp.

## Setup

```bash
cd mobile
flutter pub get
flutter gen-l10n        # generates the localization classes from the .arb files
flutter analyze
flutter test
```

Run the app with `flutter run`. Toolchain: Flutter (stable, Dart ^3.9.2), JDK 17, Gradle 8.14, Android Gradle Plugin 8.13, Kotlin 2.2.

Time-sensitive code is tested in several time zones; run the suite with `TZ=Pacific/Auckland flutter test` and `TZ=America/New_York flutter test` when you touch dates.

## Pull requests

- One focused change per pull request, with tests for behaviour changes.
- `flutter analyze` must be clean and `flutter test` must pass. Do not format whole files you did not change.
- Describe what changed and why; mention the screens affected and add screenshots for UI changes (Arabic and English).
- Do not commit secrets, keystores, or personal data. Release signing keys stay outside the repository.

## Release builds

A release APK is built locally with your own key:

1. Create a keystore (`keytool -genkey -v -keystore khuta.jks -keyalg RSA -keysize 2048 -validity 10000 -alias khuta`) and keep it outside the repository.
2. Create `mobile/android/key.properties` (ignored by git) with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. Without that file a release build is signed with the debug key and must not be distributed.
3. `cd mobile && flutter build apk --release`.
