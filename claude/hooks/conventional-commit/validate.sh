#!/usr/bin/env bash
# PreToolUse hook: enforce Conventional Commits format on Claude's `git commit`.
#
# Only constrains commits issued by Claude (the Bash tool). Parses the commit
# subject out of the command and rejects anything that is not a valid
# Conventional Commit. Scope is optional; non-standard types are not allowed.
# The message must be the subject line alone: no body.
#
# Deps: jq + awk (both already used by other hooks / POSIX-standard).
# Exit codes: 0 = allow, 2 = block (stderr is fed back to Claude).
#
# NOTE: awk only WRITES error lines to stdout; bash owns the exit code. We do
# not rely on awk's `exit N` status, which is unreliable across awk builds.

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Real `git commit` only (skip git commit-graph, etc.)
printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+commit([[:space:]]|$)' || exit 0

awk_prog=$(cat <<'AWK'
{ buf = buf $0 "\n" }
END {
  cmd = buf
  subject = ""
  # Only the text from `git commit` on can carry the message; earlier commands in a chain are not ours.
  if (match(cmd, /git[ \t]+commit([ \t\n]|$)/)) cmd = substr(cmd, RSTART)

  if (match(cmd, /<<-?[ \t]*'?[A-Za-z_][A-Za-z0-9_]*'?/)) {
    # heredoc: subject = first non-empty line after the <<DELIM line
    delim = substr(cmd, RSTART, RLENGTH); gsub(/^<<-?[ \t]*'?|'$/, "", delim)
    rest = substr(cmd, RSTART + RLENGTH)
    nl = index(rest, "\n"); if (nl > 0) rest = substr(rest, nl + 1)
    n = split(rest, lines, "\n")
    for (i = 1; i <= n; i++) {
      t = lines[i]; gsub(/^[ \t]+|[ \t]+$/, "", t)
      if (t == delim) break
      if (t == "") continue
      if (subject == "") subject = t; else has_body = 1
    }
  } else if (match(cmd, /(-m|--message)([ \t]*=|[ \t]+)/)) {
    # -m / --message / --message= : first quoted (or bare) value
    after = substr(cmd, RSTART + RLENGTH); sub(/^[ \t]+/, "", after)
    ch = substr(after, 1, 1)
    if (ch == "\"")      { r = substr(after, 2); q = index(r, "\""); subject = (q > 0) ? substr(r, 1, q - 1) : r }
    else if (ch == "'")  { r = substr(after, 2); q = index(r, "'");  subject = (q > 0) ? substr(r, 1, q - 1) : r }
    else                 { s = index(after, " "); subject = (s > 0) ? substr(after, 1, s - 1) : after }
    nl = index(subject, "\n")
    if (nl > 0) {
      tail = substr(subject, nl + 1); gsub(/[ \t\n]/, "", tail)
      if (tail != "") has_body = 1
      subject = substr(subject, 1, nl - 1)
    }
  }

  gsub(/^[ \t]+|[ \t]+$/, "", subject)
  if (subject == "") { exit }  # editor/-F/amend-reuse: nothing to validate

  type_re = "^(feat|fix|refactor|chore|docs|style|test|build|ci|perf)(\\([a-z0-9._-]+\\))?(!)?: .+"
  msg = ""
  if (subject !~ type_re)
    msg = msg "\n  - must be 'type(scope): description' (scope optional); type one of: feat/fix/refactor/chore/docs/style/test/build/ci/perf"
  if (length(subject) > 50)
    msg = msg "\n  - subject is " length(subject) " chars, exceeds the 50 limit"
  if (subject ~ /\.$/)
    msg = msg "\n  - subject must not end with a period"
  if (has_body)
    msg = msg "\n  - subject line only: no body"

  if (msg != "") {
    print "  subject: " subject
    print substr(msg, 2)  # drop leading newline
  }
}
AWK
)

errors=$(printf '%s' "$cmd" | awk "$awk_prog")
if [ -n "$errors" ]; then
  {
    echo "[commit-format] Commit message does not follow Conventional Commits:"
    echo "$errors"
    echo "  example: feat(auth): add token refresh"
  } >&2
  exit 2
fi
exit 0
