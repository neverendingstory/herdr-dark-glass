#!/usr/bin/env bash
set -euo pipefail

# Apply the Dark Glass theme to Grok Build.
#
# Grok Build has no importable theme file: `ui.theme` only names one of the
# built-in themes. Dark Glass maps to the built-in `terminal` theme, so the
# only persistent way to select it is Grok's own configuration file. This
# script merges exactly the two settings the theme needs and leaves every
# other setting in that file untouched.

ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugin-state/linyu.social-glass}"
GROK_DIR="${GROK_CONFIG_DIR:-$HOME/.grok}"
GROK_CONFIG="$GROK_DIR/config.toml"
SOURCE_THEME="$ROOT/integrations/grok/dark-glass.toml"
AWK="${AWK_BIN_PATH:-/usr/bin/awk}"
INSTALL="${INSTALL_BIN_PATH:-install}"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
TMP_INPUT=""
TMP_CONFIG=""

cleanup() {
  [[ -n "$TMP_INPUT" && -f "$TMP_INPUT" ]] && rm -f "$TMP_INPUT"
  [[ -n "$TMP_CONFIG" && -f "$TMP_CONFIG" ]] && rm -f "$TMP_CONFIG"
  return 0
}
trap cleanup EXIT

if [[ ! -f "$SOURCE_THEME" ]]; then
  printf 'Required Dark Glass file is missing: %s\n' "$SOURCE_THEME" >&2
  exit 1
fi

for tool in "$AWK" "$INSTALL"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required Dark Glass command is unavailable: %s\n' "$tool" >&2
    exit 1
  fi
done

if [[ -L "$GROK_CONFIG" ]]; then
  printf 'Refusing unsafe Grok configuration destination: %s\n' "$GROK_CONFIG" >&2
  exit 1
fi

if [[ -e "$GROK_CONFIG" && ! -f "$GROK_CONFIG" ]]; then
  printf 'Refusing unsafe Grok configuration destination: %s\n' "$GROK_CONFIG" >&2
  exit 1
fi

if [[ -e "$GROK_DIR" && ! -d "$GROK_DIR" ]]; then
  printf 'Refusing unsafe Grok configuration directory: %s\n' "$GROK_DIR" >&2
  exit 1
fi

TMP_INPUT="$(mktemp "${TMPDIR:-/tmp}/herdr-dark-glass-grok-input.XXXXXX")"
TMP_CONFIG="$(mktemp "${TMPDIR:-/tmp}/herdr-dark-glass-grok.XXXXXX")"

if [[ -f "$GROK_CONFIG" ]]; then
  cat "$GROK_CONFIG" > "$TMP_INPUT"
fi

# Merge the wanted tables and keys into the existing configuration. Keys the
# configuration already carries are rewritten in place; wanted keys that are
# missing are appended to their table; a wanted table that is absent
# altogether is appended as a new table. Every other line is copied verbatim.
if ! "$AWK" -v SRC="$SOURCE_THEME" -f - "$TMP_INPUT" > "$TMP_CONFIG" <<'AWK'
function table_name(header, name) {
  name = header
  sub(/^[[:space:]]*\[/, "", name)
  sub(/\].*$/, "", name)
  gsub(/[[:space:]]/, "", name)
  return name
}

function split_key(line, key) {
  key = line
  sub(/[[:space:]]*=.*$/, "", key)
  gsub(/[[:space:]]/, "", key)
  return key
}

function split_value(line, value) {
  value = line
  sub(/^[^=]*=[[:space:]]*/, "", value)
  sub(/[[:space:]]*$/, "", value)
  return value
}

