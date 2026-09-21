# Dark Glass Readability Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship four Terminal-owned Dark Glass opacity levels, a safe `prefix+u` cycle action, a readable ANSI muted color, and corrected Grok guidance.

**Architecture:** Terminal owns opacity through four imported settings sets; the plugin switches only the selected tab's `current settings` and stores no cycle state. The existing profile-from-birth launcher defaults to the 74% Read profile. The Herdr preset wires a custom shell command to the new plugin action, while setup and docs give customized users a merge-safe snippet.

**Tech Stack:** Bash 3.2, AppleScript/macOS Terminal, Python 3 + `plistlib`, TOML, Herdr 0.8.2 plugin actions, shell/Python regression tests.

---

## File map

- `tools/build-terminal-profile.py`: single palette builder plus deterministic legacy/four-level profile generation.
- `profiles/Herdr Dark Glass*.terminal`: committed Terminal profile assets.
- `scripts/setup-dark-glass.sh`: validate assets, query/import all four cycle profiles, preserve OpenCode behavior.
- `scripts/open-dark-glass-window.sh`: default new windows to the Read profile.
- `scripts/cycle-dark-glass-opacity.sh`: atomically cycle the selected front Terminal tab.
- `scripts/status.sh`: report cycle-profile readiness and default level.
- `scripts/cli-compat-status.sh`: accurate Grok terminal-theme rollout guidance.
- `theme/dark-glass.toml`: distributed `prefix+u` custom command.
- `herdr-plugin.toml`: version 1.3.0 and cycle action.
- `tests/dark-glass-assets.py`: profile bytes, opacity, palette, contrast, regeneration.
- `tests/dark-glass-setup.sh`: four-profile import contract.
- `tests/dark-glass-launcher.sh`: Read-profile default and profile-from-birth guard.
- `tests/dark-glass-opacity.sh`: cycle transitions and safety contract.
- `tests/cli-compat-status.sh`, `tests/smoke.sh`, `tests/functional.sh`: manifest/docs/status integration.
- `README.md`, `scripts/guide.sh`: compact user instructions.
- `docs/superpowers/specs/2026-09-18-dark-glass-design.md`: correct the owning Grok design claim.

### Task 1: Correct the Grok contract

**Files:**
- Modify: `tests/dark-glass-setup.sh`
- Modify: `tests/cli-compat-status.sh`
- Modify: `tests/smoke.sh`
- Modify: `scripts/setup-dark-glass.sh`
- Modify: `scripts/cli-compat-status.sh`
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-09-18-dark-glass-design.md`

- [ ] **Step 1: Add failing assertions for the rollout gate**

Require the setup/status/README surfaces to say that Grok has no custom `herdr-dark-glass` theme and that the built-in terminal theme is hidden until enabled:

```bash
grep -Fq 'GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok' "$TMP/first-install.out" || fail 'setup omitted the Grok terminal-theme gate'
grep -Fq 'built-in terminal theme' "$TMP/first-install.out" || fail 'setup misdescribed Grok as a custom theme'
! grep -Fq 'run /theme transparent' "$TMP/first-install.out" || fail 'setup documents an unavailable ungated theme'
```

In `tests/cli-compat-status.sh`, expect:

```bash
assert_contains "$present_output" 'Compatibility: enable the built-in terminal theme with GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok'
```

In `tests/smoke.sh`, require the environment command and reject the bare `/theme transparent` instruction.

- [ ] **Step 2: Run the focused tests and observe RED**

Run:

```bash
bash tests/dark-glass-setup.sh
bash tests/cli-compat-status.sh
bash tests/smoke.sh
```

Expected: failures naming the missing rollout-gate wording and the stale `/theme transparent` wording.

- [ ] **Step 3: Replace the inaccurate guidance**

Use this exact setup/status guidance:

```bash
printf '%s\n' 'Grok Build: Dark Glass does not install a custom Grok theme. Start Grok with its rollout-gated built-in terminal theme: GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok. To persist it, set [features] terminal_theme = true and [ui] theme = "terminal" in ~/.grok/config.toml.'
```

The README Grok row becomes:

```markdown
| Grok Build | 无自定义 Dark Glass 主题；使用 Grok 内置终端主题启动：`GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok` |
```

Correct every Grok claim in the owning 2026-09-18 design: `terminal` is built in, rollout-gated, and unavailable to `/theme` until `GROK_TERMINAL_THEME=1` or `[features] terminal_theme = true` is set.

- [ ] **Step 4: Run the focused tests and observe GREEN**

Run the three commands from Step 2. Expected: all pass.

- [ ] **Step 5: Commit the correction**

```bash
git add README.md scripts/setup-dark-glass.sh scripts/cli-compat-status.sh \
  tests/dark-glass-setup.sh tests/cli-compat-status.sh tests/smoke.sh \
  docs/superpowers/specs/2026-09-18-dark-glass-design.md
