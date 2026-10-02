#!/usr/bin/env bash
# Title:    Firefox profiles
# Installs: Separate Firefox profiles, each with its own launcher and dock icon
#
# The number of profiles is asked once at the start of install.sh (default 3).
# Profiles are created in this order:
#   1  default-release  → "Firefox Personal"  (full-colour icon)
#   2  Work             → "Firefox Work"      (monochrome icon)
#   3  Personal         → "Security Center"   (opens only after a password check)
#   4+ Profile N        → "Firefox Profile N"
# Only the password HASH is stored (in ~/.local/bin/security-center), never the
# password itself. The check gates launching; it does not encrypt the profile.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

COUNT="${FIREFOX_PROFILES:-3}"
if [ "$COUNT" -eq 0 ] 2>/dev/null; then
  info "0 profiles requested — nothing to do."
  exit 0
fi

# --- which Firefox to drive ----------------------------------------------------
if is_cmd firefox; then
  FF=(firefox); FF_EXEC="firefox"
elif is_flatpak_installed org.mozilla.firefox; then
  FF=(flatpak run org.mozilla.firefox); FF_EXEC="flatpak run org.mozilla.firefox"
else
  err "Firefox isn't installed — run the Browsers module first."
  record FAIL cfg "Firefox profiles" "Firefox not installed"
  exit 1
fi

pm_refresh
pkg "Zenity"  zenity     # password dialog
pkg "OpenSSL" openssl    # password hash check

APPS_DIR="$HOME/.local/share/applications"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$APPS_DIR" "$BIN_DIR"

_ff_ini() {
  local d
  for d in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox" \
           "$HOME/snap/firefox/common/.mozilla/firefox" \
           "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox" \
           "$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"; do
    [ -f "$d/profiles.ini" ] && { printf '%s\n' "$d/profiles.ini"; return 0; }
  done
  return 1
}
_ff_has_profile() { local ini; ini="$(_ff_ini)" || return 1; grep -qx "Name=$1" "$ini"; }

# Sets PROFILE_STATUS to OK (created now) or SKIP (already existed).
ensure_profile() {   # ensure_profile <profile-name> <label>
  if _ff_has_profile "$1"; then
    skipped "Profile '$1' ($2)" "already exists"
    PROFILE_STATUS=SKIP; return 0
  fi
  if spin_run "Creating profile '$1' ($2)" timeout 90 "${FF[@]}" --headless -CreateProfile "$1"; then
    PROFILE_STATUS=OK; return 0
  fi
  record FAIL cfg "Firefox profile: $2" "$SPIN_REASON"
  return 1
}

write_launcher() {   # write_launcher <file> <Name> <Comment> <Exec> <Icon> <WMClass> <Categories>
  local file="$APPS_DIR/$1"
  cat > "$file" << EOF
[Desktop Entry]
Name=$2
Comment=$3
Exec=$4
Icon=$5
Terminal=false
Type=Application
Categories=$7
StartupWMClass=$6
EOF
  chmod +x "$file"
}

CREATED_LAUNCHERS=()

# --- 1. Personal -------------------------------------------------------------------
if ensure_profile "default-release" "Firefox Personal"; then
  write_launcher firefox-default.desktop "Firefox Personal" "Firefox Personal Use" \
    "$FF_EXEC -P default-release --new-instance --name FirefoxDefault" firefox FirefoxDefault "Network;WebBrowser;"
  CREATED_LAUNCHERS+=(firefox-default.desktop); record "$PROFILE_STATUS" cfg "Firefox profile: Personal"
fi

# --- 2. Work -------------------------------------------------------------------------
if [ "$COUNT" -ge 2 ] && ensure_profile "Work" "Firefox Work"; then
  write_launcher firefox-work.desktop "Firefox Work" "Firefox Work Profile" \
    "$FF_EXEC -P Work --new-instance --name FirefoxWork" firefox-symbolic FirefoxWork "Network;WebBrowser;"
  CREATED_LAUNCHERS+=(firefox-work.desktop); record "$PROFILE_STATUS" cfg "Firefox profile: Work"
fi