function load_wanted(   line, source_section, key, value, composite) {
  source_section = ""
  want_count = 0
  while ((getline line < SRC) > 0) {
    if (line ~ /^[[:space:]]*\[\[/) { source_section = ""; continue }
    if (line ~ /^[[:space:]]*\[/) { source_section = table_name(line); continue }
    if (line ~ /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*=/ && source_section != "") {
      key = split_key(line)
      composite = source_section SUBSEP key
      if (!(composite in want)) want_order[++want_count] = composite
      want[composite] = split_value(line)
    }
  }
  close(SRC)
}

function flush_section(   position, composite, pair, table) {
  for (position = 1; position <= want_count; position++) {
    composite = want_order[position]
    split(composite, pair, SUBSEP)
    table = pair[1]
    if (table != section) continue
    if (composite in done) continue
    buffer[++buffer_count] = pair[2] " = " want[composite]
    done[composite] = 1
  }
  for (position = 1; position <= buffer_count; position++) print buffer[position]
  buffer_count = 0
}

BEGIN {
  buffer_count = 0
  section = ""
  load_wanted()
}

{
  line = $0
  if (line ~ /^[[:space:]]*\[\[/) {
    flush_section()
    buffer[++buffer_count] = line
    section = ""
    next
  }
  if (line ~ /^[[:space:]]*\[/) {
    flush_section()
    buffer[++buffer_count] = line
    section = table_name(line)
    if (section in table_seen) {
      printf "the [%s] table is declared more than once\n", section > "/dev/stderr"
      failed = 1
      exit 2
    }
    table_seen[section] = 1
    next
  }
  key = ""
  if (line ~ /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*=/) key = split_key(line)
  if (key != "" && section != "" && ((section SUBSEP key) in want)) {
    composite = section SUBSEP key
    buffer[++buffer_count] = key " = " want[composite]
    done[composite] = 1
    next
  }
  buffer[++buffer_count] = line
}

END {
  if (failed) exit 2
  flush_section()
  for (position = 1; position <= want_count; position++) {
    composite = want_order[position]
    split(composite, pair, SUBSEP)
    table = pair[1]
    if (table in table_seen) continue
    if (table in table_added) continue
    table_added[table] = 1
    print ""
    print "[" table "]"
    for (inner = 1; inner <= want_count; inner++) {
      inner_composite = want_order[inner]
      split(inner_composite, inner_pair, SUBSEP)
      if (inner_pair[1] != table) continue
      print inner_pair[2] " = " want[inner_composite]
    }
  }
}
AWK
then
  printf '%s\n' 'Unable to merge the Dark Glass theme into the Grok configuration.' >&2
  exit 1
fi

# The merged configuration must carry every wanted setting.
if ! "$AWK" -v SRC="$SOURCE_THEME" -f - "$TMP_CONFIG" <<'AWK' >/dev/null
function table_name(header, name) {
  name = header
  sub(/^[[:space:]]*\[/, "", name)
  sub(/\].*$/, "", name)
  gsub(/[[:space:]]/, "", name)
  return name
}

function split_key(line, key) {
  key = line
  sub(/[[:space:]]*=.*$/, "", key)
  gsub(/[[:space:]]/, "", key)
  return key
}

function split_value(line, value) {
  value = line
  sub(/^[^=]*=[[:space:]]*/, "", value)
  sub(/[[:space:]]*$/, "", value)
  return value
}

BEGIN {
  source_section = ""
  want_count = 0
  section = ""
  while ((getline line < SRC) > 0) {
    if (line ~ /^[[:space:]]*\[\[/) { source_section = ""; continue }
    if (line ~ /^[[:space:]]*\[/) {
      source_section = table_name(line)
      continue
    }
    if (line ~ /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*=/ && source_section != "") {
      key = split_key(line)
      composite = source_section SUBSEP key
      if (!(composite in want)) want_order[++want_count] = composite
      value = line
      sub(/^[^=]*=[[:space:]]*/, "", value)
      sub(/[[:space:]]*$/, "", value)
      want[composite] = value
    }
  }
  close(SRC)
}

{
  line = $0
  if (line ~ /^[[:space:]]*\[\[/) { section = ""; next }
  if (line ~ /^[[:space:]]*\[/) { section = table_name(line); next }
  if (line ~ /^[[:space:]]*[A-Za-z0-9_-]+[[:space:]]*=/ && section != "") {
    key = split_key(line)
    composite = section SUBSEP key
    if (composite in want) {
      value = line
      sub(/^[^=]*=[[:space:]]*/, "", value)
      sub(/[[:space:]]*$/, "", value)
      if (value != want[composite]) {
        printf "the %s setting did not apply\n", composite > "/dev/stderr"
        failed = 1
      }
      seen[composite] = 1
    }
  }
}

END {
  if (failed) exit 2
  for (position = 1; position <= want_count; position++) {
    composite = want_order[position]
    if (!(composite in seen)) {
      printf "the %s setting is missing\n", composite > "/dev/stderr"
      exit 2
    }
  }
}
AWK
then
  printf '%s\n' 'The merged Grok configuration did not carry every Dark Glass setting; nothing was written.' >&2
  exit 1
fi

if [[ -f "$GROK_CONFIG" ]] && cmp -s "$TMP_CONFIG" "$GROK_CONFIG"; then
  printf 'Grok Dark Glass theme is already current: %s\n' "$GROK_CONFIG"
  exit 0
fi

if ! mkdir -p "$GROK_DIR"; then
  printf '%s\n' 'Unable to create the Grok configuration directory.' >&2
  exit 1
fi

if [[ -f "$GROK_CONFIG" ]]; then
  if ! mkdir -p "$STATE_DIR/backups"; then
    printf '%s\n' 'Unable to create the plugin backup directory.' >&2
    exit 1
  fi
  BACKUP="$STATE_DIR/backups/grok-config-$STAMP.toml"
  if ! "$INSTALL" -m 600 "$GROK_CONFIG" "$BACKUP"; then
    printf '%s\n' 'Unable to back up the existing Grok configuration.' >&2
    exit 1
  fi
  printf 'Existing Grok configuration backed up to %s\n' "$BACKUP"
fi

if ! "$INSTALL" -m 600 "$TMP_CONFIG" "$TMP_CONFIG.installed"; then
  printf '%s\n' 'Unable to stage the Grok configuration.' >&2
  exit 1
fi
mv "$TMP_CONFIG.installed" "$GROK_CONFIG"
printf 'Grok Dark Glass theme applied at %s\n' "$GROK_CONFIG"
printf '%s\n' 'Grok Build: restart the running session to pick up the terminal theme. Under Herdr the message band stays off, so Grok renders directly on the Dark Glass canvas.'
