# Apple publishing

Textream is prepared for Apple distribution, but final upload/signing must happen on a machine with full Xcode and an Apple Developer account.

## Bundle settings

Default values used by `scripts/build-app.sh`:

```bash
TEXTREAM_BUNDLE_ID=com.hudsonnicoletti.Textream
TEXTREAM_VERSION=0.1.0
TEXTREAM_BUILD_NUMBER=1
TEXTREAM_CONFIGURATION=release
```

Override when needed:

```bash
TEXTREAM_VERSION=1.0.0 TEXTREAM_BUILD_NUMBER=2 scripts/build-app.sh
```

## Local release app

```bash
scripts/build-app.sh
scripts/validate-publishing.sh
open .build/Textream.app
```

## Signing

For Developer ID distribution outside the Mac App Store:

```bash
TEXTREAM_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" scripts/build-app.sh
```

For Mac App Store, create an Xcode macOS app target using this Swift package source, then use:

- bundle id: `com.hudsonnicoletti.Textream`
- minimum macOS: 14.7
- category: Productivity
- sandbox: enabled
- audio input entitlement: enabled
- microphone usage description: `Textream listens for voice activity to pause and resume teleprompter scrolling.`
- privacy manifest: `packaging/PrivacyInfo.xcprivacy`
- entitlements: `packaging/Textream.entitlements`

Then archive in Xcode:

```bash
Product → Archive → Distribute App → App Store Connect
```

## App Store Connect privacy answers

Current app behavior:

- Audio is used only locally for voice activity detection.
- Audio is not recorded.
- Audio is not transcribed.
- Audio is not uploaded.
- No analytics SDK.
- No tracking.
- No third-party dependencies.

## Before submitting

- Test microphone permission prompt from a clean install.
- Test quit/reopen preserves pasted script.
- Test resize grip on built-in and external displays.
- Test fallback overlay on non-notched displays.
- Increment `TEXTREAM_BUILD_NUMBER` for every upload.
