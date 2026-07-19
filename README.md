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

You can also build a release app from the command line:

```sh
xcodebuild \
  -project "OnePlus Buds Menu.xcodeproj" \
  -scheme "OnePlus Buds Menu" \
  -configuration Release \
  -derivedDataPath DerivedData-DMG \
  build
```

## Package A DMG

After building the Release app, create the installer DMG:

```sh
Packaging/DMG/create-dmg.sh
```

The generated DMG is written to:

```text
Artifacts/OnePlus-Buds-Menu.dmg
```

## Notes

The app uses private Bluetooth command packets for OnePlus Buds control. Behavior can vary by firmware version and device model.

The project is built as a native SwiftUI menu bar app for macOS.
