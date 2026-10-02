#!/usr/bin/env bash
# Title:    Monitor brightness
# Installs: ddcutil + i2c access, so external monitors' brightness can be changed from the desktop
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init
pm_refresh

pkg "ddcutil" ddcutil

# Load the i2c-dev kernel module now and on every boot.
if [ -f /etc/modules-load.d/i2c-dev.conf ]; then
  skipped "i2c-dev kernel module" "already loaded at boot"
else
  sudo modprobe i2c-dev 2>/dev/null || true
  echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
  ok "i2c-dev kernel module enabled"; record OK cfg "i2c-dev loaded at boot"
fi

# Distros that use an i2c group (Debian/Ubuntu) need the user in it.
if getent group i2c >/dev/null; then
  if id -nG "$USER" | tr ' ' '\n' | grep -qx i2c; then
    skipped "i2c group membership" "already a member"
  else
    sudo usermod -aG i2c "$USER"
    ok "Added $USER to the i2c group"; record OK cfg "i2c group membership"
    next_step "Log out and back in so monitor-brightness control can reach the displays."
  fi
fi
