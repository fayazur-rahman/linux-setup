#!/usr/bin/env bash
# Title:    Spotify
# Installs: Spotify + SpotX ad-blocking patches (free or premium, asked at the start)
#
# Ubuntu/Debian: Spotify from its official apt repository (SpotX can't patch
#                the Snap build).
# Fedora/other:  the Flathub build; SpotX is pointed at its install folder.
# SpotX options used: -h hide podcasts/audiobooks on Home, -l black lyrics
# background, -p premium patches (premium accounts only).
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

TIER="${SPOTIFY_TIER:-free}"
STATE_DIR="$HOME/.config/linux-setup"; mkdir -p "$STATE_DIR"
TIER_FILE="$STATE_DIR/spotx-tier"

# --- 1. Spotify itself ----------------------------------------------------------------
SP_DIR=""
if [ "$PKG_FAMILY" = "debian" ]; then
  if is_snap_installed spotify; then
    spin_run "Removing the Snap build of Spotify (SpotX can't patch it)" sudo snap remove spotify
  fi
  if ! is_pkg_installed spotify-client; then
    curl -fsSL https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg \
      | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
    echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list >/dev/null
    pm_refresh_needed; pm_refresh
  fi
  pkg "Spotify" spotify-client || exit 1
  SP_DIR="/usr/share/spotify"
else
  flatpak_app "Spotify" com.spotify.Client || exit 1
  LOC="$(flatpak info --show-location com.spotify.Client 2>/dev/null)"
  SP_DIR="$LOC/files/extra/share/spotify"
fi

if [ ! -d "$SP_DIR/Apps" ]; then
  err "Spotify files not found at $SP_DIR — can't apply SpotX."
  record FAIL step "SpotX patches" "Spotify install folder not found"
  exit 1
fi

# --- 2. SpotX ----------------------------------------------------------------------------
FLAGS=(-h -l -P "$SP_DIR")
[ "$TIER" = "premium" ] && FLAGS+=(-p)

PATCHED=0; ls "$SP_DIR"/Apps/*.bak >/dev/null 2>&1 && PATCHED=1
LAST_TIER="$(cat "$TIER_FILE" 2>/dev/null || true)"

if [ "$PATCHED" -eq 1 ] && [ "$LAST_TIER" = "$TIER" ]; then
  skipped "SpotX ($TIER)" "already patched"
  exit 0
fi
# Patched before with the other tier → force a re-patch with the right one.
[ "$PATCHED" -eq 1 ] && FLAGS+=(-f)

SPOTX="$(mktemp --suffix=.sh)"
if ! spin_run "Downloading SpotX" _download "https://raw.githubusercontent.com/SpotX-Official/SpotX-Bash/main/spotx.sh" "$SPOTX"; then
  record FAIL step "SpotX patches" "$SPIN_REASON"; rm -f "$SPOTX"; exit 1
fi
if spin_run "Applying SpotX ($TIER patches)" bash "$SPOTX" "${FLAGS[@]}"; then
  echo "$TIER" > "$TIER_FILE"
  record OK cfg "SpotX ($TIER)"
  [ "$PKG_FAMILY" != "debian" ] && next_step "After a Spotify Flatpak update, run ./install.sh 15 to re-apply SpotX."
else
  record FAIL step "SpotX patches" "$SPIN_REASON"
fi
rm -f "$SPOTX"
