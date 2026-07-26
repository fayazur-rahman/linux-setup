#!/usr/bin/env bash
# ZapZap — Flatpak WhatsApp desktop wrapper: dedicated window, taskbar
# icon, native notifications. No official Linux WhatsApp client exists,
# ZapZap is the maintained community wrapper you've settled on, so it's
# installed unconditionally now (used to be a y/N prompt).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "WhatsApp (ZapZap)"

flatpak_install com.rtosta.zapzap
