#!/usr/bin/env bash
# ==============================================================================
# lib/common.sh — shared helpers sourced by install.sh and every module.
#
#   - distro + desktop detection
#   - idempotent installers (native package, Flatpak, .deb/.rpm download) that
#     skip anything already present, natively OR as a Flatpak
#   - a live spinner with elapsed time, then one clean ✓ / ✗ line per item
#   - focused error excerpts + a plain-language hint when something fails
#   - a run ledger that feeds the final summary across all modules
#
# Raw command output never reaches the screen: it goes to logs/<module>.log.
# Everything the user should see is written to file descriptor 3, which
# install.sh points at the real terminal before any redirection happens.
# ==============================================================================

set -uo pipefail

# fd 3 = the real terminal. If a module is run on its own (not via
# install.sh), fall back to the current stdout.
if ! { true >&3; } 2>/dev/null; then
  exec 3>&1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
LEDGER="$LOG_DIR/_ledger.tsv"
PREFS_FILE="$LOG_DIR/_prefs.env"

# ---------- colours --------------------------------------------------------------
if [ -t 3 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[38;5;203m'; C_GREEN=$'\033[38;5;114m'; C_YELLOW=$'\033[38;5;221m'
  C_BLUE=$'\033[38;5;75m'; C_CYAN=$'\033[38;5;80m'; C_GREY=$'\033[38;5;245m'
  IS_TTY=1
else
  C_RESET=''; C_BOLD=''; C_DIM=''; C_RED=''; C_GREEN=''; C_YELLOW=''
  C_BLUE=''; C_CYAN=''; C_GREY=''
  IS_TTY=0
fi

# ---------- output -----------------------------------------------------------------
# term/ok/warn/err/info/section → visible on the terminal (fd 3)
# log                            → module log file only
term()    { printf '%s\n' "$*" >&3; }
log()     { [ -n "${CURRENT_MODULE_LOG:-}" ] && printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; return 0; }
ok()      { term "  ${C_GREEN}✓${C_RESET} $*"; log "OK   $*"; }
warn()    { term "  ${C_YELLOW}!${C_RESET} $*"; log "WARN $*"; }
err()     { term "  ${C_RED}✗${C_RESET} $*"; log "FAIL $*"; }
info()    { term "    ${C_GREY}$*${C_RESET}"; log "INFO $*"; }
section() { term ""; term "  ${C_BOLD}$*${C_RESET}"; log "== $*"; }
skipped() { term "  ${C_GREEN}✓${C_RESET} $1 ${C_GREY}— ${2:-already installed}${C_RESET}"; log "SKIP $1 (${2:-already installed})"; }

_fmt_secs() {
  local s=$1
  if [ "$s" -ge 60 ]; then printf '%dm %02ds' $((s / 60)) $((s % 60)); else printf '%ds' "$s"; fi
}

# ---------- run ledger -------------------------------------------------------------
# One TSV line per item: STATUS  KIND  MODULE  NAME  DETAIL
#   STATUS: OK | SKIP | FAIL | NOTE      KIND: app | ext | cfg | step | next
record() {
  mkdir -p "$LOG_DIR"
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "${CURRENT_MODULE:-manual}" "$3" "${4:-}" >> "$LEDGER"
}
# A line for the "Next steps" block of the final summary (deduplicated there).
next_step() { record NOTE next "$1"; }

# ---------- distro / desktop -----------------------------------------------------
detect_distro() {
  DISTRO_ID="unknown"; DISTRO_ID_LIKE=""; DISTRO_NAME="Linux"
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"; DISTRO_ID_LIKE="${ID_LIKE:-}"
    DISTRO_NAME="${PRETTY_NAME:-${NAME:-Linux}}"
  fi
  if command -v apt-get >/dev/null 2>&1; then
    PKG_FAMILY="debian"; PKG_MANAGER="apt-get"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_FAMILY="rpm"; PKG_MANAGER="dnf"
  else
    PKG_FAMILY="unknown"; PKG_MANAGER=""
  fi
  IS_FEDORA=0
  if [ "$DISTRO_ID" = "fedora" ]; then IS_FEDORA=1
  elif [ "$PKG_FAMILY" = "rpm" ]; then case "$DISTRO_ID_LIKE" in *fedora*) IS_FEDORA=1 ;; esac
  fi
  export DISTRO_ID DISTRO_ID_LIKE DISTRO_NAME PKG_FAMILY PKG_MANAGER IS_FEDORA
}

detect_desktop() {
  local d
  d="$(printf '%s' "${XDG_CURRENT_DESKTOP:-}${DESKTOP_SESSION:-}" | tr '[:upper:]' '[:lower:]')"
  case "$d" in
    *kde*|*plasma*) DESKTOP_ENV="kde" ;;
    *gnome*|*unity*) DESKTOP_ENV="gnome" ;;
    *)
      if pgrep -x plasmashell >/dev/null 2>&1; then DESKTOP_ENV="kde"
      elif pgrep -x gnome-shell >/dev/null 2>&1; then DESKTOP_ENV="gnome"
      else DESKTOP_ENV="other"
      fi ;;
  esac
  export DESKTOP_ENV
}

