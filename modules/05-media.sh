#!/usr/bin/env bash
# Title:    Media
# Installs: VLC · mpv + SMPlayer · HandBrake · GIMP · OBS Studio
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init
pm_refresh

pkg "VLC"      vlc
pkg "mpv"      mpv
pkg "SMPlayer" smplayer

flatpak_app "HandBrake" fr.handbrake.ghb ghb
flatpak_app "GIMP"      org.gimp.GIMP    gimp

# OBS: the official PPA on Ubuntu tracks upstream releases; Fedora's package is current.
if [ "$PKG_FAMILY" = "debian" ] && ! is_cmd obs && [ "$DISTRO_ID" = "ubuntu" ]; then
  if ! grep -rqs obsproject /etc/apt/sources.list.d/; then
    if spin_run "Adding the OBS Studio repository" sudo add-apt-repository -y ppa:obsproject/obs-studio; then
      pm_refresh_needed; pm_refresh
    else
      record FAIL step "OBS Studio repository" "$SPIN_REASON"
      info "Installing the OBS version from Ubuntu's own repositories instead."
    fi
  fi
fi
pkg "OBS Studio" obs-studio