git commit -m "fix: document Grok terminal theme rollout" \
  -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 2: Generate the four profile assets

**Files:**
- Modify: `tests/dark-glass-assets.py`
- Modify: `tools/build-terminal-profile.py`
- Modify: `profiles/Herdr Dark Glass.terminal`
- Create: `profiles/Herdr Dark Glass Glass.terminal`
- Create: `profiles/Herdr Dark Glass Clear.terminal`
- Create: `profiles/Herdr Dark Glass Read.terminal`
- Create: `profiles/Herdr Dark Glass Focus.terminal`

- [ ] **Step 1: Generalize the asset test first**

Define the expected cycle table:

```python
PROFILE_SPECS = {
    "Herdr Dark Glass Glass": 0.46,
    "Herdr Dark Glass Clear": 0.60,
    "Herdr Dark Glass Read": 0.74,
    "Herdr Dark Glass Focus": 0.88,
}
```

For each file, assert the settings-set name, `#080E14`, expected alpha, blur `0.24`, and `ANSIBrightBlackColor == rgb((185, 190, 185))`. Keep the legacy profile assertion, but require its bright-black slot to use the corrected value too.

Add WCAG helpers and assertions:

```python
def relative_luminance(rgb255: tuple[int, int, int]) -> float:
    channels = [channel / 255 for channel in rgb255]
    linear = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4 for value in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(left: tuple[int, int, int], right: tuple[int, int, int]) -> float:
    hi, lo = sorted((relative_luminance(left), relative_luminance(right)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def over_white(background: tuple[int, int, int], alpha: float) -> tuple[int, int, int]:
    return tuple(round(alpha * channel + (1 - alpha) * 255) for channel in background)

assert contrast((245, 243, 237), over_white((8, 14, 20), 0.74)) >= 7.0
assert contrast((185, 190, 185), over_white((8, 14, 20), 0.74)) >= 4.5
assert contrast((185, 190, 185), over_white((8, 14, 20), 0.88)) >= 7.0
```

Regenerate all assets into a temporary directory with `--all` and compare bytes.

- [ ] **Step 2: Run the asset test and observe RED**

```bash
python3 tests/dark-glass-assets.py
```

Expected: missing profile files and the old `(72, 82, 77)` bright-black value.

- [ ] **Step 3: Make the generator data-driven**

Add:

```python
LEGACY_PROFILE = ("Herdr Dark Glass", 0.46)
PROFILE_SPECS = (
    ("Herdr Dark Glass Glass", 0.46),
    ("Herdr Dark Glass Clear", 0.60),
    ("Herdr Dark Glass Read", 0.74),
    ("Herdr Dark Glass Focus", 0.88),
)


def build_profile(name: str, opacity: float) -> dict[str, object]:
    # Existing body, with name and opacity replacing constants.
```

Set `ANSIBrightBlackColor` to `#B9BEB9`. Extend the CLI:

```python
parser.add_argument("--all", action="store_true")
parser.add_argument("output", nargs="?", type=Path, default=DEFAULT_OUTPUT)
```

`--all OUTPUT_DIR` writes the legacy and four cycle files; the existing positional-output behavior still builds the legacy profile for compatibility.

- [ ] **Step 4: Generate assets and observe GREEN**

```bash
python3 tools/build-terminal-profile.py --all profiles
python3 tests/dark-glass-assets.py
```

Expected: `dark glass generated and integration assets: ok`.

- [ ] **Step 5: Commit the profile assets**

```bash
git add tools/build-terminal-profile.py tests/dark-glass-assets.py profiles/
git commit -m "feat: add Dark Glass opacity profiles" \
  -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 3: Import and launch the Read profile

**Files:**
- Modify: `tests/dark-glass-setup.sh`
- Modify: `tests/dark-glass-launcher.sh`
- Modify: `scripts/setup-dark-glass.sh`
- Modify: `scripts/open-dark-glass-window.sh`
- Modify: `scripts/status.sh`
- Modify: `tests/functional.sh`

- [ ] **Step 1: Add failing multi-profile setup and launcher assertions**

The setup test must require one explicit import request containing all four missing files, no import when all are present, and no OpenCode/theme mutation when the profile query fails. The launcher test must require its default query argument to be `Herdr Dark Glass Read` while preserving override validation.

Status must report:

```text
Terminal opacity profiles: 4/4 installed
Terminal default level: Read (74%)
```

- [ ] **Step 2: Run focused tests and observe RED**

```bash
bash tests/dark-glass-setup.sh
bash tests/dark-glass-launcher.sh
bash tests/functional.sh
```

Expected: current single-profile assumptions fail.

- [ ] **Step 3: Implement one bounded profile query**

In setup, define parallel arrays:

```bash
PROFILE_NAMES=(
  'Herdr Dark Glass Glass'
  'Herdr Dark Glass Clear'
  'Herdr Dark Glass Read'
  'Herdr Dark Glass Focus'
)
PROFILE_FILES=(
  "$ROOT/profiles/Herdr Dark Glass Glass.terminal"
  "$ROOT/profiles/Herdr Dark Glass Clear.terminal"
  "$ROOT/profiles/Herdr Dark Glass Read.terminal"
  "$ROOT/profiles/Herdr Dark Glass Focus.terminal"
)
```

Pass all names through AppleScript argv, return missing names separated by linefeeds, validate every returned name against the fixed table, and invoke `open` once with exactly the corresponding missing assets. Do not use `defaults` or silently import anything.

Set the launcher default:

```bash
PROFILE_NAME="${HERDR_DARK_GLASS_TERMINAL_PROFILE-Herdr Dark Glass Read}"
```

Teach status to query the four fixed names and count exact matches; retain the environment override for the launcher.

- [ ] **Step 4: Run focused tests and observe GREEN**

Run the commands from Step 2. Expected: all pass.

- [ ] **Step 5: Commit setup and launch changes**

```bash
git add scripts/setup-dark-glass.sh scripts/open-dark-glass-window.sh scripts/status.sh \
  tests/dark-glass-setup.sh tests/dark-glass-launcher.sh tests/functional.sh
git commit -m "feat: launch the readable Dark Glass profile" \
  -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 4: Add the safe opacity-cycle action

**Files:**
- Create: `tests/dark-glass-opacity.sh`
- Create: `scripts/cycle-dark-glass-opacity.sh`
- Modify: `herdr-plugin.toml`
- Modify: `theme/dark-glass.toml`
- Modify: `tests/smoke.sh`

- [ ] **Step 1: Write the cycle test before the script**

Use an injected `OSASCRIPT_BIN_PATH` mock that captures argv/stdin and returns the requested next profile. Assert the transition table:

```text
Glass -> Clear
Clear -> Read
Read -> Focus
Focus -> Glass
Herdr Dark Glass -> Clear
unrelated -> Read
```

