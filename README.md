# linux-setup

One command to turn a fresh Fedora or Ubuntu/Debian install into a ready-to-use
desktop: apps, codecs, GNOME extensions, Firefox profiles, a better terminal
prompt and login-time apps. Every step checks first and skips anything that is
already in place, so it is safe to run again at any time.

## Supported systems

| | GNOME | KDE Plasma |
|---|---|---|
| **Fedora** (dnf) | Main target, fully supported | Supported; skips what Plasma already ships |
| **Ubuntu / Debian** (apt) | Supported | Supported |

The distro, package manager and desktop are detected automatically; no
editing is needed between machines.

## Quick start

```bash
git clone <this repository> linux-setup   # or unzip the download
cd linux-setup
chmod +x install.sh
./install.sh
```

Run it as your normal user, not with `sudo`. It asks for your password once
and keeps the session alive for the whole run.

## Commands

| Command | What it does |
|---|---|
| `./install.sh` | Runs every module in `config/modules.conf` |
| `./install.sh 05 15` | Runs only the listed modules (numbers or names, e.g. `./install.sh media spotify`) |
| `./install.sh --list` | Shows what each module installs. Installs nothing |
| `./install.sh --terminal` | Configures only the terminal prompt. No sudo, no packages, nothing else touched |
| `./install.sh --terminal-reset` | Removes the terminal configuration again |
| `./install.sh --help` | Shows the usage summary |

## Questions at the start

Anything the run needs to know is asked before the first install, so it never
stops halfway waiting for input:

- **Spotify account: free or premium.** SpotX applies different patches for
  each (`-p` for premium accounts).
- **How many Firefox profiles** (press Enter for the default of 3).

Questions only appear when the matching module is part of the run.

## What gets installed

| # | Module | Contents |
|---|---|---|
| 00 | Base system | System update; on Fedora: RPM Fusion, full ffmpeg and multimedia codecs; Flathub |
| 01 | Command-line tools | Vim, curl, wget, build tools, ffmpeg, GParted, unrar, 7-Zip, archive manager |
| 02 | Desktop tools | GNOME Tweaks and Extension Manager (GNOME only), Mission Center |
| 03 | Browsers | Firefox (set as the default browser), Google Chrome |
| 04 | Firefox profiles | Separate profiles (Personal, Work, …), each with its own launcher, pinned to the dock |
| 05 | Media | VLC, mpv, SMPlayer, HandBrake, GIMP, OBS Studio |
| 06 | Office & writing | LibreOffice Writer/Calc/Impress, Apostrophe, Mail Viewer |
| 07 | Internet | qBittorrent, FileZilla, Cloudflare WARP |
| 08 | Communication | Discord, ZapZap (WhatsApp) |
| 09 | Remote access | AnyDesk, Remmina |
| 10 | Development | Visual Studio Code |
| 11 | Bangla typing | OpenBangla Keyboard (Avro Phonetic layout) |
| 12 | Screenshots | Flameshot, bound to the Print Screen key |
| 13 | Monitor brightness | ddcutil and i2c access for external monitors |
| 14 | GNOME extensions | See below, plus your saved ArcMenu layout |
| 15 | Spotify | Spotify with SpotX ad-blocking patches |
| 16 | Terminal | Two-line prompt, see below |
| 17 | Startup apps | ZapZap, Discord, Flameshot, qBittorrent, Remmina and Spotify start at login (those that are installed) |

Apps come from the distribution's repositories, the vendor's own repository
(Chrome, VS Code, AnyDesk, Cloudflare WARP, Spotify on Ubuntu) or Flathub.
An app is never installed twice: a Flatpak is skipped when the same app is
already installed as a native package, and the other way round.

### GNOME extensions

AppIndicator and KStatusNotifierItem Support, ArcMenu, Blur my Shell, Caffeine,
Clipboard Indicator, Control monitor brightness and volume with ddcutil, Dash
to Dock, Just Perfection, Media Controls, Show Desktop Applet.

They are installed from extensions.gnome.org in the version that matches the
running GNOME Shell, and enabled. Extensions that clash with them (Dash to
Panel, Ubuntu Dock, Ubuntu AppIndicators) are switched off. GNOME on Wayland
only loads new extensions after you log out and back in.

**ArcMenu layout.** `config/arcmenu.dconf` holds an exported ArcMenu
configuration. It is applied when ArcMenu has no settings yet (a fresh
install); an existing ArcMenu setup is left alone. To save your current layout
into the repository:

```bash
dconf dump /org/gnome/shell/extensions/arcmenu/ > config/arcmenu.dconf
```

### Terminal prompt

```
fayazur@fedora ~/projects  main*
$ asdf
bash: asdf: command not found...
fayazur@fedora ~/projects  ✗ 127
$
```

