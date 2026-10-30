#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/test-env.sh"
TEST_PYTHON="$(find_python_with_tomllib)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dark-glass-themes.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local text="$1"
  local needle="$2"
  [[ "$text" == *"$needle"* ]] || fail "output does not contain: $needle"
}

backup_count() {
  if [[ -d "$HERDR_PLUGIN_STATE_DIR/backups" ]]; then
    find "$HERDR_PLUGIN_STATE_DIR/backups" -type f | wc -l | tr -d ' '
  else
    printf '0\n'
  fi
}

assert_json() {
  local path="$1"
  local expression="$2"
  "$TEST_PYTHON" - "$path" "$expression" <<'PY' || fail "unexpected JSON in $path"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)
if not eval(sys.argv[2], {"data": data}):
    raise SystemExit(1)
PY
}

export HOME="$TMP/home"
export HERDR_PLUGIN_ROOT="$ROOT"
export HERDR_PLUGIN_STATE_DIR="$TMP/state"
export XDG_CONFIG_HOME="$TMP/xdg-config"
export CLAUDE_CONFIG_DIR="$TMP/claude"
mkdir -p "$HOME" "$XDG_CONFIG_HOME/opencode" "$CLAUDE_CONFIG_DIR"

SCRIPT="$ROOT/scripts/apply-dark-glass-themes.sh"
OPENCODE_CLI_CONFIG="$XDG_CONFIG_HOME/opencode/cli.json"
CLAUDE_SETTINGS="$CLAUDE_CONFIG_DIR/settings.json"

# The theme files are missing, so the action warns but still records the
# selection the CLIs read.
missing_output="$(bash "$SCRIPT" 2>&1)"
assert_contains "$missing_output" 'run setup-dark-glass first'
assert_contains "$missing_output" 'OpenCode theme selected in'
assert_contains "$missing_output" 'Claude Code theme selected in'
assert_json "$OPENCODE_CLI_CONFIG" 'data["theme"]["name"] == "herdr-dark-glass"'
assert_json "$OPENCODE_CLI_CONFIG" 'data["theme"]["mode"] == "dark"'
assert_json "$CLAUDE_SETTINGS" 'data["theme"] == "custom:herdr-dark-glass"'
[[ "$(backup_count)" == '0' ]] || fail 'a first run produced a backup'

# A second run changes nothing and reports both selections as current.
current_output="$(bash "$SCRIPT" 2>&1)"
assert_contains "$current_output" 'OpenCode theme is already selected'
assert_contains "$current_output" 'Claude Code theme is already selected'
[[ "$(backup_count)" == '0' ]] || fail 'an unchanged selection produced a backup'

# Existing configuration keeps every unrelated setting.
cat > "$OPENCODE_CLI_CONFIG" <<'CONFIG'
{
  "$schema": "https://opencode.ai/v2/cli.json",
  "plugin": ["example"],
  "theme": {
    "name": "system"
  }
}
CONFIG
cat > "$CLAUDE_SETTINGS" <<'CONFIG'
{
  "env": {"FOO": "bar"},
  "includeCoAuthoredBy": true,
  "model": "sonnet",
  "theme": "auto"
}
CONFIG

existing_output="$(bash "$SCRIPT" 2>&1)"
assert_contains "$existing_output" 'Existing OpenCode theme selection backed up to'
assert_contains "$existing_output" 'Existing Claude Code theme selection backed up to'
assert_json "$OPENCODE_CLI_CONFIG" 'data["plugin"] == ["example"]'
assert_json "$OPENCODE_CLI_CONFIG" 'data["$schema"] == "https://opencode.ai/v2/cli.json"'
assert_json "$OPENCODE_CLI_CONFIG" 'data["theme"]["name"] == "herdr-dark-glass"'
assert_json "$OPENCODE_CLI_CONFIG" 'data["theme"]["mode"] == "dark"'
assert_json "$CLAUDE_SETTINGS" 'data["env"] == {"FOO": "bar"}'
assert_json "$CLAUDE_SETTINGS" 'data["includeCoAuthoredBy"] is True'
assert_json "$CLAUDE_SETTINGS" 'data["model"] == "sonnet"'
assert_json "$CLAUDE_SETTINGS" 'data["theme"] == "custom:herdr-dark-glass"'
[[ "$(backup_count)" == '2' ]] || fail 'the existing selections were not backed up'

# A symlinked destination is refused.
rm -f "$OPENCODE_CLI_CONFIG"
printf 'untouched\n' > "$TMP/real-cli-config.json"
ln -s "$TMP/real-cli-config.json" "$OPENCODE_CLI_CONFIG"
if bash "$SCRIPT" >/dev/null 2>&1; then
  fail 'a symlinked OpenCode configuration was accepted'
fi
[[ "$(cat "$TMP/real-cli-config.json")" == 'untouched' ]] || fail 'the symlink target was modified'
rm -f "$OPENCODE_CLI_CONFIG"

# A destination that is not a regular file is refused.
printf 'not a configuration\n' > "$CLAUDE_SETTINGS"
if bash "$SCRIPT" >/dev/null 2>&1; then
  fail 'a non-regular Claude Code configuration was accepted'
fi
[[ "$(cat "$CLAUDE_SETTINGS")" == 'not a configuration' ]] || fail 'the non-regular path was modified'

printf 'dark glass themes tests: ok\n'