Assert all four profile names cross the AppleScript boundary as separate argv values and that the body contains `selected tab of front window` plus `set current settings of targetTab to settings set nextProfile`. Reject `do script`, `open`, `defaults`, `default settings`, `startup settings`, and filesystem state writes.

- [ ] **Step 2: Run the cycle test and observe RED**

```bash
bash tests/dark-glass-opacity.sh
```

Expected: missing script/action.

- [ ] **Step 3: Implement the cycle script**

The script invokes one AppleScript call with the four fixed profile names. AppleScript verifies every settings set exists before selecting the front window's selected tab. It maps the current name through the fixed transition table, sets only `current settings`, verifies the resulting settings-set name, and returns it. Shell maps that name to a concise `Glass (46%)`, `Clear (60%)`, `Read (74%)`, or `Focus (88%)` result.

Add the manifest action:

```toml
[[actions]]
id = "cycle-dark-glass-opacity"
title = "Cycle Dark Glass opacity"
command = ["bash", "scripts/cycle-dark-glass-opacity.sh"]
```

Add the preset binding:

```toml
[[keys.command]]
key = "prefix+u"
type = "shell"
command = "herdr plugin action invoke cycle-dark-glass-opacity --plugin linyu.social-glass"
```

- [ ] **Step 4: Run focused tests and observe GREEN**

```bash
bash tests/dark-glass-opacity.sh
bash tests/smoke.sh
```

Expected: both pass.

- [ ] **Step 5: Commit the cycle action**

```bash
git add scripts/cycle-dark-glass-opacity.sh tests/dark-glass-opacity.sh \
  herdr-plugin.toml theme/dark-glass.toml tests/smoke.sh
git commit -m "feat: cycle Dark Glass opacity with prefix+u" \
  -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

### Task 5: Version, docs, and complete verification

**Files:**
- Modify: `herdr-plugin.toml`
- Modify: `README.md`
- Modify: `scripts/guide.sh`
- Modify: `tests/smoke.sh`
- Modify: `docs/superpowers/specs/2026-09-21-dark-glass-readability-controls-design.md`

- [ ] **Step 1: Add failing documentation/version guards**

Require version `1.3.0`, all four levels, Read as default, `prefix+u`, the custom-command snippet, rerunning setup/import, and the accurate Grok rollout command.

- [ ] **Step 2: Run smoke and observe RED**

```bash
bash tests/smoke.sh
```

- [ ] **Step 3: Update the user surfaces**

Keep the README compact and bilingual. Explain that existing customized users rerun setup to import profiles, then merge the `[[keys.command]]` block instead of rerunning `apply-dark-glass`. Update the guide and exact manifest version to `1.3.0`.

- [ ] **Step 4: Run full verification**

```bash
bash tests/smoke.sh
bash tests/functional.sh
bash tests/dark-glass-setup.sh
bash tests/dark-glass-launcher.sh
bash tests/dark-glass-opacity.sh
bash tests/cli-compat-status.sh
bash -n scripts/*.sh
git diff --check
```

Expected: every command exits zero; no real Terminal window is opened because all AppleScript/open paths are mocked.

- [ ] **Step 5: Commit docs and version**

```bash
git add README.md scripts/guide.sh herdr-plugin.toml tests/smoke.sh \
  docs/superpowers/specs/2026-09-21-dark-glass-readability-controls-design.md
git commit -m "docs: explain Dark Glass readability controls" \
  -m "Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: Deploy locally without overwriting personal keys**

Back up `~/.config/herdr/config.toml` with mode 600, insert only the approved `[[keys.command]]` block if absent, reload Herdr, rerun setup for visible profile import, and never invoke `apply-dark-glass`. This local file and its backup must not be staged.

- [ ] **Step 7: Push after final review**

Review staged paths, exclude `.claude/`, `.superpowers/`, local configs, and backups; then push `feat/readability-controls`. Integrate to `main` only using the repository workflow explicitly confirmed at finish time.
