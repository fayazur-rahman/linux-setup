#!/usr/bin/env bash
# Core CLI tools + system utilities. Most are identical across distros; a few
# GUI helpers are desktop-specific (GNOME Tweaks/Extension Manager only make
# sense on GNOME, so they're skipped on KDE where Plasma has its own tools).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro
detect_desktop
[ "$PKG_FAMILY" = "debian" ] && apt_update_once
[ "$PKG_FAMILY" = "rpm" ] && rpm_refresh_once

section "CLI essentials"

# vim: package name differs (vim on Debian, vim-enhanced on Fedora)
pkg_install vim vim-enhanced
pkg_install curl curl
pkg_install wget wget
pkg_install gparted gparted
pkg_install htop htop
pkg_install btop btop

# build tools: build-essential on Debian, the Development Tools group on Fedora
if [ "$PKG_FAMILY" = "debian" ]; then
  pkg_install build-essential build-essential
elif [ "$PKG_FAMILY" = "rpm" ]; then
  if ! rpm -q gcc >/dev/null 2>&1; then
    spin_run "Development Tools group" sudo "$PKG_MANAGER" group install -y "Development Tools"
  else
    ok "Development Tools (already installed)"
  fi
fi

# ffmpeg — on Fedora this needs RPM Fusion (enabled in 00-system-update), where
# the full build lives; the free-repo ffmpeg-free is swapped for it there.
pkg_install ffmpeg ffmpeg

# neofetch is unmaintained upstream — fastfetch is the maintained replacement.
if is_cmd fastfetch; then
  ok "fastfetch (already installed)"
else
  pkg_install fastfetch fastfetch
  if ! is_cmd fastfetch && [ "$PKG_FAMILY" = "debian" ]; then
    warn "fastfetch not in default repos for this release — adding PPA"
    spin_run "fastfetch PPA" sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
    apt_update_once
    pkg_install fastfetch fastfetch
  fi
fi

# --- GUI helpers: only the ones that fit the current desktop ------------------
if [ "$DESKTOP_ENV" = "gnome" ]; then
  pkg_install gnome-tweaks gnome-tweaks
  if [ "$PKG_FAMILY" = "debian" ]; then
    pkg_install gnome-shell-extension-manager gnome-shell-extension-manager
  else
    pkg_install gnome-extensions-app gnome-extensions-app
  fi
elif [ "$DESKTOP_ENV" = "kde" ]; then
  log "KDE detected — GNOME Tweaks/Extension Manager not applicable."
  log "Plasma's own controls live in System Settings; no extra tweak tool needed."
fi

# Package manager GUI: Synaptic is apt-only. On Fedora, DNFDragora / the
# Discover software centre fill that role and ship by default, so nothing to do.
if [ "$PKG_FAMILY" = "debian" ]; then
  pkg_install synaptic synaptic
fi

# Archive support to replace WinRAR. Archive-manager frontend differs by
# desktop: file-roller (GNOME) vs ark (KDE). p7zip package name differs too.
pkg_install unrar unrar
if [ "$PKG_FAMILY" = "debian" ]; then
  pkg_install p7zip-full p7zip
else
  pkg_install p7zip p7zip
  pkg_install p7zip-plugins p7zip-plugins 2>/dev/null || true
fi
if [ "$DESKTOP_ENV" = "kde" ]; then
  pkg_install ark ark
else
  pkg_install file-roller file-roller
fi

# Timeshift for system snapshots (Windows "System Restore" equivalent).
pkg_install timeshift timeshift

ok "CLI essentials done"
