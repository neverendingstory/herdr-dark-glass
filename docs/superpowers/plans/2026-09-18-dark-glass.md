# Herdr Dark Glass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a third Dark Glass mode that combines a dedicated translucent macOS Terminal profile, transparent Herdr surfaces, a transparent OpenCode theme, and non-invasive compatibility guidance for Claude Code, Codex CLI, and Grok Build without changing Social Glass or Island Glass behavior.

**Architecture:** Keep opacity and blur in an explicitly imported `Herdr Dark Glass` Terminal settings profile. Add a `dark-glass` Herdr preset whose large surfaces delegate to the host terminal, install a complete OpenCode theme whose major backgrounds are `none`, and report optional CLI availability through a read-only helper. Claude Code, Codex CLI, and Grok Build remain user-configured through documented terminal-native modes; setup never writes their settings or credentials.

**Tech Stack:** Bash 3.2-compatible shell scripts, TOML plugin/Herdr configuration, JSON OpenCode themes, Python 3 (`json` and `plistlib`) plus Python 3.11+ with `tomllib` for tests, AppleScript through `osascript`, macOS Terminal `.terminal` plists.

> **Verified implementation correction:** OpenCode 1.18.31 ignores `OPENCODE_CONFIG_DIR`; the shipped implementation therefore derives theme discovery only from `${XDG_CONFIG_HOME:-$HOME/.config}/opencode` and saved state only from `${XDG_STATE_HOME:-$HOME/.local/state}/opencode`. Every later plan snippet that mentions `OPENCODE_CONFIG_DIR` or `OPENCODE_STATE_DIR` is an obsolete planning draft superseded by this rule; do not reintroduce either custom seam into runtime code or tests.

---

## Scope and file map

Implementation happens only in the delivery clone at `/Users/jachael/Documents/byMySide/herdr-dark-glass`. It starts from `main` at `9c0991f`, uses the feature branch `feat/dark-glass`, and will eventually push to `git@github.com-work:neverendingstory/herdr-dark-glass.git`. Do not edit the detached checkout under `~/.config/herdr/plugins/github/` or implement in the earlier planning clone under `Documents/project/`. The user has explicitly deferred every commit and the push until after they deploy the uncommitted feature clone and report success; all commit steps below are therefore replaced by no-commit review checkpoints during this execution.

### Create

- `theme/dark-glass.toml` — complete Herdr preset using the dark Catppuccin base and transparent large surfaces.
- `scripts/apply-dark-glass.sh` — thin wrapper selecting the new preset.
- `tools/build-terminal-profile.py` — deterministic generator for archived Terminal colors/font and the importable profile.
- `profiles/Herdr Dark Glass.terminal` — generated Terminal profile with `#080E14` at alpha `0.46` and blur `0.24`.
- `integrations/opencode/herdr-dark-glass.json` — complete transparent OpenCode theme.
- `scripts/setup-dark-glass.sh` — safe OpenCode theme installer and explicit Terminal profile importer.
- `scripts/open-dark-glass-window.sh` — profile preflight plus Dark Glass window launch.
- `tests/dark-glass-assets.py` — deterministic asset, palette, and schema assertions.
- `tests/dark-glass-setup.sh` — isolated setup/idempotency/backup/import tests.
- `tests/dark-glass-launcher.sh` — isolated launcher profile/argument/no-OSC tests.
- `tests/test-env.sh` — resolve a Python interpreter that provides `tomllib` for parser-based tests.
- `scripts/cli-compat-status.sh` — read-only availability/version report for OpenCode, Claude Code, Codex CLI, and Grok Build.
- `tests/cli-compat-status.sh` — isolated present/missing/failing CLI probe tests.

### Modify

- `herdr-plugin.toml` — bump to `1.2.0` and register the three Dark Glass actions.
- `scripts/apply-preset.sh` — recognize `dark-glass` and validate each preset's expected base theme.
- `scripts/status.sh` — detect all three Herdr presets, Terminal profile availability, OpenCode theme content/selection, and optional CLI availability/versions.
- `scripts/guide.sh` — identify version 1.2 and the third mode before rendering the README.
- `tests/smoke.sh` — use the test Python resolver, assert final action/assets/manual contracts, and invoke focused Python/shell tests.
- `tests/functional.sh` — use the test Python resolver and exercise Dark Glass apply/status/rollback/restore while retaining all current regressions.
- `README.md` — provide separate Terminal, Herdr, and CLI-inside-Herdr manuals, including OpenCode, Claude Code, Codex CLI, and Grok Build.

## Stable interfaces and test seams

Use these environment variables consistently:

| Variable | Default | Purpose |
|---|---|---|
| `HERDR_PLUGIN_ROOT` | repository root inferred from script | locate bundled files |
| `HERDR_PLUGIN_STATE_DIR` | existing plugin state directory | backups and baseline |
| `HERDR_CONFIG_PATH` | existing Herdr config path | preset activation |
| `HERDR_BIN_PATH` | `herdr` | tests and alternate binaries |
| `HERDR_DARK_GLASS_TERMINAL_PROFILE` | `Herdr Dark Glass` | validated profile override |
| `HERDR_DARK_GLASS_WINDOW_TITLE` | `Herdr Dark Glass` | validated title override |
| `XDG_CONFIG_HOME` | `$HOME/.config` | sole supported base for OpenCode theme discovery |
| `XDG_STATE_HOME` | `$HOME/.local/state` | sole supported base for optional saved-preference reporting |
| `OSASCRIPT_BIN_PATH` | `osascript` | isolated profile checks |
| `OPEN_BIN_PATH` | `open` | isolated explicit profile import |
| `INSTALL_BIN_PATH` | `install` | simulate atomic-copy failure without touching the destination |
| `PYTHON_BIN` | first Python 3.13/3.12/3.11/3 with `tomllib` | parser-based test interpreter override |

The Dark launcher validates its profile and title overrides before delegating; the existing strict color validation and zero-or-two-color interface remain in `scripts/open-social-window.sh`. The OpenCode theme installer writes a temporary sibling and then uses `mv`, so a failed copy never truncates the current destination.

---

### Task 0: Preserve the approved design and establish a clean baseline

**Files:**
- Add: `docs/superpowers/specs/2026-09-18-dark-glass-design.md`
- Add: `docs/superpowers/plans/2026-09-18-dark-glass.md`

- [ ] **Step 1: Create the implementation branch in the delivery repository**

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
git status --short --branch
git switch -c feat/dark-glass
git remote -v
```

Expected: the initial status is `main` at `9c0991f` with no changes except the copied untracked `docs/`, the new current branch is `feat/dark-glass`, and `origin` fetch/push is `git@github.com-work:neverendingstory/herdr-dark-glass.git`. No implementation files are modified.

- [ ] **Step 2: Run the current baseline tests before changing implementation**

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
bash tests/smoke.sh
bash tests/functional.sh
```

Expected: on the target machine, `tests/smoke.sh` fails before implementation because `/usr/bin/python3` is Python 3.9.6 and has no `tomllib`; record this as the known baseline defect. `tests/functional.sh` has the same latent dependency. Task 0A fixes this test-harness prerequisite before any feature test is added.

- [ ] **Step 3: Keep the approved design and plan uncommitted for deployment review**

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
git status --short --branch
```

Expected: both documentation files remain visible as intentional uncommitted work on `feat/dark-glass`. Do not stage, commit, or push until the user reports that local deployment succeeded.

---

### Task 0A: Make parser-based tests portable across macOS Python versions

**Files:**
- Create: `tests/test-env.sh`
- Modify: `tests/smoke.sh`
- Modify: `tests/functional.sh`

- [ ] **Step 1: Add the shared interpreter resolver**

Create `tests/test-env.sh` with:

```bash
#!/usr/bin/env bash

find_python_with_tomllib() {
  local candidate

  if [[ -n "${PYTHON_BIN:-}" ]]; then
    if command -v "$PYTHON_BIN" >/dev/null 2>&1 && "$PYTHON_BIN" -c 'import tomllib' >/dev/null 2>&1; then
      command -v "$PYTHON_BIN"
      return 0
    fi
    printf 'PYTHON_BIN does not provide tomllib: %s\n' "$PYTHON_BIN" >&2
    return 1
  fi

  for candidate in python3.13 python3.12 python3.11 python3; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import tomllib' >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done

  printf '%s\n' 'Python 3.11+ with tomllib is required to run the test suite.' >&2
  return 1
}
```

- [ ] **Step 2: Use the resolver in both parser-based test scripts**

After each script computes `ROOT`, add:

```bash
# shellcheck source=tests/test-env.sh
source "$ROOT/tests/test-env.sh"
TEST_PYTHON="$(find_python_with_tomllib)"
```

Replace every inline `python3 - ...` TOML-parsing invocation in `tests/smoke.sh` and `tests/functional.sh` with `"$TEST_PYTHON" - ...`. Keep production scripts and the Terminal-profile generator on generic `python3` because `plistlib` is available in macOS Python 3.9.

- [ ] **Step 3: Verify the baseline tests now run**

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
bash tests/smoke.sh
bash tests/functional.sh
PYTHON_BIN=/usr/bin/python3 bash tests/smoke.sh 2>&1 | grep -F 'does not provide tomllib'
```

Expected: the first two commands pass with the discovered Python 3.11 or 3.12; the explicit Python 3.9 command fails with the actionable message.

- [ ] **Step 4: Review without committing**

Run `git diff --check` and leave the helper plus both test changes uncommitted for the user's deployment gate.

---

### Task 1: Add and apply the transparent Herdr preset

**Files:**
- Create: `theme/dark-glass.toml`
- Create: `scripts/apply-dark-glass.sh`
- Modify: `scripts/apply-preset.sh`
- Modify: `herdr-plugin.toml`
- Modify: `tests/smoke.sh`
- Modify: `tests/functional.sh`

- [ ] **Step 1: Extend the smoke test with a failing Dark Glass preset contract**

In the existing Python block in `tests/smoke.sh`, extend the action assertion to include `apply-dark-glass`, load `theme/dark-glass.toml`, and add these exact assertions:

```python
assert manifest["version"] == "1.2.0"
actions = {action["id"]: action for action in manifest["actions"]}
assert set(actions) == {
    "apply",
    "apply-island",
    "apply-dark-glass",
    "restore",
    "open-window",
    "open-island-window",
    "status",
}
assert actions["apply-dark-glass"]["command"] == ["bash", "scripts/apply-dark-glass.sh"]

with dark_path.open("rb") as handle:
    dark = tomllib.load(handle)

assert dark["theme"]["name"] == "catppuccin"
assert dark["theme"]["auto_switch"] is False
custom = dark["theme"]["custom"]
assert custom["panel_bg"] == "transparent"
assert custom["sidebar_bg"] == "transparent"
assert custom["active_row_bg"] == "#29332D"
assert custom["selection_bg"] == "#3A463E"
assert custom["text"] == "#F5F3ED"
assert custom["subtext0"] == "#B9BEB9"
assert custom["overlay0"] == "#87918C"
assert custom["accent"] == "#B7D6A3"
assert custom["blue"] == "#8BD5FF"
assert custom["mauve"] == "#C4A7E7"
assert custom["green"] == "#A6D189"
assert custom["yellow"] == "#E5C890"
assert custom["red"] == "#E78284"
```

Change the inline Python invocation and argument unpacking to:

```bash
python3 - "$ROOT/herdr-plugin.toml" "$ROOT/theme/social-glass.toml" \
  "$ROOT/theme/island-glass.toml" "$ROOT/theme/dark-glass.toml" <<'PY'
```

```python
manifest_path, social_path, island_path, dark_path = map(pathlib.Path, sys.argv[1:])
```

Keep every existing Social Glass and Island Glass assertion. Extend the executable-file loop with `scripts/apply-dark-glass.sh`.

- [ ] **Step 2: Add a failing functional apply assertion**

In `tests/functional.sh`, immediately after the existing Island Glass TOML assertions (before the reload-failure case), add:

```bash
bash "$ROOT/scripts/apply-dark-glass.sh"
python3 - "$HERDR_CONFIG_PATH" "$TITLE" <<'PY'
import pathlib
import sys
import tomllib

with pathlib.Path(sys.argv[1]).open("rb") as handle:
    config = tomllib.load(handle)

assert config["ui"]["window_title"] == sys.argv[2]
assert config["theme"]["name"] == "catppuccin"
assert config["theme"]["custom"]["panel_bg"] == "transparent"
assert config["theme"]["custom"]["sidebar_bg"] == "transparent"
assert config["theme"]["custom"]["accent"] == "#B7D6A3"
PY
```

After the Dark Glass assertion, extend the final temporary-file leak check to include `-name '*.dark-glass.*'` alongside the existing Social and Island patterns.

- [ ] **Step 3: Run the focused tests and verify the red state**

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
bash tests/smoke.sh
bash tests/functional.sh
```

Expected: smoke fails because `apply-dark-glass` and `theme/dark-glass.toml` do not exist; functional fails because `scripts/apply-dark-glass.sh` does not exist.

- [ ] **Step 4: Create the complete Dark Glass Herdr preset**

Create `theme/dark-glass.toml` with:

```toml
# Herdr Dark Glass — dark transparent native preset
onboarding = false

[theme]
name = "catppuccin"
auto_switch = false

[theme.custom]
sidebar_bg = "transparent"
active_row_bg = "#29332D"
selection_bg = "#3A463E"
panel_bg = "transparent"
surface_dim = "#151E1A"
surface0 = "#202A25"
surface1 = "#29332D"
overlay0 = "#87918C"
overlay1 = "#A2AAA5"
text = "#F5F3ED"
subtext0 = "#B9BEB9"
accent = "#B7D6A3"
blue = "#8BD5FF"
mauve = "#C4A7E7"
green = "#A6D189"
yellow = "#E5C890"
peach = "#E5C890"
red = "#E78284"

[terminal]
new_cwd = "follow"

[ui]
# Generic public default; optional local personalization is injected as data.
window_title = "Herdr Dark Glass"
sidebar_width = 32
sidebar_min_width = 28
sidebar_max_width = 36
sidebar_start_collapsed = false
sidebar_collapsed_mode = "hidden"
mouse_capture = true
copy_on_select = true
redraw_on_focus_gained = false
confirm_close = true
pane_borders = true
pane_scrollbars = false
pane_gaps = true
show_agent_labels_on_pane_borders = true
hide_tab_bar_when_single_tab = false
tab_bar_position = "top"
tab_bar_right = [
  { type = "text", text = "DARK GLASS" },
  { type = "datetime", format = "%m/%d %H:%M" },
]
tab_bar_right_separator = " · "
agent_panel_sort = "spaces"
status_indicators = "symbols"
accent = "#B7D6A3"

[ui.sidebar.agents]
row_gap = 1
rows = [
  [
    { token = "state_icon" },
    { token = "agent", fg = "#F5F3ED", bold = true },
    { token = "state_text", fg = "#8BD5FF", bold = true },
  ],
  [
    { token = "workspace", fg = "#A6D189", bold = true },
    { token = "tab", fg = "#C4A7E7" },
  ],
]

[ui.sidebar.spaces]
row_gap = 1
rows = [
  [
    { token = "state_icon" },
    { token = "workspace", fg = "#F5F3ED", bold = true },
  ],
  [
    { token = "branch", fg = "#8BD5FF" },
    { token = "git_status", fg = "#E5C890", bold = true },
  ],
]

[ui.toast]
delivery = "off"

[ui.sound]
enabled = false
```

This deliberately keeps only active rows, selections, and small state surfaces opaque. Do not add a solid `panel_bg` or `sidebar_bg`; use only Herdr keys already exercised by the two existing presets so `herdr config check` validates the result.

- [ ] **Step 5: Create the apply wrapper**

Create executable `scripts/apply-dark-glass.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
exec bash "$ROOT/scripts/apply-preset.sh" dark-glass
```

Run:

```bash
chmod +x scripts/apply-dark-glass.sh
```

- [ ] **Step 6: Generalize preset resolution and base-theme validation**

In `scripts/apply-preset.sh`, update both usage lines to list `dark-glass`, then replace `resolve_preset()` with:

```bash
usage() {
  echo 'usage: apply-preset.sh <social-glass|island-glass|dark-glass>' >&2
  echo '       apply-preset.sh --render <social-glass|island-glass|dark-glass> <output>' >&2
  exit 2
}

resolve_preset() {
  case "$1" in
    social-glass)
      PRESET="$ROOT/theme/social-glass.toml"
      DISPLAY_NAME="Social Glass"
      EXPECTED_BASE_THEME="catppuccin-latte"
      ;;
    island-glass)
      PRESET="$ROOT/theme/island-glass.toml"
      DISPLAY_NAME="Island Glass"
      EXPECTED_BASE_THEME="catppuccin-latte"
      ;;
    dark-glass)
      PRESET="$ROOT/theme/dark-glass.toml"
      DISPLAY_NAME="Dark Glass"
      EXPECTED_BASE_THEME="catppuccin"
      ;;
    *) usage ;;
  esac
}
```

Inside `render_preset()`, replace the hard-coded `catppuccin-latte` guard with:

```bash
[[ -s "$PRESET" ]] || { echo "$DISPLAY_NAME preset is missing: $PRESET" >&2; exit 1; }
grep -Fq "name = \"$EXPECTED_BASE_THEME\"" "$PRESET" || {
  echo "$DISPLAY_NAME preset has an invalid base theme: $PRESET" >&2
  exit 1
}
```

Leave title injection, staging, config check, baseline capture, atomic `mv`, reload, and rollback unchanged.

- [ ] **Step 7: Register the apply action and bump the plugin version**

In `herdr-plugin.toml`, set:

```toml
version = "1.2.0"
description = "Three screenshot-friendly workspace themes and macOS Terminal launchers for Herdr, including transparent Dark Glass integrations."
```

Add immediately after `apply-island`:

```toml
[[actions]]
id = "apply-dark-glass"
title = "Apply Dark Glass theme"
command = ["bash", "scripts/apply-dark-glass.sh"]
```

- [ ] **Step 8: Run tests and verify the green state**

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
bash tests/smoke.sh
bash tests/functional.sh
```

Expected: both exit `0`; existing Social and Island assertions continue to pass; the mock reload log includes a successful Dark Glass activation.

- [ ] **Step 9: Review the Herdr preset slice without committing**

Run `git diff --check` and `git status --short`. Keep the Herdr preset, manifest, scripts, and tests uncommitted for the user's deployment gate.

---

### Task 2: Generate and verify the dedicated Terminal profile

**Files:**
- Create: `tools/build-terminal-profile.py`
- Create: `profiles/Herdr Dark Glass.terminal`
- Create: `tests/dark-glass-assets.py`
- Modify: `tests/smoke.sh`

- [ ] **Step 1: Write a failing deterministic profile test**

Create `tests/dark-glass-assets.py` with the following initial content:

