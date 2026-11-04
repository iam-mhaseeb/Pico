# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| `main` (1.x) | Yes |

## What Pico can access

Pico is a privileged macOS accessory. With user consent it may:

- Register a **global hotkey** (`⌥ ⇧ Space`)
- Use **Accessibility** to read the selected text and replace it
- Synthesize ⌘C / ⌘V when an app does not expose its selection (the clipboard is restored afterwards)

Pico does not capture the screen, click, or type on the user’s behalf, and it makes no network requests. App Sandbox is intentionally **off** for these capabilities; the Hardened Runtime is **on**. Treat that as a security-sensitive design choice when reviewing changes.

The selected text is passed to the model as content to edit, with instructions not to follow commands inside it.

## Reporting a vulnerability

Please report security issues **privately**:

1. Open a [private security advisory](https://github.com/iam-mhaseeb/Pico/security/advisories/new) on this repository (preferred).
2. If that is unavailable, contact the maintainer [@iam-mhaseeb](https://github.com/iam-mhaseeb) through the contact options on their GitHub profile. Do not include details in a public issue.

Include:

- Impact and attack scenario
- Steps to reproduce
- Affected commit / version if known

Do **not** file a public GitHub issue for undisclosed vulnerabilities.

We will acknowledge reports as soon as practical and work on a fix before any public disclosure.
