#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASH_BIN="${BASH_BIN:-/bin/bash}"
RM_BIN="$(command -v rm)"
CHMOD_BIN="$(command -v chmod)"
GREP_BIN="$(command -v grep)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/social-glass-cli-compat.XXXXXX")"
trap '"$RM_BIN" -rf "$TEST_ROOT"' EXIT
MOCK_BIN="$TEST_ROOT/bin"
export MOCK_CALLS="$TEST_ROOT/calls.log"
mkdir -p "$MOCK_BIN"
: > "$MOCK_CALLS"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local text="$1"
  local needle="$2"
  [[ "$text" == *"$needle"* ]] || fail "output does not contain: $needle"
}

make_mock() {
  local name="$1"
  local body="$2"
  printf '%s\n' '#!/bin/bash' 'set -euo pipefail' "printf '%s %s\\n' '$name' \"\$*\" >> \"\${MOCK_CALLS:?}\"" "$body" > "$MOCK_BIN/$name"
  "$CHMOD_BIN" +x "$MOCK_BIN/$name"
}

# Do not allow command -v in the helper to discover host optional CLIs.
export HOME="$TEST_ROOT/home"
export XDG_CONFIG_HOME="$TEST_ROOT/xdg-config"
export XDG_STATE_HOME="$TEST_ROOT/xdg-state"
mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.grok" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
export PATH="$MOCK_BIN"
printf 'sentinel\n' > "$HOME/.claude/settings.json"
printf 'sentinel\n' > "$HOME/.codex/config.toml"
printf 'sentinel\n' > "$HOME/.grok/config.toml"
printf 'sentinel\n' > "$HOME/credentials"

make_mock opencode "printf '%s\\n' '1.18.31'"
make_mock claude "printf '%s\\n' '2.1.274 (Claude Code)'"
make_mock codex "printf '%s\\n' 'codex-cli 0.154.0'"
make_mock grok "printf '%s\\n' 'grok 1.0.40 (3736acbc8658)' >&2"
present_output="$("$BASH_BIN" "$ROOT/scripts/cli-compat-status.sh")"
assert_contains "$present_output" 'OpenCode: installed (1.18.31)'
assert_contains "$present_output" 'Claude Code: installed (2.1.274 (Claude Code))'
assert_contains "$present_output" 'Codex CLI: installed (codex-cli 0.154.0)'
assert_contains "$present_output" 'Grok Build: installed (grok 1.0.40 (3736acbc8658))'
assert_contains "$present_output" '  Compatibility: select herdr-dark-glass with /themes'
assert_contains "$present_output" '  Compatibility: select dark-ansi with /theme'
assert_contains "$present_output" '  Compatibility: terminal canvas compatible; no background setting required'
assert_contains "$present_output" '  Compatibility: Grok 1.0.40 has NO custom herdr-dark-glass theme; terminal, terminal-default, transparent, and native are rollout-gated; bare /theme transparent fails until enabled. Launch: GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok. Persistent config: [features] terminal_theme = true; [ui] theme = "terminal".'
expected_calls=$'opencode --version\nclaude --version\ncodex --version\ngrok --version'
[[ "$(<"$MOCK_CALLS")" == "$expected_calls" ]] || fail 'optional CLIs received arguments other than --version'

"$RM_BIN" "$MOCK_BIN"/*
missing_output="$("$BASH_BIN" "$ROOT/scripts/cli-compat-status.sh")"
assert_contains "$missing_output" 'OpenCode: not found (optional)'
assert_contains "$missing_output" 'Claude Code: not found (optional)'
assert_contains "$missing_output" 'Codex CLI: not found (optional)'
assert_contains "$missing_output" 'Grok Build: not found (optional)'

make_mock codex 'exit 7'
failing_output="$("$BASH_BIN" "$ROOT/scripts/cli-compat-status.sh")"
assert_contains "$failing_output" 'Codex CLI: installed (version unavailable)'
assert_contains "$failing_output" '  Compatibility: terminal canvas compatible; no background setting required'

"$RM_BIN" "$MOCK_BIN"/*
make_mock opencode "printf '\\033[31munsafe\\033[0m\\n'"
ansi_output="$("$BASH_BIN" "$ROOT/scripts/cli-compat-status.sh")"
assert_contains "$ansi_output" 'OpenCode: installed (version unavailable)'

"$RM_BIN" "$MOCK_BIN"/*
make_mock opencode "printf 'safe\\000unsafe\\n'"
nul_output="$("$BASH_BIN" "$ROOT/scripts/cli-compat-status.sh")"
assert_contains "$nul_output" 'OpenCode: installed (version unavailable)'

"$RM_BIN" "$MOCK_BIN"/*
make_mock opencode "printf 'safe\\000unsafe\\nnext good\\n'"
nul_then_good_output="$("$BASH_BIN" "$ROOT/scripts/cli-compat-status.sh")"
assert_contains "$nul_then_good_output" 'OpenCode: installed (next good)'

"$RM_BIN" "$MOCK_BIN"/*
make_mock opencode "printf '%s\\n' '  tidy version  '"
trimmed_output="$("$BASH_BIN" "$ROOT/scripts/cli-compat-status.sh")"
assert_contains "$trimmed_output" 'OpenCode: installed (tidy version)'

long_version="$(printf 'x%.0s' {1..200})"
long_expected="${long_version:0:160}"
"$RM_BIN" "$MOCK_BIN"/*
make_mock opencode "printf '%s\\n' '$long_version'"
long_output="$("$BASH_BIN" "$ROOT/scripts/cli-compat-status.sh")"
assert_contains "$long_output" "OpenCode: installed ($long_expected)"
long_first_line="${long_output%%$'\n'*}"
[[ "$long_first_line" == "OpenCode: installed ($long_expected)" ]] || fail 'version was not capped at 160 bytes'

# The helper is restricted to command discovery and --version probing; it must not
# contain references to private config or credential locations prepared above.
if "$GREP_BIN" -Eiq '\.(claude|codex|grok)|credentials?|tokens?|auth(entication)?|oauth|api[-_]?key|apikey|secrets?|config\.toml|settings\.json' "$ROOT/scripts/cli-compat-status.sh"; then
  fail 'CLI helper references private config, credential, or authentication paths'
fi

printf 'CLI compatibility status tests passed\n'
