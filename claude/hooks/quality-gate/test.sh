#!/usr/bin/env bash
# Tests for gate.sh. Plain bash; all repos live under mktemp -d and are removed on exit.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/gate.sh"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

export HOME="$ROOT/home" XDG_STATE_HOME="$ROOT/state" XDG_RUNTIME_DIR="$ROOT/run"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME"

PASS=0 FAIL=0
n=0
ok()  { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1 ${2:+($2)}"; }
eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "expected '$2', got '$3'"; }

# new_case: sets CASE (scratch dir), REPO, MARKER, SID
new_case() {
  n=$((n + 1))
  CASE="$ROOT/case$n"; REPO="$CASE/repo"; MARKER="$CASE/marker"; SID="sess$n"
  mkdir -p "$REPO"
  git -C "$REPO" init -q
  echo base >"$REPO/f.txt"
}
# set_check <body>: install an executable .claude/check that records each run in $MARKER
set_check() {
  mkdir -p "$REPO/.claude"
  printf '#!/usr/bin/env bash\necho run >>"%s"\npwd >"%s.pwd"\n%s\n' "$MARKER" "$MARKER" "$1" >"$REPO/.claude/check"
  chmod +x "$REPO/.claude/check"
}
commit_all() { git -C "$REPO" add -A && git -C "$REPO" commit -qm init; }
dirty()      { echo "change $RANDOM$RANDOM" >>"$REPO/f.txt"; }
runs()       { [ -f "$MARKER" ] && wc -l <"$MARKER" | tr -d ' ' || echo 0; }
# gate <cwd> [stop_hook_active]: sets OUT, ERR, RC
gate() {
  local json; json=$(printf '{"cwd":"%s","session_id":"%s","stop_hook_active":%s}' "$1" "$SID" "${2:-false}")
  OUT=$(printf '%s' "$json" | bash "$GATE" 2>"$CASE/err"); RC=$?
  ERR=$(cat "$CASE/err")
}

# 1. not a repo
new_case; mkdir "$CASE/plain"; gate "$CASE/plain"
eq "not a repo: exit 0" 0 "$RC"; eq "not a repo: silent stdout" "" "$OUT"

# 2. no check script
new_case; commit_all; dirty; gate "$REPO"
eq "no check script: exit 0" 0 "$RC"

# 3. check not executable
new_case; set_check 'exit 1'; chmod -x "$REPO/.claude/check"; commit_all; dirty; gate "$REPO"
eq "non-executable check: exit 0" 0 "$RC"; eq "non-executable check: not run" 0 "$(runs)"

# 4. clean tree
new_case; set_check 'exit 1'; commit_all; gate "$REPO"
eq "clean tree: exit 0" 0 "$RC"; eq "clean tree: check not run" 0 "$(runs)"

# 5. failing check: exit 2, stderr message + last 40 lines, nothing on stdout, cwd=repo root
new_case; set_check 'for i in $(seq 1 60); do echo "line$i"; done; exit 3'; commit_all; dirty
mkdir "$REPO/sub"; gate "$REPO/sub"
eq "failing check: exit 2" 2 "$RC"
case "$ERR" in *"quality-gate: .claude/check failed (exit 3). Fix the failures before finishing."*) ok "failing check: message";; *) bad "failing check: message" "$ERR";; esac
case "$ERR" in *line60*) ok "failing check: tail has last line";; *) bad "failing check: tail has last line";; esac
case "$ERR" in *line21*) ok "failing check: tail starts at line21";; *) bad "failing check: tail starts at line21";; esac
case "$ERR" in *line20*) bad "failing check: tail limited to 40 lines";; *) ok "failing check: tail limited to 40 lines";; esac
eq "failing check: silent stdout" "" "$OUT"
eq "failing check: ran from repo root" "$(cd "$REPO" && pwd -P)" "$(cd "$(cat "$MARKER.pwd")" && pwd -P)"

# 6. passing check: exit 0, state recorded
new_case; set_check 'exit 0'; commit_all; dirty; gate "$REPO"
eq "passing check: exit 0" 0 "$RC"; eq "passing check: ran once" 1 "$(runs)"
eq "passing check: state recorded" 1 "$(find "$XDG_STATE_HOME/claude-quality-gate" -type f 2>/dev/null | wc -l | tr -d ' ')"
eq "passing check: silent stdout" "" "$OUT"

# 7. unchanged state after pass -> skipped; changed tracked/untracked -> runs again; ignored -> skipped
gate "$REPO"; eq "unchanged state: exit 0" 0 "$RC"; eq "unchanged state: check not re-run" 1 "$(runs)"
echo x >"$REPO/new.txt"; gate "$REPO"; eq "new untracked file: check re-run" 2 "$(runs)"
gate "$REPO"; eq "state re-recorded: skipped" 2 "$(runs)"
echo y >"$REPO/new.txt"; gate "$REPO"; eq "untracked content change: check re-run" 3 "$(runs)"
dirty; gate "$REPO"; eq "tracked change: check re-run" 4 "$(runs)"
printf 'ign.log\n' >"$REPO/.gitignore"; commit_all; dirty; gate "$REPO"; eq "after commit+dirty: re-run" 5 "$(runs)"
echo z >"$REPO/ign.log"; gate "$REPO"; eq "ignored file: not part of state" 5 "$(runs)"

