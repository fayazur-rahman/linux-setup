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
_autostart "discord"           "Discord"                "discord"                             "is_cmd discord"
_autostart "flameshot"         "Flameshot"               "flatpak run org.flameshot.Flameshot" "is_flatpak_installed org.flameshot.Flameshot"
_autostart "nvidia-settings"   "NVIDIA X Server Settings" "nvidia-settings"                    "is_cmd nvidia-settings"
_autostart "qbittorrent"       "qBittorrent"             "qbittorrent"                         "is_cmd qbittorrent"
_autostart "remmina"           "Remmina Applet"          "remmina"                             "is_cmd remmina"
_autostart "spotify"           "Spotify"                 "spotify"                             "is_cmd spotify"

log "Autostart entries live in $AUTOSTART_DIR — remove a file there any time to stop"
log "that app launching at login, or manage them via GNOME Tweaks > Startup Applications."

ok "Startup applications done"
