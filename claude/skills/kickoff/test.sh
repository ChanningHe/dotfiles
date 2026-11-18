#!/usr/bin/env bash
# Tests for init.sh. Usage: bash test.sh
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
INIT="$HERE/init.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/kickoff-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
check() { # check <desc> <cmd...>
  local d=$1; shift
  if "$@" >/dev/null 2>&1; then ok; else bad "$d"; fi
}
newrepo() {
  local r; r=$(mktemp -d "$TMP/repo.XXXXXX")
  git -C "$r" init -q
  git -C "$r" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  echo "$r"
}
TODAY=$(date +%y%m%d)

# 1. outside a git work tree -> exit 1 with message
NOGIT=$(mktemp -d "$TMP/nogit.XXXXXX")
out=$(cd "$NOGIT" && bash "$INIT" foo 2>&1 >/dev/null); rc=$?
[ "$rc" -eq 1 ] && ok || bad "outside git: expected exit 1, got $rc"
[ -n "$out" ] && ok || bad "outside git: expected message on stderr"

# 2. happy path T2, run from a subdirectory
R=$(newrepo); mkdir -p "$R/sub/dir"
before=$(git -C "$R" status --porcelain)
stdout=$(cd "$R/sub/dir" && bash "$INIT" my-item 2>"$TMP/err"); rc=$?
[ "$rc" -eq 0 ] && ok || bad "T2 happy: exit $rc"
[ "$stdout" = "$R/.work/$TODAY-my-item" ] && ok || bad "T2 happy: stdout was '$stdout'"
[ "$(printf '%s\n' "$stdout" | wc -l)" -eq 1 ] && ok || bad "T2 happy: stdout must be one line"
[ ! -s "$TMP/err" ] && ok || bad "T2 happy: unexpected stderr: $(cat "$TMP/err")"
check ".work/.gitignore contains *" grep -qx '\*' "$R/.work/.gitignore"
check "INDEX ignored" git -C "$R" check-ignore -q .work/INDEX.md
check "design.md exists" test -s "$R/.work/$TODAY-my-item/design.md"
check "no ledger for T2" test ! -e "$R/.work/$TODAY-my-item/ledger.md"
for h in "Active" "Learnings" "Out of scope"; do
  check "INDEX has $h" grep -q "^## $h" "$R/.work/INDEX.md"
done
check "INDEX has table header" grep -q '^| id | tier | status | next |' "$R/.work/INDEX.md"
[ "$(git -C "$R" status --porcelain)" = "$before" ] && ok || bad "git status changed"

# 3. T3 creates ledger; INDEX not overwritten
echo "SENTINEL" >> "$R/.work/INDEX.md"
stdout=$(cd "$R" && bash "$INIT" big-one T3 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && ok || bad "T3: exit $rc"
check "ledger.md exists for T3" test -s "$R/.work/$TODAY-big-one/ledger.md"
check "INDEX preserved" grep -q SENTINEL "$R/.work/INDEX.md"
[ "$(git -C "$R" status --porcelain)" = "$before" ] && ok || bad "git status changed (T3)"

# 4. refusals
refuse() { # refuse <desc> <repo> <args...>
  local d=$1 r=$2; shift 2
  local so; so=$(cd "$r" && bash "$INIT" "$@" 2>/dev/null); local c=$?
  [ "$c" -eq 1 ] && ok || bad "$d: expected exit 1, got $c"
  [ -z "$so" ] && ok || bad "$d: stdout must be empty on refusal"
}
refuse "duplicate item" "$R" my-item
refuse "bad slug upper" "$R" Foo
refuse "bad slug underscore" "$R" a_b
refuse "bad slug empty" "$R" ""
refuse "bad slug traversal" "$R" ../x
refuse "bad tier" "$R" okslug T9
refuse "no args" "$R"
R2=$(newrepo); mkdir "$R2/.work"; echo x > "$R2/.work/tracked.md"
git -C "$R2" add -f .work/tracked.md
refuse "tracked .work" "$R2" thing
[ ! -e "$R2/.work/.gitignore" ] && ok || bad "tracked .work: must not create files"

# 5. legacy notice, nothing moved
R3=$(newrepo); mkdir -p "$R3/dev/docs" "$R3/dev/tasks"; echo a > "$R3/dev/docs/a.md"
before3=$(git -C "$R3" status --porcelain)
(cd "$R3" && bash "$INIT" legacy-check >/dev/null 2>"$TMP/err3"); rc=$?
[ "$rc" -eq 0 ] && ok || bad "legacy: exit $rc"
[ "$(wc -l < "$TMP/err3")" -eq 1 ] && grep -q 'dev/' "$TMP/err3" && ok || bad "legacy: expected one-line stderr notice"
check "legacy file untouched" test -f "$R3/dev/docs/a.md"
[ "$(git -C "$R3" status --porcelain)" = "$before3" ] && ok || bad "legacy: git status changed"

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
