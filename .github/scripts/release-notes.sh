#!/usr/bin/env bash
# Prints release notes for a tag, taken from CHANGELOG.md.
#
# Usage: release-notes.sh <tag> [changelog]     e.g. release-notes.sh v1.0.0-rc2
#
# Looks for a "## [1.0.0-rc2]" section first (the tag without its leading "v"), then falls back
# to "## [Unreleased]". Prints nothing (and exits 0) when neither has any content, so the
# caller can fall back to GitHub's generated notes.
set -euo pipefail

tag="${1:?usage: release-notes.sh <tag> [changelog]}"
changelog="${2:-CHANGELOG.md}"
version="${tag#v}"

extract() {
  awk -v heading="## [$1]" '
    /^## \[/ {
      if (found) exit
      if (index($0, heading) == 1) { found = 1; next }
    }
    found { print }
  ' "$changelog"
}

# Trim leading and trailing blank lines (plain awk so it behaves the same with BSD and GNU tools).
trim() {
  awk '
    NF { started = 1 }
    started { lines[++count] = $0 }
    END {
      while (count > 0 && lines[count] !~ /[^[:space:]]/) count--
      for (i = 1; i <= count; i++) print lines[i]
    }
  '
}

notes="$(extract "$version" | trim)"
if [ -z "$notes" ]; then
  notes="$(extract "Unreleased" | trim)"
fi
printf '%s' "$notes"
