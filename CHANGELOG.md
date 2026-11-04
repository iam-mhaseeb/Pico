# Changelog

All notable changes to Pico are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- **Pico is now a Text Actions-only, on-device writing helper** (a Grammarly-style alternative). Select text, press `⌥ ⇧ Space`, preview, insert
- Preview highlights the words that changed
- Long selections (up to 12,000 characters) are processed in paragraph-sized chunks to fit the on-device model
- SwiftUI settings and onboarding trimmed to the one remaining permission (Accessibility)
- `Pico.xcodeproj` is generated from `project.yml` and no longer tracked
- Hardened Runtime enabled; unsigned Release build workflow added

### Removed

- Ask Pico chat, conversation history (and the SwiftData store), the `⌥ Space` shortcut
- Screen help: screen capture, OCR, UI clicking/typing/key presses, and the Screen Recording permission
- Desktop overlay and mascot extras from earlier builds
- Unused code

### Fixed

- Race conditions in on-device generation and Text Actions cancellation
- Clipboard capture waits longer for slow apps; the clipboard is restored even when a paste is cancelled
- Multi-monitor coordinate conversion for selection rects
- Launch-at-login preference stores the real system status
- Generated text can no longer be treated as instructions by the model

## [1.0.0] - 2026-08

### Added

- Ask Pico (`⌥ Space`) with on-device Apple Intelligence streaming chat
- Look at screen + on-device UI actions (click / type / keys) when asked
- Text Actions (`⌥ ⇧ Space`) with preview and Insert
- Desktop pet: drag, gestures, edge snap, Ghost Mode, speech
- History (SwiftData), Settings, onboarding, launch at login, pause/resume
- Unit tests and GitHub Actions CI on `macos-26`
