#!/usr/bin/env bash
# ==============================================================================
# 02-gpu-drivers.sh — detects whatever GPU(s) are actually in the machine and
# installs the right driver stack for each. Handles NVIDIA (any generation,
# including the RTX 50-series -open kernel module requirement), AMD/ATI
# (amdgpu — mostly upstream-kernel already, just needs mesa/vulkan userspace
# + firmware), Intel integrated graphics, and laptop hybrid setups (Intel/AMD
# iGPU + NVIDIA dGPU, i.e. Optimus). Safe to run on any of these without
# editing anything — detection is automatic via lspci.
# ==============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
detect_distro

section "GPU detection"

pkg_install pciutils pciutils   # ensures lspci exists

if ! is_cmd lspci; then
  err "lspci unavailable even after install attempt — cannot detect GPU. Skipping module."
  exit 1
fi

GPU_LINES="$(lspci -nnk | grep -iE 'VGA compatible controller|3D controller|Display controller')"

if [ -z "$GPU_LINES" ]; then
  warn "No GPU detected via lspci — skipping driver install."
  exit 0
fi

echo "$GPU_LINES"

HAS_NVIDIA=0
HAS_AMD=0
HAS_INTEL=0

echo "$GPU_LINES" | grep -qi 'nvidia'                          && HAS_NVIDIA=1
echo "$GPU_LINES" | grep -qiE 'amd|ati|advanced micro devices' && HAS_AMD=1
echo "$GPU_LINES" | grep -qi 'intel'                            && HAS_INTEL=1

GPU_COUNT=$((HAS_NVIDIA + HAS_AMD + HAS_INTEL))
if [ "$GPU_COUNT" -gt 1 ]; then
  log "Hybrid/multi-GPU system detected — will install drivers for each vendor found."
fi

# ------------------------------------------------------------------------------
# NVIDIA
# ------------------------------------------------------------------------------
install_nvidia() {
  section "NVIDIA driver"

  if is_cmd nvidia-smi && nvidia-smi >/dev/null 2>&1; then
    ok "NVIDIA driver already active — skipping install"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
    return
  fi

  # Pull the exact model so we know whether this is a Blackwell (RTX 50-series)
  # card, which REQUIRES the -open kernel module driver (>=570.153.02). Older
  # cards (GTX 900/1000/1600, RTX 20/30/40) work fine with the regular
  # (non-open) driver that ubuntu-drivers picks by default.
  NVIDIA_MODEL="$(echo "$GPU_LINES" | grep -i nvidia | head -n1)"
  log "Detected: $NVIDIA_MODEL"

  IS_BLACKWELL=0
  if echo "$NVIDIA_MODEL" | grep -qiE 'RTX 50[0-9]{2}'; then
    IS_BLACKWELL=1
  fi

  if [ "$PKG_FAMILY" = "debian" ]; then
    apt_update_once
    pkg_install ubuntu-drivers-common ubuntu-drivers-common

    if [ "$IS_BLACKWELL" -eq 1 ]; then
      warn "RTX 50-series (Blackwell) detected — this requires the -open kernel module"
      warn "driver variant (>=570.153.02); the legacy proprietary driver will fail to"
      warn "initialize the card (RmInitAdapter errors)."
      RECOMMENDED="$(ubuntu-drivers devices 2>/dev/null | grep -oP 'nvidia-driver-\S+-open' | sort -V | tail -n1)"
      if [ -n "${RECOMMENDED:-}" ]; then
        pkg_install "$RECOMMENDED" "$RECOMMENDED"
      else
        warn "Could not auto-resolve an -open package name. Install manually, e.g.:"
        warn "  sudo apt install nvidia-driver-575-open   (or newer)"
      fi
    else
      log "Pre-Blackwell NVIDIA card — using ubuntu-drivers' standard recommendation."
      sudo ubuntu-drivers autoinstall
    fi

    # Laptop hybrid graphics: give an easy switch between iGPU/dGPU
    if [ "$HAS_INTEL" -eq 1 ] || [ "$HAS_AMD" -eq 1 ]; then
      pkg_install nvidia-prime nvidia-prime
      log "Hybrid laptop detected — 'nvidia-prime' installed."
      log "Switch GPUs with: sudo prime-select nvidia|intel|on-demand"
    fi

  elif [ "$PKG_FAMILY" = "rpm" ]; then
    warn "RPM-based NVIDIA install depends on your distro (typically RPM Fusion)."
    warn "See: https://rpmfusion.org/Howto/NVIDIA"
    if [ "$IS_BLACKWELL" -eq 1 ]; then
      warn "Make sure to pick the -open kmod variant — required for RTX 50-series."
    fi
  fi

  warn "A REBOOT is required for the NVIDIA driver to load."
}

