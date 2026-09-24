#!/usr/bin/env bash
# find-sheet.sh — print the path of the cheat sheet the Mystic should read.
#
# Lookup order (first hit wins):
#   1. ./.fate/tarot-cheat-sheet.md                per-project override / Forge output
#   2. <plugin>/cheat-sheet/tarot-cheat-sheet.md   the shipped, forged sheet
#   3. <plugin>/data/seed-cheat-sheet.md           the seed (announced in the reading)
# Output: "<tier>|<path>" where tier is project, shipped, or seed. Exit 1 if none found.
set -euo pipefail

SELF="$(printf '%s' "${BASH_SOURCE[0]}" | tr '\134' '/')"   # \134 is a backslash: tolerate Windows paths
HERE="$(cd "$(dirname "$SELF")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

try() { if [ -r "$2" ]; then printf '%s|%s\n' "$1" "$2"; exit 0; fi; }
try project "./.fate/tarot-cheat-sheet.md"
try shipped "$ROOT/cheat-sheet/tarot-cheat-sheet.md"
try seed    "$ROOT/data/seed-cheat-sheet.md"
echo "find-sheet.sh: no cheat sheet found" >&2
exit 1
