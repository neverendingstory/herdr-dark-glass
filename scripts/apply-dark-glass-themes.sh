#!/usr/bin/env bash
set -euo pipefail

# Select the Dark Glass themes in OpenCode and Claude Code.
#
# `setup-dark-glass` installs the theme files. This action only records the
# selection each CLI reads: OpenCode keeps its theme in `cli.json`, and Claude
# Code keeps it in `settings.json` as `custom:<slug>`. Every other setting in
# those files is preserved, each file is backed up before it is replaced, and a
# selection that is already correct is left untouched.

ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugin-state/linyu.social-glass}"
OPENCODE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
OPENCODE_CLI_CONFIG="$OPENCODE_DIR/cli.json"
OPENCODE_THEME="$OPENCODE_DIR/themes/herdr-dark-glass.json"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
CLAUDE_THEME="$CLAUDE_DIR/themes/herdr-dark-glass.json"
INSTALL="${INSTALL_BIN_PATH:-install}"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
TMP_MERGE=""

cleanup() {
  if [[ -n "$TMP_MERGE" && -f "$TMP_MERGE" ]]; then
    rm -f "$TMP_MERGE"
  fi
  return 0
}
trap cleanup EXIT

if ! command -v "$INSTALL" >/dev/null 2>&1; then
  printf 'Required Dark Glass command is unavailable: %s\n' "$INSTALL" >&2
  exit 1
fi

PYTHON="${PYTHON_BIN:-}"
if [[ -z "$PYTHON" ]]; then
  for candidate in python3.13 python3.12 python3.11 python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
      PYTHON="$(command -v "$candidate")"
      break
    fi
  done
fi

for destination in "$OPENCODE_CLI_CONFIG" "$CLAUDE_SETTINGS"; do
  if [[ -L "$destination" ]]; then
    printf 'Refusing unsafe theme selection destination: %s\n' "$destination" >&2
    exit 1
  fi
  if [[ -e "$destination" && ! -f "$destination" ]]; then
    printf 'Refusing unsafe theme selection destination: %s\n' "$destination" >&2
    exit 1
  fi
done

if [[ -z "$PYTHON" ]]; then
  printf '%s\n' 'Python 3 is required to record the theme selection.' >&2
  printf '%s\n' 'OpenCode: run /themes and select herdr-dark-glass, then press Ctrl+P and run Switch to dark mode.' >&2
  printf '%s\n' 'Claude Code: run /theme and select Herdr Dark Glass.' >&2
  exit 1
fi

# apply_selection <file> <kind> <label> <backup-slug>
apply_selection() {
  local destination="$1"
  local kind="$2"
  local label="$3"
  local slug="$4"
  local state

  TMP_MERGE="$(mktemp "${TMPDIR:-/tmp}/herdr-dark-glass-themes.XXXXXX")"
  if ! state="$("$PYTHON" - "$destination" "$kind" "$TMP_MERGE" <<'PY'
import json
import os
import sys

path, kind, output = sys.argv[1:4]

if os.path.exists(path):
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise SystemExit("the configuration file does not hold a JSON object")
else:
    data = {}

if kind == "opencode":
    theme = data.get("theme")
    if not isinstance(theme, dict):
        theme = {}
    changed = theme.get("name") != "herdr-dark-glass" or theme.get("mode") != "dark"
    theme["name"] = "herdr-dark-glass"
    theme["mode"] = "dark"
    data["theme"] = theme
elif kind == "claude":
    changed = data.get("theme") != "custom:herdr-dark-glass"
    data["theme"] = "custom:herdr-dark-glass"
else:
    raise SystemExit("unknown selection kind")

if not changed:
    print("unchanged")
    raise SystemExit(0)

with open(output, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, ensure_ascii=False)
    handle.write("\n")
print("changed")
PY
  )"; then
    printf 'Unable to merge the Dark Glass theme selection into %s\n' "$destination" >&2
    exit 1
  fi

  if [[ "$state" == 'unchanged' ]]; then
    printf '%s theme is already selected: %s\n' "$label" "$destination"
    rm -f "$TMP_MERGE"
    TMP_MERGE=""
    return 0
  fi

  if [[ -f "$destination" ]]; then
    if ! mkdir -p "$STATE_DIR/backups"; then
      printf '%s\n' 'Unable to create the plugin backup directory.' >&2
      exit 1
    fi
    BACKUP="$STATE_DIR/backups/$slug-theme-selection-$STAMP.json"
    if ! "$INSTALL" -m 600 "$destination" "$BACKUP"; then
      printf '%s\n' 'Unable to back up the existing theme selection.' >&2
      exit 1
    fi
    printf 'Existing %s theme selection backed up to %s\n' "$label" "$BACKUP"
  fi

  if ! "$INSTALL" -m 600 "$TMP_MERGE" "$TMP_MERGE.installed"; then
    printf '%s\n' 'Unable to stage the theme selection.' >&2
    exit 1
  fi
  mv "$TMP_MERGE.installed" "$destination"
  rm -f "$TMP_MERGE"
  TMP_MERGE=""
  printf '%s theme selected in %s\n' "$label" "$destination"
}

if [[ ! -f "$OPENCODE_THEME" ]]; then
  printf 'OpenCode theme file is missing; run setup-dark-glass first: %s\n' "$OPENCODE_THEME" >&2
fi

if [[ ! -f "$CLAUDE_THEME" ]]; then
  printf 'Claude Code theme file is missing; run setup-dark-glass first: %s\n' "$CLAUDE_THEME" >&2
fi

apply_selection "$OPENCODE_CLI_CONFIG" opencode OpenCode opencode
apply_selection "$CLAUDE_SETTINGS" claude 'Claude Code' claude-code

printf '%s\n' 'Restart the OpenCode and Claude Code sessions to pick up the new themes.'
