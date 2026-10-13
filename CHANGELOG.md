# Changelog

All notable changes to Pico are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

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
