---
name: kickoff
description: Use when a task sizes as T2/T3 (several files, a real design choice, or the escalation list) and needs a design note the user approves before any implementation; not for T0/T1 edits or resuming existing work (use pickup).
argument-hint: <slug> [T2|T3]
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/init.sh *)
---

# Kickoff

Create the work record for one item, design it on verified facts, then stop for approval. Nothing is written outside `.shoal-dev/`.

1. Pick slug (`[a-z0-9-]+`) and tier from `$ARGUMENTS`; default tier T2. If the slug is missing, derive one from the task and say which you chose.
2. Run `${CLAUDE_SKILL_DIR}/init.sh <slug> [T2|T3]` from inside the repo. Stdout is the item path (`ITEM`). On exit 1, report the stderr message and stop; never work around a refusal (for example by deleting or untracking files).
3. Problem: the user's words, verbatim, quoted. No paraphrase. Leave the `Base:` line as init.sh wrote it.
   Goal: 1–2 lines on the outcome behind the request and how we will know it was reached. A request usually names a process ("add X"); the goal is what that process is for. If the conversation does not say, ask; if a different process would serve the goal better, say so in Rulings.
4. Unknowns: list every fact the design depends on that you have not verified in this session (how the existing code behaves, what a library or API really does, hard constraints). Resolve each before designing, by the cheapest means:
   - a few known files: read them yourself;
   - broad recon or external docs: dispatch `researcher` with the `design.md` path, the questions, and the note path `ITEM/research.md` (tell it to write the note in Chinese; it does not load the rules);
   - only the user can answer: ask now, not after the draft.
   Replace each entry with its answer and evidence (`file:line` or URL). Never design on a guess; anything still open is named in step 9.
5. Draft the rest yourself; you hold the conversation, a fresh agent does not:
   - Rulings: one per line, as `Ruling: what — why — cost if wrong`.
   - Design and Slices (T3): short; data structures and interfaces first.
   - How we verify: exactly 3 lines.
6. T3 or escalation list: dispatch `architect` to challenge the draft, with the `design.md` path and the note path `ITEM/design.review.md` (written in Chinese). One round. Fold in what you accept; record what you reject as a Ruling with the reason.
7. T3 only: fill `ITEM/ledger.md` (Status, Next, Decisions, Running lanes, Open issues, References), at most 40 lines.
8. Add a row to the Active table in `.shoal-dev/INDEX.md`: `| <id> | <tier> | design | <next step> |`, where `<id>` is the item directory name.
9. STOP. Show the item path, the goal restated in one plain sentence, a 3-line summary of the design, and any Unknown still open, and ask the user to approve it; say that approval also authorizes one commit per accepted slice on the current branch (never a push). Do not implement or dispatch implementation before approval.

If the init.sh stderr reported a legacy `dev/docs` or `dev/tasks`, offer to move that content to `.shoal-dev/legacy/`. Ask first. Never move automatically. Move only what the user confirms.

Language: write `design.md` and `ledger.md` in Chinese; headings and fixed keys (`Base:`, `Ruling:`) stay in English.

Templates: `${CLAUDE_SKILL_DIR}/templates/design.md`, `${CLAUDE_SKILL_DIR}/templates/ledger.md`.
Tests for the script: `bash ${CLAUDE_SKILL_DIR}/test.sh`.
