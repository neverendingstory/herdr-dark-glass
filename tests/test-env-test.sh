#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/test-env.sh"

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/social-glass-env-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
BIN="$TEST_ROOT/bin"
PROBE_LOG="$TEST_ROOT/probes.log"
mkdir -p "$BIN"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

write_probe() {
  local name="$1"
  local status="$2"
  cat > "$BIN/$name" <<EOF
#!/usr/bin/env bash
printf '%s\\n' '$name' >> "\${PROBE_LOG:?}"
exit $status
EOF
  chmod +x "$BIN/$name"
}

# A valid explicit override must be selected without probing fallback candidates.
write_probe explicit-valid 0
write_probe python3.13 0
write_probe python3.12 0
write_probe python3.11 0
write_probe python3 0
: > "$PROBE_LOG"
resolved="$(PATH="$BIN:$PATH" PYTHON_BIN="$BIN/explicit-valid" PROBE_LOG="$PROBE_LOG" find_python_with_tomllib)"
[[ "$resolved" == "$BIN/explicit-valid" ]] || fail "valid PYTHON_BIN was not selected: $resolved"
[[ "$(cat "$PROBE_LOG")" == 'explicit-valid' ]] || fail 'fallback candidate was probed before valid PYTHON_BIN'

# An invalid explicit override must fail rather than falling back.
write_probe explicit-invalid 1
: > "$PROBE_LOG"
if output="$(PATH="$BIN:$PATH" PYTHON_BIN="$BIN/explicit-invalid" PROBE_LOG="$PROBE_LOG" find_python_with_tomllib 2>&1)"; then
  fail 'invalid PYTHON_BIN unexpectedly succeeded'
fi
[[ "$output" == "PYTHON_BIN does not provide tomllib: $BIN/explicit-invalid" ]] || fail "unexpected invalid override error: $output"
[[ "$(cat "$PROBE_LOG")" == 'explicit-invalid' ]] || fail 'fallback was used after invalid PYTHON_BIN'

# Fallback candidates must be tried in order and stop at the first compatible one.
write_probe python3.13 1
write_probe python3.12 0
write_probe python3.11 0
write_probe python3 0
: > "$PROBE_LOG"
resolved="$(PATH="$BIN:$PATH" PROBE_LOG="$PROBE_LOG" find_python_with_tomllib)"
[[ "$resolved" == "$BIN/python3.12" ]] || fail "fallback order selected: $resolved"
expected_log='python3.13
python3.12'
[[ "$(cat "$PROBE_LOG")" == "$expected_log" ]] || fail 'fallback probes did not stop at first compatible candidate'

# A third-party tomllib module must not make a pre-3.11 interpreter acceptable.
REAL_PYTHON="$(find_python_with_tomllib)"
PRE311_MODULES="$TEST_ROOT/pre311-modules"
PRE311_PYTHON="$TEST_ROOT/python-pre311"
mkdir -p "$PRE311_MODULES"
printf 'value = 1\n' > "$PRE311_MODULES/tomllib.py"
printf 'import sys\nsys.version_info = (3, 9, 6)\n' > "$PRE311_MODULES/sitecustomize.py"
cat > "$PRE311_PYTHON" <<EOF
#!/usr/bin/env bash
PYTHONPATH='$PRE311_MODULES' exec '$REAL_PYTHON' "\$@"
EOF
chmod +x "$PRE311_PYTHON"
if output="$(PYTHON_BIN="$PRE311_PYTHON" find_python_with_tomllib 2>&1)"; then
  fail 'pre-3.11 Python unexpectedly accepted with a third-party tomllib module'
fi
[[ "$output" == "PYTHON_BIN does not provide tomllib: $PRE311_PYTHON" ]] || fail "unexpected pre-3.11 Python error: $output"

printf 'test-env focused tests passed\n'
