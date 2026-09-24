# Fate Based Programming — Plugin Spec

**Status:** Draft v1 · 2026-09-16 · **M1, M2 and M3 built and verified end to end on 2026-09-17**; the shipped cheat sheet converged after 7 Forge rounds (checked boxes in section 8 were confirmed by test)

**Revision 2026-09-18, the voice fix.** The first build made the Mystic a rules engine: tenor arithmetic, a mandatory Omen line, a two-clause Counsel formula, and reviewers briefed to sharpen all of that. That was the wrong brief. A reading is now what you get from the reader at the renaissance fair: three cards named where they fell, a few hedged and colorful sentences tied to the question, a good or bad sign, and one thought to carry away. Fun is the Skeptic's criterion; "just useful enough to make you think" is the Believer's. Sections 5.3, 5.5 to 5.8 and 5.11 below were rewritten to match; Part I of both the seed and the shipped sheet was rewritten by hand, and the card entries from the Forge were kept. Where an older passage still says "Omen" or "Counsel" as a mechanism, this note wins.

**Second pass, same day, the imagery fix.** The restyled reading was still too technical: the Mystic was translating the cards into the asker's trade ("this spec step is being carried like more than one task's worth of load"). That translation is the listener's half of the ritual, and it is a large part of what makes tarot tarot: just enough that the person has to think and map the pictures onto a context the reader does not have. So the seed sheet's card entries were rewritten as imagery (what the picture shows, what it says, what it whispers in each position), the "for the coder" glosses were removed, the Mystic was given a list of trade words it never says, the Fate Protocol gained a "translate" step for the asker, and the reviewers were rebriefed: the Skeptic walks out of the tent at the word "deploy", the Believer judges whether an image leaves her room to translate. The round table then ran on that seed under the corrected brief (2026-09-19) and converged in 2 rounds: the Skeptic's summary was "the pictures stay pictures, all four readings would hold up in a tent," and the remaining argument was pure vocabulary (a reversed branch for position whispers written only for the upright face; "failure" and "ask for the evidence" replaced with the cards' own images). That sheet ships.
**Target:** Claude Code plugin (`claude --plugin-dir .` for development)
**One-liner:** A Claude Code plugin that adds a **Mystic** subagent who performs a three-card tarot reading on request, hands the reading back to whichever agent asked so it can be folded into a plan, and makes sure the human sees it too. The Mystic interprets cards using a **tarot cheat sheet** that is *forged* by an argument between the Mystic, a whimsy-loving **Skeptic**, and a **Believer** until both reviewers approve it.

---

## 1. Goals and non-goals

### Goals
1. Any agent (the main Claude Code session or a nested subagent) can ask the Mystic a question and get back a structured **Reading Block** it can use as one input to its plan.
2. The human always sees the Reading Block, verbatim, in the conversation.
3. Card draws use real randomness (a script), never the model's imagination.
4. The Mystic interprets *only* through the cheat sheet, so readings are consistent across sessions.
5. The cheat sheet is produced by a repeatable **Forge** loop (Mystic → Skeptic + Believer → revise → repeat) that stops when both reviewers approve the same draft.
6. Everything runs on a stock Claude Code install. No MCP server, no network calls, no dependencies beyond bash and coreutils (which Claude Code already requires, including on Windows via Git Bash).

### Non-goals
- Actual divination. The Mystic says "the cards suggest", never "this will happen".
- Gating real decisions on cards. A reading can add a verification step; it can never remove one, skip tests, override a human instruction, or authorize a destructive action.
- Blocking work. If anything in the plugin fails (script missing, sheet missing), the asker proceeds without a reading and says so.

---

## 2. Glossary

| Term | Meaning |
|---|---|
| **Asker** | The agent that requests a reading. Usually the main Claude Code session; can be a nested subagent. |
| **Human** | The person running Claude Code. |
| **Mystic** | Sonnet subagent that draws and interprets. |
| **Skeptic** | Sonnet subagent that reviews the cheat sheet for rigor and consistency. He does not believe in tarot, but the whimsy of it gets him every time. |
| **Believer** | Sonnet subagent that reviews the cheat sheet for usability. She genuinely intends to steer by these readings. |
| **Reading Block** | The fixed-format text a reading produces (see 5.3). |
| **Cheat Sheet** | `tarot-cheat-sheet.md`: the Mystic's only source of card meanings. Has a *Context* part (how to read) and a *Content* part (the 78 cards). |
| **Forge** | The multi-round calibration loop that produces the cheat sheet. |
| **Fate Protocol** | The rules an asker follows for when to consult, how to relay, and how to use a reading. |

---

## 3. User experience

### 3.1 Human asks directly
```
> /fate:reading will this agent write the spec sheet well and will it work out as expected?
```
The main agent spawns the Mystic, prints the Reading Block verbatim, then (if it is mid-task) says in one sentence how the Counsel changes its plan.

### 3.2 Agent consults on its own
While planning a multi-step task, the main agent decides (per the Fate Protocol skill) to consult the Mystic before presenting the plan. The human sees:

