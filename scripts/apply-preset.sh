#!/usr/bin/env bash
set -euo pipefail

HERDR="${HERDR_BIN_PATH:-herdr}"
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugin-state/linyu.social-glass}"
CONFIG_DIR="${HERDR_PLUGIN_CONFIG_DIR:-$HOME/.config/herdr/plugins/config/linyu.social-glass}"
CONFIG_FILE="${HERDR_CONFIG_PATH:-$HOME/.config/herdr/config.toml}"
TITLE_FILE="$CONFIG_DIR/window-title.txt"

usage() {
  echo 'usage: apply-preset.sh <social-glass|island-glass|dark-glass>' >&2
  echo '       apply-preset.sh --render <social-glass|island-glass|dark-glass> <output>' >&2
  exit 2
}

resolve_preset() {
  case "$1" in
    social-glass)
      PRESET="$ROOT/theme/social-glass.toml"
      DISPLAY_NAME="Social Glass"
      EXPECTED_BASE_THEME="catppuccin-latte"
      ;;
    island-glass)
      PRESET="$ROOT/theme/island-glass.toml"
      DISPLAY_NAME="Island Glass"
      EXPECTED_BASE_THEME="catppuccin-latte"
      ;;
    dark-glass)
      PRESET="$ROOT/theme/dark-glass.toml"
      DISPLAY_NAME="Dark Glass"
      EXPECTED_BASE_THEME="catppuccin"
      ;;
    *) usage ;;
  esac
}

read_local_title() {
  LOCAL_TITLE=""
  if [[ ! -e "$TITLE_FILE" ]]; then
    return
  fi
  if [[ ! -f "$TITLE_FILE" ]] || ! LC_ALL=C awk '
    BEGIN { valid = 1 }
    NR > 1 || /[[:cntrl:]]/ || length($0) > 120 { valid = 0 }
    END { exit(valid && NR == 1 ? 0 : 1) }
  ' "$TITLE_FILE"; then
    echo "Invalid local window title in $TITLE_FILE: use one non-empty line of at most 120 bytes with no control characters." >&2
    exit 1
  fi
  IFS= read -r LOCAL_TITLE < "$TITLE_FILE" || [[ -n "$LOCAL_TITLE" ]]
  if [[ -z "$LOCAL_TITLE" ]]; then
    echo "Invalid local window title in $TITLE_FILE: the window title must not be empty." >&2
    exit 1
  fi
}

render_preset() {
  local output="$1"
  local output_tmp="$output.render.$$"
  local title_seen=0
  local escaped_title="$LOCAL_TITLE"
  escaped_title="${escaped_title//\\/\\\\}"
  escaped_title="${escaped_title//\"/\\\"}"

  [[ -s "$PRESET" ]] || { echo "$DISPLAY_NAME preset is missing: $PRESET" >&2; exit 1; }
  grep -Fq "name = \"$EXPECTED_BASE_THEME\"" "$PRESET" || { echo "$DISPLAY_NAME preset has an invalid base theme: $PRESET" >&2; exit 1; }

  : > "$output_tmp"
  chmod 600 "$output_tmp"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -n "$LOCAL_TITLE" && "$line" == 'window_title = '* ]]; then
      printf 'window_title = "%s"\n' "$escaped_title" >> "$output_tmp"
      title_seen=$((title_seen + 1))
    else
      printf '%s\n' "$line" >> "$output_tmp"
    fi
  done < "$PRESET"
  if [[ -n "$LOCAL_TITLE" && "$title_seen" -ne 1 ]]; then
    rm -f "$output_tmp"
    echo "$DISPLAY_NAME preset must contain exactly one window_title setting." >&2
    exit 1
  fi
  mv "$output_tmp" "$output"
}

if [[ "${1:-}" == "--render" ]]; then
  [[ "$#" -eq 3 ]] || usage
  resolve_preset "$2"
  read_local_title
  render_preset "$3"
  exit 0
fi

[[ "$#" -eq 1 ]] || usage
PRESET_ID="$1"
resolve_preset "$PRESET_ID"
read_local_title

mkdir -p "$STATE_DIR/backups" "$(dirname "$CONFIG_FILE")"
STAGE="$CONFIG_FILE.$PRESET_ID.$$"
trap 'rm -f "$STAGE"' EXIT
render_preset "$STAGE"
HERDR_CONFIG_PATH="$STAGE" "$HERDR" config check >/dev/null

STAMP="$(date +%Y%m%d-%H%M%S)-$$"
BACKUP_FILE=""
if [[ -f "$CONFIG_FILE" ]]; then
  BACKUP_FILE="$STATE_DIR/backups/config-$STAMP.toml"
  install -m 600 "$CONFIG_FILE" "$BACKUP_FILE"
  if [[ ! -f "$STATE_DIR/baseline-config.toml" ]]; then
    BASELINE_TMP="$STATE_DIR/baseline-config.toml.$$"
    install -m 600 "$CONFIG_FILE" "$BASELINE_TMP"
    if [[ ! -f "$STATE_DIR/baseline-config.toml" ]]; then
      mv "$BASELINE_TMP" "$STATE_DIR/baseline-config.toml"
    else
      rm -f "$BASELINE_TMP"
    fi
  fi
fi

mv "$STAGE" "$CONFIG_FILE"
if ! "$HERDR" server reload-config; then
  if [[ -n "$BACKUP_FILE" ]]; then
    ROLLBACK_TMP="$CONFIG_FILE.rollback.$$"
    install -m 600 "$BACKUP_FILE" "$ROLLBACK_TMP"
    mv "$ROLLBACK_TMP" "$CONFIG_FILE"
  else
    rm -f "$CONFIG_FILE"
  fi
  "$HERDR" server reload-config || true
  echo "$DISPLAY_NAME reload failed; previous config restored." >&2
  exit 1
fi

printf 'Herdr %s applied.\nConfig: %s\n' "$DISPLAY_NAME" "$CONFIG_FILE"
if [[ -n "$BACKUP_FILE" ]]; then
  printf 'Backup: %s\n' "$BACKUP_FILE"
else
  echo 'Backup: none (no previous config existed)'
fi
