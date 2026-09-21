#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Q-Audio"
BUILD_DIR="build/macos/Build/Products/Release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_DIR="build/macos/dmg"
DMG_PATH="${DMG_DIR}/${APP_NAME}.dmg"

# Verify .app bundle exists
if [ ! -d "${APP_PATH}" ]; then
    echo "ERROR: ${APP_PATH} not found!"
    echo "Searching for .app bundle..."
    find build/macos -name "*.app" -type d 2>/dev/null | head -5
    exit 1
fi

mkdir -p "${DMG_DIR}"
rm -f "${DMG_PATH}"

echo "Creating DMG from ${APP_PATH}..."
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${APP_PATH}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

echo "DMG created: ${DMG_PATH}"
ls -lh "${DMG_PATH}"