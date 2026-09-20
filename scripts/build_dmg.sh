#!/usr/bin/env bash
# Build macOS DMG for Q-Audio
# Run from project root (app/)

set -euo pipefail

APP_NAME="Q-Audio"
BUILD_DIR="build/macos/Build/Products/Release"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
OUTPUT_NAME="${APP_NAME}-${1:-$(git describe --tags --always 2>/dev/null || echo 'dev')}-macos.dmg"

echo "=== Building DMG for $APP_NAME ==="

if [ ! -d "$APP_BUNDLE" ]; then
  echo "Error: App bundle not found at $APP_BUNDLE"
  echo "Run 'flutter build macos --release' first"
  exit 1
fi

# Verify create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
  echo "Error: create-dmg not found. Install with: brew install create-dmg"
  exit 1
fi

# Create DMG
echo "Creating DMG..."
create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 200 190 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 600 185 \
  "$OUTPUT_NAME" \
  "$APP_BUNDLE"

echo "=== DMG created: $OUTPUT_NAME ==="
ls -lh "$OUTPUT_NAME"