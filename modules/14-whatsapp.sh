#!/usr/bin/env bash
# WhatsApp has no official Linux desktop client — it's web.whatsapp.com
# everywhere. Functionally identical in Firefox/Brave/Chrome since it's the
# same web app; there is no "better in X browser" difference to chase.
# This installs an optional lightweight Electron-style wrapper (WhatsApp for
# Linux, "whatsapp-for-linux" — unofficial) purely for a dedicated window +
# app-switcher/taskbar icon + native notifications, if you want that instead
# of a browser tab. Skip this module entirely if a browser tab is fine.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "WhatsApp (optional native wrapper)"

read -r -p "Install a dedicated WhatsApp desktop wrapper app? [y/N] " REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  flatpak_install com.rtosta.zapzap
  log "ZapZap installed — a Flatpak WhatsApp client wrapper with native notifications."
else
  log "Skipped — just use web.whatsapp.com in Brave/Chrome/Firefox, they behave identically."
fi

ok "WhatsApp module done"
