#!/usr/bin/env bash
# log-reading.sh — append a Reading Block (from stdin) to ./.fate/readings.md.
#
# Usage:  bash log-reading.sh <<'READING'
#         🔮 THE MYSTIC'S READING
#         Question: ...
#         ...
#         READING
# Env:    FATE_LOG  override the log path (default ./.fate/readings.md)
# The heading is "## <UTC timestamp> — <question>", with the question taken from
# the block's "Question:" line. Exit 0 on success, 1 if stdin was empty.
set -euo pipefail

LOG="${FATE_LOG:-./.fate/readings.md}"
block="$(cat)"
[ -n "$block" ] || { echo "log-reading.sh: nothing on stdin" >&2; exit 1; }

question="$(printf '%s\n' "$block" | grep -m1 '^Question: ' | sed 's/^Question: //' || true)"
stamp="$(date -u +%Y-%m-%dT%H:%MZ)"

mkdir -p "$(dirname "$LOG")"
{
  printf '## %s — %s\n\n' "$stamp" "${question:-untitled reading}"
  printf '%s\n\n' "$block"
} >> "$LOG"
echo "logged to $LOG"
