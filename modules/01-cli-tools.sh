#!/usr/bin/env bash
# Title:    Command-line tools
# Installs: Vim · curl · wget · build tools · ffmpeg · GParted · archive support (rar, 7z)
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init
pm_refresh

pkg "Vim"  vim vim-enhanced
pkg "curl" curl
pkg "wget" wget

if [ "$PKG_FAMILY" = "debian" ]; then
  pkg "Build tools" build-essential
else
  pkg_group "Build tools" gcc gcc-c++ make automake autoconf kernel-headers
fi

pkg "ffmpeg"  ffmpeg
pkg "GParted" gparted

# Archive support so the file manager can open .rar / .7z.
pkg "unrar" unrar
if [ "$PKG_FAMILY" = "debian" ]; then pkg "7-Zip" p7zip-full; else pkg "7-Zip" 7zip; fi
if [ "$DESKTOP_ENV" = "kde" ]; then pkg "Ark" ark; else pkg "File Roller" file-roller; fi