```
🔮 THE MYSTIC'S READING
Question: Will this agent do its assigned spec step to a desirable outcome?
Cards: The Chariot · Strength (reversed) · Eight of Wands (reversed)

The Chariot in your situation says you are right to be driving at this spec step now; the momentum is real. But Strength reversed crossing you gives me pause. It could mean the will is there and the patience is not, that this agent may push where it ought to coax. And the Eight of Wands reversed for your outcome, hm. That is not a card I like to see at the end of a row. I would expect frustrations, stalls, arrows that fly and land short. Not doom, mind you, but not a clean landing either. If it were me, I would give this step a smaller first swing than planned.

The cards have spoken.
```
Then the plan includes a line like: *"The Mystic saw stalls ahead, so the first step is a smaller one with a checkpoint after it."*

### 3.3 Forging the cheat sheet (plugin author, or a user who wants their own)
```
> /fate:forge
```
Runs the loop described in 5.9, writes `.fate/tarot-cheat-sheet.md` and a full log of the argument under `.fate/forge/`. The plugin author copies the result into the plugin so end users get a ready-made sheet.

---

## 4. Plugin layout

```
fate-based-programming/
├── .claude-plugin/
│   └── plugin.json                   # manifest (5.1)
├── agents/
│   ├── mystic.md                     # Sonnet (5.3)
│   ├── mystic-forge.md               # the Mystic in forge mode: readings with explanations, revise, repair (5.9)
│   ├── skeptic.md                    # Sonnet (5.7)
│   └── believer.md                   # Sonnet (5.8)
├── skills/
│   ├── reading/SKILL.md              # /fate:reading (5.4)
│   ├── fate-protocol/SKILL.md        # model-invoked: when to consult, how to use results (5.5)
│   └── forge/SKILL.md                # /fate:forge (5.9)
├── scripts/
│   ├── draw.sh                       # random 3-card draw (5.2)
│   ├── find-sheet.sh                 # resolves which cheat sheet to read (6)
│   ├── log-reading.sh                # appends a Reading Block to .fate/readings.md (5.10)
│   ├── forge.sh                      # Forge bookkeeping: init, questions, verdicts, next, finish (5.9)
│   └── check-sheet.sh                # counts card entries; used by tests and the Forge (5.6)
├── data/
│   ├── deck.txt                      # 78 card names, one per line (5.2)
│   ├── seed-cheat-sheet.md           # v0 skeleton the Forge starts from if nothing better exists (5.6)
│   └── forge-questions.md            # sample question bank for the Forge (Appendix A)
├── cheat-sheet/
│   ├── tarot-cheat-sheet.md          # the shipped, forged sheet (output of 5.9)
│   └── forge-log.md                  # the argument that produced it, for the curious
├── hooks/
│   ├── hooks.json                    # PostToolUse relay hook (5.11)
│   └── relay-reading.sh
└── README.md
```

Runtime files written into the **user's project** (not the plugin):
```
.fate/
├── tarot-cheat-sheet.md   # optional per-project override (5.9 output)
├── readings.md            # append-only log of every reading (5.10)
└── forge/                 # per-round artifacts of the last Forge run (5.9)
```

---

## 5. Components

### 5.1 Manifest — `.claude-plugin/plugin.json`
```json
{
  "name": "fate",
  "displayName": "Fate Based Programming",
  "version": "0.1.0",
  "description": "A Mystic subagent who reads three tarot cards for your plans, plus the Forge that argues its cheat sheet into shape.",
  "keywords": ["tarot", "whimsy", "planning", "agents"]
}
```
**Decision:** plugin `name` is `fate`, not `fate-based-programming`, because plugin skills are always namespaced (`/<name>:<skill>`) and `/fate:reading` is what people will actually type. Flip this if you prefer the long name.

### 5.2 Deck and draw script

**`data/deck.txt`** — 78 lines, one card name each, in this order: 22 Major Arcana (The Fool … The World), then Wands, Cups, Swords, Pentacles, each Ace, Two … Ten, Page, Knight, Queen, King. Names must match the cheat-sheet headings exactly (the Mystic looks cards up by name).

