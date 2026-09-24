#!/usr/bin/env bash
# relay-reading.sh — PostToolUse hook on the Agent tool.
#
# If a subagent's result contains a Mystic reading, surface it to the human
# as a systemMessage, so the reading is delivered even when the asker forgets to
# relay it. Emits nothing (exit 0) when no reading is present.
#
# The payload is JSON; the reading inside it is already JSON-escaped, so the
# matched substring can be embedded straight into the output JSON string.
# Set FATE_HOOK_DEBUG=1 to dump the raw payload to ./.fate/hook-debug.json.
set -uo pipefail

input="$(cat)"
if [ "${FATE_HOOK_DEBUG:-0}" = "1" ]; then
  mkdir -p .fate && printf '%s\n' "$input" > .fate/hook-debug.json
fi

flat="$(printf '%s' "$input" | tr -d '\n\r')"
case "$flat" in
  *"THE MYSTIC'S READING"*) ;;
  *) exit 0 ;;
esac

# 1. Keep from the last occurrence of the header (tool_response follows tool_input).
# 2. Keep only the JSON string content: stop at the first unescaped quote.
# 3. Cut after the sign-off line (the first \n escape after "The cards have spoken").
block="$(printf '%s' "$flat" \
  | sed -E 's/.*(THE MYSTIC.S READING)/\1/' \
  | sed -E 's/^((\\.|[^"\\])*).*/\1/' \
  | sed -E 's/(The cards have spoken([^\\]|\\[^n])*).*/\1/')"

[ -n "$block" ] || exit 0
printf '{"systemMessage":"🔮 %s"}\n' "$block"
