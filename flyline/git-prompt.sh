#!/usr/bin/env bash
# Async git segment for the flyline prompt. Output goes through bash's
# decode_prompt_string, so \e color escapes work.
# Shows " branch +staged !unstaged ?untracked", nothing outside a repo.
# Colors mirror ~/.p10k.zsh: branch/clean 76, modified 178, untracked 39

branch=$(git symbolic-ref --short HEAD 2>/dev/null) \
  || branch=$(git rev-parse --short HEAD 2>/dev/null) \
  || exit 0
staged=0 unstaged=0 untracked=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    '??'*) untracked=$((untracked + 1)) ;;
    *)
      [ "${line:0:1}" != " " ] && staged=$((staged + 1))
      [ "${line:1:1}" != " " ] && unstaged=$((unstaged + 1))
      ;;
  esac
done <<<"$(git status --porcelain --no-renames 2>/dev/null)"
out=" \e[38;5;76m${branch}\e[0m"
[ "$staged" -gt 0 ] && out="$out \e[38;5;178m+${staged}\e[0m"
[ "$unstaged" -gt 0 ] && out="$out \e[38;5;178m!${unstaged}\e[0m"
[ "$untracked" -gt 0 ] && out="$out \e[38;5;39m?${untracked}\e[0m"
printf '%s' "$out"
