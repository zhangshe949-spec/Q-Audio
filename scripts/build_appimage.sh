#!/usr/bin/env bash
# Build Linux AppImage for Q-Audio
# Run from project root (app/)

set -euo pipefail

APP_NAME="Q-Audio"
BUILD_DIR="build/linux/x64/release/bundle"
APPIMAGE_DIR="AppDir"
OUTPUT_NAME="${APP_NAME}-${1:-$(git describe --tags --always 2>/dev/null || echo 'dev')}-linux-x64.AppImage"

echo "=== Building AppImage for $APP_NAME ==="

# Clean previous build
rm -rf "$APPIMAGE_DIR"
mkdir -p "$APPIMAGE_DIR/usr/bin"
mkdir -p "$APPIMAGE_DIR/usr/share/applications"
mkdir -p "$APPIMAGE_DIR/usr/share/icons/hicolor/256x256/apps"
mkdir -p "$APPIMAGE_DIR/usr/share/metainfo"

# Copy built bundle
echo "Copying bundle..."
cp -r "$BUILD_DIR"/* "$APPIMAGE_DIR/usr/bin/"

# Find the executable
EXECUTABLE=$(find "$APPIMAGE_DIR/usr/bin" -maxdepth 1 -type f -executable -name "$APP_NAME" | head -1)
if [ -z "$EXECUTABLE" ]; then
  EXECUTABLE=$(find "$APPIMAGE_DIR/usr/bin" -maxdepth 1 -type f -executable | head -1)
fi
echo "Found executable: $EXECUTABLE"

# Create AppRun entry point
cat > "$APPIMAGE_DIR/AppRun" << 'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
export QT_QPA_PLATFORM=xcb
exec "$HERE/usr/bin/q_audio" "$@"
EOF
chmod +x "$APPIMAGE_DIR/AppRun"

# Create .desktop file
cat > "$APPIMAGE_DIR/usr/share/applications/${APP_NAME}.desktop" << EOF
[Desktop Entry]
Name=$APP_NAME
Comment=Modern desktop music player
Exec=q_audio
Icon=$APP_NAME
Type=Application
Categories=AudioVideo;Audio;Player;
StartupNotify=true
MimeType=audio/mpeg;audio/ogg;audio/flac;audio/x-wav;audio/mp4;x-content/audio-player;
EOF

# Copy icon (use Flutter's generated icon or fallback)
ICON_SOURCE="linux/icon.png"
if [ -f "$ICON_SOURCE" ]; then
  cp "$ICON_SOURCE" "$APPIMAGE_DIR/usr/share/icons/hicolor/256x256/apps/${APP_NAME}.png"
  cp "$ICON_SOURCE" "$APPIMAGE_DIR/${APP_NAME}.png"
else
  # Create a simple fallback icon
  convert -size 256x256 xc:none -fill "#6366f1" -draw "circle 128,128 128,20" "$APPIMAGE_DIR/usr/share/icons/hicolor/256x256/apps/${APP_NAME}.png" 2>/dev/null || \
  echo "Warning: Could not create icon (imagemagick not installed)"
  cp "$APPIMAGE_DIR/usr/share/icons/hicolor/256x256/apps/${APP_NAME}.png" "$APPIMAGE_DIR/${APP_NAME}.png" 2>/dev/null || true
fi

# Create AppStream metainfo
cat > "$APPIMAGE_DIR/usr/share/metainfo/${APP_NAME}.metainfo.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>${APP_NAME}.desktop</id>
  <name>$APP_NAME</name>
  <summary>Modern desktop music player with local library, online sources, lyrics, equalizer, and more</summary>
  <description>
    <p>$APP_NAME is a feature-rich desktop music player built with Flutter.</p>
    <p>Features:</p>
    <ul>
      <li>Local music library with metadata scanning</li>
      <li>Online music sources (NetEase, QQ, Kuwo)</li>
      <li>Synchronized lyrics (LRC) display</li>
      <li>10-band equalizer with presets</li>
      <li>Download manager with resume support</li>
      <li>Playlists and queue management</li>
      <li>System tray and global hotkeys</li>
      <li>Cross-platform: Windows, macOS, Linux</li>
    </ul>
  </description>
  <project_license>MIT</project_license>
  <url type="homepage">https://github.com/yourusername/q-audio</url>
  <url type="bugtracker">https://github.com/yourusername/q-audio/issues</url>
  <provides>
    <binary>q_audio</binary>
  </provides>
  <screenshots>
    <screenshot type="default">https://raw.githubusercontent.com/yourusername/q-audio/main/assets/screenshot.png</screenshot>
  </screenshots>
  <releases>
    <release version="${1:-dev}" date="$(date +%Y-%m-%d)"/>
  </releases>
</component>
EOF

# Build AppImage
echo "Running linuxdeploy..."
linuxdeploy --appdir "$APPIMAGE_DIR" --plugin gtk --output appimage

# Rename output
mv "${APP_NAME}"-*.AppImage "$OUTPUT_NAME" 2>/dev/null || true

echo "=== AppImage created: $OUTPUT_NAME ==="
ls -lh "$OUTPUT_NAME"