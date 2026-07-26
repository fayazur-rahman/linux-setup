#!/usr/bin/env bash
# ==============================================================================
# install.sh — master orchestrator
#
# Usage:
#   ./install.sh                 # run every module listed in config/modules.conf
#   ./install.sh 03 09           # run only modules whose filename starts with
#                                # these numbers (e.g. browsers + obs/discord)
#   ./install.sh --list          # show available modules and exit
#
# Safe to re-run any time: every module checks whether its target is already
# installed and skips it if so.
# ==============================================================================

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

MODULES_CONF="$SCRIPT_DIR/config/modules.conf"

if [ "${1:-}" = "--list" ]; then
  echo "Available modules:"
  grep -v '^\s*#' "$MODULES_CONF" | grep -v '^\s*$' | sed 's/^/  - /'
  exit 0
fi

if [ "$EUID" -eq 0 ]; then
  err "Don't run this as root — it calls sudo internally where needed. Run as your normal user."
  exit 1
fi

detect_distro
detect_desktop
if [ "$PKG_FAMILY" = "unknown" ]; then
  err "Could not detect a supported package manager (apt/dnf/yum). Aborting."
  exit 1
fi

log "This script will use 'sudo' repeatedly — you may be prompted for your password."
sudo -v   # prime sudo credential cache once up front

# --- Upfront preferences ------------------------------------------------------
# We ask everything the run needs to know once, up front, rather than
# interrupting the flow mid-way. Right now that's just the Spotify tier
# (free vs premium) — SpotX applies different patches for each. The answer
# gets exported AND written to a small state file so 15-spotify-spotx.sh
# can read it regardless of subprocess isolation.
PREFS_FILE="$SCRIPT_DIR/logs/_prefs.env"
mkdir -p "$SCRIPT_DIR/logs"

term ""
term "${C_YELLOW}Before we start — one quick question:${C_RESET}"
term "Are you a Spotify Free or Premium user?"
term "  This lets SpotX apply the right ad-block / patch set."
term "  (Free = default patches; Premium = SpotX runs with the --premium flag.)"
SPOTIFY_TIER=""
while [ -z "$SPOTIFY_TIER" ]; do
  read -r -p "  [f] Free   [p] Premium : " ans
  case "${ans,,}" in
    f|free)    SPOTIFY_TIER="free" ;;
    p|premium) SPOTIFY_TIER="premium" ;;
    *)         term "  Please answer 'f' or 'p'." ;;
  esac
done
echo "SPOTIFY_TIER=${SPOTIFY_TIER}" > "$PREFS_FILE"
export SPOTIFY_TIER
term ""

# Keep sudo alive for the duration of a long run
( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# Build the list of modules to run
mapfile -t ALL_MODULES < <(grep -v '^\s*#' "$MODULES_CONF" | grep -v '^\s*$')

if [ "$#" -gt 0 ]; then
  SELECTED=()
  for arg in "$@"; do
    for m in "${ALL_MODULES[@]}"; do
      [[ "$m" == "$arg"* ]] && SELECTED+=("$m")
    done
  done
  ALL_MODULES=("${SELECTED[@]}")
fi

if [ "${#ALL_MODULES[@]}" -eq 0 ]; then
  err "No matching modules to run."
  exit 1
fi

section "Running ${#ALL_MODULES[@]} module(s) on a ${PKG_FAMILY}-based system"

# Fresh ledgers for this run so the final summary only reflects what
# actually happened now, not leftovers from a previous run.
mkdir -p "$LOG_DIR"
: > "$APPS_LEDGER"
: > "$EXT_LEDGER"

for module in "${ALL_MODULES[@]}"; do
  run_module "$SCRIPT_DIR/modules/$module"
done

print_summary
