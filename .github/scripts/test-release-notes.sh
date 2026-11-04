#!/usr/bin/env bash
# Tests release-notes.sh. Runs in CI on macOS (BSD sed/awk) and works locally too.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/release-notes.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

check() { # name expected actual
  if [ "$2" = "$3" ]; then echo "ok   - $1"; else echo "FAIL - $1"; echo "  expected: [$2]"; echo "  actual:   [$3]"; fail=1; fi
}

cat > "$tmp/CHANGELOG.md" <<'MD'
# Changelog

## [Unreleased]

### Added

- upcoming thing

## [1.0.1] - 2026-12-01

### Fixed

- the 1.0.1 fix

## [1.0.0] - 2026-08

- first release
MD

check "version section wins" $'### Fixed\n\n- the 1.0.1 fix' "$("$script" v1.0.1 "$tmp/CHANGELOG.md")"
check "last section" "- first release" "$("$script" v1.0.0 "$tmp/CHANGELOG.md")"
check "rc tag falls back to Unreleased" $'### Added\n\n- upcoming thing' "$("$script" v1.0.2-rc1 "$tmp/CHANGELOG.md")"
check "unknown tag falls back to Unreleased" $'### Added\n\n- upcoming thing' "$("$script" v9.9.9 "$tmp/CHANGELOG.md")"

printf '# Changelog\n\n## [0.1.0]\n\n- old\n' > "$tmp/nounreleased.md"
check "no section and no Unreleased is empty" "" "$("$script" v2.0.0 "$tmp/nounreleased.md")"

printf '# Changelog\n\n## [Unreleased]\n\n\n## [0.1.0]\n\n- old\n' > "$tmp/emptyunreleased.md"
check "empty Unreleased is empty" "" "$("$script" v2.0.0 "$tmp/emptyunreleased.md")"

# The real changelog must produce notes for an rc tag.
real="$("$script" v1.0.0-rc2 "$here/../../CHANGELOG.md")"
[ -n "$real" ] && echo "ok   - real CHANGELOG yields notes" || { echo "FAIL - real CHANGELOG yields no notes"; fail=1; }

exit "$fail"
