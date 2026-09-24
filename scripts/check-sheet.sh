#!/usr/bin/env bash
# check-sheet.sh — validate a tarot cheat sheet's structure.
#
# Usage: check-sheet.sh [SHEET] [DECK]
#   SHEET defaults to ../cheat-sheet/tarot-cheat-sheet.md, DECK to ../data/deck.txt
# Checks:
#   - every card in DECK has exactly one "### <name>" heading (a "(…)" suffix is allowed)
#   - each card section has Upright, Reversed and Positions lines
#   - each Positions block names Situation:, Crossing: and Outcome:
#   - Part I has "How the Mystic speaks" and "The spread" headings
# Exit 0 when clean; otherwise list every problem and exit 1.
set -uo pipefail

SELF="$(printf '%s' "${BASH_SOURCE[0]}" | tr '\134' '/')"   # \134 is a backslash: tolerate Windows paths
HERE="$(cd "$(dirname "$SELF")" && pwd)"
SHEET="${1:-$HERE/../cheat-sheet/tarot-cheat-sheet.md}"
DECK="${2:-$HERE/../data/deck.txt}"

[ -r "$SHEET" ] || { echo "check-sheet.sh: sheet not found: $SHEET" >&2; exit 1; }
[ -r "$DECK" ]  || { echo "check-sheet.sh: deck not found: $DECK" >&2; exit 1; }

awk -v deckfile="$DECK" '
  BEGIN {
    while ((getline line < deckfile) > 0) if (line != "") { deck[++n] = line; want[line] = 1 }
    close(deckfile)
  }
  /^### How the Mystic speaks/ { voice = 1 }
  /^### The spread/            { spread = 1 }
  /^### / {
    name = substr($0, 5)
    sub(/ \(.*\)$/, "", name)            # strip "(XVI)"-style suffix
    if (name in want) { cur = name; seen[name]++ } else { cur = "" }
    next
  }
  /^## / { cur = "" }
  cur != "" {
    if ($0 ~ /^Upright/)   { up[cur] = 1 }
    if ($0 ~ /^Reversed/)  { rev[cur] = 1 }
    if ($0 ~ /^Positions/) { posl[cur] = 1 }
    if ($0 ~ /Situation:/) { sit[cur] = 1 }
    if ($0 ~ /Crossing:/)  { cro[cur] = 1 }
    if ($0 ~ /Outcome:/)   { out[cur] = 1 }
  }
  END {
    bad = 0
    for (i = 1; i <= n; i++) {
      c = deck[i]
      if (!(c in seen))   { print "MISSING heading:      " c; bad++; continue }
      if (seen[c] > 1)    { print "DUPLICATE heading:    " c " (" seen[c] "x)"; bad++ }
      if (!(c in up))     { print "MISSING Upright:      " c; bad++ }
      if (!(c in rev))    { print "MISSING Reversed:     " c; bad++ }
      if (!(c in posl))   { print "MISSING Positions:    " c; bad++ }
      if (!(c in sit))    { print "MISSING Situation:    " c; bad++ }
      if (!(c in cro))    { print "MISSING Crossing:     " c; bad++ }
      if (!(c in out))    { print "MISSING Outcome:      " c; bad++ }
    }
    if (!voice)  { print "MISSING section:      ### How the Mystic speaks"; bad++ }
    if (!spread) { print "MISSING section:      ### The spread"; bad++ }
    found = 0; for (c in seen) found++
    if (bad) { printf "check-sheet: %d problem(s); %d/%d cards present\n", bad, found, n; exit 1 }
    printf "check-sheet: OK — %d/%d cards, all orientations and positions present\n", found, n
  }
' "$SHEET"