- `user@host` and the current folder on the first line, the `$` on its own line
- `$` is green, and turns **red** after a command fails or isn't found, with
  the exit code shown on the line above (Ctrl+C doesn't count as a failure)
- The git branch when inside a repository, with `*` for uncommitted changes
- `took 12s` after any command that ran for 5 seconds or more
- The active Python virtualenv
- Larger, de-duplicated, timestamped history shared between open terminals
- Aliases: `ll`, `la`, `..`, `...`, plus `mkcd <dir>` (create and enter)

The settings live in `config/terminal.bash`, are copied to
`~/.config/linux-setup/terminal.bash` and loaded by a three-line block in
`~/.bashrc` (a backup is saved as `~/.bashrc.linux-setup.bak`). Edit
`config/terminal.bash` and run `./install.sh --terminal` to apply changes.

## Fedora and KDE notes

- **Fedora** gets RPM Fusion (free and nonfree), the full ffmpeg build and the
  multimedia codec group before anything else, since several apps depend on them.
- **Spotify** is the Flathub build on Fedora; SpotX is pointed at its install
  folder. A Flatpak update replaces the patched files, so run
  `./install.sh 15` again after Spotify updates.
- **Fedora KDE Plasma** skips Flameshot (Spectacle is built in), Remmina (KRDC is
  built in) and the GNOME extensions; LibreOffice is already present and is
  detected as such. OpenBangla Keyboard uses the Fcitx5 backend on KDE and iBus
  on GNOME.
- **Ubuntu** replaces the Snap build of Spotify with the apt one, because SpotX
  can't patch Snap packages.

## Output and logs

Each item shows a spinner with elapsed time while it runs, then a single line:

```
[ 5/18] Media
  ✓ VLC — already installed
  ✓ HandBrake — installed (34s)
  ✗ SMPlayer — failed to install
      │ No match for argument: smplayer
      → Package not found in the enabled repositories for this release.
      ↳ full output: logs/05-media.log
```

When something fails you get the lines from the output that explain it, a
plain-language guess at the cause (network, missing package, expired sudo,
signing key, package manager busy, disk full) and the log file with the full
output. Raw package-manager output never reaches the screen; every module
writes its complete output to `logs/<module>.log`.

The run ends with a summary: what was installed, what was already there, what
was configured, which extensions are active, what failed and why, and the next
steps for this run (for example logging out so new extensions load).

## Customising

- **Skip a module permanently:** put `#` in front of it in `config/modules.conf`.
- **Change what a module installs:** each file in `modules/` is short and reads
  top to bottom. The helpers it uses:
  - `pkg "Label" <deb-name> [rpm-name]` — native package; use `-` where it doesn't exist
  - `pkg_group "Label" <pkg> <pkg> …` — several packages under one name
  - `flatpak_app "Label" <flathub-id> [native-command …]` — Flathub app, skipped if the native command exists
  - `url_package "Label" <url>` — download and install a .deb/.rpm
- **Add a module:** create `modules/NN-name.sh` with this header and add it to
  `config/modules.conf`:

  ```bash
  #!/usr/bin/env bash
  # Title:    My tools
  # Installs: What it installs, shown by --list
  source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
  module_init

  pkg "tree" tree
  flatpak_app "Inkscape" org.inkscape.Inkscape inkscape
  ```

## After the run

1. Log out and back in. Needed for new GNOME extensions, the i2c group
   (monitor brightness) and the Bangla input method.
2. Add OpenBangla Keyboard as an input source:
   Settings › Keyboard › Input Sources › + › Bangla.
3. Connect Cloudflare WARP once: `warp-cli registration new && warp-cli connect`.
4. Sign in to Chrome, Firefox profiles, Discord, Spotify, ZapZap, AnyDesk and the rest.

The summary at the end of each run lists the steps that apply to that run.

## Project layout

```
linux-setup/
├── install.sh              entry point: options, questions, runs modules, summary
├── lib/common.sh           detection, installers, spinner, error hints, summary
├── modules/                one file per area, run in the order of modules.conf
├── config/
│   ├── modules.conf        module list and order
│   ├── arcmenu.dconf       saved ArcMenu layout
│   └── terminal.bash       prompt and shell settings
└── logs/                   created on each run, one log per module
```

## Troubleshooting

- **Something failed.** Read the hint under the ✗, fix the cause, run
  `./install.sh` again. Finished items are skipped, so only the failed parts run.
- **"Another package manager is running".** GNOME Software or automatic updates
  hold the package lock. Wait for them to finish, then re-run.
- **Extensions don't show up.** Log out and back in. Check with `gnome-extensions list --enabled`.
- **Prompt unchanged.** Open a new terminal, or run `source ~/.bashrc`.
- **Monitor brightness slider can't find the screen.** Log out and back in, then
  test with `ddcutil detect`. DDC/CI must be enabled in the monitor's own menu.
