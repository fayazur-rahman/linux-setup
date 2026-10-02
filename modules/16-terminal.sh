#!/usr/bin/env bash
# Title:    Terminal
# Installs: Two-line bash prompt (red $ after a failed command), git branch, command timing, history and alias tweaks
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

[ "${CHANGED:-0}" = 1 ] && next_step "Open a new terminal (or run: source ~/.bashrc) to see the new prompt."
