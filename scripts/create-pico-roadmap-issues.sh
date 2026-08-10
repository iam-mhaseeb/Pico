#!/usr/bin/env bash
# Create Pico pet-roadmap GitHub labels + issues.
# Label policy: ONLY p0 / p1 / p3. Deletes every other label.
#
# Auth (first match wins):
#   1) GITHUB_ISSUES_TOKEN
#   2) GH_TOKEN / GITHUB_TOKEN
#   3) gh auth token
#
# Usage:
#   ./scripts/create-pico-roadmap-issues.sh
#   DRY_RUN=1 ./scripts/create-pico-roadmap-issues.sh

set -euo pipefail

REPO="${REPO:-iam-mhaseeb/Pico}"
API="https://api.github.com/repos/${REPO}"
DRY_RUN="${DRY_RUN:-0}"

resolve_token() {
  if [[ -n "${GITHUB_ISSUES_TOKEN:-}" ]]; then
    echo "$GITHUB_ISSUES_TOKEN"
  elif [[ -n "${GH_TOKEN:-}" ]]; then
    echo "$GH_TOKEN"
  elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo "$GITHUB_TOKEN"
  elif command -v gh >/dev/null 2>&1; then
    gh auth token 2>/dev/null || true
  fi
}

TOKEN="$(resolve_token)"
if [[ -z "$TOKEN" ]]; then
  echo "error: no GitHub token found (set GITHUB_ISSUES_TOKEN)" >&2
  exit 1
fi