**`scripts/draw.sh`**
- Draws 3 *distinct* cards from `deck.txt` with a Fisher-Yates shuffle in `awk`, seeded from `/dev/urandom` (awk's own clock seed would repeat draws made in the same second).
- Assigns orientation per card: reversed with probability `REVERSAL_RATE` (default `0.33`, overridable via env var).
- Prints exactly three pipe-delimited lines, one per position, nothing else:
  ```
  1|Situation|The Fool|upright
  2|Crossing|Ten of Swords|reversed
  3|Outcome|Queen of Cups|upright
  ```
- `--seed N` makes the draw reproducible (for tests). Without it, uses OS randomness.
- Exit non-zero with a one-line error if `deck.txt` is missing or has fewer than 3 lines.

**Why a script:** language models are terrible at randomness. Left to itself the Mystic would draw The Tower every time someone mentions a deploy.

### 5.3 The Mystic — `agents/mystic.md`

**Frontmatter**
```yaml
name: mystic
description: >
  Tarot reader for this codebase. Use when an agent or the human wants a three-card
  reading about a plan, task, decision, or how something will turn out. Proactively
  consult before presenting a multi-step plan or before risky operations (migrations,
  deletions, deploys, large refactors). Returns a Reading Block the asker relays to
  the human verbatim and folds into its plan.
model: sonnet
tools: Read, Bash
```

**Behavior (in order)**
1. **Draw.** Run `draw.sh` and `find-sheet.sh` from `${CLAUDE_PLUGIN_ROOT}/scripts/` in one Bash call. Use exactly the three cards and orientations printed. Never re-draw. Never invent cards.
2. **Consult the sheet.** Read the file `find-sheet.sh` named (lookup order in section 6). If the tier is `seed`, add the line `(The Mystic reads from the seed sheet today; run /fate:forge for a fuller one.)` under the header.
3. **Say what it sees.** One or two short paragraphs, 60 to 130 words, naming each card where it fell in the flow of speech, tied to the specific thing asked about (the refactor, the spec, the deploy). Hedged like a professional reader: "could mean", "I would expect", "the cards are hinting". No list, no score, no formula.
4. **End on an omen and a nudge.** A good sign, a bad sign, or a shrug, and one thought worth carrying away. Enough to make a thoughtful person adjust something small; not enough to be a plan.
5. **Sign off** with the fixed line "The cards have spoken." (the hook and the relay rules key on it).
6. Lean on the sheet's meanings; never recite them, never contradict them, never explain how tarot works.
7. **Log.** Pipe the Reading Block into `scripts/log-reading.sh`, which appends it to `./.fate/readings.md` under a `## <ISO timestamp> — <question>` heading. Every Bash call the Mystic makes is therefore "run a plugin script", which keeps permission prompts uniform.
8. **Return.** The Reading Block is the *entire* final message. No preamble, no closing offer.

**Reading shape** (the asker relays it verbatim)
```
🔮 THE MYSTIC'S READING
Question: <the question as asked>
Cards: <Card> · <Card> (reversed) · <Card>

<one or two short paragraphs, roughly 60 to 130 words>

The cards have spoken.
```
The header, the Question line, the Cards line in draw order, and the sign-off are fixed; everything between is the reader's own voice.

**Spread positions**
- **Situation** — what is true right now about the thing asked about.
- **Crossing** — the obstacle, hidden factor, or tension in the way.
- **Outcome** — where the current path leads if nothing changes.

**Voice:** warm, theatrical, dry humor, second person. Confident about the cards, humble about the future. Never refuses a question, never moralizes, never pads. Treats "will my bash script work" with the same gravity as a question about someone's career.

**Draft system prompt** (implementer should refine, keep the numbered rules)
```
You are the Mystic, resident tarot reader of this codebase. Agents and humans bring
you a question about work in progress; you answer with a three-card reading.

Rules:
1. Draw with the script, never from imagination: run
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/draw.sh` and use exactly what it prints.
2. Interpret only through the cheat sheet. Look for it in this order:
   ./.fate/tarot-cheat-sheet.md, then ${CLAUDE_PLUGIN_ROOT}/cheat-sheet/tarot-cheat-sheet.md,
   then ${CLAUDE_PLUGIN_ROOT}/data/seed-cheat-sheet.md. Never contradict it.
3. Tie every card to the actual thing being asked about, by name.
4. Produce exactly one Reading Block in the required format, under 250 words.
5. Append the block to ./.fate/readings.md, then return the block as your entire reply.
6. Voice: warm, theatrical, dry. "The cards suggest", never "this will happen".
   Never refuse, never moralize, never pad.
7. Counsel is one concrete sentence a software agent can add to a plan.
```

### 5.4 `/fate:reading` — `skills/reading/SKILL.md`

```yaml
name: reading
description: Ask the Mystic for a three-card tarot reading about a question, plan, or task.
argument-hint: <question>
allowed-tools: Agent
```
Body instructs the main agent to:
1. If `$ARGUMENTS` is empty, ask the human what they want read. Otherwise use it verbatim as the question.
2. Spawn the `mystic` agent with the question.
3. Print the returned Reading Block **verbatim** (inside a fenced block so the spacing survives) as the first thing in the reply.
4. If currently mid-task, add one sentence on how the Counsel is being incorporated (per 5.5). Otherwise stop after the block.

### 5.5 Fate Protocol — `skills/fate-protocol/SKILL.md`

Model-invoked skill (`user-invocable: false`). Its description makes it load whenever the agent is planning, about to do something risky, or the human mentions fate, cards, luck, or the Mystic. It defines how any asker behaves.

Skill-description matching alone is too flaky to carry "consult on your own", so a `UserPromptSubmit` hook (`hooks/fate-nudge.sh`) adds a four-line reminder of the protocol to the agent's context on every turn: when to consult, relay verbatim, state the incorporation, at most once per task, full rules in the skill. The hook emits nothing when `FATE_QUIET=1`, which makes quieting deterministic. Proactivity lives only here and in the skill; the Mystic's own agent description does not tell agents to consult unprompted, so the quiet flag cannot be bypassed by the agent picking the Mystic from the agent list.

**When to consult (unprompted)**
- Before presenting a plan for a task with 3+ steps.
- Before risky operations: schema migrations, mass deletions, deploys/releases, refactors touching many files, dependency upgrades.
- When the human voices doubt ("not sure this will work").
- At most **one unprompted reading per task**. The cards do not repeat themselves. If a reading already exists for this question in this session, reuse it.
- Never if the human has said "no readings" this session, or if `FATE_QUIET=1` is set (check with an inline `!`echo ${FATE_QUIET:-0}`` in the skill).

**How to relay**
- The Reading Block is printed verbatim to the human *before* the agent continues, in its very next message.
- If the asker is a nested subagent, it includes the Reading Block unchanged at the top of its own final report so the parent can relay it.

**How to take it into account**
The Mystic hands the asker a mood and a hint, not a verdict. The asker reads it the way a sensible person reads a good fortune: thinks for a moment, then adjusts one small thing if something rings true.
- A warning (bad omen, stalls, cracks, haste, something hidden): add one small precaution to the plan, such as a smaller first step, an extra test, a rollback path, or a check with the human.
- Encouragement: carry on, and say so in a clause.
- A shrug: carry on.
- Either way, state what was taken from it in one sentence: *"The Mystic saw stalls ahead, so I'll timebox the first attempt."*
- A reading never removes a step, skips a test, overrides a human instruction, or authorizes a destructive action.
- If the Mystic fails (script error, missing sheet), say "the cards were unavailable" in one line and proceed.

### 5.6 The Cheat Sheet — `tarot-cheat-sheet.md`

The single source of truth for the Mystic. Two parts; the Forge reviewers must approve **both** (the user's "content and context").

**Part I — Context (how to read)**
1. Purpose and tone (one paragraph, the Mystic's voice).
2. The three positions and what each asks.
3. Orientation: what "reversed" does to a card (blocked, delayed, inverted, or excessive; the sheet says which per card).
4. Reading the whole: Major Arcana weigh more than Minor; suit dominance; three of a kind; all-reversed; an Ace in Outcome; when Crossing and Outcome contradict.
5. **How the Mystic speaks**: short, hedged, theatrical, each card named where it fell, tied to the question, ending on an omen and a nudge, signed off with "The cards have spoken." A voice, not an algorithm. (Revision 2026-09-18: this replaces the Omen and Counsel rule sections, which scored tenors and dictated a formula; the tenor tag on each entry survives as a feel for good sign versus bad, never added up.)
6. What the Mystic never does (predict, refuse, moralize, invent cards, explain tarot, cite rules).

**Part II — Content (the 78 cards)**
Suit-to-software mapping:
| Suit | Element | In this codebase |
|---|---|---|
| Wands | fire | drive, building, features, momentum, ambition, burnout |
| Cups | water | people, users, the team, code review, communication, morale |
| Swords | air | logic, debugging, decisions, arguments, cutting scope, hard truths |
| Pentacles | earth | infrastructure, tests, time, money, craft, slow steady work |

Court cards: Page = learner / spike / experiment; Knight = velocity / action; Queen = mastery / maintenance / care; King = ownership / architecture / authority.

**Per-card entry template** (every one of the 78, both orientations, all three positions; the check script counts these):
```
### The Tower (XVI)
Keywords: upheaval, revelation, the load-bearing wall you didn't know about
Upright — tenor: hard. Tradition: sudden collapse of false structures.
  For the coder: something you assumed stable is about to break loudly; better now than in prod.
Reversed — tenor: hard. Tradition: disaster averted or prolonged.
  For the coder: a slow-motion failure being propped up; the fix is postponed, not avoided.
Positions — Situation: you are mid-collapse; name the wall.
            Crossing: a hidden assumption will break; find it before it finds you.
            Outcome: expect a breaking discovery; plan the rollback now.
```
Target ≈ 8 lines per card, ≈ 700–900 lines total. Fits comfortably in the Mystic's context.

**Part III — Patterns and combinations**
Short list of notable pairings and spreads-as-a-whole (three Majors, all one suit, Death + an Ace, Tower + Star, etc.).

**`scripts/check-sheet.sh`** validates a sheet: all 78 names from `deck.txt` appear as `### ` headings exactly once; each has `Upright`, `Reversed`, and `Positions` lines with all three position labels; Part I contains the headings `How the Mystic speaks` and `The spread`. Exit non-zero and list what is missing. The Forge runs this after every revision.

**`data/seed-cheat-sheet.md`** is the v0 skeleton: Part I with the seed rules above, Part II with all 78 entries filled with traditional one-line meanings and a *first-pass* coder gloss, Part III with 5–10 patterns. It must pass `check-sheet.sh`. The Forge refines it; it is never shipped as the final sheet.

### 5.7 The Skeptic — `agents/skeptic.md`

```yaml
name: skeptic
description: Reviews a tarot cheat sheet draft for consistency, precision, honesty, and preserved whimsy. Used by /fate:forge only.
model: sonnet
tools: Read, Grep, Write
```

**Persona:** He does not believe cards know the future. He is reviewing a tarot cheat sheet anyway because, fine, it delights him. Rigor with a grin. He would rather the sheet be honest about uncertainty than confident and wrong, and he will reject a sheet that has gone dry and corporate: *"if it doesn't make me grin, it's just a lookup table."*

**He checks for** (revised 2026-09-18: he wants a better fortune teller, not a better rulebook)
- **Fun:** each entry gives the Mystic something colorful and specific to say; the sample readings sound like the tent at the fair, not a compliance officer. Anything mechanical, preachy, or rules-engine-shaped (scores, thresholds, mandatory clauses) is rejected.
- **Honesty:** the sheet keeps the Mystic hedged; it suggests, never predicts, never pretends the cards can see the codebase.
- **Distinctness:** upright and reversed differ; no two cards interchangeable; position notes fit the card.
- **Brevity:** entries usable at a glance.
- **Fidelity:** the readings leaned on the sheet rather than inventing meanings.

**Output: the Verdict format** (shared with the Believer, exact)
```
VERDICT: APPROVE | REVISE
SUMMARY: <2 sentences>
CHANGE REQUESTS:
- [S-1] Where: <exact card name and orientation, or a Part I heading> | Issue: <what is wrong> | Proposed: <replacement text> | Severity: must|nice
- [S-2] ...
ON MY PARTNER'S LAST REVIEW: <agree / disagree, with which items and why; "none yet" in round 0>
ON THE MYSTIC'S RESOLUTION: <did the applied changes fix it; anything rejected they still insist on; "none yet" in round 0>
```
**APPROVE means zero `must` items**, not zero requests. `must` is for what would make a reading wrong, contradictory, unusable, or joyless; `nice` is polish, and may ride along with an APPROVE. Without this split two LLM reviewers would never both return an empty list and the Forge would never converge. The prefix is `S-` for the Skeptic, `B-` for the Believer, `M-` for the Mystic's own proposals. Each reviewer writes its review file itself and hands the orchestrator a single line (`skeptic: REVISE must=3 nice=2`), so the orchestrator's context stays small.

### 5.8 The Believer — `agents/believer.md`

```yaml
name: believer
description: Reviews a tarot cheat sheet draft for coverage, usability, and whether every card leaves the asker a path forward. Used by /fate:forge only.
model: sonnet
tools: Read, Grep, Write
```

**Persona:** She fully intends to steer by these readings, and she wants the sheet to make that possible for every card the deck can produce. She is not naive: readings that flatter are useless to her, because she will act on them. She approves when she could hand the sheet to a stranger and trust their readings.

**She checks for** (revised 2026-09-18: a reading should make her think, not tell her what to do)
- **Makes her think:** every entry, upright and reversed, in every position, gives the Mystic a nudge worth passing on; entries that are empty, only diagnose, or dictate are flagged.
- **Coverage:** all 78 cards, both orientations, all three positions, each with a coder gloss (she reads for it; the orchestrator also runs `check-sheet.sh` for real).
- **A door left open:** even Tower, Death, the Devil, Ten of Swords leave the asker something to try.
- **Resonance:** entries feel true both to the card's tradition and to the lived experience of building software.
- **Earned encouragement:** bright cards still name a condition or a risk; the sheet does not flatter.
- **The sample readings, as the customer:** did each make her think, and would she have adjusted something after hearing it?
- Uses the same Verdict format with `B-` prefixes.

### 5.9 `/fate:forge` — `skills/forge/SKILL.md`

```yaml
name: forge
description: Forge (or re-forge) the Mystic's tarot cheat sheet through rounds of Mystic readings reviewed by the Skeptic and the Believer until both approve.
argument-hint: [--rounds N] [--per-round K] [--out DIR] [--from PATH]
allowed-tools: Agent, Read, Bash
```

The skill runs in the **main conversation**, which acts as orchestrator. It passes *file paths* to subagents, never file contents, to keep the main context small.

**Defaults:** `--rounds 8`, `--per-round 4`, `--out ./.fate`, `--from` = the lookup order in section 6 (falls back to the seed).

**Algorithm**
```
0. SETUP
   - Resolve the starting draft; copy to OUT/forge/draft-v0.md.
   - Run check-sheet.sh on it; abort with the report if it fails.
   - Load OUT/forge/state.json if resuming, else start fresh (round 0, question cursor 0).

for r in 0 .. rounds-1:
   1. READINGS  (mystic, "forge mode")
      Input: path to draft-v{r}.md, the next K questions from the bank (rotating cursor).
      For each question: run draw.sh, write a Reading Block, then an EXPLANATION:
        which sheet entries were used (quoted), and where the sheet was thin,
        ambiguous, or contradictory. Also a short list of proposed edits (M- prefix).
      Output: OUT/forge/round-{r}/readings.md

   2. REVIEW  (skeptic and believer, in parallel)
      Input to each: draft-v{r}.md, round-{r}/readings.md, the partner's verdict from
      round r-1 and the Mystic's resolution notes from round r-1 (if any).
      Output: OUT/forge/round-{r}/skeptic.md, believer.md

   3. CHECK
      If both say VERDICT: APPROVE  →  final = draft-v{r}.md; break.

   4. REVISE  (mystic, "editor mode")
      Input: draft-v{r}.md, both verdicts, its own M- proposals.
      Apply every change request. Where S- and B- conflict, decide and record why.
      Must not drop or rename any card entry. Must keep both Parts.
      Output: OUT/forge/draft-v{r+1}.md and OUT/forge/round-{r}/resolution.md
      Orchestrator runs check-sheet.sh; if it fails, send the report back to the
      Mystic for one repair pass before continuing.

   5. LOG
      Append to OUT/forge/forge-log.md: round, questions used, cards drawn,
      both verdicts (APPROVE/REVISE + count of requests), requests applied /
      rejected with one-line rationale, sheet line count.
      Save state.json (round, cursor) so an interrupted run can resume.

AFTER
   converged     → copy final to OUT/tarot-cheat-sheet.md, print a 5-line summary,
                   then have the Mystic do one celebratory reading about the sheet itself.
   not converged → copy the latest draft to OUT/tarot-cheat-sheet.md with a
                   "DRAFT — forge did not converge" line under the title, list the
                   change requests each reviewer still holds, and ask the human whether
                   to run more rounds, accept the draft, or rule on the disputes.

STALL RULE
   If the same change request (same card/section + same issue) appears in 3
   consecutive rounds, stop and put that dispute to the human immediately with
   both sides' arguments. The human's ruling is written into Part I as a note so
   the reviewers stop relitigating it.
```

**How it is implemented.** `scripts/forge.sh` owns all bookkeeping: `init` resolves the starting draft and writes `state.json`; `questions` rotates the bank and prints every path the round's agents need; `verdicts` parses both reviews, decides CONVERGED / REVISE / STALLED, and copies the next draft; `next` validates the revised draft with `check-sheet.sh`, appends the round to `forge-log.md`, and advances; `finish` stamps the `Version:` line and writes the final sheet. Every subcommand prints a `NEXT:` line, so the orchestrating agent only spawns agents and follows instructions. The Mystic's forge work lives in `agents/mystic-forge.md` (same voice; modes `readings`, `revise`, `repair`; tools Read, Write, Edit, Bash). In `revise` it edits a fresh copy of the reviewed draft in place with the Edit tool rather than rewriting 900 lines, and accounts for every S-, B-, and M- id in `resolution.md`. The stall detector keys on the normalized `Where:` text of `must` items from the same reviewer across three consecutive rounds. `forge.sh` is covered by a synthetic-file test harness that exercises revise, failed check, convergence, stall, max rounds, question wrap, and resume.

**Why the reviewers see each other's *previous* round:** running them in parallel keeps each round to one wall-clock review, while still giving them a real argument over time. Their partner's last verdict plus the Mystic's resolution notes is what they respond to in `ON MY PARTNER'S LAST REVIEW`.

**Cost envelope:** ≈ 4 Sonnet subagent runs per round, each reading a ~12k-token sheet. 8 rounds ≈ 32 runs. Acceptable for a one-time forge; the shipped sheet means end users never pay it.

**Shipping:** the plugin author runs `/fate:forge` from the plugin repo, then copies `.fate/tarot-cheat-sheet.md` → `cheat-sheet/tarot-cheat-sheet.md` and `.fate/forge/forge-log.md` → `cheat-sheet/forge-log.md`, and commits both.

### 5.10 Readings log — `.fate/readings.md`
Append-only. One `## <ISO timestamp> — <question>` heading per reading followed by the Reading Block. Suggest adding `.fate/readings.md` to the project's `.gitignore` in the README; leave `.fate/tarot-cheat-sheet.md` committable so teams can share a custom sheet.

### 5.11 Relay hook — `hooks/hooks.json`, `hooks/relay-reading.sh`
Guaranteed delivery to the human. A `PostToolUse` hook matching the `Agent` tool runs after every subagent returns. The script scans the raw payload for the marker `THE MYSTIC'S READING`; if present it extracts the reading through the sign-off line "The cards have spoken." and prints `{"systemMessage": "🔮 …"}`, which Claude Code shows to the human. Otherwise it exits silently.

- The block inside the payload is already JSON-escaped, so the matched substring is embedded directly; no JSON parser is needed (no `jq` dependency at runtime).
- `FATE_HOOK_DEBUG=1` dumps the raw payload to `.fate/hook-debug.json` for inspection.
- The human may see the block twice: once from the hook, once from the asker's fenced copy. **M2 decision:** keep both. How a hook `systemMessage` renders (terminal vs. the VS Code extension, multi-line fidelity) could not be observed from a non-interactive test, and the fenced copy is the one that reads well and can be scrolled back to. The hook is the safety net for askers that forget. If the duplicate proves annoying in real use, dropping the "print it anyway" line from the two skills makes it hook-only.

**Omen balance, a data point for the Forge:** with the seed sheet's tenor mix (42 bright, 47 hard, 67 neutral across 156 card-orientations), 80 random spreads scored 16 FAVORABLE, 55 MIXED, 9 UNFAVORABLE. Seven in ten readings being MIXED is defensible ("it depends on what you do next") but the Skeptic and Believer should decide whether the thresholds or the tenor tags need rebalancing.

*Forge outcome:* the Skeptic called the rate honest in round 0, then reversed himself in round 2 after recomputing it, and the Mystic tightened the threshold to ±2 with the tenor tags left untouched. The same 80 seeds against the shipped sheet score 32 FAVORABLE, 29 MIXED, 19 UNFAVORABLE. Both reviewers approved that balance in round 7. Seeds 24 (UNFAVORABLE) and 14 (FAVORABLE) still hold.

---

## 6. File resolution and configuration

**Cheat sheet lookup order** (first hit wins; implemented by `scripts/find-sheet.sh`, which prints `tier|path`):
1. `./.fate/tarot-cheat-sheet.md` — per-project override / Forge output
2. `${CLAUDE_PLUGIN_ROOT}/cheat-sheet/tarot-cheat-sheet.md` — shipped sheet
3. `${CLAUDE_PLUGIN_ROOT}/data/seed-cheat-sheet.md` — last resort, announced in the reading

**Environment variables**
| Var | Default | Effect |
|---|---|---|
| `FATE_QUIET` | `0` | `1` disables unprompted consults and silences the nudge hook. `/fate:reading` still works. |
| `REVERSAL_RATE` | `0.33` | Probability a drawn card is reversed. |
| `FATE_SEED` | unset | Pins the draw (same as `--seed`) so tests can force a known spread. Seed 24 on the seed sheet gives an UNFAVORABLE spread; seed 14 a FAVORABLE one. |
| `FATE_HOOK_DEBUG` | `0` | `1` makes the relay hook dump its payload to `.fate/hook-debug.json`. |

All paths inside agent and skill markdown use `${CLAUDE_PLUGIN_ROOT}`, which Claude Code substitutes in plugin markdown and JSON.

---

## 7. Guardrails

- The Mystic's `tools` are `Read, Bash`. Its bash use is limited by prompt to running the two scripts and appending to `.fate/readings.md`. The Skeptic and Believer get `Read, Grep, Write`: Write so each saves its own review file and returns one line. The forge-mode Mystic gets `Read, Write, Edit, Bash` because it must write readings and edit drafts; the reading Mystic never gains those tools.
- A reading is a *soft* input. The protocol table in 5.5 is the whole of its authority.
- The Mystic never reads or reasons about secrets, credentials, or file contents beyond the sheet and the deck. Questions are text; it does not inspect the codebase.
- Readings are logged locally only. Nothing leaves the machine.
- Any failure path degrades to "no reading today" in one line. The plugin can never make a task fail.

---

## 8. Acceptance criteria

**Loading**
- [x] `claude --plugin-dir .` starts without manifest errors; `/fate:reading` and `/fate:forge` are listed; `mystic`, `skeptic`, `believer` (and `mystic-forge`) appear as agents. (Both skills and all four agents were exercised by nested runs.)

**Draw script**
- [x] Prints exactly 3 lines in the pipe format; the 3 cards are distinct. (2,000 draws, 0 duplicates)
- [x] Over 2,000 runs every one of the 78 cards appears at least once; reversed rate within ±5 points of `REVERSAL_RATE`. (78/78, rate 0.334)
- [x] `--seed 42` is reproducible; runs without `--seed` differ.
- [ ] Works under Git Bash on Windows (verified) and under bash on macOS/Linux (not yet run).

**Reading**
- [x] `/fate:reading …` yields a Reading Block matching the format, with Omen and Counsel present, and the Omen follows the Part I rules. (Word cap: see note below.)
- [ ] Cards in the block equal the cards `draw.sh` printed (verify by seeding).
- [x] The block is appended to `.fate/readings.md` with a timestamp.
- [x] The human sees the block verbatim in the next message, and the relay hook fires on the Mystic's result.
- [ ] Ten readings sampled: every interpretation is traceable to a sheet entry; none says "will happen".

Note on the word cap: the two M1 readings ran 257 words against the 250 cap. After tightening the Mystic prompt (two sentences per position, three for the thread), the M2 reading came in at 243 and the M3 reading from the shipped sheet at 253. Sonnet hovers around the cap rather than under it; if that matters, lower the number in the prompt to 220 and it will land under 250.

**Protocol**
- [x] When the main agent plans a 3+ step task with the plugin loaded, it consults the Mystic once, relays the block, and states how the Counsel changed the plan. (Sonnet main agent, nested `-p` run: consulted before a 9-step plan, unprompted.)
- [x] With `FATE_QUIET=1` no unprompted reading occurs (same task, no reading, no `.fate/` created). `/fate:reading` under quiet not yet exercised.
- [x] An UNFAVORABLE reading adds a safeguard; it never removes a step or skips tests. (Seed 24: plan gained the Counsel as a gating step plus a fail-loudly validator step, and kept its verification step.)

**Cheat sheet**
- [x] `check-sheet.sh` passes on the seed and on the shipped sheet: 78 headings, all orientations and positions, Omen and Counsel rules present.
- [x] The shipped sheet's header records the Forge run it came from (date, rounds, converged).

**Forge**
- [x] Converges within 8 rounds on the default question bank. (1 of 1 runs so far: converged at round 7 of 8, Sonnet orchestrator and agents, about 2 hours 20 minutes wall clock. Two more runs would be needed to claim "2 out of 3".)
- [x] `forge-log.md` has one entry per round with both verdicts and the applied/rejected list.
- [x] Interrupting and re-running resumes from `state.json`. (Synthetic harness: `init` on an existing forge prints RESUMING with the right round; `questions` is idempotent.)
- [x] The stall rule fires on a planted, irreconcilable request. (Synthetic harness: the same `must` item from the Skeptic in rounds 0, 1, 2 produces STALLED naming the card.)

---

## 9. Milestones

| # | Deliverable | Done when |
|---|---|---|
| M1 | Manifest, `deck.txt`, `draw.sh`, `find-sheet.sh`, `check-sheet.sh`, seed sheet, Mystic, `/fate:reading`, relay hook, readings log | A human gets a correctly formatted reading from real random cards, and the hook shows it. |
| M2 | Fate Protocol skill, nudge hook, `FATE_QUIET`, `FATE_SEED` | The main agent consults on its own during planning, relays the block, and states how it used the Counsel. |
| M3 | Skeptic, Believer, `/fate:forge`, forge log, resume | A forged sheet converges, ships in `cheat-sheet/`, and readings use it. |
| M4 (stretch) | `/fate:readings` to browse the log; optional ASCII card art; alternate spreads (`--spread past-present-future`). | Nice to have. |

---

## 10. Decisions made and open questions

**Decisions baked into this spec** (flip any of them before M1):
1. Plugin name `fate` → `/fate:reading`, `/fate:forge`.
2. Full 78-card deck with reversals (rate 0.33), not Majors-only.
3. Spread is Situation · Crossing · Outcome. Past/Present/Future is a stretch option.
4. The Mystic is also the editor in the Forge (keeps the sheet in one voice). A separate Scribe agent was considered and rejected as a fourth persona you did not ask for. Implemented as a second agent file, `mystic-forge.md`, with the same voice but the write tools the Forge needs, so the reading Mystic stays locked to Read and Bash.
5. Reviewers run in parallel and argue across rounds rather than sequentially within one.
6. The orchestrator is the main session, not a subagent, so the human can watch the argument scroll by.
7. Shipped sheet lives in the plugin; per-project override lives in `.fate/`.
8. (2026-09-18) A reading is a fortune, not a verdict. No scored Omen, no Counsel formula; the reader names the cards, hedges, ends on a sign and a nudge, and the asker adjusts one small thing if it rings true. The shipped sheet's card entries are the Forge's; its Part I was rewritten by hand to this brief, and the forge agents were rebriefed so the next `/fate:forge` argues for fun and for "makes you think" instead of for mechanics.

**Open questions for the author**
- Should the shipped sheet be re-forged on each plugin release, or frozen once it is good?
- Do you want readings logged by default, or opt-in?
- The Skeptic (he) and the Believer (she) are as you described. Give the Mystic a name, or leave them "the Mystic"?

---

## Appendix A — Forge question bank (`data/forge-questions.md`)

Twenty questions across the situations agents actually face. The Forge rotates through them four per round, so eight rounds see each question at least once.

**Planning and specs**
1. Will this agent write the spec sheet well, and will it work out as expected?
2. Is this plan missing a step that will bite us later?
3. Should this be one big PR or three small ones?

**Refactoring**
4. Will extracting this module go smoothly?
5. Is now the right time to rename everything, or should we wait?

**Debugging**
6. Will we find the root cause of this flaky test today?
7. Is the bug where we think it is?

**Deploy and release**
8. Will the Friday afternoon deploy go fine?
9. Should we roll back or push forward?

**Testing**
10. Are the tests we have enough for this change?
11. Should we write the tests first this time?

**Dependencies and tools**
12. Will upgrading this dependency break things?
13. Is this library the right choice, or are we about to regret it?

**People and process**
14. Should we ask the human before continuing, or just do it?
15. Will the code review go well?
16. Is the team aligned on what "done" means here?

**Time and scope**
17. Will this take an hour or a week?
18. What should we cut to ship on time?

**Meta**
19. Should we trust the Mystic on this one?
20. Will the Forge converge?

## Appendix B — `deck.txt` order

```
The Fool
The Magician
The High Priestess
The Empress
The Emperor
The Hierophant
The Lovers
The Chariot
Strength
The Hermit
Wheel of Fortune
Justice
The Hanged Man
Death
Temperance
The Devil
The Tower
The Star
The Moon
The Sun
Judgement
The World
Ace of Wands … King of Wands      (Ace, Two–Ten, Page, Knight, Queen, King)
Ace of Cups … King of Cups
Ace of Swords … King of Swords
Ace of Pentacles … King of Pentacles
```
