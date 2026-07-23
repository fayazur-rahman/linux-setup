#!/usr/bin/env bash
# ==============================================================================
# lib/common.sh — shared helpers sourced by every module in modules/
# Provides: distro detection, idempotent package installs, logging, flatpak
# helpers, "already installed?" checks, and a small module runner.
# ==============================================================================

set -uo pipefail

# ---------- logging -----------------------------------------------------------
C_RESET='\033[0m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'; C_RED='\033[0;31m'; C_BLUE='\033[0;34m'

log()      { echo -e "${C_BLUE}[*]${C_RESET} $*"; }
ok()       { echo -e "${C_GREEN}[OK]${C_RESET} $*"; }
warn()     { echo -e "${C_YELLOW}[!]${C_RESET} $*"; }
err()      { echo -e "${C_RED}[ERROR]${C_RESET} $*" >&2; }
section()  { echo -e "\n${C_BLUE}==>${C_RESET} \033[1m$*${C_RESET}"; }

# ---------- distro detection ---------------------------------------------------
# Sets PKG_FAMILY to "debian" or "rpm" (or "unknown"), and PKG_MANAGER to the
# concrete binary to use (apt, dnf, yum).
detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_ID_LIKE="${ID_LIKE:-}"
  else
    DISTRO_ID="unknown"
    DISTRO_ID_LIKE=""
  fi

  if command -v apt-get >/dev/null 2>&1; then
    PKG_FAMILY="debian"
    PKG_MANAGER="apt-get"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_FAMILY="rpm"
    PKG_MANAGER="dnf"
  elif command -v yum >/dev/null 2>&1; then
    PKG_FAMILY="rpm"
    PKG_MANAGER="yum"
  else
    PKG_FAMILY="unknown"
    PKG_MANAGER=""
  fi

  export DISTRO_ID DISTRO_ID_LIKE PKG_FAMILY PKG_MANAGER
  log "Detected distro: ${DISTRO_ID} (family: ${PKG_FAMILY}, manager: ${PKG_MANAGER})"
}

# ---------- "is X already there?" checks ---------------------------------------
is_cmd()        { command -v "$1" >/dev/null 2>&1; }

is_apt_pkg_installed() { dpkg -s "$1" >/dev/null 2>&1; }

is_rpm_pkg_installed() { rpm -q "$1" >/dev/null 2>&1; }

is_pkg_installed() {
  local pkg="$1"
  case "$PKG_FAMILY" in
    debian) is_apt_pkg_installed "$pkg" ;;
    rpm)    is_rpm_pkg_installed "$pkg" ;;
    *)      return 1 ;;
  esac
}

is_flatpak_installed() {
  is_cmd flatpak && flatpak info "$1" >/dev/null 2>&1
}

is_snap_installed() {
  is_cmd snap && snap list 2>/dev/null | grep -q "^$1 "
}

# ---------- generic package install (skips if already present) ----------------
# Usage: pkg_install <apt-name> <rpm-name>
# If only one name is given it is used for both families.
pkg_install() {
  local apt_name="$1"
  local rpm_name="${2:-$1}"
  local name display

  case "$PKG_FAMILY" in
    debian) name="$apt_name" ;;
    rpm)    name="$rpm_name" ;;
    *) warn "Unknown package family, cannot install '$apt_name'"; return 1 ;;
  esac

  if is_pkg_installed "$name"; then
    ok "$name already installed — skipping"
    return 0
  fi

  log "Installing $name ..."
  case "$PKG_FAMILY" in
    debian) sudo apt-get install -y "$name" ;;
    rpm)    sudo "$PKG_MANAGER" install -y "$name" ;;
  esac

  if [ $? -eq 0 ]; then
    ok "$name installed"
  else
    err "Failed to install $name"
  fi
}

# Install a batch of packages in one call (space separated single name that
# is identical on both families).
pkg_install_many() {
  local pkg
  for pkg in "$@"; do
    pkg_install "$pkg"
  done
}

apt_update_once() {
  if [ "$PKG_FAMILY" = "debian" ] && [ -z "${APT_UPDATED:-}" ]; then
    log "Running apt-get update ..."
    sudo apt-get update -y
    export APT_UPDATED=1
  fi
}

