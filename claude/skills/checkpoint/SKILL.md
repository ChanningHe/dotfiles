---
name: checkpoint
description: Use at a milestone, before a long pause, or when context is getting heavy in a T3 item, to save state to its ledger; not for T0-T2 work without a ledger or as an activity log.
---

# Checkpoint

Rewrite the item's state so a fresh session can continue from it. The ledger is a state file, never a log.

1. Find the item: `.shoal-dev/INDEX.md` Active table, or the item the conversation is about. If several are active and it is unclear which, ask.
2. Rewrite `.shoal-dev/<id>/ledger.md` in place, at most 40 lines, with exactly these sections:
   - Status: one line.
   - Next: the single next action.
   - Decisions: settled choices not obvious from code/git.
   - Running lanes: agent, slice, brief path, state. Remove finished lanes.
   - Open issues: ranked by severity, highest first.
   - References: paths only (design.md, briefs, reports, research notes).
   Drop stale content. Do not append history; do not copy report bodies.
3. Update the item's row in `.shoal-dev/INDEX.md` (status and next). Keep INDEX at most 30 lines.
4. Verify before claiming: `git log --oneline -5` and `git status --short` agree with Status; fix the ledger if not.
5. Say in one line whether this is a good point for a new session: yes when no lane is running and Next is self-contained in the ledger; no otherwise, and name what must finish first.

If the item has no ledger.md (T2), update only its INDEX row and the design's open points; do not create a ledger.

Template for the ledger: `${CLAUDE_SKILL_DIR}/../kickoff/templates/ledger.md`.
