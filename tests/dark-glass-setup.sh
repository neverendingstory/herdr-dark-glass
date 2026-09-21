#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dark-glass-setup.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

line_count() {
  wc -l < "$1" | tr -d ' '
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
export XDG_CONFIG_HOME="$TMP/xdg-config"
OPENCODE_HOME="$XDG_CONFIG_HOME/opencode"
export PATH="$TMP/bin:$PATH"
mkdir -p "$HOME" "$TMP/bin"

cat > "$TMP/bin/osascript" <<'MOCK_OSASCRIPT'
#!/usr/bin/env bash
set -euo pipefail
cat > "${MOCK_OSASCRIPT_STDIN:?}"
printf '%s\n' "$*" >> "${MOCK_OSASCRIPT_ARGS:?}"
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
MOCK_OSASCRIPT

cat > "$TMP/bin/open" <<'MOCK_OPEN'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_OPEN_LOG:?}"
[[ "${MOCK_OPEN_FAIL:-0}" != 1 ]]
MOCK_OPEN

cat > "$TMP/bin/install" <<'MOCK_INSTALL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${MOCK_INSTALL_LOG:?}"
exec /usr/bin/install "$@"
MOCK_INSTALL

for cli in opencode claude codex grok; do
  cat > "$TMP/bin/$cli" <<'MOCK_CLI'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$0 $*" >> "${MOCK_OPTIONAL_CLI_LOG:?}"
exit 97
MOCK_CLI
  chmod +x "$TMP/bin/$cli"
done
chmod +x "$TMP/bin/osascript" "$TMP/bin/open" "$TMP/bin/install"

export MOCK_OSASCRIPT_STDIN="$TMP/osascript.stdin"
export MOCK_OSASCRIPT_ARGS="$TMP/osascript.args"
export MOCK_OPEN_LOG="$TMP/open.log"
export MOCK_INSTALL_LOG="$TMP/install.log"
export MOCK_OPTIONAL_CLI_LOG="$TMP/optional-cli.log"
export OSASCRIPT_BIN_PATH="$TMP/bin/osascript"
export OPEN_BIN_PATH="$TMP/bin/open"
export INSTALL_BIN_PATH="$TMP/bin/install"
: > "$MOCK_OSASCRIPT_ARGS"
: > "$MOCK_OPEN_LOG"
: > "$MOCK_INSTALL_LOG"
: > "$MOCK_OPTIONAL_CLI_LOG"

# The source-theme check names the missing theme after a bundled profile is found.
MISSING_ROOT="$TMP/missing-root"
mkdir -p "$MISSING_ROOT/profiles"
cp "$ROOT/profiles/Herdr Dark Glass.terminal" "$MISSING_ROOT/profiles/Herdr Dark Glass.terminal"
MISSING_THEME="$MISSING_ROOT/integrations/opencode/herdr-dark-glass.json"
if HERDR_PLUGIN_ROOT="$MISSING_ROOT" MOCK_TERMINAL_PROFILE_STATE=present \
  bash "$ROOT/scripts/setup-dark-glass.sh" > "$TMP/missing-source.out" 2> "$TMP/missing-source.err"; then
  fail 'setup unexpectedly accepted a missing bundled theme'
fi
grep -Fq "Required Dark Glass file is missing: $MISSING_THEME" "$TMP/missing-source.err" || fail 'missing source error did not name the theme'
[[ ! -e "$OPENCODE_HOME" ]] || fail 'missing source created OpenCode configuration'
[[ ! -e "$HERDR_PLUGIN_STATE_DIR" ]] || fail 'missing source created plugin state'
[[ ! -s "$MOCK_OPTIONAL_CLI_LOG" ]] || fail 'missing source invoked an optional CLI'

