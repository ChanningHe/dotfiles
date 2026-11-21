---
name: delegate
description: Use when handing a bounded slice of a T2/T3 item to a subagent (researcher, architect, coder, designer, debugger, tester, reviewer); not for inline edits under 20 lines or work without a written design.
---

# Delegate

One slice = one brief file = one agent = one report file. Dispatch passes paths only; never paste context into the prompt.

1. Locate the item directory `ITEM` (`.shoal-dev/<id>/`). Number the slice `N` (next unused `sN`).
2. Write `ITEM/sN.brief.md` from `${CLAUDE_SKILL_DIR}/templates/brief.md`:
   - Use absolute paths everywhere, including the absolute report path `ITEM/sN.report.md`.
   - Copy the user's words verbatim into the brief.
   - Write the brief in Chinese and keep the template's language line, so the agent's report is in Chinese too.
   - Acceptance criteria must be checkable by command; list files in scope and out of scope.
3. Choose the agent by slice kind: researcher (library or web question), architect (design decision), coder (implement a brief), designer (how UI looks and feels; acceptance is screenshots, so the brief names the viewports and states to capture), debugger (bug hunt), tester (verification), reviewer (fresh-context review of a finished change).
4. Dispatch with a prompt that contains only the brief path, for example: `Brief: <abs path to sN.brief.md>`.
   `reviewer` cannot write files: its final message is the report; save it to `ITEM/sN.report.md` yourself. Its diff is `git diff <Base>`, with `Base` from `design.md`.
5. On return, read `ITEM/sN.report.md`. Reports are claims. Spot-check one artifact: rerun `.claude/check` if it exists, or read the key hunk of the diff; for a `designer` slice, open the screenshots. Compare it with the report.
6. If the check disagrees or an acceptance criterion is missed, send the fix request to the same agent with SendMessage (cite the criterion). After two misses on the same slice, change the slice boundary or the agent; do not retry a third time unchanged.
7. Slice accepted: commit it yourself. One conventional commit on the current branch, staging only the paths the slice touched (never `git add -A`). If a file had uncommitted changes before the item started, ask first. A worktree lane is integrated into the main tree before its commit. Then append `<short hash> <subject>` under Commits in `design.md`: commit messages carry no item id, so this list is the only link between the item and its commits.
8. If `ITEM/ledger.md` exists, update the lane's row (state, report path, open issues). Rewrite in place.

Parallelism: sequential by default. Run slices in parallel only when their files in scope are disjoint and each runs in its own worktree (`isolation: "worktree"`): the quality gate checks the whole tree, so a half-done sibling lane fails yours. Never run a review in parallel with the edits under review.
Never commit or push through a subagent. The main thread integrates, commits and reports; it never pushes unasked.

Templates: `${CLAUDE_SKILL_DIR}/templates/brief.md`, `${CLAUDE_SKILL_DIR}/templates/report.md` (the agent writes the report in this shape).
