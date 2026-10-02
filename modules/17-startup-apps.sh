#!/usr/bin/env bash
# Title:    Startup apps
# Installs: Launch at login: ZapZap · Discord · Flameshot · qBittorrent · Remmina · Spotify (only those installed)
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

AUTOSTART="$HOME/.config/autostart"
mkdir -p "$AUTOSTART"

# autostart <file-id> <Name> <Exec>
autostart() {
  local file="$AUTOSTART/$1.desktop"
  if [ -f "$file" ]; then skipped "$2" "already starts at login"; return; fi
  cat > "$file" << DESK
[Desktop Entry]
Type=Application
Name=$2
Exec=$3
Terminal=false
X-GNOME-Autostart-enabled=true
DESK
  ok "$2 will start at login"; record OK cfg "Autostart: $2"
}

# Picks the native command if present, otherwise the Flatpak, otherwise skips.
autostart_app() {   # autostart_app <file-id> <Name> <native-cmd> <flatpak-id> [args]
  if [ -n "$3" ] && is_cmd "$3"; then autostart "$1" "$2" "$3${5:+ $5}"
  elif [ -n "$4" ] && is_flatpak_installed "$4"; then autostart "$1" "$2" "flatpak run $4${5:+ $5}"
  else info "$2 isn't installed — no startup entry."
  fi
}

autostart_app zapzap      "ZapZap"       ""            com.rtosta.zapzap
autostart_app discord     "Discord"      discord       com.discordapp.Discord  "--start-minimized"
autostart_app flameshot   "Flameshot"    flameshot     org.flameshot.Flameshot
autostart_app qbittorrent "qBittorrent"  qbittorrent   ""
autostart_app remmina     "Remmina"      remmina       ""                      "-i"
autostart_app spotify     "Spotify"      spotify       com.spotify.Client
