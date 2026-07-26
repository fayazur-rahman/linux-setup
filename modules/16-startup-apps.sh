#!/usr/bin/env bash
# Creates autostart entries (~/.config/autostart/*.desktop) for the apps you
# marked to launch automatically at login — the same thing GNOME's "Startup
# Applications" tool does under the hood, just scripted.
#
# We author minimal .desktop files ourselves rather than trying to locate
# and copy each vendor's installed .desktop file (fragile — flatpak apps in
# particular keep theirs in a version-dependent export path). Each entry is
# only created if the underlying app is actually installed, and skipped if
# an autostart entry for it already exists.
#
# NOT included here because they're already provided by the system with no
# action needed: "SSH Key Agent" (GNOME Keyring, always present) and
# "xapp-sn-watcher" (pulled in automatically as a dependency of the
# AppIndicator support stack).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "Startup applications"

AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

# _autostart <id> <Name> <Exec> <check-command-or-empty>
# If a check command is given, only creates the entry when that command
# succeeds (i.e. the app is actually present).
_autostart() {
  local id="$1" name="$2" exec_cmd="$3" check="${4:-}"
  local desktop_file="$AUTOSTART_DIR/${id}.desktop"

  if [ -n "$check" ] && ! eval "$check" >/dev/null 2>&1; then
    warn "$name not installed — skipping autostart entry"
    return
  fi

  if [ -f "$desktop_file" ]; then
    ok "$name (autostart entry already exists)"
    return
  fi

  cat > "$desktop_file" << EOF
[Desktop Entry]
Type=Application
Name=$name
Exec=$exec_cmd
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
EOF
  ok "$name (autostart entry created)"
}

_autostart "zapzap"            "ZapZap"                 "flatpak run com.rtosta.zapzap"      "is_flatpak_installed com.rtosta.zapzap"
_autostart "flameshot"         "Flameshot"               "flatpak run org.flameshot.Flameshot" "is_flatpak_installed org.flameshot.Flameshot"
_autostart "nvidia-settings"   "NVIDIA X Server Settings" "nvidia-settings"                    "is_cmd nvidia-settings"
_autostart "qbittorrent"       "qBittorrent"             "qbittorrent"                         "is_cmd qbittorrent"
_autostart "remmina"           "Remmina Applet"          "remmina"                             "is_cmd remmina"

# Discord + Spotify can be native (Debian) or flatpak (Fedora). Pick whichever
# is actually present, preferring the native command if both somehow exist.
if is_cmd discord; then
  _autostart "discord" "Discord" "discord" ""
elif is_flatpak_installed com.discordapp.Discord; then
  _autostart "discord" "Discord" "flatpak run com.discordapp.Discord" ""
else
  warn "Discord not installed — skipping autostart entry"
fi

if is_cmd spotify; then
  _autostart "spotify" "Spotify" "spotify" ""
elif is_flatpak_installed com.spotify.Client; then
  _autostart "spotify" "Spotify" "flatpak run com.spotify.Client" ""
else
  warn "Spotify not installed — skipping autostart entry"
fi

log "Autostart entries live in $AUTOSTART_DIR (freedesktop standard — works on both"
log "GNOME and KDE). Remove a file there to stop that app launching at login, or"
log "manage them via GNOME Tweaks / KDE System Settings > Autostart."

ok "Startup applications done"
