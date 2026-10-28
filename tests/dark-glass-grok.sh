#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/test-env.sh"
TEST_PYTHON="$(find_python_with_tomllib)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dark-glass-grok.XXXXXX")"
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

assert_valid_toml() {
  "$TEST_PYTHON" - "$1" <<'PY' || fail "not valid TOML: $1"
import pathlib
import sys
import tomllib

with open(sys.argv[1], "rb") as handle:
    tomllib.load(handle)
PY
}

assert_setting() {
  local path="$1"
  local table="$2"
  local key="$3"
  local expected="$4"
  "$TEST_PYTHON" - "$path" "$table" "$key" "$expected" <<'PY' || fail "$table.$key is not $expected"
import sys
import tomllib

path, table, key, expected = sys.argv[1:5]
with open(path, "rb") as handle:
    parsed = tomllib.load(handle)
value = parsed.get(table, {}).get(key)
expected_value = tomllib.loads(f"value = {expected}")["value"]
if value != expected_value:
    print(f"{table}.{key} = {value!r}, expected {expected_value!r}", file=sys.stderr)
    raise SystemExit(1)
PY
}

backup_count() {
  if [[ -d "$HERDR_PLUGIN_STATE_DIR/backups" ]]; then
    find "$HERDR_PLUGIN_STATE_DIR/backups" -type f | wc -l | tr -d ' '
  else
    printf '0\n'
  fi
}

export HOME="$TMP/home"
export HERDR_PLUGIN_ROOT="$ROOT"
export HERDR_PLUGIN_STATE_DIR="$TMP/state"
unset GROK_CONFIG_DIR
mkdir -p "$HOME"

SCRIPT="$ROOT/scripts/apply-dark-glass-grok.sh"
GROK_CONFIG="$HOME/.grok/config.toml"

# A missing configuration is created with both Dark Glass settings.
fresh_output="$(bash "$SCRIPT")"
assert_contains "$fresh_output" 'Grok Dark Glass theme applied at'
[[ -f "$GROK_CONFIG" ]] || fail 'the Grok configuration was not created'
assert_valid_toml "$GROK_CONFIG"
assert_setting "$GROK_CONFIG" features terminal_theme true
assert_setting "$GROK_CONFIG" ui theme '"terminal"'
[[ "$(backup_count)" == '0' ]] || fail 'a fresh configuration produced a backup'

# A second run changes nothing and reports the theme as current.
current_output="$(bash "$SCRIPT")"
assert_contains "$current_output" 'Grok Dark Glass theme is already current'
[[ "$(backup_count)" == '0' ]] || fail 'an unchanged configuration produced a backup'

# An existing configuration keeps every unrelated setting.
cat > "$GROK_CONFIG" <<'CONFIG'
[cli]
installer = "internal"

[marketplace]
default_skills_installs_purged = true

[[marketplace.sources]]
name = "xAI Official"
git = "https://github.com/xai-org/plugin-marketplace.git"

[ui]
max_thoughts_width = 120
permission_mode = "always-approve"
theme = "auto"
CONFIG

existing_output="$(bash "$SCRIPT")"
assert_contains "$existing_output" 'Existing Grok configuration backed up to'
assert_contains "$existing_output" 'Grok Dark Glass theme applied at'
assert_valid_toml "$GROK_CONFIG"
assert_setting "$GROK_CONFIG" features terminal_theme true
assert_setting "$GROK_CONFIG" ui theme '"terminal"'
assert_setting "$GROK_CONFIG" ui max_thoughts_width 120
assert_setting "$GROK_CONFIG" ui permission_mode '"always-approve"'
assert_setting "$GROK_CONFIG" cli installer '"internal"'
assert_setting "$GROK_CONFIG" marketplace default_skills_installs_purged true
[[ "$(backup_count)" == '1' ]] || fail 'the existing configuration was not backed up'
[[ "$(grep -c '^\[ui\]$' "$GROK_CONFIG")" == '1' ]] || fail 'the ui table was duplicated'
[[ "$(grep -c '^\[marketplace\]$' "$GROK_CONFIG")" == '1' ]] || fail 'the marketplace table was duplicated'
[[ "$(grep -c '^\[\[marketplace.sources\]\]$' "$GROK_CONFIG")" == '1' ]] || fail 'the marketplace sources table was lost'
grep -q 'git = "https://github.com/xai-org/plugin-marketplace.git"' "$GROK_CONFIG" || fail 'the marketplace source was lost'

# An existing features table receives the setting instead of a second table.
cat > "$GROK_CONFIG" <<'CONFIG'
[features]
dock_enabled = true

[ui]
theme = "groknight"
CONFIG

bash "$SCRIPT" >/dev/null
assert_valid_toml "$GROK_CONFIG"
assert_setting "$GROK_CONFIG" features terminal_theme true
assert_setting "$GROK_CONFIG" features dock_enabled true
assert_setting "$GROK_CONFIG" ui theme '"terminal"'
[[ "$(grep -c '^\[features\]$' "$GROK_CONFIG")" == '1' ]] || fail 'the features table was duplicated'

# The theme only ever rewrites the settings it owns.
[[ "$(grep -c '^dock_enabled = true$' "$GROK_CONFIG")" == '1' ]] || fail 'an unrelated features setting was rewritten'

# A symlinked destination is refused.
rm -f "$GROK_CONFIG"
printf 'untouched\n' > "$TMP/real-config.toml"
ln -s "$TMP/real-config.toml" "$GROK_CONFIG"
if bash "$SCRIPT" >/dev/null 2>&1; then
  fail 'a symlinked Grok configuration was accepted'
fi
[[ "$(cat "$TMP/real-config.toml")" == 'untouched' ]] || fail 'the symlink target was modified'
rm -f "$GROK_CONFIG"

# A destination whose parent is not a directory is refused.
printf 'not a directory\n' > "$TMP/not-a-directory"
if GROK_CONFIG_DIR="$TMP/not-a-directory" bash "$SCRIPT" >/dev/null 2>&1; then
  fail 'a non-directory Grok home was accepted'
fi
[[ "$(cat "$TMP/not-a-directory")" == 'not a directory' ]] || fail 'the non-directory path was modified'

# An explicit Grok home override is honoured.
mkdir -p "$TMP/alternate-grok"
Grok_override_output="$(GROK_CONFIG_DIR="$TMP/alternate-grok" bash "$SCRIPT")"
assert_contains "$Grok_override_output" 'Grok Dark Glass theme applied at'
assert_setting "$TMP/alternate-grok/config.toml" ui theme '"terminal"'
assert_setting "$TMP/alternate-grok/config.toml" features terminal_theme true

printf 'dark glass grok tests: ok\n'
