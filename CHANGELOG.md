# Changelog

All notable changes to Pico are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Pico runs from the menu bar. Click the face to ask. Right-click for the menu
- The face is a pebble with two capsule eyes, in the spirit of the Grok Bot mark, with a light rim so it stays visible in the menu bar
- Ask and History open from the menu bar icon
- Shortcuts can be changed in Settings

### Added

- Copy as well as Insert, a custom writing instruction, reply, translate, and bullets
- Undo last rewrite
- Saved prompts
- Search and rename in History
- Pico asks before it clicks, types, or presses a key
- Optional list of apps Pico is allowed to control
- Check for updates against GitHub releases
- A much larger unit test pass for writing, history, shortcuts, screen confirmation, and update checks
- Open-source project docs: LICENSE (MIT), CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, PRIVACY, issue/PR templates
- Screen prompts that ask Pico to read on-screen instructions trigger Look

### Removed

- Desktop overlay
- Mascot extras: drag, pet, feed, shoo, toys, Ghost Mode, edge snap, wander, care stats, outfits, speech, and pet tips

## [1.0.0] - 2026-08

### Added

- Ask Pico (`⌥ Space`) with on-device Apple Intelligence streaming chat
- Look at screen + on-device UI actions (click / type / keys) when asked
- Text Actions (`⌥ ⇧ Space`) with preview and Insert
- Desktop pet: drag, gestures, edge snap, Ghost Mode, speech
- History (SwiftData), Settings, onboarding, launch at login, pause/resume
- Unit tests and GitHub Actions CI on `macos-26`
