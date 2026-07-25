#!/usr/bin/env bash
# ==============================================================================
# lib/common.sh — shared helpers sourced by every module in modules/
# Provides: distro detection, idempotent package installs with a live
# spinner + tick/cross result per item, flatpak helpers, "already installed?"
# checks, and a module runner that keeps full noisy output in a per-module
# log file while showing only clean status lines on screen.
# ==============================================================================

set -uo pipefail

# ---------- terminal channel (fd 3) --------------------------------------------
# Modules run with their own stdout/stderr redirected to a per-module log
# file so raw apt/flatpak/curl output never floods the screen. But section
# headers, spinners, and per-item ✓/✗ results should ALWAYS reach the real
# terminal regardless of that redirection. fd 3 is a duplicate of the
# terminal opened once (by install.sh, before any redirection happens) and
# inherited by every module subprocess — writing to it bypasses whatever
# fd 1/2 happen to be pointed at in the current process.
#
# Guarded so this is also safe if a module is ever run standalone (not
# through install.sh): if fd 3 isn't already open, open it from the current
# stdout.
if ! { true >&3; } 2>/dev/null; then
  exec 3>&1
fi

term() { printf '%b\n' "$*" >&3; }

# ---------- logging -------------------------------------------------------------
# log()   → detailed narration, goes to the module's log file only (quiet).
# ok()/warn()/err()/section() → always visible on the real terminal (fd 3),
#           since these are our own short, curated status lines, not raw
#           command output.
C_RESET='\033[0m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'; C_RED='\033[0;31m'; C_BLUE='\033[0;34m'; C_DIM='\033[2m'

log()      { echo -e "${C_BLUE}[*]${C_RESET} $*"; }
ok()       { term "  ${C_GREEN}✓${C_RESET} $*"; }
warn()     { term "  ${C_YELLOW}!${C_RESET} $*"; }
err()      { term "  ${C_RED}✗${C_RESET} $*"; }
section()  { term "\n${C_BLUE}==>${C_RESET} \033[1m$*${C_RESET}"; }

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

# ---------- ledgers for the final cross-module summary --------------------------
# Each module runs as its own subprocess, so an in-memory array can't
# accumulate "what got installed" across the whole run. Instead every
# install helper appends one line to a small TSV ledger file; install.sh
# reads it back at the very end to print one final report covering every
# module, not just the one that happened to run last.
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/logs"
APPS_LEDGER="$LOG_DIR/_apps.tsv"
EXT_LEDGER="$LOG_DIR/_extensions.tsv"

_ledger_record() {
  # _ledger_record <ledger-file> <STATUS> <name>
  mkdir -p "$LOG_DIR"
  printf '%s\t%s\n' "$2" "$3" >> "$1"
}

# ---------- spinner-driven command runner ---------------------------------------
# spin_run "Label" command args...
# Runs a command in the background, shows a live spinner + label on the real
# terminal while it runs, then replaces that line with a ✓ or ✗ result. Full
# command output (stdout+stderr) is appended to the current module's log
# file (env var CURRENT_MODULE_LOG, set by run_module) regardless of outcome
# — on failure, the last non-empty line of that output is also shown inline
# so an obvious error doesn't require opening the log.
_SPIN_FRAMES='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

spin_run() {
  local label="$1"; shift
  local out; out="$(mktemp)"

  "$@" >"$out" 2>&1 &
  local pid=$!

  local i=0 frame
  while kill -0 "$pid" 2>/dev/null; do
    frame="${_SPIN_FRAMES:$((i % ${#_SPIN_FRAMES})):1}"
    printf '\r  %s %s' "$frame" "$label" >&3
    i=$((i + 1))
    sleep 0.1
  done
  wait "$pid"
  local status=$?

  if [ -n "${CURRENT_MODULE_LOG:-}" ]; then
    { echo "----- $label -----"; cat "$out"; echo; } >> "$CURRENT_MODULE_LOG"
  fi

  if [ "$status" -eq 0 ]; then
    printf '\r\033[K  %b✓%b %s\n' "$C_GREEN" "$C_RESET" "$label" >&3
  else
    printf '\r\033[K  %b✗%b %s\n' "$C_RED" "$C_RESET" "$label" >&3
    local reason
    reason="$(grep -vE '^\s*$' "$out" | tail -n 1 | cut -c1-140)"
    [ -n "$reason" ] && printf '      %b%s%b\n' "$C_DIM" "$reason" "$C_RESET" >&3
  fi

  rm -f "$out"
  return "$status"
}

