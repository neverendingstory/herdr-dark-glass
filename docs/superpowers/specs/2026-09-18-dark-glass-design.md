# Herdr Dark Glass Design

**Date:** 2026-09-18  
**Status:** Approved design  
**Target:** Herdr Social Glass plugin on macOS

## Problem

The existing Social Glass and Island Glass launchers use the macOS Terminal `Clear Light` profile. On the target machine, that profile has a white background with alpha `0.93` and `BackgroundBlur = 0.5`, so it is nearly opaque. Island Glass additionally sends OSC 10/11 foreground and background colors, but OSC colors cannot control window alpha or blur.

The requested result is a third visual mode resembling a dark desktop glass surface: the wallpaper remains visible, the terminal carries a dark translucent veil, and Herdr plus supported terminal CLIs avoid painting opaque full-area backgrounds. The selected visual direction is Scheme C from `/Users/jachael/dark-glass-demo.html`.

## Goals

- Preserve the existing Social Glass and Island Glass modes unchanged.
- Add a new Dark Glass mode spanning macOS Terminal, Herdr, OpenCode, Claude Code, Codex CLI, and Grok Build.
- Keep OpenCode's installable transparent theme and make Claude Code, Codex CLI, and Grok Build compatible through their supported terminal-native behavior and explicit user instructions.
- Report optional CLI presence and versions without requiring those CLIs to be installed.
- Use a dedicated Terminal profile rather than modifying `Clear Light` or `Clear Dark`.
- Keep wallpaper detail visible while prioritizing long-session readability.
- Make setup explicit, reversible, and safe around existing user configuration.
- Extend the current validation, backup, rollback, status, and test behavior to the new mode.

## Non-goals

- Reproduce native AppKit vibrancy, per-card blur, rounded translucent panels, or layered compositor effects inside a terminal character grid.
- Install or require a different terminal emulator.
- Silently mutate `com.apple.Terminal` private preferences.
- Overwrite OpenCode's `tui.json`, `tui.jsonc`, plugin list, or unrelated settings.
- Install, upgrade, or authenticate OpenCode, Claude Code, Codex CLI, or Grok Build binaries; rewrite Claude, Codex, or Grok configuration; or rewrite OpenCode configuration outside the dedicated theme file.
- Add a separate Terminal-window action or wrapper for every supported CLI.
- Claim that a CLI theme is selected when the CLI does not expose a reliable read-only selection signal.
- Guarantee equal contrast over every possible wallpaper.
- Change the visual contract of the existing Social Glass or Island Glass actions.

## Verified Constraints

### macOS Terminal

- Transparency and blur belong to a Terminal profile, not to Herdr.
- The Terminal AppleScript dictionary exposes profile selection and foreground/background colors, but not background alpha or blur as writable scripting properties.
- The Terminal preference data contains `BackgroundColor` with an alpha component and `BackgroundBlur`, but directly writing those private preferences is deliberately excluded.
- OSC 10/11 can change foreground/background colors but cannot set alpha or blur.

### Herdr

- Herdr supports reset/transparent background color aliases, including `transparent`, but has no opacity or blur configuration.
- `panel_bg` and `sidebar_bg` can reveal the host terminal background.
- Any ANSI background painted for a row, selection, or nested TUI remains opaque. Small opaque state surfaces are acceptable; full-area opaque surfaces are not.

### OpenCode

- OpenCode user themes can set `background`, `backgroundPanel`, and `backgroundElement` to `none`, delegating those surfaces to the terminal.
- User themes are discovered from `~/.config/opencode/themes/*.json`.
- Theme selection can be performed through `/themes`; the plugin will not rewrite OpenCode configuration or state to force selection.
- Third-party OpenCode TUI extensions may still draw their own opaque backgrounds. This integration can control only the OpenCode theme contract.

### Claude Code

- Claude Code provides a built-in `dark-ansi` theme through `/theme`; it uses the terminal's ANSI palette rather than owning the Terminal profile.
- Claude Code does not provide OpenCode-style `none` background tokens. Local message, diff, memory, and selection surfaces may remain opaque while the full terminal canvas remains host-owned.
- The plugin does not install a Claude theme and does not read or write `~/.claude/settings.json`, `~/.claude.json`, project settings, or credentials.
- The verified manual baseline is Claude Code `2.1.274`.

### Codex CLI

