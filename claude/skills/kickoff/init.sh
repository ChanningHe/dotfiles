#!/usr/bin/env bash
# Usage: init.sh <slug> [T2|T3]
# Creates .work/<YYMMDD>-<slug>/ in the current git repo. Prints the item path on stdout.
set -euo pipefail

die() { echo "kickoff: $*" >&2; exit 1; }

SLUG=${1:-}
TIER=${2:-T2}
TEMPLATES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/templates"

[[ "$SLUG" =~ ^[a-z0-9-]+$ ]] || die "slug must match [a-z0-9-]+ (got '$SLUG')"
[[ "$TIER" == T2 || "$TIER" == T3 ]] || die "tier must be T2 or T3 (got '$TIER')"

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git work tree"
WORK="$ROOT/.work"

[[ -z "$(git -C "$ROOT" ls-files .work)" ]] || die ".work/ has tracked files; untrack them first (git rm -r --cached .work)"

shopt -s nullglob
existing=("$WORK"/[0-9][0-9][0-9][0-9][0-9][0-9]-"$SLUG")
[[ ${#existing[@]} -eq 0 ]] || die "item already exists: ${existing[0]}"
shopt -u nullglob

mkdir -p "$WORK"
[[ -f "$WORK/.gitignore" ]] || printf '*\n' > "$WORK/.gitignore"
git -C "$ROOT" check-ignore -q .work/INDEX.md || die ".work/ is not git-ignored; check $WORK/.gitignore"

if [[ ! -f "$WORK/INDEX.md" ]]; then
  cat > "$WORK/INDEX.md" <<'IDX'
# Work index

## Active

| id | tier | status | next |
|---|---|---|---|

## Learnings

## Out of scope
IDX
fi

ITEM="$WORK/$(date +%y%m%d)-$SLUG"
mkdir "$ITEM"
cp "$TEMPLATES/design.md" "$ITEM/design.md"
[[ "$TIER" == T3 ]] && cp "$TEMPLATES/ledger.md" "$ITEM/ledger.md"

if [[ -d "$ROOT/dev/docs" || -d "$ROOT/dev/tasks" ]]; then
  echo "kickoff: legacy dev/docs or dev/tasks found; nothing moved (offer migration to .work/legacy/)" >&2
fi

echo "$ITEM"
