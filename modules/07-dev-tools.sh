#!/usr/bin/env bash
# VS Code + Cloudflare WARP client.
# NOTE: You said "Git: not required" — left OUT deliberately. Uncomment the
# line below if you change your mind later; VS Code's own Git integration
# still needs the git binary to function, so you may hit that wall.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "Dev tools"

# --- VS Code ---------------------------------------------------------------
if is_cmd code; then
  ok "VS Code already installed — skipping"
elif [ "$PKG_FAMILY" = "debian" ]; then
  log "Adding Microsoft VS Code repo ..."
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
  sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /usr/share/keyrings/packages.microsoft.gpg
  echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
    sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
  rm -f /tmp/packages.microsoft.gpg
  apt_update_once
  pkg_install code code
elif [ "$PKG_FAMILY" = "rpm" ]; then
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
  pkg_install code code
fi

# --- Cloudflare WARP ---------------------------------------------------------
if is_cmd warp-cli; then
  ok "Cloudflare WARP already installed — skipping"
elif [ "$PKG_FAMILY" = "debian" ]; then
  log "Adding Cloudflare WARP repo ..."
  curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/cloudflare-client.list > /dev/null
  apt_update_once
  pkg_install cloudflare-warp cloudflare-warp
else
  warn "Cloudflare WARP repo setup in this script targets Debian/Ubuntu only."
  warn "For RPM distros see: https://pkg.cloudflareclient.com/"
fi

# git intentionally skipped per your instruction — uncomment if needed later:
# pkg_install git git

ok "Dev tools done"
