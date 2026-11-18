# Workflow

Scope: software development in a code repository. Ignore otherwise.

## Size the process to the task

Pick the lightest workflow that fits.

| Tier | Signal | How |
|---|---|---|
| T0 | 1 file, ≤ ~20 lines | Do it inline. No plan, no review. |
| T1 | 1–3 files, one behavior | Do it inline. Bug fix: failing test first. |
| T2 | several files or a real design choice | Plan mode → design note ≤ 1 page in `dev/docs/<topic>.md`, ending with 3 lines on how it will be verified → **user approves** → implement inline, or one `coder` per independent slice. |
| T3 | multiple subsystems or sessions | Main thread orchestrates only. `researcher` → `architect` design ≤ ~200 lines (**user approves**) → vertical slices in `dev/tasks/<topic>.md` → one `coder` per slice (sequential unless in separate worktrees) → `tester` against the acceptance criteria → `reviewer` final review. |

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

## Delegation contract

- Delegate by context held, not only by size: small clear changes and work that is mostly context you already hold stay inline; a fresh agent starts cold.
- Pass references, not history. The brief lives in `dev/tasks/<topic>.md`: goal, acceptance criteria, files in scope, constraints, and the user's own words quoted verbatim. Give the agent its path; it writes its report there and replies in ≤ 15 lines.
- Reports are claims, not evidence: they list commands with exit codes and what stayed unverified. Spot-check one artifact (rerun `.claude/check`, read the key hunk) before accepting. Missing scope and out-of-scope extras are both defects.
- Send fixes back to the same agent (SendMessage). If a delegation misses twice, change the slice boundary or the agent, not the prompt length.
- Parallelize only independent slices with disjoint files. Never run a review in parallel with the edits it reviews.

## Verification

- Deterministic checks beat LLM review. For T2+ work in a repo without `.claude/check`, propose one (format + lint + typecheck + affected tests); the quality-gate hook runs it on Stop and when a `coder` or `debugger` finishes.
- LLM review is risk-based: `reviewer` for T3 and the escalation list; otherwise optional (`/code-review low` for a quick look). Act on CRITICAL/HIGH; at most 2 re-review rounds, each only for materially changed risk.

## Sessions

- One milestone per session. At a milestone, update the ledger and tell the user it is a good point to start a new session. Do not drag a session toward the context limit.
- Ledger (`dev/tasks/<topic>.md`): ≤ 40 lines, rewritten in place: status, decisions, ranked open issues, next step. Briefs and reports may follow below it.
- At the start of dev work, read `dev/docs/` and `dev/tasks/` for existing context.

## Artifacts and git

- `dev/docs/` (plans, designs) and `dev/tasks/` (ledgers, briefs, reports) are git-excluded and local only. Never put plans in tracked paths.
- Conventional commits (`feat|fix|refactor|docs|test|chore|perf|ci: …`), enforced by hook. Commit or push only when the user asks.