# Modules call this once at the top.
module_init() {
  detect_distro
  detect_desktop
  # shellcheck disable=SC1090
  [ -f "$PREFS_FILE" ] && . "$PREFS_FILE"
  log "distro=$DISTRO_ID family=$PKG_FAMILY desktop=$DESKTOP_ENV"
}

is_fedora_kde() { [ "$IS_FEDORA" -eq 1 ] && [ "$DESKTOP_ENV" = "kde" ]; }

# ---------- presence checks ----------------------------------------------------------
is_cmd() { command -v "$1" >/dev/null 2>&1; }

is_pkg_installed() {
  case "$PKG_FAMILY" in
    debian) dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed" ;;
    rpm)    rpm -q "$1" >/dev/null 2>&1 ;;
    *)      return 1 ;;
  esac
}

is_flatpak_installed() {
  is_cmd flatpak || return 1
  flatpak info --system "$1" >/dev/null 2>&1 || flatpak info --user "$1" >/dev/null 2>&1
}

is_snap_installed() { is_cmd snap && snap list "$1" >/dev/null 2>&1; }

# ---------- error excerpt + hint -------------------------------------------------------
_strip() { sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g' "$1" | tr '\r' '\n' | grep -vE '^[[:space:]]*$'; }

# Up to 4 lines that actually explain the failure, not the last bit of noise.
_error_excerpt() {
  local cleaned hits
  cleaned="$(_strip "$1")"
  hits="$(printf '%s\n' "$cleaned" \
    | grep -iE '(^E: |error|failed|fatal|not found|no match|nothing provides|cannot|unable to|denied|conflict|could not|timed out|404|refused|problem:)' \
    | grep -viE '^[[:space:]]*(warning|w:)' | awk '!seen[$0]++' | tail -n 4)"
  [ -z "$hits" ] && hits="$(printf '%s\n' "$cleaned" | tail -n 3)"
  printf '%s\n' "$hits" | cut -c1-150
}

# One plain-language guess at the cause.
_error_hint() {
  local text; text="$(_strip "$1" | tr '[:upper:]' '[:lower:]')"
  case "$text" in
    *"could not resolve"*|*"temporary failure in name resolution"*|*"network is unreachable"*|*"timed out"*|*"curl: (6)"*|*"curl: (7)"*|*"curl: (28)"*)
      echo "Network problem — check your internet connection and run the script again." ;;
    *"a password is required"*|*"sudo: a terminal is required"*)
      echo "The sudo session expired — run the script again." ;;
    *"no match for argument"*|*"unable to locate package"*|*"nothing provides"*|*"no package"*available*)
      echo "Package not found in the enabled repositories for this release." ;;
    *"no remote refs found"*|*"nothing matches"*)
      echo "This Flatpak ID isn't on Flathub (it may have been renamed)." ;;
    *"could not get lock"*|*"waiting for process with pid"*|*"lock"*held*)
      echo "Another package manager is running (Software / updates). Wait for it, then re-run." ;;
    *"gpg"*|*"signature"*|*"nopubkey"*)
      echo "Repository signing key problem — the vendor may have rotated its key." ;;
    *"no space left"*)
      echo "Out of disk space — free some space and re-run." ;;
    *"404"*|*"not found (http"*)
      echo "Download link returned 404 — the vendor moved the file." ;;
    *) echo "" ;;
  esac
}

