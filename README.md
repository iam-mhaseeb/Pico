# Pico

**A little AI buddy** for your Mac.

Pico is a local-first macOS accessory app: a quiet desktop mascot and menu bar utility powered by on-device Apple Intelligence. No account, no API key, no cloud backend.

## What it does

1. **Ask Pico** (`⌥ Space`) — chat from anywhere. Ask it to look at your screen or act on the UI when you need hands-on help.
2. **Text Actions** (`⌥ ⇧ Space`) — select text, preview a rewrite, then Insert.
3. **Desktop pet** — drag, click, feed, and shoo. Ghost Mode fades Pico while you type.

## Requirements

- macOS 26.0+
- Xcode 26+ (and [XcodeGen](https://github.com/yonaskolb/XcodeGen))
- Apple Intelligence enabled for on-device AI
- **Accessibility** — text capture/replace and UI clicks
- **Screen Recording** — only when you ask Pico to look at the display

> Pico is intentionally **not App Sandboxed** in v1 so it can register global hotkeys, use Accessibility, and synthesize key events.

## Features

- Local-first AI via Apple Foundation Models
- Streaming Ask panel with markdown
- **Look at screen** — on-device capture + UI reading; can click, type, or press keys when you ask
- Conversation history (SwiftData; optional Keep History)
- Text actions: Rewrite, Fix grammar, Professional, Casual, Shorter, Improve
- Pet emotions, edge snap, Ghost Mode, launch at login, pause/resume
- Multi-monitor aware placement

## Build & run

```bash
git clone https://github.com/iam-mhaseeb/Pico.git
cd Pico
brew install xcodegen   # if needed
xcodegen generate
open Pico.xcodeproj
```

Select the **Pico** scheme and Run (⌘R).

CLI:

```bash
xcodegen generate
xcodebuild -scheme Pico -destination 'platform=macOS' build
```

Tests:

```bash
xcodegen generate
xcodebuild -scheme Pico -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

On first launch, grant Accessibility (and Screen Recording when prompted for Look).

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `⌥ Space` | Toggle Ask Pico |
| `⌥ ⇧ Space` | Text Actions |
| `Esc` | Close active panel |
| `Enter` | Send (Ask) |
| `⇧ Enter` | New line |
| `⌘ Enter` | Ask |

## Project layout

```
Pico/
  App/           # AppDelegate, coordinator, environment
  Core/AI/       # Foundation Models provider, prompts, screen tools
  Core/Screen/   # Capture, OCR, AX snapshot, UI actions
  Core/Text/     # Text Actions capture / transform / insert
  Core/Conversations/
  System/        # Hotkeys, clipboard, panels, ghost mode
  UI/            # Pet, Ask, Text Actions, History, Settings, Onboarding
PicoTests/       # Unit tests (mocked AI / AX)
project.yml      # XcodeGen spec — regenerate the .xcodeproj from this
```

## Privacy

When using on-device AI, prompts and screen captures stay on your Mac. Screen frames are not stored in conversation history and are not uploaded. Pico v1 has no backend, no analytics SDK, and does not log prompts or responses.

See [PRIVACY.md](PRIVACY.md) for a short privacy summary and [SECURITY.md](SECURITY.md) for how to report vulnerabilities.

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Compatibility

Manual Text Actions / Ask targets are tracked in [COMPATIBILITY.md](COMPATIBILITY.md).

## License

[MIT](LICENSE) © Muhammad Haseeb
