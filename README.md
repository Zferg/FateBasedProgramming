# Fate Based Programming

A Claude Code plugin that adds a **Mystic**: a Sonnet subagent who pulls three tarot cards for whatever you or your agent are about to do and reads them the way the reader at the renaissance fair would: a few hedged, colorful sentences, a good sign or a bad one, and one thought to carry away. The human sees every reading. Nobody's tests get skipped because of a card.

Full design: [SPEC.md](SPEC.md).

## What this project exercises

The plugin is small on purpose. It was built as a hands-on tour of what a Claude Code plugin can be made of, and every piece below is a stock Claude Code feature with no MCP server, no network calls, and no dependencies beyond bash and coreutils:

- **Subagents** with their own model, tools, and voice (`agents/`): a reader, a reader-turned-editor, and two reviewers who argue with each other across rounds.
- **Skills**, both user-invoked (`/fate:reading`, `/fate:forge`) and model-invoked (the Fate Protocol, which the main agent loads on its own when it is about to plan or do something risky).
- **Hooks**: a `UserPromptSubmit` hook that keeps the protocol in the agent's context every turn, and a `PostToolUse` hook that guarantees the human sees a reading even if the agent that asked for it forgets to relay it.
- **Scripts as the source of truth** for anything a language model is bad at: real randomness for the draw, a structural validator for the cheat sheet, and a state machine that drives a multi-round, multi-agent review loop so the orchestrating agent only has to follow `NEXT:` lines.

## Requirements

- Claude Code with plugin support (`claude --plugin-dir`).
- bash and coreutils. On Windows this is Git Bash, which Claude Code already requires; the scripts tolerate Windows-style paths.

## Try it

```
git clone https://github.com/Zferg/FateBasedProgramming.git
claude --plugin-dir /path/to/FateBasedProgramming
```

Then, inside the session:

```
/fate:reading will this refactor go well?
```

The main agent spawns the Mystic, prints the reading, and (if it is mid-task) says what it took from it. A hook also surfaces the reading as a system message the moment the Mystic returns, so it reaches you even if the asker forgets to relay it.

```
🔮 THE MYSTIC'S READING
Question: Will this agent do its assigned spec step to a desirable outcome?
Cards: The Chariot · Strength (reversed) · Eight of Wands (reversed)

You ask whether the step before you will end well. The Chariot rides through your situation, and I like that: reins in hand, wheels already turning, a will that knows where it is going. But Strength lies reversed across your path, and, hm. The lion in this picture is not tamed, only held, and the hand that holds it is tired. There is force here where there should be patience. And at the end of the row, the Eight of Wands, reversed. Arrows that leave the bow and fall short in the grass. Delay, I think. Frustration. Not ruin, but not the clean landing the Chariot promised. If I were you I would ride a little slower than you want to, and let the lion come to you.

The cards have spoken.
```

The Mystic speaks in the cards' pictures and never in your trade. Working out that the tired hand on the lion is your rushed test plan is your half of the ritual; when an agent asked, the Fate Protocol makes it say its translation out loud.

## Consulting on its own

With the plugin loaded, the agent follows the **Fate Protocol**: before presenting a plan of three or more steps, or before a risky operation (migration, mass deletion, deploy, dependency upgrade, wide refactor), it asks the Mystic once, prints the reading, and says in one sentence what it took from it. A reading that sounds like a warning adds one small precaution to the plan; an encouraging one is noted and the plan stands. A reading never removes a step, skips a test, or authorizes anything destructive. If the cards are unavailable for any reason, the agent says so in one line and carries on; the plugin never blocks work.

To silence unprompted readings for a session:

```
FATE_QUIET=1 claude --plugin-dir /path/to/FateBasedProgramming
```

`/fate:reading` still works when quiet. Saying "no readings" to the agent has the same effect.

## Forging the cheat sheet

The Mystic reads only from `tarot-cheat-sheet.md`. The plugin ships one that was argued into shape by the Forge:

```
/fate:forge
```

Each round, the Mystic reads four sample questions against the current draft and notes which entries it leaned on and where the book let it down. Then two reviewers read the draft and the readings in parallel: the **Skeptic**, who does not believe in any of this but cannot resist it, judges whether the readings are fun and honest and whether the sheet keeps the Mystic sounding like a reader rather than a manual; the **Believer**, who fully intends to steer by it, judges whether every card in every position gives her something worth thinking about. Each files change requests marked `must` or `nice`. The Mystic applies them, records what was rejected and why, and the next round begins. It ends when both approve the same draft (zero `must` items), when the same dispute survives three rounds (the human rules), or at the round limit.

The shipped sheet is the imagery seed argued into shape under this brief on 2026-09-19; it converged in two rounds, and the argument is in `cheat-sheet/forge-log.md`. Re-forging writes to `.fate/tarot-cheat-sheet.md` (which overrides the shipped sheet for that project) with the whole argument under `.fate/forge/`. Options: `--rounds N` (default 8), `--per-round K` (default 4), `--out DIR`, `--from PATH`, `--fresh`. An interrupted run resumes where it stopped.

## How it fits together