# ------------------------------------------------------------------------------
# AMD
# ------------------------------------------------------------------------------
install_amd() {
  section "AMD driver"

  # Modern AMD GPUs (GCN and newer) use the amdgpu kernel driver, which is
  # already upstream in the Linux kernel — there's no separate "install the
  # driver" step like NVIDIA. What actually needs installing is the
  # userspace stack: Mesa (OpenGL/Vulkan), firmware blobs, and video
  # acceleration (VA-API).
  if [ "$PKG_FAMILY" = "debian" ]; then
    apt_update_once
    pkg_install linux-firmware linux-firmware
    pkg_install mesa-vulkan-drivers mesa-vulkan-drivers
    pkg_install libgl1-mesa-dri mesa-dri-drivers
    pkg_install mesa-va-drivers mesa-va-drivers
    pkg_install vainfo libva-utils
  elif [ "$PKG_FAMILY" = "rpm" ]; then
    rpm_refresh_once
    pkg_install linux-firmware linux-firmware
    pkg_install mesa-vulkan-drivers mesa-vulkan-drivers
    pkg_install mesa-dri-drivers mesa-dri-drivers
    pkg_install libva-utils libva-utils
  fi

  # CoreCtrl is NOT on Flathub (confirmed — it was never published there and
  # the project entered maintenance mode in 2025). LACT (Linux GPU
  # Configuration And Monitoring Tool) is the actively maintained, actually
  # Flathub-published alternative — fan curves, power limits, overclocking —
  # and it also supports NVIDIA/Intel, not just AMD.
  flatpak_install io.github.ilya_zlobintsev.LACT

  ok "AMD driver stack ready (amdgpu is kernel-native — no reboot required, but"
  ok "recommended after a fresh firmware install)."
}

# ------------------------------------------------------------------------------
# Intel
# ------------------------------------------------------------------------------
install_intel() {
  section "Intel graphics driver"

  # Same situation as AMD: the i915/Xe kernel driver is already in the
  # kernel. We just need Mesa + VA-API userspace pieces for OpenGL/Vulkan
  # and hardware video decode/encode.
  if [ "$PKG_FAMILY" = "debian" ]; then
    apt_update_once
    pkg_install mesa-vulkan-drivers mesa-vulkan-drivers
    pkg_install intel-media-va-driver-non-free intel-media-driver
    pkg_install vainfo libva-utils
  elif [ "$PKG_FAMILY" = "rpm" ]; then
    rpm_refresh_once
    pkg_install mesa-vulkan-drivers mesa-vulkan-drivers
    pkg_install intel-media-driver intel-media-driver
    pkg_install libva-utils libva-utils
  fi

  ok "Intel graphics stack ready (i915/Xe is kernel-native — no reboot required)."
}

# ------------------------------------------------------------------------------
# Dispatch based on what was actually detected
# ------------------------------------------------------------------------------
[ "$HAS_NVIDIA" -eq 1 ] && install_nvidia
[ "$HAS_AMD" -eq 1 ]    && install_amd
[ "$HAS_INTEL" -eq 1 ]  && install_intel

if [ "$GPU_COUNT" -eq 0 ]; then
  warn "GPU vendor not recognized as NVIDIA/AMD/Intel (could be a VM virtual GPU) — nothing installed."
fi

ok "GPU driver module done"
