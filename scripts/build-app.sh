#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${TEXTREAM_CONFIGURATION:-release}"
BUNDLE_ID="${TEXTREAM_BUNDLE_ID:-com.hudsonnicoletti.Textream}"
VERSION="${TEXTREAM_VERSION:-0.1.0}"
BUILD_NUMBER="${TEXTREAM_BUILD_NUMBER:-1}"
SIGN_IDENTITY="${TEXTREAM_SIGN_IDENTITY:-}"
APP="$ROOT/.build/Textream.app"
BIN="$ROOT/.build/$CONFIGURATION/Textream"
ICONSET="$ROOT/.build/Textream.iconset"
ENTITLEMENTS="$ROOT/packaging/Textream.entitlements"
PRIVACY="$ROOT/packaging/PrivacyInfo.xcprivacy"

cd "$ROOT"
swift build -c "$CONFIGURATION"
rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
cp "$BIN" "$APP/Contents/MacOS/Textream"
cp "$PRIVACY" "$APP/Contents/Resources/PrivacyInfo.xcprivacy"

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
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Textream</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>Textream</string>
  <key>CFBundleDisplayName</key><string>Textream</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>Textream</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
  <key>LSMinimumSystemVersion</key><string>14.7</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Textream contributors. All rights reserved.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Textream listens for voice activity to pause and resume teleprompter scrolling.</string>
  <key>ITSAppUsesNonExemptEncryption</key><false/>
</dict>
</plist>
PLIST

if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP"
fi

echo "$APP"
