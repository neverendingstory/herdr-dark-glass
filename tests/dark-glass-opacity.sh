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
printf '1\n' > "${MOCK_OSASCRIPT_COUNT:?}"
case "${MOCK_OSASCRIPT_FAILURE:-}" in
  '')
    printf '%s\n%s\n' "${MOCK_OSASCRIPT_CURRENT:?}" "${MOCK_OSASCRIPT_NEXT:?}"
    ;;
  missing-profile)
    printf '%s\n' 'Dark Glass profile is missing: Herdr Dark Glass Read' >&2
    exit 74
    ;;
  applescript-error)
    printf '%s\n' 'mock Terminal scripting failure' >&2
    exit 75
    ;;
  *)
    printf 'unknown mock failure mode: %s\n' "${MOCK_OSASCRIPT_FAILURE}" >&2
    exit 76
    ;;
esac
MOCK_OSASCRIPT
chmod +x "$MOCK_OSASCRIPT"

export HERDR_PLUGIN_ROOT="$ROOT"
export OSASCRIPT_BIN_PATH="$MOCK_OSASCRIPT"
export MOCK_OSASCRIPT_ARGS="$MOCK_ARGS"
export MOCK_OSASCRIPT_BODY="$MOCK_BODY"
export MOCK_OSASCRIPT_COUNT="$MOCK_COUNT"

run_cycle() {
  local current="$1"
  local next="$2"
  MOCK_OSASCRIPT_CURRENT="$current" MOCK_OSASCRIPT_NEXT="$next" \
    bash "$ROOT/scripts/cycle-dark-glass-opacity.sh"
}

# Every public transition is checked through the result protocol. The script must
# reject an AppleScript next profile that disagrees with its transition seam.
for transition in \
  'Herdr Dark Glass Glass|Herdr Dark Glass Clear|Clear|60%' \
  'Herdr Dark Glass Clear|Herdr Dark Glass Read|Read|74%' \
  'Herdr Dark Glass Read|Herdr Dark Glass Focus|Focus|88%' \
  'Herdr Dark Glass Focus|Herdr Dark Glass Glass|Glass|46%' \
  'Herdr Dark Glass|Herdr Dark Glass Clear|Clear|60%' \
  'Unrelated Profile|Herdr Dark Glass Read|Read|74%'; do
  IFS='|' read -r current next level percent <<< "$transition"
  rm -f "$MOCK_COUNT"
  output="$(run_cycle "$current" "$next")"
  [[ "$(<"$MOCK_COUNT")" == 1 ]] || fail 'cycle did not use exactly one AppleScript call'
  [[ "$output" == *"$level"* && "$output" == *"$percent"* ]] || fail "cycle did not report $level at $percent"
done

rm -f "$MOCK_COUNT"
if mismatch_output="$(run_cycle 'Herdr Dark Glass Glass' 'Herdr Dark Glass Read' 2>&1)"; then
  fail 'cycle unexpectedly accepted a mismatched AppleScript transition'
fi
[[ "$mismatch_output" == *'Unexpected Dark Glass opacity transition'* ]] || fail 'mismatched transition error was not actionable'
[[ "$(<"$MOCK_COUNT")" == 1 ]] || fail 'mismatched transition did not use exactly one AppleScript call'

# The production AppleScript must preserve the same complete transition table.
python3 - "$MOCK_BODY" <<'PY'
import pathlib
import sys

body = pathlib.Path(sys.argv[1]).read_text()
expected = '''    if currentName is glassName then
      set nextName to clearName
    else if currentName is clearName then
      set nextName to readName
    else if currentName is readName then
      set nextName to focusName
    else if currentName is focusName then
      set nextName to glassName
    else if currentName is "Herdr Dark Glass" then
      set nextName to clearName
    else
      set nextName to readName
    end if'''
assert expected in body, "production AppleScript transition table changed"
PY

printf '%s\n' - 'Herdr Dark Glass Glass' 'Herdr Dark Glass Clear' 'Herdr Dark Glass Read' 'Herdr Dark Glass Focus' > "$TMP/expected.args"
cmp -s "$TMP/expected.args" "$MOCK_ARGS" || fail 'cycle did not pass fixed profile names as separate argv values'
assert_contains "$MOCK_BODY" 'name of every settings set'
assert_contains "$MOCK_BODY" 'requiredNames'
assert_contains "$MOCK_BODY" 'selected tab of front window'
assert_contains "$MOCK_BODY" 'name of current settings of targetTab'
assert_contains "$MOCK_BODY" 'set current settings of targetTab to settings set nextName'
assert_not_contains "$MOCK_BODY" 'do script'
assert_not_contains "$MOCK_BODY" 'default settings'
assert_not_contains "$MOCK_BODY" 'startup settings'
assert_not_contains "$MOCK_BODY" 'open '
assert_not_contains "$ROOT/scripts/cycle-dark-glass-opacity.sh" 'defaults'

for failure_mode in missing-profile applescript-error; do
  if failure_output="$(MOCK_OSASCRIPT_FAILURE="$failure_mode" bash "$ROOT/scripts/cycle-dark-glass-opacity.sh" 2>&1)"; then
    fail "cycle unexpectedly accepted $failure_mode"
  fi
  [[ "$failure_output" == *'Unable to cycle Dark Glass opacity.'* ]] || fail "$failure_mode error was not actionable"
  [[ "$failure_output" == *'Verify all four cycle profiles are imported'* ]] || fail "$failure_mode error did not explain remediation"
  [[ "$(<"$MOCK_COUNT")" == 1 ]] || fail "$failure_mode did not use exactly one AppleScript call"
done

if non_macos_output="$(UNAME_BIN_PATH=false bash "$ROOT/scripts/cycle-dark-glass-opacity.sh" 2>&1)"; then
  fail 'cycle unexpectedly accepted a non-macOS platform'
fi
[[ "$non_macos_output" == *'requires macOS Terminal'* ]] || fail 'non-macOS error was not actionable'

printf 'dark glass opacity tests: ok\n'
