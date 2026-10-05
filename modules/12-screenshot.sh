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
  gnome_shortcut flameshot "Flameshot" "flatpak run org.flameshot.Flameshot gui" "Print"
  case $? in
    0) gsettings set org.gnome.shell.keybindings show-screenshot-ui "[]" 2>/dev/null || true
       ok "Print Screen → Flameshot"; record OK cfg "Print Screen opens Flameshot" ;;
    2) skipped "Print Screen → Flameshot" "already bound" ;;
    *) warn "Couldn't bind Print Screen to Flameshot" ;;
  esac
fi
