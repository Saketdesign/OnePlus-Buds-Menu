#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/OnePlus Buds Menu.xcodeproj"
SCHEME="OnePlus Buds Menu"
BUILD_DIR="$ROOT_DIR/Build/Release"
ARCHIVE_PATH="$BUILD_DIR/OnePlus Buds Menu.xcarchive"
APP_PATH="$ARCHIVE_PATH/Products/Applications/OnePlus Buds Menu.app"
DMG_PATH="$ROOT_DIR/Artifacts/OnePlus-Buds-Menu.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"

SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "Set DEVELOPER_ID_APPLICATION to your Developer ID Application identity." >&2
  echo "Example: Developer ID Application: Your Name (TEAMID)" >&2
  exit 1
fi

if [[ "$SKIP_NOTARIZATION" != "1" && -z "$NOTARY_PROFILE" ]]; then
  echo "Set NOTARY_KEYCHAIN_PROFILE to a notarytool keychain profile." >&2
  echo "For local packaging only, explicitly set SKIP_NOTARIZATION=1." >&2
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild clean archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Archived app was not produced at: $APP_PATH" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

ENTITLEMENTS="$(codesign -d --entitlements - "$APP_PATH" 2>/dev/null || true)"
if grep -q "com.apple.security.get-task-allow" <<<"$ENTITLEMENTS"; then
  echo "Release app unexpectedly contains get-task-allow." >&2
  exit 1
fi

BINARY="$APP_PATH/Contents/MacOS/OnePlus Buds Menu"
ARCHITECTURES="$(lipo -archs "$BINARY")"
if [[ "$ARCHITECTURES" != *"arm64"* || "$ARCHITECTURES" != *"x86_64"* ]]; then
  echo "Release app is not universal: $ARCHITECTURES" >&2
  exit 1
fi

"$ROOT_DIR/Packaging/DMG/create-dmg.sh" "$APP_PATH"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
  echo "Warning: notarization was explicitly skipped; do not publish this DMG." >&2
else
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type execute --verbose=2 "$APP_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
fi

(cd "$ROOT_DIR" && shasum -a 256 "Artifacts/$(basename "$DMG_PATH")") > "$CHECKSUM_PATH"
echo "Release artifacts:"
echo "$DMG_PATH"
echo "$CHECKSUM_PATH"
