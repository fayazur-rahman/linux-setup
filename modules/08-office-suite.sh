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

ok "Office suite done"
