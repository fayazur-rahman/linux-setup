#!/usr/bin/env bash
# Flameshot — closest Lightshot equivalent (region capture, annotate, copy to
# clipboard, upload). Installed via Flatpak deliberately: the Flatpak build
# tracks upstream fixes for the Wayland screenshot portal faster than most
# distro apt/dnf packages, which matters because GNOME on Ubuntu 22.04+/
# Fedora defaults to Wayland.
#
# KNOWN GOTCHAS (read before relying on this for client screenshots):
#   1. GNOME's own "Screenshot" binding intercepts PrtScn before Flameshot
#      ever sees the keypress. This script unbinds GNOME's default so
#      Flameshot's shortcut actually fires.
#   2. Older Flameshot builds had clipboard/copy bugs specifically under
#      Wayland — this is why we use flatpak (auto-updates to latest fix)
#      rather than a possibly-stale distro package.
#   3. If screenshots still come out blank/black or the capture UI won't
#      draw on your session, the reliable last-resort fix is logging into
#      "Ubuntu on Xorg" from the gear icon on the GDM login screen — this is
#      a login-time choice, not something a script can flip for you.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro
detect_desktop

section "Screenshot tool"

# Fedora KDE ships Spectacle preinstalled, already bound to PrtScn and
# portal-integrated. Flameshot on top of that is redundant, so skip it there.
# Debian/Ubuntu and Fedora GNOME still get Flameshot as the Lightshot-equivalent.
if [ "$DISTRO_ID" = "fedora" ] && [ "$DESKTOP_ENV" = "kde" ]; then
  ok "Flameshot (skipped — Fedora KDE ships Spectacle, already bound to PrtScn)"
  exit 0
fi

flatpak_install org.flameshot.Flameshot

if [ "$DESKTOP_ENV" = "gnome" ] && is_cmd gsettings; then
  log "Disabling GNOME's default PrtScn bindings so Flameshot can claim the key ..."
  gsettings set org.gnome.shell.keybindings show-screenshot-ui "[]" 2>/dev/null || true
  gsettings set org.gnome.settings-daemon.plugins.media-keys screenshot "[]" 2>/dev/null || true
  gsettings set org.gnome.settings-daemon.plugins.media-keys area-screenshot "[]" 2>/dev/null || true

  log "Binding Print key to launch Flameshot's capture UI ..."
  CUSTOM_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-flameshot/"
  EXISTING="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo "@as []")"
  if ! echo "$EXISTING" | grep -q "custom-flameshot"; then
    if [ "$EXISTING" = "@as []" ] || [ "$EXISTING" = "[]" ]; then
      NEW="['$CUSTOM_PATH']"
    else
      NEW="$(echo "$EXISTING" | sed "s/]$/, '$CUSTOM_PATH']/")"
    fi
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW" 2>/dev/null || true
  fi
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$CUSTOM_PATH" name "Flameshot" 2>/dev/null || true
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$CUSTOM_PATH" command "flatpak run org.flameshot.Flameshot gui" 2>/dev/null || true
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$CUSTOM_PATH" binding "Print" 2>/dev/null || true
  warn "If capture comes out blank on Wayland, log into 'Ubuntu on Xorg' (GDM gear icon) as a fallback."

elif [ "$DESKTOP_ENV" = "kde" ]; then
  # KDE Plasma ships Spectacle, already bound to PrtScn and well-integrated
  # with the KWin screenshot portal — arguably a better Lightshot-equivalent
  # on KDE than Flameshot. We still install Flameshot (you may prefer its
  # annotation UI), but we DON'T rebind PrtScn: on KDE that's done through
  # System Settings > Shortcuts, and stomping on it from a script is fragile.
  log "KDE detected — Spectacle is already installed and bound to PrtScn by default."
  log "Flameshot is installed too; to make PrtScn open Flameshot instead, set it in"
  log "System Settings > Shortcuts > Custom Shortcuts, command:"
  log "  flatpak run org.flameshot.Flameshot gui"
fi

ok "Screenshot tool done"
