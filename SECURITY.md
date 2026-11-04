# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| `main` (1.x) | Yes |

## What Pico can access

Pico is a privileged macOS accessory. With user consent it may:

- Register **global hotkeys**
- Use **Accessibility** to read/replace selection and drive UI
- Use **Screen Recording** when the user asks it to look at the display
- Synthesize keyboard events for paste / UI automation

App Sandbox is intentionally **off** for these capabilities; the Hardened Runtime is **on**.

On-screen text is treated as untrusted: the model cannot press quit/close/delete-style shortcuts or type into secure fields, and screen tools only turn on when the user asks (and expire after 5 idle minutes). Treat that as a security-sensitive design choice when reviewing changes.

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
