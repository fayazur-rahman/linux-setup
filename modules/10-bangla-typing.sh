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
elif is_cmd openbangla-keyboard; then
  ok "OpenBangla Keyboard already installed — skipping"
else
  # There is no real PPA for this (ppa:sarim/openbangla-keyboard doesn't
  # exist) — the project's own documented install method is this bash
  # script, which detects your distro and installs the right package itself.
  log "Running OpenBangla Keyboard's official install script ..."
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/OpenBangla/OpenBangla-Keyboard/master/tools/install.sh)" \
    || warn "Official installer failed — see https://github.com/OpenBangla/OpenBangla-Keyboard/wiki for distro-specific steps"
fi

if ! is_cmd openbangla-keyboard 2>/dev/null; then
  warn "OpenBangla Keyboard not detected after install attempt — falling back to ibus-avro"
  pkg_install ibus-avro ibus-avro
fi

log "After install: log out/in, then enable the input method via"
log "Settings > Keyboard > Input Sources, or 'ibus-setup'."

ok "Bangla typing done"