# ---------- spinner ----------------------------------------------------------------------
# spin_run [-a] "Label" command args...
#   -a  label is an app name: shows "Installing <Label>" while running and
#       "<Label> — installed" when done.
# Command output goes to the module log; stdin is closed so nothing can hang
# waiting for input. On failure the excerpt + hint are printed and kept in
# SPIN_REASON for the ledger.
_SPIN_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
SPIN_REASON=""

spin_run() {
  local app=0
  [ "${1:-}" = "-a" ] && { app=1; shift; }
  local label="$1"; shift
  local running="$label"; [ "$app" -eq 1 ] && running="Installing $label"
  local out start pid rc i=0 elapsed
  out="$(mktemp)"; start=$SECONDS

  "$@" >"$out" 2>&1 </dev/null &
  pid=$!

  if [ "$IS_TTY" -eq 1 ]; then
    while kill -0 "$pid" 2>/dev/null; do
      elapsed=$((SECONDS - start))
      printf '\r\033[K  %s%s%s %s %s%s%s' "$C_CYAN" "${_SPIN_FRAMES[i % 10]}" "$C_RESET" \
        "$running" "$C_GREY" "$( [ "$elapsed" -ge 2 ] && _fmt_secs "$elapsed")" "$C_RESET" >&3
      i=$((i + 1))
      sleep 0.1
    done
  fi
  wait "$pid"; rc=$?
  elapsed=$((SECONDS - start))

  { echo "----- $running  (exit $rc, $(_fmt_secs "$elapsed")) -----"; cat "$out"; echo; } >> "${CURRENT_MODULE_LOG:-/dev/null}"

  [ "$IS_TTY" -eq 1 ] && printf '\r\033[K' >&3
  local t=""; [ "$elapsed" -ge 2 ] && t=" ${C_GREY}($(_fmt_secs "$elapsed"))${C_RESET}"
  if [ "$rc" -eq 0 ]; then
    SPIN_REASON=""
    if [ "$app" -eq 1 ]; then term "  ${C_GREEN}✓${C_RESET} $label ${C_GREY}— installed${C_RESET}$t"
    else term "  ${C_GREEN}✓${C_RESET} $label$t"; fi
  else
    local excerpt hint
    excerpt="$(_error_excerpt "$out")"; hint="$(_error_hint "$out")"
    SPIN_REASON="$(printf '%s\n' "$excerpt" | tail -n 1)"
    if [ "$app" -eq 1 ]; then term "  ${C_RED}✗${C_RESET} $label ${C_RED}— failed to install${C_RESET}"
    else term "  ${C_RED}✗${C_RESET} $label ${C_RED}— failed${C_RESET}"; fi
    while IFS= read -r line; do term "      ${C_GREY}│${C_RESET} $line"; done <<< "$excerpt"
    [ -n "$hint" ] && term "      ${C_YELLOW}→${C_RESET} $hint"
    [ -n "${CURRENT_MODULE_LOG:-}" ] && term "      ${C_GREY}↳ full output: logs/$(basename "$CURRENT_MODULE_LOG")${C_RESET}"
  fi
  rm -f "$out"
  return "$rc"
}

# ---------- package manager plumbing --------------------------------------------------
_pm_install() {   # raw install, used inside spin_run
  case "$PKG_FAMILY" in
    debian) sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::=--force-confold "$@" ;;
    rpm)    sudo dnf install -y "$@" ;;
  esac
}

