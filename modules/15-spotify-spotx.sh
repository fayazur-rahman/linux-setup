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
  # SpotX-Bash patches the native (deb-installed) client and explicitly does
  # NOT support Snap; on Fedora there's no official apt-style native package
  # in the same way. Install the Flatpak so you still get Spotify — just
  # un-patched. (SpotX can patch a Flatpak install too, but that's a more
  # involved, breakage-prone path we don't automate here.)
  warn "SpotX-Bash targets APT-based native installs — can't auto-patch on Fedora."
  log "Installing the Spotify Flatpak instead (un-patched, but you still get the app)."
  flatpak_install com.spotify.Client
  warn "To ad-block a Flatpak Spotify you'd run SpotX with a custom -P path — see"
  warn "  https://github.com/SpotX-Official/SpotX-Bash  (not automated here)."
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
