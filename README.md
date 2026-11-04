# Pico

**A private, on-device writing helper** for your Mac — a Grammarly-style alternative powered by Apple Foundation Models.

Select text in any app, press `⌥ ⇧ Space`, pick an action, preview the changes, and insert. Everything runs on-device: no account, no API key, no cloud backend. Pico lives in the menu bar.

## What it does

- **Text Actions** (`⌥ ⇧ Space`): Rewrite, Fix grammar & spelling, Make professional, Make casual, Make shorter, Improve.
- **Change preview**: the suggestion is shown next to the original with the changed words highlighted before anything is inserted.
- **Long text**: selections up to 12,000 characters are processed in paragraph-sized pieces to fit the on-device model.
- **Menu bar mascot**: Pico’s face lives in the menu bar and reacts while it works.

## Requirements

- macOS 26.0+
- Xcode 26+ (and [XcodeGen](https://github.com/yonaskolb/XcodeGen))
- Apple Intelligence enabled for on-device AI
- **Accessibility** — the only permission Pico needs: it reads the selected text and replaces it

> Pico is intentionally **not App Sandboxed** so it can register a global hotkey, use Accessibility, and synthesize copy/paste when an app doesn’t expose its selection. The Hardened Runtime is on. Pico does not capture your screen and does not click or type for you.

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

On first launch, grant Accessibility.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `⌥ ⇧ Space` | Text Actions |
| `Esc` | Close the panel |
| `Return` | Insert the previewed result |

## Project layout

```
Pico/
  App/           # AppDelegate, coordinator, environment
  Core/AI/       # Foundation Models provider, prompts
  Core/Text/     # Capture, chunking, transform, diff, insert
  System/        # Hotkey, clipboard, accessibility, panels, menu bar
  UI/            # Mascot, Text Actions, Settings, Onboarding
PicoTests/       # Unit tests (mocked AI / AX)
project.yml      # XcodeGen spec — regenerate the .xcodeproj from this
```

## Privacy

Your text is processed by the on-device model and stays on your Mac. Pico has no backend and no analytics SDK, and it does not store or log your text.

See [PRIVACY.md](PRIVACY.md) for a short privacy summary and [SECURITY.md](SECURITY.md) for how to report vulnerabilities.

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Compatibility

Manual Text Actions targets are tracked in [COMPATIBILITY.md](COMPATIBILITY.md).

## License

[MIT](LICENSE) © Muhammad Haseeb
