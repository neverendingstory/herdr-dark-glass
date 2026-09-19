#!/usr/bin/env bash
set -euo pipefail

ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugin-state/linyu.social-glass}"
OPENCODE_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
OSASCRIPT="${OSASCRIPT_BIN_PATH:-osascript}"
OPEN="${OPEN_BIN_PATH:-open}"
INSTALL="${INSTALL_BIN_PATH:-install}"
PROFILE_NAME="${HERDR_DARK_GLASS_TERMINAL_PROFILE:-Herdr Dark Glass}"
PROFILE_FILE="$ROOT/profiles/Herdr Dark Glass.terminal"
SOURCE_THEME="$ROOT/integrations/opencode/herdr-dark-glass.json"
DEST_THEME="$OPENCODE_HOME/themes/herdr-dark-glass.json"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
TMP_THEME=""

cleanup() {
  if [[ -n "$TMP_THEME" && -f "$TMP_THEME" ]]; then
    rm -f "$TMP_THEME"
  fi
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf '%s\n' 'Dark Glass setup requires macOS Terminal.' >&2
  exit 1
fi

for source in "$PROFILE_FILE" "$SOURCE_THEME"; do
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

if ! mkdir -p "$OPENCODE_HOME/themes"; then
  printf '%s\n' 'Unable to create the OpenCode theme directory.' >&2
  exit 1
fi

if [[ -L "$DEST_THEME" ]] || [[ -e "$DEST_THEME" && ! -f "$DEST_THEME" ]]; then
  printf 'Refusing unsafe OpenCode theme destination: %s\n' "$DEST_THEME" >&2
  exit 1
fi

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
    printf 'Terminal profile is available: %s\n' "$PROFILE_NAME"
    ;;
  missing)
    if ! "$OPEN" "$PROFILE_FILE"; then
      printf 'Unable to open the Terminal profile for import: %s\n' "$PROFILE_FILE" >&2
      exit 1
    fi
    printf 'Opened %s for explicit Terminal import. Complete the import, then run status.\n' "$PROFILE_FILE"
    ;;
  *)
    printf 'Unexpected Terminal profile query response for %s: %s\n' "$PROFILE_NAME" "$PROFILE_QUERY" >&2
    exit 1
    ;;
esac

if [[ -f "$DEST_THEME" ]] && cmp -s "$SOURCE_THEME" "$DEST_THEME"; then
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

printf '%s\n' 'OpenCode: run /themes, select herdr-dark-glass, and lock dark mode.'
printf '%s\n' 'Claude Code: run /theme and select dark-ansi.'
printf '%s\n' 'Codex CLI: run codex normally; tui.theme controls syntax only.'
printf '%s\n' 'Grok Build: run /theme transparent, or use GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok.'
