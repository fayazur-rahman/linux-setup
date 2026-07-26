#!/usr/bin/env bash
# Spotify + SpotX-Bash adblock/patch runner.
# The Spotify tier (free vs premium) is asked ONCE at the start of install.sh
# and written to logs/_prefs.env; we read it here rather than prompting again.
# SpotX applies different patches per tier — free is the default, premium
# needs the -p / --premium flag per SpotX-Bash docs.
#
# Also: SpotX explicitly does NOT support the Snap-packaged Spotify client
# ("Error: Snap client not supported"). On Debian we install from Spotify's
# official apt repo. On Fedora there's no official apt-equivalent, so we
# install the Flatpak un-patched.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

# Read the tier chosen up front by install.sh. Default to "free" if the
# module is ever run standalone without install.sh having asked.
PREFS_FILE="$SCRIPT_DIR/logs/_prefs.env"
[ -f "$PREFS_FILE" ] && . "$PREFS_FILE"
SPOTIFY_TIER="${SPOTIFY_TIER:-free}"

section "Spotify + SpotX  (tier: $SPOTIFY_TIER)"

if [ "$PKG_FAMILY" != "debian" ]; then
  # Fedora path — install the Flatpak un-patched. (SpotX can patch a Flatpak
  # install with -P pointing at ~/.var/app/com.spotify.Client/... , but the
  # exact path varies with Spotify updates and it's fragile to script.)
  warn "SpotX-Bash targets APT-based native installs — can't auto-patch on Fedora."
  log "Installing the Spotify Flatpak instead (un-patched, but you still get the app)."
  flatpak_install com.spotify.Client
  warn "To ad-block a Flatpak Spotify you'd run SpotX with a custom -P path — see"
  warn "  https://github.com/SpotX-Official/SpotX-Bash"
  exit 0
fi

# Debian/Ubuntu path — install Spotify from the official apt repo, NOT snap.
if is_snap_installed spotify; then
  warn "Snap Spotify detected — SpotX cannot patch this. Removing snap package first ..."
  spin_run "Removing snap Spotify" sudo snap remove spotify
fi

if ! is_pkg_installed spotify-client; then
  log "Adding Spotify's official apt repo ..."
  curl -fsSL https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
  echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null
  apt_update_once
  pkg_install spotify-client spotify-client
else
  ok "Spotify (already installed via apt)"
fi

# Build SpotX flags from the tier we captured earlier. For Premium users, the
# -p flag is essential — free-tier patches applied to a paid account are what
# breaks playback in weird ways. Default (no flag) = free patches.
SPOTX_FLAGS=()
if [ "$SPOTIFY_TIER" = "premium" ]; then
  SPOTX_FLAGS+=("--premium")
  log "Running SpotX with --premium flag."
else
  log "Running SpotX with default (free-tier) patches."
fi

# SpotX-Bash has its own interactive prompts (e.g. "hide non-music
# categories?"). We can't spinner-wrap this — the whole point is that its
# UI is visible. This module is listed in INTERACTIVE_MODULES so its output
# is attached to the real terminal directly.
bash <(curl -sSL https://spotx-official.github.io/run.sh) "${SPOTX_FLAGS[@]}"

ok "Spotify + SpotX done"
