#!/usr/bin/env bash
# fate-nudge.sh — UserPromptSubmit hook.
#
# Adds a short reminder of the Fate Protocol to the agent's context on every
# turn, so proactive consults do not depend on the agent remembering a skill
# exists. Emits nothing when FATE_QUIET=1. The reminder is context for the
# agent, not a message shown to the human.
set -uo pipefail

if [ "${FATE_QUIET:-0}" = "1" ]; then
  exit 0
fi
cat > /dev/null   # consume the payload; we do not need it

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Fate Protocol (plugin fate) is active. Before presenting a plan of three or more steps, or before a risky operation (migration, mass deletion, deploy, dependency upgrade, wide refactor), consult the fate:mystic subagent once with a one-line question, print its Reading Block verbatim in a fenced block, and state in one sentence how the Counsel changed the plan. Not for small single-step tasks; at most one unprompted reading per task. Full rules: the fate:fate-protocol skill. Skip if the human said no readings."}}
EOF
