# Play Store & App Store Release Checklist

## Android (Play Store)

- [ ] Set unique `applicationId` in `android/app/build.gradle.kts`
- [ ] Create upload keystore (`.jks`) and store it safely
- [ ] Create `android/key.properties` from `android/key.properties.example`
- [ ] Verify release signing is used (not debug)
- [ ] Update app version in `pubspec.yaml` (`version: x.y.z+build`)
- [ ] Build App Bundle: `flutter build appbundle --release`
- [ ] Test release bundle on internal testing track
- [ ] Prepare store listing assets (icon, screenshots, privacy policy)

## iOS (App Store)

- [ ] Set bundle identifier in Xcode (`ios/Runner.xcworkspace`)
- [ ] Configure Team signing and provisioning profiles
- [ ] Update version/build number in Xcode or `pubspec.yaml`
- [ ] Build IPA: `flutter build ipa --release`
- [ ] Upload via Xcode Organizer / Transporter
- [ ] Fill App Store Connect metadata and privacy labels

## Security & Stability

- [ ] Firestore production rules reviewed and deployed
- [ ] Firebase Auth methods and abuse protections configured
- [ ] Crash/error logging validated
- [ ] Release smoke test: login, upload CSV, SMS parse, sync

## Final QA

- [ ] No analyzer errors
- [ ] No blocker UI issues
- [ ] Authentication works after app restart
- [ ] Bank statement import works with malformed rows
