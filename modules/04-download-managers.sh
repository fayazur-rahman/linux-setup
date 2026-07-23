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

# xtreme download manager — current releases ship a direct .deb asset
# (xdman_gtk_<version>_amd64.deb), not the old tar.xz+install.sh bundle this
# script originally targeted, so we grab that asset directly.
if is_cmd xdman; then
  ok "xdman already installed — skipping"
elif [ "$PKG_FAMILY" = "debian" ]; then
  log "Installing xtreme download manager (xdman) from latest GitHub release ..."
  XDM_DEB_URL="$(curl -fsSL https://api.github.com/repos/subhra74/xdm/releases/latest \
    | grep -oP '"browser_download_url":\s*"\K[^"]+xdman_gtk[^"]+amd64\.deb')"
  if [ -n "${XDM_DEB_URL:-}" ]; then
    download_and_install_deb "$XDM_DEB_URL"
    sudo apt-get install -f -y   # resolve any deps the .deb pulled in
  else
    warn "Could not auto-resolve the xdman .deb URL — grab it manually from:"
    warn "  https://github.com/subhra74/xdm/releases (look for xdman_gtk_*_amd64.deb)"
  fi
else
  warn "xdman install is Debian-family only in this script — see https://github.com/subhra74/xdm"
fi

# Parabolic (GNOME video/audio downloader, GUI over yt-dlp) — the project
# was renamed from "Nickvision Tube Converter"; its flatpak ID kept the old
# reverse-DNS name.
flatpak_install org.nickvision.tubeconverter

ok "Download managers done"