- Codex leaves its full viewport on the terminal's default background. It may calculate small user-message and proposed-plan backgrounds from the terminal's reported nominal background.
- `tui.theme` controls syntax highlighting only. `tui.alternate_screen` controls screen-buffer behavior and does not control transparency.
- Codex does not expose a supported transparent-background setting, so the correct Dark Glass behavior is to run it without a background override.
- The plugin does not read or write `~/.codex/config.toml` or credentials. The verified manual baseline is Codex CLI `0.154.0`.

### Grok Build

- Grok Build 1.0.40 has NO custom `herdr-dark-glass` theme.
- Its built-in terminal aliases `terminal`, `terminal-default`, `transparent`, and `native` are rollout-gated. A bare `/theme transparent` fails until terminal themes are enabled.
- The exact one-session launch command is `GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok`.
- Persistent user-managed configuration is `[features] terminal_theme = true` and `[ui] theme = "terminal"`.
- The plugin does not read or write Grok configuration or credentials. The verified manual baseline is Grok Build `1.0.40`.

## Selected Visual Contract

The browser demo's Scheme C is the source of truth for the initial implementation:

| Property | Value |
|---|---|
| Background RGB | `#080E14` |
| Cycle profiles | Glass `46%`, Clear `60%`, Read `74%`, Focus `88%` opacity |
| Default launch profile | `Herdr Dark Glass Read` (`74%` opacity) |
| Legacy profile | `Herdr Dark Glass` at `46%` opacity |
| Initial Terminal blur mapping | `BackgroundBlur = 0.24` |
| Border alpha | `14%` |
| Accent | `#B7D6A3` |
| Primary text | `#F5F3ED` |
| Muted text | `#B9BEB9` |

The browser blur value is a perceptual reference, not a unit-equivalent mapping to Terminal. `BackgroundBlur = 0.24` is the native value for every shipped profile and must be checked visually on the target macOS release. The Read profile is the documented high-readability default; users can cycle or select another shipped profile without changing Terminal defaults.

The shared semantic palette is fixed as follows:

| Role | Value |
|---|---|
| Primary / accent | `#B7D6A3` |
| Secondary / info | `#8BD5FF` |
| Success | `#A6D189` |
| Warning | `#E5C890` |
| Error | `#E78284` |
| Purple syntax accent | `#C4A7E7` |
| Primary text | `#F5F3ED` |
| Muted text | `#B9BEB9` |
| Overlay text | `#87918C` |
| Border | `#6C7770` |
| Subtle border | `#48524D` |
| Herdr active row | `#29332D` |
| Herdr selection | `#3A463E` |

Terminal bold text is `#FFFFFF`, the cursor is `#B7D6A3`, and selection uses the active-row surface. Herdr and OpenCode reuse the semantic palette so status, Markdown, syntax, and diagnostics remain consistent across layers.

## Architecture

Dark Glass consists of three coordinated visual layers plus a read-only CLI compatibility contract.

### 1. Dedicated macOS Terminal Profile

Ship a legacy importable profile plus four dedicated cycle profiles under:

```text
profiles/Herdr Dark Glass.terminal
profiles/Herdr Dark Glass Glass.terminal
profiles/Herdr Dark Glass Clear.terminal
profiles/Herdr Dark Glass Read.terminal
profiles/Herdr Dark Glass Focus.terminal
```

The legacy profile remains `Herdr Dark Glass` at opacity `0.46`. The dedicated profiles use opacity Glass `0.46`, Clear `0.60`, Read `0.74`, and Focus `0.88`; Read is the default launcher profile. All retain `#080E14`, blur `0.24`, the shared palette/font/cursor/selection values, and `ANSIBrightBlackColor = #B9BEB9`.

These profiles own:

- Background RGB and alpha.
- Background blur.
- Foreground, bold text, cursor, and selection colors.
- Font and ordinary Terminal appearance defaults needed for a usable imported profile.

The profiles must not replace or rename an existing built-in profile. The plugin never modifies `Clear Light` or `Clear Dark`.

### 2. Transparent Herdr Preset

Add:

```text
theme/dark-glass.toml
```

Use Herdr's dark Catppuccin base and define the visual tokens explicitly. The large surfaces use the host terminal background:

