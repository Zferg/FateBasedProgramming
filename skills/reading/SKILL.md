---
name: reading
description: Ask the Mystic for a three-card tarot reading about a question, plan, task, or decision. Use when the human asks for a reading, asks what the cards say, or invokes fate.
argument-hint: <question>
allowed-tools: Agent
---

Question from the human: $ARGUMENTS

Do exactly this:

1. If the question is empty, ask the human what they would like the cards to consider, then stop.
2. Spawn the `fate:mystic` subagent with the Agent tool. Its prompt is the question, verbatim, and nothing else.
3. When it returns, print its reading verbatim, inside a fenced code block so the spacing survives, as the first thing in your reply. Every line, from the 🔮 header to "The cards have spoken." Do not paraphrase, trim, or tidy the reading.
4. If you are in the middle of a task, add one sentence after the block translating the reading's images into this task and saying what you took from it. Otherwise stop after the block: the human does their own translating, and that is the fun of it.
5. If the Mystic reports the cards are unavailable, relay that one line and carry on with whatever you were doing.

A hook also shows the reading to the human as a system message the moment the Mystic returns. Print it anyway: the fenced copy is the one they can scroll back to.
