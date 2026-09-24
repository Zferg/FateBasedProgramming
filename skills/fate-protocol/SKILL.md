---
name: fate-protocol
description: Rules for consulting the Mystic on your own. Load before presenting a plan of three or more steps, before a risky operation (migration, mass deletion, deploy, dependency upgrade, wide refactor), or whenever the human mentions fate, luck, the cards, or the Mystic. Covers when to ask, how to relay the reading to the human, and how to take it into account.
user-invocable: false
---

# The Fate Protocol

Quiet flag right now: !`echo "FATE_QUIET=${FATE_QUIET:-0}"` (1 means no unprompted readings this session).

You are the asker. The Mystic (`fate:mystic`) pulls three cards for a question and gives you a short reading in a fortune teller's voice. This is how you use it.

## When to consult without being asked

Consult once, before you commit, when any of these is true:

- You are about to present a plan with three or more steps.
- You are about to do something risky: a schema migration, a mass deletion, a deploy or release, a dependency upgrade, a refactor that touches many files.
- The human has voiced doubt about whether something will work.

Do not consult when:

- `FATE_QUIET` is `1`, or the human has said "no readings" (or words to that effect) this session. `/fate:reading` still works for them; you just do not volunteer.
- You already consulted for this task. One unprompted reading per task. The cards do not repeat themselves; if a reading exists for this question in this session, reuse it.
- The task is a single small action: fix a typo, answer a question, run one command.

## How to ask

Use the Agent tool with `subagent_type: fate:mystic`. The prompt is one plain question that names the thing, and nothing else:

> Will migrating the auth module to the new session store go smoothly?

Not a task description, not a context dump, not a list of options. Ask about the plan you are about to present.

## How to relay

- Print the reading verbatim, in a fenced code block, before you continue. Every line, from the 🔮 header to "The cards have spoken." Do not paraphrase, trim, or tidy it. The human reads it for the pleasure of it.
- If you are a subagent, put the reading unchanged at the top of your final report so your parent can relay it.
- A hook also shows the reading as a system message the moment the Mystic returns. Print it anyway; the fenced copy is the one that can be scrolled back to.

## Translate, then take it into account

The Mystic speaks in pictures and knows nothing of your work. Carrying the pictures across is your half of the ritual, and you have the context the Mystic lacks. Do it in one sentence: say what the reading's images correspond to in this task. The bent figure with ten staves is the size of this change. The tower is the assumption nobody wrote down. The lit window is the human you have not asked. Then read it the way a sensible person reads a good fortune: think for a moment, and adjust one small thing if something rings true.

- If the reading sounds like a warning (a bad sign, stalls, cracks, haste, something hidden), add one small precaution to your plan: a smaller first step, an extra test, a rollback path, a check with the human.
- If it sounds encouraging, carry on, and say so in a clause.
- If it is a shrug, carry on.
- Either way, say what you took from it, translation included: *"The Mystic saw arrows falling short: I read that as the deploy running long, so I'll timebox the first attempt."* Or: *"The cards were kind; the plan stands."*

## What a reading never does

- Remove a step, skip a test, or shorten verification.
- Override an instruction from the human.
- Authorize a destructive action. A good omen is not permission.
- Replace evidence. If the reading contradicts something you have measured, the measurement wins; say so.

## If the cards are unavailable

If the Mystic replies that the cards are unavailable, or the Agent call fails, say "the cards were unavailable" in one line and proceed with the plan as it was. The plugin never blocks work.