```toml
[theme]
name = "catppuccin"
auto_switch = false

[theme.custom]
panel_bg = "transparent"
sidebar_bg = "transparent"
active_row_bg = "#29332D"
selection_bg = "#3A463E"
text = "#F5F3ED"
subtext0 = "#B9BEB9"
overlay0 = "#87918C"
accent = "#B7D6A3"
blue = "#8BD5FF"
mauve = "#C4A7E7"
green = "#A6D189"
yellow = "#E5C890"
red = "#E78284"
```

Focused rows and selections use only the two specified small opaque dark surfaces so keyboard navigation remains legible. Pane gaps, fine borders, and labels provide structure without simulating unsupported per-panel alpha.

### 3. CLI Compatibility Layer

#### Transparent OpenCode Theme

Ship:

```text
integrations/opencode/herdr-dark-glass.json
```

The theme uses Scheme C foreground colors and delegates major backgrounds to the terminal:

```json
{
  "background": "none",
  "backgroundPanel": "none",
  "backgroundElement": "none"
}
```

The OpenCode core mapping is fixed as follows:

- `primary` and `accent`: `#B7D6A3`
- `secondary` and `info`: `#8BD5FF`
- `text`: `#F5F3ED`
- `textMuted`: `#B9BEB9`
- `border`: `#6C7770`
- `borderActive`: `#B7D6A3`
- `borderSubtle`: `#48524D`
- `success`, `warning`, and `error`: the shared semantic values above
- `background`, `backgroundPanel`, and `backgroundElement`: `none`
- `diffAddedBg`, `diffRemovedBg`, `diffContextBg`, `diffAddedLineNumberBg`, and `diffRemovedLineNumberBg`: `none`

Added and removed diff foregrounds remain `#A6D189` and `#E78284`; borders and line-number foregrounds continue to communicate structure without opaque full-row fills. The theme includes every core, diff, Markdown, and syntax field required by the current OpenCode theme schema, using the fixed shared palette rather than introducing additional colors.

#### Claude Code, Codex CLI, and Grok Build

No additional theme asset is installed for these three CLIs:

- Claude Code users select `dark-ansi` with `/theme` so its colors follow the Terminal ANSI palette.
- Codex users run `codex` normally; its main viewport retains the terminal default background, and `tui.theme` remains a syntax-only choice.
- Grok 1.0.40 has NO custom Dark Glass theme. Its built-in terminal aliases are rollout-gated, so bare `/theme transparent` fails until enabled. Users use `GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok` for one session, or persist `[features] terminal_theme = true` and `[ui] theme = "terminal"`.

This is intentionally a compatibility-and-documentation contract rather than automatic configuration. Localized state backgrounds remain acceptable, and the Terminal profile remains the sole owner of full-window opacity and blur.

#### Read-only CLI Discovery

A focused shell helper reports OpenCode, Claude Code, Codex CLI, and Grok Build availability. It uses `command -v` and each command's `--version` only. A missing optional CLI or a failed version query is informational and never makes plugin `status` fail. The helper does not inspect CLI configuration, authentication, tokens, or account state.

## Plugin Actions

Add the following actions while retaining all existing action IDs.

### `setup-dark-glass`

Command:

```text
bash scripts/setup-dark-glass.sh
```

Behavior:

1. Confirm the platform, required files, and safe destination type.
2. Query all four dedicated Terminal cycle profiles as separate argv values before any OpenCode theme mutation.
3. In one visible Terminal import request, open every missing bundled cycle profile.
4. Install the OpenCode theme at `~/.config/opencode/themes/herdr-dark-glass.json` only after Terminal preflight/import succeeds.
5. If the destination differs, back it up under the plugin state directory before replacement.
6. Print the remaining user-controlled actions: select `herdr-dark-glass` through OpenCode `/themes`, select Claude Code `dark-ansi` through `/theme`, run Codex normally, and use the exact Grok terminal-theme enablement instructions.
7. Never write Terminal private preferences; never modify OpenCode TUI configuration, selection state, plugin lists, or unrelated settings; and never modify Claude Code, Codex CLI, or Grok Build configuration.

The action may complete with the Terminal profile import still awaiting user confirmation. `status` provides the authoritative post-import check.

### `apply-dark-glass`

Command:

```text
bash scripts/apply-dark-glass.sh
```

Behavior:

- Reuse `apply-preset.sh` with a new `dark-glass` preset ID.
- Render and validate the complete Herdr configuration before activation.
- Preserve the current backup, baseline, atomic replacement, reload, and rollback guarantees.
- Generalize the current hard-coded `catppuccin-latte` validation so each preset declares its expected base theme.

