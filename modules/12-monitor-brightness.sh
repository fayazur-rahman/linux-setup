#!/usr/bin/env bash
# ddcutil — controls external monitor brightness/contrast over DDC/CI via
# HDMI/DisplayPort, the same thing Monitorian did on Windows. Paired with the
# GNOME Shell extension "Brightness Control Using ddcutil" (installed as part
# of the extensions module) for an in-panel slider.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "Monitor brightness (Monitorian replacement)"

pkg_install ddcutil ddcutil

log "Enabling i2c-dev kernel module (required for ddcutil to see monitors) ..."
if ! lsmod | grep -q "^i2c_dev"; then
  sudo modprobe i2c-dev
fi
if ! grep -q "^i2c-dev" /etc/modules 2>/dev/null; then
  echo "i2c-dev" | sudo tee -a /etc/modules > /dev/null
fi

log "Adding current user to the 'i2c' group (avoids needing sudo for ddcutil) ..."
if ! getent group i2c >/dev/null; then
  sudo groupadd i2c
fi
sudo usermod -aG i2c "$USER"

warn "Group membership needs a re-login (or reboot) to take effect."
log "Test with: ddcutil detect   (after re-login)"
log "GUI slider: install the 'Brightness Control Using ddcutil' GNOME extension"
log "(handled in the gnome-extensions module) — search it in the Extension Manager."

ok "Monitor brightness setup done"
