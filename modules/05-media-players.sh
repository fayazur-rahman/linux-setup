#!/usr/bin/env bash
# VLC (required) + mpv/SMPlayer as the closest thing Linux has to PotPlayer
# (no native PotPlayer port exists) + Caesium Image Compressor (has native
# Linux builds, so no substitute needed).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "Media players"

pkg_install vlc vlc

# PotPlayer has no Linux build. mpv + SMPlayer (a GUI shell over mpv) is the
# nearest equivalent: fast hardware-accelerated playback, on-the-fly subtitle
# styling, speed control, similar keyboard-driven workflow.
pkg_install mpv mpv
pkg_install smplayer smplayer

# Caesium Image Compressor — checked directly with upstream: the project
# (Lymphatus/caesium-image-compressor) does NOT currently publish an
# official Linux build (no Flathub package, no AppImage in GitHub Releases —
# confirmed via their own open GitHub issue asking for one). There's nothing
# reliable to auto-install here, so we say so plainly rather than silently
# failing, and offer Curtail as a real, Flathub-published alternative that
# does the same PNG/JPEG/WebP compression job.
warn "Caesium Image Compressor has no official Linux build (confirmed via upstream"
warn "GitHub issue tracker — no Flathub package, no Linux AppImage as of this check)."
warn "Installing 'Curtail' instead — a Flathub-published lossless/lossy image"
warn "compressor covering the same PNG/JPEG/WebP/SVG use case."
flatpak_install com.github.huluti.Curtail

ok "Media players done"
