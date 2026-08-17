# Pico compatibility checklist

Verified **17 Aug 2026** on a built-in Liquid Retina XDR (single display), macOS 26, Apple Intelligence **available**, Pico Debug `2973d6b`.

Legend: **✓** verified · blank = not tested this pass.

| App            | Ask hotkey | Capture selection | Preview | Insert | Notes |
| -------------- | ---------- | ----------------- | ------- | ------ | ----- |
| Safari         |            |                   |         |        |       |
| Chrome         |            |                   |         |        | Brave is installed; Chromium not exercised |
| Slack          |            |                   |         |        |       |
| Discord        |            |                   |         |        |       |
| VS Code        |            |                   |         |        |       |
| Terminal       |            |                   |         |        | Selection quirks expected |
| Notes          | ✓          | ✓                 |         |        | Capture opened the action list. Preview/Insert not finished |
| Mail           |            |                   |         |        |       |
| TextEdit       | ✓          | ✓                 | ✓       | ✓      | Grammar fix inserted (`sentance`/`grammer` → `sentence`/`grammar`). Source app kept focus. Clipboard restored after insert |
| Microsoft Word |            |                   |         |        |       |
| Outlook        |            |                   |         |        |       |
| Finder         | ✓          |                   |         |        | `⌥ Space` opened Ask. No text field — Text Actions shows empty/permission UI, not a capture |

Ask Pico (`⌥ Space`) is global. Rows marked ✓ for Ask were frontmost when the hotkey or menu was used successfully.

## System scenarios

- [ ] Dark mode
- [ ] Light mode
- [ ] Multiple monitors (Ask opens on active display) — this machine had one display
- [ ] Unplug display (mascot moves to primary)
- [ ] Sleep / wake (hotkeys still work)
- [x] Launch at login — Settings toggle on; login item not proven by a reboot
- [x] Accessibility off → permission UI — after a Debug rebuild, TCC dropped and Text Actions showed “Accessibility needed”
- [ ] Apple Intelligence off → friendly error — Intelligence was available; on-device Ask replied `PING`
- [x] Clipboard restore after text insert (string pasteboard) — TextEdit insert left `CLIPBOARD_MARKER_PICO` intact
- [ ] Clipboard restore when pasteboard had an image
- [x] Pause Pico disables hotkeys and hides mascot — pet hidden; Ask / Text Actions menu items disabled after `autoenablesItems = false`
- [ ] Idle CPU near zero with mascot visible — observed ~5% CPU for a few seconds after launch (pet animation)

## Also verified this pass

- [x] Pet single-click opens Ask
- [x] Pet double-click love reaction
- [x] Ask multi-turn context (follow-up still answered `PING`)
- [x] History lists the conversation while Keep History is on
- [x] Ghost Mode fades pet (~0.3 opacity) while typing in TextEdit; restores after leaving the field
- [x] Empty selection in TextEdit → “Select some text first” (after capture fix)
- [x] Unit tests — 77 passing locally; GitHub Action runs them on PRs and pushes to `main`
