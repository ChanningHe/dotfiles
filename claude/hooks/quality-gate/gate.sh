#!/usr/bin/env bash
# Stop / SubagentStop quality gate: run <repo>/.claude/check, block (exit 2) when it fails.
# UserPromptSubmit only records the tree the turn started from; a turn that leaves it untouched is not gated.
# Fail-open on any internal problem. Never writes to stdout, never modifies the repo.

MAX_BLOCKS=3
TAIL_LINES=40
TIMEOUT_SECS="${CLAUDE_QUALITY_GATE_TIMEOUT:-300}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-quality-gate"
RUN_DIR="${XDG_RUNTIME_DIR:-/tmp}/claude-quality-gate"

warn() { echo "quality-gate: $*" >&2; }
sha1() { if command -v sha1sum >/dev/null 2>&1; then sha1sum | cut -d' ' -f1; else shasum | cut -d' ' -f1; fi; }

# --- parse hook input: cwd, session_id, stop_hook_active, hook_event_name, background task count (one per line) ---
INPUT="$(cat)"
if command -v jq >/dev/null 2>&1; then
  FIELDS="$(printf '%s' "$INPUT" | jq -r '[(.cwd // ""), (.session_id // ""), ((.stop_hook_active // false) | tostring), (.hook_event_name // ""), ((.background_tasks // []) | length | tostring)] | .[]' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  FIELDS="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("cwd") or "")
print(d.get("session_id") or "")
print("true" if d.get("stop_hook_active") else "false")
print(d.get("hook_event_name") or "")
print(len(d.get("background_tasks") or []))' 2>/dev/null)"
else
  warn "neither jq nor python3 found; gate disabled"
  exit 0
fi
{ read -r CWD; read -r SESSION_ID; read -r ACTIVE; read -r EVENT; read -r BG_TASKS; } <<<"$FIELDS"
[ -n "$FIELDS" ] || exit 0
# Main-thread Stop while background work (e.g. an implementer subagent) is still editing the tree:
# the tree is half-done, so do not gate. SubagentStop is unaffected.
case "$BG_TASKS" in ''|*[!0-9]*) BG_TASKS=0;; esac
if [ "$EVENT" = "Stop" ] && [ "$BG_TASKS" -gt 0 ]; then exit 0; fi
[ -n "$CWD" ] || CWD="$PWD"

# --- 1/2: repo + opt-in check script ---
cd "$CWD" 2>/dev/null || exit 0
export GIT_OPTIONAL_LOCKS=0
REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
CHECK="$REPO/.claude/check"
[ -f "$CHECK" ] && [ -x "$CHECK" ] || exit 0
cd "$REPO" || exit 0

# --- 3: working-tree state ---
state_of_tree() {
  git diff HEAD --no-ext-diff --no-textconv 2>/dev/null || { git diff --cached; git diff; }
  git ls-files -z --others --exclude-standard | while IFS= read -r -d '' f; do
    printf '%s\n' "$f"
    git hash-object -- "$f" 2>/dev/null
  done
}
SAFE_SID="$(printf '%s' "${SESSION_ID:-nosession}" | tr -c 'A-Za-z0-9_-' '_')"
COUNTER_FILE="$RUN_DIR/$SAFE_SID"
BASE_FILE="$RUN_DIR/$SAFE_SID.base"

if [ "$EVENT" = "UserPromptSubmit" ]; then
  mkdir -p "$RUN_DIR" 2>/dev/null && state_of_tree | sha1 >"$BASE_FILE" 2>/dev/null
  exit 0
fi
[ -n "$(git status --porcelain 2>/dev/null)" ] || exit 0
STATE="$(state_of_tree | sha1)"
# Tree untouched since the prompt: any failure predates this turn and is not its job to fix.
if [ -f "$BASE_FILE" ] && [ "$(cat "$BASE_FILE" 2>/dev/null)" = "$STATE" ]; then exit 0; fi

# --- 4: skip when this exact state already passed ---
REPO_KEY="$(printf '%s' "$REPO" | sha1)"
STATE_FILE="$STATE_DIR/$REPO_KEY"
reset_counter() { rm -f "$COUNTER_FILE" 2>/dev/null; }

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE" 2>/dev/null)" = "$STATE" ]; then
  reset_counter
  exit 0
fi

# --- 5: run the check ---
OUTFILE="$(mktemp 2>/dev/null)" || exit 0
trap 'rm -f "$OUTFILE"' EXIT
RUNNER=()
if command -v timeout >/dev/null 2>&1; then RUNNER=(timeout -k 5 "$TIMEOUT_SECS")
elif command -v gtimeout >/dev/null 2>&1; then RUNNER=(gtimeout -k 5 "$TIMEOUT_SECS"); fi
"${RUNNER[@]}" "$CHECK" </dev/null >"$OUTFILE" 2>&1
RC=$?

if [ "$RC" -eq 0 ]; then
  mkdir -p "$STATE_DIR" 2>/dev/null && printf '%s' "$STATE" >"$STATE_FILE" 2>/dev/null
  reset_counter
  exit 0
fi

# --- 6: failure; retry cap ---
BLOCKS=0
[ -f "$COUNTER_FILE" ] && BLOCKS="$(cat "$COUNTER_FILE" 2>/dev/null)"
case "$BLOCKS" in ''|*[!0-9]*) BLOCKS=0;; esac
if [ "$ACTIVE" = "true" ] && [ "$BLOCKS" -ge "$MAX_BLOCKS" ]; then
  warn ".claude/check still failing after $MAX_BLOCKS blocks (exit $RC); letting the turn end. A human should look."
  exit 0
fi
mkdir -p "$RUN_DIR" 2>/dev/null && printf '%s' "$((BLOCKS + 1))" >"$COUNTER_FILE" 2>/dev/null

if [ "$RC" -eq 124 ] && [ "${#RUNNER[@]}" -gt 0 ]; then
  echo "quality-gate: .claude/check timed out after ${TIMEOUT_SECS}s (exit $RC). Fix the failures before finishing." >&2
else
  echo "quality-gate: .claude/check failed (exit $RC). Fix the failures before finishing." >&2
fi
tail -n "$TAIL_LINES" "$OUTFILE" >&2
exit 2
