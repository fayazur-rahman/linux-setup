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
│   ├── 02-gpu-drivers.sh
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
│   ├── 15-spotify-spotx.sh
│   └── 16-startup-apps.sh
├── config/
│   └── modules.conf          # which modules run, and in what order
├── logs/                     # per-module logs, created on first run
└── INSTALLED-APPS.md         # full list of what gets installed and why
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

## Output — clean, per-item status with a live spinner

Section headers and a live spinner appear for every package/extension being
worked on; when it finishes you get a single ✓ or ✗ line — never the raw
apt/dnf/flatpak/curl output itself. That noisy detail is still captured, just
into `logs/<module-name>.log` instead of your screen:

```
==> 03-browsers
  ⠹ brave-browser
  ✓ brave-browser
  ✓ google-chrome-stable (already installed)

==> 07-dev-tools
  ✓ code
  ⠴ cloudflare-warp
  ✗ cloudflare-warp
      E: Unable to locate package cloudflare-warp
```

If something fails, the last real line of its actual output is shown right
under the ✗ — enough to tell what went wrong without opening a log file, but
without flooding the screen with the full apt transcript either. The full
transcript for every package attempted (success or failure) still lives in
that module's log file for whenever you want to dig further.

At the very end, `install.sh` prints one consolidated report covering the
whole run: which modules completed, every package newly installed vs.
already present vs. failed, every GNOME extension installed, and the
standing next-steps (log out/reboot for extensions, i2c group, NVIDIA driver
to take effect).

