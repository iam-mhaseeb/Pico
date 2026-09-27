# Contributing to Pico

Thanks for helping improve Pico. This guide covers how to propose changes.

## Ways to contribute

- Bug reports and reproducible steps
- Feature ideas (open an issue first for large changes)
- Documentation and compatibility checklist updates
- Unit tests and small, focused PRs

## Development setup

1. Install **Xcode 26+** and **XcodeGen** (`brew install xcodegen`).
2. Clone the repo and generate the project:

   ```bash
   xcodegen generate
   open Pico.xcodeproj
   ```

3. Run the **Pico** scheme. Grant Accessibility (and Screen Recording if you exercise Look).
4. Run tests before opening a PR:

   ```bash
   xcodegen generate
   xcodebuild -scheme Pico -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
   ```

Always treat `project.yml` as the source of truth for the Xcode project. After changing targets or sources, run `xcodegen generate` and commit the updated `Pico.xcodeproj` if it changes.

## Coding guidelines

- Match existing Swift / SwiftUI style in the file you touch.
- Prefer small, focused diffs. Do not refactor unrelated code in the same PR.
- Keep AI and Accessibility seams injectable so unit tests can use mocks (`AIProvider`, `AccessibilityProviding`, etc.).
- Do not add analytics, network calls, or third-party telemetry without discussion.
- Do not commit secrets, personal absolute paths, or DerivedData.

## Pull requests

1. Open an issue for non-trivial features so scope can be agreed first.
2. Branch from `main`.
3. Keep the PR focused; include a short summary and test plan.
4. Ensure CI (unit tests on `macos-26`) is green.
5. Be kind in review — see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Reporting security issues

Please do **not** open a public issue for security problems. Follow [SECURITY.md](SECURITY.md).
