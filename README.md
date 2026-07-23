# linux-setup — portable post-install toolkit

A decentralized, idempotent setup script for fresh Debian/Ubuntu (apt) or
Fedora/RHEL (dnf/yum) installs. Detects the package family automatically and
skips anything already installed, so it's safe to re-run.

## Structure

```
linux-setup/
├── install.sh              # master orchestrator — run this
├── lib/
│   └── common.sh            # shared helpers: distro detection, pkg_install,
│                             # flatpak_install, logging, module runner
├── modules/                 # one file per software group, all independent
│   ├── 00-system-update.sh
│   ├── 01-cli-essentials.sh
│   ├── 02-nvidia-drivers.sh
│   ├── 03-browsers.sh
│   ├── 04-download-managers.sh
│   ├── 05-media-players.sh
│   ├── 06-remote-access.sh
│   ├── 07-dev-tools.sh
│   ├── 08-office-suite.sh
│   ├── 09-obs-discord.sh
│   ├── 10-bangla-typing.sh
│   ├── 11-screenshot-tool.sh
│   ├── 12-monitor-brightness.sh
│   ├── 13-gnome-extensions.sh
│   ├── 14-whatsapp.sh
│   └── 15-spotify-spotx.sh
└── config/
    └── modules.conf          # which modules run, and in what order
```

## Usage

```bash
chmod +x install.sh
./install.sh                  # run everything in config/modules.conf
./install.sh 03 09            # run only modules starting with 03 and 09
./install.sh --list           # show the module list without running anything
```

Run as your normal user, **not** as root — it calls `sudo` internally only
where needed, and primes the sudo session once at the start so you're not
repeatedly prompted for a password mid-run.

## Editing what gets installed

- To permanently skip a module on future runs, comment it out (`#`) in
  `config/modules.conf`.
- To change *what* a module installs, edit that module file directly — each
  one is short, self-contained, and readable top to bottom.
- To add a new module: drop a new `NN-name.sh` file in `modules/`, source
  `lib/common.sh` at the top the same way the others do, add its filename to
  `config/modules.conf`.

## Notes / deliberate decisions baked into specific modules

- **02-gpu-drivers.sh** — GPU-agnostic: reads `lspci` to detect whatever is
  actually in the machine (NVIDIA, AMD, Intel, or a hybrid laptop with more
  than one) and only installs the matching stack(s). No editing needed
  per-machine — same script runs unchanged on the desktop, a laptop with
  integrated Intel graphics, an AMD box, or an old GTX card.
  - **NVIDIA**: checks the exact model string. RTX 50-series (Blackwell,
    e.g. the 5060 Ti) *requires* the `-open` kernel-module driver variant
    (≥570.153.02) — the legacy proprietary driver won't initialize the card
    — so the module specifically resolves and installs the `-open` package
    for those. Anything older (GTX 900/1000/1600, RTX 20/30/40) just gets
    `ubuntu-drivers autoinstall`'s normal recommendation. On a hybrid
    laptop (Intel/AMD iGPU + NVIDIA dGPU), it also installs `nvidia-prime`
    so you can switch GPUs with `sudo prime-select nvidia|intel|on-demand`.
  - **AMD**: the `amdgpu` kernel driver ships in-kernel already, so there's
    no separate driver to install — the module installs the Mesa/Vulkan/
    VA-API userspace stack plus `linux-firmware`, and CoreCtrl (closest
    Linux equivalent to AMD's Adrenalin overclock/fan panel).
  - **Intel integrated**: same story — `i915`/Xe is in-kernel, so the
    module just installs Mesa/Vulkan and `intel-media-driver` for hardware
    video decode/encode.
  - Only the NVIDIA path needs a reboot; AMD/Intel take effect immediately
    since there's no separate kernel module being swapped in.
- **04-download-managers.sh** — installs `yt-dlp` + `xdman` + Parabolic as
  the IDM-equivalent stack rather than one single tool, since no single tool
  covers both "segmented HTTP download manager" and "YouTube downloader"
  as well as IDM did.
- **05-media-players.sh** — PotPlayer has no Linux build; `mpv` + `SMPlayer`
  is the closest substitute. Caesium has no official Flathub package (only
  an AppImage from GitHub releases), so the module fetches that directly
  instead of guessing a flatpak ID.
- **10-bangla-typing.sh** — OpenBangla Keyboard is installed as the modern
  Avro-equivalent; falls back to `ibus-avro` if the PPA isn't available for
  your release.
- **11-screenshot-tool.sh** — installs Flameshot via Flatpak specifically
  (not apt) because the Flatpak build tracks Wayland-portal fixes faster.
  Also unbinds GNOME's default PrtScn shortcut so Flameshot's own binding
  actually fires, and documents the "Ubuntu on Xorg" login fallback if
  capture still misbehaves on your session.
- **12-monitor-brightness.sh** — `ddcutil` is the Monitorian equivalent for
  external monitors over DDC/CI; needs `i2c-dev` + group membership, both
  handled here, but requires a re-login to take effect.
- **13-gnome-extensions.sh** — installs Dash to Panel, Caffeine, Blur My
  Shell, GSConnect, AppIndicator Support, Clipboard Indicator, and Just
  Perfection via `gext` (gnome-extensions-cli). This module intentionally
  stops at *installing* them — per-extension configuration (your custom
  settings) is meant to become a follow-up module once you share the config.
- **15-spotify-spotx.sh** — explicitly avoids the Snap Spotify package,
  since SpotX-Bash refuses to patch it (confirmed by your own run log:
  `Error: Snap client not supported`). Installs from Spotify's official APT
  repo instead, then runs SpotX against that.

## Explicitly left out (per your instructions)

ESET, Revo Uninstaller, WinRAR (replaced by built-in Archive Manager +
unrar/p7zip), Epic Games launcher, Rockstar launcher, Steam, Git, Adobe
Acrobat.

## After running

1. Reboot if the NVIDIA driver module ran.
2. Log out/in if the monitor-brightness module ran (group membership).
3. Open GNOME Extension Manager to enable + configure the extensions
   (send over your customization list and it'll become
   `modules/16-gnome-extension-config.sh`).
4. Sign into Brave/Chrome, TeamViewer, Discord, Spotify, WhatsApp Web as
   usual — none of that is scriptable without your credentials.
