#!/usr/bin/env bash
# LibreOffice (core suite) + OnlyOffice Desktop Editors (better MS-format
# fidelity — worth having alongside LibreOffice for client-facing docx/xlsx/pptx
# work, e.g. your Cikitsa SOW or ERMED reports).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro
[ "$PKG_FAMILY" = "debian" ] && apt_update_once
[ "$PKG_FAMILY" = "rpm" ] && rpm_refresh_once

section "Office suite"

pkg_install libreoffice libreoffice

flatpak_install org.onlyoffice.desktopeditors

section "Email (Thunderbird)"
# Installed via Flatpak rather than `apt install thunderbird` — on recent
# Ubuntu that apt package is a thin transitional wrapper around the Snap
# build, and this keeps the whole toolkit snap-free and consistent with how
# the other desktop apps here are installed.
flatpak_install org.mozilla.Thunderbird

ok "Office suite done"
