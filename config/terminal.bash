# ==============================================================================
# Terminal setup — installed by linux-setup (./install.sh --terminal)
#
# Copied to ~/.config/linux-setup/terminal.bash and loaded from ~/.bashrc.
# Edit the copy in the repo (config/terminal.bash) and re-run
# ./install.sh --terminal to update it. Remove it with ./install.sh --terminal-reset.
#
# Prompt:
#   fayazur@fedora ~/projects  main*            ← user@host, folder, git branch
#   $                                           ← green; red when the last command failed
# ==============================================================================

# Only for interactive shells.
case $- in *i*) ;; *) return ;; esac

# --- History: big, deduplicated, timestamped, shared between open terminals ---
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T  '
shopt -s histappend cmdhist checkwinsize

# --- Small conveniences ------------------------------------------------------------
alias ls='ls --color=auto'
alias ll='ls -lh --group-directories-first'
alias la='ls -lAh --group-directories-first'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
mkcd() { mkdir -p -- "$1" && cd -- "$1" || return; }

# --- Prompt ------------------------------------------------------------------------------
__lsp_c() { printf '\[\033[%sm\]' "$1"; }
__LSP_USER="$(__lsp_c '1;38;5;75')"    # blue
__LSP_PATH="$(__lsp_c '38;5;180')"     # sand
__LSP_GIT="$(__lsp_c '38;5;176')"      # purple
__LSP_DIM="$(__lsp_c '38;5;244')"      # grey
__LSP_OK="$(__lsp_c '1;38;5;114')"     # green
__LSP_BAD="$(__lsp_c '1;38;5;203')"    # red
__LSP_RST="$(__lsp_c '0')"

# PS0 is printed just before a command runs; the arithmetic records the start
# time without printing anything, so slow commands can report how long they took.
PS0='${PS1:0:$((__lsp_t0=SECONDS, 0))}'

__lsp_git() {
  command -v git >/dev/null 2>&1 || return
  local b
  b="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)" || return
  [ -z "$b" ] && return
  if [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null | head -n 1)" ]; then b="$b*"; fi
  printf '  %s%s%s' "$__LSP_GIT" "$b" "$__LSP_RST"
}

__lsp_prompt() {
  local status=$?                       # must be the first line
  history -a                            # share history with other terminals
  local extra="" sym="$__LSP_OK"

  # Failed command → red $ and the exit code. 130 (Ctrl+C) isn't treated as an error.
  if [ "$status" -ne 0 ] && [ "$status" -ne 130 ]; then
    sym="$__LSP_BAD"
    extra+="  ${__LSP_BAD}✗ ${status}${__LSP_RST}"
  fi

  # Show the duration of anything that ran for 5 s or more.
  if [ -n "${__lsp_t0:-}" ]; then
    local took=$((SECONDS - __lsp_t0)) t
    if [ "$took" -ge 5 ]; then
      if [ "$took" -ge 60 ]; then t="$((took / 60))m $((took % 60))s"; else t="${took}s"; fi
      extra+="  ${__LSP_DIM}took ${t}${__LSP_RST}"
    fi
    unset __lsp_t0
  fi

  # Python virtualenv
  [ -n "${VIRTUAL_ENV:-}" ] && extra+="  ${__LSP_DIM}($(basename "$VIRTUAL_ENV"))${__LSP_RST}"

  local title='\[\033]0;\u@\h: \w\007\]'
  PS1="${title}${__LSP_USER}\u@\h${__LSP_RST} ${__LSP_PATH}\w${__LSP_RST}$(__lsp_git)${extra}\n${sym}\\\$${__LSP_RST} "
}

# Run first, so it sees the real exit status before anything else touches $?.
if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
  [[ " ${PROMPT_COMMAND[*]} " == *" __lsp_prompt "* ]] || PROMPT_COMMAND=(__lsp_prompt "${PROMPT_COMMAND[@]}")
else
  # shellcheck disable=SC2128,SC2178
  [[ "${PROMPT_COMMAND:-}" == *__lsp_prompt* ]] || PROMPT_COMMAND="__lsp_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
