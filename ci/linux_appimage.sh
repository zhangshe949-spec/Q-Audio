#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Q-Audio"
BUILD_DIR="build/linux/x64/release/bundle"
APPIMAGE_DIR="build/linux/appimage"
APPDIR="${APPIMAGE_DIR}/AppDir"
APPIMAGE_PATH="${APPIMAGE_DIR}/${APP_NAME}.AppImage"
TOOLS_DIR="tools/appimage"

mkdir -p "${APPIMAGE_DIR}"
flutter config --enable-linux-desktop
flutter build linux --release

rm -rf "${APPDIR}"
mkdir -p "${APPDIR}"
cp -r "${BUILD_DIR}/"* "${APPDIR}/"

cat > "${APPDIR}/${APP_NAME}.desktop" <<EOF
[Desktop Entry]
Name=${APP_NAME}
Exec=${APP_NAME}
Icon=${APP_NAME}
Type=Application
Categories=Audio;Player;
EOF

chmod +x "${TOOLS_DIR}/linuxdeploy-x86_64.AppImage"
chmod +x "${TOOLS_DIR}/appimagetool-x86_64.AppImage"

"${TOOLS_DIR}/linuxdeploy-x86_64.AppImage" --appdir "${APPDIR}" --output appimage
"${TOOLS_DIR}/appimagetool-x86_64.AppImage" "${APPDIR}" "${APPIMAGE_PATH}"