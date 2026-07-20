#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DMG_DIR="$ROOT_DIR/Packaging/DMG"
APP_PATH="${1:-$ROOT_DIR/Build/DerivedData/Build/Products/Release/OnePlus Buds Menu.app}"
OUTPUT_DIR="$ROOT_DIR/Artifacts"
VOLUME_NAME="OnePlus Buds Menu"
DMG_NAME="OnePlus-Buds-Menu.dmg"
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

if ! python3 -c "import dmgbuild" >/dev/null 2>&1; then
  echo "Python package 'dmgbuild' is required. Install it with: python3 -m pip install --user dmgbuild" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -f "$FINAL_DMG"

python3 -m dmgbuild \
  -s "$DMG_DIR/settings.py" \
  -Dapp_path="$APP_PATH" \
  -Dbackground_path="$DMG_DIR/generated/dmg-background.png" \
  "$VOLUME_NAME" \
  "$FINAL_DMG"

echo "$FINAL_DMG"
