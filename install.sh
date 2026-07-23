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
if [ "$PKG_FAMILY" = "unknown" ]; then
  err "Could not detect a supported package manager (apt/dnf/yum). Aborting."
  exit 1
fi

log "This script will use 'sudo' repeatedly — you may be prompted for your password."
sudo -v   # prime sudo credential cache once up front

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
for module in "${ALL_MODULES[@]}"; do
  run_module "$SCRIPT_DIR/modules/$module"
done

print_summary

warn "If the NVIDIA driver module ran, REBOOT before relying on GPU acceleration."
warn "If the monitor-brightness module ran, log out/in for the i2c group change to apply."
ok "All done."
