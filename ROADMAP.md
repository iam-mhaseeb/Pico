# Pico Pet Interactivity Roadmap

Inspired by [Arcrawls](https://arcrawls.com/) pet interactivity, adapted for Pico (native macOS desk buddy + Ask Pico + Text Actions).

**Label policy:** only `p0` (highest), `p1` (medium), `p3` (low). No other labels.

---

## North star

Make Pico feel *alive* on the desktop the way Arcrawls feels alive in the browser: springy motion, direct play gestures, idle autonomy, and reactions that respect focus — without becoming Clippy.

Current baseline (v1): mascot with `idle` / `listening` / `thinking` / `success` / `error`, drag placement, Ask Pico, Text Actions, on-device Apple Intelligence.

---

## Phases

### Phase 0 — Interaction foundation (`p0`)
Ship the play loop people notice in the first 30 seconds.

| # | Ticket theme | Why first |
|---|---|---|
| 1 | Gesture triad: pet / feed / shoo | Core Arcrawls delight |
| 2 | Speech bubbles | Makes the pet “talk” |
| 3 | Hover acknowledge + squash/stretch | Instant tactile feedback |
| 4 | Spring drag & edge snap | Physics presence |
| 5 | Expand pet emotion/state set | Unlocks later reactions |

### Phase 1 — Alive when idle (`p0` → `p1`)
Pet stays interesting without constant clicks.

| # | Ticket theme |
|---|---|
| 6 | Idle hobby animations (>45s) |
| 7 | Deep-idle sleep (>5 min) |
| 8 | Cursor / pointer curiosity chase |
| 9 | Screen-edge crawl / bounce locomotion |

### Phase 2 — Anti-annoyance modes (`p0`)
Protect productivity so the pet can stay enabled.

| # | Ticket theme |
|---|---|
| 10 | Ghost Mode (fade while typing / focused work) |
| 11 | Focus Blocks (quiet schedule windows) |
| 12 | Hide on this Space / Display / forever pause polish |
| 13 | Performance Mode (cap FPS, simplify shaders) |

### Phase 3 — Context reactions (`p1`)
React to Mac context, not browser DOM.

| # | Ticket theme |
|---|---|
| 14 | Frontmost-app mood map (Xcode, Slack, Safari, Music, etc.) |
| 15 | Time-of-day routines (night sleep, morning stretch) |
| 16 | Seasonal / holiday outfits |
| 17 | AI session mirroring (Ask/Text Actions → pet mood) |
| 18 | Error-aware consoling (AI failure / permission denied) |

### Phase 4 — Toys & play objects (`p1`)
| # | Ticket theme |
|---|---|
| 19 | Droppable toys (ball, yarn, laser, etc.) with chase queue |
| 20 | Toy physics on desktop layer |

### Phase 5 — Care loop / light gamification (`p1` → `p3`)
Optional Tamagotchi layer; keep opt-in and light.

| # | Ticket theme |
|---|---|
| 21 | Stats: Happiness / Energy / Curiosity (local only) |
| 22 | XP + level unlocks for emotes / outfits |
| 23 | Adaptive “trait” from usage (Builder / Chatter / Scholar) |
| 24 | Wardrobe / color / aura cosmetics |

### Phase 6 — Chat surface on the pet (`p1`)
| # | Ticket theme |
|---|---|
| 25 | Click pet → Ask Pico (or mini chat bubble) |
| 26 | Persona / vibe presets for pet dialogue |
| 27 | Ambient one-liners from local AI (rate-limited) |

### Phase 7 — Polish & platform (`p3`)
| # | Ticket theme |
|---|---|
| 28 | Sound board (opt-in, tiny set) |
| 29 | Multi-display crawl continuity |
| 30 | Accessibility: Reduce Motion + VoiceOver for new gestures |
| 31 | Onboarding tips for pet gestures |
| 32 | Analytics-free local “milestones” log (optional) |

---

## Explicit non-goals (for now)

- Cloud LLM for page/desktop content
- Browser extension port (Pico stays native macOS)
- Copying Arcrawls assets/code (PolyForm Noncommercial); patterns only
- Heavy gamification that guilt-trips users

---

## Suggested ship order (MVP cut)

1. Gestures + bubbles + hover (`p0`)
2. Spring drag / edge snap (`p0`)
3. Ghost Mode (`p0`)
4. Idle hobbies + sleep (`p0`/`p1`)
5. App-context moods + AI mirroring (`p1`)
6. Toys (`p1`)
7. Stats/XP only if care-loop demand is clear (`p1`/`p3`)

---

## Issue creation

Issues are opened from `scripts/create-pico-roadmap-issues.sh` once the GitHub token has **Issues: write**. That script also enforces the label policy (only `p0` / `p1` / `p3`).
