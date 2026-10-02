#!/usr/bin/env bash
# Title:    Communication
# Installs: Discord · ZapZap (WhatsApp desktop app)
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

# Discord: official .deb on Debian/Ubuntu, Flathub elsewhere.
if is_cmd discord || is_pkg_installed discord || is_flatpak_installed com.discordapp.Discord; then
  skipped "Discord"; record SKIP app "Discord"
elif [ "$PKG_FAMILY" = "debian" ]; then
  url_package "Discord" "https://discord.com/api/download?platform=linux&format=deb"
else
  flatpak_app "Discord" com.discordapp.Discord
fi

flatpak_app "ZapZap" com.rtosta.zapzap
