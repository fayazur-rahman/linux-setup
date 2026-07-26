#!/usr/bin/env bash
# TeamViewer — used to control this desktop from mobile when away from it.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro
detect_desktop

section "Remote access (TeamViewer)"

if is_cmd teamviewer; then
  ok "TeamViewer (already installed)"
elif [ "$PKG_FAMILY" = "debian" ]; then
  download_and_install_deb "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb"
  spin_run "Resolving TeamViewer dependencies" sudo apt-get install -f -y
elif [ "$PKG_FAMILY" = "rpm" ]; then
  tmp="$(mktemp --suffix=.rpm)"
  spin_run "Downloading TeamViewer" curl -fsSL "https://download.teamviewer.com/download/linux/teamviewer.x86_64.rpm" -o "$tmp"
  spin_run "Installing TeamViewer" sudo "$PKG_MANAGER" install -y "$tmp"
  rm -f "$tmp"
fi

ok "Remote access done"

# Remmina: skip on Fedora KDE — the spin ships KRDC (KDE's own RDP/VNC
# client) which covers the same use case natively.
if [ "$DISTRO_ID" = "fedora" ] && [ "$DESKTOP_ENV" = "kde" ]; then
  ok "Remmina (skipped — Fedora KDE ships KRDC for the same job)"
else
  section "Remmina (remote desktop client)"
  pkg_install remmina remmina
  pkg_install remmina-plugin-rdp remmina-plugin-rdp 2>/dev/null || true
fi
