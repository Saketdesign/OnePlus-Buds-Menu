#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DMG_DIR="$ROOT_DIR/Packaging/DMG"
APP_PATH="${1:-$ROOT_DIR/Build/DerivedData/Build/Products/Release/OnePlus Buds Menu.app}"
OUTPUT_DIR="$ROOT_DIR/Artifacts"
VOLUME_NAME="OnePlus Buds Menu"
DMG_NAME="OnePlus-Buds-Menu.dmg"
STAGING_DIR=""
RW_DMG="$OUTPUT_DIR/$VOLUME_NAME-rw.dmg"
FINAL_DMG="$OUTPUT_DIR/$DMG_NAME"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  echo "Build the Release app first, or pass the app path as the first argument." >&2
  exit 1
fi

if [[ ! -f "$DMG_DIR/generated/dmg-background.png" ]]; then
  echo "DMG background not found. Run generate-background.py first." >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d "$ROOT_DIR/.dmg-staging.XXXXXX")"
DEVICE=""
MOUNT_POINT=""

cleanup() {
  if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet || true
  elif [[ -n "$DEVICE" ]]; then
    hdiutil detach "$DEVICE" -quiet || true
  fi
  rm -rf "$STAGING_DIR"
  rm -f "$RW_DMG"
}
trap cleanup EXIT

mkdir -p "$STAGING_DIR/.background" "$OUTPUT_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$DMG_DIR/generated/dmg-background.png" "$STAGING_DIR/.background/background.png"

rm -f "$RW_DMG" "$FINAL_DMG"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  "$RW_DMG"

MOUNT_OUTPUT="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen)"
DEVICE="$(printf '%s\n' "$MOUNT_OUTPUT" | awk -F '\t' 'index($NF, "/Volumes/") == 1 { print $1; exit }')"
MOUNT_POINT="$(printf '%s\n' "$MOUNT_OUTPUT" | awk -F '\t' 'index($NF, "/Volumes/") == 1 { print $NF; exit }')"

osascript <<APPLESCRIPT
tell application "Finder"
  set bgFile to POSIX file "$MOUNT_POINT/.background/background.png" as alias
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 640, 440}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 100
    set text size of viewOptions to 10
    set background picture of viewOptions to bgFile
    set position of item "OnePlus Buds Menu.app" of container window to {140, 170}
    set position of item "Applications" of container window to {400, 170}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_POINT" -quiet
MOUNT_POINT=""
DEVICE=""

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG"
rm -f "$RW_DMG"
rm -rf "$STAGING_DIR"
trap - EXIT

echo "$FINAL_DMG"
