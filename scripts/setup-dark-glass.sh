#!/usr/bin/env bash
set -euo pipefail

ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugin-state/linyu.social-glass}"
OPENCODE_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
OSASCRIPT="${OSASCRIPT_BIN_PATH:-osascript}"
OPEN="${OPEN_BIN_PATH:-open}"
INSTALL="${INSTALL_BIN_PATH:-install}"
CYCLE_PROFILE_NAMES=(
  'Herdr Dark Glass Glass'
  'Herdr Dark Glass Clear'
  'Herdr Dark Glass Read'
  'Herdr Dark Glass Focus'
)
CYCLE_PROFILE_FILES=(
  "$ROOT/profiles/Herdr Dark Glass Glass.terminal"
  "$ROOT/profiles/Herdr Dark Glass Clear.terminal"
  "$ROOT/profiles/Herdr Dark Glass Read.terminal"
  "$ROOT/profiles/Herdr Dark Glass Focus.terminal"
)
SOURCE_THEME="$ROOT/integrations/opencode/herdr-dark-glass.json"
THEME_DIRECTORY="$OPENCODE_HOME/themes"
DEST_THEME="$THEME_DIRECTORY/herdr-dark-glass.json"
THEME_DIRECTORY_PROBE="${THEME_DIRECTORY_PROBE_BIN_PATH:-}"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
TMP_THEME=""
THEME_PROBE_FILE=""

cleanup() {
  if [[ -n "$TMP_THEME" && -f "$TMP_THEME" ]]; then
    rm -f "$TMP_THEME"
  fi
  if [[ -n "$THEME_PROBE_FILE" && -f "$THEME_PROBE_FILE" ]]; then
    rm -f "$THEME_PROBE_FILE"
  fi
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s\n' 'Dark Glass setup requires macOS Terminal.' >&2
  exit 1
fi

for source in "${CYCLE_PROFILE_FILES[@]}" "$SOURCE_THEME"; do
  if [[ ! -f "$source" ]]; then
    printf 'Required Dark Glass file is missing: %s\n' "$source" >&2
    exit 1
  fi
done

for tool in "$OSASCRIPT" "$OPEN" "$INSTALL"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required Dark Glass setup command is unavailable: %s\n' "$tool" >&2
    exit 1
  fi
done

if [[ -L "$DEST_THEME" ]] || [[ -e "$DEST_THEME" && ! -f "$DEST_THEME" ]]; then
  printf 'Refusing unsafe OpenCode theme destination: %s\n' "$DEST_THEME" >&2
  exit 1
fi

THEME_IS_CURRENT=0
if [[ -f "$DEST_THEME" ]] && cmp -s "$SOURCE_THEME" "$DEST_THEME"; then
  THEME_IS_CURRENT=1
fi

if ! PROFILE_QUERY="$("$OSASCRIPT" - "${CYCLE_PROFILE_NAMES[@]}" <<'APPLESCRIPT'
on run argv
  tell application "Terminal"
    set profileNames to name of every settings set
  end tell
  set results to {}
  repeat with profileName in argv
    if profileNames contains (contents of profileName) then
      set end of results to "present"
    else
      set end of results to "missing"
    end if
  end repeat
  set text item delimiters to linefeed
  return results as text
end run
APPLESCRIPT
)"; then
  printf '%s\n' 'Unable to query Terminal cycle profiles. Check that Terminal is available and retry.' >&2
  exit 1
fi

IFS=$'\n' read -r -d '' -a PROFILE_RESULTS < <(printf '%s\0' "$PROFILE_QUERY")
if [[ "${#PROFILE_RESULTS[@]}" -ne "${#CYCLE_PROFILE_NAMES[@]}" ]]; then
  printf 'Unexpected Terminal cycle profile query response: %s\n' "$PROFILE_QUERY" >&2
  exit 1
fi

MISSING_PROFILE_FILES=()
for index in "${!CYCLE_PROFILE_NAMES[@]}"; do
  case "${PROFILE_RESULTS[$index]}" in
    present)
      ;;
    missing)
      MISSING_PROFILE_FILES+=("${CYCLE_PROFILE_FILES[$index]}")
      ;;
    *)
      printf 'Unexpected Terminal cycle profile query response for %s: %s\n' \
        "${CYCLE_PROFILE_NAMES[$index]}" "${PROFILE_RESULTS[$index]}" >&2
      exit 1
      ;;
  esac
