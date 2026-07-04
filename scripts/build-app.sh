#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/.build/Textream.app"
BIN="$ROOT/.build/debug/Textream"
ICONSET="$ROOT/.build/Textream.iconset"

cd "$ROOT"
swift build
rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
cp "$BIN" "$APP/Contents/MacOS/Textream"

cp AppIcon.appiconset/16.png "$ICONSET/icon_16x16.png"
cp AppIcon.appiconset/32.png "$ICONSET/icon_16x16@2x.png"
cp AppIcon.appiconset/32.png "$ICONSET/icon_32x32.png"
cp AppIcon.appiconset/64.png "$ICONSET/icon_32x32@2x.png"
cp AppIcon.appiconset/128.png "$ICONSET/icon_128x128.png"
cp AppIcon.appiconset/256.png "$ICONSET/icon_128x128@2x.png"
cp AppIcon.appiconset/256.png "$ICONSET/icon_256x256.png"
cp AppIcon.appiconset/512.png "$ICONSET/icon_256x256@2x.png"
cp AppIcon.appiconset/512.png "$ICONSET/icon_512x512.png"
cp AppIcon.appiconset/1024.png "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Textream.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Textream</string>
  <key>CFBundleIdentifier</key><string>dev.local.Textream</string>
  <key>CFBundleName</key><string>Textream</string>
  <key>CFBundleDisplayName</key><string>Textream</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>Textream</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>Textream listens for voice activity to pause and resume scrolling.</string>
</dict>
</plist>
PLIST

echo "$APP"
