# Pico

**A little AI buddy** for your Mac.

Pico is a native macOS accessory app: a quiet desktop mascot + menu bar utility with two core flows:

1. **Ask Pico** — press `⌥ Space` from anywhere and chat with on-device Apple Intelligence. Ask it to look at your screen or click something when you need hands-on help.
2. **Text Actions** — select text, press `⌥ ⇧ Space`, preview a rewrite, then Insert.

## Requirements

- macOS 26.0+
- Xcode 26+
- Apple Intelligence enabled for on-device AI
- Accessibility permission for system-wide text actions and UI clicks
- Screen Recording permission to look at the display (only when you ask)

## Features (v1)

- Local-first AI via Apple Foundation Models (no account, no API key, no cloud required)
- Floating assistant with streaming responses and markdown
- **Look at screen** — when you ask (or tap Look), Pico captures the display on-device, reads the UI, and can click, type, or press keys
- Conversation history (SwiftData)
- System-wide text actions: Rewrite, Fix grammar, Professional, Casual, Shorter, Improve
- Desktop mascot with idle / listening / thinking / success / error states
- Launch at login, pause/resume, multi-monitor placement

## Build & run

```bash
cd /Users/haseeb/projects/pico
xcodegen generate
open Pico.xcodeproj
```

Select the **Pico** scheme and Run.

Or from the CLI:

```bash
xcodegen generate
xcodebuild -scheme Pico -configuration Debug build
```

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `⌥ Space` | Toggle Ask Pico |
| `⌥ ⇧ Space` | Text Actions |
| `Esc` | Close active panel |
| `Enter` | Send (Ask) |
| `⇧ Enter` | New line |
| `⌘ Enter` | Ask |

## Privacy

When using on-device AI, your text stays on your Mac. Screen captures are processed on-device, are not stored in conversation history, and are not uploaded. Pico v1 has no backend, no analytics, and does not log prompts or responses.

## Compatibility checklist

Manual verification targets for Text Actions / Ask:

- Safari, Chrome, Slack, Discord, VS Code, Terminal, Notes, Mail, TextEdit, Microsoft Office

## License

See the repository for license details.