done

if [[ "$THEME_IS_CURRENT" != 1 ]]; then
  # The profile query above is read-only. Validate and create the theme path before
  # requesting any visible Terminal imports so a bad OpenCode parent has no import
  # or theme-install side effects.
  if [[ ( -e "$OPENCODE_HOME" && ! -d "$OPENCODE_HOME" ) || \
    ( -e "$THEME_DIRECTORY" && ! -d "$THEME_DIRECTORY" ) ]]; then
    printf 'Refusing unsafe OpenCode theme directory: %s\n' "$THEME_DIRECTORY" >&2
    exit 1
  fi

  if ! mkdir -p "$THEME_DIRECTORY"; then
    printf '%s\n' 'Unable to create the OpenCode theme directory.' >&2
    exit 1
  fi

  if [[ -n "$THEME_DIRECTORY_PROBE" ]]; then
    if ! "$THEME_DIRECTORY_PROBE" "$THEME_DIRECTORY"; then
      printf '%s\n' 'Unable to prepare the OpenCode theme directory for installation.' >&2
      exit 1
    fi
  else
    if ! THEME_PROBE_FILE="$(mktemp "$THEME_DIRECTORY/.herdr-dark-glass-write-probe.XXXXXX")"; then
      printf '%s\n' 'Unable to prepare the OpenCode theme directory for installation.' >&2
      exit 1
    fi
    if ! rm -f "$THEME_PROBE_FILE"; then
      printf '%s\n' 'Unable to prepare the OpenCode theme directory for installation.' >&2
      exit 1
    fi
    THEME_PROBE_FILE=""
  fi
fi

if [[ "${#MISSING_PROFILE_FILES[@]}" -gt 0 ]]; then
  if ! "$OPEN" "${MISSING_PROFILE_FILES[@]}"; then
    printf '%s\n' 'Unable to open the missing Terminal profiles for import. Complete the visible Terminal imports, then run status.' >&2
    exit 1
  fi
  printf 'Opened %s missing Terminal cycle profile(s) for explicit import. Complete the imports, then run status.\n' "${#MISSING_PROFILE_FILES[@]}"
else
  printf '%s\n' 'Terminal cycle profiles are available: 4/4; Herdr Dark Glass Read is the default launch profile.'
fi

if [[ "$THEME_IS_CURRENT" == 1 ]]; then
  printf 'OpenCode theme is already current: %s\n' "$DEST_THEME"
else
  if [[ -f "$DEST_THEME" ]]; then
    if ! mkdir -p "$STATE_DIR/backups"; then
      printf '%s\n' 'Unable to create the plugin backup directory.' >&2
      exit 1
    fi
    BACKUP="$STATE_DIR/backups/opencode-theme-$STAMP.json"
    "$INSTALL" -m 600 "$DEST_THEME" "$BACKUP"
    printf 'Existing OpenCode theme backed up to %s\n' "$BACKUP"
  fi

  TMP_THEME="$DEST_THEME.tmp.$$"
  "$INSTALL" -m 600 "$SOURCE_THEME" "$TMP_THEME"
  mv "$TMP_THEME" "$DEST_THEME"
  TMP_THEME=""
  printf 'OpenCode theme installed at %s\n' "$DEST_THEME"
fi

printf '%s\n' 'OpenCode: run /themes and select herdr-dark-glass; then open Ctrl+P. Run Switch to dark mode if shown; when already dark, run Lock theme mode only if that action is shown.'
printf '%s\n' 'Claude Code: run /theme and select dark-ansi; the selection persists globally.'
printf '%s\n' 'Codex CLI: run codex normally; tui.theme controls syntax only.'
printf '%s\n' 'Grok Build 1.0.40 has NO custom herdr-dark-glass theme. Its terminal aliases (terminal, terminal-default, transparent, native) are rollout-gated; a bare /theme transparent fails until enabled. Use GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok. Persistent config: [features] terminal_theme = true and [ui] theme = "terminal".'