# ---------- generic package install (skips if already present) ----------------
# Usage: pkg_install <apt-name> <rpm-name>
# If only one name is given it is used for both families.
pkg_install() {
  local apt_name="$1"
  local rpm_name="${2:-$1}"
  local name

  case "$PKG_FAMILY" in
    debian) name="$apt_name" ;;
    rpm)    name="$rpm_name" ;;
    *) err "$apt_name — unknown package family, cannot install"; _ledger_record "$APPS_LEDGER" FAIL "$apt_name"; return 1 ;;
  esac

  if is_pkg_installed "$name"; then
    ok "$name (already installed)"
    _ledger_record "$APPS_LEDGER" SKIP "$name"
    return 0
  fi

  case "$PKG_FAMILY" in
    debian) spin_run "$name" sudo apt-get install -y "$name" ;;
    rpm)    spin_run "$name" sudo "$PKG_MANAGER" install -y "$name" ;;
  esac
  local status=$?
  _ledger_record "$APPS_LEDGER" "$([ $status -eq 0 ] && echo OK || echo FAIL)" "$name"
  return $status
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
    spin_run "Refreshing package lists" sudo apt-get update -y
    export APT_UPDATED=1
  fi
}

rpm_refresh_once() {
  if [ "$PKG_FAMILY" = "rpm" ] && [ -z "${RPM_REFRESHED:-}" ]; then
    spin_run "Refreshing package metadata" sudo "$PKG_MANAGER" makecache -y
    export RPM_REFRESHED=1
  fi
}

# ---------- flatpak helper -----------------------------------------------------
ensure_flatpak() {
  if ! is_cmd flatpak; then
    pkg_install flatpak flatpak
  fi
  if ! flatpak remote-list 2>/dev/null | grep -q flathub; then
    spin_run "Adding Flathub remote" sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
}

flatpak_install() {
  local app_id="$1"
  ensure_flatpak
  if is_flatpak_installed "$app_id"; then
    ok "$app_id (already installed)"
    _ledger_record "$APPS_LEDGER" SKIP "$app_id (flatpak)"
    return 0
  fi
  spin_run "$app_id (flatpak)" sudo flatpak install -y flathub "$app_id"
  local status=$?
  _ledger_record "$APPS_LEDGER" "$([ $status -eq 0 ] && echo OK || echo FAIL)" "$app_id (flatpak)"
  return $status
}

# ---------- .deb / external-repo download helper -------------------------------
download_and_install_deb() {
  local url="$1" tmp label
  tmp="$(mktemp --suffix=.deb)"
  label="$(basename "$url")"
  spin_run "Downloading $label" curl -fsSL "$url" -o "$tmp"
  if [ $? -ne 0 ]; then
    rm -f "$tmp"
    _ledger_record "$APPS_LEDGER" FAIL "$label (download)"
    return 1
  fi
  spin_run "Installing $label" sudo apt-get install -y "$tmp"
  local status=$?
  rm -f "$tmp"
  _ledger_record "$APPS_LEDGER" "$([ $status -eq 0 ] && echo OK || echo FAIL)" "$label"
  return $status
}