# Refresh package metadata at most once per run (a marker file is shared by
# all modules; install.sh clears it at the start of every run).
REFRESH_MARKER="$LOG_DIR/_refreshed"
pm_refresh() {
  [ -f "$REFRESH_MARKER" ] && return 0
  case "$PKG_FAMILY" in
    debian) spin_run "Refreshing package lists" sudo apt-get update ;;
    rpm)    spin_run "Refreshing package metadata" sudo dnf makecache ;;
  esac
  mkdir -p "$LOG_DIR"; touch "$REFRESH_MARKER"
}

# Force the next pm_refresh to run (after adding a repository).
pm_refresh_needed() { rm -f "$REFRESH_MARKER"; }

# ---------- installers -------------------------------------------------------------------
# pkg "Label" <deb-package> [rpm-package]
#   Use "-" for a family where the package isn't available.
#   The rpm name defaults to the deb name.
pkg() {
  local label="$1" deb="$2" rpmn="${3:-$2}" name
  case "$PKG_FAMILY" in debian) name="$deb" ;; rpm) name="$rpmn" ;; *) name="-" ;; esac
  if [ "$name" = "-" ]; then
    skipped "$label" "not available on this distro"
    return 0
  fi
  if is_pkg_installed "$name"; then
    skipped "$label"; record SKIP app "$label"; return 0
  fi
  if spin_run -a "$label" _pm_install "$name"; then
    record OK app "$label"; return 0
  fi
  record FAIL app "$label" "$SPIN_REASON"; return 1
}

# Install several packages under a single label (e.g. a build toolchain).
pkg_group() {
  local label="$1"; shift
  local missing=() p
  for p in "$@"; do is_pkg_installed "$p" || missing+=("$p"); done
  if [ "${#missing[@]}" -eq 0 ]; then skipped "$label"; record SKIP app "$label"; return 0; fi
  if spin_run -a "$label" _pm_install "${missing[@]}"; then record OK app "$label"; return 0; fi
  record FAIL app "$label" "$SPIN_REASON"; return 1
}

ensure_flathub() {
  [ -n "${FLATHUB_READY:-}" ] && return 0
  if ! is_cmd flatpak; then pkg "Flatpak" flatpak flatpak || return 1; fi
  if ! flatpak remotes --system 2>/dev/null | grep -q '^flathub'; then
    spin_run "Adding Flathub" sudo flatpak remote-add --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo || return 1
  fi
  # Fedora ships Flathub as a filtered remote on some installs; make it complete.
  sudo flatpak remote-modify --system --no-filter --enable flathub >/dev/null 2>&1 || true
  export FLATHUB_READY=1
}

# flatpak_app "Label" <app-id> [native-command ...]
#   Skips when the Flatpak OR any listed native command is already present,
#   so an app installed from the distro repos is never duplicated.
flatpak_app() {
  local label="$1" id="$2"; shift 2
  local c
  if is_flatpak_installed "$id"; then skipped "$label"; record SKIP app "$label"; return 0; fi
  for c in "$@"; do
    if is_cmd "$c"; then skipped "$label" "already installed (native package)"; record SKIP app "$label"; return 0; fi
  done
  ensure_flathub || { record FAIL app "$label" "Flathub unavailable"; return 1; }
  if spin_run -a "$label" sudo flatpak install -y --noninteractive --system flathub "$id"; then
    record OK app "$label"; return 0
  fi
  record FAIL app "$label" "$SPIN_REASON"; return 1
}

_download() { curl -fsSL --retry 3 --connect-timeout 15 "$1" -o "$2"; }

# url_package "Label" <url>   — download a .deb/.rpm and install it locally.
url_package() {
  local label="$1" url="$2" ext tmp
  case "$PKG_FAMILY" in debian) ext=deb ;; rpm) ext=rpm ;; *) return 1 ;; esac
  tmp="$(mktemp --suffix=".$ext")"
  if ! spin_run "Downloading $label" _download "$url" "$tmp"; then
    rm -f "$tmp"; record FAIL app "$label" "$SPIN_REASON"; return 1
  fi
  chmod 644 "$tmp"
  if spin_run -a "$label" _pm_install "$tmp"; then
    rm -f "$tmp"; record OK app "$label"; return 0
  fi
  rm -f "$tmp"; record FAIL app "$label" "$SPIN_REASON"; return 1
}

