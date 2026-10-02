#!/usr/bin/env bash
# Title:    Bangla typing
# Installs: OpenBangla Keyboard (Avro Phonetic) — iBus on GNOME, Fcitx5 on KDE
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

if is_pkg_installed openbangla-keyboard || is_pkg_installed ibus-openbangla || is_pkg_installed fcitx-openbangla; then
  skipped "OpenBangla Keyboard"; record SKIP app "OpenBangla Keyboard"; exit 0
fi

if [ "$PKG_FAMILY" = "rpm" ]; then
  # Maintainer's COPR. KDE's iBus support is poor, so KDE gets the Fcitx5 build.
  if ! ls /etc/yum.repos.d/*openbangla* >/dev/null 2>&1; then
    spin_run "Enabling the OpenBangla repository (COPR)" sudo dnf copr enable -y badshah/openbangla-keyboard
    pm_refresh_needed
  fi
  pm_refresh
  if [ "$DESKTOP_ENV" = "kde" ]; then
    pkg "Fcitx5" - fcitx5
    pkg "OpenBangla Keyboard" - fcitx-openbangla
    next_step "Bangla typing: System Settings › Input Method › add OpenBangla Keyboard."
  else
    pkg "OpenBangla Keyboard" - ibus-openbangla
    next_step "Bangla typing: Settings › Keyboard › Input Sources › + › Bangla › OpenBangla Keyboard."
  fi
else
  if spin_run -a "OpenBangla Keyboard" bash -c \
      'curl -fsSL https://raw.githubusercontent.com/OpenBangla/OpenBangla-Keyboard/master/tools/install.sh | bash'; then
    record OK app "OpenBangla Keyboard"
  else
    record FAIL app "OpenBangla Keyboard" "$SPIN_REASON"
    info "Falling back to ibus-avro (same Avro Phonetic layout)."
    pm_refresh
    pkg "ibus-avro" ibus-avro
  fi
  next_step "Bangla typing: Settings › Keyboard › Input Sources › + › Bangla › OpenBangla Keyboard."
fi
