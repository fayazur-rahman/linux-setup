#!/usr/bin/env bash
# Title:    Remote access
# Installs: AnyDesk
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

# --- AnyDesk (official repository, so it updates with the system) ----------------
if is_cmd anydesk; then
  skipped "AnyDesk"; record SKIP app "AnyDesk"
elif [ "$PKG_FAMILY" = "debian" ]; then
  if [ ! -f /etc/apt/sources.list.d/anydesk-stable.list ]; then
    curl -fsSL https://keys.anydesk.com/repos/DEB-GPG-KEY | sudo gpg --yes --dearmor -o /usr/share/keyrings/anydesk.gpg
    echo "deb [signed-by=/usr/share/keyrings/anydesk.gpg] https://deb.anydesk.com all main" \
      | sudo tee /etc/apt/sources.list.d/anydesk-stable.list >/dev/null
    pm_refresh_needed
  fi
  pm_refresh
  pkg "AnyDesk" anydesk
else
  if [ ! -f /etc/yum.repos.d/anydesk.repo ]; then
    # repo_gpgcheck=0: DNF5 rejects AnyDesk's repository metadata signature, but
    # every package is still verified against the imported key (gpgcheck=1).
    sudo rpm --import https://keys.anydesk.com/repos/RPM-GPG-KEY 2>/dev/null || true
    sudo tee /etc/yum.repos.d/anydesk.repo >/dev/null << 'REPO'
[anydesk]
name=AnyDesk Fedora - stable
baseurl=https://rpm.anydesk.com/fedora/$basearch/
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://keys.anydesk.com/repos/RPM-GPG-KEY
REPO
    pm_refresh_needed
  fi
  pm_refresh
  pkg "AnyDesk" - anydesk
fi