auth_hdr=(-H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")

api_code() {
  local method="$1"; shift
  local path="$1"; shift
  curl -sS -o /tmp/pico-gh-body.json -w "%{http_code}" -X "$method" "${auth_hdr[@]}" "${API}${path}" "$@"
}

echo "==> Checking Issues permission on ${REPO}"
code="$(api_code GET /issues)"
if [[ "$code" == "403" ]]; then
  echo "error: token cannot access Issues (HTTP 403). Grant Issues: Read and write to the GitHub App / PAT, then re-run." >&2
  cat /tmp/pico-gh-body.json >&2 || true
  exit 1
fi
if [[ "$code" != "200" ]]; then
  echo "error: unexpected HTTP ${code} listing issues" >&2
  cat /tmp/pico-gh-body.json >&2 || true
  exit 1
fi

export TOKEN REPO DRY_RUN

echo "==> Enforcing label policy (only p0 / p1 / p3)"
python3 - <<'PY'
import json, os, sys, urllib.parse, urllib.request

token = os.environ["TOKEN"]
repo = os.environ["REPO"]
dry = os.environ.get("DRY_RUN", "0") == "1"
api = f"https://api.github.com/repos/{repo}"
headers = {
    "Authorization": f"Bearer {token}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "pico-roadmap-script",
}
priority = {
    "p0": ("b60205", "Highest priority"),
    "p1": ("fbca04", "Medium priority"),
    "p3": ("0e8a16", "Low priority"),
}

def req(method, url, data=None):
    body = None if data is None else json.dumps(data).encode()
    r = urllib.request.Request(url, data=body, headers=headers, method=method)
    if body is not None:
        r.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(r) as resp:
            raw = resp.read().decode() or "null"
            return resp.status, json.loads(raw) if raw != "null" else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            parsed = json.loads(raw) if raw else None
        except Exception:
            parsed = raw
        return e.code, parsed

# collect labels
labels = []
page = 1
while True:
    status, data = req("GET", f"{api}/labels?per_page=100&page={page}")
    if status != 200:
        print(f"error listing labels: {status} {data}", file=sys.stderr)
        sys.exit(1)
    if not data:
        break
    labels.extend(data)
    if len(data) < 100:
        break
    page += 1

for lab in labels:
    name = lab["name"]
    if name in priority:
        continue
    print(f"  delete label: {name}")
    if dry:
        continue
    enc = urllib.parse.quote(name)
    status, data = req("DELETE", f"{api}/labels/{enc}")
    if status not in (204, 404):
        print(f"  warn: failed to delete {name}: {status} {data}", file=sys.stderr)

existing = {lab["name"] for lab in labels}
for name, (color, desc) in priority.items():
    payload = {"name": name, "color": color, "description": desc}
    if name in existing:
        print(f"  update label: {name}")
        if dry:
            continue
        status, data = req("PATCH", f"{api}/labels/{urllib.parse.quote(name)}", {
            "new_name": name,
            "color": color,
            "description": desc,
        })
        if status not in (200,):
            print(f"  error updating {name}: {status} {data}", file=sys.stderr)
            sys.exit(1)
    else:
        print(f"  create label: {name}")
        if dry:
            continue
        status, data = req("POST", f"{api}/labels", payload)
        if status not in (201,):
            print(f"  error creating {name}: {status} {data}", file=sys.stderr)
            sys.exit(1)

print("labels ok")
PY

echo "==> Creating roadmap issues"
TOKEN="$TOKEN" REPO="$REPO" DRY_RUN="$DRY_RUN" python3 - <<'PY'
import json, os, sys, urllib.parse, urllib.request, textwrap

token = os.environ["TOKEN"]
repo = os.environ["REPO"]
dry = os.environ.get("DRY_RUN", "0") == "1"
api = f"https://api.github.com/repos/{repo}"
headers = {
    "Authorization": f"Bearer {token}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "pico-roadmap-script",
}

def req(method, url, data=None):
    body = None if data is None else json.dumps(data).encode()
    r = urllib.request.Request(url, data=body, headers=headers, method=method)
    if body is not None:
        r.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(r) as resp:
            raw = resp.read().decode() or "null"
            return resp.status, json.loads(raw) if raw != "null" else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            parsed = json.loads(raw) if raw else None
        except Exception:
            parsed = raw
        return e.code, parsed

def open_issue_exists(title: str) -> str | None:
    q = urllib.parse.quote(f'repo:{repo} is:issue is:open in:title "{title}"')
    status, data = req("GET", f"https://api.github.com/search/issues?q={q}")
    if status != 200:
        return None
    for item in data.get("items", []):
        if item.get("title") == title:
            return item.get("html_url")
    return None

def create_issue(title: str, label: str, body: str):
    existing = open_issue_exists(title)
    if existing:
        print(f"  skip (exists): {title} -> {existing}")
        return
    print(f"  create [{label}]: {title}")
    if dry:
        return
    status, data = req("POST", f"{api}/issues", {
        "title": title,
        "labels": [label],
        "body": textwrap.dedent(body).strip() + "\n",
    })
    if status != 201:
        print(f"  error creating issue: {status} {data}", file=sys.stderr)
        sys.exit(1)
    print(f"   -> {data['html_url']}")

ISSUES = [
  ("p0", "[Pet] Gesture triad: pet / feed / shoo", """
    ## Summary
    Add Arcrawls-style direct play gestures on the desktop mascot.

    ## Acceptance criteria
    - [ ] Single-click (or defined pet gesture) triggers a happy / love reaction
    - [ ] Double-click feeds Pico with celebrate animation + short speech bubble
    - [ ] Right-click (or secondary click) shoos Pico; pet dashes / hops to another spot
    - [ ] Gestures do not conflict with drag-to-reposition
    - [ ] Reduce Motion: still works with simpler feedback
    - [ ] Document gestures in onboarding or Settings help

    ## Notes
    Highest-impact interactivity borrowed from Arcrawls. Foundation for toys/XP later.
  """),
  ("p0", "[Pet] Speech bubbles for reactions", """
    ## Summary
    Show short, non-blocking speech bubbles above Pico for greetings and reactions.

    ## Acceptance criteria
    - [ ] Bubbles for feed / shoo / pet / greeting
    - [ ] Auto-dismiss after a short TTL; never steal keyboard focus
    - [ ] Positioned relative to pet; flip when near screen edges
    - [ ] Text is local / hardcoded for MVP (AI ambient lines come later)
    - [ ] Accessible: VoiceOver announces bubble text when shown

    ## Notes
    Makes the pet feel conversational without opening Ask Pico every time.
  """),
  ("p0", "[Pet] Hover acknowledge + squash/stretch", """
    ## Summary
    When the cursor hovers Pico, acknowledge with scale / squash-stretch, then spring back.

    ## Acceptance criteria
    - [ ] Hover scales/rotates slightly; leave restores with spring easing
    - [ ] Respects Reduce Motion (opacity or static highlight only)
    - [ ] Does not trigger while dragging
    - [ ] Feels responsive (<1 frame of lag on target Macs)

    ## Notes
    Small polish that sells “alive” immediately.
  """),
  ("p0", "[Pet] Spring physics drag and edge snap", """
    ## Summary
    Upgrade drag placement to springy motion with intelligent edge snapping (inspired by Arcrawls floor/ceiling snap, adapted to macOS displays).

    ## Acceptance criteria
    - [ ] Drag follows pointer smoothly
    - [ ] On release, spring toward nearest sensible edge or stay free (setting)
    - [ ] Multi-display: snap stays on the display where released
    - [ ] No jitter / fighting with Mission Control
    - [ ] Existing persistence of pet position still works

    ## Notes
    Core “presence” of Arcrawls physics, desktop-native.
  """),
  ("p0", "[Pet] Expand emotion and animation state set", """
    ## Summary
    Grow beyond idle / listening / thinking / success / error so gestures and context have something to play.

    ## Acceptance criteria
    - [ ] Add at least: love, celebrating, sad/shoo, sleeping, curious, working
    - [ ] Shared state machine used by PetView + PetPanelController
    - [ ] Ask Pico / Text Actions still drive listening/thinking/success/error
    - [ ] Animation metrics for new states (or sensible fallbacks)
    - [ ] Unit or snapshot coverage for state transitions where practical

    ## Notes
    Unblocks idle hobbies, context moods, and care-loop visuals.
  """),
  ("p0", "[Pet] Ghost Mode while typing or focused work", """
    ## Summary
    Fade Pico (e.g. ~30% opacity) while the user is actively typing or in a focus window so the pet never blocks work.

    ## Acceptance criteria
    - [ ] Detect active typing / text-field focus via Accessibility where permitted
    - [ ] Opacity fades down during activity; restores after idle short delay
    - [ ] Toggle in Settings (default documented in PR)
    - [ ] Does not break Text Actions / Ask Pico hotkeys
    - [ ] Clear Settings copy explaining Ghost Mode vs Pause

    ## Notes
    Arcrawls Ghost Mode equivalent — critical so interactivity stays welcome.
  """),
  ("p1", "[Pet] Idle hobby animations after short inactivity", """
    ## Summary
    After ~45s without interaction, Pico picks a random light hobby animation.

    ## Acceptance criteria
    - [ ] Idle timer resets on pet interaction, Ask Pico, Text Actions, drag
    - [ ] At least 5 hobby variants (even if simple at first)
    - [ ] Suppressed during Ghost/Focus/Pause
    - [ ] Does not spike CPU (pause timers on Performance Mode)

    ## Notes
    Arcrawls idle pool pattern; keep asset cost low for v1.
  """),
  ("p1", "[Pet] Deep-idle sleep after prolonged inactivity", """
    ## Summary
    After ~5 minutes idle, Pico sleeps; wake on pointer proximity or interaction.

    ## Acceptance criteria
    - [ ] Sleep state + optional bubble
    - [ ] Wake on hover / click / Ask Pico / Text Actions
    - [ ] Animation loop can pause while sleeping to save CPU
    - [ ] Compatible with night schedule (later ticket)

    ## Notes
    Pairs with idle hobbies; sleep is the long-idle end state.
  """),
  ("p1", "[Pet] Cursor curiosity chase", """
    ## Summary
    Occasionally, when idle, Pico wanders toward the pointer and peeks with a short line.

    ## Acceptance criteria
    - [ ] Low probability, rate-limited (not constant chasing)
    - [ ] Disabled in Ghost/Focus/Pause
    - [ ] Optional Settings toggle
    - [ ] Speech bubble lines are short and local

    ## Notes
    High delight, easy to make annoying — defaults must be gentle.
  """),
  ("p1", "[Pet] Screen-edge crawl / bounce locomotion", """
    ## Summary
    Let Pico optionally crawl or bounce along screen edges instead of only sitting still.

    ## Acceptance criteria
    - [ ] Optional autonomous locomotion along bottom (and maybe top) edge
    - [ ] Spring easing; avoids menu bar / Dock collision
    - [ ] Multi-monitor aware
    - [ ] Toggle: Stay put / Wander
    - [ ] Stops during Ghost fade / Focus / user drag

    ## Notes
    Desktop analog of Arcrawls viewport crawling.
  """),
  ("p1", "[Pet] Focus Blocks quiet schedule", """
    ## Summary
    Time windows where Pico stays visible but quiet (no autonomous toys/speech/chase).

    ## Acceptance criteria
    - [ ] Settings UI to define one or more daily Focus Blocks
    - [ ] During block: mute sounds, suppress idle hobbies/chase, keep calm working pose
    - [ ] Distinct from Pause (hidden) and Ghost (opacity)
    - [ ] Survives relaunch (persisted)

    ## Notes
    Arcrawls Focus Blocks pattern for deep work.
  """),
  ("p1", "[Pet] Context moods from frontmost app", """
    ## Summary
    Map frontmost app bundle IDs to moods (e.g. Xcode → working, Music → groove, Slack → social).

    ## Acceptance criteria
    - [ ] Local rules table (no cloud)
    - [ ] User-editable overrides in Settings (app → mood)
    - [ ] Rate-limit mood flips
    - [ ] Falls back to idle when unknown
    - [ ] Privacy: only uses app identity, not window contents

    ## Notes
    Arcrawls site-category reactions → macOS app-category reactions.
  """),
  ("p1", "[Pet] Mirror Ask Pico and Text Actions in pet mood", """
    ## Summary
    Tighten coupling so listening/thinking/success/error (and new states) clearly reflect AI sessions.

    ## Acceptance criteria
    - [ ] Ask Pico open → listening; streaming → thinking; done → success; fail → error/sad
    - [ ] Text Actions preview → thinking/curious; insert success → celebrate
    - [ ] Bubbles optional one-liners on success/error
    - [ ] No regressions to hotkey latency

    ## Notes
    Pico’s unique advantage vs Arcrawls: the pet IS the AI surface.
  """),
  ("p1", "[Pet] Droppable toys with chase queue", """
    ## Summary
    From menu/settings, drop toys onto the desktop layer; Pico chases them in order.

    ## Acceptance criteria
    - [ ] At least 3 toys (ball, yarn, laser or equivalent)
    - [ ] Queue multiple toys; clear queue on shoo/drag
    - [ ] Toys respect display bounds
    - [ ] Disabled during Focus Blocks
    - [ ] Settings: enable toys / clear toys

    ## Notes
    Major Arcrawls play feature; ship after gesture triad.
  """),
  ("p1", "[Pet] Click pet to open Ask Pico mini chat", """
    ## Summary
    Primary click (when not dragging) opens Ask Pico or a pet-anchored mini chat.

    ## Acceptance criteria
    - [ ] Clear gesture disambiguation vs pet / drag
    - [ ] Panel anchors near pet when possible
    - [ ] Same AI provider / history as Ask Pico
    - [ ] Esc closes; focus returns sensibly
    - [ ] Documented in onboarding

    ## Notes
    Unifies companion + assistant the way Arcrawls chat rides the pet.
  """),
  ("p1", "[Pet] Local care stats (happiness / energy / curiosity)", """
    ## Summary
    Lightweight local-only stats that react to pet / feed / shoo and gentle decay.

    ## Acceptance criteria
    - [ ] 3 stats max for MVP; stored on-device only
    - [ ] Visible in Settings or a small status popover
    - [ ] Decay is slow; never punishes users harshly
    - [ ] Fully wipeable / disable-able
    - [ ] No network / analytics

    ## Notes
    Optional Tamagotchi layer — keep opt-out easy.
  """),
  ("p1", "[Pet] Persona presets for pet dialogue", """
    ## Summary
    Let users pick a dialogue vibe (Friendly, Encouraging, Snarky, etc.) for bubbles and Ask Pico tone when invoked from the pet.

    ## Acceptance criteria
    - [ ] ≥4 personas
    - [ ] Applies to bubble copy templates and optional system prompt flavor
    - [ ] Default Friendly
    - [ ] Settings picker

    ## Notes
    Inspired by Arcrawls AI personas; keep on-device.
  """),
  ("p3", "[Pet] Time-of-day routines (night sleep, morning stretch)", """
    ## Summary
    Calendar-aware daily routines for night sleep and morning stretch moods.

    ## Acceptance criteria
    - [ ] Configurable quiet hours
    - [ ] Default night window slows/sleeps pet
    - [ ] Morning stretch once per day
    - [ ] Respects Focus Blocks / Pause

    ## Notes
    Nice polish after core interactivity ships.
  """),
  ("p3", "[Pet] Seasonal and holiday outfits", """
    ## Summary
    Automatic seasonal cosmetics (winter scarf, spooky, celebration) with optional lock/unlock later.

    ## Acceptance criteria
    - [ ] At least 3 seasonal variants
    - [ ] Toggle auto-season in Settings
    - [ ] Does not break hit-testing / drag
    - [ ] Asset size stays reasonable

    ## Notes
    Low priority cosmetics.
  """),
  ("p3", "[Pet] XP and unlockable emotes / outfits", """
    ## Summary
    Earn XP from interactions; unlock extra emotes/outfits over time.

    ## Acceptance criteria
    - [ ] XP from pet/feed/toys only (not surveillance)
    - [ ] Clear unlock table
    - [ ] Level-up toast is dismissible and rare
    - [ ] Can reset progression
    - [ ] Entire system disableable

    ## Notes
    Only after care stats prove sticky; easy to over-scope.
  """),
  ("p3", "[Pet] Adaptive usage trait (Builder / Chatter / Scholar)", """
    ## Summary
    Derive a soft trait from how the user uses Pico (Ask vs Text Actions vs pet play) and tweak idle bias / speed.

    ## Acceptance criteria
    - [ ] Local counters only; no content logging
    - [ ] Trait badge in Settings
    - [ ] Subtle behavior bias only
    - [ ] Resettable

    ## Notes
    Arcrawls Developer/Gamer/Scholar idea, Pico-native.
  """),
  ("p3", "[Pet] Performance Mode for low-power Macs", """
    ## Summary
    Cap animation FPS, disable fancy effects, pause autonomy on battery if desired.

    ## Acceptance criteria
    - [ ] Settings toggle + optional “on battery” auto
    - [ ] Measurable CPU drop vs full mode
    - [ ] Still usable gestures

    ## Notes
    Parity with Arcrawls Performance Mode.
  """),
  ("p3", "[Pet] Opt-in sound board", """
    ## Summary
    Tiny set of soft SFX for greet / feed / shoo / level-up; default muted or very quiet.

    ## Acceptance criteria
    - [ ] Master volume + per-event mute
    - [ ] Respects macOS mute / Focus
    - [ ] No sound during Focus Blocks
    - [ ] Bundle size impact documented

    ## Notes
    Easy to annoy — ship last and default conservative.
  """),
  ("p3", "[Pet] Onboarding tips for pet gestures", """
    ## Summary
    First-run or tip card explaining pet / feed / shoo / drag / Ghost Mode.

    ## Acceptance criteria
    - [ ] Shown once; re-openable from Settings
    - [ ] Short (≤4 steps)
    - [ ] Matches final gesture mapping

    ## Notes
    Depends on p0 gesture tickets landing first.
  """),
  ("p3", "[Pet] Accessibility pass for new pet interactions", """
    ## Summary
    VoiceOver, keyboard alternatives, and Reduce Motion coverage for all new pet features.

    ## Acceptance criteria
    - [ ] Every gesture has an equivalent in Settings or menu
    - [ ] Reduce Motion paths verified
    - [ ] VoiceOver names/hints updated
    - [ ] Contrast of bubbles OK in light/dark

    ## Notes
    Should ideally be done alongside each p0 feature; this ticket tracks residual gaps.
  """),
]

for label, title, body in ISSUES:
    create_issue(title, label, body)

print("issues ok")
PY

echo "==> Done"
