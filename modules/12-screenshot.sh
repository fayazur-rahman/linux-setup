#!/usr/bin/env bash
# Title:    Screenshots
# Installs: Flameshot, bound to the Print Screen key (skipped on Fedora KDE, which ships Spectacle)
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

if is_fedora_kde; then
  skipped "Flameshot" "not needed — Spectacle is built in"; exit 0
fi

flatpak_app "Flameshot" org.flameshot.Flameshot flameshot

# GNOME grabs Print Screen for its own tool; hand the key to Flameshot.
if [ "$DESKTOP_ENV" = "gnome" ] && is_cmd gsettings && is_flatpak_installed org.flameshot.Flameshot; then
  KB="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-flameshot/"
  SCHEMA="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$KB"
  if [ "$(gsettings get "$SCHEMA" binding 2>/dev/null)" = "'Print'" ]; then
    skipped "Print Screen → Flameshot" "already bound"
  else
    gsettings set org.gnome.shell.keybindings show-screenshot-ui "[]" 2>/dev/null || true
    EXISTING="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo '@as []')"
    if ! printf '%s' "$EXISTING" | grep -q custom-flameshot; then
      case "$EXISTING" in
        "@as []"|"[]") NEW="['$KB']" ;;
        *)             NEW="${EXISTING%]}, '$KB']" ;;
      esac
      gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW"
    fi
    gsettings set "$SCHEMA" name "Flameshot"
    gsettings set "$SCHEMA" command "flatpak run org.flameshot.Flameshot gui"
    gsettings set "$SCHEMA" binding "Print"
    ok "Print Screen → Flameshot"; record OK cfg "Print Screen opens Flameshot"
  fi
fi
