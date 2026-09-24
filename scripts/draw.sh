#!/usr/bin/env bash
# draw.sh — draw three distinct tarot cards, each upright or reversed.
#
# Usage:  draw.sh [--seed N]
# Env:    REVERSAL_RATE  probability a card is reversed (default 0.33)
#         DECK_FILE      path to the deck list (default ../data/deck.txt)
#         FATE_SEED      default seed when --seed is not given (for tests)
# Output: exactly three lines, pipe-delimited:
#         1|Situation|<card>|<upright|reversed>
#         2|Crossing|<card>|<upright|reversed>
#         3|Outcome|<card>|<upright|reversed>
set -euo pipefail

SELF="$(printf '%s' "${BASH_SOURCE[0]}" | tr '\134' '/')"   # \134 is a backslash: tolerate Windows paths
HERE="$(cd "$(dirname "$SELF")" && pwd)"
DECK="${DECK_FILE:-$HERE/../data/deck.txt}"
RATE="${REVERSAL_RATE:-0.33}"
SEED="${FATE_SEED:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --seed)   SEED="${2:-}"; shift 2 ;;
    --seed=*) SEED="${1#--seed=}"; shift ;;
    -h|--help) sed -n '2,10p' "$SELF"; exit 0 ;;
    *) echo "draw.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ ! -r "$DECK" ]; then
  echo "draw.sh: deck not found at $DECK" >&2; exit 1
fi
if [ "$(grep -c . "$DECK")" -lt 3 ]; then
  echo "draw.sh: deck has fewer than 3 cards" >&2; exit 1
fi

# Seed from the OS unless the caller pinned one. awk's own srand() only has
# one-second resolution, which would repeat draws made in the same second.
if [ -z "$SEED" ]; then
  if [ -r /dev/urandom ]; then
    SEED="$(od -An -N4 -tu4 /dev/urandom | tr -d ' \n')"
  else
    SEED="$(( (RANDOM << 15 | RANDOM) ^ $$ ^ $(date +%s) ))"
  fi
fi

awk -v seed="$SEED" -v rate="$RATE" '
  BEGIN { srand(seed + 0) }
  NF { deck[++n] = $0 }
  END {
    if (n < 3) { print "draw.sh: deck has fewer than 3 cards" > "/dev/stderr"; exit 1 }
    # Fisher-Yates shuffle, then take the top three.
    for (i = n; i > 1; i--) { j = int(rand() * i) + 1; t = deck[i]; deck[i] = deck[j]; deck[j] = t }
    split("Situation Crossing Outcome", pos, " ")
    for (k = 1; k <= 3; k++) {
      o = (rand() < rate + 0) ? "reversed" : "upright"
      printf "%d|%s|%s|%s\n", k, pos[k], deck[k], o
    }
  }
' "$DECK"