# --- 3. Security Center ------------------------------------------------------------
if [ "$COUNT" -ge 3 ] && ensure_profile "Personal" "Security Center"; then
  SC_SCRIPT="$BIN_DIR/security-center"
  HASH=""
  [ -n "${LS_SC_HASH_FILE:-}" ] && [ -s "$LS_SC_HASH_FILE" ] && HASH="$(cat "$LS_SC_HASH_FILE")"

  if [ -z "$HASH" ] && [ -f "$SC_SCRIPT" ]; then
    skipped "Security Center password" "kept the existing password"
  elif [ -z "$HASH" ]; then
    warn "No password was set for Security Center — launcher not created."
    info "Run ./install.sh 04 to set one."
    record FAIL cfg "Security Center" "no password set"
  else
    # Written with a quoted heredoc, then the hash is substituted in. The hash
    # only contains [./0-9A-Za-z$], so single-quoting it is safe.
    cat > "$SC_SCRIPT" << 'EOF'
#!/bin/bash
# Security Center — asks for a password, then opens the protected Firefox profile.
# To change the password: openssl passwd -6, then replace PASSWORD_HASH below
# (or run ./install.sh 04 again).

PASSWORD_HASH='__HASH__'

PASSWORD=$(zenity --password --title="Require Administrative Access")
[ $? -ne 0 ] && exit 1

SALT=$(printf '%s' "$PASSWORD_HASH" | cut -d'$' -f3)
CHECK_HASH=$(printf '%s' "$PASSWORD" | openssl passwd -6 -salt "$SALT" -stdin)

if [ "$CHECK_HASH" != "$PASSWORD_HASH" ]; then
    zenity --error --title="Access Denied" --text="Incorrect password."
    exit 1
fi

exec __FF__ -P Personal --new-instance --name FirefoxPrivate
EOF
    sed -i "s|__HASH__|${HASH}|; s|__FF__|${FF_EXEC}|" "$SC_SCRIPT"
    chmod 700 "$SC_SCRIPT"
    ok "Security Center password set"
  fi

  if [ -f "$SC_SCRIPT" ]; then
    write_launcher security-center.desktop "Security Center" "Protected Browser" \
      "$SC_SCRIPT" security-high-symbolic FirefoxPrivate "Utility;"
    CREATED_LAUNCHERS+=(security-center.desktop); record "$PROFILE_STATUS" cfg "Firefox profile: Security Center"
  fi
fi

# --- 4+. Extra profiles ------------------------------------------------------------
n=4
while [ "$n" -le "$COUNT" ]; do
  if ensure_profile "Profile $n" "Firefox Profile $n"; then
    write_launcher "firefox-profile-$n.desktop" "Firefox Profile $n" "Firefox Profile $n" \
      "$FF_EXEC -P \"Profile $n\" --new-instance --name FirefoxProfile$n" firefox "FirefoxProfile$n" "Network;WebBrowser;"
    CREATED_LAUNCHERS+=("firefox-profile-$n.desktop"); record "$PROFILE_STATUS" cfg "Firefox profile: Profile $n"
  fi
  n=$((n + 1))
done

# --- Always ask which profile to use when plain "firefox" is started --------------
if INI="$(_ff_ini)"; then
  if grep -q '^StartWithLastProfile=' "$INI"; then
    sed -i 's/^StartWithLastProfile=.*/StartWithLastProfile=0/' "$INI"
  else
    sed -i '/^\[General\]/a StartWithLastProfile=0' "$INI"
  fi
fi

is_cmd update-desktop-database && update-desktop-database "$APPS_DIR" >/dev/null 2>&1
ok "Launchers ready: ${#CREATED_LAUNCHERS[@]}"

# --- Dock: replace the stock Firefox icon with the profile launchers (GNOME) -------
if [ "$DESKTOP_ENV" = "gnome" ] && is_cmd gsettings && is_cmd python3 && [ "${#CREATED_LAUNCHERS[@]}" -gt 0 ]; then
  CURRENT="$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || echo '[]')"
  NEW="$(python3 - "$CURRENT" "${CREATED_LAUNCHERS[@]}" << 'PY'
import ast, sys
current = sys.argv[1].replace("@as ", "")
try:
    favs = list(ast.literal_eval(current))
except Exception:
    favs = []
ours = sys.argv[2:]
stock = {"firefox.desktop", "org.mozilla.firefox.desktop", "firefox_firefox.desktop"}
pos = next((i for i, f in enumerate(favs) if f in stock), len(favs))
favs = [f for f in favs if f not in stock and f not in ours]
pos = min(pos, len(favs))
favs[pos:pos] = ours
print(str(favs))
PY
)"
  if [ -n "$NEW" ] && [ "$NEW" != "$CURRENT" ]; then
    gsettings set org.gnome.shell favorite-apps "$NEW" && ok "Profile launchers pinned to the dock"
  else
    skipped "Dock icons" "already pinned"
  fi
fi
