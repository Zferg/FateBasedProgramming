---
name: forge
description: Forge (or re-forge) the Mystic's tarot cheat sheet through rounds of Mystic readings reviewed by the Skeptic and the Believer until both approve. Long-running (several minutes per round); run it when there is time.
argument-hint: [--rounds N] [--per-round K] [--out DIR] [--from PATH] [--fresh]
allowed-tools: Agent, Read, Write, Bash
---

Arguments: $ARGUMENTS

You are the orchestrator of the Forge. A script does the bookkeeping; you spawn the agents and follow the `NEXT:` line every script call prints. Rules for you:

- Pass file **paths** to agents, never file contents. Do not read the draft, the readings, or the reviews yourself. Keep your own context small; the agents read what they need.
- Do not skip, merge, or reorder steps. Do not stop early unless a script prints `CONVERGED`, `STALLED`, or `DONE`.
- Make sure `FATE_SEED` is not set in the environment (it would make every draw identical).
- Tell the human what is happening in one short line per step: "Round 2: readings", "Round 2: reviews", "Round 2: revising (Skeptic 5 must, Believer 2 must)".

The script is `bash "${CLAUDE_PLUGIN_ROOT}/scripts/forge.sh"`; the arguments above go to `init` (for example `--rounds 6 --out ./.fate`). If `--out` is given, pass the same `--out` to every later call; the printed `NEXT:` lines already include it.

## The loop

1. **Init.** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/forge.sh" init <arguments>`. It prints `STATE`, `DRAFT`, and `NEXT`. If it prints `RESUMING`, continue from the round it names.

2. **Questions.** Run the `questions` call it named. It prints `ROUND`, `DRAFT`, `ROUND_DIR`, the `QUESTIONS`, the `PREV_*` paths (or `none`), and `HAVE:` flags saying which artifacts already exist for this round.

3. **Readings.** Unless `readings=yes`, spawn `fate:mystic-forge` with this prompt, filling the values in:
   ```
   MODE: readings
   DRAFT: <DRAFT>
   ROUND_DIR: <ROUND_DIR>
   QUESTIONS:
   - <question 1>
   - <question 2>
   ...
   ```
   Wait for it. It replies with one line.

4. **Reviews.** Spawn `fate:skeptic` and `fate:believer` **in parallel** (two Agent calls in the same message), skipping any whose file already exists. Prompt for the Skeptic:
   ```
   DRAFT: <DRAFT>
   READINGS: <ROUND_DIR>/readings.md
   PARTNER: <PREV_BELIEVER>
   RESOLUTION: <PREV_RESOLUTION>
   OUT: <ROUND_DIR>/skeptic.md
   ```
   The Believer's is the same with `PARTNER: <PREV_SKEPTIC>` and `OUT: <ROUND_DIR>/believer.md`. Wait for both.

5. **Verdicts.** Run the `verdicts` call. It prints both verdicts and a `DECISION`:
   - `CONVERGED`: go to step 7.
   - `STALLED`: go to step 8.
   - `REVISE`: it has created `NEXT_DRAFT`. Spawn `fate:mystic-forge` with:
     ```
     MODE: revise
     DRAFT: <NEXT_DRAFT>
     SKEPTIC: <SKEPTIC_REVIEW>
     BELIEVER: <BELIEVER_REVIEW>
     READINGS: <READINGS>
     RESOLUTION: <RESOLUTION>
     ```
     Wait for it.

6. **Advance.** Run the `next` call. If it prints `CHECK_FAILED` with a report, spawn `fate:mystic-forge` with `MODE: repair`, `DRAFT: <path>`, and `REPORT: <the report lines>`, then run `next` again. If it prints `ADVANCED`, go back to step 2. If it prints `DONE`, go to step 7 with `--draft`.

7. **Finish.** Run `finish` (or `finish --draft` when not converged). It prints `FINAL`, `LOG`, and a `SUMMARY`. Show the human the summary and the final path. If it converged, spawn `fate:mystic` once with the question `Will this cheat sheet serve its readers well?` and print the Reading Block verbatim: the Forge closes with a reading from the very sheet it made.

8. **Stalled.** Follow the script's `NEXT:` line: with a human present, show both sides' arguments from the reviews and resolution notes, ask them to rule, record the ruling as a note in Part I of the next draft, and continue with `next`. Without a human (non-interactive), run `finish --draft` and report the dispute.

## Shipping

The Forge writes into the project's `.fate/` folder. To ship a forged sheet with the plugin, copy `.fate/tarot-cheat-sheet.md` to the plugin's `cheat-sheet/tarot-cheat-sheet.md` and `.fate/forge/forge-log.md` to `cheat-sheet/forge-log.md`, then remove the `.fate/` copy so the project override does not shadow the shipped sheet.
