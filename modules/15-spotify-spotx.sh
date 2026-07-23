#!/usr/bin/env bash
# Spotify + SpotX-Bash adblock patcher.
# IMPORTANT (learned from your own run log): SpotX explicitly does NOT
# support the Snap-packaged Spotify client ("Error: Snap client not
# supported"). This module therefore installs Spotify from the official APT
# repo (Debian-family) instead of snap, then runs SpotX against it.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "Spotify + SpotX"

if [ "$PKG_FAMILY" != "debian" ]; then
  warn "SpotX-Bash targets APT-based distros per upstream docs — skipping on this RPM system."
  warn "See https://github.com/SpotX-Official/SpotX-Bash for other install paths."
  exit 0
fi

# Make sure we are NOT on the snap package, since SpotX refuses to patch it.
if is_snap_installed spotify; then
  warn "Snap Spotify detected — SpotX cannot patch this. Removing snap package first ..."
  sudo snap remove spotify
fi

if ! is_pkg_installed spotify-client; then
  log "Installing Spotify from the official apt repo ..."
  curl -fsSL https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
  echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null
  apt_update_once
  pkg_install spotify-client spotify-client
else
  ok "Spotify already installed via apt — skipping install step"
fi

log "Running SpotX-Bash (interactive prompts will appear — free tier patches by default,"
log "pass --premium if you're on paid Spotify) ..."
bash <(curl -sSL https://spotx-official.github.io/run.sh)

ok "Spotify + SpotX done"