# ---------- module runner ------------------------------------------------------
# Runs a module script, records pass/fail into arrays install.sh reports on.
#
# QUIET BY DEFAULT: each module's full output (package manager chatter,
# flatpak "Looking for matches", curl progress, etc.) is captured into its
# own log file under logs/, NOT printed to the terminal. Section headers and
# per-item ✓/✗ lines (via section()/spin_run()) still reach the terminal
# through fd 3 regardless. On module failure, the last ~25 lines of its log
# are also printed automatically.
#
# Modules that need to prompt the user interactively (read -p, or a
# third-party interactive installer like SpotX) are listed in
# INTERACTIVE_MODULES and run with output attached directly to the terminal
# instead, since redirecting their output would hide the prompts themselves.
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

  section "$module_name"
  if [ ! -f "$module_path" ]; then
    warn "Module not found: $module_path — skipping"
    MODULES_SKIPPED+=("$module_name")
    return
  fi

  if _is_interactive_module "$module_name"; then
    if bash "$module_path"; then
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

  if CURRENT_MODULE_LOG="$log_file" bash "$module_path" >"$log_file" 2>&1; then
    MODULES_OK+=("$module_name")
  else
    err "$module_name FAILED — last 25 lines of logs/${module_name}.log:"
    term "----------------------------------------------------------------"
    tail -n 25 "$log_file" | sed 's/^/    /' >&3
    term "----------------------------------------------------------------"
    MODULES_FAILED+=("$module_name")
  fi
}

# ---------- final report ---------------------------------------------------------
# Reads the app/extension ledgers written by every module that ran and
# prints one consolidated report: what installed, what was already there,
# what failed, and what extensions ended up installed — plus the standing
# reminders (reboot / re-login) relevant to whatever actually ran.
print_summary() {
  section "Summary"

  echo -e "${C_GREEN}Modules completed:${C_RESET} ${MODULES_OK[*]:-none}" >&3
  [ "${#MODULES_SKIPPED[@]}" -gt 0 ] && echo -e "${C_YELLOW}Modules skipped:${C_RESET}   ${MODULES_SKIPPED[*]}" >&3
  [ "${#MODULES_FAILED[@]}" -gt 0 ] && echo -e "${C_RED}Modules failed:${C_RESET}    ${MODULES_FAILED[*]}" >&3

  if [ -f "$APPS_LEDGER" ]; then
    local installed skipped failed
    installed="$(awk -F'\t' '$1=="OK"{print "  - "$2}' "$APPS_LEDGER")"
    skipped="$(awk -F'\t' '$1=="SKIP"{print "  - "$2}' "$APPS_LEDGER")"
    failed="$(awk -F'\t' '$1=="FAIL"{print "  - "$2}' "$APPS_LEDGER")"

    [ -n "$installed" ] && { term "\n${C_GREEN}Newly installed:${C_RESET}"; term "$installed"; }
    [ -n "$skipped" ]   && { term "\n${C_DIM}Already present (skipped):${C_RESET}"; term "$skipped"; }
    [ -n "$failed" ]    && { term "\n${C_RED}Failed to install:${C_RESET}"; term "$failed"; }
  fi

  if [ -f "$EXT_LEDGER" ]; then
    local ext_installed ext_failed
    ext_installed="$(awk -F'\t' '$1=="OK" || $1=="SKIP"{print "  - "$2}' "$EXT_LEDGER")"
    ext_failed="$(awk -F'\t' '$1=="FAIL"{print "  - "$2}' "$EXT_LEDGER")"
    [ -n "$ext_installed" ] && { term "\n${C_GREEN}GNOME extensions installed:${C_RESET}"; term "$ext_installed"; }
    [ -n "$ext_failed" ]    && { term "\n${C_RED}GNOME extensions failed:${C_RESET}"; term "$ext_failed"; }
  fi

  [ "${#MODULES_FAILED[@]}" -gt 0 ] && term "\nFull logs for failed modules are in: ${LOG_DIR}/"

  term "\n${C_YELLOW}Next steps:${C_RESET}"
  term "  - Log out and back in (or reboot) — needed for GNOME extensions to fully"
  term "    load, the i2c group change (monitor brightness) to apply, and the"
  term "    NVIDIA driver (if installed) to take effect."
  term "  - Open Extension Manager afterward to confirm/configure extensions."
  term "  - Sign into Brave/Chrome, TeamViewer, Discord, Spotify, Thunderbird etc."
  term "    manually — none of that is scriptable without your credentials."
}
