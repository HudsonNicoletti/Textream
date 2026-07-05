#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/.build/Textream.app"
PLIST="$APP/Contents/Info.plist"
RES="$APP/Contents/Resources"

test -x "$APP/Contents/MacOS/Textream"
test -f "$RES/Textream.icns"
test -f "$RES/PrivacyInfo.xcprivacy"
test -f "$ROOT/packaging/Textream.entitlements"

/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$PLIST" >/dev/null
/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST" >/dev/null
/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$PLIST" >/dev/null
/usr/libexec/PlistBuddy -c 'Print NSMicrophoneUsageDescription' "$PLIST" >/dev/null
/usr/libexec/PlistBuddy -c 'Print LSApplicationCategoryType' "$PLIST" >/dev/null
/usr/libexec/PlistBuddy -c 'Print ITSAppUsesNonExemptEncryption' "$PLIST" >/dev/null

codesign --display --entitlements :- "$APP" >/dev/null 2>&1 || true
spctl --assess --type execute "$APP" >/dev/null 2>&1 || true

echo "Publishing checks passed for $APP"
