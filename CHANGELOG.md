# Changelog

All notable changes to Pico are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- **Pico is now a Text Actions-only, on-device writing helper** (a Grammarly-style alternative). Select text, press `⌥ ⇧ Space`, preview, insert
- App icon: Pico now has a launcher icon (the pencil on ruled paper) in every size macOS needs, so it shows in Finder, Spotlight, Login Items and the Accessibility list
- New mascot: Pico is now a pencil with a face (eraser, ferrule, wooden tip). It writes a little scribble while thinking, sparkles on success, and still reacts in every state
- Preview highlights the words that changed
- Long selections (up to 12,000 characters) are processed in paragraph-sized chunks to fit the on-device model
- SwiftUI settings and onboarding trimmed to the one remaining permission (Accessibility)
- `Pico.xcodeproj` is generated from `project.yml` and no longer tracked
- Hardened Runtime enabled; tag-triggered Release workflow publishes an unsigned `Pico.zip` to GitHub Releases, with the version taken from the tag

- About Pico item in the menu bar menu (author, email, website)

### Removed

- Ask Pico chat, conversation history (and the SwiftData store), the `⌥ Space` shortcut
- Screen help: screen capture, OCR, UI clicking/typing/key presses, and the Screen Recording permission
- Desktop overlay and mascot extras from earlier builds
- Unused code

### Fixed

- Release workflow marks tags with a hyphen (for example `v1.0.0-rc2`) as pre-releases and writes the release notes from `CHANGELOG.md` instead of listing every merged PR
- Text Actions panel no longer cuts off its message or shows hard, square-looking bottom corners: it sizes itself to its content and uses the window's own shadow
- Accessibility prompt explains the "switched on but still blocked" case (the permission is tied to the exact app build for unsigned apps) and offers **Reset & Re-enable**, also available in Settings
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