# ---------- Fedora: RPM Fusion ----------------------------------------------------------
ensure_rpmfusion() {
  [ "$IS_FEDORA" -eq 1 ] || return 0
  if rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1; then
    skipped "RPM Fusion repositories" "already enabled"; return 0
  fi
  local ver; ver="$(rpm -E %fedora)"
  if spin_run "Enabling RPM Fusion (free + nonfree)" sudo dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${ver}.noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${ver}.noarch.rpm"; then
    record OK step "RPM Fusion repositories"
    pm_refresh_needed; pm_refresh
  else
    record FAIL step "RPM Fusion repositories" "$SPIN_REASON"; return 1
  fi
}

# ---------- module discovery -------------------------------------------------------------
# Each module declares two header lines:
#   # Title:    Short name shown in headers and --list
#   # Installs: What it installs or configures (one line)
module_field() { sed -n "s/^# $2:[[:space:]]*//p" "$1" | head -n 1; }

# ---------- module runner ----------------------------------------------------------------
declare -a MODULES_OK=() MODULES_FAILED=()

run_module() {
  local path="$1" idx="$2" total="$3" name title log_file
  shift 3   # anything left is passed through to the module
  name="$(basename "$path" .sh)"
  title="$(module_field "$path" Title)"; title="${title:-$name}"
  term ""
  term "${C_BLUE}${C_BOLD}[$(printf '%2d' "$idx")/${total}]${C_RESET} ${C_BOLD}${title}${C_RESET}"

  if [ ! -f "$path" ]; then
    warn "Module file not found: $path"; MODULES_FAILED+=("$name"); return
  fi

  mkdir -p "$LOG_DIR"
  log_file="$LOG_DIR/${name}.log"
  : > "$log_file"

  local before after
  before="$(grep -c "^FAIL" "$LEDGER" 2>/dev/null || true)"
  if CURRENT_MODULE="$name" CURRENT_MODULE_LOG="$log_file" bash "$path" "$@" >>"$log_file" 2>&1; then
    MODULES_OK+=("$name")
  else
    after="$(grep -c "^FAIL" "$LEDGER" 2>/dev/null || true)"
    # Only dump the log tail if no individual item already explained the failure.
    if [ "${after:-0}" = "${before:-0}" ]; then
      err "$title stopped unexpectedly"
      while IFS= read -r line; do term "      ${C_GREY}│${C_RESET} $line"; done < <(_error_excerpt "$log_file")
      term "      ${C_GREY}↳ full output: logs/${name}.log${C_RESET}"
      CURRENT_MODULE="$name" record FAIL step "$title" "module exited with an error"
    fi
    MODULES_FAILED+=("$name")
  fi
}

# ---------- final summary ----------------------------------------------------------------
_wrap_list() {   # comma-join names and wrap at the terminal width
  local width=${COLUMNS:-100}; [ "$width" -gt 110 ] && width=110
  paste -sd ',' - | sed 's/,/, /g' | fold -s -w $((width - 8)) | sed 's/^/      /'
}