### `open-dark-glass-window`

Command:

```text
bash scripts/open-dark-glass-window.sh
```

Behavior:

1. Verify that `Herdr Dark Glass Read` exists as a Terminal settings set by default, while permitting the validated profile-name override.
2. If it is missing, exit with a direct instruction to run `setup-dark-glass` and complete the Terminal import.
3. Open a new macOS Terminal window using the dedicated profile.
4. Set the window title and launch Herdr after removing inherited `HERDR_*` pane context.
5. Do not send OSC 11, because the profile's archived background color carries the required alpha.
6. Permit profile name and window title overrides through validated environment variables for testing and advanced use.

### `cycle-dark-glass-opacity`

Command:

```text
bash scripts/cycle-dark-glass-opacity.sh
```

The action passes the four fixed dedicated profile names as separate argv values to one AppleScript call. It verifies every profile exists, changes only the selected tab of the front Terminal window, and cycles Glass → Clear → Read → Focus → Glass. The legacy `Herdr Dark Glass` profile moves to Clear; an unrelated profile moves to Read. It neither opens a window nor changes startup/default Terminal settings, and reports the resulting level and opacity percentage.

### `status`

Extend the current status output with independent checks for:

- Herdr preset state: Social Glass, Island Glass, Dark Glass, or locally modified.
- Count the four dedicated cycle profiles and report `Herdr Dark Glass Read` as the default launcher profile.
- Installation and content match of the OpenCode theme file.
- Detectable OpenCode theme selection when available; otherwise report that selection must be verified in OpenCode rather than claiming success.
- Optional OpenCode, Claude Code, Codex CLI, and Grok Build command availability and sanitized version text.
- Static compatibility guidance for each installed CLI without reading or claiming its selected theme.

A present command whose `--version` exits unsuccessfully is reported as installed with version unavailable. A missing optional CLI is reported as not found and does not change the status exit code.

## Existing Script Changes

### `scripts/apply-preset.sh`

- Recognize `dark-glass`.
- Resolve the expected base theme per preset instead of requiring `catppuccin-latte` globally.
- Keep local title injection and all existing safety behavior.

### `scripts/open-social-window.sh`

Do not overload its current zero-or-two-color interface with opacity concerns. Either reuse it only for shared profile/window launching behavior after a small extraction, or keep the Dark Glass launcher separate. Any refactor must leave Social and Island behavior byte-for-byte equivalent at their external interfaces.

### Documentation and guide

Keep the bilingual README compact while documenting the four Terminal levels, Read as the default, `prefix+u` cycling, and rerunning setup to visibly import missing profiles. Existing customized users must merge the `[[keys.command]]` snippet and must not rerun `apply-dark-glass`, because it can replace their custom keys. The guide renders this README unchanged.

## Error Handling and Configuration Safety

- Missing platform support, source files, profile, or destination directories produces a specific actionable error.
- OpenCode theme installation is idempotent when content already matches.
- A differing existing OpenCode theme is backed up before replacement.
- A failed copy leaves the existing theme untouched.
- Terminal profile import is explicit and user-visible.
- Claude Code, Codex CLI, and Grok Build are never installed, launched by setup, authenticated, or configured by the plugin.
- CLI discovery executes only `command -v` and `--version`; missing commands and failed version reads are informational.
- No source or runtime script reads or writes Claude, Codex, or Grok configuration or credential paths.
- `apply-dark-glass` uses the current atomic config staging and rollback path.
- `restore` continues to restore the first pre-theme Herdr baseline; it does not delete a user-imported Terminal profile or OpenCode theme without an explicit separate action.
- Uninstall documentation explains that the imported Terminal profile and copied OpenCode theme are user configuration and remain until manually removed.

## Test Strategy

### Static smoke tests

- Parse the manifest and assert all existing actions plus the three new Dark Glass actions.
- Parse all three Herdr presets.
- Assert Dark Glass uses the dark base theme and transparent/reset large surfaces.
- Assert Scheme C foreground and accent tokens.
- Parse the OpenCode theme and assert all required theme keys.
- Assert the three main OpenCode backgrounds are `none`.
- Assert README exposes the compact bilingual four-level workflow and exact guidance for OpenCode, Claude Code `dark-ansi`, normal Codex operation, and Grok’s rollout-gated terminal aliases, session command, and persistent configuration.
- Assert runtime scripts do not contain configuration-write paths for Claude Code, Codex CLI, or Grok Build.
- Parse the legacy profile plus all four dedicated profile assets, including their exact opacities, shared blur/palette/font/cursor/selection values, deterministic regeneration, and bright-wallpaper WCAG floors.
- Assert the README exposes the compact bilingual four-level workflow, Read default, `prefix+u`, safe custom-key merge instructions, and exact Grok rollout/session/persistent guidance.
- Run `bash -n` on all shell scripts.
- Resolve a Python interpreter with `tomllib` by preferring `PYTHON_BIN`, then Python 3.13/3.12/3.11/3; fail with an actionable Python 3.11+ test prerequisite instead of silently using macOS Python 3.9.

