#!/usr/bin/env bash
# Tests for validate.sh. Usage: bash test.sh
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0 FAIL=0
# t <expected exit> <description> <command string as the Bash tool would receive it>
t() {
  local rc
  jq -n --arg c "$3" '{tool_input:{command:$c}}' | bash "$HERE/validate.sh" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$1" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL - $2 (expected $1, got $rc)"; fi
}

t 0 "non-commit command"            'ls -la'
t 0 "git commit-graph is not ours"  'git commit-graph write'
t 0 "subject only"                  'git commit -m "fix(a): ok"'
t 0 "scope is optional"             'git commit -m "fix: ok"'
t 2 "not conventional"              'git commit -m "bad message"'
t 2 "unknown type"                  'git commit -m "wip(a): ok"'
t 2 "trailing period"               'git commit -m "fix(a): ok."'
t 2 "subject over 50 chars"         'git commit -m "fix(a): this subject line is far too long to be accepted"'
t 2 "multi-line -m carries a body"  $'git commit -m "fix(a): ok\n\nbody here"'
t 0 "heredoc, subject only"         $'git commit -m "$(cat <<\'EOF\'\nfix(a): ok\nEOF\n)"'
t 2 "heredoc with a body"           $'git commit -m "$(cat <<\'EOF\'\nfix(a): ok\n\nwhy text\nEOF\n)"'
t 0 "heredoc of an earlier command" $'python3 - <<\'EOF\'\nprint(1)\nEOF\ngit add f && git commit -m "fix(a): ok"'
t 0 "text after the heredoc ends"   $'git commit -m "$(cat <<\'EOF\'\nfix(a): ok\nEOF\n)" && git log --oneline -1'

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
