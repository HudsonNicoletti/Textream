# Contributing

Thanks for improving Textream.

## Local setup

```bash
git clone <repo-url>
cd Textream
swift build
swift run Textream
```

Build the local app bundle:

```bash
scripts/build-app.sh
open .build/Textream.app
```

## Before opening a PR

Run:

```bash
swift build
scripts/build-app.sh
```

Then smoke test:

1. Paste text.
2. Press Play.
3. Speak: text scrolls.
4. Stop speaking: text pauses.
5. Reset returns to start.
6. Move to a non-notched display if available: fallback overlay appears.

## Code style

- Keep it small.
- Prefer SwiftUI/AppKit/stdlib over dependencies.
- Avoid speculative settings and abstractions.
- Keep public comments for non-obvious hardware/macOS behavior only.
- If changing notch layout, test on at least one built-in display and one external display when possible.

## Good first issues

- Better public-API notch heuristics
- Manual notch/text alignment controls
- Keyboard shortcuts for speed
- Signed release pipeline

## Reporting bugs

Include:

- macOS version
- Mac model / display type
- Screenshot if layout-related
- Exact steps to reproduce
- Expected vs actual behavior
