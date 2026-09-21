#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dark-glass-opacity.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
MOCK_BIN="$TMP/bin"
MOCK_OSASCRIPT="$MOCK_BIN/osascript"
MOCK_CALLS="$TMP/osascript.calls"
MOCK_COUNT="$TMP/osascript.count"
EXPECTED_ARGS="$TMP/expected.args"
EXPECTED_BODY="$TMP/expected.applescript"
mkdir -p "$MOCK_BIN"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

reset_osascript_calls() {
  rm -rf "$MOCK_CALLS"
  mkdir -p "$MOCK_CALLS"
  rm -f "$MOCK_COUNT"
}

assert_one_complete_cycle_call() {
  local call_args="$MOCK_CALLS/1.args"
  local call_body="$MOCK_CALLS/1.applescript"

  [[ -f "$MOCK_COUNT" && "$(<"$MOCK_COUNT")" == 1 ]] || fail 'cycle did not use exactly one AppleScript call'
  [[ "$(find "$MOCK_CALLS" -type f | wc -l | tr -d ' ')" == 2 ]] || fail 'cycle did not retain exactly one complete AppleScript call log'
  [[ -f "$call_args" && -f "$call_body" ]] || fail 'cycle did not retain complete AppleScript argv and body'
  cmp -s "$EXPECTED_ARGS" "$call_args" || fail 'cycle did not pass the exact fixed profile argv'
  cmp -s "$EXPECTED_BODY" "$call_body" || fail 'cycle AppleScript body changed'

  if [[ "$(uname -s)" == Darwin ]]; then
    command -v osacompile >/dev/null 2>&1 || fail 'macOS did not provide osacompile'
    rm -f "$TMP/captured-cycle.scpt"
    osacompile -o "$TMP/captured-cycle.scpt" "$call_body" || fail 'captured AppleScript did not compile'
  fi
}

cat > "$MOCK_OSASCRIPT" <<'MOCK_OSASCRIPT'
#!/usr/bin/env bash
set -euo pipefail

call_number=0
if [[ -f "${MOCK_OSASCRIPT_COUNT:?}" ]]; then
  call_number="$(<"${MOCK_OSASCRIPT_COUNT}")"
fi
call_number=$((call_number + 1))
printf '%s\n' "$call_number" > "${MOCK_OSASCRIPT_COUNT}"
printf '%s\n' "$@" > "${MOCK_OSASCRIPT_CALLS:?}/$call_number.args"
cat > "${MOCK_OSASCRIPT_CALLS}/$call_number.applescript"

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

printf '%s\n' - 'Herdr Dark Glass Glass' 'Herdr Dark Glass Clear' 'Herdr Dark Glass Read' 'Herdr Dark Glass Focus' > "$EXPECTED_ARGS"
cat > "$EXPECTED_BODY" <<'APPLESCRIPT'
on run argv
  if (count of argv) is not 4 then error "Dark Glass opacity cycling received invalid profile arguments."
  set glassName to item 1 of argv
  set clearName to item 2 of argv
  set readName to item 3 of argv
  set focusName to item 4 of argv
  set requiredNames to {glassName, clearName, readName, focusName}
  tell application "Terminal"
    set profileNames to name of every settings set
    repeat with requiredName in requiredNames
      if profileNames does not contain (contents of requiredName) then
        error "Dark Glass profile is missing: " & (contents of requiredName)
      end if
    end repeat
    if not (exists front window) then error "No Terminal front window is available."
    set targetTab to selected tab of front window
    set currentName to name of current settings of targetTab
    if currentName is glassName then
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
    end if
    set current settings of targetTab to settings set nextName
    if (name of current settings of targetTab) is not nextName then
      error "Terminal did not apply the requested Dark Glass profile."
    end if
    return currentName & linefeed & nextName
  end tell
end run
APPLESCRIPT

export HERDR_PLUGIN_ROOT="$ROOT"
export OSASCRIPT_BIN_PATH="$MOCK_OSASCRIPT"
export MOCK_OSASCRIPT_CALLS="$MOCK_CALLS"
export MOCK_OSASCRIPT_COUNT="$MOCK_COUNT"

if grep -Fq 'defaults' "$ROOT/scripts/cycle-dark-glass-opacity.sh"; then
  fail 'cycle script unexpectedly references Terminal defaults'
fi

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
  reset_osascript_calls
  output="$(run_cycle "$current" "$next")"
  assert_one_complete_cycle_call
  [[ "$output" == *"$level"* && "$output" == *"$percent"* ]] || fail "cycle did not report $level at $percent"
done

reset_osascript_calls
if mismatch_output="$(run_cycle 'Herdr Dark Glass Glass' 'Herdr Dark Glass Read' 2>&1)"; then
  fail 'cycle unexpectedly accepted a mismatched AppleScript transition'
fi
assert_one_complete_cycle_call
[[ "$mismatch_output" == *'Unexpected Dark Glass opacity transition'* ]] || fail 'mismatched transition error was not actionable'

for failure_mode in missing-profile applescript-error; do
  reset_osascript_calls
  if failure_output="$(MOCK_OSASCRIPT_FAILURE="$failure_mode" bash "$ROOT/scripts/cycle-dark-glass-opacity.sh" 2>&1)"; then
    fail "cycle unexpectedly accepted $failure_mode"
  fi
  assert_one_complete_cycle_call
  [[ "$failure_output" == *'Unable to cycle Dark Glass opacity.'* ]] || fail "$failure_mode error was not actionable"
  [[ "$failure_output" == *'Verify all four cycle profiles are imported'* ]] || fail "$failure_mode error did not explain remediation"
done

reset_osascript_calls
if non_macos_output="$(UNAME_BIN_PATH=false bash "$ROOT/scripts/cycle-dark-glass-opacity.sh" 2>&1)"; then
  fail 'cycle unexpectedly accepted a non-macOS platform'
fi
[[ "$non_macos_output" == *'requires macOS Terminal'* ]] || fail 'non-macOS error was not actionable'
[[ ! -e "$MOCK_COUNT" && "$(find "$MOCK_CALLS" -type f | wc -l | tr -d ' ')" == 0 ]] || fail 'non-macOS cycle invoked AppleScript'

printf 'dark glass opacity tests: ok\n'
