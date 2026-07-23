#!/usr/bin/env bash
# Brave + Google Chrome
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "Browsers"

# --- Brave ---------------------------------------------------------------
if is_cmd brave-browser; then
  ok "Brave already installed — skipping"
else
  log "Installing Brave via official install script ..."
  curl -fsS https://dl.brave.com/install.sh | sh
fi

# --- Google Chrome ---------------------------------------------------------
if is_cmd google-chrome || is_cmd google-chrome-stable; then
  ok "Chrome already installed — skipping"
else
  if [ "$PKG_FAMILY" = "debian" ]; then
    log "Installing Google Chrome (.deb) ..."
    download_and_install_deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
  elif [ "$PKG_FAMILY" = "rpm" ]; then
    log "Installing Google Chrome (.rpm) ..."
    tmp="$(mktemp --suffix=.rpm)"
    curl -fsSL "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm" -o "$tmp"
    sudo "$PKG_MANAGER" install -y "$tmp"
    rm -f "$tmp"
  fi
fi

ok "Browsers done"
