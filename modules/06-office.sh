#!/usr/bin/env bash
# Title:    Office & writing
# Installs: LibreOffice (Writer, Calc, Impress) · Apostrophe · Mail Viewer
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init
pm_refresh

# Most desktop editions ship these already; they're skipped when present.
pkg_group "LibreOffice" libreoffice-writer libreoffice-calc libreoffice-impress

flatpak_app "Apostrophe"  org.gnome.gitlab.somas.Apostrophe apostrophe
flatpak_app "Mail Viewer" io.github.alescdb.mailviewer      mailviewer