Two modules need to prompt you interactively (a WhatsApp-wrapper yes/no, and
SpotX's own setup wizard) — `14-whatsapp.sh` and `15-spotify-spotx.sh` run
fully attached to the terminal instead, since redirecting them would hide
the prompts you need to answer.

See `INSTALLED-APPS.md` for a full list of what each module installs and why.

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
  per-machine.
  - **NVIDIA**: RTX 50-series (Blackwell, e.g. the 5060 Ti) *requires* the
    `-open` kernel-module driver variant (≥570.153.02) — the legacy
    proprietary driver won't initialize the card — so the module resolves
    and installs the `-open` package specifically for those. Older cards
    just get `ubuntu-drivers autoinstall`'s normal recommendation. Hybrid
    laptops also get `nvidia-prime` for `sudo prime-select nvidia|intel|on-demand`.
  - **AMD**: `amdgpu` ships in-kernel already, so the module just installs
    the Mesa/Vulkan/VA-API userspace stack plus `linux-firmware`, and
    **LACT** (`io.github.ilya_zlobintsev.LACT`) for fan-curve/power-limit
    control. CoreCtrl was deliberately dropped — it was never actually
    published on Flathub (confirmed) and is now in maintenance mode with
    no further hardware support; LACT is the actively maintained,
    genuinely-on-Flathub alternative, and also covers NVIDIA/Intel.
  - **Intel integrated**: Mesa/Vulkan + `intel-media-driver` for hardware
    video decode/encode.
  - Only the NVIDIA path needs a reboot.
- **04-download-managers.sh** — `yt-dlp` + `xdman` + Parabolic as the
  IDM-equivalent stack. xdman is installed from the current `.deb` release
  asset directly (the old tar.xz+install.sh bundle this originally targeted
  is no longer how upstream ships it). Parabolic's flatpak ID is
  `org.nickvision.tubeconverter` — it kept its old project name
  ("Nickvision Tube Converter") in the reverse-DNS ID after rebranding.
- **05-media-players.sh** — PotPlayer has no Linux build; `mpv` + `SMPlayer`
  is the closest substitute. **Caesium was dropped** — checked directly with
  upstream and confirmed there is no official Flathub package and no Linux
  AppImage in their GitHub releases (there's an open issue asking for one).
  **Curtail** (`com.github.huluti.Curtail`) is installed instead — a real,
  Flathub-published PNG/JPEG/WebP/SVG compressor covering the same job.
- **07-dev-tools.sh** — Cloudflare WARP codename detection no longer trusts
  `lsb_release -cs` blindly (Ubuntu derivatives like Mint/Pop!_OS/Zorin
  often report their own codename, which doesn't exist on Cloudflare's
  server and silently produces a repo with no Release file). It now prefers
  `UBUNTU_CODENAME` from `/etc/os-release`, verifies the repo actually
  resolves before adding it, and falls back through a short list of known
  codenames if needed.
- **10-bangla-typing.sh** — `ppa:sarim/openbangla-keyboard` doesn't actually
  exist as a real PPA, so this now runs OpenBangla Keyboard's own official
  install script instead (`tools/install.sh` from their GitHub repo, which
  detects your distro itself). Falls back to `ibus-avro` if that fails.
- **11-screenshot-tool.sh** — installs Flameshot via Flatpak specifically
  (not apt) because the Flatpak build tracks Wayland-portal fixes faster.
  Also unbinds GNOME's default PrtScn shortcut so Flameshot's own binding
  actually fires, and documents the "Ubuntu on Xorg" login fallback if
  capture still misbehaves on your session.
- **12-monitor-brightness.sh** — `ddcutil` is the Monitorian equivalent for
  external monitors over DDC/CI; needs `i2c-dev` + group membership, both
  handled here, but requires a re-login to take effect.
- **06-remote-access.sh** — also installs **Remmina** (+ RDP plugin)
  alongside TeamViewer: TeamViewer is for controlling *this* desktop
  remotely, Remmina is for connecting *out* to other machines.
- **08-office-suite.sh** — also installs **Thunderbird** via Flatpak rather
  than `apt install thunderbird`, since on recent Ubuntu that apt package is
  a thin transitional wrapper around the Snap build; Flatpak keeps this
  toolkit snap-free and consistent with how the other desktop apps here are
  installed.
- **13-gnome-extensions.sh** — installs Dash to Panel, Caffeine, Blur My
  Shell, GSConnect, AppIndicator Support, Clipboard Indicator, Just
  Perfection, ArcMenu, Monitor Brightness & Volume (ddcutil), Show Desktop
  Applet, Spotify Controls + Track Info, and System Monitor via `gext`
  (gnome-extensions-cli). Two bugs fixed here: (1) `pipx install` puts
  `gext` in `~/.local/bin`, which often isn't on `PATH` within the same
  script run — the module now exports that path explicitly right after
  installing it, instead of the install silently succeeding and then the
  very next check reporting "gext unavailable". (2) `gext`'s default DBus
  backend pops up an interactive GNOME confirmation dialog per extension
  (the same one you'd see installing from a browser) — that would silently
  block a scripted run, so the module now uses `gext --filesystem`, which
  installs directly without that dialog. A logout/login afterward lets
  GNOME Shell fully pick the new extensions up. This module intentionally
  stops at *installing* them — per-extension configuration is meant to
  become a follow-up module once you share your settings.
- **16-startup-apps.sh** — creates `~/.config/autostart/*.desktop` entries
  (the same mechanism GNOME's own "Startup Applications" tool uses) for
  ZapZap, Discord, Flameshot, NVIDIA X Server Settings, qBittorrent,
  Remmina, and Spotify. Runs last in the module order deliberately, since
  it checks whether each app is actually installed before creating its
  entry. "SSH Key Agent" and "xapp-sn-watcher" need no action of their own
  — they're provided by the system already.
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
2. Log out/in if the monitor-brightness or gnome-extensions modules ran
   (group membership / Shell restart).
3. Open GNOME Extension Manager to enable + configure the extensions
   (send over your customization list and it'll become
   `modules/16-gnome-extension-config.sh`).
4. Sign into Brave/Chrome, TeamViewer, Discord, Spotify, WhatsApp Web as
   usual — none of that is scriptable without your credentials.
5. Check `logs/` for any module that failed — the terminal already showed
   you the last 25 lines, but the full log is there for anything deeper.
