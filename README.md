# OnePlus Buds Menu

A lightweight macOS menu bar app for controlling OnePlus Buds noise modes and viewing battery status from the menu bar.

## Features

- Connects to compatible OnePlus Buds over Bluetooth
- Switches between Noise Cancellation, Transparency, and Off modes
- Shows left, right, and weighted total battery levels
- Displays battery percentage directly in the macOS menu bar
- Optional launch-at-login setting
- Includes a DMG packaging script for distribution

## Requirements

- macOS 13.0 or later
- Xcode with SwiftUI and CoreBluetooth support
- Compatible OnePlus Buds paired with the Mac

## Build And Run

Open the project in Xcode:

```sh
open "OnePlus Buds Menu.xcodeproj"
```

Then select the `OnePlus Buds Menu` scheme and run the app.

You can also build an unsigned Release app locally from the command line:

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

## Run Tests

```sh
xcodebuild test \
  -project "OnePlus Buds Menu.xcodeproj" \
  -scheme "OnePlus Buds Menu" \
  -destination "platform=macOS"
```

## Create A GitHub Release DMG

Public downloads should be Developer ID signed and notarized. First store
notarization credentials in the Keychain:

```sh
xcrun notarytool store-credentials "OnePlusBudsMenu-Notary"
```

Then run:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARY_KEYCHAIN_PROFILE="OnePlusBudsMenu-Notary" \
Packaging/release.sh
```

The notarized DMG and SHA-256 checksum are written to:

```text
Artifacts/OnePlus-Buds-Menu.dmg
Artifacts/OnePlus-Buds-Menu.dmg.sha256
```

Upload both files to a GitHub Release. Do not commit generated apps, Derived
Data, staging folders, or DMGs to the source tree.

## Notes

The app uses private Bluetooth command packets for OnePlus Buds control. Behavior can vary by firmware version and device model.

The project is built as a native SwiftUI menu bar app for macOS.
