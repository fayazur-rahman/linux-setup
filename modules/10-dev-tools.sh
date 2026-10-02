#!/usr/bin/env bash
# Title:    Development
# Installs: Visual Studio Code
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

if is_cmd code; then
  skipped "Visual Studio Code"; record SKIP app "Visual Studio Code"; exit 0
fi

if [ "$PKG_FAMILY" = "debian" ]; then
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/ms.gpg
  sudo install -D -o root -g root -m 644 /tmp/ms.gpg /usr/share/keyrings/packages.microsoft.gpg
  rm -f /tmp/ms.gpg
  echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
else
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
    | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
fi
pm_refresh_needed; pm_refresh
pkg "Visual Studio Code" code
