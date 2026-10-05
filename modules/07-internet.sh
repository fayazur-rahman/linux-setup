#!/usr/bin/env bash
# Title:    Internet
# Installs: qBittorrent · FileZilla · Cloudflare WARP
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init
pm_refresh

pkg "qBittorrent" qbittorrent
pkg "FileZilla"   filezilla

# --- Cloudflare WARP -----------------------------------------------------------
if is_cmd warp-cli; then
  skipped "Cloudflare WARP"; record SKIP app "Cloudflare WARP"
elif [ "$PKG_FAMILY" = "debian" ]; then
  # Cloudflare only publishes some codenames; derivatives (Mint, Pop!_OS…) report
  # their own, so try the Ubuntu/Debian base codename first and verify it exists.
  # shellcheck disable=SC1091
  . /etc/os-release
  CF_CODENAME=""
  for c in "${UBUNTU_CODENAME:-}" "${VERSION_CODENAME:-}" noble jammy bookworm; do
    [ -z "$c" ] && continue
    if curl -fsSL -o /dev/null "https://pkg.cloudflareclient.com/dists/${c}/Release" 2>/dev/null; then
      CF_CODENAME="$c"; break
    fi
  done
  if [ -z "$CF_CODENAME" ]; then
    err "Cloudflare WARP — no repository for this release"; record FAIL app "Cloudflare WARP" "no repository for this release"
  else
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg \
      | sudo gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${CF_CODENAME} main" \
      | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null
    pm_refresh_needed; pm_refresh
    pkg "Cloudflare WARP" cloudflare-warp
  fi
else
  if [ ! -f /etc/yum.repos.d/cloudflare-warp.repo ]; then
    spin_run "Adding the Cloudflare WARP repository" bash -c \
      'curl -fsSL https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo | sudo tee /etc/yum.repos.d/cloudflare-warp.repo >/dev/null'
    pm_refresh_needed; pm_refresh
  fi
  pkg "Cloudflare WARP" - cloudflare-warp
fi
if is_cmd warp-cli; then next_step "Connect Cloudflare WARP once: warp-cli registration new && warp-cli connect"; fi
