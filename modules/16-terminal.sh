#!/usr/bin/env bash
# Title:    Terminal
# Installs: Ctrl+Alt+T opens a terminal · two-line bash prompt (red $ after a failed command), git branch, command timing, history and alias tweaks
#
# Runs on its own with ./install.sh --terminal (no sudo, no packages, nothing
# else touched). Undo with ./install.sh --terminal-reset.
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

SRC="$ROOT_DIR/config/terminal.bash"
DEST_DIR="$HOME/.config/linux-setup"
DEST="$DEST_DIR/terminal.bash"
RC="$HOME/.bashrc"
BEGIN="# >>> linux-setup terminal >>>"
END="# <<< linux-setup terminal <<<"

if [ "${1:-}" = "--reset" ]; then
  if [ -f "$RC" ] && grep -qF "$BEGIN" "$RC"; then
    cp "$RC" "$RC.linux-setup.bak"
    sed -i "/^${BEGIN//\//\\/}\$/,/^${END//\//\\/}\$/d" "$RC"
    ok "Removed the terminal block from ~/.bashrc (backup: ~/.bashrc.linux-setup.bak)"
  else
    skipped "$HOME/.bashrc" "no terminal block to remove"
  fi
  rm -f "$DEST" && ok "Removed $DEST"
  if [ "$DESKTOP_ENV" = "gnome" ] && is_cmd gsettings && gnome_shortcut_remove terminal; then
    ok "Removed the Ctrl+Alt+T shortcut"
  fi
  info "Open a new terminal to get the default prompt back."
  exit 0
fi

[ -f "$SRC" ] || { err "Missing $SRC"; exit 1; }
mkdir -p "$DEST_DIR"

if [ -f "$DEST" ] && cmp -s "$SRC" "$DEST"; then
  skipped "Prompt and shell settings" "already up to date"
else
  cp "$SRC" "$DEST"
  ok "Prompt and shell settings → ~/.config/linux-setup/terminal.bash"
  record OK cfg "Terminal prompt"
  CHANGED=1
fi

touch "$RC"
if grep -qF "$BEGIN" "$RC"; then
  skipped ".bashrc hook" "already present"
else
  cp "$RC" "$RC.linux-setup.bak"
  [ -s "$RC" ] && [ -n "$(tail -c1 "$RC")" ] && echo >> "$RC"   # end with a newline first
  {
    printf '%s\n' "$BEGIN"
    printf '[ -f "$HOME/.config/linux-setup/terminal.bash" ] && . "$HOME/.config/linux-setup/terminal.bash"\n'
    printf '%s\n' "$END"
  } >> "$RC"
  ok "Hooked into ~/.bashrc (backup: ~/.bashrc.linux-setup.bak)"
  CHANGED=1
fi

# --- Ctrl+Alt+T opens a terminal -------------------------------------------------
# Ubuntu binds it already; Fedora doesn't. KDE Plasma binds it to Konsole by default.
if [ "$DESKTOP_ENV" = "gnome" ] && is_cmd gsettings; then
  if gsettings get org.gnome.settings-daemon.plugins.media-keys terminal 2>/dev/null | grep -q "<Primary><Alt>t"; then
    skipped "Ctrl+Alt+T opens a terminal" "already bound by the system"
  else
    TERM_CMD=""
    if is_cmd ptyxis; then TERM_CMD="ptyxis --new-window"        # Fedora 41+
    elif is_cmd gnome-terminal; then TERM_CMD="gnome-terminal"
    elif is_cmd kgx; then TERM_CMD="kgx"                          # GNOME Console
    elif is_cmd tilix; then TERM_CMD="tilix"
    fi
    if [ -z "$TERM_CMD" ]; then
      warn "No terminal app found for the Ctrl+Alt+T shortcut."
    else
      gnome_shortcut terminal "Terminal" "$TERM_CMD" "<Primary><Alt>t"
      case $? in
        0) ok "Ctrl+Alt+T opens a terminal (${TERM_CMD%% *})"; record OK cfg "Ctrl+Alt+T opens a terminal" ;;
        2) skipped "Ctrl+Alt+T opens a terminal" "already bound" ;;
        *) warn "Couldn't set the Ctrl+Alt+T shortcut" ;;
      esac
    fi
  fi
elif [ "$DESKTOP_ENV" = "kde" ]; then
  skipped "Ctrl+Alt+T opens a terminal" "Plasma binds it to Konsole by default"
fi

if [ "${CHANGED:-0}" = 1 ]; then next_step "Open a new terminal (or run: source ~/.bashrc) to see the new prompt."; fi
