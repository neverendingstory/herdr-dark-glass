#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/test-env.sh"
TEST_PYTHON="$(find_python_with_tomllib)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/social-glass-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

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

assert_not_exists() {
  [[ ! -e "$1" ]] || fail "unexpected path exists: $1"
}

export HOME="$TEST_ROOT/home"
export HERDR_PLUGIN_ROOT="$ROOT"
export HERDR_PLUGIN_CONFIG_DIR="$TEST_ROOT/plugin-config"
export HERDR_PLUGIN_STATE_DIR="$TEST_ROOT/plugin-state"
export HERDR_CONFIG_PATH="$TEST_ROOT/herdr/config.toml"
export HERDR_BIN_PATH="$TEST_ROOT/bin/herdr"
export XDG_CONFIG_HOME="$TEST_ROOT/xdg-config"
export XDG_STATE_HOME="$TEST_ROOT/xdg-state"
export OSASCRIPT_BIN_PATH="$TEST_ROOT/bin/osascript"
export HERDR_DARK_GLASS_TERMINAL_PROFILE='Herdr Dark Glass'
mkdir -p "$HOME" "$HERDR_PLUGIN_CONFIG_DIR" "$(dirname "$HERDR_CONFIG_PATH")" "$(dirname "$HERDR_BIN_PATH")" "$XDG_CONFIG_HOME/opencode/themes" "$XDG_STATE_HOME/opencode"

cat > "$HERDR_BIN_PATH" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_HERDR_LOG:?}"
if [[ "${1:-}" == "--version" ]]; then
  echo 'herdr 0.8.2-test'
  exit 0
fi
if [[ "${1:-}" == "server" && "${2:-}" == "reload-config" && "${MOCK_HERDR_FAIL_NEXT:-0}" == 1 && ! -e "${MOCK_HERDR_FAIL_MARKER:?}" ]]; then
  : > "$MOCK_HERDR_FAIL_MARKER"
  exit 1
fi
MOCK
chmod +x "$HERDR_BIN_PATH"

# Pin all optional probes before the first status call, so no host application is used.
cat > "$OSASCRIPT_BIN_PATH" <<'MOCK_OSASCRIPT_STATUS'
#!/usr/bin/env bash
set -euo pipefail
while IFS= read -r _; do
  :
done
case "${MOCK_TERMINAL_PROFILE_STATE:-present}" in
  present)
    printf '%s\n' present present present present
    ;;
  missing)
    printf '%s\n' missing missing missing missing
    ;;
  query-error)
    exit 1
    ;;
  *)
    printf '%s\n' unexpected present present present
    ;;
esac
MOCK_OSASCRIPT_STATUS
chmod +x "$OSASCRIPT_BIN_PATH"

make_cli_mock() {
  local command_name="$1"
  local version="$2"
  local stream="$3"
  cat > "$TEST_ROOT/bin/$command_name" <<MOCK_CLI
#!/bin/bash
set -euo pipefail
printf '%s\\n' "\$*" >> "\${MOCK_CLI_LOG:?}"
[[ "\${1:-}" == '--version' ]] || exit 64
printf '%s\\n' '$version' $stream
MOCK_CLI
  chmod +x "$TEST_ROOT/bin/$command_name"
}

export MOCK_CLI_LOG="$TEST_ROOT/cli-calls.log"
: > "$MOCK_CLI_LOG"
make_cli_mock opencode '1.18.31' ''
make_cli_mock claude '2.1.274 (Claude Code)' ''
make_cli_mock codex 'codex-cli 0.154.0' ''
make_cli_mock grok 'grok 1.0.40 (3736acbc8658)' '>&2'
export PATH="$TEST_ROOT/bin:$PATH"

export MOCK_HERDR_LOG="$TEST_ROOT/herdr-calls.log"
export MOCK_HERDR_FAIL_MARKER="$TEST_ROOT/fail-next.marker"
: > "$MOCK_HERDR_LOG"

ORIGINAL='# original Herdr config
onboarding = true
'
printf '%s' "$ORIGINAL" > "$HERDR_CONFIG_PATH"
cp "$HERDR_CONFIG_PATH" "$TEST_ROOT/original.toml"