1. A skill (or the Fate Protocol) spawns the `fate:mystic` subagent with a one-line question.
2. The Mystic runs `draw.sh` for three random cards and `find-sheet.sh` to locate the cheat sheet, reads the sheet, writes the reading, and logs it with `log-reading.sh`.
3. The `PostToolUse` hook sees the reading in the subagent's result and shows it to the human as a system message; the asker prints it again in a fenced block and, if mid-task, says what it took from it.

The Forge is the same Mystic plus two reviewers, driven by `forge.sh`, which keeps its state in `.fate/forge/state.json` so the orchestrating agent never has to hold the draft or the reviews in its own context.

## What is here

| Path | What it does |
|---|---|
| `.claude-plugin/plugin.json` | Manifest. Plugin name is `fate`, so commands are `/fate:…`. |
| `agents/mystic.md` | The Mystic. Sonnet, tools `Read` and `Bash`. |
| `agents/mystic-forge.md` | The Mystic at the Forge: sample readings with notes, revising a draft, repairing one. Same voice, write tools. |
| `agents/skeptic.md`, `agents/believer.md` | The two reviewers. Sonnet, tools `Read`, `Grep`, `Write`. |
| `skills/reading/SKILL.md` | `/fate:reading <question>`. |
| `skills/fate-protocol/SKILL.md` | The Fate Protocol: when to consult unprompted, how to relay, how to translate the pictures and take a reading into account. Model-invoked. |
| `skills/forge/SKILL.md` | `/fate:forge`: the orchestration loop. |
| `hooks/hooks.json`, `hooks/relay-reading.sh` | `PostToolUse` hook on the Agent tool that relays a reading to the human. |
| `hooks/fate-nudge.sh` | `UserPromptSubmit` hook that reminds the agent of the protocol each turn. Silent when `FATE_QUIET=1`. |
| `scripts/draw.sh` | Draws 3 distinct cards with real randomness. `--seed N` or `FATE_SEED` for reproducible tests. |
| `scripts/find-sheet.sh` | Resolves which cheat sheet to read: project `.fate/` override, then the shipped sheet, then the seed. |
| `scripts/log-reading.sh` | Appends a reading from stdin to `.fate/readings.md` with a timestamped heading. |
| `scripts/check-sheet.sh` | Validates a cheat sheet: all 78 cards present once, upright and reversed lines, all three positions, and the two Part I headings the voice depends on. |
| `scripts/forge.sh` | Forge bookkeeping: `init`, `questions`, `verdicts`, `next`, `finish`, `status`. Each prints the next step. |
| `data/deck.txt` | The 78 cards. |
| `data/seed-cheat-sheet.md` | The starting cheat sheet the Forge refines. |
| `data/forge-questions.md` | The 20 sample questions the Forge rotates through. |
| `cheat-sheet/tarot-cheat-sheet.md`, `cheat-sheet/forge-log.md` | The shipped, forged sheet and the log of the argument that produced it. |
| `prior-example.md` | A reading from before the imagery revision, kept for contrast: it translates the cards into the asker's trade, which the current Mystic never does. |

## Configuration

| Variable | Default | Effect |
|---|---|---|
| `FATE_QUIET` | `0` | `1` disables unprompted consults and silences the nudge hook. `/fate:reading` still works. |
| `FATE_SEED` | unset | Pins the draw (same as `draw.sh --seed`) so tests can force a known spread. Leave unset for the Forge. |
| `REVERSAL_RATE` | `0.33` | Probability a drawn card is reversed. |
| `DECK_FILE` | `data/deck.txt` | Alternate deck for `draw.sh`. |
| `FATE_LOG` | `.fate/readings.md` | Where `log-reading.sh` appends readings. |
| `FATE_HOOK_DEBUG` | `0` | `1` makes the relay hook dump its raw payload to `.fate/hook-debug.json`. |

All paths inside the agent and skill markdown use `${CLAUDE_PLUGIN_ROOT}`, which Claude Code substitutes at load time, so the plugin works from wherever it is checked out.

The Mystic's only shell use is running the plugin's own scripts, so you will see permission prompts of the form `bash .../scripts/draw.sh`. Approve them, or allow `Bash(bash:*)` for the session if you trust every bash script anyway.

## Runtime files

Everything the plugin writes lands in the project you run Claude Code from, under `.fate/`:

- `readings.md`: an append-only log of every reading. Add it to your `.gitignore` if you do not want it committed.
- `tarot-cheat-sheet.md`: an optional per-project sheet, written by `/fate:forge`. Committable, so a team can share a custom sheet.
- `forge/`: the per-round artifacts of the last Forge run.

This repository's `.gitignore` already excludes its own runtime files.

## Checking your work

From the plugin directory, in bash:

```
bash scripts/check-sheet.sh                    # validate the shipped sheet
bash scripts/check-sheet.sh data/seed-cheat-sheet.md
bash scripts/draw.sh --seed 42                 # a reproducible three-card draw
bash scripts/find-sheet.sh                     # which sheet the Mystic would read, as tier|path
bash scripts/forge.sh status                   # state of any Forge run in ./.fate
```

## Ideas not built

`/fate:readings` to browse the log, ASCII card art, alternate spreads. See [SPEC.md](SPEC.md) for the acceptance criteria and the design decisions.

## License

MIT. See [LICENSE](LICENSE).
