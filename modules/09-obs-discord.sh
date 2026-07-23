#!/usr/bin/env bash
# OBS Studio + Discord
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "OBS + Discord"

if [ "$PKG_FAMILY" = "debian" ]; then
  if ! is_cmd obs; then
    log "Adding OBS Studio PPA for the latest version ..."
    sudo add-apt-repository -y ppa:obsproject/obs-studio
    apt_update_once
  fi
fi
pkg_install obs-studio obs-studio

if is_cmd discord; then
  ok "Discord already installed — skipping"
elif [ "$PKG_FAMILY" = "debian" ]; then
  download_and_install_deb "https://discord.com/api/download?platform=linux&format=deb"
  sudo apt-get install -f -y
else
  flatpak_install com.discordapp.Discord
fi

ok "OBS + Discord done"
