#!/usr/bin/env bash
# Installs GNOME Shell extensions via the `gnome-extensions-cli` (gext) tool,
# which can install directly from extensions.gnome.org by UUID — far more
# reliable for scripting than clicking through the Extension Manager GUI.
#
# Extensions requested:
#   Dash to Panel, Caffeine, Blur My Shell (optional), GSConnect,
#   AppIndicator (KStatusNotifierItem/AppIndicator Support),
#   Clipboard Indicator (clipboard saver), Just Perfection
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro
[ "$PKG_FAMILY" = "debian" ] && apt_update_once
[ "$PKG_FAMILY" = "rpm" ] && rpm_refresh_once

section "GNOME Tweaks + Extension Manager + Extensions"

pkg_install gnome-tweaks gnome-tweaks
if [ "$PKG_FAMILY" = "debian" ]; then
  pkg_install gnome-shell-extension-manager gnome-shell-extension-manager
  pkg_install gnome-shell-extension-prefs gnome-shell-extension-prefs 2>/dev/null
fi

# gnome-extensions-cli (gext) — lets us install extensions by UUID from the CLI
if ! is_cmd gext; then
  log "Installing gnome-extensions-cli (pipx) ..."
  pkg_install pipx pipx
  if is_cmd pipx; then
    pipx install gnome-extensions-cli --system-site-packages 2>/dev/null || \
      python3 -m pip install --user gnome-extensions-cli --break-system-packages 2>/dev/null || \
      warn "Could not install gext automatically — install extensions manually via Extension Manager instead."
  fi
fi

declare -A EXTENSIONS=(
  ["dash-to-panel@jderose9.github.com"]="Dash to Panel"
  ["caffeine@patapon.info"]="Caffeine"
  ["blur-my-shell@aunetx"]="Blur My Shell (optional)"
  ["gsconnect@andyholmes.github.io"]="GSConnect"
  ["appindicatorsupport@rgcjonas.gmail.com"]="AppIndicator Support"
  ["clipboard-indicator@tudmotu.com"]="Clipboard Indicator (clipboard saver)"
  ["just-perfection-desktop@just-perfection"]="Just Perfection"
)

if is_cmd gext; then
  for uuid in "${!EXTENSIONS[@]}"; do
    name="${EXTENSIONS[$uuid]}"
    if gext list 2>/dev/null | grep -q "$uuid"; then
      ok "$name already installed — skipping"
    else
      log "Installing extension: $name"
      gext install "$uuid" || warn "gext failed for $name — install manually from extensions.gnome.org"
    fi
  done
else
  warn "gext unavailable — install these manually via GNOME Extension Manager:"
  for uuid in "${!EXTENSIONS[@]}"; do
    warn "  ${EXTENSIONS[$uuid]}  ($uuid)"
  done
fi

log "Once installed, run 'gnome-extensions-app' (Extension Manager) to enable + configure each one."
log "You mentioned you'll share your specific per-extension config later — that will slot in as"
log "a follow-up module (e.g. modules/14-gnome-extension-config.sh) once you send it."

ok "GNOME extensions done"
