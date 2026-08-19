#!/usr/bin/env bash
set -euo pipefail

HERDR="${HERDR_BIN_PATH:-herdr}"
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONFIG_FILE="${HERDR_CONFIG_PATH:-$HOME/.config/herdr/config.toml}"

printf 'Herdr Social Glass\n\n'
printf 'Herdr:  %s\n' "$("$HERDR" --version)"
printf 'Config: %s\n' "$CONFIG_FILE"
printf 'Preset: %s\n' "$ROOT/theme/social-glass.toml"
printf 'Data:   %s\n' "${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugin-state/linyu.social-glass}"
if [[ -f "$CONFIG_FILE" ]] && cmp -s "$CONFIG_FILE" "$ROOT/theme/social-glass.toml"; then
  echo 'State:   applied'
else
  echo 'State:   not applied or locally modified'
fi
