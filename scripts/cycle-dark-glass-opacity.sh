#!/usr/bin/env bash
set -euo pipefail

OSASCRIPT="${OSASCRIPT_BIN_PATH:-osascript}"
UNAME="${UNAME_BIN_PATH:-uname}"
PROFILE_NAMES=(
  'Herdr Dark Glass Glass'
  'Herdr Dark Glass Clear'
  'Herdr Dark Glass Read'
  'Herdr Dark Glass Focus'
)

if ! PLATFORM="$("$UNAME" -s 2>/dev/null)" || [[ "$PLATFORM" != "Darwin" ]]; then
  printf '%s\n' 'Dark Glass opacity cycling requires macOS Terminal.' >&2
  exit 1
fi

if ! command -v "$OSASCRIPT" >/dev/null 2>&1; then
  printf 'Dark Glass opacity cycling requires osascript: %s\n' "$OSASCRIPT" >&2
  exit 1
fi

if ! NEXT_PROFILE="$("$OSASCRIPT" - "${PROFILE_NAMES[@]}" <<'APPLESCRIPT'
on run argv
  if (count of argv) is not 4 then error "Dark Glass opacity cycling received invalid profile arguments."
  set glassName to item 1 of argv
  set clearName to item 2 of argv
  set readName to item 3 of argv
  set focusName to item 4 of argv
  set requiredNames to {glassName, clearName, readName, focusName}
  tell application "Terminal"
    set profileNames to name of every settings set
    repeat with requiredName in requiredNames
      if profileNames does not contain (contents of requiredName) then
        error "Dark Glass profile is missing: " & (contents of requiredName)
      end if
    end repeat
    if not (exists front window) then error "No Terminal front window is available."
    set targetTab to selected tab of front window
    set currentName to name of current settings of targetTab
    if currentName is glassName then
      set nextName to clearName
    else if currentName is clearName then
      set nextName to readName
    else if currentName is readName then
      set nextName to focusName
    else if currentName is focusName then
      set nextName to glassName
    else if currentName is "Herdr Dark Glass" then
      set nextName to clearName
    else
      set nextName to readName
    end if
    set current settings of targetTab to settings set nextName
    if (name of current settings of targetTab) is not nextName then
      error "Terminal did not apply the requested Dark Glass profile."
    end if
    return nextName
  end tell
end run
APPLESCRIPT
)"; then
  printf '%s\n' 'Unable to cycle Dark Glass opacity. Verify all four cycle profiles are imported and a Terminal window is frontmost.' >&2
  exit 1
fi

case "$NEXT_PROFILE" in
  'Herdr Dark Glass Glass')
    printf '%s\n' 'Dark Glass opacity: Glass (46%)'
    ;;
  'Herdr Dark Glass Clear')
    printf '%s\n' 'Dark Glass opacity: Clear (60%)'
    ;;
  'Herdr Dark Glass Read')
    printf '%s\n' 'Dark Glass opacity: Read (74%)'
    ;;
  'Herdr Dark Glass Focus')
    printf '%s\n' 'Dark Glass opacity: Focus (88%)'
    ;;
  *)
    printf 'Unexpected Dark Glass opacity response: %s\n' "$NEXT_PROFILE" >&2
    exit 1
    ;;
esac
