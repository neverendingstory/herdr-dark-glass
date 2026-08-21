#!/usr/bin/env bash
set -euo pipefail

HERDR="${HERDR_BIN_PATH:-herdr}"
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONFIG_FILE="${HERDR_CONFIG_PATH:-$HOME/.config/herdr/config.toml}"
CONFIG_DIR="${HERDR_PLUGIN_CONFIG_DIR:-$HOME/.config/herdr/plugins/config/linyu.social-glass}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/social-glass-status.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

bash "$ROOT/scripts/apply-preset.sh" --render social-glass "$TMP_DIR/social.toml"
bash "$ROOT/scripts/apply-preset.sh" --render island-glass "$TMP_DIR/island.toml"

same_settings() {
  local left="$1"
  local right="$2"
  [[ -f "$left" ]] && cmp -s \
    <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$left") \
    <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$right")
}

printf 'Herdr Social Glass 1.1\n\n'
printf 'Herdr:  %s\n' "$("$HERDR" --version)"
printf 'Config: %s\n' "$CONFIG_FILE"
printf 'Social: %s\n' "$ROOT/theme/social-glass.toml"
printf 'Island: %s\n' "$ROOT/theme/island-glass.toml"
printf 'Title:  %s\n' "$CONFIG_DIR/window-title.txt"
printf 'Data:   %s\n' "${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugin-state/linyu.social-glass}"
if same_settings "$CONFIG_FILE" "$TMP_DIR/social.toml"; then
  echo 'State:   social-glass'
elif same_settings "$CONFIG_FILE" "$TMP_DIR/island.toml"; then
  echo 'State:   island-glass'
else
  echo 'State:   not applied or locally modified'
fi
