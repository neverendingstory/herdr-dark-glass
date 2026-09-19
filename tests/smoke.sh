#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/test-env.sh"
TEST_PYTHON="$(find_python_with_tomllib)"
bash "$ROOT/tests/test-env-test.sh"
bash "$ROOT/tests/cli-compat-status.sh"

[[ -x "$ROOT/scripts/cli-compat-status.sh" ]] || { printf '%s\n' 'CLI compatibility helper is not executable' >&2; exit 1; }
[[ -x "$ROOT/tests/cli-compat-status.sh" ]] || { printf '%s\n' 'CLI compatibility test is not executable' >&2; exit 1; }

for script in "$ROOT"/scripts/*.sh; do
  bash -n "$script"
done

"$TEST_PYTHON" - "$ROOT/herdr-plugin.toml" "$ROOT/theme/social-glass.toml" "$ROOT/theme/island-glass.toml" "$ROOT/theme/dark-glass.toml" <<'PY'
import os
import pathlib
import re
import sys
import tomllib

if not __debug__:
    raise RuntimeError("smoke assertions require assertions; do not use PYTHONOPTIMIZE")

manifest_path, social_path, island_path, dark_path = map(pathlib.Path, sys.argv[1:])
manifest = tomllib.loads(manifest_path.read_text())
social = tomllib.loads(social_path.read_text())
island = tomllib.loads(island_path.read_text())
dark = tomllib.loads(dark_path.read_text())

HEREDOC_START = re.compile(
    r"<<-?[ \t]*(?:(['\"])([A-Za-z_][A-Za-z0-9_]*)\1|([A-Za-z_][A-Za-z0-9_]*))"
)
DEFAULTS_MUTATION = re.compile(
    r"(?<![A-Za-z0-9_.-])(?:(?:/[A-Za-z0-9_.-]+)+/defaults|defaults)"
    r"(?![A-Za-z0-9_.-])[ \t]+(?:write|delete|import)\b"
)
TUI_PATH = re.compile(r"\btui\.jsonc?\b", re.IGNORECASE)
PRIVATE_STATE = re.compile(
    r"(?ix)(?:(?<![a-z0-9_-])\.(?:claude|codex|grok)(?![a-z0-9_-])|"
    r"(?<![a-z0-9_])(?:credentials?|tokens?|auth(?:entication)?|oauth|api[-_]?key|secrets?)(?![a-z0-9_]))"
)


def executable_shell_source(source):
    source = re.sub(r"\\\n", " ", source)
    code = []
    heredoc_end = None
    for line in source.splitlines(keepends=True):
        if heredoc_end is not None:
            if line.strip() == heredoc_end:
                heredoc_end = None
            continue
        if line.lstrip().startswith("#"):
            continue
        code.append(line)
        match = HEREDOC_START.search(line)
        if match and match.group(1):
            heredoc_end = match.group(2)
    return "".join(code)


# Reject executable mutation/access code while excluding user-facing heredoc prose.
assert DEFAULTS_MUTATION.search("defaults write com.apple.Terminal value\n")
assert DEFAULTS_MUTATION.search(executable_shell_source("/usr/bin/defaults \\\nwrite com.apple.Terminal value\n"))
assert DEFAULTS_MUTATION.search("defaults delete com.apple.Terminal value\n")
assert DEFAULTS_MUTATION.search("defaults import com.apple.Terminal value\n")
assert DEFAULTS_MUTATION.search("/usr/bin/defaults delete com.apple.Terminal value\n")
assert DEFAULTS_MUTATION.search("/usr/bin/defaults import com.apple.Terminal value\n")
assert DEFAULTS_MUTATION.search("env /usr/bin/defaults write com.apple.Terminal value\n")
assert DEFAULTS_MUTATION.search('result="$(/usr/bin/defaults write com.apple.Terminal value)"\n')
assert not DEFAULTS_MUTATION.search("mydefaults write com.apple.Terminal value\n")
assert not PRIVATE_STATE.search("author = 'safe prose'")
assert PRIVATE_STATE.search("authentication = 'forbidden'")
assert PRIVATE_STATE.search('rm -rf "$HOME/.claude"\n')
assert PRIVATE_STATE.search('rm -rf "$HOME/.codex"\n')
assert PRIVATE_STATE.search('rm -rf "$HOME/.grok"\n')
assert not TUI_PATH.search(executable_shell_source("cat <<'GUIDE'\nmanual tui.json prose\nGUIDE\n"))
assert TUI_PATH.search(executable_shell_source('cat "$HOME/.config/opencode/tui.json"\n'))
assert not DEFAULTS_MUTATION.search(executable_shell_source("cat <<'GUIDE'\n$(/usr/bin/defaults write com.apple.Terminal value)\nGUIDE\n"))
assert DEFAULTS_MUTATION.search(executable_shell_source("cat <<GUIDE\n$(/usr/bin/defaults write com.apple.Terminal value)\nGUIDE\n"))
assert PRIVATE_STATE.search(executable_shell_source("cat <<GUIDE\nrm -rf \"$HOME/.claude\"\nGUIDE\n"))

for script_path in sorted((manifest_path.parent / "scripts").glob("*.sh")):
    executable = executable_shell_source(script_path.read_text())
    assert not DEFAULTS_MUTATION.search(executable), f"Terminal defaults mutation: {script_path}"
    assert not TUI_PATH.search(executable), f"OpenCode TUI access: {script_path}"
    assert not PRIVATE_STATE.search(executable), f"private CLI state access: {script_path}"

assert manifest["id"] == "linyu.social-glass"
assert manifest["version"] == "1.2.0"
assert manifest["min_herdr_version"] == "0.8.2"
assert manifest["platforms"] == ["macos"]

actions = {action["id"]: action for action in manifest["actions"]}
assert set(actions) == {
    "apply",
    "apply-island",
    "apply-dark-glass",
    "setup-dark-glass",
    "restore",
    "open-window",
    "open-island-window",
    "open-dark-glass-window",
    "status",
}
assert actions["apply"]["command"] == ["bash", "scripts/apply.sh"]
assert actions["open-window"]["command"] == ["bash", "scripts/open-social-window.sh"]
assert actions["restore"]["command"] == ["bash", "scripts/restore.sh"]
assert actions["status"]["command"] == ["bash", "scripts/status.sh"]
assert actions["apply-island"]["command"] == ["bash", "scripts/apply-island.sh"]
assert actions["apply-dark-glass"]["command"] == ["bash", "scripts/apply-dark-glass.sh"]
assert actions["setup-dark-glass"]["command"] == ["bash", "scripts/setup-dark-glass.sh"]
assert actions["open-island-window"]["command"] == ["bash", "scripts/open-island-window.sh"]
assert actions["open-dark-glass-window"]["command"] == ["bash", "scripts/open-dark-glass-window.sh"]

assert social["theme"]["name"] == "catppuccin-latte"
assert social["theme"]["custom"]["panel_bg"] == "reset"
assert social["ui"]["sidebar_collapsed_mode"] == "hidden"
assert social["ui"]["tab_bar_position"] == "top"
assert social["ui"]["sidebar_width"] == 29
assert social["ui"]["sidebar_min_width"] == 25
assert social["ui"]["sidebar_max_width"] == 33

custom = island["theme"]["custom"]
assert island["theme"]["name"] == "catppuccin-latte"
assert custom["sidebar_bg"] == "#F1EAD8"
assert custom["active_row_bg"] == "#E3EFCF"
assert custom["selection_bg"] == "#F3D77D"
assert custom["accent"] == "#4F7D2A"
assert custom["blue"] == "#2FAFA0"
assert custom["mauve"] == "#2FAFA0"
assert custom["green"] == "#68A942"
assert custom["yellow"] == "#D6A53A"
assert custom["red"] == "#D86D5F"
assert custom["surface0"] == "#E9DFC9"
assert custom["surface1"] == "#DED1B8"
assert custom["overlay0"] == "#A89578"
assert custom["overlay1"] == "#8E7A60"
assert custom["text"] == "#5B4636"
assert custom["subtext0"] == "#7B6750"
assert island["ui"]["accent"] == "#4F7D2A"

dark_custom = dark["theme"]["custom"]
dark_ui = dark["ui"]
assert dark["theme"]["name"] == "catppuccin"
assert dark["theme"]["auto_switch"] is False
assert dark_custom["panel_bg"] == "transparent"
assert dark_custom["sidebar_bg"] == "transparent"
assert dark_custom["active_row_bg"] == "#29332D"
assert dark_custom["selection_bg"] == "#3A463E"
assert dark_custom["text"] == "#F5F3ED"
assert dark_custom["subtext0"] == "#B9BEB9"
assert dark_custom["overlay0"] == "#87918C"
assert dark_custom["accent"] == "#B7D6A3"
assert dark_custom["blue"] == "#8BD5FF"
assert dark_custom["mauve"] == "#C4A7E7"
assert dark_custom["green"] == "#A6D189"
assert dark_custom["yellow"] == "#E5C890"
assert dark_custom["peach"] == "#E5C890"
assert dark_custom["red"] == "#E78284"
assert dark_ui["window_title"] == "Herdr Dark Glass"
assert dark_ui["sidebar_width"] == 32
assert dark_ui["sidebar_min_width"] == 28
assert dark_ui["sidebar_max_width"] == 36
assert dark_ui["pane_gaps"] is True
assert dark_ui["pane_borders"] is True
assert dark_ui["status_indicators"] == "symbols"
assert dark_ui["accent"] == "#B7D6A3"
assert dark_ui["tab_bar_right"] == [
    {"type": "text", "text": "DARK GLASS"},
    {"type": "datetime", "format": "%m/%d %H:%M"},
]
assert dark_ui["tab_bar_right_separator"] == " · "
assert dark_ui["sidebar"]["agents"] == {
    "row_gap": 1,
    "rows": [
        [
            {"token": "state_icon"},
            {"token": "agent", "fg": "#F5F3ED", "bold": True},
            {"token": "state_text", "fg": "#8BD5FF", "bold": True},
        ],
        [
            {"token": "workspace", "fg": "#A6D189", "bold": True},
            {"token": "tab", "fg": "#C4A7E7"},
        ],
    ],
}
assert dark_ui["sidebar"]["spaces"] == {
    "row_gap": 1,
    "rows": [
        [
            {"token": "state_icon"},
            {"token": "workspace", "fg": "#F5F3ED", "bold": True},
        ],
        [
            {"token": "branch", "fg": "#8BD5FF"},
            {"token": "git_status", "fg": "#E5C890", "bold": True},
        ],
    ],
}

def relative_luminance(color):
    channels = [int(color[index:index + 2], 16) / 255 for index in (1, 3, 5)]
    linear = [channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4 for channel in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]

assert 1.05 / (relative_luminance(island["ui"]["accent"]) + 0.05) >= 4.5
assert island["ui"]["sidebar_width"] == 32
assert island["ui"]["sidebar_min_width"] == 28
assert island["ui"]["sidebar_max_width"] == 36
assert island["ui"]["pane_gaps"] is True
assert island["ui"]["pane_borders"] is True
assert island["ui"]["status_indicators"] == "symbols"
assert island["ui"]["tab_bar_right"] == [
    {"type": "text", "text": "QINGYUE LAB"},
    {"type": "datetime", "format": "%m/%d %H:%M"},
]
assert island["ui"]["tab_bar_right_separator"] == " · "

for path, theme in ((social_path, social), (island_path, island), (dark_path, dark)):
    assert "yulin807" not in path.read_text()
    assert theme["ui"]["window_title"] in {"Herdr Social Glass", "Herdr Island Glass", "Herdr Dark Glass"}

for relative in (
    "scripts/apply-island.sh",
    "scripts/apply-dark-glass.sh",
    "scripts/setup-dark-glass.sh",
    "scripts/apply-preset.sh",
    "scripts/open-island-window.sh",
    "scripts/open-dark-glass-window.sh",
    "tests/functional.sh",
):
    assert os.access(manifest_path.parent / relative, os.X_OK), f"not executable: {relative}"

assert "assets/plugin-actions.png" not in (manifest_path.parent / "README.md").read_text()

readme = (manifest_path.parent / "README.md").read_text()
guide = (manifest_path.parent / "scripts" / "guide.sh").read_text()
manual_headings = (
    "## Manual 1 — macOS Terminal",
    "## Manual 2 — Herdr",
    "## Manual 3 — CLI inside Herdr Dark Glass",
)
for heading in manual_headings:
    assert readme.count(heading) == 1, heading
for heading in ("### OpenCode", "### Claude Code", "### Codex CLI", "### Grok Build"):
    assert readme.count(heading) == 1, heading

for value in (
    "three screenshot-friendly presets",
    "Social and Island existing visuals and launch behavior remain unchanged",
    "herdr plugin install neverendingstory/herdr-dark-glass",
    "setup-dark-glass",
    "apply-dark-glass",
    "open-dark-glass-window",
    "herdr-dark-glass",
    "54% transparent",
    "BackgroundBlur = 0.24",
    "dark-ansi",
    "tui.theme",
    "GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok",
    "grok --minimal",
    "Terminal Settings",
    "third-party",
    "OpenCode 1.18.31",
    "Claude Code 2.1.274",
    "Codex CLI 0.154.0",
    "Grok Build 1.0.34",
    "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/themes/herdr-dark-glass.json",
    "~/.config/opencode/themes/herdr-dark-glass.json",
    "OpenCode, Claude Code, Codex CLI, and Grok Build are optional; none is required",
    "To remove the profile manually, open **Terminal Settings**",
    "remove the OpenCode theme file manually",
    "`HERDR_DARK_GLASS_TERMINAL_PROFILE` may override the profile name used by Dark Glass setup, status, and launch",
    "`HERDR_DARK_GLASS_WINDOW_TITLE` applies only to the Dark Glass launch",
    "invokes each resolved executable only with `--version`",
    "that subprocess's own behavior remains the responsibility of the CLI provider",
):
    assert value in readme, value
assert "never reads or writes `tui.json`" in readme
assert "saved preference" in readme
assert "verify active theme" in readme
assert "Social/Island unchanged" in readme
assert "HERDR SOCIAL GLASS 1.2" in guide
assert "183;214;163" in guide
assert "185;190;185" in guide
assert "Social Glass + Island Glass + Dark Glass workspace presets." in guide
PY

"$TEST_PYTHON" "$ROOT/tests/dark-glass-assets.py"
bash "$ROOT/tests/dark-glass-setup.sh"
bash "$ROOT/tests/dark-glass-launcher.sh"

printf 'smoke tests passed\n'
