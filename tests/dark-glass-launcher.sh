#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dark-glass-launcher.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
MOCK_BIN="$TMP/bin"
MOCK_OSASCRIPT="$MOCK_BIN/osascript"
MOCK_LOG="$TMP/osascript.log"
MOCK_COUNT="$TMP/osascript.count"
MOCK_ARGS_DIR="$TMP/osascript-args"
MOCK_BODY_DIR="$TMP/osascript-bodies"
mkdir -p "$MOCK_BIN" "$MOCK_ARGS_DIR" "$MOCK_BODY_DIR"

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

invocation_count() {
  if [[ -f "$MOCK_COUNT" ]]; then
    /bin/cat "$MOCK_COUNT"
  else
    printf '0\n'
  fi
}

reset_mock() {
  rm -f "$MOCK_LOG" "$MOCK_COUNT" "$MOCK_ARGS_DIR"/* "$MOCK_BODY_DIR"/*
  : > "$MOCK_LOG"
}

cat > "$MOCK_OSASCRIPT" <<'MOCK_OSASCRIPT'
#!/usr/bin/env bash
set -euo pipefail
count=0
if [[ -f "${MOCK_OSASCRIPT_COUNT:?}" ]]; then
  count="$(/bin/cat "$MOCK_OSASCRIPT_COUNT")"
fi
count=$((count + 1))
printf '%s' "$count" > "$MOCK_OSASCRIPT_COUNT"
printf '%s\t%s\n' "$count" "$#" >> "${MOCK_OSASCRIPT_LOG:?}"
printf '%s\n' "$@" > "${MOCK_OSASCRIPT_ARGS_DIR:?}/$count"
/bin/cat > "${MOCK_OSASCRIPT_BODY_DIR:?}/$count"

if [[ "$#" -eq 2 ]]; then
  case "${MOCK_TERMINAL_PROFILE_STATE:-missing}" in
    present|missing)
      printf '%s\n' "${MOCK_TERMINAL_PROFILE_STATE}"
      ;;
    query-error)
      printf '%s\n' 'mock Terminal query failed' >&2
      exit 74
      ;;
    unexpected)
      printf '%s\n' 'unexpected Terminal response'
      ;;
    *)
      printf 'unknown mock Terminal state: %s\n' "${MOCK_TERMINAL_PROFILE_STATE}" >&2
      exit 75
      ;;
  esac
  exit 0
fi

if [[ "$#" -eq 4 ]]; then
  exit 0
fi

printf 'unexpected osascript argument count: %s\n' "$#" >&2
exit 76
MOCK_OSASCRIPT
chmod +x "$MOCK_OSASCRIPT"

export MOCK_OSASCRIPT_LOG="$MOCK_LOG"
export MOCK_OSASCRIPT_COUNT="$MOCK_COUNT"
export MOCK_OSASCRIPT_ARGS_DIR="$MOCK_ARGS_DIR"
export MOCK_OSASCRIPT_BODY_DIR="$MOCK_BODY_DIR"
export HERDR_PLUGIN_ROOT="$ROOT"
export HERDR_BIN_PATH="/opt/mock/herdr"
unset HERDR_DARK_GLASS_TERMINAL_PROFILE HERDR_DARK_GLASS_WINDOW_TITLE

# Each launch explicitly pins both routes to the mock, even if the caller supplied
# a different OSASCRIPT_BIN_PATH before this test began.
export OSASCRIPT_BIN_PATH="$TMP/inherited-osascript-that-must-not-run"

run_launcher() {
  OSASCRIPT_BIN_PATH="$MOCK_OSASCRIPT" PATH="$MOCK_BIN:$PATH" bash "$ROOT/scripts/open-dark-glass-window.sh" "$@"
}

# Missing profiles are reported only after one successful preflight query.
reset_mock
if missing_output="$(MOCK_TERMINAL_PROFILE_STATE=missing run_launcher 2>&1)"; then
  fail 'launcher unexpectedly accepted a missing Terminal profile'
fi
[[ "$(invocation_count)" == 1 ]] || fail 'missing profile did not make exactly one query'
grep -Fq 'Terminal profile "Herdr Dark Glass" is missing.' <<< "$missing_output" || fail 'missing profile error did not name the profile'
grep -Fq 'setup-dark-glass' <<< "$missing_output" || fail 'missing profile error did not direct setup'
assert_contains "$MOCK_BODY_DIR/1" 'name of every settings set'

# A failed query is distinct from a missing profile and must never launch a window.
reset_mock
if query_error_output="$(MOCK_TERMINAL_PROFILE_STATE=query-error run_launcher 2>&1)"; then
  fail 'launcher unexpectedly accepted a Terminal query error'
fi
[[ "$(invocation_count)" == 1 ]] || fail 'query error launched a window'
grep -Fq 'Unable to query Terminal profile' <<< "$query_error_output" || fail 'query error was not actionable'
if grep -Fq 'is missing' <<< "$query_error_output"; then
  fail 'query error was reported as a missing profile'
fi

# Unexpected protocol output fails closed before the delegated launcher runs.
reset_mock
if unexpected_output="$(MOCK_TERMINAL_PROFILE_STATE=unexpected run_launcher 2>&1)"; then
  fail 'launcher unexpectedly accepted an unknown Terminal query response'
fi
[[ "$(invocation_count)" == 1 ]] || fail 'unexpected query response launched a window'
grep -Fq 'Unexpected Terminal profile query response' <<< "$unexpected_output" || fail 'unexpected response was not actionable'

# A present profile delegates unchanged to Social with exactly its four arguments.
reset_mock
MOCK_TERMINAL_PROFILE_STATE=present \
HERDR_DARK_GLASS_TERMINAL_PROFILE='Herdr Dark Glass Test' \
HERDR_DARK_GLASS_WINDOW_TITLE='Dark Glass Test Window' \
run_launcher
[[ "$(invocation_count)" == 2 ]] || fail 'present profile did not query then launch exactly once'
printf '%s\n' '-' 'Herdr Dark Glass Test' > "$TMP/expected-query.args"
cmp -s "$TMP/expected-query.args" "$MOCK_ARGS_DIR/1" || fail 'profile query arguments were not exact'
printf '%s\n' '-' 'Herdr Dark Glass Test' '/opt/mock/herdr' 'Dark Glass Test Window' > "$TMP/expected-launch.args"
cmp -s "$TMP/expected-launch.args" "$MOCK_ARGS_DIR/2" || fail 'delegated launcher arguments were not exactly four expected values'
assert_contains "$MOCK_BODY_DIR/2" 'if (count of argv) is 5 then'
assert_contains "$MOCK_BODY_DIR/2" 'exec env -u HERDR_ENV -u HERDR_WORKSPACE_ID -u HERDR_TAB_ID -u HERDR_PANE_ID'
assert_contains "$MOCK_BODY_DIR/2" 'set previousDefaultSettings to default settings'
assert_contains "$MOCK_BODY_DIR/2" 'set default settings to socialSettings'
[[ "$(grep -Fc 'set default settings to previousDefaultSettings' "$MOCK_BODY_DIR/2")" == 2 ]] || fail 'launcher does not restore Terminal default settings on both success and failure paths'
assert_contains "$MOCK_BODY_DIR/2" 'repeat with attempt from 1 to 20'
assert_contains "$MOCK_BODY_DIR/2" 'name of current settings of socialTab'
assert_not_contains "$MOCK_BODY_DIR/2" 'set startup settings'
assert_not_contains "$MOCK_BODY_DIR/2" 'defaults write'
assert_not_contains "$MOCK_ARGS_DIR/2" '#080E14'
assert_not_contains "$MOCK_ARGS_DIR/2" '#'

# Both override classes fail before the first osascript invocation.
reset_mock
if invalid_profile_output="$(MOCK_TERMINAL_PROFILE_STATE=present HERDR_DARK_GLASS_TERMINAL_PROFILE=$'bad\nprofile' run_launcher 2>&1)"; then
  fail 'launcher accepted a multiline profile override'
fi
[[ "$(invocation_count)" == 0 ]] || fail 'invalid profile reached osascript'
grep -Fq 'HERDR_DARK_GLASS_TERMINAL_PROFILE must be one non-empty line' <<< "$invalid_profile_output" || fail 'invalid profile error was not variable-specific'

reset_mock
if invalid_title_output="$(MOCK_TERMINAL_PROFILE_STATE=present HERDR_DARK_GLASS_WINDOW_TITLE=$'bad\ttitle' run_launcher 2>&1)"; then
  fail 'launcher accepted a control character in the title override'
fi
[[ "$(invocation_count)" == 0 ]] || fail 'invalid title reached osascript'
grep -Fq 'HERDR_DARK_GLASS_WINDOW_TITLE must be one non-empty line' <<< "$invalid_title_output" || fail 'invalid title error was not variable-specific'

# Explicitly empty values are overrides, not requests for defaults.
reset_mock
if empty_profile_output="$(MOCK_TERMINAL_PROFILE_STATE=present HERDR_DARK_GLASS_TERMINAL_PROFILE='' run_launcher 2>&1)"; then
  fail 'launcher accepted an empty profile override'
fi
[[ "$(invocation_count)" == 0 ]] || fail 'empty profile reached osascript'
grep -Fq 'HERDR_DARK_GLASS_TERMINAL_PROFILE must be one non-empty line' <<< "$empty_profile_output" || fail 'empty profile error was not variable-specific'

reset_mock
if empty_title_output="$(MOCK_TERMINAL_PROFILE_STATE=present HERDR_DARK_GLASS_WINDOW_TITLE='' run_launcher 2>&1)"; then
  fail 'launcher accepted an empty title override'
fi
[[ "$(invocation_count)" == 0 ]] || fail 'empty title reached osascript'
grep -Fq 'HERDR_DARK_GLASS_WINDOW_TITLE must be one non-empty line' <<< "$empty_title_output" || fail 'empty title error was not variable-specific'

printf 'dark glass launcher tests: ok\n'
