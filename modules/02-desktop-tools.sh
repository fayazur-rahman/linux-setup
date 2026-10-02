#!/usr/bin/env bash
# Title:    Desktop tools
# Installs: GNOME Tweaks · Extension Manager (GNOME only) · Mission Center
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

if [ "$DESKTOP_ENV" = "gnome" ]; then
  pm_refresh
  pkg "GNOME Tweaks" gnome-tweaks
  # Extension Manager: native on Ubuntu, Flathub elsewhere.
  if [ "$PKG_FAMILY" = "debian" ]; then
    pkg "Extension Manager" gnome-shell-extension-manager
  else
    flatpak_app "Extension Manager" com.mattjakeman.ExtensionManager extension-manager
  fi
else
  info "Not GNOME — GNOME Tweaks and Extension Manager skipped."
fi

flatpak_app "Mission Center" io.missioncenter.MissionCenter missioncenter
