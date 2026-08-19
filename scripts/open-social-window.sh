#!/usr/bin/env bash
set -euo pipefail

PROFILE="${HERDR_SOCIAL_TERMINAL_PROFILE:-Clear Light}"
HERDR="${HERDR_BIN_PATH:-$(command -v herdr)}"
osascript - "$PROFILE" "$HERDR" <<'APPLESCRIPT'
on run argv
  set profileName to item 1 of argv
  set herdrBin to item 2 of argv
  tell application "Terminal"
    activate
    try
      set socialSettings to settings set profileName
    on error
      display dialog "Terminal profile ‘" & profileName & "’ was not found." buttons {"OK"} default button 1
      error number -128
    end try
    set socialTab to do script ""
    set current settings of socialTab to socialSettings
    delay 0.6
    set launchCommand to "printf '\\033]0;Herdr Social Glass\\007'; exec env -u HERDR_ENV -u HERDR_WORKSPACE_ID -u HERDR_TAB_ID -u HERDR_PANE_ID " & quoted form of herdrBin
    do script launchCommand in socialTab
    delay 0.6
    set bounds of front window to {150, 55, 1360, 910}
    return id of front window
  end tell
end run
APPLESCRIPT
