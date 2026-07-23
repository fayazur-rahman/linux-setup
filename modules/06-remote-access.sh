#!/usr/bin/env bash
# TeamViewer — used to control this desktop from mobile when away from it.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "Remote access (TeamViewer)"

if is_cmd teamviewer; then
  ok "TeamViewer already installed — skipping"
elif [ "$PKG_FAMILY" = "debian" ]; then
  download_and_install_deb "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb"
  sudo apt-get install -f -y   # resolve any missing deps pulled in by the .deb
elif [ "$PKG_FAMILY" = "rpm" ]; then
  tmp="$(mktemp --suffix=.rpm)"
  curl -fsSL "https://download.teamviewer.com/download/linux/teamviewer.x86_64.rpm" -o "$tmp"
  sudo "$PKG_MANAGER" install -y "$tmp"
  rm -f "$tmp"
fi

ok "Remote access done"
