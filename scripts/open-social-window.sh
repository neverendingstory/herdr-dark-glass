#!/usr/bin/env bash
set -euo pipefail

PROFILE="${HERDR_SOCIAL_TERMINAL_PROFILE:-Clear Light}"
HERDR="${HERDR_BIN_PATH:-$(command -v herdr)}"
WINDOW_TITLE="${HERDR_SOCIAL_WINDOW_TITLE:-Herdr Social Glass}"

if [[ "$#" -ne 0 && "$#" -ne 2 ]]; then
  echo 'Internal launcher error: expected zero or two color arguments.' >&2
  exit 2
fi
if [[ "$#" -eq 2 ]]; then
  if [[ ! "$1" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
    echo "Invalid window foreground color: $1 (expected #RRGGBB)." >&2
    exit 1
  fi
  if [[ ! "$2" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
    echo "Invalid window background color: $2 (expected #RRGGBB)." >&2
    exit 1
  fi
fi

osascript - "$PROFILE" "$HERDR" "$WINDOW_TITLE" "$@" <<'APPLESCRIPT'
on run argv
  set profileName to item 1 of argv
  set herdrBin to item 2 of argv
  set windowTitle to item 3 of argv
  set colorCommand to ""
  if (count of argv) is 5 then
    set foregroundColor to item 4 of argv
    set backgroundColor to item 5 of argv
    set colorCommand to "printf '\\033]10;%s\\007\\033]11;%s\\007' " & quoted form of foregroundColor & " " & quoted form of backgroundColor & "; "
  end if
  tell application "Terminal"
    activate
    try
      set socialSettings to settings set profileName
    on error
      display dialog "Terminal profile ‘" & profileName & "’ was not found." buttons {"OK"} default button 1
      error number -128
    end try
    set previousDefaultSettings to default settings
    try
      set default settings to socialSettings
      set socialTab to do script ""
      set default settings to previousDefaultSettings
    on error errorMessage number errorNumber
      set default settings to previousDefaultSettings
      error errorMessage number errorNumber
    end try
    set profileReady to false
    repeat with attempt from 1 to 20
      try
        if (name of current settings of socialTab) is profileName then
          set profileReady to true
          exit repeat
        end if
      end try
      delay 0.05
    end repeat
    if profileReady is false then
      error "Terminal did not create the new tab with profile ‘" & profileName & "’."
    end if
    set launchCommand to colorCommand & "printf '\\033]0;%s\\007' " & quoted form of windowTitle & "; exec env -u HERDR_ENV -u HERDR_WORKSPACE_ID -u HERDR_TAB_ID -u HERDR_PANE_ID " & quoted form of herdrBin
    do script launchCommand in socialTab
    delay 0.6
    set bounds of front window to {150, 55, 1360, 910}
    return id of front window
  end tell
end run
APPLESCRIPT
