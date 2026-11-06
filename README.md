# oneplus buds menu

[![license: mit](https://img.shields.io/badge/license-mit-yellow.svg)](LICENSE)
[![macos ci](https://github.com/Saketdesign/OnePlus-Buds-Menu/actions/workflows/ci.yml/badge.svg)](https://github.com/Saketdesign/OnePlus-Buds-Menu/actions/workflows/ci.yml)

macos menu bar app to switch noise modes and check battery on oneplus buds.

## download

[download latest macos app (.dmg)](https://github.com/Saketdesign/OnePlus-Buds-Menu/releases/latest/download/OnePlus-Buds-Menu.dmg)

## what it does

- connects to compatible oneplus buds over bluetooth
- switches between noise cancellation, transparency, and off
- shows left, right, and case battery levels right in the macos menu bar
- optional launch at login
- includes packaging script to generate a signed and notarized dmg

## requirements

- macos 13.0 or later
- xcode with swiftui and corebluetooth support
- compatible oneplus buds paired with your mac

## build and run

open the project in xcode:

```sh
open "OnePlus Buds Menu.xcodeproj"
```

then select the `OnePlus Buds Menu` scheme and run the app.

or build an unsigned release app from the command line:

```sh
xcodebuild \
  -project "OnePlus Buds Menu.xcodeproj" \
  -scheme "OnePlus Buds Menu" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath Build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## run tests

```sh
xcodebuild test \
  -project "OnePlus Buds Menu.xcodeproj" \
  -scheme "OnePlus Buds Menu" \
  -destination "platform=macOS"
```

## create a release dmg

save notarization credentials to your keychain once:

```sh
xcrun notarytool store-credentials "OnePlusBudsMenu-Notary"
```

then run:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARY_KEYCHAIN_PROFILE="OnePlusBudsMenu-Notary" \
Packaging/release.sh
```

the notarized dmg and sha-256 checksum are written to:

```text
Artifacts/OnePlus-Buds-Menu.dmg
Artifacts/OnePlus-Buds-Menu.dmg.sha256
```

## notes

this uses private bluetooth command packets to talk to oneplus buds. behavior can vary depending on your earbuds' firmware version and hardware model.

## community & support

- issue sla: bug reports and questions are answered within 24 hours.
- discussions: join our [github discussions](https://github.com/Saketdesign/OnePlus-Buds-Menu/discussions).

## license

[mit](LICENSE) © 2026 Saket Joshi
