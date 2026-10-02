#!/usr/bin/env bash
# Title:    GNOME extensions
# Installs: AppIndicator · ArcMenu (+ your saved settings) · Blur my Shell · Caffeine · Clipboard Indicator · ddcutil brightness · Dash to Dock · Just Perfection · Media Controls · Show Desktop Applet
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

if [ "$DESKTOP_ENV" != "gnome" ]; then
  info "Desktop is ${DESKTOP_ENV}, not GNOME — skipped."
  exit 0
fi

# uuid | display name   (installed and enabled in this order)
EXTENSIONS=(
  "appindicatorsupport@rgcjonas.gmail.com|AppIndicator and KStatusNotifierItem Support"
  "arcmenu@arcmenu.com|ArcMenu"
  "blur-my-shell@aunetx|Blur my Shell"
  "caffeine@patapon.info|Caffeine"
  "clipboard-indicator@tudmotu.com|Clipboard Indicator"
  "monitor-brightness-volume@ailin.nemui|Control monitor brightness and volume with ddcutil"
  "dash-to-dock@micxgx.gmail.com|Dash to Dock"
  "just-perfection-desktop@just-perfection|Just Perfection"
  "mediacontrols@cliffniff.github.com|Media Controls"
  "show-desktop-applet@valent-in|Show Desktop Applet"
)

# Extensions that fight with the ones above (two docks, two tray-icon providers).
CONFLICTS=(
  "dash-to-panel@jderose9.github.com"
  "ubuntu-dock@ubuntu.com"
  "ubuntu-appindicators@ubuntu.com"
)

# --- gext (installs from extensions.gnome.org for the running GNOME version) ------
export PATH="$HOME/.local/bin:$PATH"
if ! is_cmd gext; then
  pm_refresh
  pkg "pipx" pipx
  if spin_run -a "gnome-extensions-cli" pipx install gnome-extensions-cli --system-site-packages; then
    record OK app "gnome-extensions-cli"
  else
    record FAIL app "gnome-extensions-cli" "$SPIN_REASON"
  fi
fi
if ! is_cmd gext; then
  err "gnome-extensions-cli isn't available — install the extensions from Extension Manager instead."
  exit 1
fi
is_cmd dconf || pkg "dconf" dconf-cli dconf

# --- gsettings list helper ---------------------------------------------------------
# _gs_list <key> add|remove <uuid>   — edits org.gnome.shell string lists safely
_gs_list() {
  local key="$1" action="$2" uuid="$3" cur new
  cur="$(gsettings get org.gnome.shell "$key" 2>/dev/null || echo '[]')"
  new="$(python3 - "$cur" "$action" "$uuid" << 'PY'
import ast, sys
cur, action, uuid = sys.argv[1].replace("@as ", ""), sys.argv[2], sys.argv[3]
try: items = list(ast.literal_eval(cur))
except Exception: items = []
if action == "add" and uuid not in items: items.append(uuid)
if action == "remove": items = [i for i in items if i != uuid]
print(str(items))
PY
)"
  [ "$new" != "$cur" ] && gsettings set org.gnome.shell "$key" "$new"
}

_ext_present() {
  [ -d "$HOME/.local/share/gnome-shell/extensions/$1" ] || [ -d "/usr/share/gnome-shell/extensions/$1" ]
}
_ext_enabled() {
  gsettings get org.gnome.shell enabled-extensions 2>/dev/null | grep -q "'$1'"
}

gsettings set org.gnome.shell disable-user-extensions false 2>/dev/null || true

# --- install + enable ------------------------------------------------------------
for entry in "${EXTENSIONS[@]}"; do
  uuid="${entry%%|*}"; name="${entry#*|}"
  if _ext_present "$uuid"; then
    if _ext_enabled "$uuid"; then
      skipped "$name"
    else
      _gs_list enabled-extensions add "$uuid"; _gs_list disabled-extensions remove "$uuid"
      skipped "$name" "already installed — enabled it"
    fi
    record SKIP ext "$name"
    continue
  fi
  if spin_run -a "$name" gext --filesystem install "$uuid"; then
    _gs_list enabled-extensions add "$uuid"; _gs_list disabled-extensions remove "$uuid"
    record OK ext "$name"
    CHANGED=1
  else
    record FAIL ext "$name" "$SPIN_REASON"
  fi
done

for uuid in "${CONFLICTS[@]}"; do
  if _ext_enabled "$uuid"; then
    _gs_list enabled-extensions remove "$uuid"; _gs_list disabled-extensions add "$uuid"
    ok "Disabled $uuid (conflicts with Dash to Dock / AppIndicator)"
    record OK cfg "Disabled conflicting extension: $uuid"
    CHANGED=1
  fi
done

# --- ArcMenu settings ------------------------------------------------------------
# Applied only when ArcMenu has no saved settings yet (a fresh install), so a
# re-run never overwrites changes made later from ArcMenu's own settings.
ARC_FILE="$ROOT_DIR/config/arcmenu.dconf"
if [ -f "$ARC_FILE" ] && _ext_present "arcmenu@arcmenu.com"; then
  if [ -n "$(dconf dump /org/gnome/shell/extensions/arcmenu/ 2>/dev/null)" ]; then
    skipped "ArcMenu settings" "kept your current ArcMenu settings"
  elif dconf load /org/gnome/shell/extensions/arcmenu/ < "$ARC_FILE"; then
    ok "ArcMenu settings restored"; record OK cfg "ArcMenu settings restored"
  else
    err "ArcMenu settings — dconf load failed"; record FAIL cfg "ArcMenu settings" "dconf load failed"
  fi
fi

if [ "${CHANGED:-0}" = "1" ]; then
  next_step "Log out and back in so GNOME loads the new extensions (Wayland can't reload them live)."
fi
