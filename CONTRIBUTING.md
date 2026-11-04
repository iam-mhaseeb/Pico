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

3. Run the **Pico** scheme. Grant Accessibility.
4. Run tests before opening a PR:

   ```bash
   xcodegen generate
   xcodebuild -scheme Pico -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
   ```

## App icon

The icon is drawn in `Design/AppIcon.svg`. After editing it, regenerate every size (needs Node and Playwright with Chromium):

```bash
node Design/generate-icons.cjs
```

## Releasing

Maintainers publish a release by pushing a version tag:

```bash
git tag v1.0.1
git push origin v1.0.1
```

The **Release** workflow builds an unsigned `Pico.zip`, stamps the tag into the app’s version, and attaches it to a GitHub release.

- **Pre-release or stable:** a tag with a hyphen (`v1.0.0-rc2`, `v1.1.0-beta1`) is published as a pre-release; a plain tag (`v1.0.1`) is a stable release and becomes the latest.
- **Release notes** come from `CHANGELOG.md`: the `## [1.0.1]` section if you add one (the tag without the leading `v`), otherwise `## [Unreleased]`. If neither has content, GitHub’s generated notes are used. Before tagging a stable release, rename `[Unreleased]` to the version.
- If a release for the tag already exists (for example you created it in the GitHub UI), the workflow keeps its notes and only uploads `Pico.zip`.

The build is not signed or notarized, so on first launch users open **System Settings → Privacy & Security** and choose **Open Anyway**.

Always treat `project.yml` as the source of truth for the Xcode project. `Pico.xcodeproj` is generated and git-ignored; run `xcodegen generate` after pulling or after changing targets or sources.

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
