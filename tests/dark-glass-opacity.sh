#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dark-glass-opacity.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
MOCK_BIN="$TMP/bin"
MOCK_OSASCRIPT="$MOCK_BIN/osascript"
MOCK_ARGS="$TMP/osascript.args"
MOCK_BODY="$TMP/osascript.body"
MOCK_COUNT="$TMP/osascript.count"
mkdir -p "$MOCK_BIN"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" || fail "$file does not contain: $text"
}

assert_not_contains() {
  local file="$1"
  local text="$2"
  if grep -Fq -- "$text" "$file"; then
    fail "$file unexpectedly contains: $text"
  fi
}

cat > "$MOCK_OSASCRIPT" <<'MOCK_OSASCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${MOCK_OSASCRIPT_ARGS:?}"
cat > "${MOCK_OSASCRIPT_BODY:?}"
printf '%s\n' "${MOCK_OSASCRIPT_RESULT:?}"
printf '1\n' > "${MOCK_OSASCRIPT_COUNT:?}"
MOCK_OSASCRIPT
chmod +x "$MOCK_OSASCRIPT"

export HERDR_PLUGIN_ROOT="$ROOT"
export OSASCRIPT_BIN_PATH="$MOCK_OSASCRIPT"
export MOCK_OSASCRIPT_ARGS="$MOCK_ARGS"
export MOCK_OSASCRIPT_BODY="$MOCK_BODY"
export MOCK_OSASCRIPT_COUNT="$MOCK_COUNT"

run_cycle() {
  MOCK_OSASCRIPT_RESULT="$1" bash "$ROOT/scripts/cycle-dark-glass-opacity.sh"
}

for result_and_expected in \
  'Herdr Dark Glass Glass|Glass|46%' \
  'Herdr Dark Glass Clear|Clear|60%' \
  'Herdr Dark Glass Read|Read|74%' \
  'Herdr Dark Glass Focus|Focus|88%'; do
  IFS='|' read -r result level percent <<< "$result_and_expected"
  rm -f "$MOCK_COUNT"
  output="$(run_cycle "$result")"
  [[ "$(<"$MOCK_COUNT")" == 1 ]] || fail 'cycle did not use exactly one AppleScript call'
  [[ "$output" == *"$level"* && "$output" == *"$percent"* ]] || fail "cycle did not report $level at $percent"
done

printf '%s\n' - 'Herdr Dark Glass Glass' 'Herdr Dark Glass Clear' 'Herdr Dark Glass Read' 'Herdr Dark Glass Focus' > "$TMP/expected.args"
cmp -s "$TMP/expected.args" "$MOCK_ARGS" || fail 'cycle did not pass fixed profile names as separate argv values'
assert_contains "$MOCK_BODY" 'name of every settings set'
assert_contains "$MOCK_BODY" 'requiredNames'
assert_contains "$MOCK_BODY" 'selected tab of front window'
assert_contains "$MOCK_BODY" 'name of current settings of targetTab'
assert_contains "$MOCK_BODY" 'if currentName is glassName then'
assert_contains "$MOCK_BODY" 'else if currentName is "Herdr Dark Glass" then'
assert_contains "$MOCK_BODY" 'set current settings of targetTab to settings set nextName'
assert_contains "$MOCK_BODY" 'Herdr Dark Glass'
assert_not_contains "$MOCK_BODY" 'do script'
assert_not_contains "$MOCK_BODY" 'default settings'
assert_not_contains "$MOCK_BODY" 'startup settings'
assert_not_contains "$MOCK_BODY" 'open '
assert_not_contains "$ROOT/scripts/cycle-dark-glass-opacity.sh" 'defaults'

if non_macos_output="$(UNAME_BIN_PATH=false bash "$ROOT/scripts/cycle-dark-glass-opacity.sh" 2>&1)"; then
  fail 'cycle unexpectedly accepted a non-macOS platform'
fi
[[ "$non_macos_output" == *'requires macOS Terminal'* ]] || fail 'non-macOS error was not actionable'

printf 'dark glass opacity tests: ok\n'
