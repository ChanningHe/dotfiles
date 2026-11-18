---
name: delegate
description: Use when handing a bounded slice of a T2/T3 item to a subagent (researcher, architect, coder, debugger, tester, reviewer); not for inline edits under 20 lines or work without a written design.
---

# Delegate

One slice = one brief file = one agent = one report file. Dispatch passes paths only; never paste context into the prompt.

1. Locate the item directory `ITEM` (`.work/<id>/`). Number the slice `N` (next unused `sN`).
2. Write `ITEM/sN.brief.md` from `${CLAUDE_SKILL_DIR}/templates/brief.md`:
   - Use absolute paths everywhere, including the absolute report path `ITEM/sN.report.md`.
   - Copy the user's words verbatim into the brief.
   - Acceptance criteria must be checkable by command; list files in scope and out of scope.
3. Choose the agent by slice kind: researcher (library or web question), architect (design decision), coder (implement a brief), debugger (bug hunt), tester (verification), reviewer (fresh-context review of a finished change).
4. Dispatch with a prompt that contains only the brief path, for example: `Brief: <abs path to sN.brief.md>`.
5. On return, read `ITEM/sN.report.md`. Reports are claims. Spot-check one artifact: rerun `.claude/check` if it exists, or read the key hunk of the diff. Compare it with the report.
6. If the check disagrees or an acceptance criterion is missed, send the fix request to the same agent with SendMessage (cite the criterion). After two misses on the same slice, change the slice boundary or the agent; do not retry a third time unchanged.
7. If `ITEM/ledger.md` exists, update the lane's row (state, report path, open issues). Rewrite in place.

Parallelism: run slices in parallel only when their files in scope are disjoint. Never run a review in parallel with the edits under review.
Never commit or push through a subagent. The main thread integrates and reports.

Templates: `${CLAUDE_SKILL_DIR}/templates/brief.md`, `${CLAUDE_SKILL_DIR}/templates/report.md` (the agent writes the report in this shape).
