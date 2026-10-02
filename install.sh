#!/usr/bin/env bash
# ==============================================================================
# install.sh — sets up a fresh Fedora or Ubuntu/Debian desktop in one run.
#
#   ./install.sh                  run every module in config/modules.conf
#   ./install.sh 05 15            run only modules 05 and 15 (numbers or names)
#   ./install.sh --list           show what each module installs; changes nothing
#   ./install.sh --terminal       configure the terminal prompt only
#   ./install.sh --terminal-reset remove the terminal configuration
#   ./install.sh --help
#
# Safe to re-run: anything already installed or configured is skipped.
# ==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec 3>&1                         # fd 3 = the terminal, for all status output
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
MODULES_CONF="$SCRIPT_DIR/config/modules.conf"
MODULES_DIR="$SCRIPT_DIR/modules"

mapfile -t ALL_MODULES < <(grep -vE '^[[:space:]]*(#|$)' "$MODULES_CONF" | sed 's/[[:space:]]*$//')

usage() {
  cat >&3 << EOF

  ${C_BOLD}linux-setup${C_RESET} — post-install setup for Fedora and Ubuntu/Debian desktops

  ${C_BOLD}Usage${C_RESET}
    ./install.sh                   Run every module
    ./install.sh 05 15             Run selected modules (by number or name, e.g. "media")
    ./install.sh --list            Show what each module installs, without installing
    ./install.sh --terminal        Configure only the terminal prompt — nothing else is touched
    ./install.sh --terminal-reset  Remove the terminal configuration
    ./install.sh --help            Show this help

  Logs for every run are written to ./logs/<module>.log

EOF
}

list_modules() {
  local m title installs width
  width=${COLUMNS:-$(tput cols 2>/dev/null || echo 100)}; [ "$width" -gt 110 ] && width=110
  term ""
  term "  ${C_BOLD}Modules${C_RESET} ${C_GREY}(order from config/modules.conf — nothing is installed by --list)${C_RESET}"
  term ""
  for m in "${ALL_MODULES[@]}"; do
    [ -f "$MODULES_DIR/$m" ] || continue
    title="$(module_field "$MODULES_DIR/$m" Title)"
    installs="$(module_field "$MODULES_DIR/$m" Installs)"
    term "  ${C_BLUE}${m:0:2}${C_RESET}  ${C_BOLD}${title}${C_RESET}"
    printf '%s\n' "$installs" | fold -s -w $((width - 8)) | sed 's/^/      /' >&3
  done
  term ""
  term "  ${C_GREY}Run a subset:${C_RESET}  ./install.sh 05 15      ${C_GREY}Terminal only:${C_RESET}  ./install.sh --terminal"
  term ""
}

# --- arguments ------------------------------------------------------------------------
MODE="install"; FILTERS=()
for arg in "$@"; do
  case "$arg" in
    -h|--help)        usage; exit 0 ;;
    -l|--list)        MODE="list" ;;
    --terminal)       MODE="terminal" ;;
    --terminal-reset) MODE="terminal-reset" ;;
    -*)               term "  Unknown option: $arg"; usage; exit 1 ;;
    *)                FILTERS+=("$arg") ;;
  esac
done

[ "$MODE" = "list" ] && { list_modules; exit 0; }

if [ "$EUID" -eq 0 ]; then
  term "  ${C_RED}✗${C_RESET} Run this as your normal user, not root — it asks for sudo when it needs it."
  exit 1
fi

detect_distro
detect_desktop
mkdir -p "$LOG_DIR"
: > "$LEDGER"
rm -f "$REFRESH_MARKER"
START=$SECONDS

# --- terminal-only modes (no sudo, no packages, no prompts) ----------------------------
TERMINAL_MODULE="$(printf '%s\n' "${ALL_MODULES[@]}" | grep -m1 'terminal' || echo 16-terminal.sh)"
if [ "$MODE" = "terminal" ] || [ "$MODE" = "terminal-reset" ]; then
  if [ "$MODE" = "terminal" ]; then
    run_module "$MODULES_DIR/$TERMINAL_MODULE" 1 1
  else
    run_module "$MODULES_DIR/$TERMINAL_MODULE" 1 1 --reset
  fi
  steps="$(awk -F'\t' '$1=="NOTE"{print $4}' "$LEDGER" | awk '!seen[$0]++')"
  [ -n "$steps" ] && { term ""; while IFS= read -r s; do term "  ${C_YELLOW}→${C_RESET} $s"; done <<< "$steps"; }
  term ""
  exit 0
fi

# --- module selection ------------------------------------------------------------------
SELECTED=()
if [ "${#FILTERS[@]}" -eq 0 ]; then
  SELECTED=("${ALL_MODULES[@]}")
else
  for f in "${FILTERS[@]}"; do
    [[ "$f" =~ ^[0-9]$ ]] && f="0$f"
    for m in "${ALL_MODULES[@]}"; do
      if [[ "$m" == "$f"* ]] || [[ "$m" == *"$f"* ]]; then
        [[ " ${SELECTED[*]} " == *" $m "* ]] || SELECTED+=("$m")
      fi
    done
  done
