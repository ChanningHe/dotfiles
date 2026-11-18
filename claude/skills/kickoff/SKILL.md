---
name: kickoff
description: Use when starting a T2/T3 work item that needs a design note the user approves; not for T0/T1 edits or resuming existing work (use pickup).
argument-hint: <slug> [T2|T3]
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/init.sh *)
---

# Kickoff

Create the work record for one item, then stop for approval. Nothing is written outside `.work/`.

1. Pick slug (`[a-z0-9-]+`) and tier from `$ARGUMENTS`; default tier T2. If the slug is missing, derive one from the task and say which you chose.
2. Run `${CLAUDE_SKILL_DIR}/init.sh <slug> [T2|T3]` from inside the repo. Stdout is the item path (`ITEM`). On exit 1, report the stderr message and stop; never work around a refusal (for example by deleting or untracking files).
3. Fill `ITEM/design.md` from the conversation, following the template headings:
   - Problem: the user's words, verbatim, quoted. No paraphrase.
   - Rulings: one per line, as `Ruling: what — why — cost if wrong`.
   - Design and Slices (T3): short; data structures and interfaces first.
   - How we verify: exactly 3 lines.
4. T3 only: fill `ITEM/ledger.md` (Status, Next, Decisions, Running lanes, Open issues, References), at most 40 lines.
5. Add a row to the Active table in `.work/INDEX.md`: `| <id> | <tier> | design | <next step> |`, where `<id>` is the item directory name.
6. If the init.sh stderr reported a legacy `dev/docs` or `dev/tasks`, offer to move that content to `.work/legacy/`. Ask first. Never move automatically. Move only what the user confirms.
7. STOP. Show the item path and a 3-line summary of the design, and ask the user to approve it. Do not dispatch or implement before approval.

Templates: `${CLAUDE_SKILL_DIR}/templates/design.md`, `${CLAUDE_SKILL_DIR}/templates/ledger.md`.
Tests for the script: `bash ${CLAUDE_SKILL_DIR}/test.sh`.
