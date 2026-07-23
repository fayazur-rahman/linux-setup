#!/usr/bin/env bash
# VLC (required) + mpv/SMPlayer as the closest thing Linux has to PotPlayer
# (no native PotPlayer port exists) + Caesium Image Compressor (has native
# Linux builds, so no substitute needed).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "Media players"

pkg_install vlc vlc

# PotPlayer has no Linux build. mpv + SMPlayer (a GUI shell over mpv) is the
# nearest equivalent: fast hardware-accelerated playback, on-the-fly subtitle
# styling, speed control, similar keyboard-driven workflow.
pkg_install mpv mpv
pkg_install smplayer smplayer

# Caesium Image Compressor — the project (Lymphatus/caesium-image-compressor)
# does NOT currently publish an official Flathub package; the only reliable
# Linux build is the AppImage from GitHub Releases. We fetch and stage it
# rather than guessing a flatpak id that may not exist.
CAESIUM_DIR="$HOME/Applications"
mkdir -p "$CAESIUM_DIR"
if ls "$CAESIUM_DIR"/Caesium*.AppImage >/dev/null 2>&1; then
  ok "Caesium AppImage already present in $CAESIUM_DIR — skipping"
else
  log "Fetching latest Caesium AppImage from GitHub releases ..."
  CAESIUM_URL="$(curl -fsSL https://api.github.com/repos/Lymphatus/caesium-image-compressor/releases/latest \
    | grep -oP '"browser_download_url":\s*"\K[^"]+\.AppImage' | head -n1)"
  if [ -n "${CAESIUM_URL:-}" ]; then
    curl -fsSL "$CAESIUM_URL" -o "$CAESIUM_DIR/$(basename "$CAESIUM_URL")"
    chmod +x "$CAESIUM_DIR"/Caesium*.AppImage
    ok "Caesium AppImage staged in $CAESIUM_DIR (double-click or run directly to launch)"
  else
    warn "Could not auto-resolve Caesium AppImage URL — grab it manually from:"
    warn "  https://github.com/Lymphatus/caesium-image-compressor/releases"
  fi
fi

ok "Media players done"
