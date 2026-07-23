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
  # Cloudflare's repo only has directories for specific codenames (as of
  # this writing: noble, jammy, focal, bionic, xenial, resolute). On Ubuntu
  # derivatives (Mint, Pop!_OS, Zorin, etc.) `lsb_release -cs` can return the
  # derivative's own codename, which doesn't exist on Cloudflare's server and
  # silently produces a repo with no Release file. We prefer the Ubuntu base
  # codename from /etc/os-release (UBUNTU_CODENAME) when present, and verify
  # the repo actually resolves before adding it — falling back through a
  # short list of known-good codenames rather than failing outright.
  CF_CANDIDATES=()
  [ -f /etc/os-release ] && . /etc/os-release
  [ -n "${UBUNTU_CODENAME:-}" ] && CF_CANDIDATES+=("$UBUNTU_CODENAME")
  [ -n "${VERSION_CODENAME:-}" ] && CF_CANDIDATES+=("$VERSION_CODENAME")
  is_cmd lsb_release && CF_CANDIDATES+=("$(lsb_release -cs)")
  CF_CANDIDATES+=(noble jammy focal)   # final fallbacks, newest first

  CF_CODENAME=""
  for c in "${CF_CANDIDATES[@]}"; do
    [ -z "$c" ] && continue
    if curl -fsSL -o /dev/null "https://pkg.cloudflareclient.com/dists/${c}/Release" 2>/dev/null; then
      CF_CODENAME="$c"
      break
    fi
  done

  if [ -n "$CF_CODENAME" ]; then
    log "Adding Cloudflare WARP repo for codename '$CF_CODENAME' ..."
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${CF_CODENAME} main" | \
      sudo tee /etc/apt/sources.list.d/cloudflare-client.list > /dev/null
    sudo apt-get update -y
    pkg_install cloudflare-warp cloudflare-warp
  else
    warn "Could not find a working Cloudflare WARP repo for this distro/release."
    warn "Check current supported codenames at: https://pkg.cloudflareclient.com/"
  fi
else
  warn "Cloudflare WARP repo setup in this script targets Debian/Ubuntu only."
  warn "For RPM distros see: https://pkg.cloudflareclient.com/"
fi

# git intentionally skipped per your instruction — uncomment if needed later:
# pkg_install git git

ok "Dev tools done"