# 8. retry cap with stop_hook_active=true: 3 blocks then release; pass resets
new_case; set_check 'exit 1'; commit_all; dirty
gate "$REPO" false; eq "cap: block 1 (active=false)" 2 "$RC"
gate "$REPO" true;  eq "cap: block 2" 2 "$RC"
gate "$REPO" true;  eq "cap: block 3" 2 "$RC"
gate "$REPO" true;  eq "cap: 4th released" 0 "$RC"
case "$ERR" in *quality-gate*) ok "cap: notice on stderr";; *) bad "cap: notice on stderr" "$ERR";; esac
eq "cap: silent stdout" "" "$OUT"
set_check 'exit 0'; dirty; gate "$REPO" true; eq "cap: pass exit 0" 0 "$RC"
set_check 'exit 1'; dirty; gate "$REPO" true; eq "cap: counter reset after pass" 2 "$RC"

# 9. without stop_hook_active the cap never applies
new_case; set_check 'exit 1'; commit_all; dirty
for _ in 1 2 3 4 5; do gate "$REPO" false; [ "$RC" = 2 ] || break; done
eq "no cap when stop_hook_active=false" 2 "$RC"

# 10. timeout honored
new_case; set_check 'sleep 30 & wait'; commit_all; dirty
start=$SECONDS; export CLAUDE_QUALITY_GATE_TIMEOUT=1; gate "$REPO"; unset CLAUDE_QUALITY_GATE_TIMEOUT
eq "timeout: exit 2" 2 "$RC"
[ $((SECONDS - start)) -lt 15 ] && ok "timeout: returned promptly" || bad "timeout: returned promptly" "$((SECONDS - start))s"
case "$ERR" in *"timed out"*) ok "timeout: says timed out";; *) bad "timeout: says timed out" "$ERR";; esac

# 11. repo without commits still works
new_case; set_check 'exit 1'; gate "$REPO"
eq "unborn HEAD: exit 2" 2 "$RC"

# 12. never modifies the repo
new_case; set_check 'exit 0'; commit_all; dirty
before=$(git -C "$REPO" status --porcelain=v1 -uall; git -C "$REPO" diff HEAD | sha1sum)
gate "$REPO"
after=$(git -C "$REPO" status --porcelain=v1 -uall; git -C "$REPO" diff HEAD | sha1sum)
eq "repo unmodified by gate" "$before" "$after"

# 12b. Stop with in-flight background tasks -> skipped; SubagentStop unaffected
raw_gate() { # raw_gate <json>
  OUT=$(printf '%s' "$1" | bash "$GATE" 2>"$CASE/err"); RC=$?; ERR=$(cat "$CASE/err")
}
ev_json() { # ev_json <event> <background_tasks json or ''>
  printf '{"cwd":"%s","session_id":"%s","hook_event_name":"%s","stop_hook_active":false%s}' \
    "$REPO" "$SID" "$1" "${2:+,\"background_tasks\":$2}"
}
BG='[{"id":"t1","type":"subagent","status":"running","description":"impl","agent_type":"implementer"}]'
new_case; set_check 'exit 1'; commit_all; dirty
raw_gate "$(ev_json Stop "$BG")"
eq "Stop + running background task: exit 0" 0 "$RC"; eq "Stop + running background task: check not run" 0 "$(runs)"
raw_gate "$(ev_json SubagentStop "$BG")"
eq "SubagentStop + background task: still blocks" 2 "$RC"; eq "SubagentStop + background task: check ran" 1 "$(runs)"
new_case; set_check 'exit 1'; commit_all; dirty
raw_gate "$(ev_json Stop '[]')"; eq "Stop + empty background_tasks: blocks" 2 "$RC"
raw_gate "$(ev_json Stop '')";   eq "Stop + absent background_tasks: blocks" 2 "$RC"
eq "Stop + no background tasks: check ran twice" 2 "$(runs)"

# 13. python3 fallback when jq is absent; neither -> warn + exit 0
BIN="$ROOT/bin"; mkdir -p "$BIN"
for c in bash env git sha1sum shasum timeout cat tail head mkdir date sed tr rm mktemp dirname basename wc sort xargs grep cut mv sleep seq pwd printf uname; do
  p=$(command -v "$c") && [ -x "$p" ] && ln -sf "$p" "$BIN/$c"
done
new_case; set_check 'exit 1'; commit_all; dirty
json=$(printf '{"cwd":"%s","session_id":"%s","stop_hook_active":false}' "$REPO" "$SID")
if command -v python3 >/dev/null; then
  ln -sf "$(command -v python3)" "$BIN/python3"
  printf '%s' "$json" | PATH="$BIN" bash "$GATE" >/dev/null 2>&1; eq "python3 fallback (no jq): blocks" 2 $?
  printf '%s' "$(ev_json Stop "$BG")" | PATH="$BIN" bash "$GATE" >/dev/null 2>&1; eq "python3 fallback: Stop + background task skipped" 0 $?
  rm "$BIN/python3"
fi
OUT=$(printf '%s' "$json" | PATH="$BIN" bash "$GATE" 2>"$CASE/err"); RC=$?
eq "no jq, no python3: exit 0" 0 "$RC"
[ -s "$CASE/err" ] && ok "no jq, no python3: warns on stderr" || bad "no jq, no python3: warns on stderr"

# 14. malformed stdin fails open
new_case; OUT=$(printf 'not json' | bash "$GATE" 2>/dev/null); RC=$?
eq "malformed stdin: exit 0" 0 "$RC"

echo "---"; echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
