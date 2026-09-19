#!/usr/bin/env bash
set -euo pipefail

ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
OSASCRIPT="${OSASCRIPT_BIN_PATH:-osascript}"
PROFILE_NAME="${HERDR_DARK_GLASS_TERMINAL_PROFILE-Herdr Dark Glass}"
WINDOW_TITLE="${HERDR_DARK_GLASS_WINDOW_TITLE-Herdr Dark Glass}"

validate_single_line() {
  local label="$1"
  local value="$2"

  if [[ -z "$value" ]] || ! printf '%s\n' "$value" | LC_ALL=C awk '
    BEGIN { valid = 1 }
    NR > 1 || /[[:cntrl:]]/ || length($0) > 120 { valid = 0 }
    END { exit(valid && NR == 1 ? 0 : 1) }
  '; then
    printf '%s must be one non-empty line of at most 120 bytes with no control characters.\n' "$label" >&2
    exit 2
  fi
}

validate_single_line 'HERDR_DARK_GLASS_TERMINAL_PROFILE' "$PROFILE_NAME"
validate_single_line 'HERDR_DARK_GLASS_WINDOW_TITLE' "$WINDOW_TITLE"

if ! PROFILE_QUERY="$("$OSASCRIPT" - "$PROFILE_NAME" <<'APPLESCRIPT'
on run argv
  set profileName to item 1 of argv
  tell application "Terminal"
    set profileNames to name of every settings set
  end tell
  if profileNames contains profileName then
    return "present"
  end if
  return "missing"
end run
APPLESCRIPT
)"; then
  printf 'Unable to query Terminal profile %s. Check that Terminal is available and retry.\n' "$PROFILE_NAME" >&2
  exit 1
fi

case "$PROFILE_QUERY" in
  present)
    ;;
  missing)
    printf 'Terminal profile "%s" is missing. Run setup-dark-glass and complete the Terminal import first.\n' "$PROFILE_NAME" >&2
    exit 1
    ;;
  *)
    printf 'Unexpected Terminal profile query response for %s: %s\n' "$PROFILE_NAME" "$PROFILE_QUERY" >&2
    exit 1
    ;;
esac

export HERDR_SOCIAL_TERMINAL_PROFILE="$PROFILE_NAME"
export HERDR_SOCIAL_WINDOW_TITLE="$WINDOW_TITLE"
exec bash "$ROOT/scripts/open-social-window.sh"
