#!/usr/bin/env bash
# Build Windows MSIX for Q-Audio (run on Windows via Git Bash or WSL)
# Run from project root (app/)

set -euo pipefail

APP_NAME="Q-Audio"
OUTPUT_NAME="${APP_NAME}-${1:-$(git describe --tags --always 2>/dev/null || echo 'dev')}-windows.msix"

echo "=== Building MSIX for $APP_NAME ==="

# Verify we're on Windows
if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "cygwin" && -z "${WSL_DISTRO_NAME:-}" ]]; then
  echo "Warning: This script is designed to run on Windows (Git Bash/WSL)"
fi

# Build release
echo "Building Windows release..."
flutter build windows --release --no-pub

# Create MSIX
echo "Creating MSIX..."
flutter pub run msix:create

# Find and rename MSIX
MSIX_FILE=$(find build/msix -name "*.msix" | head -1)
if [ -n "$MSIX_FILE" ]; then
  mv "$MSIX_FILE" "$OUTPUT_NAME"
  echo "=== MSIX created: $OUTPUT_NAME ==="
  ls -lh "$OUTPUT_NAME"
else
  echo "Error: MSIX not found in build/msix/"
  exit 1
fi