fi
if [ "${#SELECTED[@]}" -eq 0 ]; then
  term "  ${C_RED}✗${C_RESET} No module matches: ${FILTERS[*]}   (see ./install.sh --list)"
  exit 1
fi
selected() { [[ " ${SELECTED[*]} " == *"$1"* ]]; }

if [ "$PKG_FAMILY" = "unknown" ]; then
  term "  ${C_RED}✗${C_RESET} No supported package manager found (needs dnf or apt)."
  exit 1
fi

# --- banner ------------------------------------------------------------------------------
term ""
term "  ${C_BOLD}linux-setup${C_RESET}"
term "  ${C_GREY}${DISTRO_NAME} · ${DESKTOP_ENV} · ${PKG_MANAGER} · ${#SELECTED[@]} module(s)${C_RESET}"

if ! curl -fsI --max-time 8 https://dl.flathub.org >/dev/null 2>&1; then
  term ""
  term "  ${C_YELLOW}!${C_RESET} No internet connection detected — almost every step needs one."
  read -r -p "    Continue anyway? [y/N] " ans
  [[ "${ans,,}" == y* ]] || exit 1
fi

# --- sudo, kept alive for the whole run ----------------------------------------------------
term ""
term "  ${C_GREY}Administrator access is needed to install packages.${C_RESET}"
sudo -v || { term "  ${C_RED}✗${C_RESET} sudo failed — can't continue."; exit 1; }
( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
KEEPALIVE_PID=$!

SECRET_FILE=""
cleanup() {
  kill "$KEEPALIVE_PID" 2>/dev/null
  [ -n "$SECRET_FILE" ] && rm -f "$SECRET_FILE"
  [ "$IS_TTY" -eq 1 ] && printf '\033[?25h' >&3   # show the cursor again
}
trap cleanup EXIT
trap 'term ""; term "  ${C_YELLOW}Interrupted.${C_RESET} Re-run any time — finished steps are skipped."; exit 130' INT TERM

# --- questions, all asked up front so the run never stops halfway --------------------------
ask() { printf '  %s?%s %s' "$C_CYAN" "$C_RESET" "$1" >&3; }
: > "$PREFS_FILE"; chmod 600 "$PREFS_FILE"

if selected spotify; then
  term ""
  SPOTIFY_TIER=""
  while [ -z "$SPOTIFY_TIER" ]; do
    ask "Spotify account — [f]ree or [p]remium? "
    read -r ans
    case "${ans,,}" in
      f|free)    SPOTIFY_TIER="free" ;;
      p|premium) SPOTIFY_TIER="premium" ;;
      *)         term "    Type f or p." ;;
    esac
  done
  echo "SPOTIFY_TIER=$SPOTIFY_TIER" >> "$PREFS_FILE"
fi

if selected firefox-profiles; then
  term ""
  FIREFOX_PROFILES=""
  while [ -z "$FIREFOX_PROFILES" ]; do
    ask "How many Firefox profiles do you need? [3] "
    read -r ans
    ans="${ans:-3}"
    if [[ "$ans" =~ ^[0-9]$ ]]; then FIREFOX_PROFILES="$ans"; else term "    Enter a number from 0 to 9 (Enter = 3)."; fi
  done
  echo "FIREFOX_PROFILES=$FIREFOX_PROFILES" >> "$PREFS_FILE"

  # The third profile is the password-protected one.
  if [ "$FIREFOX_PROFILES" -ge 3 ]; then
    NEED_PW=1
    if [ -f "$HOME/.local/bin/security-center" ]; then
      ask "Security Center already has a password. Keep it? [Y/n] "
      read -r ans
      [[ "${ans,,}" == n* ]] || NEED_PW=0
    fi
    if [ "$NEED_PW" -eq 1 ]; then
      if ! is_cmd openssl; then
        pm_refresh >/dev/null 2>&1
        spin_run "Installing OpenSSL (needed to store the password safely)" _pm_install openssl
      fi
      while true; do
        ask "New password for Security Center: "; read -rs pw1; term ""
        if [ -z "$pw1" ]; then term "    ${C_YELLOW}The password can't be empty.${C_RESET}"; continue; fi
        ask "Retype the password: "; read -rs pw2; term ""
        if [ "$pw1" != "$pw2" ]; then term "    ${C_YELLOW}The passwords don't match — try again.${C_RESET}"; continue; fi
        break
      done
      SECRET_FILE="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/linux-setup.XXXXXX")"
      chmod 600 "$SECRET_FILE"
      printf '%s\n' "$pw1" | openssl passwd -6 -stdin > "$SECRET_FILE"
      unset pw1 pw2
      term "    ${C_GREEN}✓${C_RESET} Password confirmed"
      echo "LS_SC_HASH_FILE=$SECRET_FILE" >> "$PREFS_FILE"
    fi
  fi
fi

# --- run -------------------------------------------------------------------------------------
[ "$IS_TTY" -eq 1 ] && printf '\033[?25l' >&3   # hide the cursor while spinners run
total=${#SELECTED[@]}; i=0
for m in "${SELECTED[@]}"; do
  i=$((i + 1))
  run_module "$MODULES_DIR/$m" "$i" "$total"
done

print_summary $((SECONDS - START))