rpm_refresh_once() {
  if [ "$PKG_FAMILY" = "rpm" ] && [ -z "${RPM_REFRESHED:-}" ]; then
    log "Refreshing dnf/yum metadata ..."
    sudo "$PKG_MANAGER" makecache -y 2>/dev/null || true
    export RPM_REFRESHED=1
  fi
}

# ---------- flatpak helper -----------------------------------------------------
ensure_flatpak() {
  if ! is_cmd flatpak; then
    log "Installing flatpak ..."
    pkg_install flatpak flatpak
  fi
  if ! flatpak remote-list 2>/dev/null | grep -q flathub; then
    log "Adding Flathub remote ..."
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
}

flatpak_install() {
  local app_id="$1"
  ensure_flatpak
  if is_flatpak_installed "$app_id"; then
    ok "$app_id (flatpak) already installed — skipping"
    return 0
  fi
  log "Installing $app_id via flatpak ..."
  sudo flatpak install -y flathub "$app_id" && ok "$app_id installed" || err "Failed to install $app_id"
}

# ---------- .deb / external-repo download helper -------------------------------
download_and_install_deb() {
  local url="$1" tmp
  tmp="$(mktemp --suffix=.deb)"
  log "Downloading $url ..."
  if curl -fsSL "$url" -o "$tmp"; then
    sudo apt-get install -y "$tmp"
    rm -f "$tmp"
  else
    err "Download failed: $url"
  fi
}

# ---------- module runner ------------------------------------------------------
# Runs a module script if it's executable, records pass/fail into arrays that
# install.sh reports on at the end.
#
# QUIET BY DEFAULT: each module's full output (package manager chatter,
# flatpak "Looking for matches", curl progress, etc.) is captured into its own
# log file under logs/, NOT printed to the terminal. Only a one-line
# pass/fail per module is shown live. On failure, the last ~25 lines of that
# module's log are printed automatically so you can see the actual error
# without having to go dig for it.
#
# Modules that need to prompt the user interactively (read -p, or a
# third-party interactive installer like SpotX) are listed in
# INTERACTIVE_MODULES and run with output attached directly to the terminal
# instead, since redirecting their output would hide the prompts themselves.
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/logs"
INTERACTIVE_MODULES=("14-whatsapp" "15-spotify-spotx")

declare -a MODULES_OK=()
declare -a MODULES_FAILED=()
declare -a MODULES_SKIPPED=()

_is_interactive_module() {
  local name="$1" m
  for m in "${INTERACTIVE_MODULES[@]}"; do
    [ "$m" = "$name" ] && return 0
  done
  return 1
}

run_module() {
  local module_path="$1"
  local module_name
  module_name="$(basename "$module_path" .sh)"

  section "Module: $module_name"
  if [ ! -f "$module_path" ]; then
    warn "Module not found: $module_path — skipping"
    MODULES_SKIPPED+=("$module_name")
    return
  fi

  if _is_interactive_module "$module_name"; then
    if bash "$module_path"; then
      ok "$module_name completed"
      MODULES_OK+=("$module_name")
    else
      err "$module_name FAILED"
      MODULES_FAILED+=("$module_name")
    fi
    return
  fi

  mkdir -p "$LOG_DIR"
  local log_file="$LOG_DIR/${module_name}.log"
  : > "$log_file"

  if bash "$module_path" >"$log_file" 2>&1; then
    ok "$module_name completed  (log: logs/${module_name}.log)"
    MODULES_OK+=("$module_name")
  else
    err "$module_name FAILED — last 25 lines of logs/${module_name}.log:"
    echo "----------------------------------------------------------------"
    tail -n 25 "$log_file" | sed 's/^/    /'
    echo "----------------------------------------------------------------"
    MODULES_FAILED+=("$module_name")
  fi
}

print_summary() {
  section "Summary"
  echo -e "${C_GREEN}Completed:${C_RESET} ${MODULES_OK[*]:-none}"
  [ "${#MODULES_SKIPPED[@]}" -gt 0 ] && echo -e "${C_YELLOW}Skipped:${C_RESET}   ${MODULES_SKIPPED[*]}"
  [ "${#MODULES_FAILED[@]}" -gt 0 ] && echo -e "${C_RED}Failed:${C_RESET}    ${MODULES_FAILED[*]}"
  [ "${#MODULES_FAILED[@]}" -gt 0 ] && echo -e "Full logs for failed modules are in: ${LOG_DIR}/"
}
