# flyline (https://github.com/HalFrgrd/flyline) bash configuration.
# Sourced from .bashrc; portable to any host with bash >= 5 and libflyline.
#
# Lookup order for the builtin: $FLYLINE_LIB (set by nix-config with the
# exact store path), then common install locations. If flyline cannot be
# loaded, or FLYLINE_DISABLE is set, or TERM is dumb, the shell keeps plain
# readline with a basic prompt.

_flyline_dir="${BASH_SOURCE[0]%/*}"

_flyline_find_lib() {
  local dir ext
  if [ -n "${FLYLINE_LIB:-}" ] && [ -f "$FLYLINE_LIB" ]; then
    printf '%s' "$FLYLINE_LIB"
    return 0
  fi
  for dir in "$HOME/.local/lib" "$HOME/.nix-profile/lib" /run/current-system/sw/lib \
             /opt/homebrew/lib /usr/local/lib /usr/lib; do
    for ext in so dylib; do
      if [ -f "$dir/libflyline.$ext" ]; then
        printf '%s' "$dir/libflyline.$ext"
        return 0
      fi
    done
  done
  return 1
}

# Load the builtin; returns non-zero when flyline should not / cannot run
_flyline_load() {
  local lib
  [[ $TERM == dumb || -n ${FLYLINE_DISABLE:-} ]] && return 1
  lib=$(_flyline_find_lib) || return 1
  enable -f "$lib" flyline 2>/dev/null
}

# Rebuild PS1 each prompt: > turns red after a failing command.
# Colors mirror ~/.p10k.zsh: dir 108, char ok 71 / err 124, ssh context 180
__flyline_set_ps1() {
  # One `local` so both expand before it runs and see the previous command
  local last_status=$? pipe_status="${PIPESTATUS[*]}"
  local char_color='\[\e[1;38;5;71m\]'
  [ "$last_status" -ne 0 ] && char_color='\[\e[1;38;5;124m\]'
  local ssh_part=""
  [ -n "${SSH_TTY:-}${SSH_CONNECTION:-}" ] && ssh_part='\[\e[38;5;180m\]\u@\h\[\e[0m\] '
  PS1="$ssh_part"'\[\e[38;5;108m\]\w\[\e[0m\]FLYLINE_GIT_INFO\n'"$char_color"'>\[\e[0m\] '
  __flyline_set_rps1 "$last_status" "$pipe_status"
}

# Right prompt in p10k order: status, duration, jobs, direnv, nix shell, clock.
# Colors and glyphs mirror ~/.p10k.zsh: error 160, duration 101, jobs 70,
# direnv 178, nix shell 74, clock 66
__flyline_set_rps1() {
  local last_status=$1 pipe_status=$2 rps1=""
  if [[ $pipe_status == *' '* && $pipe_status == *[1-9]* ]]; then
    rps1+='\e[38;5;160mх'"${pipe_status// /|}"'\e[0m '
  elif [ "$last_status" -ne 0 ]; then
    rps1+='\e[38;5;160mх'"$last_status"'\e[0m '
  fi
  rps1+='\e[38;5;101mFLYLINE_LAST_COMMAND_DURATION\e[0m '
  [ -n "$(jobs -p)" ] && rps1+='\e[38;5;70m≡\e[0m '
  [ -n "${DIRENV_DIR:-}" ] && rps1+='\e[38;5;178mdirenv\e[0m '
  case "${IN_NIX_SHELL:-}" in
    pure) rps1+='\e[38;5;74mnix:pure\e[0m ' ;;
    ?*) rps1+='\e[38;5;74mnix:impure\e[0m ' ;;
  esac
  RPS1="$rps1"'\e[38;5;66m\t\e[0m'
}

if _flyline_load; then
  flyline --set-frame-rate 60
  # cwd + async git widget · status, duration, jobs, env, clock / > input
  flyline create-prompt-widget custom --name FLYLINE_GIT_INFO \
    --command "$_flyline_dir/git-prompt.sh" --placeholder prev
  flyline create-prompt-widget last-command-duration

  PROMPT_DIRTRIM=5

  # Prepend so it runs first and sees the real $? (direnv's hook uses the
  # same array/string-compatible idiom)
  if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
    PROMPT_COMMAND=(__flyline_set_ps1 "${PROMPT_COMMAND[@]}")
  else
    PROMPT_COMMAND="__flyline_set_ps1${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
  fi

  # fill 244; RPS1 is rebuilt each prompt by __flyline_set_rps1
  PS1_FILL='\e[38;5;244m·\e[0m'
  PS2='\e[38;5;244mFLYLINE_PROMPT_LINE_NUMBER>\e[0m '

  flyline set-cursor --effect blink --style "#A8A8A8"

  # Right arrow accepts the highlighted tab-completion entry (like Enter)
  flyline key bind Right tabCompletionEntrySelected=tabCompletionAcceptEntry
  flyline suggestions --auto-suggest
  flyline editor --auto-close-chars false
  flyline set-agent-mode \
      --system-prompt "Be concise. Answer with a JSON array of at most 3 items with objects containing: command and description. Command will be a Bash command. " \
      --trigger-prefix ': ' \
      --command 'claude --effort low --print'

  flyline history --backend flyline
  flyline editor --inline-history-prefer cwd
else
  # Basic fallback: plain prompt (16-color ANSI only), user@host over SSH
  PS1='\[\e[1;34m\]\w\[\e[0m\]\n\[\e[1;32m\]>\[\e[0m\] '
  if [ -n "${SSH_TTY:-}${SSH_CONNECTION:-}" ]; then
    PS1='\[\e[1;35m\]\u@\h\[\e[0m\] '"$PS1"
  fi
fi

unset -f _flyline_load _flyline_find_lib
unset _flyline_dir