# Treat the local title as data, including shell syntax, quotes, and backslashes.
TITLE='QingYue "literal" \\ $(touch should-never-exist)'
printf '%s\n' "$TITLE" > "$HERDR_PLUGIN_CONFIG_DIR/window-title.txt"
(
  cd "$TEST_ROOT"
  bash "$ROOT/scripts/apply.sh"
)
assert_not_exists "$TEST_ROOT/should-never-exist"
"$TEST_PYTHON" - "$HERDR_CONFIG_PATH" "$TITLE" <<'PY'
import pathlib, sys, tomllib
config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
assert config["ui"]["window_title"] == sys.argv[2]
PY
cmp -s "$TEST_ROOT/original.toml" "$HERDR_PLUGIN_STATE_DIR/baseline-config.toml" || fail 'baseline was not preserved'
[[ "$(stat -f '%Lp' "$HERDR_CONFIG_PATH")" == 600 ]] || fail 'active config mode is not 600'
assert_contains "$MOCK_HERDR_LOG" 'server reload-config'
assert_contains "$MOCK_HERDR_LOG" 'config check'

SOCIAL_STATUS="$TEST_ROOT/social-status.txt"
bash "$ROOT/scripts/status.sh" > "$SOCIAL_STATUS"
assert_contains "$SOCIAL_STATUS" 'State:   social-glass'
assert_contains "$SOCIAL_STATUS" 'Terminal cycle profiles: 4/4 installed'
assert_contains "$SOCIAL_STATUS" 'Terminal launch default: Herdr Dark Glass Read'
assert_contains "$SOCIAL_STATUS" 'OpenCode theme: missing'
assert_contains "$SOCIAL_STATUS" 'OpenCode saved preference: verify in OpenCode with /themes'
assert_contains "$SOCIAL_STATUS" 'OpenCode active theme: verify in OpenCode with /themes'
assert_contains "$SOCIAL_STATUS" 'OpenCode: installed (1.18.31)'
assert_contains "$SOCIAL_STATUS" 'Claude Code: installed (2.1.274 (Claude Code))'
assert_contains "$SOCIAL_STATUS" 'Codex CLI: installed (codex-cli 0.154.0)'
assert_contains "$SOCIAL_STATUS" 'Grok Build: installed (grok 1.0.40 (3736acbc8658))'

# The parent status command remains successful when optional CLI probes are missing or fail.
mv "$TEST_ROOT/bin/opencode" "$TEST_ROOT/opencode-cli.mock"
MISSING_CLI_STATUS="$TEST_ROOT/missing-cli-status.txt"
PATH="$TEST_ROOT/bin:/usr/bin:/bin" bash "$ROOT/scripts/status.sh" > "$MISSING_CLI_STATUS"
assert_contains "$MISSING_CLI_STATUS" 'OpenCode: not found (optional)'
mv "$TEST_ROOT/opencode-cli.mock" "$TEST_ROOT/bin/opencode"
cat > "$TEST_ROOT/bin/codex" <<'MOCK_FAILING_CODEX'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_CLI_LOG:?}"
[[ "${1:-}" == '--version' ]] || exit 64
exit 7
MOCK_FAILING_CODEX
chmod +x "$TEST_ROOT/bin/codex"
FAILING_CLI_STATUS="$TEST_ROOT/failing-cli-status.txt"
bash "$ROOT/scripts/status.sh" > "$FAILING_CLI_STATUS"
assert_contains "$FAILING_CLI_STATUS" 'Codex CLI: installed (version unavailable)'
make_cli_mock codex 'codex-cli 0.154.0' ''

bash "$ROOT/scripts/apply-island.sh"
ISLAND_STATUS="$TEST_ROOT/island-status.txt"
bash "$ROOT/scripts/status.sh" > "$ISLAND_STATUS"
assert_contains "$ISLAND_STATUS" 'State:   island-glass'
"$TEST_PYTHON" - "$HERDR_CONFIG_PATH" "$TITLE" <<'PY'
import pathlib, sys, tomllib
config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
assert config["ui"]["window_title"] == sys.argv[2]
assert config["theme"]["custom"]["sidebar_bg"] == "#F1EAD8"
PY

bash "$ROOT/scripts/apply-dark-glass.sh"
DARK_STATUS="$TEST_ROOT/dark-status.txt"
bash "$ROOT/scripts/status.sh" > "$DARK_STATUS"
assert_contains "$DARK_STATUS" 'State:   dark-glass'
"$TEST_PYTHON" - "$HERDR_CONFIG_PATH" "$TITLE" <<'PY'
import pathlib, sys, tomllib
config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
assert config["ui"]["window_title"] == sys.argv[2]
assert config["theme"]["name"] == "catppuccin"
assert config["theme"]["custom"]["panel_bg"] == "transparent"
assert config["theme"]["custom"]["sidebar_bg"] == "transparent"
assert config["theme"]["custom"]["accent"] == "#B7D6A3"
PY

