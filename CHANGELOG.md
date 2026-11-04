# Changelog

All notable changes to Pico are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Security

- Screen text is treated as untrusted; the model can no longer press quit/close/delete-style shortcuts (⌃/⌥/fn combos and most ⌘ combos) and won't type into focused secure fields
- Screen tools no longer carry over between conversations and expire after 5 idle minutes
- Screen intent detection no longer fires on ordinary questions such as “how do I submit a PR?”
- Hardened Runtime enabled; unsigned Release build workflow added
- Stored history is bounded and flattened before it is sent back to the model

### Fixed

- A corrupt or unmigratable history store no longer crashes the app on launch; Pico falls back to an in-memory store and tells you
- Race conditions in on-device generation and Text Actions cancellation (a newer request could be dropped; cancelling no longer stops unrelated Ask streams)
- Clipboard capture waits longer for slow apps; the clipboard is restored even when a paste is cancelled
- Multi-monitor coordinate conversion for selection rects and display detection
- Key shortcuts use the active keyboard layout; typed text keeps emoji intact
- Cancelling a screen action no longer re-opens panels the user closed
- Launch-at-login preference stores the real system status

### Changed

- SwiftData store now uses a versioned schema (V1) with a migration plan
- `Pico.xcodeproj` is generated from `project.yml` and no longer tracked
- Removed unused code

- Pico runs from the menu bar. The mascot is the menu bar face and still reacts during Ask and Text Actions
- Ask and History open under the menu bar icon

### Removed

- Desktop overlay
- Mascot extras: drag, pet, feed, shoo, toys, Ghost Mode, edge snap, wander, care stats, outfits, speech, and pet tips

### Added

- Open-source project docs: LICENSE (MIT), CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, PRIVACY, issue/PR templates
- Screen prompts that ask Pico to read on-screen instructions trigger Look

## [1.0.0] - 2026-08

### Added

- Ask Pico (`⌥ Space`) with on-device Apple Intelligence streaming chat
- Look at screen + on-device UI actions (click / type / keys) when asked
- Text Actions (`⌥ ⇧ Space`) with preview and Insert
- Desktop pet: drag, gestures, edge snap, Ghost Mode, speech
- History (SwiftData), Settings, onboarding, launch at login, pause/resume
- Unit tests and GitHub Actions CI on `macos-26`
