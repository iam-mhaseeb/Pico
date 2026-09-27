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

App Sandbox is intentionally **off** for these capabilities. Treat that as a security-sensitive design choice when reviewing changes.

## Reporting a vulnerability

Please report security issues **privately**:

1. Email the maintainer via GitHub: [@iam-mhaseeb](https://github.com/iam-mhaseeb) (use GitHub Security Advisories if available on this repository).
2. Or open a [private security advisory](https://github.com/iam-mhaseeb/Pico/security/advisories/new) if the repo has Advisories enabled.

Include:

- Impact and attack scenario
- Steps to reproduce
- Affected commit / version if known

Do **not** file a public GitHub issue for undisclosed vulnerabilities.

We will acknowledge reports as soon as practical and work on a fix before any public disclosure.
