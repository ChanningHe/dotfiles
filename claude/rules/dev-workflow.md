# Dev Workflow

> Scope: only when doing software development in a code repository
> (planning, implementing, refactoring, reviewing). Ignore otherwise.

## Planning Artifacts

- Plans and designs go in `dev/docs/`; task lists, progress and review notes go in `dev/tasks/` (relative to the repo root).
- Both are git-excluded and local only. Never put plans in tracked paths.
- At the start of dev work, check `dev/docs/` and `dev/tasks/` for existing context.

## Execution

- Main thread orchestrates only: plan, dispatch, integrate, report. Keep it clean.
- Delegate implementation and reviews to subagents.
- Pick the model by difficulty: `opus` for architecture, complex or ambiguous work; `sonnet` for well-scoped implementation and routine review.
- Batch small or low-volume tasks (or reviews) into a single subagent.