# Unsafe destination types fail before either Terminal or theme-install side effects.
for unsafe_kind in directory symlink; do
  unsafe_xdg="$TMP/unsafe-$unsafe_kind/xdg-config"
  unsafe_home="$unsafe_xdg/opencode"
  unsafe_destination="$unsafe_home/themes/herdr-dark-glass.json"
  mkdir -p "$unsafe_home/themes"
  case "$unsafe_kind" in
    directory)
      mkdir "$unsafe_destination"
      ;;
    symlink)
      unsafe_target="$TMP/off-path-$unsafe_kind"
      mkdir -p "$unsafe_target"
      ln -s "$unsafe_target" "$unsafe_destination"
      ;;
  esac
  before_osascript_count="$(line_count "$MOCK_OSASCRIPT_ARGS")"
  before_open_count="$(line_count "$MOCK_OPEN_LOG")"
  before_install_count="$(line_count "$MOCK_INSTALL_LOG")"
  if XDG_CONFIG_HOME="$unsafe_xdg" MOCK_TERMINAL_PROFILE_STATE=present \
    bash "$ROOT/scripts/setup-dark-glass.sh" > "$TMP/unsafe-$unsafe_kind.out" 2> "$TMP/unsafe-$unsafe_kind.err"; then
    fail "setup unexpectedly accepted unsafe $unsafe_kind destination"
  fi
  grep -Fq 'Refusing unsafe OpenCode theme destination' "$TMP/unsafe-$unsafe_kind.err" || fail "unsafe $unsafe_kind error was unclear"
  [[ ! -s "$TMP/unsafe-$unsafe_kind.out" ]] || fail "unsafe $unsafe_kind printed success output"
  [[ ! -e "$HERDR_PLUGIN_STATE_DIR" ]] || fail "unsafe $unsafe_kind created plugin backup state"
  [[ "$before_osascript_count" == "$(line_count "$MOCK_OSASCRIPT_ARGS")" ]] || fail "unsafe $unsafe_kind queried Terminal"
  [[ "$before_open_count" == "$(line_count "$MOCK_OPEN_LOG")" ]] || fail "unsafe $unsafe_kind opened Terminal profile"
  [[ "$before_install_count" == "$(line_count "$MOCK_INSTALL_LOG")" ]] || fail "unsafe $unsafe_kind attempted an install"
  [[ ! -e "$unsafe_destination/herdr-dark-glass.json" ]] || fail "unsafe $unsafe_kind wrote below destination"
  if [[ "$unsafe_kind" == symlink ]]; then
    [[ ! -e "$unsafe_target/herdr-dark-glass.json" ]] || fail 'symlink destination wrote off path'
  fi
done

# A new theme installs at OpenCode's XDG discovery path and requests a visible Terminal-profile import.
MOCK_TERMINAL_PROFILE_STATE=missing bash "$ROOT/scripts/setup-dark-glass.sh" > "$TMP/first-install.out"
cmp "$ROOT/integrations/opencode/herdr-dark-glass.json" \
  "$OPENCODE_HOME/themes/herdr-dark-glass.json"
grep -Fq "OpenCode theme installed at $OPENCODE_HOME/themes/herdr-dark-glass.json" "$TMP/first-install.out" || fail 'setup did not report OpenCode discovery path'
grep -Fq 'Switch to dark mode' "$TMP/first-install.out" || fail 'setup did not explain how to select dark mode'
grep -Fq 'Lock theme mode' "$TMP/first-install.out" || fail 'setup did not explain how to persist dark mode'
grep -Fq 'dark-ansi' "$TMP/first-install.out" || fail 'setup did not name the persistent Claude Code theme'
grep -Fq 'name of every settings set' "$MOCK_OSASCRIPT_STDIN" || fail 'setup did not enumerate Terminal profile names'
[[ "$(stat -f '%Lp' "$OPENCODE_HOME/themes/herdr-dark-glass.json")" == 600 ]] || fail 'installed theme mode is not 600'
grep -Fq "$ROOT/profiles/Herdr Dark Glass.terminal" "$MOCK_OPEN_LOG" || fail 'missing Terminal profile was not opened'
[[ "$(line_count "$MOCK_OPEN_LOG")" == 1 ]] || fail 'first install imported Terminal profile more than once'
[[ ! -e "$OPENCODE_HOME/tui.json" && ! -e "$OPENCODE_HOME/tui.jsonc" ]] || fail 'setup wrote OpenCode TUI configuration'
[[ ! -s "$MOCK_OPTIONAL_CLI_LOG" ]] || fail 'setup invoked an optional CLI'

