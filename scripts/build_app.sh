#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCT_NAME="Unifer"
BUNDLE_ID="${UNIFER_BUNDLE_ID:-com.unifer.app}"
VERSION="${UNIFER_VERSION:-1.0}"
BUILD_NUMBER="${UNIFER_BUILD_NUMBER:-1}"
MIN_MACOS_VERSION="${UNIFER_MIN_MACOS_VERSION:-14.0}"
CONFIGURATION="${1:-release}"
APP_DIR="$ROOT_DIR/dist/${PRODUCT_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_PATH="$CONTENTS_DIR/Info.plist"
EXECUTABLE_PATH=""

if [[ "$CONFIGURATION" != "debug" && "$CONFIGURATION" != "release" ]]; then
  echo "Usage: $0 [debug|release]"
  exit 1
fi

echo "==> Building $PRODUCT_NAME ($CONFIGURATION)"
(cd "$ROOT_DIR" && swift build -c "$CONFIGURATION")

if [[ -f "$ROOT_DIR/.build/$CONFIGURATION/$PRODUCT_NAME" ]]; then
  EXECUTABLE_PATH="$ROOT_DIR/.build/$CONFIGURATION/$PRODUCT_NAME"
elif [[ -f "$ROOT_DIR/.build/arm64-apple-macosx/$CONFIGURATION/$PRODUCT_NAME" ]]; then
  EXECUTABLE_PATH="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIGURATION/$PRODUCT_NAME"
elif [[ -f "$ROOT_DIR/.build/x86_64-apple-macosx/$CONFIGURATION/$PRODUCT_NAME" ]]; then
  EXECUTABLE_PATH="$ROOT_DIR/.build/x86_64-apple-macosx/$CONFIGURATION/$PRODUCT_NAME"
fi

if [[ ! -f "$EXECUTABLE_PATH" ]]; then
  echo "Expected executable not found at: $EXECUTABLE_PATH"
  exit 1
fi

echo "==> Creating app bundle"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$PRODUCT_NAME"
chmod +x "$MACOS_DIR/$PRODUCT_NAME"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS_VERSION</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> Built app bundle:"
echo "    $APP_DIR"
echo
echo "Open it with:"
echo "    open \"$APP_DIR\""