print_summary() {
  local elapsed="$1"
  local bar="────────────────────────────────────────────────────────────"
  term ""
  term "${C_BLUE}${bar}${C_RESET}"
  term "  ${C_BOLD}Summary${C_RESET}  ${C_GREY}${DISTRO_NAME} · ${DESKTOP_ENV} · finished in $(_fmt_secs "$elapsed")${C_RESET}"
  term "${C_BLUE}${bar}${C_RESET}"

  [ -f "$LEDGER" ] || { term "  Nothing was recorded."; return; }

  _block() {   # _block <colour> <heading> <awk filter>
    local items count
    items="$(awk -F'\t' "$3"' {print $4}' "$LEDGER" | awk '!seen[$0]++')"
    [ -z "$items" ] && return
    count="$(printf '%s\n' "$items" | wc -l)"
    term ""
    term "  $1$2 ($count)${C_RESET}"
    printf '%s\n' "$items" | _wrap_list >&3
  }

  _block "$C_GREEN" "Installed"          '$1=="OK"   && $2=="app"'
  _block "$C_GREY"  "Already installed"  '$1=="SKIP" && $2=="app"'
  _block "$C_GREEN" "GNOME extensions"   '($1=="OK" || $1=="SKIP") && $2=="ext"'
  _block "$C_GREEN" "Configured"         '$1=="OK"   && ($2=="cfg" || $2=="step")'

  local failures
  failures="$(awk -F'\t' '$1=="FAIL"' "$LEDGER")"
  if [ -n "$failures" ]; then
    term ""
    term "  ${C_RED}Failed ($(printf '%s\n' "$failures" | wc -l))${C_RESET}"
    while IFS=$'\t' read -r _ _ mod item reason; do
      term "    ${C_RED}✗${C_RESET} $item${reason:+ ${C_GREY}— $reason${C_RESET}}"
      term "      ${C_GREY}↳ logs/${mod}.log${C_RESET}"
    done <<< "$failures"
    term ""
    term "  ${C_GREY}Fix the cause and run ./install.sh again — finished items are skipped.${C_RESET}"
  else
    term ""
    term "  ${C_GREEN}Nothing failed.${C_RESET}"
  fi

  local steps
  steps="$(awk -F'\t' '$1=="NOTE" && $2=="next" {print $4}' "$LEDGER" | awk '!seen[$0]++')"
  if [ -n "$steps" ]; then
    term ""
    term "  ${C_YELLOW}Next steps${C_RESET}"
    local n=1
    while IFS= read -r s; do term "    $n. $s"; n=$((n + 1)); done <<< "$steps"
  fi
  term ""
}

# ---------- GNOME custom keyboard shortcuts ----------------------------------------------
_MK="org.gnome.settings-daemon.plugins.media-keys"
_kb_path() { printf '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-%s/' "$1"; }

# _kb_list add|remove <path>   — edit the list of custom shortcut paths
_kb_list() {
  local cur new
  cur="$(gsettings get "$_MK" custom-keybindings 2>/dev/null || echo '[]')"
  new="$(python3 - "$cur" "$1" "$2" << 'PY'
import ast, sys
cur, action, path = sys.argv[1].replace("@as ", ""), sys.argv[2], sys.argv[3]
try: items = list(ast.literal_eval(cur))
except Exception: items = []
if action == "add" and path not in items: items.append(path)
if action == "remove": items = [i for i in items if i != path]
print(str(items))
PY
)"
  [ "$new" != "$cur" ] && gsettings set "$_MK" custom-keybindings "$new"
}

_gs_str() { gsettings get "$1" "$2" 2>/dev/null | sed "s/^'//; s/'\$//"; }

# gnome_shortcut <id> <Name> <command> <binding>
#   returns 0 when it was created/updated, 2 when it was already exactly like this
gnome_shortcut() {
  local path schema
  path="$(_kb_path "$1")"; schema="$_MK.custom-keybinding:$path"
  if [ "$(_gs_str "$schema" binding)" = "$4" ] && [ "$(_gs_str "$schema" command)" = "$3" ] \
     && gsettings get "$_MK" custom-keybindings 2>/dev/null | grep -qF "$path"; then
    return 2
  fi
  _kb_list add "$path"
  gsettings set "$schema" name "$2"
  gsettings set "$schema" command "$3"
  gsettings set "$schema" binding "$4"
}

gnome_shortcut_remove() {
  local path; path="$(_kb_path "$1")"
  gsettings get "$_MK" custom-keybindings 2>/dev/null | grep -qF "$path" || return 1
  _kb_list remove "$path"
  gsettings reset-recursively "$_MK.custom-keybinding:$path" 2>/dev/null || true
}
