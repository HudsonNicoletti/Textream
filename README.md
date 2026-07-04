# Textream

macOS SwiftUI teleprompter for notch area. Uses AVAudioEngine RMS voice activity: speech scrolls, silence pauses.

## Build/run

```bash
cd /Users/hudsonnicoletti/Textream
swift run Textream
```

Better daily-use bundle with microphone usage description:

```bash
cd /Users/hudsonnicoletti/Textream
scripts/build-app.sh
open .build/Textream.app
```

If macOS blocks microphone access, enable it in:
System Settings → Privacy & Security → Microphone → Textream or Terminal.

## Controls

- Paste script in main window.
- Play/Pause starts/stops mic-driven scrolling.
- Space toggles playback.
- Speed slider changes scroll rate.
- Mic sensitivity slider adjusts voice threshold.
- Reset returns text to start.

## Notch behavior

Textream uses public NSScreen geometry only. On built-in notched displays it positions over the notch center; elsewhere it draws a notch-shaped overlay at the top center.
