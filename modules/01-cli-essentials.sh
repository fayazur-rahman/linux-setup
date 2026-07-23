#!/usr/bin/env bash
# Core CLI tools + system utilities you listed under "in terms of linux".
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro
[ "$PKG_FAMILY" = "debian" ] && apt_update_once
[ "$PKG_FAMILY" = "rpm" ] && rpm_refresh_once

section "CLI essentials"
pkg_install_many vim curl wget git-core 2>/dev/null
pkg_install vim vim-enhanced
pkg_install curl curl
pkg_install wget wget
pkg_install gparted gparted
pkg_install htop htop
pkg_install btop btop

# build-essential has no direct RPM equivalent name; use groups on rpm side
if [ "$PKG_FAMILY" = "debian" ]; then
  pkg_install build-essential build-essential
elif [ "$PKG_FAMILY" = "rpm" ]; then
  if ! rpm -q gcc >/dev/null 2>&1; then
    log "Installing 'Development Tools' group (build-essential equivalent) ..."
    sudo "$PKG_MANAGER" groupinstall -y "Development Tools"
  else
    ok "Development Tools already installed — skipping"
  fi
fi

pkg_install ffmpeg ffmpeg

# neofetch is unmaintained/abandoned upstream — fastfetch is the maintained
# drop-in replacement, so we install fastfetch by default.
if is_cmd fastfetch; then
  ok "fastfetch already installed — skipping"
else
  pkg_install fastfetch fastfetch
  if ! is_cmd fastfetch && [ "$PKG_FAMILY" = "debian" ]; then
    warn "fastfetch not in default repos for this release — adding PPA"
    sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
    apt_update_once
    pkg_install fastfetch fastfetch
  fi
fi

pkg_install gnome-tweaks gnome-tweaks
pkg_install synaptic synaptic

# GNOME Shell extension manager — package name differs across distros
if [ "$PKG_FAMILY" = "debian" ]; then
  pkg_install gnome-shell-extension-manager gnome-shell-extension-manager
else
  pkg_install gnome-extensions-app gnome-extensions-app
fi

# Archive support to replace WinRAR — unrar/p7zip so the built-in Archive
# Manager can open everything WinRAR could.
pkg_install unrar unrar
pkg_install p7zip-full p7zip
pkg_install file-roller file-roller

# Timeshift for system snapshots (your Windows "System Restore" equivalent)
pkg_install timeshift timeshift

ok "CLI essentials done"