```python
#!/usr/bin/env python3
from __future__ import annotations

import math
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "profiles/Herdr Dark Glass.terminal"
GENERATOR = ROOT / "tools/build-terminal-profile.py"


def archived_components(value: bytes) -> tuple[float, ...]:
    archive = plistlib.loads(value)
    color = archive["$objects"][1]
    raw = color.get("NSRGB", color.get("NSComponents"))
    if not isinstance(raw, bytes):
        raise AssertionError("archived color has no byte component payload")
    return tuple(float(item) for item in raw.rstrip(b"\0").split())


assert GENERATOR.is_file()
assert PROFILE.is_file()

with PROFILE.open("rb") as handle:
    profile = plistlib.load(handle)

assert profile["name"] == "Herdr Dark Glass"
assert profile["type"] == "Window Settings"
assert math.isclose(profile["BackgroundBlur"], 0.24, abs_tol=1e-9)
assert math.isclose(profile["BackgroundBlurInactive"], 0.24, abs_tol=1e-9)
assert profile["BackgroundSettingsForInactiveWindows"] is False
assert profile["columnCount"] == 120
assert profile["rowCount"] == 30

font = plistlib.loads(profile["Font"])
assert font["$objects"][2] == "SFMonoTerminal-Regular"
assert math.isclose(font["$objects"][1]["NSSize"], 12.0, abs_tol=1e-9)

background = archived_components(profile["BackgroundColor"])
expected_background = (8 / 255, 14 / 255, 20 / 255, 0.46)
assert len(background) == 4
for actual, expected in zip(background, expected_background):
    assert math.isclose(actual, expected, abs_tol=1e-9)

assert archived_components(profile["TextColor"]) == tuple(
    channel / 255 for channel in (245, 243, 237)
)
assert archived_components(profile["TextBoldColor"]) == (1.0, 1.0, 1.0)
assert archived_components(profile["CursorColor"]) == tuple(
    channel / 255 for channel in (183, 214, 163)
)
assert archived_components(profile["SelectionColor"]) == tuple(
    channel / 255 for channel in (41, 51, 45)
)

with tempfile.TemporaryDirectory() as directory:
    rebuilt = Path(directory) / PROFILE.name
    subprocess.run([sys.executable, str(GENERATOR), str(rebuilt)], check=True)
    assert rebuilt.read_bytes() == PROFILE.read_bytes()

print("dark glass Terminal profile asset: ok")
```

- [ ] **Step 2: Invoke the asset test from smoke and verify it fails**

Add this command near the end of `tests/smoke.sh`, before the final success message:

```bash
python3 "$ROOT/tests/dark-glass-assets.py"
```

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
python3 tests/dark-glass-assets.py
```

Expected: failure at `assert GENERATOR.is_file()`.

- [ ] **Step 3: Create the deterministic profile generator**

Create executable `tools/build-terminal-profile.py`:

```python
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import plistlib
from pathlib import Path

PROFILE_NAME = "Herdr Dark Glass"


def hex_components(value: str) -> tuple[float, float, float]:
    value = value.removeprefix("#")
    if len(value) != 6:
        raise ValueError(f"expected six-digit RGB color, got {value!r}")
    return tuple(int(value[index : index + 2], 16) / 255 for index in (0, 2, 4))


def archived_color(value: str, alpha: float = 1.0) -> bytes:
    components = (*hex_components(value), alpha)
    count = 4 if alpha != 1.0 else 3
    payload = " ".join(format(component, ".17g") for component in components[:count])
    archive = {
        "$version": 100000,
        "$archiver": "NSKeyedArchiver",
        "$top": {"root": plistlib.UID(1)},
        "$objects": [
            "$null",
            {
                "NSRGB": (payload + "\0").encode("ascii"),
                "NSColorSpace": 1,
                "$class": plistlib.UID(2),
            },
            {
                "$classname": "NSColor",
                "$classes": ["NSColor", "NSObject"],
            },
        ],
    }
    return plistlib.dumps(archive, fmt=plistlib.FMT_BINARY, sort_keys=True)


def archived_font(name: str = "SFMonoTerminal-Regular", size: float = 12.0) -> bytes:
    archive = {
        "$version": 100000,
        "$archiver": "NSKeyedArchiver",
        "$top": {"root": plistlib.UID(1)},
        "$objects": [
            "$null",
            {
                "NSSize": size,
                "NSfFlags": 16,
                "NSName": plistlib.UID(2),
                "$class": plistlib.UID(3),
            },
            name,
            {
                "$classname": "NSFont",
                "$classes": ["NSFont", "NSObject"],
            },
        ],
    }
    return plistlib.dumps(archive, fmt=plistlib.FMT_BINARY, sort_keys=True)


def build_profile() -> dict[str, object]:
    colors = {
        "ANSIBlackColor": "#080E14",
        "ANSIRedColor": "#E78284",
        "ANSIGreenColor": "#A6D189",
        "ANSIYellowColor": "#E5C890",
        "ANSIBlueColor": "#8BD5FF",
        "ANSIMagentaColor": "#C4A7E7",
        "ANSICyanColor": "#83C5BE",
        "ANSIWhiteColor": "#D5D8D4",
        "ANSIBrightBlackColor": "#48524D",
        "ANSIBrightRedColor": "#E78284",
        "ANSIBrightGreenColor": "#B7D6A3",
        "ANSIBrightYellowColor": "#E5C890",
        "ANSIBrightBlueColor": "#8BD5FF",
        "ANSIBrightMagentaColor": "#C4A7E7",
        "ANSIBrightCyanColor": "#8BD5FF",
        "ANSIBrightWhiteColor": "#FFFFFF",
    }
    profile: dict[str, object] = {
        "name": PROFILE_NAME,
        "type": "Window Settings",
        "ProfileCurrentVersion": 2.09,
        "BackgroundColor": archived_color("#080E14", 0.46),
        "BackgroundBlur": 0.24,
        "BackgroundBlurInactive": 0.24,
        "BackgroundSettingsForInactiveWindows": False,
        "TextColor": archived_color("#F5F3ED"),
        "TextBoldColor": archived_color("#FFFFFF"),
        "CursorColor": archived_color("#B7D6A3"),
        "SelectionColor": archived_color("#29332D"),
        "Font": archived_font(),
        "FontAntialias": True,
        "FontHeightSpacing": 1.0,
        "FontWidthSpacing": 1,
        "columnCount": 120,
        "rowCount": 30,
        "useOptionAsMetaKey": True,
    }
    profile.update({key: archived_color(value) for key, value in colors.items()})
    return profile


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the Herdr Dark Glass Terminal profile")
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "profiles/Herdr Dark Glass.terminal",
    )
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("wb") as handle:
        plistlib.dump(build_profile(), handle, fmt=plistlib.FMT_XML, sort_keys=True)


if __name__ == "__main__":
    main()
```

Run:

```bash
chmod +x tools/build-terminal-profile.py
```

The nested `NSColor` and `NSFont` values use the same `NSKeyedArchiver` shape observed in native Terminal profiles. Do not use `defaults write` or modify `com.apple.Terminal`.

- [ ] **Step 4: Generate the reproducible profile asset**

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
python3 tools/build-terminal-profile.py
```

Expected: `profiles/Herdr Dark Glass.terminal` is created as an XML property list containing archived binary color/font data.

- [ ] **Step 5: Run the focused and full smoke tests**

Run:

```bash
python3 tests/dark-glass-assets.py
bash tests/smoke.sh
```

Expected:

```text
dark glass Terminal profile asset: ok
```

and smoke exits `0`. The profile test proves RGB `#080E14`, alpha `0.46`, blur `0.24`, profile name, dimensions, key foreground colors, and deterministic regeneration.

- [ ] **Step 6: Review the generated profile slice without committing**

Run `git diff --check` and leave the generator, profile, and asset test uncommitted for the user's deployment gate.

---

### Task 3: Add the OpenCode theme and safe setup action

**Files:**
- Create: `integrations/opencode/herdr-dark-glass.json`
- Create: `scripts/setup-dark-glass.sh`
- Create: `tests/dark-glass-setup.sh`
- Modify: `tests/dark-glass-assets.py`
- Modify: `tests/smoke.sh`
- Modify: `herdr-plugin.toml`

- [ ] **Step 1: Add failing OpenCode schema assertions**

Append to `tests/dark-glass-assets.py` before its final print:

```python
import json

OPENCODE_THEME = ROOT / "integrations/opencode/herdr-dark-glass.json"
with OPENCODE_THEME.open(encoding="utf-8") as handle:
    opencode = json.load(handle)

theme = opencode["theme"]
required_keys = {
    "primary", "secondary", "accent", "error", "warning", "success", "info",
    "text", "textMuted", "background", "backgroundPanel", "backgroundElement",
    "border", "borderActive", "borderSubtle",
    "diffAdded", "diffRemoved", "diffContext", "diffHunkHeader",
    "diffHighlightAdded", "diffHighlightRemoved", "diffAddedBg", "diffRemovedBg",
    "diffContextBg", "diffLineNumber", "diffAddedLineNumberBg",
    "diffRemovedLineNumberBg", "markdownText", "markdownHeading", "markdownLink",
    "markdownLinkText", "markdownCode", "markdownBlockQuote", "markdownEmph",
    "markdownStrong", "markdownHorizontalRule", "markdownListItem", "markdownListEnumeration",
    "markdownImage", "markdownImageText", "markdownCodeBlock", "syntaxComment",
    "syntaxKeyword", "syntaxFunction", "syntaxVariable", "syntaxString", "syntaxNumber",
    "syntaxType", "syntaxOperator", "syntaxPunctuation",
}
assert required_keys <= theme.keys()
assert theme["primary"] == "#B7D6A3"
assert theme["accent"] == "#B7D6A3"
assert theme["secondary"] == "#8BD5FF"
assert theme["info"] == "#8BD5FF"
assert theme["text"] == "#F5F3ED"
assert theme["textMuted"] == "#B9BEB9"
assert theme["border"] == "#6C7770"
assert theme["borderActive"] == "#B7D6A3"
assert theme["borderSubtle"] == "#48524D"
assert theme["success"] == "#A6D189"
assert theme["warning"] == "#E5C890"
assert theme["error"] == "#E78284"
for key in (
    "background", "backgroundPanel", "backgroundElement", "diffAddedBg",
    "diffRemovedBg", "diffContextBg", "diffAddedLineNumberBg",
    "diffRemovedLineNumberBg",
):
    assert theme[key] == "none"
```

Move the existing `print(...)` to the end and change it to:

```python
print("dark glass generated and integration assets: ok")
```

- [ ] **Step 2: Write the failing isolated setup test**