# Status checks are observational: Terminal is queried read-only and OpenCode uses XDG paths.
MISSING_TERMINAL_STATUS="$TEST_ROOT/missing-terminal-status.txt"
MOCK_TERMINAL_PROFILE_STATE=missing bash "$ROOT/scripts/status.sh" > "$MISSING_TERMINAL_STATUS"
assert_contains "$MISSING_TERMINAL_STATUS" 'Terminal cycle profiles: 0/4 installed'
QUERY_ERROR_TERMINAL_STATUS="$TEST_ROOT/query-error-terminal-status.txt"
MOCK_TERMINAL_PROFILE_STATE=query-error bash "$ROOT/scripts/status.sh" > "$QUERY_ERROR_TERMINAL_STATUS"
assert_contains "$QUERY_ERROR_TERMINAL_STATUS" 'Terminal cycle profiles: check unavailable'
assert_not_contains "$QUERY_ERROR_TERMINAL_STATUS" 'Terminal cycle profiles: 0/4 installed'
MISSING_OSASCRIPT_STATUS="$TEST_ROOT/missing-osascript-status.txt"
OSASCRIPT_BIN_PATH="$TEST_ROOT/no-such-osascript" bash "$ROOT/scripts/status.sh" > "$MISSING_OSASCRIPT_STATUS"
assert_contains "$MISSING_OSASCRIPT_STATUS" 'Terminal cycle profiles: check unavailable'
assert_not_contains "$MISSING_OSASCRIPT_STATUS" 'Terminal cycle profiles: 0/4 installed'
MALFORMED_TERMINAL_STATUS="$TEST_ROOT/malformed-terminal-status.txt"
MOCK_TERMINAL_PROFILE_STATE=unexpected bash "$ROOT/scripts/status.sh" > "$MALFORMED_TERMINAL_STATUS"
assert_contains "$MALFORMED_TERMINAL_STATUS" 'Terminal cycle profiles: check unavailable'
assert_not_contains "$MALFORMED_TERMINAL_STATUS" 'Terminal cycle profiles: 0/4 installed'

OPENCODE_THEME="$XDG_CONFIG_HOME/opencode/themes/herdr-dark-glass.json"
OPENCODE_STATE="$XDG_STATE_HOME/opencode/kv.json"
cp "$ROOT/integrations/opencode/herdr-dark-glass.json" "$OPENCODE_THEME"
printf '{"theme":"system"}\n' > "$OPENCODE_STATE"
WRONG_OPENCODE_STATUS="$TEST_ROOT/wrong-opencode-status.txt"
bash "$ROOT/scripts/status.sh" > "$WRONG_OPENCODE_STATUS"
assert_contains "$WRONG_OPENCODE_STATUS" 'OpenCode theme: installed and current'
assert_contains "$WRONG_OPENCODE_STATUS" 'OpenCode saved preference: system (not herdr-dark-glass)'
printf '{"theme":"herdr-dark-glass"}\n' > "$OPENCODE_STATE"
MATCHING_OPENCODE_STATUS="$TEST_ROOT/matching-opencode-status.txt"
bash "$ROOT/scripts/status.sh" > "$MATCHING_OPENCODE_STATUS"
assert_contains "$MATCHING_OPENCODE_STATUS" 'State:   dark-glass'
assert_contains "$MATCHING_OPENCODE_STATUS" 'OpenCode saved preference: herdr-dark-glass'
assert_contains "$MATCHING_OPENCODE_STATUS" 'OpenCode active theme: verify in OpenCode with /themes'
assert_not_contains "$MATCHING_OPENCODE_STATUS" 'OpenCode active theme: herdr-dark-glass'
printf '{"theme":"herdr-dark-glass\\n"}\n' > "$OPENCODE_STATE"
NEWLINE_OPENCODE_STATUS="$TEST_ROOT/newline-opencode-status.txt"
bash "$ROOT/scripts/status.sh" > "$NEWLINE_OPENCODE_STATUS"
assert_contains "$NEWLINE_OPENCODE_STATUS" 'OpenCode saved preference: verify in OpenCode with /themes'
assert_not_contains "$NEWLINE_OPENCODE_STATUS" 'OpenCode saved preference: herdr-dark-glass'
printf '{"theme":"safe\\u0000unsafe"}\n' > "$OPENCODE_STATE"
NUL_OPENCODE_STATUS="$TEST_ROOT/nul-opencode-status.txt"
bash "$ROOT/scripts/status.sh" > "$NUL_OPENCODE_STATUS"
assert_contains "$NUL_OPENCODE_STATUS" 'OpenCode saved preference: verify in OpenCode with /themes'
assert_not_contains "$NUL_OPENCODE_STATUS" 'OpenCode saved preference: herdr-dark-glass'
printf '{"theme":"herdr-dark-glass"}\n' > "$OPENCODE_STATE"
printf '{"locally_modified":true}\n' > "$OPENCODE_THEME"
MODIFIED_OPENCODE_STATUS="$TEST_ROOT/modified-opencode-status.txt"
bash "$ROOT/scripts/status.sh" > "$MODIFIED_OPENCODE_STATUS"
assert_contains "$MODIFIED_OPENCODE_STATUS" 'OpenCode theme: installed but locally modified'
rm -f "$OPENCODE_STATE"
ABSENT_OPENCODE_STATUS="$TEST_ROOT/absent-opencode-status.txt"
bash "$ROOT/scripts/status.sh" > "$ABSENT_OPENCODE_STATUS"
assert_contains "$ABSENT_OPENCODE_STATUS" 'OpenCode saved preference: verify in OpenCode with /themes'
printf '{malformed\n' > "$OPENCODE_STATE"
MALFORMED_OPENCODE_STATUS="$TEST_ROOT/malformed-opencode-status.txt"
bash "$ROOT/scripts/status.sh" > "$MALFORMED_OPENCODE_STATUS"
assert_contains "$MALFORMED_OPENCODE_STATUS" 'OpenCode saved preference: verify in OpenCode with /themes'

