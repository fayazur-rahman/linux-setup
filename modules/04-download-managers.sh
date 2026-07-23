#!/usr/bin/env bash
# qBittorrent (torrent client) + IDM-equivalents:
#   - xtreme download manager (xdman): closest IDM clone, segmented HTTP downloads
#   - yt-dlp: CLI YouTube/video downloader (actively maintained youtube-dl fork)
#   - Parabolic (flatpak): GUI front-end over yt-dlp for people who want IDM-like UX
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "Download managers"

pkg_install qbittorrent qbittorrent

# yt-dlp — install via pip/pipx if not packaged, so we always get latest
if is_cmd yt-dlp; then
  ok "yt-dlp already installed — skipping"
else
  pkg_install yt-dlp yt-dlp
  if ! is_cmd yt-dlp; then
    log "Falling back to direct binary install for yt-dlp ..."
    sudo curl -fsSL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
    sudo chmod a+rx /usr/local/bin/yt-dlp
  fi
fi

# xtreme download manager — no repo package, ships as .deb / AppImage on GitHub
if is_cmd xdman; then
  ok "xdman already installed — skipping"
elif [ "$PKG_FAMILY" = "debian" ]; then
  log "Installing xtreme download manager (xdman) from GitHub release ..."
  XDM_URL="$(curl -fsSL https://api.github.com/repos/subhra74/xdm/releases/latest \
    | grep -oP '"browser_download_url":\s*"\K[^"]+setup\.sh' | head -n1)"
  if [ -n "${XDM_URL:-}" ]; then
    tmp="$(mktemp -d)"
    curl -fsSL "$XDM_URL" -o "$tmp/xdm-setup.sh"
    chmod +x "$tmp/xdm-setup.sh"
    warn "xdm-setup.sh downloaded to $tmp — run it manually and follow prompts:"
    warn "  sudo bash $tmp/xdm-setup.sh"
  else
    warn "Could not auto-resolve latest xdman release URL — grab it manually from:"
    warn "  https://github.com/subhra74/xdm/releases"
  fi
else
  warn "xdman install is Debian-family only in this script — see https://github.com/subhra74/xdm"
fi

# Parabolic — polished GUI for yt-dlp downloads, closest to "IDM for YouTube"
flatpak_install io.gitlab.theevilskeleton.Parabolic

ok "Download managers done"
