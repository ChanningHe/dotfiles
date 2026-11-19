# Workflow skills

Five skills drive the tiered workflow (`../rules/workflow.md`) and keep work records in `.shoal-dev/`.

## Typical flow

```text
/kickoff add-auth T3   # start: verify unknowns, draft the design, then wait for your approval
                       # ...approve; Claude hands slices to subagents via `delegate`
/checkpoint            # at a milestone: save state, then maybe start a new session
/pickup                # new session: continue where you left off
/finish                # done: keep what you learned, archive, clean up
```

## Commands

| Command | Use it when | What it does |
|---|---|---|
| `/kickoff <slug> [T2\|T3]` | Starting a multi-file change or anything that needs a design (default T2); Claude also invokes it on its own when a task sizes as T2/T3 | Creates `.shoal-dev/<YYMMDD-slug>/`, resolves the design's unknowns (reading code, or `researcher`), drafts `design.md` (plus `ledger.md` for T3), has `architect` challenge a T3 or escalation-list draft, adds it to `INDEX.md`, then **stops for your approval** |
| `delegate` | Claude uses it on its own when handing a slice to a subagent; you can also type `/delegate` | Writes `sN.brief.md`, dispatches the right agent with only that path, spot-checks the report, updates the ledger |
| `/checkpoint` | A milestone is reached, you are pausing, or the context is getting long (T3) | Rewrites `ledger.md` in place (≤ 40 lines), updates `INDEX.md`, tells you if it is a good moment for a new session |
| `/pickup [id]` | Starting a new session on existing work | Reads `INDEX.md` → ledger → only the files it references, checks them against `git log` and `.claude/check`, then confirms the next step with you |
| `/finish [id]` | The item is done and its checks pass | Keeps a lesson only if it is worth it (a test or check first, then a CLAUDE.md line, then a note), writes a short tombstone to `archive/`, deletes the item folder after you confirm |

Which tier uses what:
- **T0/T1**: no skills and no records.
- **T2**: `/kickoff`, then `delegate` if needed, then `/finish`.
- **T3**: all five.

## The `.shoal-dev/` folder

```text
.shoal-dev/                 at the repo root; never committed (.shoal-dev/.gitignore contains "*")
  INDEX.md             active items, learnings, out-of-scope ideas
  <YYMMDD-slug>/       one work item
    design.md          base commit, problem (your words), unknowns, rulings, design, how we verify
    research.md        researcher's notes, when unknowns needed one
    design.review.md   architect's challenge of the draft (T3 / escalation list)
    ledger.md          T3 state: status, next step, decisions, open issues
    sN.brief.md        task for a subagent
    sN.report.md       the subagent's report
  learnings/           lessons worth keeping
  archive/             ≤ 15-line summaries of finished items
```

## Notes

- Everything under `.shoal-dev/` is written in Chinese (headings, fixed keys, code and paths stay in English).

- `/kickoff` only runs inside a git repo. It refuses if any file under `.shoal-dev/` is tracked by git.
- Old `dev/docs` and `dev/tasks` folders are not moved automatically. `/kickoff` and `/pickup` offer to migrate them.
- Run the script tests with `bash kickoff/test.sh`.
