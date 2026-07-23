# What this script installs, and why

A plain-language reference for everything `install.sh` puts on your machine.
Grouped by module, in run order.

## 00 — System update
Runs `apt-get update && apt-get upgrade` (or the dnf/yum equivalent) plus a
handful of prerequisite packages (`ca-certificates`, `gnupg`,
`software-properties-common`) that later modules need in order to add
third-party repos. Nothing user-facing here — just groundwork.

## 01 — CLI essentials
| Package | Why |
|---|---|
| vim | text editor |
| curl, wget | download tools, used throughout the rest of the script itself |
| build-essential (or "Development Tools" group on RPM) | compilers/headers needed to build things from source occasionally |
| ffmpeg | audio/video conversion — also a dependency for a lot of media tooling |
| gparted | partition editor, your Windows equivalent for disk management |
| htop, btop | process/resource monitors (terminal task manager) |
| fastfetch | system-info splash — replaces neofetch, which is unmaintained upstream |
| gnome-tweaks | exposes GNOME settings not in the normal Settings app |
| synaptic | GUI package manager/browser, for when you want to browse apt visually |
| gnome-shell-extension-manager | GUI for installing/enabling GNOME extensions |
| unrar, p7zip-full, file-roller | archive support — replaces WinRAR entirely; Nautilus's Archive Manager can then open .rar/.7z/.zip natively |
| timeshift | system snapshot/restore tool — your Windows "System Restore" equivalent |

## 02 — GPU drivers (auto-detected)
Detects your actual GPU vendor(s) via `lspci` and only installs the matching
stack — same script, no editing, on NVIDIA/AMD/Intel/hybrid machines:
- **NVIDIA**: driver install (the `-open` variant specifically for RTX
  50-series cards); `nvidia-prime` too if it's a hybrid laptop.
- **AMD**: `amdgpu` is already in the kernel, so this just installs the
  Mesa/Vulkan/VA-API userspace pieces + firmware, plus **LACT** (GPU fan
  curve/power-limit control — the maintained alternative to CoreCtrl, which
  was never actually published on Flathub and is now unmaintained).
- **Intel**: same idea — Mesa/Vulkan + `intel-media-driver` for hardware
  video decode on integrated graphics.

## 03 — Browsers
| App | Why |
|---|---|
| Brave | your primary browser |
| Google Chrome | secondary browser |

## 04 — Download managers
| App | Why |
|---|---|
| qBittorrent | torrent client |
| yt-dlp | command-line YouTube/video downloader (actively maintained, what most GUI downloaders wrap internally) |
| xdman (Xtreme Download Manager) | closest thing to IDM on Linux — segmented/resumable HTTP downloads, browser integration |
| Parabolic (flatpak: `org.nickvision.tubeconverter`) | GUI front-end for yt-dlp, for when you don't want the CLI |

## 05 — Media players
| App | Why |
|---|---|
| VLC | general playback |
| mpv + SMPlayer | closest available substitute for PotPlayer, which has no Linux build — mpv is the fast hardware-accelerated engine, SMPlayer is a GUI shell over it |
| Curtail (flatpak: `com.github.huluti.Curtail`) | image compressor — substituted for Caesium, which has no official Linux build at all (confirmed via their own GitHub issue tracker) |

## 06 — Remote access
| App | Why |
|---|---|
| TeamViewer | control this desktop from your phone when you're away from it |

## 07 — Dev tools
| App | Why |
|---|---|
| VS Code | your editor |
| Cloudflare WARP | required, per your list |

Git is deliberately **not** installed here — you said it's not required.

## 08 — Office suite
| App | Why |
|---|---|
| LibreOffice | general office suite |
| OnlyOffice Desktop Editors | added on top of LibreOffice — noticeably closer to real MS Office's docx/xlsx/pptx rendering fidelity, useful for client-facing documents |

## 09 — OBS + Discord
Both installed as requested — OBS for recording/streaming, Discord for chat.

## 10 — Bangla typing
**OpenBangla Keyboard** — the actively maintained, modern equivalent of Avro
Keyboard on Linux (same phonetic layout, proper system input-method
integration). Falls back to `ibus-avro` only if the official installer fails
on your specific distro/release.

## 11 — Screenshot tool
**Flameshot**, installed via Flatpak specifically (not apt) because the
Flatpak build tracks Wayland screenshot-portal fixes faster than most distro
packages. The module also unbinds GNOME's own PrtScn shortcut so Flameshot's
binding actually fires, and documents the "log in via Xorg" fallback if
capture still misbehaves on your session.

## 12 — Monitor brightness
**ddcutil** — controls external monitor brightness/contrast over
DisplayPort/HDMI DDC/CI, the same mechanism Monitorian used on Windows.
Needs the `i2c-dev` kernel module and group membership, both set up here
(a re-login is needed for the group change to take effect). Pairs with a
GNOME extension for an in-panel slider (see module 13).

## 13 — GNOME extensions
Installs, via `gext` (gnome-extensions-cli): Dash to Panel, Caffeine, Blur My
Shell, GSConnect, AppIndicator Support, Clipboard Indicator, Just Perfection —
the ones you asked for. Uses `gext`'s filesystem backend so the install
doesn't block on an interactive GNOME popup per extension. A logout/login is
recommended afterward for GNOME Shell to fully pick them up.

## 14 — WhatsApp (optional, asks first)
No native Linux WhatsApp client exists — it's the same web app in every
browser, so there's nothing to meaningfully install. This module just asks
whether you want a dedicated wrapper window (ZapZap) instead of a browser
tab; skip it and use web.whatsapp.com if a tab is fine.

## 15 — Spotify + SpotX
Installs Spotify from the **official apt repo** (not Snap — SpotX explicitly
refuses to patch the Snap build, which is exactly the error you hit on your
first run), then runs the SpotX-Bash adblock/experimental-features patcher
against it.

---

## Deliberately left out (per your instructions)
ESET, Revo Uninstaller, WinRAR (replaced by built-in Archive Manager +
unrar/p7zip), Epic Games launcher, Rockstar launcher, Steam, Git, Adobe
Acrobat.
