---
name: finish
description: Use when a .shoal-dev item is done and should be closed out (tombstone, learnings, prune); not for pausing work (use checkpoint) or unfinished items.
argument-hint: [id]
disable-model-invocation: true
---

# Finish

Close one item. Keep only what future work needs.

1. Choose the item from `$ARGUMENTS` or the INDEX Active table; ask if ambiguous. Confirm it is done: run `.claude/check` if present (or the design's "How we verify" commands). Do not proceed unless green; report failures and stop.
2. Learnings bar: keep a lesson only if it would change future behavior and is not obvious from code or git. For each survivor use the cheapest durable form:
   - A test or a `.claude/check` entry (preferred; implement it or ask).
   - Else a proposed one-line addition to CLAUDE.md. Show the line and ask; never edit CLAUDE.md unasked.
   - Else `.shoal-dev/learnings/<slug>.md`, at most 15 lines, and add a line under Learnings in INDEX.
   If nothing passes the bar, record none.
3. Write the tombstone `.shoal-dev/archive/<id>.md`, at most 15 lines: outcome, commits (copied from Commits in `design.md`; if that list is empty, fall back to `git log --oneline <Base>..HEAD` and keep the item's own), follow-ups. Create `.shoal-dev/archive/` if needed.
4. Show the user the tombstone and the item directory size. Delete `.shoal-dev/<id>/` only after they confirm. Use `rm -r` on that exact path, nothing broader.
5. Update `.shoal-dev/INDEX.md`: remove the item's Active row; add follow-ups to Out of scope if any. Keep INDEX at most 30 lines.
6. Before the tombstone, commit any accepted work of the item that is still uncommitted (same rule as slices: only the item's paths, conventional message, recorded under Commits in `design.md`). Never push. Mention any other uncommitted changes if `git status --short` is non-empty.