Create executable `tests/dark-glass-setup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export HERDR_PLUGIN_ROOT="$ROOT"
export HERDR_PLUGIN_STATE_DIR="$TMP/state"
export OPENCODE_CONFIG_DIR="$TMP/opencode"
export PATH="$TMP/bin:$PATH"
mkdir -p "$HOME" "$TMP/bin"

cat > "$TMP/bin/osascript" <<'SH'
#!/usr/bin/env bash
cat > "${MOCK_OSASCRIPT_STDIN:?}"
printf '%s\n' "$*" >> "${MOCK_OSASCRIPT_ARGS:?}"
[[ "${MOCK_TERMINAL_PROFILE_STATE:-missing}" == "present" ]]
SH

cat > "$TMP/bin/open" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${MOCK_OPEN_LOG:?}"
SH
chmod +x "$TMP/bin/osascript" "$TMP/bin/open"

export MOCK_OSASCRIPT_STDIN="$TMP/osascript.stdin"
export MOCK_OSASCRIPT_ARGS="$TMP/osascript.args"
export MOCK_OPEN_LOG="$TMP/open.log"
: > "$MOCK_OSASCRIPT_ARGS"
: > "$MOCK_OPEN_LOG"

if HERDR_PLUGIN_ROOT="$TMP/missing-root" MOCK_TERMINAL_PROFILE_STATE=present \
  bash "$ROOT/scripts/setup-dark-glass.sh" > "$TMP/missing-source.out" 2> "$TMP/missing-source.err"; then
  echo 'setup unexpectedly accepted missing bundled files' >&2
  exit 1
fi
grep -Fq 'Required Dark Glass file is missing' "$TMP/missing-source.err"

MOCK_TERMINAL_PROFILE_STATE=missing bash "$ROOT/scripts/setup-dark-glass.sh"
cmp "$ROOT/integrations/opencode/herdr-dark-glass.json" \
  "$OPENCODE_CONFIG_DIR/themes/herdr-dark-glass.json"
grep -Fq "$ROOT/profiles/Herdr Dark Glass.terminal" "$MOCK_OPEN_LOG"

before_count="$(find "$HERDR_PLUGIN_STATE_DIR/backups" -type f 2>/dev/null | wc -l | tr -d ' ')"
MOCK_TERMINAL_PROFILE_STATE=present bash "$ROOT/scripts/setup-dark-glass.sh"
after_count="$(find "$HERDR_PLUGIN_STATE_DIR/backups" -type f 2>/dev/null | wc -l | tr -d ' ')"
[[ "$before_count" == "$after_count" ]]
[[ "$(wc -l < "$MOCK_OPEN_LOG" | tr -d ' ')" == "1" ]]

printf '{"name":"local-theme"}\n' > "$OPENCODE_CONFIG_DIR/themes/herdr-dark-glass.json"
MOCK_TERMINAL_PROFILE_STATE=present bash "$ROOT/scripts/setup-dark-glass.sh"
cmp "$ROOT/integrations/opencode/herdr-dark-glass.json" \
  "$OPENCODE_CONFIG_DIR/themes/herdr-dark-glass.json"
backup=""
for candidate in "$HERDR_PLUGIN_STATE_DIR"/backups/opencode-theme-*.json; do
  [[ -f "$candidate" ]] || continue
  backup="$candidate"
  break
done
[[ -n "$backup" ]]
grep -Fq 'local-theme' "$backup"

cat > "$TMP/bin/failing-install" <<'SH'
#!/usr/bin/env bash
last=""
for argument in "$@"; do
  last="$argument"
done
if [[ "$last" == *.tmp.* ]]; then
  exit 73
fi
exec /usr/bin/install "$@"
SH
chmod +x "$TMP/bin/failing-install"
printf '{"name":"must-survive"}\n' > "$OPENCODE_CONFIG_DIR/themes/herdr-dark-glass.json"
cp "$OPENCODE_CONFIG_DIR/themes/herdr-dark-glass.json" "$TMP/must-survive.json"
if INSTALL_BIN_PATH="$TMP/bin/failing-install" MOCK_TERMINAL_PROFILE_STATE=present \
  bash "$ROOT/scripts/setup-dark-glass.sh" > "$TMP/copy-failure.out" 2> "$TMP/copy-failure.err"; then
  echo 'setup unexpectedly succeeded when the staged copy failed' >&2
  exit 1
fi
cmp "$TMP/must-survive.json" "$OPENCODE_CONFIG_DIR/themes/herdr-dark-glass.json"

printf 'dark glass setup tests: ok\n'
```

Run:

```bash
chmod +x tests/dark-glass-setup.sh
python3 tests/dark-glass-assets.py
bash tests/dark-glass-setup.sh
```

Expected: the Python test fails because the OpenCode theme is absent; the shell test fails because `scripts/setup-dark-glass.sh` is absent. Before implementing, extend the setup test with mock `opencode`, `claude`, `codex`, and `grok` executables that append to one log, then assert the log remains empty after every setup case; setup prints instructions but must never launch or configure an optional CLI.

- [ ] **Step 3: Create the complete transparent OpenCode theme**

Create `integrations/opencode/herdr-dark-glass.json`:

```json
{
  "$schema": "https://opencode.ai/theme.json",
  "defs": {
    "accent": "#B7D6A3",
    "blue": "#8BD5FF",
    "green": "#A6D189",
    "yellow": "#E5C890",
    "red": "#E78284",
    "purple": "#C4A7E7",
    "text": "#F5F3ED",
    "muted": "#B9BEB9",
    "overlay": "#87918C",
    "border": "#6C7770",
    "subtle": "#48524D"
  },
  "theme": {
    "primary": "accent",
    "secondary": "blue",
    "accent": "accent",
    "error": "red",
    "warning": "yellow",
    "success": "green",
    "info": "blue",
    "text": "text",
    "textMuted": "muted",
    "background": "none",
    "backgroundPanel": "none",
    "backgroundElement": "none",
    "border": "border",
    "borderActive": "accent",
    "borderSubtle": "subtle",
    "diffAdded": "green",
    "diffRemoved": "red",
    "diffContext": "muted",
    "diffHunkHeader": "blue",
    "diffHighlightAdded": "green",
    "diffHighlightRemoved": "red",
    "diffAddedBg": "none",
    "diffRemovedBg": "none",
    "diffContextBg": "none",
    "diffLineNumber": "overlay",
    "diffAddedLineNumberBg": "none",
    "diffRemovedLineNumberBg": "none",
    "markdownText": "text",
    "markdownHeading": "accent",
    "markdownLink": "blue",
    "markdownLinkText": "blue",
    "markdownCode": "green",
    "markdownBlockQuote": "muted",
    "markdownEmph": "purple",
    "markdownStrong": "text",
    "markdownHorizontalRule": "border",
    "markdownListItem": "accent",
    "markdownListEnumeration": "blue",
    "markdownImage": "purple",
    "markdownImageText": "muted",
    "markdownCodeBlock": "text",
    "syntaxComment": "overlay",
    "syntaxKeyword": "purple",
    "syntaxFunction": "blue",
    "syntaxVariable": "text",
    "syntaxString": "green",
    "syntaxNumber": "yellow",
    "syntaxType": "accent",
    "syntaxOperator": "blue",
    "syntaxPunctuation": "muted"
  }
}
```

OpenCode theme references must use the `defs` names as shown. The asset test should resolve definition references before comparing fixed hex values. Replace direct comparisons such as `theme["primary"] == "#B7D6A3"` in Step 1 with this helper and assertions:

```python
def resolved(value: str) -> str:
    return opencode.get("defs", {}).get(value, value)

assert resolved(theme["primary"]) == "#B7D6A3"
assert resolved(theme["accent"]) == "#B7D6A3"
assert resolved(theme["secondary"]) == "#8BD5FF"
assert resolved(theme["info"]) == "#8BD5FF"
assert resolved(theme["text"]) == "#F5F3ED"
assert resolved(theme["textMuted"]) == "#B9BEB9"
assert resolved(theme["border"]) == "#6C7770"
assert resolved(theme["borderActive"]) == "#B7D6A3"
assert resolved(theme["borderSubtle"]) == "#48524D"
assert resolved(theme["success"]) == "#A6D189"
assert resolved(theme["warning"]) == "#E5C890"
assert resolved(theme["error"]) == "#E78284"
```

- [ ] **Step 4: Create the setup action**

Create executable `scripts/setup-dark-glass.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugin-state/linyu.social-glass}"
OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"
OSASCRIPT="${OSASCRIPT_BIN_PATH:-osascript}"
OPEN="${OPEN_BIN_PATH:-open}"
INSTALL="${INSTALL_BIN_PATH:-install}"
PROFILE_NAME="${HERDR_DARK_GLASS_TERMINAL_PROFILE:-Herdr Dark Glass}"
PROFILE_FILE="$ROOT/profiles/Herdr Dark Glass.terminal"
SOURCE_THEME="$ROOT/integrations/opencode/herdr-dark-glass.json"
DEST_THEME="$OPENCODE_CONFIG_DIR/themes/herdr-dark-glass.json"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
TMP_THEME=""

cleanup() {
  if [[ -n "$TMP_THEME" && -f "$TMP_THEME" ]]; then
    rm -f "$TMP_THEME"
  fi
}
trap cleanup EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Dark Glass setup requires macOS Terminal." >&2
  exit 1
fi
for source in "$PROFILE_FILE" "$SOURCE_THEME"; do
  if [[ ! -f "$source" ]]; then
    printf 'Required Dark Glass file is missing: %s\n' "$source" >&2
    exit 1
  fi
done
for tool in "$OSASCRIPT" "$OPEN" "$INSTALL"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Required Dark Glass setup command is unavailable: %s\n' "$tool" >&2
    exit 1
  fi
done

if ! mkdir -p "$OPENCODE_CONFIG_DIR/themes" "$STATE_DIR/backups"; then
  printf 'Unable to create the OpenCode theme or plugin backup directory.\n' >&2
  exit 1
fi
if [[ -f "$DEST_THEME" ]] && cmp -s "$SOURCE_THEME" "$DEST_THEME"; then
  printf 'OpenCode theme is already current: %s\n' "$DEST_THEME"
else
  if [[ -f "$DEST_THEME" ]]; then
    BACKUP="$STATE_DIR/backups/opencode-theme-$STAMP.json"
    "$INSTALL" -m 600 "$DEST_THEME" "$BACKUP"
    printf 'Existing OpenCode theme backed up to %s\n' "$BACKUP"
  fi
  TMP_THEME="$DEST_THEME.tmp.$$"
  "$INSTALL" -m 600 "$SOURCE_THEME" "$TMP_THEME"
  mv "$TMP_THEME" "$DEST_THEME"
  TMP_THEME=""
  printf 'OpenCode theme installed at %s\n' "$DEST_THEME"
fi

if "$OSASCRIPT" - "$PROFILE_NAME" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  set profileName to item 1 of argv
  tell application "Terminal"
    settings set profileName
  end tell
end run
APPLESCRIPT
then
  printf 'Terminal profile is available: %s\n' "$PROFILE_NAME"
else
  if ! "$OPEN" "$PROFILE_FILE"; then
    printf 'Unable to open the Terminal profile for import: %s\n' "$PROFILE_FILE" >&2
    exit 1
  fi
  printf 'Opened %s for explicit Terminal import. Complete the import, then run status.\n' "$PROFILE_FILE"
fi

printf '%s\n' 'OpenCode: run /themes, select herdr-dark-glass, and lock dark mode.'
printf '%s\n' 'Claude Code: run /theme and select dark-ansi.'
printf '%s\n' 'Codex CLI: run codex normally; tui.theme controls syntax only.'
printf '%s\n' 'Grok Build: run /theme transparent, or use GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok.'
```