before_count="$(backup_count)"
before_install_count="$(line_count "$MOCK_INSTALL_LOG")"
# An already-current theme is a no-op and a present profile is not re-imported.
MOCK_TERMINAL_PROFILE_STATE=present bash "$ROOT/scripts/setup-dark-glass.sh"
after_count="$(backup_count)"
[[ "$before_count" == "$after_count" ]] || fail 'identical theme created a backup'
[[ "$before_install_count" == "$(line_count "$MOCK_INSTALL_LOG")" ]] || fail 'identical theme attempted an install or replacement'
[[ "$(line_count "$MOCK_OPEN_LOG")" == 1 ]] || fail 'present Terminal profile was re-imported'
[[ ! -s "$MOCK_OPTIONAL_CLI_LOG" ]] || fail 'identical setup invoked an optional CLI'

# Fallible Terminal preflight cannot alter a differing local theme or create a backup.
printf '{"name":"must-survive-terminal-preflight"}\n' > "$OPENCODE_HOME/themes/herdr-dark-glass.json"
cp "$OPENCODE_HOME/themes/herdr-dark-glass.json" "$TMP/must-survive-terminal-preflight.json"
preflight_backup_count="$(backup_count)"
preflight_install_count="$(line_count "$MOCK_INSTALL_LOG")"
open_before_preflight_error="$(line_count "$MOCK_OPEN_LOG")"
if MOCK_TERMINAL_PROFILE_STATE=query-error bash "$ROOT/scripts/setup-dark-glass.sh" > "$TMP/query-error.out" 2> "$TMP/query-error.err"; then
  fail 'setup unexpectedly accepted a Terminal query error'
fi
grep -Fq 'Unable to query Terminal profile' "$TMP/query-error.err" || fail 'query error was not actionable'
[[ ! -s "$TMP/query-error.out" ]] || fail 'query error printed success output'
cmp "$TMP/must-survive-terminal-preflight.json" "$OPENCODE_HOME/themes/herdr-dark-glass.json"
[[ "$preflight_backup_count" == "$(backup_count)" ]] || fail 'query error created a theme backup'
[[ "$preflight_install_count" == "$(line_count "$MOCK_INSTALL_LOG")" ]] || fail 'query error attempted a theme install'
[[ "$open_before_preflight_error" == "$(line_count "$MOCK_OPEN_LOG")" ]] || fail 'query error opened the Terminal profile'

if MOCK_TERMINAL_PROFILE_STATE=unexpected bash "$ROOT/scripts/setup-dark-glass.sh" > "$TMP/unexpected-query.out" 2> "$TMP/unexpected-query.err"; then
  fail 'setup unexpectedly accepted an unexpected Terminal query response'
fi
grep -Fq 'Unexpected Terminal profile query response' "$TMP/unexpected-query.err" || fail 'unexpected response was not actionable'
[[ ! -s "$TMP/unexpected-query.out" ]] || fail 'unexpected response printed success output'
cmp "$TMP/must-survive-terminal-preflight.json" "$OPENCODE_HOME/themes/herdr-dark-glass.json"
[[ "$preflight_backup_count" == "$(backup_count)" ]] || fail 'unexpected response created a theme backup'
[[ "$preflight_install_count" == "$(line_count "$MOCK_INSTALL_LOG")" ]] || fail 'unexpected response attempted a theme install'
[[ "$open_before_preflight_error" == "$(line_count "$MOCK_OPEN_LOG")" ]] || fail 'unexpected response opened the Terminal profile'