# A reload failure must restore the exact immediate predecessor and reload it.
cp "$HERDR_CONFIG_PATH" "$TEST_ROOT/before-failed-apply.toml"
rm -f "$MOCK_HERDR_FAIL_MARKER"
export MOCK_HERDR_FAIL_NEXT=1
if bash "$ROOT/scripts/apply.sh" > "$TEST_ROOT/failed-apply.out" 2> "$TEST_ROOT/failed-apply.err"; then
  fail 'apply unexpectedly succeeded when reload failed'
fi
unset MOCK_HERDR_FAIL_NEXT
cmp -s "$TEST_ROOT/before-failed-apply.toml" "$HERDR_CONFIG_PATH" || fail 'reload failure did not restore immediate backup'
assert_contains "$TEST_ROOT/failed-apply.err" 'previous config restored'
[[ "$(grep -c '^server reload-config$' "$MOCK_HERDR_LOG")" -ge 4 ]] || fail 'rollback reload was not attempted'

# Invalid local titles must fail closed without touching config or invoking Herdr.
cp "$HERDR_CONFIG_PATH" "$TEST_ROOT/before-invalid-title.toml"
CALLS_BEFORE="$(wc -l < "$MOCK_HERDR_LOG" | tr -d ' ')"
printf 'bad\ttitle\n' > "$HERDR_PLUGIN_CONFIG_DIR/window-title.txt"
if bash "$ROOT/scripts/apply.sh" > /dev/null 2> "$TEST_ROOT/control-title.err"; then
  fail 'control-character title was accepted'
fi
assert_contains "$TEST_ROOT/control-title.err" 'window title'
cmp -s "$TEST_ROOT/before-invalid-title.toml" "$HERDR_CONFIG_PATH" || fail 'invalid title changed config'
[[ "$(wc -l < "$MOCK_HERDR_LOG" | tr -d ' ')" == "$CALLS_BEFORE" ]] || fail 'invalid title invoked Herdr'

"$TEST_PYTHON" - <<'PY' > "$HERDR_PLUGIN_CONFIG_DIR/window-title.txt"
print("x" * 121)
PY
if bash "$ROOT/scripts/apply-island.sh" > /dev/null 2> "$TEST_ROOT/long-title.err"; then
  fail 'overlong title was accepted'
fi
assert_contains "$TEST_ROOT/long-title.err" 'window title'
cmp -s "$TEST_ROOT/before-invalid-title.toml" "$HERDR_CONFIG_PATH" || fail 'overlong title changed config'

