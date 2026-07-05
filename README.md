# Textream

Textream is a tiny macOS teleprompter that lives around the MacBook notch. Paste a script, press Play, and it scrolls while you speak. Stop speaking and it pauses.

Built with SwiftUI, AppKit, and AVAudioEngine. No third-party dependencies.

<a href="https://www.buymeacoffee.com/hudsonnicoletti"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee 🙏🏻&emoji=☕&slug=hudsonnicoletti&button_colour=5F7FFF&font_colour=ffffff&font_family=Lato&outline_colour=000000&coffee_colour=FFDD00" /></a>

## Features

- Notch-centered teleprompter overlay
- Fallback notch-shaped overlay on displays without a physical notch
- Voice activity detection using local microphone audio level
- Automatic scroll while speaking, pause on silence
- Hover over the prompter to pause; move away to resume
- Adjustable scroll speed and mic sensitivity
- Custom text color and font size
- Manual script navigation with trackpad scroll and keyboard shortcuts
- Script editor with paste support
- Script persists across quit/reopen via `UserDefaults`
- Play/Pause, Reset, Space shortcut
- Live resizing from the overlay bottom-right corner
- App icon support via `AppIcon.appiconset`

## Screens and privacy

Textream only listens for voice activity. It does not record, store, transcribe, or send audio anywhere.

macOS may ask for microphone permission. If blocked:

System Settings → Privacy & Security → Microphone → enable Textream or Terminal.

## Requirements

- macOS 14.7+
- Swift 6+
- Xcode Command Line Tools

Check your toolchain:

```bash
swift --version
```

## Build and run

From this repo:

```bash
swift run Textream
```

Build a local `.app` bundle with icon and microphone usage description:

```bash
scripts/build-app.sh
scripts/validate-publishing.sh
open .build/Textream.app
```

## Controls

- Play/Pause starts or stops mic-driven scrolling.
- Space toggles playback.
- Reset returns to start.
- Hover over the overlay pauses; leaving resumes.
- Scroll on the overlay with a trackpad to move manually.
- Up/Down arrows move backward/forward; Command-Left resets.
- Speed, font size, text color, and mic sensitivity are adjustable in the main window.

## Project layout

```text
Package.swift                         Swift package definition
Sources/Textream/TextreamApp.swift    App, UI, overlay, notch positioning, VAD
AppIcon.appiconset/                   Source icon PNGs
scripts/build-app.sh                  Local app bundle builder
```

## How it works

`TeleprompterModel` owns script text, playback state, scroll offset, speed, and mic status.

`VoiceActivityDetector` uses `AVAudioEngine` input taps and RMS level checks. Audio above the sensitivity threshold marks speech. A short silence hangover avoids jitter.

`NotchOverlayController` creates a borderless floating `NSPanel` on all spaces and sets `NSWindow.sharingType = .none` so it should not appear in screen sharing or window capture.

`NotchGeometry` uses public `NSScreen` data. macOS does not expose exact notch bounds through public API, so Textream uses a small built-in-display heuristic and draws a fallback notch on other displays.

`NotchOverlayView` draws solid black UI around the notch and a 133px-high scrolling text panel below it.

## Tuning

Hardware varies. If overlay placement needs adjustment, edit these constants in `NotchGeometry` and `NotchOverlayView`:

- `notchWidth`
- `notchHeight`
- default overlay height (`notchHeight + 133`)
- top overlap (`.padding(.top, -8)`)

## Release build

```bash
swift build -c release
```

For Apple publishing, see [docs/apple-publishing.md](docs/apple-publishing.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
