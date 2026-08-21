#!/usr/bin/env bash
set -euo pipefail

ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export HERDR_SOCIAL_TERMINAL_PROFILE="${HERDR_ISLAND_TERMINAL_PROFILE:-Clear Light}"
export HERDR_SOCIAL_WINDOW_TITLE="${HERDR_ISLAND_WINDOW_TITLE:-Herdr Island Glass}"
FOREGROUND="${HERDR_ISLAND_FOREGROUND:-#5B4636}"
BACKGROUND="${HERDR_ISLAND_BACKGROUND:-#F8F4E8}"

if [[ ! "$FOREGROUND" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
  echo "Invalid Island foreground color: $FOREGROUND (expected #RRGGBB)." >&2
  exit 1
fi
if [[ ! "$BACKGROUND" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
  echo "Invalid Island background color: $BACKGROUND (expected #RRGGBB)." >&2
  exit 1
fi

exec bash "$ROOT/scripts/open-social-window.sh" "$FOREGROUND" "$BACKGROUND"
