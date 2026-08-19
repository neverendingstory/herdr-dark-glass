#!/usr/bin/env bash
set -euo pipefail

HERDR="${HERDR_BIN_PATH:-herdr}"
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugin-state/linyu.social-glass}"
CONFIG_FILE="${HERDR_CONFIG_PATH:-$HOME/.config/herdr/config.toml}"
PRESET="$ROOT/theme/social-glass.toml"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$STATE_DIR/backups" "$(dirname "$CONFIG_FILE")"
if [[ ! -s "$PRESET" ]] || ! grep -q 'name = "catppuccin-latte"' "$PRESET"; then
  echo "Social Glass preset is missing or invalid: $PRESET" >&2
  exit 1
fi

BACKUP_FILE=""
if [[ -f "$CONFIG_FILE" ]]; then
  BACKUP_FILE="$STATE_DIR/backups/config-$STAMP.toml"
  cp "$CONFIG_FILE" "$BACKUP_FILE"
  if [[ ! -f "$STATE_DIR/baseline-config.toml" ]]; then
    cp "$CONFIG_FILE" "$STATE_DIR/baseline-config.toml"
  fi
fi

TMP="$CONFIG_FILE.social-glass.$$"
install -m 600 "$PRESET" "$TMP"
mv "$TMP" "$CONFIG_FILE"

if ! "$HERDR" server reload-config; then
  if [[ -n "$BACKUP_FILE" ]]; then
    cp "$BACKUP_FILE" "$CONFIG_FILE"
  else
    rm -f "$CONFIG_FILE"
  fi
  "$HERDR" server reload-config || true
  echo "Social Glass reload failed; previous config restored." >&2
  exit 1
fi

printf 'Herdr Social Glass applied.\nConfig: %s\n' "$CONFIG_FILE"
if [[ -n "$BACKUP_FILE" ]]; then
  printf 'Backup: %s\n' "$BACKUP_FILE"
else
  echo 'Backup: none (no previous config existed)'
fi
