# Pico

**A little AI buddy** for your Mac.

Pico is a local-first macOS menu bar app with a small mascot, powered by on-device Apple Intelligence. No account, no API key, no cloud backend. Pico stays in the menu bar instead of sitting on the desktop.

## What it does

1. **Ask Pico** (click the face, or `⌥ Space`) — chat from the menu bar. Ask it to look at your screen or act on the UI when you need hands-on help. Pico asks before it clicks or types.
2. **Text Actions** (`⌥ ⇧ Space`) — select text, preview a rewrite, then Copy or Insert. You can also give Pico your own instruction.
3. **Menu bar mascot** — a pebble with two eyes. Click it to ask. Right-click for the menu.

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
- Text actions: Rewrite, Fix grammar, Professional, Casual, Shorter, Improve, Reply, Translate, Bullets, plus your own instruction
- Copy or Insert a rewrite, and undo the last insert from the menu
- Saved prompts, searchable history, and rename
- Shortcuts you can change
- Screen control asks first, and can be limited to apps you choose
- Update check against GitHub releases (no chats or screens are sent)
- Menu bar mascot that reacts while Pico is listening, thinking, or done
- Launch at login, pause/resume

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
| `⌥ Space` | Toggle Ask Pico (default; change it in Settings) |
| `⌥ ⇧ Space` | Text Actions (default; change it in Settings) |
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
  System/        # Hotkeys, clipboard, panels, menu bar
  UI/            # Mascot, Ask, Text Actions, History, Settings, Onboarding
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

## Updates

Settings → **Check for updates** asks GitHub which release is newest. It does not send prompts, rewrites, or screen contents.

A downloadable build needs to be signed and notarized on a Mac with an Apple Developer account:

```bash
codesign --deep --force --options runtime --sign "Developer ID Application: Your Name" Pico.app
xcrun notarytool submit Pico.zip --apple-id you@example.com --team-id TEAMID --password APP_PASSWORD --wait
xcrun stapler staple Pico.app
```

Publish that build as a GitHub release. The in-app check reads `https://api.github.com/repos/iam-mhaseeb/Pico/releases/latest`.

## License

[MIT](LICENSE) © Muhammad Haseeb
