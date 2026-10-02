#!/usr/bin/env bash
# Title:    Base system
# Installs: System update · RPM Fusion + full multimedia codecs (Fedora) · Flathub
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

case "$PKG_FAMILY" in
  debian)
    pm_refresh
    spin_run "Updating installed packages" sudo env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
      && record OK step "System update" || record FAIL step "System update" "$SPIN_REASON"
    pkg_group "Repository tools" ca-certificates curl gnupg software-properties-common apt-transport-https
    ;;
  rpm)
    spin_run "Updating installed packages" sudo dnf upgrade -y --refresh \
      && record OK step "System update" || record FAIL step "System update" "$SPIN_REASON"
    mkdir -p "$LOG_DIR"; touch "$REFRESH_MARKER"   # dnf upgrade --refresh already did it
    # "dnf copr" and "dnf config-manager" live in the plugins package
    # (dnf5-plugins on Fedora 41+, dnf-plugins-core before that).
    if rpm -q dnf5 >/dev/null 2>&1; then
      pkg_group "Repository tools" dnf5-plugins ca-certificates curl
    else
      pkg_group "Repository tools" dnf-plugins-core ca-certificates curl
    fi
    ensure_rpmfusion

    if [ "$IS_FEDORA" -eq 1 ]; then
      # Fedora ships a patent-free ffmpeg; RPM Fusion's full build plays everything.
      if rpm -q ffmpeg >/dev/null 2>&1; then
        skipped "Full ffmpeg (RPM Fusion)"
      elif rpm -q ffmpeg-free >/dev/null 2>&1; then
        spin_run "Swapping ffmpeg-free for full ffmpeg" sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing \
          && record OK step "Full ffmpeg" || record FAIL step "Full ffmpeg" "$SPIN_REASON"
      fi
      if rpm -q gstreamer1-plugins-bad-freeworld >/dev/null 2>&1; then
        skipped "Multimedia codecs"
      else
        spin_run "Installing multimedia codecs" sudo dnf group install -y multimedia \
          --setopt=install_weak_deps=False --exclude=PackageKit-gstreamer-plugin \
          && record OK step "Multimedia codecs" || record FAIL step "Multimedia codecs" "$SPIN_REASON"
      fi
    fi
    ;;
  *)
    err "No supported package manager (apt or dnf) found."
    exit 1 ;;
esac

ensure_flathub && ok "Flathub ready"
