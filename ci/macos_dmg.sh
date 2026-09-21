#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Q-Audio"
BUILD_DIR="build/macos/Build/Products/Release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_DIR="build/macos/dmg"
DMG_PATH="${DMG_DIR}/${APP_NAME}.dmg"

mkdir -p "${DMG_DIR}"
rm -f "${DMG_PATH}"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${APP_PATH}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"