# Without local personalization, applying a public preset keeps its generic title.
mv "$HERDR_PLUGIN_CONFIG_DIR/window-title.txt" "$TEST_ROOT/window-title.disabled"
bash "$ROOT/scripts/apply-island.sh" > "$TEST_ROOT/generic-apply.out"
"$TEST_PYTHON" - "$HERDR_CONFIG_PATH" <<'PY'
import pathlib, sys, tomllib
config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
assert config["ui"]["window_title"] == "Herdr Island Glass"
PY
mv "$TEST_ROOT/window-title.disabled" "$HERDR_PLUGIN_CONFIG_DIR/window-title.txt"

# Restore must return the first pre-theme baseline, not a later variant.
printf '%s\n' 'Restored title' > "$HERDR_PLUGIN_CONFIG_DIR/window-title.txt"
bash "$ROOT/scripts/restore.sh"
cmp -s "$TEST_ROOT/original.toml" "$HERDR_CONFIG_PATH" || fail 'restore did not recover original baseline'

printf 'local_marker = true\n' >> "$HERDR_CONFIG_PATH"
MODIFIED_STATUS="$TEST_ROOT/modified-status.txt"
bash "$ROOT/scripts/status.sh" > "$MODIFIED_STATUS"
assert_contains "$MODIFIED_STATUS" 'State:   not applied or locally modified'

# The Island launcher adds per-window OSC 10/11 defaults; Social adds none.
cat > "$TEST_ROOT/bin/osascript" <<'MOCK_OSASCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "${MOCK_OSASCRIPT_ARGS:?}"
cp /dev/stdin "${MOCK_OSASCRIPT_STDIN:?}"
MOCK_OSASCRIPT
chmod +x "$TEST_ROOT/bin/osascript"
export PATH="$TEST_ROOT/bin:$PATH"
export MOCK_OSASCRIPT_ARGS="$TEST_ROOT/osascript.args"
export MOCK_OSASCRIPT_STDIN="$TEST_ROOT/osascript.stdin"

bash "$ROOT/scripts/open-island-window.sh" > /dev/null
assert_contains "$MOCK_OSASCRIPT_ARGS" '#5B4636'
assert_contains "$MOCK_OSASCRIPT_ARGS" '#F8F4E8'
assert_contains "$MOCK_OSASCRIPT_STDIN" "\\\\033]10;%s\\\\007"
assert_contains "$MOCK_OSASCRIPT_STDIN" "\\\\033]11;%s\\\\007"

SOCIAL_ARGS="$TEST_ROOT/social-osascript.args"
SOCIAL_STDIN="$TEST_ROOT/social-osascript.stdin"
MOCK_OSASCRIPT_ARGS="$SOCIAL_ARGS" MOCK_OSASCRIPT_STDIN="$SOCIAL_STDIN" bash "$ROOT/scripts/open-social-window.sh" > /dev/null
[[ "$(wc -l < "$SOCIAL_ARGS" | tr -d ' ')" == 4 ]] || fail 'Social launcher gained Island color arguments'

cp "$MOCK_OSASCRIPT_ARGS" "$TEST_ROOT/island-valid.args"
if HERDR_ISLAND_FOREGROUND='#12345;bad' bash "$ROOT/scripts/open-island-window.sh" > /dev/null 2> "$TEST_ROOT/invalid-color.err"; then
  fail 'invalid Island foreground was accepted'
fi
assert_contains "$TEST_ROOT/invalid-color.err" 'Invalid Island foreground color'
cmp -s "$TEST_ROOT/island-valid.args" "$MOCK_OSASCRIPT_ARGS" || fail 'invalid color reached osascript'

if HERDR_ISLAND_BACKGROUND='rgb(1,2,3)' bash "$ROOT/scripts/open-island-window.sh" > /dev/null 2> "$TEST_ROOT/invalid-background.err"; then
  fail 'invalid Island background was accepted'
fi
assert_contains "$TEST_ROOT/invalid-background.err" 'Invalid Island background color'
cmp -s "$TEST_ROOT/island-valid.args" "$MOCK_OSASCRIPT_ARGS" || fail 'invalid background reached osascript'

if find "$(dirname "$HERDR_CONFIG_PATH")" -maxdepth 1 -type f \( -name '*.social-glass.*' -o -name '*.island-glass.*' -o -name '*.dark-glass.*' \) | grep -q .; then
  fail 'temporary config file was left behind'
fi

printf 'functional tests passed\n'
