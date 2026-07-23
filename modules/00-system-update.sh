#!/usr/bin/env bash
# System update + baseline utilities every other module can assume exist
# (curl, wget, ca-certificates, gnupg, software-properties-common/apt-add-repo
# equivalents).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "Updating package lists"
case "$PKG_FAMILY" in
  debian)
    apt_update_once
    sudo apt-get upgrade -y
    pkg_install_many software-properties-common apt-transport-https ca-certificates gnupg lsb-release
    ;;
  rpm)
    rpm_refresh_once
    sudo "$PKG_MANAGER" upgrade -y
    pkg_install_many dnf-plugins-core ca-certificates gnupg2
    ;;
  *)
    err "Unsupported package family — cannot continue"
    exit 1
    ;;
esac

ok "Base system updated"
