#!/usr/bin/env bash
set -euo pipefail

HERDR="${HERDR_BIN_PATH:-herdr}"
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONFIG_FILE="${HERDR_CONFIG_PATH:-$HOME/.config/herdr/config.toml}"
CONFIG_DIR="${HERDR_PLUGIN_CONFIG_DIR:-$HOME/.config/herdr/plugins/config/linyu.social-glass}"
STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugin-state/linyu.social-glass}"
OPENCODE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
OPENCODE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/opencode"
OSASCRIPT="${OSASCRIPT_BIN_PATH:-osascript}"
PROFILE_NAME="${HERDR_DARK_GLASS_TERMINAL_PROFILE:-Herdr Dark Glass}"
SOURCE_OPENCODE_THEME="$ROOT/integrations/opencode/herdr-dark-glass.json"
INSTALLED_OPENCODE_THEME="$OPENCODE_DIR/themes/herdr-dark-glass.json"
OPENCODE_STATE_FILE="$OPENCODE_STATE_DIR/kv.json"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/social-glass-status.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

bash "$ROOT/scripts/apply-preset.sh" --render social-glass "$TMP_DIR/social.toml"
bash "$ROOT/scripts/apply-preset.sh" --render island-glass "$TMP_DIR/island.toml"
bash "$ROOT/scripts/apply-preset.sh" --render dark-glass "$TMP_DIR/dark.toml"

same_settings() {
  local left="$1"
  local right="$2"
  [[ -f "$left" ]] && cmp -s \
    <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$left") \
    <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$right")
}

terminal_profile_status() {
  local response

  if response="$("$OSASCRIPT" - "$PROFILE_NAME" 2>/dev/null <<'APPLESCRIPT'
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
    case "$response" in
      present|missing)
        printf '%s' "$response"
        ;;
      *)
        printf '%s' 'unavailable'
        ;;
    esac
  else
    printf '%s' 'unavailable'
  fi
}

opencode_selection_status() {
  if [[ -f "$OPENCODE_STATE_FILE" ]] && command -v python3 >/dev/null 2>&1; then
    if python3 - "$OPENCODE_STATE_FILE" <<'PY' 2>/dev/null
import json
import sys

UNKNOWN = "verify in OpenCode with /themes"

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        state = json.load(handle)
except (OSError, ValueError, UnicodeError):
    print(UNKNOWN)
    raise SystemExit(0)

value = state.get("theme") if isinstance(state, dict) else None
if value == "herdr-dark-glass":
    print("herdr-dark-glass")
elif isinstance(value, str) and value and all(" " <= character <= "~" for character in value):
    print(f"{value} (not herdr-dark-glass)")
else:
    print(UNKNOWN)
PY
    then
      return 0
    fi
  fi

  printf '%s\n' 'verify in OpenCode with /themes'
}

printf 'Herdr Social Glass 1.2\n\n'
printf 'Herdr:  %s\n' "$("$HERDR" --version)"
printf 'Config: %s\n' "$CONFIG_FILE"
printf 'Social: %s\n' "$ROOT/theme/social-glass.toml"
printf 'Island: %s\n' "$ROOT/theme/island-glass.toml"
printf 'Dark:   %s\n' "$ROOT/theme/dark-glass.toml"
printf 'Title:  %s\n' "$CONFIG_DIR/window-title.txt"
printf 'Data:   %s\n' "$STATE_DIR"
if same_settings "$CONFIG_FILE" "$TMP_DIR/social.toml"; then
  echo 'State:   social-glass'
elif same_settings "$CONFIG_FILE" "$TMP_DIR/island.toml"; then
  echo 'State:   island-glass'
elif same_settings "$CONFIG_FILE" "$TMP_DIR/dark.toml"; then
  echo 'State:   dark-glass'
else
  echo 'State:   not applied or locally modified'
fi

case "$(terminal_profile_status)" in
  present)
    printf 'Terminal profile: installed\n'
    ;;
  missing)
    printf 'Terminal profile: missing\n'
    ;;
  *)
    printf 'Terminal profile: check unavailable\n'
    ;;
esac

if [[ ! -f "$INSTALLED_OPENCODE_THEME" ]]; then
  printf 'OpenCode theme: missing\n'
elif cmp -s "$SOURCE_OPENCODE_THEME" "$INSTALLED_OPENCODE_THEME"; then
  printf 'OpenCode theme: installed and current\n'
else
  printf 'OpenCode theme: installed but locally modified\n'
fi
printf 'OpenCode saved preference: %s\n' "$(opencode_selection_status)"
printf '%s\n' 'OpenCode active theme: verify in OpenCode with /themes'

printf '\nCLI compatibility:\n'
bash "$ROOT/scripts/cli-compat-status.sh"