Run:

```bash
chmod +x scripts/setup-dark-glass.sh
```

The script intentionally does not write Terminal preferences, OpenCode `tui.json`/`tui.jsonc`, plugin lists, or unrelated state.

- [ ] **Step 5: Register setup and include its tests in smoke**

Add to `herdr-plugin.toml`:

```toml
[[actions]]
id = "setup-dark-glass"
title = "Set up Dark Glass integrations"
command = ["bash", "scripts/setup-dark-glass.sh"]
```

Extend the exact `set(actions)` assertion in `tests/smoke.sh` with `"setup-dark-glass"`, assert `actions["setup-dark-glass"]["command"] == ["bash", "scripts/setup-dark-glass.sh"]`, and add:

```bash
bash "$ROOT/tests/dark-glass-setup.sh"
```

near the final smoke success output.

- [ ] **Step 6: Run setup and asset tests**

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
python3 tests/dark-glass-assets.py
bash tests/dark-glass-setup.sh
bash tests/smoke.sh
```

The plugin and this test target macOS, so the production platform guard runs normally; do not add a test-only platform bypass. Expected output includes:

```text
dark glass generated and integration assets: ok
dark glass setup tests: ok
```

and smoke exits `0`. Verify setup tests prove first install, identical no-op, differing-file backup, failed staged-copy preservation, missing-profile import, and existing-profile no duplicate import.

- [ ] **Step 7: Review the setup slice without committing**

Run `git diff --check` and leave the OpenCode asset, setup script, manifest change, and tests uncommitted for the user's deployment gate.

---

### Task 4: Launch a dedicated Dark Glass Terminal window

**Files:**
- Create: `scripts/open-dark-glass-window.sh`
- Create: `tests/dark-glass-launcher.sh`
- Modify: `herdr-plugin.toml`
- Modify: `tests/smoke.sh`

- [ ] **Step 1: Write the failing launcher test**

Create executable `tests/dark-glass-launcher.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
export PATH="$TMP/bin:$PATH"
export HERDR_PLUGIN_ROOT="$ROOT"
export HERDR_BIN_PATH="/opt/mock/herdr"
export MOCK_OSASCRIPT_LOG="$TMP/osascript.log"
export MOCK_OSASCRIPT_BODY_DIR="$TMP/osascript-body"
mkdir -p "$MOCK_OSASCRIPT_BODY_DIR"

cat > "$TMP/bin/osascript" <<'SH'
#!/usr/bin/env bash
count_file="${MOCK_OSASCRIPT_LOG}.count"
count=0
[[ -f "$count_file" ]] && count="$(cat "$count_file")"
count=$((count + 1))
printf '%s' "$count" > "$count_file"
printf '%s\t%s\t%s\n' "$count" "$#" "$*" >> "$MOCK_OSASCRIPT_LOG"
cat > "$MOCK_OSASCRIPT_BODY_DIR/$count.applescript"
if [[ "$count" == "1" && "${MOCK_TERMINAL_PROFILE_STATE:-missing}" != "present" ]]; then
  exit 1
fi
SH
chmod +x "$TMP/bin/osascript"

set +e
missing_output="$(MOCK_TERMINAL_PROFILE_STATE=missing bash "$ROOT/scripts/open-dark-glass-window.sh" 2>&1)"
missing_status=$?
set -e
[[ "$missing_status" -ne 0 ]]
grep -Fq 'setup-dark-glass' <<< "$missing_output"
[[ "$(cat "$MOCK_OSASCRIPT_LOG.count")" == "1" ]]

: > "$MOCK_OSASCRIPT_LOG"
rm -f "$MOCK_OSASCRIPT_LOG.count"
MOCK_TERMINAL_PROFILE_STATE=present \
HERDR_DARK_GLASS_TERMINAL_PROFILE="Herdr Dark Glass Test" \
HERDR_DARK_GLASS_WINDOW_TITLE="Dark Glass Test Window" \
bash "$ROOT/scripts/open-dark-glass-window.sh"

[[ "$(cat "$MOCK_OSASCRIPT_LOG.count")" == "2" ]]
grep -Fq $'1\t2\t- Herdr Dark Glass Test' "$MOCK_OSASCRIPT_LOG"
grep -Fq $'2\t4\t- Herdr Dark Glass Test /opt/mock/herdr Dark Glass Test Window' "$MOCK_OSASCRIPT_LOG"
grep -Fq 'exec env -u HERDR_ENV -u HERDR_WORKSPACE_ID -u HERDR_TAB_ID -u HERDR_PANE_ID' \
  "$MOCK_OSASCRIPT_BODY_DIR/2.applescript"
if grep -Fq '#080E14' "$MOCK_OSASCRIPT_LOG"; then
  echo "Dark Glass launcher unexpectedly passed an OSC background color" >&2
  exit 1
fi

set +e
invalid_output="$(HERDR_DARK_GLASS_TERMINAL_PROFILE=$'bad\nprofile' \
  bash "$ROOT/scripts/open-dark-glass-window.sh" 2>&1)"
invalid_status=$?
set -e
[[ "$invalid_status" -ne 0 ]]
grep -Fq 'must be one non-empty line' <<< "$invalid_output"

printf 'dark glass launcher tests: ok\n'
```

Run:

```bash
chmod +x tests/dark-glass-launcher.sh
bash tests/dark-glass-launcher.sh
```

Expected: failure because `scripts/open-dark-glass-window.sh` does not exist.

- [ ] **Step 2: Create the launcher**

Create executable `scripts/open-dark-glass-window.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
OSASCRIPT="${OSASCRIPT_BIN_PATH:-osascript}"
PROFILE_NAME="${HERDR_DARK_GLASS_TERMINAL_PROFILE:-Herdr Dark Glass}"
WINDOW_TITLE="${HERDR_DARK_GLASS_WINDOW_TITLE:-Herdr Dark Glass}"

validate_single_line() {
  local label="$1"
  local value="$2"
  if [[ -z "$value" ]] || ! printf '%s\n' "$value" | LC_ALL=C awk '
    BEGIN { valid = 1 }
    NR > 1 || /[[:cntrl:]]/ || length($0) > 120 { valid = 0 }
    END { exit(valid && NR == 1 ? 0 : 1) }
  '; then
    printf '%s must be one non-empty line of at most 120 bytes with no control characters.\n' "$label" >&2
    exit 2
  fi
}

validate_single_line "HERDR_DARK_GLASS_TERMINAL_PROFILE" "$PROFILE_NAME"
validate_single_line "HERDR_DARK_GLASS_WINDOW_TITLE" "$WINDOW_TITLE"

if ! "$OSASCRIPT" - "$PROFILE_NAME" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  set profileName to item 1 of argv
  tell application "Terminal"
    settings set profileName
  end tell
end run
APPLESCRIPT
then
  printf 'Terminal profile "%s" is missing. Run setup-dark-glass and complete the Terminal import first.\n' "$PROFILE_NAME" >&2
  exit 1
fi

export HERDR_SOCIAL_TERMINAL_PROFILE="$PROFILE_NAME"
export HERDR_SOCIAL_WINDOW_TITLE="$WINDOW_TITLE"
exec bash "$ROOT/scripts/open-social-window.sh"
```

Run:

```bash
chmod +x scripts/open-dark-glass-window.sh
```

Calling `open-social-window.sh` with zero color arguments preserves its existing behavior and produces no OSC 10/11 prefix. Do not modify the zero-or-two-color interface.

- [ ] **Step 3: Register the launch action and run regressions**

Add to `herdr-plugin.toml`:

```toml
[[actions]]
id = "open-dark-glass-window"
title = "Open Dark Glass Terminal window"
command = ["bash", "scripts/open-dark-glass-window.sh"]
```

Extend the exact `set(actions)` assertion in `tests/smoke.sh` with `"open-dark-glass-window"`, assert `actions["open-dark-glass-window"]["command"] == ["bash", "scripts/open-dark-glass-window.sh"]`, and add:

```bash
bash "$ROOT/tests/dark-glass-launcher.sh"
```

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
bash tests/dark-glass-launcher.sh
bash tests/functional.sh
bash tests/smoke.sh
```

Expected: all exit `0`. The launcher test proves the delegated AppleScript receives four arguments, while its OSC branch requires five; therefore the Dark launch emits no OSC 10/11 sequence. The existing functional assertions for Social's zero-color path and Island's two-color OSC 10/11 path must remain unchanged and pass.

- [ ] **Step 4: Review the launcher slice without committing**

Run `git diff --check` and leave the launcher, manifest change, and tests uncommitted for the user's deployment gate.

---

### Task 5: Extend status across all three layers

**Files:**
- Create: `scripts/cli-compat-status.sh`
- Create: `tests/cli-compat-status.sh`
- Modify: `scripts/status.sh`
- Modify: `tests/functional.sh`
- Modify: `tests/smoke.sh`

