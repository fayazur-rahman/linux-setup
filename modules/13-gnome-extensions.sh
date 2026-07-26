#!/usr/bin/env bash
# Installs GNOME Shell extensions via the `gnome-extensions-cli` (gext) tool,
# which can install directly from extensions.gnome.org by UUID — far more
# reliable for scripting than clicking through the Extension Manager GUI.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro
detect_desktop

section "GNOME Tweaks + Extension Manager + Extensions"

# GNOME Shell extensions are a GNOME-only concept — none of this applies on
# KDE Plasma (which uses its own Widgets/KWin scripts instead). Skip the
# whole module cleanly rather than installing gnome-tweaks/gext onto a KDE
# session where they'd be useless.
if [ "$DESKTOP_ENV" != "gnome" ]; then
  warn "Desktop is '${DESKTOP_ENV}', not GNOME — skipping GNOME extensions module."
  if [ "$DESKTOP_ENV" = "kde" ]; then
    log "On KDE Plasma, the equivalents are handled natively:"
    log "  - panel/taskbar   → built in (no Dash-to-Panel needed)"
    log "  - Caffeine        → 'Caffeine' widget or the built-in DND/keep-awake"
    log "  - clipboard        → Klipper (built in, in the system tray)"
    log "  - app indicators   → built into the Plasma system tray"
    log "  - monitor brightness → Plasma's built-in brightness applet (+ ddcutil)"
    log "  Add widgets via: right-click panel > Add Widgets, or 'Get New Widgets'."
  fi
  ok "GNOME extensions module skipped (not applicable on this desktop)"
  exit 0
fi

[ "$PKG_FAMILY" = "debian" ] && apt_update_once
[ "$PKG_FAMILY" = "rpm" ] && rpm_refresh_once

pkg_install gnome-tweaks gnome-tweaks
if [ "$PKG_FAMILY" = "debian" ]; then
  pkg_install gnome-shell-extension-manager gnome-shell-extension-manager
  pkg_install gnome-shell-extension-prefs gnome-shell-extension-prefs 2>/dev/null
fi

# gnome-extensions-cli (gext) — lets us install extensions by UUID from the CLI
if ! is_cmd gext; then
  pkg_install pipx pipx
  if is_cmd pipx; then
    spin_run "gnome-extensions-cli (pipx)" pipx install gnome-extensions-cli --system-site-packages \
      || spin_run "gnome-extensions-cli (pip fallback)" python3 -m pip install --user gnome-extensions-cli --break-system-packages
  fi
fi

# pipx installs to ~/.local/bin, which often isn't on PATH yet within this
# same script invocation (it only gets added to PATH by your shell's rc file
# on next login). Add it explicitly so `is_cmd gext` below actually finds it
# instead of falsely reporting it "unavailable" right after installing it.
export PATH="$HOME/.local/bin:$PATH"

# Extensions to install — UUIDs taken directly from the GNOME Extensions app.
declare -A EXTENSIONS=(
  ["dash-to-panel@jderose9.github.com"]="Dash to Panel"
  ["caffeine@patapon.info"]="Caffeine"
  ["blur-my-shell@aunetx"]="Blur My Shell"
  ["gsconnect@andyholmes.github.io"]="GSConnect"
  ["appindicatorsupport@rgcjonas.gmail.com"]="AppIndicator Support"
  ["clipboard-indicator@tudmotu.com"]="Clipboard Indicator"
  ["just-perfection-desktop@just-perfection"]="Just Perfection"
  ["arcmenu@arcmenu.com"]="ArcMenu"
  ["monitor-brightness-volume@ailin.nemui"]="Monitor Brightness & Volume (ddcutil)"
  ["show-desktop-applet@valent-in"]="Show Desktop Applet"
  ["spotify-controls@Sonath21"]="Spotify Controls + Track Info"
  ["system-monitor@gnome-shell-extensions.gcampax.github.com"]="System Monitor"
)

if is_cmd gext; then
  for uuid in "${!EXTENSIONS[@]}"; do
    name="${EXTENSIONS[$uuid]}"
    if gext --filesystem list -a 2>/dev/null | grep -q "$uuid"; then
      ok "$name (already installed)"
      _ledger_record "$EXT_LEDGER" SKIP "$name"
    else
      # gext's default DBus backend pops up an interactive GNOME
      # confirmation dialog per extension (same as installing from a
      # browser) — that would silently block a scripted run.
      # --filesystem installs directly, no dialog needed.
      spin_run "$name" gext --filesystem install "$uuid"
      status=$?
      _ledger_record "$EXT_LEDGER" "$([ $status -eq 0 ] && echo OK || echo FAIL)" "$name"
    fi
  done
else
  err "gext unavailable — install these manually via GNOME Extension Manager:"
  for uuid in "${!EXTENSIONS[@]}"; do
    warn "  ${EXTENSIONS[$uuid]}  ($uuid)"
    _ledger_record "$EXT_LEDGER" FAIL "${EXTENSIONS[$uuid]} (gext unavailable)"
  done
fi

log "gext --filesystem restarts GNOME Shell itself after each install on X11."
log "On Wayland, GNOME Shell can't restart itself live — log out and back in once"
log "after this module runs, then open 'Extension Manager' to enable + configure each one."
