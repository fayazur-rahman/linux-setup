#!/usr/bin/env bash
# System update + baseline utilities every other module can assume exist
# (curl, wget, ca-certificates, gnupg, repo-management tooling). On Fedora,
# this is also where RPM Fusion + the multimedia codec group get enabled,
# since later modules (GPU drivers, media players) depend on them.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "Updating package lists"
case "$PKG_FAMILY" in
  debian)
    apt_update_once
    spin_run "System upgrade" sudo apt-get upgrade -y
    pkg_install_many software-properties-common apt-transport-https ca-certificates gnupg lsb-release
    ;;
  rpm)
    rpm_refresh_once
    spin_run "System upgrade" sudo "$PKG_MANAGER" upgrade -y
    pkg_install_many dnf-plugins-core ca-certificates gnupg2

    # Fedora-specific: enable RPM Fusion (free + nonfree) and pull in the
    # multimedia codec group. Fedora ships without these by patent/licensing
    # policy, and NVIDIA drivers, full ffmpeg, VLC codecs, etc. need them.
    ensure_rpmfusion
    if [ "$DISTRO_ID" = "fedora" ]; then
      # Swap Fedora's limited ffmpeg-free for RPM Fusion's full ffmpeg build,
      # and install the multimedia group for broad codec support. Both are
      # tolerant of "nothing to do" on a system where they're already set.
      spin_run "Full ffmpeg (codec swap)" sudo "$PKG_MANAGER" swap -y ffmpeg-free ffmpeg --allowerasing
      spin_run "Multimedia codec group" sudo "$PKG_MANAGER" group install -y multimedia
    fi
    ;;
  *)
    err "Unsupported package family — cannot continue"
    exit 1
    ;;
esac

ok "Base system updated"
