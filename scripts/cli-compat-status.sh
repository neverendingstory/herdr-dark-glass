#!/usr/bin/env bash
set -euo pipefail

# Parse version output as bytes so control characters cannot be discarded first.
export LC_ALL=C
TEMP_OUTPUT=''

cleanup_temp_output() {
  if [[ -n "$TEMP_OUTPUT" ]]; then
    /bin/rm -f "$TEMP_OUTPUT" >/dev/null 2>&1 || :
  fi
}

trap cleanup_temp_output EXIT

extract_version() {
  /usr/bin/od -An -v -t x1 "$1" | /usr/bin/awk '
function hex_digit(character) {
  return index("0123456789abcdef", tolower(character)) - 1
}

function hex_byte(hex) {
  return (hex_digit(substr(hex, 1, 1)) * 16) + hex_digit(substr(hex, 2, 1))
}

function finish_line(  value) {
  if (have_bytes && !invalid_line && !found) {
    value = line
    sub(/^ +/, "", value)
    sub(/ +$/, "", value)
    if (length(value) > 0) {
      print substr(value, 1, 160)
      found = 1
    }
  }
  line = ""
  have_bytes = 0
  invalid_line = 0
}

{
  if (found) {
    next
  }
  for (field = 1; field <= NF; field++) {
    current = hex_byte($field)
    if (current == 10) {
      finish_line()
      if (found) {
        break
      }
    } else {
      have_bytes = 1
      if (current < 32 || current > 126) {
        invalid_line = 1
      } else {
        line = line sprintf("%c", current)
      }
    }
  }
}

END {
  if (!found) {
    finish_line()
  }
}
'
}

probe_cli() {
  local label="$1"
  local command_name="$2"
  local guidance="$3"
  local resolved
  local raw_output=''
  local version=''

  if ! resolved="$(command -v "$command_name")"; then
    printf '%s: not found (optional)\n' "$label"
    return 0
  fi

  if raw_output="$(umask 077; /usr/bin/mktemp "${TMPDIR:-/tmp}/herdr-cli-compat.XXXXXX" 2>/dev/null)"; then
    TEMP_OUTPUT="$raw_output"
    if "$resolved" --version > "$raw_output" 2>&1; then
      if ! version="$(extract_version "$raw_output")"; then
        version=''
      fi
    fi
    cleanup_temp_output
    TEMP_OUTPUT=''
  fi

  if [[ -n "$version" ]]; then
    printf '%s: installed (%s)\n' "$label" "$version"
  else
    printf '%s: installed (version unavailable)\n' "$label"
  fi
  printf '  Compatibility: %s\n' "$guidance"
}

probe_cli 'OpenCode' opencode 'select herdr-dark-glass with /themes'
probe_cli 'Claude Code' claude 'select dark-ansi with /theme'
probe_cli 'Codex CLI' codex 'terminal canvas compatible; no background setting required'
probe_cli 'Grok Build' grok 'select terminal / transparent with /theme'

exit 0
