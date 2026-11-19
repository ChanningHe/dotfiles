# quality-gate

Deterministic Stop / SubagentStop hook. Runs the project's own `<repo>/.claude/check`
and blocks completion (exit 2, stderr = last 40 lines) when it fails.

Opt-in per project: no git repo, no executable `.claude/check`, or a clean tree -> no-op.
Needs git plus jq or python3 (otherwise warns and exits 0). Never writes to stdout or the repo.

- Skips re-running when the working-tree state (git diff HEAD + untracked files) already passed.
  State: `${XDG_STATE_HOME:-~/.local/state}/claude-quality-gate/<sha1(repo root)>`.
- `Stop` with a non-empty `background_tasks` array (docs: hooks.md, Stop input) -> no-op, since a
  background subagent may still be editing the tree. `SubagentStop` is unaffected.
- Turn baseline: on `UserPromptSubmit` the gate only records the tree state
  (`${XDG_RUNTIME_DIR:-/tmp}/claude-quality-gate/<session_id>.base`). A `Stop` / `SubagentStop` on that same
  state is a no-op: the turn changed nothing, so a red check is pre-existing (user WIP, `/pickup`, a question).
- Timeout: `CLAUDE_QUALITY_GATE_TIMEOUT` seconds (default 300), uses `timeout`/`gtimeout` if present.
- Retry cap: with `stop_hook_active` true, after 3 consecutive blocks per session the gate lets the
  turn end with a stderr notice. Counter: `${XDG_RUNTIME_DIR:-/tmp}/claude-quality-gate/<session_id>`,
  reset on pass.

Register (settings.json):
    "Stop": [{"hooks": [{"type": "command", "command": "bash \"$HOME/.claude/hooks/quality-gate/gate.sh\"", "timeout": 330}]}]
    "SubagentStop": same entry
    "UserPromptSubmit": same command, short timeout (records the baseline, never blocks)

Test: `bash test.sh` (temp repos under mktemp -d).
