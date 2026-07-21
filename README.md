![Textream App Icon](./TextReam/Assets.xcassets/AppIcon.appiconset/128.png)
# Textream

Textream is a tiny macOS teleprompter that lives around the MacBook notch. Paste a script, press Play, and it scrolls while you speak. Stop speaking and it pauses.

Built with SwiftUI, AppKit, and AVAudioEngine. No third-party dependencies.

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
- App icon support in macOS and the control window via `Assets.xcassets/AppIcon.appiconset`

## Screens and privacy

Textream only listens for voice activity. It does not record, store, transcribe, or send audio anywhere.

macOS may ask for microphone permission. If blocked:

System Settings → Privacy & Security → Microphone → enable Textream or Terminal.

## Requirements

- macOS 27+
- Xcode 27+

## Build and run

Open `TextReam.xcodeproj` in Xcode and run the `TextReam` scheme, or build from the command line:

```bash
xcodebuild -project TextReam.xcodeproj -scheme TextReam build
```

## Controls

- Play/Pause starts or stops mic-driven scrolling.
- Space toggles playback.
- Reset returns to start.
- Hover over the overlay pauses; leaving resumes.
- Scroll on the overlay with a trackpad to move manually.
- Up/Down arrows move backward/forward; Command-Left resets.
- Speed, font size, text color, and mic sensitivity are adjustable in the main window.

<p align="center">
  <a href="https://www.buymeacoffee.com/hudsonnicoletti">
    <img src="https://www.owlstown.com/assets/icons/bmc-yellow-button-941f96a1.png" width="240" />
  </a>
</p>

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
