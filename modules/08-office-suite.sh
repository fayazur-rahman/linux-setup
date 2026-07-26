#!/usr/bin/env bash
# Office suite + email client.
#
# On Fedora KDE Plasma, this entire module is a no-op: the KDE spin already
# ships LibreOffice (via the kde-desktop-environment group defaults) and
# KMail (via kde-pim), and you've asked to skip OnlyOffice and Thunderbird
# on that combination. Everything installed here would either duplicate an
# already-present app or land unused. Debian/Ubuntu and Fedora-GNOME get
# the full stack.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro
detect_desktop
[ "$PKG_FAMILY" = "debian" ] && apt_update_once
[ "$PKG_FAMILY" = "rpm" ] && rpm_refresh_once

section "Office suite"

if [ "$DISTRO_ID" = "fedora" ] && [ "$DESKTOP_ENV" = "kde" ]; then
  ok "LibreOffice (preinstalled by Fedora KDE Plasma spin — skipping)"
  ok "OnlyOffice (skipped per your preference on Fedora KDE)"
  ok "Thunderbird (skipped — Fedora KDE ships KMail via kde-pim)"
  exit 0
fi

pkg_install libreoffice libreoffice
flatpak_install org.onlyoffice.desktopeditors

section "Email (Thunderbird)"
# Installed via Flatpak rather than `apt install thunderbird` — on recent
# Ubuntu that apt package is a thin transitional wrapper around the Snap
# build, and this keeps the whole toolkit snap-free and consistent with how
# the other desktop apps here are installed.
flatpak_install org.mozilla.Thunderbird

ok "Office suite done"
