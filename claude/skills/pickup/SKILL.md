---
name: pickup
description: Use at the start of a session to resume an existing .shoal-dev item; not for starting new work (use kickoff) or for repos without .shoal-dev.
argument-hint: [id]
disable-model-invocation: true
---

# Pickup

Resume an item from its records with minimal reading. Trust git over the ledger.

1. Read `.shoal-dev/INDEX.md`. Choose the item from `$ARGUMENTS` (id or unique substring); if empty and several are active, list them and ask.
2. If there is no `.shoal-dev/` but `dev/docs` or `dev/tasks` exist, tell the user and offer to migrate them into `.shoal-dev/legacy/`. Ask first; never move automatically. Then stop unless they accept or decline.
3. Read the item's `ledger.md`, or `design.md` when there is no ledger. Then read only the files it references; do not scan the directory.
4. Verify against reality:
   - `git log --oneline -10` and `git status --short`.
   - Run `.claude/check` from the repo root if present.
   - Compare with the ledger's Status and Next. Where they differ, git and the check win; list each discrepancy.
5. Summarize in at most 10 lines: goal, status, what changed since the ledger, discrepancies, open issues (top 3), and the proposed next step.
6. Ask the user to confirm the next step before doing anything. Do not start work, dispatch agents, or edit the ledger until they confirm. After confirmation, fix the ledger discrepancies you listed.
