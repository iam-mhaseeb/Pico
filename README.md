<h1 align="center">✏️ Pico</h1>

<p align="center">
  A private writing helper that lives in your Mac's menu bar.<br>
  Select text anywhere, press <strong>⌥ ⇧ Space</strong>, and fix, rewrite, or reshape it, entirely on-device.
</p>

<p align="center">
  <img alt="macOS 26+" src="https://img.shields.io/badge/macOS-26%2B-1c1c1e?style=for-the-badge&logo=apple&logoColor=white">
  <img alt="On-device AI" src="https://img.shields.io/badge/AI-100%25%20on--device-0A84FF?style=for-the-badge">
  <img alt="MIT license" src="https://img.shields.io/badge/License-MIT-34c759?style=for-the-badge">
</p>

<p align="center">
  <a href="#installation">Install</a>
  ·
  <a href="#usage">Usage</a>
  ·
  <a href="#privacy">Privacy</a>
  ·
  <a href="#contributing">Contribute</a>
</p>

---

## Why it exists

Most writing assistants send everything you type to a server. Pico doesn't. It uses Apple's on-device foundation model through Apple Intelligence, so your text is edited right on your Mac. There is no account, no API key, and no cloud backend.

Pico is a small pencil in the menu bar. Select text in any app, press the shortcut, pick an action, review exactly what changed, and insert it.

## Features

| | |
| --- | --- |
| **Works in any app** | Reads your selection with Accessibility, or falls back to copy and paste for apps that don't expose it. |
| **Six actions** | Rewrite, Fix grammar & spelling, Make professional, Make casual, Make shorter, Improve. |
| **See what changed** | The suggestion sits next to your original with every changed word highlighted before anything is inserted. |
| **Long text** | Selections up to 12,000 characters are edited paragraph by paragraph so they fit the on-device model. Your spacing stays put. |
| **Private by design** | Text never leaves your Mac. No analytics, no history, nothing saved. |
| **Menu bar only** | No Dock icon. Pico stays out of the way until you need it. |
| **Clipboard safe** | If Pico has to use the clipboard, it puts your previous contents back afterwards. |

## Installation

**Requires macOS 26 or later and Apple Intelligence enabled.**

Download `Pico.zip` from the [latest release](https://github.com/iam-mhaseeb/Pico/releases/latest) once one is published, unzip it, and move **Pico** into your Applications folder. The app is unsigned, so on first launch right-click it, choose **Open**, then confirm. Until the first release is out, build it from source.

### Build from source

You need Xcode 26 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/iam-mhaseeb/Pico.git
cd Pico
brew install xcodegen   # if needed
xcodegen generate
open Pico.xcodeproj
```

Select the **Pico** scheme and run with **⌘R**. On first launch, grant **Accessibility** when asked.

The Xcode project is generated from `project.yml` and isn't checked in, so run `xcodegen generate` after pulling changes.

## Usage

Launch Pico. A pencil appears in the menu bar. Then:

1. Select some text in any app.
2. Press **⌥ ⇧ Space** (or choose **Text Actions** from the menu bar).
3. Pick an action.
4. Review the highlighted changes, then press **Return** to insert, or **Esc** to cancel.

| Menu item | Shortcut | What it does |
| --- | --- | --- |
| Text Actions | ⌥ ⇧ Space | Opens the action list for your current selection |
| About Pico | | Version and credits |
| Settings… | | Launch at login, shortcut status, Accessibility |
| Pause Pico | | Turns off the shortcut and lets the pencil nap |
| Quit Pico | | Exits the app |

### Actions

- **Rewrite**: clearer, more natural phrasing
- **Fix grammar & spelling**: corrections only, tone preserved
- **Make professional**: polished and formal
- **Make casual**: friendly and conversational
- **Make shorter**: same meaning, fewer words
- **Improve**: clarity, grammar, and flow in one pass

## Privacy

- Your text is processed by Apple's on-device model and stays on your Mac.
- No account, backend, or analytics. Pico doesn't store or log your text.
- Pico makes no network requests.
- It needs a single permission, **Accessibility**, to read your selection and replace it.

Read more in [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md). Pico is intentionally **not App Sandboxed** so it can register a global shortcut and use Accessibility. The Hardened Runtime is on.

## How it is built

SwiftUI for the panels, preview, onboarding, and settings. AppKit for the status item, floating panels, Accessibility, and clipboard. Apple's Foundation Models framework for generation. The mascot is drawn in code with SwiftUI `Canvas`.

| Path | Role |
| --- | --- |
| `Pico/App/` | App entry point, coordinator, and environment |
| `Pico/Core/AI/` | Foundation Models provider, prompts, availability |
| `Pico/Core/Text/` | Selection capture, chunking, transform, diff, insert |
| `Pico/System/` | Hotkey, Accessibility, clipboard, panels, menu bar |
| `Pico/UI/` | Pencil mascot, Text Actions panel, settings, onboarding |
| `PicoTests/` | Unit tests with mocked AI and Accessibility |
| `project.yml` | XcodeGen spec for the Xcode project |

Run the tests:

```bash
xcodegen generate
xcodebuild -scheme Pico -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```

App-by-app testing notes live in [COMPATIBILITY.md](COMPATIBILITY.md).

## Contributing

Issues and pull requests are welcome. For a larger change, open an issue first so the direction is clear.

1. Fork the repository and create a branch.
2. Make the change and commit it.
3. Open a pull request against `main`.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) and follow the [Code of Conduct](CODE_OF_CONDUCT.md). Bug reports go in [Issues](https://github.com/iam-mhaseeb/Pico/issues); include your macOS version, the app you were using, and what you expected to happen.

## Author

Created by [Muhammad Haseeb](https://muhammadhaseeb.me) · [hello@muhammadhaseeb.me](mailto:hello@muhammadhaseeb.me)

## License

Released under the [MIT License](LICENSE).

---

<p align="center">
  <sub>Write freely. Your words stay on your Mac.</sub>
</p>
