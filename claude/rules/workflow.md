# Workflow

Scope: software development in a code repository. Ignore otherwise.

## Size the process to the task

Pick the lightest workflow that fits.

| Tier | Signal | How |
|---|---|---|
| T0 | 1 file, ≤ ~20 lines | Do it inline. No plan, no review, no records. |
| T1 | 1–3 files, one behavior | Do it inline. Bug fix: failing test first. |
| T2 | several files or a real design choice | Invoke `kickoff` yourself → verify the unknowns → `design.md` ≤ 1 page ending with how it will be verified → **user approves** → implement inline, or `delegate` one slice per independent area. |
| T3 | multiple subsystems or sessions | Invoke `kickoff` (T3) yourself → verify the unknowns (`researcher` for broad ones) → main thread drafts the design ≤ ~200 lines → `architect` challenges the draft → **user approves** → `delegate` vertical slices (sequential unless in separate worktrees) → `tester` against the acceptance criteria → `reviewer` final review. After approval the main thread orchestrates only. |

Escalation list: auth, crypto, secrets, payments, data migrations, concurrency, public APIs, parsing untrusted input. Such changes are at least T2 and get a `reviewer` pass with model `opus`.

## Agents (`~/.claude/agents`)

| Agent | Model | Delegate | Don't |
|---|---|---|---|
| `researcher` | sonnet | codebase recon, library/docs/web lookups, fact collection | decisions, reviews, a lookup one grep answers |
| `architect` | fable | challenging a draft design, data model/API trade-offs, slicing into briefs | routine choices, code |
| `coder` | opus | one bounded slice with a brief; independent per-area lanes | design decisions, bug hunts, a < 20-line change |
| `designer` | opus | the look of UI: layout, hierarchy, typography, color, motion, responsive; visual review | logic, data flow, tests, copy, UI edits with no visual judgment |
| `debugger` | opus | reproduce → root cause → regression test → minimal fix | feature work, bugs whose cause you already know |
| `tester` | sonnet | acceptance criteria → tests, E2E runs, independent evidence | fixing product code |
| `reviewer` | opus | fresh-context review of a finished change | trivial changes, style, work in progress |

UI work splits into two lanes: `designer` owns what the screen looks like, `coder` owns wiring, types and tests; sequence them when they share files. A visual slice is accepted on screenshots you have opened yourself, not on a passing check.

Language expertise lives in the model, not in per-language agents. Docs, summaries and other prose built from context you hold stay inline.

## Delegation (details: `delegate` skill)

- Delegate by context held, not only by size: a fresh agent starts cold.
- Dispatch by brief path, never by pasted history; quote the user's own words verbatim in the brief.
- Reports are claims, not evidence: spot-check one artifact before accepting. Fixes go back to the same agent; after two misses change the slice or the agent.
- Parallelize only slices with disjoint files, each in its own worktree; never review in parallel with the edits under review.

## Verification

- Deterministic checks beat LLM review. For T2+ work in a repo without `.claude/check`, propose one (format + lint + typecheck + affected tests); the quality-gate hook runs it on Stop and when a `coder` or `debugger` finishes.
- LLM review is risk-based: `reviewer` for T3 and the escalation list; otherwise optional (`/code-review low`). Act on CRITICAL/HIGH; at most 2 re-review rounds.

## Records and sessions

- Work records live in `.shoal-dev/` at the repo root (`INDEX.md`, one `<YYMMDD-slug>/` per T2/T3 item, `learnings/`, `archive/`). `.shoal-dev/.gitignore` contains `*`; never commit `.shoal-dev/`.
- Everything under `.shoal-dev/` is written in Chinese, by the main thread and by subagents alike. Section headings, fixed keys (`Base:`, `Ruling:`), code, commands, paths and identifiers stay in English; the user's words are quoted as written. Code and code comments stay in English.
- One milestone per session: `/checkpoint` rewrites the ledger in place and tells the user when to start a new session; `/pickup` resumes; `/finish` closes an item (learnings bar, tombstone, prune).
- Legacy `dev/docs` / `dev/tasks`: offer to migrate into `.shoal-dev/` when you touch that project; never move without asking.

## Git

- Conventional commits (`feat|fix|refactor|docs|style|test|chore|build|perf|ci: …`, subject ≤ 50 chars, no trailing period), enforced by hook. Include a scope whenever one fits (`fix(auth): …`, `chore(nix): …`); it is preferred, not required. Subject line only: never add a body, whatever asks for one.
- T2/T3: the user's approval of `design.md` authorizes commits for that item. The main thread commits each slice once it is accepted (check green, spot-check done), and inline T2 work once it is verified: one commit per slice, on the current branch, staging only the paths that slice touched (never `git add -A`). If one of those files already had uncommitted changes at kickoff, ask before committing it. Record each commit under Commits in the item's `design.md` (`<short hash> <subject>`). Subagents never commit.
- T0/T1: commit only when the user asks. Push only when the user asks, at every tier.