- [ ] **Step 1: Add failing functional status cases**

In `tests/functional.sh`, define isolated OpenCode paths next to the existing state/config variables:

```bash
export OPENCODE_CONFIG_DIR="$TEST_ROOT/opencode-config"
export OPENCODE_STATE_DIR="$TEST_ROOT/opencode-state"
export OSASCRIPT_BIN_PATH="$TEST_ROOT/bin/osascript"
```

Extend the existing `mkdir -p` call with `"$OPENCODE_CONFIG_DIR/themes"` and `"$OPENCODE_STATE_DIR"`. After creating the mock `herdr` binary, create the test `osascript` mock before the first status call:

```bash
cat > "$OSASCRIPT_BIN_PATH" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
[[ "${MOCK_TERMINAL_PROFILE_STATE:-present}" == "present" ]]
SH
chmod +x "$OSASCRIPT_BIN_PATH"
```

After applying Dark Glass, install matching OpenCode state and assert the complete status contract:

```bash
install -m 600 "$ROOT/integrations/opencode/herdr-dark-glass.json" \
  "$OPENCODE_CONFIG_DIR/themes/herdr-dark-glass.json"
printf '{"theme":"system"}\n' > "$OPENCODE_STATE_DIR/kv.json"
wrong_selection_output="$(MOCK_TERMINAL_PROFILE_STATE=present bash "$ROOT/scripts/status.sh")"
grep -Fq 'OpenCode selection: system (not herdr-dark-glass)' <<< "$wrong_selection_output"

printf '{"theme":"herdr-dark-glass"}\n' > "$OPENCODE_STATE_DIR/kv.json"
status_output="$(MOCK_TERMINAL_PROFILE_STATE=present bash "$ROOT/scripts/status.sh")"
grep -Fq 'State:   dark-glass' <<< "$status_output"
grep -Fq 'Terminal profile: installed' <<< "$status_output"
grep -Fq 'OpenCode theme: installed and current' <<< "$status_output"
grep -Fq 'OpenCode selection: herdr-dark-glass' <<< "$status_output"

printf '{"local":true}\n' > "$OPENCODE_CONFIG_DIR/themes/herdr-dark-glass.json"
modified_output="$(MOCK_TERMINAL_PROFILE_STATE=missing bash "$ROOT/scripts/status.sh")"
grep -Fq 'Terminal profile: missing' <<< "$modified_output"
grep -Fq 'OpenCode theme: installed but locally modified' <<< "$modified_output"

rm -f "$OPENCODE_STATE_DIR/kv.json"
unknown_output="$(bash "$ROOT/scripts/status.sh")"
grep -Fq 'OpenCode selection: verify in OpenCode with /themes' <<< "$unknown_output"
```

Retain the current Social, Island, locally modified, backup, rollback, and restore assertions.

- [ ] **Step 2: Run functional tests and verify the red state**

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
bash tests/functional.sh
```

Expected: failure because the current status script neither recognizes Dark Glass nor prints Terminal/OpenCode layer state.

- [ ] **Step 3: Replace status with the complete three-layer implementation**

Replace `scripts/status.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

HERDR="${HERDR_BIN_PATH:-herdr}"
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONFIG_FILE="${HERDR_CONFIG_PATH:-$HOME/.config/herdr/config.toml}"
CONFIG_DIR="${HERDR_PLUGIN_CONFIG_DIR:-$HOME/.config/herdr/plugins/config/linyu.social-glass}"
STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-$HOME/.config/herdr/plugin-state/linyu.social-glass}"
OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"
OPENCODE_STATE_DIR="${OPENCODE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/opencode}"
OSASCRIPT="${OSASCRIPT_BIN_PATH:-osascript}"
PROFILE_NAME="${HERDR_DARK_GLASS_TERMINAL_PROFILE:-Herdr Dark Glass}"
SOURCE_OPENCODE_THEME="$ROOT/integrations/opencode/herdr-dark-glass.json"
INSTALLED_OPENCODE_THEME="$OPENCODE_CONFIG_DIR/themes/herdr-dark-glass.json"
OPENCODE_STATE_FILE="$OPENCODE_STATE_DIR/kv.json"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/social-glass-status.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

bash "$ROOT/scripts/apply-preset.sh" --render social-glass "$TMP_DIR/social.toml"
bash "$ROOT/scripts/apply-preset.sh" --render island-glass "$TMP_DIR/island.toml"
bash "$ROOT/scripts/apply-preset.sh" --render dark-glass "$TMP_DIR/dark.toml"

same_settings() {
  local left="$1"
  local right="$2"
  [[ -f "$left" ]] && cmp -s \
    <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$left") \
    <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$right")
}

selection_status() {
  if [[ ! -f "$OPENCODE_STATE_FILE" ]]; then
    printf '%s' 'verify in OpenCode with /themes'
    return
  fi
  python3 - "$OPENCODE_STATE_FILE" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        state = json.load(handle)
except (OSError, ValueError):
    print("verify in OpenCode with /themes")
    raise SystemExit

selected = state.get("theme")
if selected == "herdr-dark-glass":
    print(selected)
elif isinstance(selected, str) and selected:
    print(f"{selected} (not herdr-dark-glass)")
else:
    print("verify in OpenCode with /themes")
PY
}

printf 'Herdr Social Glass 1.2\n\n'
printf 'Herdr:  %s\n' "$("$HERDR" --version)"
printf 'Config: %s\n' "$CONFIG_FILE"
printf 'Social: %s\n' "$ROOT/theme/social-glass.toml"
printf 'Island: %s\n' "$ROOT/theme/island-glass.toml"
printf 'Dark:   %s\n' "$ROOT/theme/dark-glass.toml"
printf 'Title:  %s\n' "$CONFIG_DIR/window-title.txt"
printf 'Data:   %s\n' "$STATE_DIR"
if same_settings "$CONFIG_FILE" "$TMP_DIR/social.toml"; then
  echo 'State:   social-glass'
elif same_settings "$CONFIG_FILE" "$TMP_DIR/island.toml"; then
  echo 'State:   island-glass'
elif same_settings "$CONFIG_FILE" "$TMP_DIR/dark.toml"; then
  echo 'State:   dark-glass'
else
  echo 'State:   not applied or locally modified'
fi

if "$OSASCRIPT" - "$PROFILE_NAME" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  set profileName to item 1 of argv
  tell application "Terminal"
    settings set profileName
  end tell
end run
APPLESCRIPT
then
  printf 'Terminal profile: installed\n'
else
  printf 'Terminal profile: missing\n'
fi

if [[ ! -f "$INSTALLED_OPENCODE_THEME" ]]; then
  printf 'OpenCode theme: missing\n'
elif cmp -s "$SOURCE_OPENCODE_THEME" "$INSTALLED_OPENCODE_THEME"; then
  printf 'OpenCode theme: installed and current\n'
else
  printf 'OpenCode theme: installed but locally modified\n'
