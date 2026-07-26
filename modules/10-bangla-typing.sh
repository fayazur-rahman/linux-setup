#!/usr/bin/env bash
# OpenBangla Keyboard — the actively-maintained, modern equivalent of Avro
# Keyboard on Linux (same phonetic + fixed layouts). It ships two input-method
# backends: iBus (best on GNOME/Cinnamon) and Fcitx5 (best on KDE Plasma,
# whose iBus support is notoriously poor). We pick the backend to match the
# detected desktop.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro
detect_desktop

section "Bangla typing (Avro replacement)"

_already_installed() {
  is_cmd openbangla-keyboard 2>/dev/null \
    || dpkg -s openbangla-keyboard >/dev/null 2>&1 \
    || rpm -q ibus-openbangla >/dev/null 2>&1 \
    || rpm -q fcitx-openbangla >/dev/null 2>&1
}

if _already_installed; then
  ok "OpenBangla Keyboard (already installed)"
elif [ "$PKG_FAMILY" = "debian" ]; then
  # Debian/Ubuntu: the project's official install script detects the distro
  # and installs the right package itself (ibus-based).
  log "Running OpenBangla Keyboard's official install script ..."
  spin_run "OpenBangla Keyboard (official installer)" \
    bash -c "curl -fsSL https://raw.githubusercontent.com/OpenBangla/OpenBangla-Keyboard/master/tools/install.sh | bash"

elif [ "$PKG_FAMILY" = "rpm" ] && [ "$DISTRO_ID" = "fedora" ]; then
  # Fedora: install from the maintainer's COPR. Pick the backend that matches
  # the desktop — Fcitx5 on KDE (ibus barely works on Plasma), iBus on GNOME.
  spin_run "Enable OpenBangla COPR" sudo "$PKG_MANAGER" copr enable -y badshah/openbangla-keyboard
  rpm_refresh_once
  if [ "$DESKTOP_ENV" = "kde" ]; then
    log "KDE detected — installing the Fcitx5 backend (fcitx-openbangla)."
    pkg_install fcitx5 fcitx5
    pkg_install fcitx5-configtool fcitx5-configtool 2>/dev/null || true
    pkg_install fcitx-openbangla fcitx-openbangla
    OBK_BACKEND="fcitx5"
  else
    log "GNOME/other detected — installing the iBus backend (ibus-openbangla)."
    pkg_install ibus ibus
    pkg_install ibus-openbangla ibus-openbangla
    OBK_BACKEND="ibus"
  fi
else
  warn "OpenBangla Keyboard install here targets Debian/Ubuntu and Fedora only."
  warn "See https://github.com/OpenBangla/OpenBangla-Keyboard for other distros."
fi

# Last-resort fallback only if nothing above landed AND we're on Debian.
if ! _already_installed && [ "$PKG_FAMILY" = "debian" ]; then
  warn "OpenBangla not detected after install attempt — falling back to ibus-avro"
  pkg_install ibus-avro ibus-avro
fi

log "After install: log out/in, then enable the input method:"
if [ "${OBK_BACKEND:-}" = "fcitx5" ] || [ "$DESKTOP_ENV" = "kde" ]; then
  log "  KDE: System Settings > Input Method (Fcitx5) > add 'OpenBangla Keyboard'."
  log "  You may need to set Fcitx5 as the virtual keyboard first."
else
  log "  GNOME/other: run 'ibus-setup' or Settings > Keyboard > Input Sources,"
  log "  then add 'OpenBangla Keyboard' (Bengali)."
fi

ok "Bangla typing done"