### Isolated functional tests

Use the existing temporary HOME and mock command pattern to cover:

- Dark Glass apply, status detection, backup, and restore.
- Reload failure rollback.
- First-time OpenCode theme installation.
- Identical theme reinstall as a no-op.
- Differing theme backup before replacement.
- Missing Terminal profile opening the bundled profile.
- Existing Terminal profile avoiding duplicate import.
- Launcher refusal when the profile is absent.
- Launcher selection of the correct profile when present.
- No OSC 11 emission in the Dark Glass launcher.
- CLI status when all four commands return versions, when commands are absent, and when an installed command's version query fails.
- CLI status remaining successful without reading mocked Claude, Codex, or Grok configuration.
- Setup not invoking or configuring optional CLI commands.
- Existing Social and Island launcher behavior remaining unchanged.

### Manual verification

On Herdr `0.9.0`, OpenCode `1.18.31`, Claude Code `2.1.274`, Codex CLI `0.154.0`, and Grok Build `1.0.40`:

1. Run setup and import the dedicated Terminal profile.
2. Apply Dark Glass.
3. Select the OpenCode theme and lock dark mode.
4. In Claude Code, select `dark-ansi` through `/theme`.
5. Run Codex normally without treating `tui.theme` as a transparency control.
6. For Grok, enable terminal themes through the exact session command or the documented persistent configuration; do not expect bare `/theme transparent` to work before rollout enablement.
7. Launch a Dark Glass window.
8. Inspect ordinary shell panes, Herdr sidebar/panels, all four CLI canvases, diffs, dialogs, selections, and third-party TUI extensions.
9. Repeat with forest, dark, and bright wallpapers.
10. Verify that `Clear Light`, `Clear Dark`, Social Glass, and Island Glass remain unchanged.
11. Restore the original Herdr configuration and confirm rollback behavior.

## Acceptance Criteria

- A dedicated `Herdr Dark Glass` Terminal window visibly reveals the desktop wallpaper through a `#080E14` dark veil.
- The legacy profile remains `#080E14`, alpha `0.46`, and blur `0.24`; dedicated Glass/Clear/Read/Focus profiles use alphas `0.46`/`0.60`/`0.74`/`0.88` and Read launches by default.
- Herdr's main panel and sidebar do not paint opaque full-area backgrounds.
- OpenCode's main, panel, and element backgrounds delegate to the terminal.
- Claude Code `dark-ansi`, Codex's default canvas, and Grok's enabled built-in terminal aliases preserve the Terminal-owned full-area background while allowing localized state surfaces.
- Status reports optional CLI availability and versions without making missing CLIs fatal or inspecting private CLI configuration.
- README provides a compact bilingual Glass/Clear/Read/Focus workflow, identifies Read as the launch default, documents `prefix+u` cycling and visible setup imports, and separately gives the shipped OpenCode, Claude Code, Codex, and Grok guidance.
- Primary and muted text remain readable on the reference forest wallpaper.
- Existing Social Glass and Island Glass commands continue to behave as before.
- No action modifies `Clear Light`, `Clear Dark`, Terminal private preferences, or unrelated OpenCode configuration.
- Setup and apply operations are idempotent or safely backed up.
- Automated tests pass, and manual testing confirms the visual result on the target machine.

## Development and Rollout

The Herdr-managed plugin checkout is a detached, replaceable cache and must not be edited. Development occurs in a normal clone on a feature branch. Tests run from that clone first. A linked-plugin switch is performed only after the implementation and tests are ready, because Herdr registrations are keyed by plugin ID and the managed installation must not be assumed to coexist with a local link of the same ID.

The original managed registration remains in place during design and offline test work. Switching to the local linked copy is a separate reversible rollout step and requires preserving the existing plugin configuration and state directories.