fi
printf 'OpenCode selection: %s\n' "$(selection_status)"
```

This status check is read-only. It continues to render presets through `apply-preset.sh`, so optional local title injection is compared exactly as before. It reports detectable OpenCode state but does not claim selection when state is absent or unparsable.

- [ ] **Step 3A: Write the failing CLI compatibility probe test**

Create executable `tests/cli-compat-status.sh`. In a temporary directory, put mock `opencode`, `claude`, `codex`, and `grok` commands on `PATH`; make three return their version on stdout and one on stderr. Assert the report contains:

```text
OpenCode: installed (1.18.31)
Claude Code: installed (2.1.274 (Claude Code))
Codex CLI: installed (codex-cli 0.154.0)
Grok Build: installed (grok 1.0.34 (3736acbc8658))
```

Then remove all four mocks and assert each reports `not found (optional)`. Finally create an installed `codex` mock whose `--version` exits `7` and assert `Codex CLI: installed (version unavailable)` while the helper itself still exits `0`.

Run the test and expect failure because `scripts/cli-compat-status.sh` does not exist.

- [ ] **Step 3B: Implement the read-only CLI helper**

Create executable `scripts/cli-compat-status.sh` with a `probe_cli LABEL COMMAND GUIDANCE` function. For each command:

1. Resolve it with `command -v`.
2. If absent, print `LABEL: not found (optional)` and continue.
3. Run only `EXECUTABLE --version`, capturing stdout and stderr.
4. Select the first non-empty printable line and cap it at 160 bytes.
5. If the command fails or provides no usable line, print `LABEL: installed (version unavailable)`.
6. Print the compatibility guidance only for installed commands.

The exact entries and guidance are:

```bash
probe_cli 'OpenCode' opencode 'select herdr-dark-glass with /themes'
probe_cli 'Claude Code' claude 'select dark-ansi with /theme'
probe_cli 'Codex CLI' codex 'terminal canvas compatible; no background setting required'
probe_cli 'Grok Build' grok 'select terminal / transparent with /theme'
```

The helper must not mention or access `.claude`, `.codex`, `.grok`, authentication, or configuration paths. Optional command failures must never change its final exit code.

- [ ] **Step 3C: Integrate CLI compatibility into status**

Append to `scripts/status.sh`:

```bash
printf '\nCLI compatibility:\n'
bash "$ROOT/scripts/cli-compat-status.sh"
```

Extend `tests/functional.sh` with PATH-based CLI mocks and assert the four version lines appear in the main status output. Include `bash "$ROOT/tests/cli-compat-status.sh"` in `tests/smoke.sh`.

Add a static safety assertion over production scripts that rejects `.claude/settings.json`, `.claude.json`, `.codex/config.toml`, `.grok/config.toml`, or credential/token mutations. The documentation may mention these paths; the runtime scripts must not.

- [ ] **Step 4: Ensure static checks expect all final actions**

The final `set(actions)` assertion in `tests/smoke.sh` must equal:

```python
{
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
```

Also assert `manifest["version"] == "1.2.0"` and these exact command arrays:

```python
assert actions["apply-dark-glass"]["command"] == ["bash", "scripts/apply-dark-glass.sh"]
assert actions["setup-dark-glass"]["command"] == ["bash", "scripts/setup-dark-glass.sh"]
assert actions["open-dark-glass-window"]["command"] == ["bash", "scripts/open-dark-glass-window.sh"]
```

- [ ] **Step 5: Run status, regression, and shell syntax tests**

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
bash tests/functional.sh
bash tests/smoke.sh
bash -n scripts/*.sh tests/*.sh
```

Expected: all commands exit `0`; Dark Glass status is recognized independently of Terminal/OpenCode state; all four optional CLI states are reported without becoming fatal; Social and Island status cases remain green.

- [ ] **Step 6: Review the status and CLI compatibility slice without committing**

Run `git diff --check` and leave the status helper, integration, and tests uncommitted for the user's deployment gate.

---

### Task 6: Write the Terminal, Herdr, and CLI-inside-Herdr manuals

**Files:**
- Modify: `README.md`
- Modify: `scripts/guide.sh`
- Modify: `tests/smoke.sh`

- [ ] **Step 1: Add failing documentation smoke assertions**

Add these checks to `tests/smoke.sh`:

```bash
grep -Fq 'Dark Glass' "$ROOT/README.md"
grep -Fq 'setup-dark-glass' "$ROOT/README.md"
grep -Fq 'herdr-dark-glass' "$ROOT/README.md"
grep -Fq '54% transparent' "$ROOT/README.md"
grep -Fq 'BackgroundBlur' "$ROOT/README.md"
grep -Fq 'third-party' "$ROOT/README.md"
grep -Fq 'manually remove' "$ROOT/README.md"
grep -Fq '## Manual 1 — macOS Terminal' "$ROOT/README.md"
grep -Fq '## Manual 2 — Herdr' "$ROOT/README.md"
grep -Fq '## Manual 3 — CLI inside Herdr Dark Glass' "$ROOT/README.md"
grep -Fq '### OpenCode' "$ROOT/README.md"
grep -Fq '### Claude Code' "$ROOT/README.md"
grep -Fq 'dark-ansi' "$ROOT/README.md"
grep -Fq '### Codex CLI' "$ROOT/README.md"
grep -Fq 'tui.theme' "$ROOT/README.md"
grep -Fq '### Grok Build' "$ROOT/README.md"
grep -Fq 'GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok' "$ROOT/README.md"
grep -Fq 'grok --minimal' "$ROOT/README.md"
grep -Fq 'SOCIAL GLASS 1.2' "$ROOT/scripts/guide.sh"
```

Temporarily run:

```bash
bash tests/smoke.sh
```

Expected: failure because the README and guide still describe version 1.1 and two presets.

- [ ] **Step 2: Update the guide banner**

In `scripts/guide.sh`, replace the two banner lines with:

```bash
printf '\033[1;38;2;183;214;163mHERDR SOCIAL GLASS 1.2\033[0m\n'
printf '\033[38;2;185;190;185mSocial Glass + Island Glass + Dark Glass workspace presets.\033[0m\n\n'
```

Leave its README rendering and keypress behavior unchanged.

- [ ] **Step 3: Add the Dark Glass quick-start and three-layer explanation to README**

Replace the README's opening “pair” description with:

```markdown
Herdr Social Glass provides three screenshot-friendly workspace presets for Herdr on macOS. Social Glass keeps the translucent editorial workspace, Island Glass adds a warm cream collaboration station, and Dark Glass coordinates a native translucent Terminal profile with transparent Herdr and OpenCode surfaces. Social Glass and Island Glass retain their existing visual and launch behavior.
```

Then add this exact workflow under the preset introduction:

````markdown
## Manual 1 — macOS Terminal

Dark Glass is a coordinated three-layer mode:

1. **macOS Terminal** owns the window-wide `#080E14` veil, 46% background opacity (54% transparent), and native `BackgroundBlur = 0.24`.
2. **Herdr** uses transparent main panel and sidebar surfaces, with small opaque active-row and selection colors for keyboard readability.
3. **OpenCode** uses `none` for its main, panel, element, and diff-row backgrounds so the Terminal profile remains visible.

The setup action imports a dedicated `Herdr Dark Glass` profile instead of modifying `Clear Light` or `Clear Dark`. Complete Terminal's visible import confirmation, then verify profile availability with the status action. The opacity/blur adjustment, Terminal-grid limits, and profile-removal instructions remain in this manual.

## Manual 2 — Herdr

Run these actions in order:

```bash
herdr plugin action invoke setup-dark-glass --plugin linyu.social-glass
herdr plugin action invoke apply-dark-glass --plugin linyu.social-glass
herdr plugin action invoke status --plugin linyu.social-glass
herdr plugin action invoke open-dark-glass-window --plugin linyu.social-glass
```

The setup action installs `~/.config/opencode/themes/herdr-dark-glass.json`. If Terminal does not already contain a profile named `Herdr Dark Glass`, setup opens the bundled profile for Terminal's explicit import flow. Complete that import before launching a Dark Glass window.

## Manual 3 — CLI inside Herdr Dark Glass

Run each CLI inside a pane opened by the Dark Glass Herdr window. The plugin installs only the OpenCode theme; every CLI selection below remains user-controlled.

### OpenCode

Run `/themes`, select `herdr-dark-glass`, and lock dark mode. The plugin deliberately does not overwrite `tui.json`, `tui.jsonc`, plugin lists, or OpenCode's selection state. Third-party extensions may still paint localized backgrounds.

### Claude Code

Run `claude`, then `/theme`, and select `dark-ansi`. This delegates the palette to Terminal while allowing localized message, diff, memory, and selection surfaces. The plugin never reads or writes Claude settings or credentials.

### Codex CLI

Run `codex` normally. Its full viewport retains the terminal background; `tui.theme` changes syntax highlighting only and `tui.alternate_screen` changes scrollback behavior, not transparency. Localized user-message and proposed-plan backgrounds may remain visible.

### Grok Build

Run `/theme transparent` in Grok. If terminal-theme rollout opt-in is required for the installed build, start a session with:

```bash
GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok
```

Use `grok --minimal` as the terminal-native fallback. The plugin never reads or writes Grok configuration or credentials.
````

- [ ] **Step 4: Document opacity, wallpaper adjustment, limits, restore, and uninstall**

Add these sections to `README.md`:

````markdown
### Opacity and transparency

The shipped Terminal background opacity is 46%, which is the same as 54% transparency. Increasing opacity makes the dark veil stronger and improves contrast; increasing transparency reveals more wallpaper and can reduce readability.

For a bright or high-detail wallpaper, open Terminal Settings, duplicate or edit only the imported `Herdr Dark Glass` profile, and raise its Background opacity. Keep the bundled profile file unchanged so updates and tests remain reproducible. `BackgroundBlur = 0.24` is an initial native value, not a pixel-equivalent mapping of the browser demo's 24px blur.

### Terminal-grid limits

Dark Glass is window-level translucency, not native AppKit vibrancy. A terminal character grid cannot provide independently blurred rounded cards or per-pane compositor layers. ANSI backgrounds used by selections, active rows, dialogs, and third-party OpenCode TUI extensions remain opaque where those components draw them. The integration controls Herdr's preset and OpenCode's theme contract, but it cannot force third-party extensions to stop drawing backgrounds.

### Restore and uninstall

`restore` restores the first pre-theme Herdr configuration baseline:

```bash
herdr plugin action invoke restore --plugin linyu.social-glass
```

Restore does not delete the user-imported Terminal profile or the copied OpenCode theme. To remove those user settings, manually remove `Herdr Dark Glass` in Terminal Settings and manually remove `~/.config/opencode/themes/herdr-dark-glass.json`. If setup replaced a differing file at that path, inspect the timestamped copy under `~/.config/herdr/plugin-state/linyu.social-glass/backups/` before deleting it.
````

Replace the existing Actions command block with:

```bash
herdr plugin action invoke apply --plugin linyu.social-glass
herdr plugin action invoke apply-island --plugin linyu.social-glass
herdr plugin action invoke apply-dark-glass --plugin linyu.social-glass
herdr plugin action invoke setup-dark-glass --plugin linyu.social-glass
herdr plugin action invoke open-window --plugin linyu.social-glass
herdr plugin action invoke open-island-window --plugin linyu.social-glass
herdr plugin action invoke open-dark-glass-window --plugin linyu.social-glass
herdr plugin action invoke status --plugin linyu.social-glass
herdr plugin action invoke restore --plugin linyu.social-glass
```

Add these bullets to “What each action does” without changing the existing six descriptions:

```markdown
- `setup-dark-glass` safely installs the OpenCode theme and opens the bundled Terminal profile only when explicit import is still needed.
- `apply-dark-glass` validates and applies the transparent Dark Glass Herdr preset through the same backup and rollback path as the existing presets.
- `open-dark-glass-window` refuses to launch until `Herdr Dark Glass` exists, then opens that profile without an OSC 11 background override.
- `status` independently reports the active Herdr preset, Terminal profile availability, OpenCode theme content/selection when detectable, and optional OpenCode/Claude/Codex/Grok command versions without claiming their selected themes.
```

Also update the requirements and files/layout lists to include the dedicated Terminal profile, OpenCode integration, CLI compatibility helper, generator, and new scripts. State explicitly that Social Glass and Island Glass keep their existing behavior. Record the manual verification baselines (OpenCode `1.18.31`, Claude Code `2.1.274`, Codex CLI `0.154.0`, Grok Build `1.0.34`) as tested versions rather than minimum requirements.

- [ ] **Step 5: Run guide and documentation checks**

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
bash tests/smoke.sh
printf 'x' | bash scripts/guide.sh > /tmp/herdr-social-glass-guide.txt
grep -Fq 'HERDR SOCIAL GLASS 1.2' /tmp/herdr-social-glass-guide.txt
grep -Fq 'Dark Glass' /tmp/herdr-social-glass-guide.txt
```

Expected: smoke exits `0`; the guide renders the updated README without trying to display Markdown images and closes after the supplied keypress.

- [ ] **Step 6: Review documentation without committing**

Run `git diff --check` and leave README, guide, and documentation tests uncommitted for the user's deployment gate.

---

### Task 7: Final automated verification, regression audit, and deployment handoff

**Files:**
- Verify all files above
- Modify only if a test exposes a defect

- [ ] **Step 1: Regenerate the Terminal profile and prove there is no drift**

Run:

```bash
cd /Users/jachael/Documents/byMySide/herdr-dark-glass
profile_tmp="$(mktemp)"
python3 tools/build-terminal-profile.py "$profile_tmp"
cmp "$profile_tmp" "profiles/Herdr Dark Glass.terminal"
rm -f "$profile_tmp"
```

Expected: `cmp` exits `0`; no generated asset diff.

- [ ] **Step 2: Run every focused test directly**

Run:

```bash
TEST_PYTHON="$(bash -c 'source tests/test-env.sh; find_python_with_tomllib')"
"$TEST_PYTHON" tests/dark-glass-assets.py
bash tests/dark-glass-setup.sh
bash tests/dark-glass-launcher.sh
bash tests/cli-compat-status.sh
```

Expected: all four focused tests print their `ok` line and exit `0`.

- [ ] **Step 3: Run the complete project test suite**

Run:

```bash
bash tests/smoke.sh
bash tests/functional.sh
bash -n scripts/*.sh tests/*.sh
```

Expected: all commands exit `0`. This pass must include existing Social and Island launch/apply behavior, Dark apply/status/backup/restore, reload rollback, setup idempotency and backup, profile import decisions, profile launcher refusal/selection, and no Dark OSC 11 emission.

- [ ] **Step 4: Audit prohibited mutations and external interfaces**

Run:

```bash
if grep -R -nE 'defaults[[:space:]]+write[[:space:]]+com\.apple\.Terminal|tui\.jsonc.*>|tui\.json.*>|\.claude/(settings\.json|themes)|\.claude\.json|\.codex/config\.toml|\.grok/config\.toml' scripts; then
  echo 'prohibited configuration mutation or private CLI config access found' >&2
  exit 1
fi
git diff -- scripts/open-social-window.sh scripts/open-island-window.sh
git diff --check
git status --short --branch
```

Expected:

- No private Terminal preference write.
- No OpenCode TUI config write.
- No diff in `open-social-window.sh` or `open-island-window.sh` unless a regression-required change was separately justified and tested.
- `git diff --check` exits `0`.
- Only intentional implementation files are changed.

- [ ] **Step 5: Compare implementation against every acceptance criterion**

Confirm each item with a file or test:

```text
Terminal profile: #080E14, alpha 0.46, blur 0.24
Herdr: panel_bg/sidebar_bg transparent; active/selection surfaces retained
OpenCode: main/panel/element/diff backgrounds none
Claude Code: dark-ansi documented; no settings/theme installation by plugin
Codex CLI: terminal-owned full viewport documented; tui.theme identified as syntax-only
Grok Build: /theme transparent, session-only environment command, and --minimal fallback documented
CLI status: present/missing/failed-version cases are non-fatal and no private config is read
README: three manuals with four separate CLI subsections
Text palette: primary #F5F3ED, muted #B9BEB9, accent #B7D6A3
Existing modes: Social and Island functional regressions pass
Safety: no Clear Light/Clear Dark or private preference mutation
Idempotency: setup and apply tests pass; differing files are backed up
Recovery: reload failure rollback and baseline restore tests pass
Documentation: setup, adjustment, limits, restore, uninstall documented
```

If an item lacks a passing automated assertion, add that assertion before declaring implementation complete.

- [ ] **Step 6: Hand the uncommitted feature clone to the user for deployment**

Run:

```bash
git diff --stat
git diff --check
git status --short --branch
```

Expected: the branch is `feat/dark-glass`, every intended source/documentation/test change is present but uncommitted, there are no whitespace errors, and no remote branch has been created. Give the user exactly three local-deployment sentences. Wait for their successful deployment report before creating any commit or push.

After the user reports success, create focused commits ending with `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`, rerun the full suite, and push once with:

```bash
git push -u origin feat/dark-glass
```

Do not open a pull request unless separately requested.

---

### Task 8: User-approved local rollout and manual visual verification

**Files:**
- Runtime user configuration only; no source changes expected

This task is intentionally gated because it changes the user's active Herdr plugin registration, imports Terminal configuration, and writes an OpenCode theme file. Complete Tasks 0–7 first, then obtain explicit approval before running any command below.

- [ ] **Step 1: Record and back up the current plugin registration without changing it**

Run:

```bash
herdr plugin list
herdr plugin config-dir linyu.social-glass
ROLLOUT_BACKUP="$(mktemp -d "$HOME/.config/herdr/dark-glass-rollout.XXXXXX")"
printf '%s\n' "$ROLLOUT_BACKUP" > /tmp/herdr-dark-glass-rollout-backup-path
for source in \
  "$HOME/.config/herdr/plugins/config/linyu.social-glass" \
  "$HOME/.config/herdr/plugin-state/linyu.social-glass"; do
  if [[ -e "$source" ]]; then
    cp -a "$source" "$ROLLOUT_BACKUP/"
  fi
done
printf 'Runtime backup: %s\n' "$ROLLOUT_BACKUP"
```

Expected: `plugin list` shows the managed `linyu.social-glass` registration, and the printed rollout directory contains copies of every existing plugin config/state directory. Keep `/tmp/herdr-dark-glass-rollout-backup-path` until rollback is complete.

- [ ] **Step 2: Switch the registration to the local feature clone**

Run:

```bash
herdr plugin uninstall linyu.social-glass
herdr plugin link --enabled /Users/jachael/Documents/byMySide/herdr-dark-glass
herdr plugin list
```

Expected: plugin ID remains `linyu.social-glass`, source is the local clone, and version is `1.2.0`. If either plugin config/state directory disappeared during registration replacement, restore its saved copy from the directory recorded in `/tmp/herdr-dark-glass-rollout-backup-path` before invoking an action. Do not attempt to keep managed and linked copies with the same ID registered simultaneously.

- [ ] **Step 3: Run explicit setup and confirm profile import**

Run:

```bash
herdr plugin action invoke setup-dark-glass --plugin linyu.social-glass
herdr plugin action invoke status --plugin linyu.social-glass
```

Expected: the OpenCode theme is current. If Terminal displays its import UI, approve the `Herdr Dark Glass` import, then rerun status until it reports `Terminal profile: installed`.

- [ ] **Step 4: Activate Dark Glass and exercise all four CLI paths**

Run:

```bash
herdr plugin action invoke apply-dark-glass --plugin linyu.social-glass
herdr plugin action invoke status --plugin linyu.social-glass
```

Expected: `State:   dark-glass`. Then, inside Dark Glass Herdr panes:

1. OpenCode: run `/themes`, choose `herdr-dark-glass`, and lock dark mode.
2. Claude Code: run `/theme` and choose `dark-ansi`.
3. Codex CLI: run `codex` normally without changing `tui.theme` for transparency.
4. Grok Build: run `/theme transparent`; if needed, restart with `GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok`, and verify `grok --minimal` as a fallback.

Rerun status to confirm command versions and any detectable OpenCode selection. Status must not claim Claude, Codex, or Grok theme selection.

- [ ] **Step 5: Launch and visually inspect the reference scenarios**

Run:

```bash
herdr plugin action invoke open-dark-glass-window --plugin linyu.social-glass
```

Inspect:

1. Desktop wallpaper remains visible through the `#080E14` veil.
2. Primary and muted text remain readable on forest, dark, and bright wallpapers.
3. Herdr sidebar and main panel do not paint full opaque areas.
4. OpenCode, Claude Code, Codex CLI, and Grok Build main canvases remain terminal-owned; inspect each CLI's localized messages, diffs, dialogs, plans, composer, and selection surfaces for readability.
5. Active rows/selections are the intended small opaque surfaces.
6. The window does not flash or settle to an opaque OSC 11 background.
7. `Clear Light`, `Clear Dark`, Social Glass, and Island Glass remain visually unchanged.

For a bright wallpaper, raise the imported profile's background opacity in Terminal Settings rather than editing the generated asset or adding OSC color overrides.

- [ ] **Step 6: Exercise restore and registration rollback**

Run only after visual verification:

```bash
herdr plugin action invoke restore --plugin linyu.social-glass
```

Expected: the first pre-theme Herdr baseline returns. Confirm that the Terminal profile and OpenCode theme remain as documented. To revert registration to the exact previously inspected managed revision, run:

```bash
herdr plugin unlink linyu.social-glass
herdr plugin install --yes --ref 9c0991f ythx-101/herdr-social-glass
herdr plugin list
```

Expected: `linyu.social-glass` is managed again at the recorded revision. If registration commands removed config/state, restore the saved directories from `"$(cat /tmp/herdr-dark-glass-rollout-backup-path)"`, then delete the temporary pointer file only after verifying the managed plugin works.

---

## Self-review checklist

Before execution handoff, verify the plan itself:

- [ ] Every approved spec section maps to a task: Python test portability (Task 0A), Terminal profile (Task 2), Herdr preset/apply (Task 1), OpenCode/setup (Task 3), launcher (Task 4), layered and CLI status (Task 5), three manuals (Task 6), automated acceptance (Task 7), manual rollout (Task 8).
- [ ] Social and Island external launch interfaces stay unchanged and retain regression coverage.
- [ ] All new scripts have explicit error messages, test seams, and executable-bit steps.
- [ ] All new generated/config files have parser-based tests rather than grep-only validation.
- [ ] No runtime step silently writes Terminal private preferences, OpenCode TUI configuration, or Claude/Codex/Grok configuration and credentials.
- [ ] Optional CLI probes are read-only, version failures are non-fatal, and README instructions distinguish localized state surfaces from full-area backgrounds.
- [ ] No commit or push occurs before the user reports successful local deployment; later commits must include `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- [ ] There are no `TBD`, `TODO`, “implement later,” or unspecified “add tests” placeholders.
- [ ] Naming is consistent: preset `dark-glass`, profile `Herdr Dark Glass`, OpenCode theme `herdr-dark-glass`, plugin version `1.2.0`.