if MOCK_TERMINAL_PROFILE_STATE=missing MOCK_OPEN_FAIL=1 bash "$ROOT/scripts/setup-dark-glass.sh" > "$TMP/open-failure.out" 2> "$TMP/open-failure.err"; then
  fail 'setup unexpectedly accepted a Terminal profile import failure'
fi
grep -Fq 'Unable to open the Terminal profile for import' "$TMP/open-failure.err" || fail 'profile import failure was not actionable'
[[ ! -s "$TMP/open-failure.out" ]] || fail 'profile import failure printed success output'
cmp "$TMP/must-survive-terminal-preflight.json" "$OPENCODE_HOME/themes/herdr-dark-glass.json"
[[ "$preflight_backup_count" == "$(backup_count)" ]] || fail 'profile import failure created a theme backup'
[[ "$preflight_install_count" == "$(line_count "$MOCK_INSTALL_LOG")" ]] || fail 'profile import failure attempted a theme install'
[[ "$((open_before_preflight_error + 1))" == "$(line_count "$MOCK_OPEN_LOG")" ]] || fail 'profile import failure did not attempt exactly one visible import'

# A locally changed destination is preserved as a private backup before replacement.
printf '{"name":"local-theme"}\n' > "$OPENCODE_HOME/themes/herdr-dark-glass.json"
MOCK_TERMINAL_PROFILE_STATE=present bash "$ROOT/scripts/setup-dark-glass.sh"
cmp "$ROOT/integrations/opencode/herdr-dark-glass.json" \
  "$OPENCODE_HOME/themes/herdr-dark-glass.json"
backup=""
for candidate in "$HERDR_PLUGIN_STATE_DIR"/backups/opencode-theme-*.json; do
  [[ -f "$candidate" ]] || continue
  backup="$candidate"
  break
done
[[ -n "$backup" ]] || fail 'changed theme was not backed up'
[[ "$(stat -f '%Lp' "$backup")" == 600 ]] || fail 'theme backup mode is not 600'
grep -Fq 'local-theme' "$backup" || fail 'backup did not retain local theme'
[[ ! -s "$MOCK_OPTIONAL_CLI_LOG" ]] || fail 'replacement invoked an optional CLI'

# A partial staged copy must leave the destination byte-for-byte intact and clean up.
cat > "$TMP/bin/failing-install" <<'MOCK_FAILING_INSTALL'
#!/usr/bin/env bash
set -euo pipefail
last=""
for argument in "$@"; do
  last="$argument"
done
if [[ "$last" == *.tmp.* ]]; then
  printf 'partial staged theme\n' > "$last"
  chmod 600 "$last"
  exit 73
fi
exec /usr/bin/install "$@"
MOCK_FAILING_INSTALL
chmod +x "$TMP/bin/failing-install"
printf '{"name":"must-survive"}\n' > "$OPENCODE_HOME/themes/herdr-dark-glass.json"
cp "$OPENCODE_HOME/themes/herdr-dark-glass.json" "$TMP/must-survive.json"
export INSTALL_BIN_PATH="$TMP/bin/failing-install"
if MOCK_TERMINAL_PROFILE_STATE=present \
  bash "$ROOT/scripts/setup-dark-glass.sh" > "$TMP/copy-failure.out" 2> "$TMP/copy-failure.err"; then
  fail 'setup unexpectedly succeeded when the staged copy failed'
fi
export INSTALL_BIN_PATH="$TMP/bin/install"
cmp "$TMP/must-survive.json" "$OPENCODE_HOME/themes/herdr-dark-glass.json"
if find "$OPENCODE_HOME/themes" -maxdepth 1 -name '*.tmp.*' -print | grep -q .; then
  fail 'failed staged copy leaked a partial temporary theme'
fi
[[ ! -s "$MOCK_OPTIONAL_CLI_LOG" ]] || fail 'failed setup invoked an optional CLI'
[[ ! -e "$OPENCODE_HOME/tui.json" && ! -e "$OPENCODE_HOME/tui.jsonc" ]] || fail 'setup wrote OpenCode TUI configuration'

printf 'dark glass setup tests: ok\n'
