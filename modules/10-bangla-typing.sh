#!/usr/bin/env bash
# OpenBangla Keyboard — the actively-maintained, modern equivalent of Avro
# Keyboard on Linux (same phonetic + fixed layouts, proper ibus/fcitx
# integration). Falls back to ibus-avro if OpenBangla isn't packaged for
# your release.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "Bangla typing (Avro replacement)"

if dpkg -s openbangla-keyboard >/dev/null 2>&1 || rpm -q openbangla-keyboard >/dev/null 2>&1; then
  ok "OpenBangla Keyboard already installed — skipping"
else
  if [ "$PKG_FAMILY" = "debian" ]; then
    log "Adding OpenBangla Keyboard PPA ..."
    sudo add-apt-repository -y ppa:sarim/openbangla-keyboard
    apt_update_once
    pkg_install openbangla-keyboard openbangla-keyboard
  else
    warn "No prebuilt RPM found — build from source: https://github.com/OpenBangla/OpenBangla-Keyboard"
  fi
fi

if ! is_cmd openbangla-keyboard 2>/dev/null; then
  warn "OpenBangla Keyboard not detected after install attempt — falling back to ibus-avro"
  pkg_install ibus-avro ibus-avro
fi

log "After install: log out/in, then enable the input method via"
log "Settings > Keyboard > Input Sources, or 'ibus-setup'."

ok "Bangla typing done"
