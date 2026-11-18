# Workflow

Scope: software development in a code repository. Ignore otherwise.

## Size the process to the task

Pick the lightest workflow that fits.

| Tier | Signal | How |
|---|---|---|
| T0 | 1 file, ≤ ~20 lines | Do it inline. No plan, no review, no records. |
| T1 | 1–3 files, one behavior | Do it inline. Bug fix: failing test first. |
| T2 | several files or a real design choice | `/kickoff` → `design.md` ≤ 1 page ending with how it will be verified → **user approves** → implement inline, or `delegate` one slice per independent area. |
| T3 | multiple subsystems or sessions | `/kickoff` (T3) → `researcher` → `architect` design ≤ ~200 lines (**user approves**) → `delegate` vertical slices (sequential unless in separate worktrees) → `tester` against the acceptance criteria → `reviewer` final review. Main thread orchestrates only. |

Escalation list: auth, crypto, secrets, payments, data migrations, concurrency, public APIs, parsing untrusted input. Such changes are at least T2 and get a `reviewer` pass with model `opus`.

## Agents (`~/.claude/agents`)

| Agent | Model | Delegate | Don't |
|---|---|---|---|
| `researcher` | haiku (pass `sonnet` for deep research) | codebase recon, library/docs/web lookups, fact collection | decisions, reviews, a lookup one grep answers |
| `architect` | opus | design trade-offs, data model/API decisions, slicing into briefs | routine choices, code |
| `coder` | sonnet | one bounded slice with a brief; independent per-area lanes | design decisions, bug hunts, a < 20-line change |
| `debugger` | sonnet (pass `opus` for hard cases) | reproduce → root cause → regression test → minimal fix | feature work, bugs whose cause you already know |
| `tester` | sonnet | acceptance criteria → tests, E2E runs, independent evidence | fixing product code |
| `reviewer` | sonnet (pass `opus` on the escalation list) | fresh-context review of a finished change | trivial changes, style, work in progress |

Language expertise lives in the model, not in per-language agents. Docs, summaries and other prose built from context you hold stay inline.

## Delegation (details: `delegate` skill)

- Delegate by context held, not only by size: a fresh agent starts cold.
- Dispatch by brief path, never by pasted history; quote the user's own words verbatim in the brief.
- Reports are claims, not evidence: spot-check one artifact before accepting. Fixes go back to the same agent; after two misses change the slice or the agent.
- Parallelize only slices with disjoint files; never review in parallel with the edits under review.

## Verification

- Deterministic checks beat LLM review. For T2+ work in a repo without `.claude/check`, propose one (format + lint + typecheck + affected tests); the quality-gate hook runs it on Stop and when a `coder` or `debugger` finishes.
- LLM review is risk-based: `reviewer` for T3 and the escalation list; otherwise optional (`/code-review low`). Act on CRITICAL/HIGH; at most 2 re-review rounds.

## Records and sessions

- Work records live in `.work/` at the repo root (`INDEX.md`, one `<YYMMDD-slug>/` per T2/T3 item, `learnings/`, `archive/`). `.work/.gitignore` contains `*`; never commit `.work/`.
- One milestone per session: `/checkpoint` rewrites the ledger in place and tells the user when to start a new session; `/pickup` resumes; `/finish` closes an item (learnings bar, tombstone, prune).
- Legacy `dev/docs` / `dev/tasks`: offer to migrate into `.work/` when you touch that project; never move without asking.

## Git

- Conventional commits (`feat|fix|refactor|docs|test|chore|perf|ci: …`), enforced by hook. Commit or push only when the user asks.
