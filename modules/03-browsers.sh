#!/usr/bin/env bash
# Title:    Browsers
# Installs: Firefox (set as default browser) · Google Chrome
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
module_init

# --- Firefox ------------------------------------------------------------------
if is_cmd firefox; then
  skipped "Firefox"; record SKIP app "Firefox"
else
  pm_refresh
  pkg "Firefox" firefox
fi

# Default browser = the system Firefox launcher (whichever name this distro uses).
FF_DESKTOP=""
for f in org.mozilla.firefox.desktop firefox.desktop firefox_firefox.desktop; do
  for dir in /usr/share/applications /var/lib/snapd/desktop/applications "$HOME/.local/share/applications"; do
    [ -f "$dir/$f" ] && { FF_DESKTOP="$f"; break 2; }
  done
done
if [ -n "$FF_DESKTOP" ] && is_cmd xdg-settings; then
  if [ "$(xdg-settings get default-web-browser 2>/dev/null)" = "$FF_DESKTOP" ]; then
    skipped "Firefox as default browser" "already the default"
  elif xdg-settings set default-web-browser "$FF_DESKTOP" 2>/dev/null; then
    for t in x-scheme-handler/http x-scheme-handler/https text/html; do
      xdg-mime default "$FF_DESKTOP" "$t" 2>/dev/null || true
    done
    ok "Firefox set as default browser"; record OK cfg "Default browser: Firefox"
  else
    warn "Couldn't set Firefox as default browser — set it in Settings › Default Apps."
  fi
fi

# --- Google Chrome ----------------------------------------------------------------
if is_cmd google-chrome || is_cmd google-chrome-stable; then
  skipped "Google Chrome"; record SKIP app "Google Chrome"
elif [ "$PKG_FAMILY" = "debian" ]; then
  url_package "Google Chrome" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
else
  url_package "Google Chrome" "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"
fi
