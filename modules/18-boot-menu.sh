#!/usr/bin/env bash
# Title:    Boot menu (GRUB)
# Installs: 2-second boot menu · Windows detected for dual boot · Windows or Linux as the default (asked at the start)
#
# Edits /etc/default/grub, then rebuilds the GRUB menu:
#   GRUB_TIMEOUT=2
#   GRUB_DEFAULT="<the Windows entry's exact title>"   (only when Windows is chosen)
# The Windows title differs per machine (e.g. "Windows Boot Manager (on /dev/nvme0n1p1)"),
# so it is read from the generated menu rather than hard-coded.
# A backup of the original file is kept at /etc/default/grub.linux-setup.bak.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

CFG=/etc/default/grub
export PATH="$PATH:/usr/sbin:/sbin"   # GRUB tools live in sbin on some distros
WANT_WINDOWS="${GRUB_WINDOWS_DEFAULT:-n}"

if [ ! -f "$CFG" ]; then
  skipped "Boot menu" "GRUB isn't the boot loader on this system"
  exit 0
fi

# --- how this distro rebuilds the menu -------------------------------------------
if is_cmd grub2-mkconfig; then
  GRUB_OUT=/boot/grub2/grub.cfg                 # Fedora (also correct on UEFI)
  rebuild() { sudo grub2-mkconfig -o "$GRUB_OUT"; }
elif is_cmd update-grub; then
  GRUB_OUT=/boot/grub/grub.cfg                  # Ubuntu / Debian
  rebuild() { sudo update-grub; }
elif is_cmd grub-mkconfig; then
  GRUB_OUT=/boot/grub/grub.cfg
  rebuild() { sudo grub-mkconfig -o "$GRUB_OUT"; }
else
  err "No grub-mkconfig / update-grub found"; record FAIL cfg "Boot menu" "GRUB tools not found"; exit 1
fi

get()  { sudo sed -n "s/^$1=//p" "$CFG" | tail -n 1 | sed 's/^"\(.*\)"$/\1/'; }
put()  {   # put KEY VALUE — replace the line, or append it
  if sudo grep -q "^$1=" "$CFG"; then
    sudo sed -i "s|^$1=.*|$1=$2|" "$CFG"
  else
    echo "$1=$2" | sudo tee -a "$CFG" >/dev/null
  fi
}
windows_entry() { sudo grep -oP "^menuentry '\K[^']*Windows[^']*" "$GRUB_OUT" 2>/dev/null | head -n 1; }

[ -f "$CFG.linux-setup.bak" ] || sudo cp "$CFG" "$CFG.linux-setup.bak"
CHANGED=0

# --- 1. 2-second menu, always shown ----------------------------------------------
if [ "$(get GRUB_TIMEOUT)" = "2" ]; then
  skipped "Boot menu timeout" "already 2 seconds"
else
  put GRUB_TIMEOUT 2; CHANGED=1
  ok "Boot menu timeout → 2 seconds"; record OK cfg "GRUB timeout: 2 seconds"
fi
if [ "$IS_FEDORA" -eq 1 ] && is_cmd grub2-editenv; then
  # Fedora hides the menu unless the previous boot failed; show it every time.
  sudo grub2-editenv - unset menu_auto_hide 2>/dev/null || true
elif [ "$(get GRUB_TIMEOUT_STYLE)" != "menu" ] && sudo grep -q '^GRUB_TIMEOUT_STYLE=' "$CFG"; then
  put GRUB_TIMEOUT_STYLE menu; CHANGED=1
fi

# --- 2. Let GRUB find Windows (os-prober is off by default since GRUB 2.06) -------
if [ "$(get GRUB_DISABLE_OS_PROBER)" != "false" ]; then
  put GRUB_DISABLE_OS_PROBER false; CHANGED=1
fi
is_cmd os-prober || pkg "os-prober" os-prober

# --- 3. Rebuild once so the Windows entry (if any) appears in the menu -------------
if [ "$CHANGED" -eq 1 ] || [ -z "$(windows_entry)" ]; then
  spin_run "Rebuilding the boot menu" rebuild || { record FAIL cfg "Boot menu" "$SPIN_REASON"; exit 1; }
  CHANGED=0
fi
WIN_TITLE="$(windows_entry)"
if [ -n "$WIN_TITLE" ]; then
  ok "Windows found in the boot menu: $WIN_TITLE"
else
  info "No Windows installation was found on this machine."
fi

# --- 4. Default entry ------------------------------------------------------------
CURRENT_DEFAULT="$(get GRUB_DEFAULT)"
if [[ "$WANT_WINDOWS" == y* ]]; then
  if [ -z "$WIN_TITLE" ]; then
    warn "Windows was chosen as the default, but no Windows entry exists — Linux stays the default."
    record FAIL cfg "Windows as default boot entry" "no Windows installation found"
  elif [ "$CURRENT_DEFAULT" = "$WIN_TITLE" ]; then
    skipped "Default boot entry: Windows" "already the default"
  else
    put GRUB_DEFAULT "\"$WIN_TITLE\""; CHANGED=1
    ok "Default boot entry → Windows"; record OK cfg "Default boot entry: Windows"
  fi
else
  # Linux default. Undo a Windows default set by an earlier run.
  if [[ "$CURRENT_DEFAULT" == *Windows* ]]; then
    if [ "$IS_FEDORA" -eq 1 ]; then put GRUB_DEFAULT saved; else put GRUB_DEFAULT 0; fi
    CHANGED=1
    ok "Default boot entry → Linux"; record OK cfg "Default boot entry: Linux"
  else
    skipped "Default boot entry: Linux" "already the default"
  fi
fi

if [ "$CHANGED" -eq 1 ]; then
  spin_run "Rebuilding the boot menu" rebuild || { record FAIL cfg "Boot menu" "$SPIN_REASON"; exit 1; }
fi
