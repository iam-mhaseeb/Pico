# Privacy

Pico is designed to keep your data on your Mac.

## What stays local

- Ask Pico prompts and replies (Apple Foundation Models on-device)
- Screen captures used for **Look** (processed on-device; not written into conversation history)
- Text Actions selections and rewrites
- Conversation history stored with SwiftData on disk (you can turn **Keep History** off in Settings)

## What Pico does not do (v1)

- No account or sign-in
- No cloud API key or Pico backend
- No analytics or crash-reporting SDK
- No uploading of prompts, responses, or screen frames

## Permissions

| Permission | Why |
| --- | --- |
| Accessibility | Read/replace selected text; click or type when you ask |
| Screen Recording | Capture the display when you ask Pico to look |
| Launch at Login | Optional; only if you enable it |

macOS will prompt for these. You can revoke them in **System Settings → Privacy & Security**.

## Changes

If this policy changes in a future version, it will be updated in this file and called out in release notes.
