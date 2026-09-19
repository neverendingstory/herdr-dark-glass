# Herdr Social Glass

Herdr Social Glass 1.2 provides **three screenshot-friendly presets** for Herdr on macOS. Social and Island existing visuals and launch behavior remain unchanged. Dark Glass coordinates the Terminal, Herdr, and CLI layers into one dark, transparent workspace without taking ownership of your CLI configuration.

![Herdr Social Glass workspace](assets/social-glass-workspace.jpg)

## Manual 1 — macOS Terminal

### Requirements and install

- macOS and Herdr 0.8.2 or newer (protocol 20)
- macOS Terminal
- Bash and AppleScript, both included with macOS
- A dedicated Terminal profile named **Herdr Dark Glass** for the Dark Glass preset

OpenCode, Claude Code, Codex CLI, and Grok Build are optional; none is required to use the presets or to run setup.

Review the trust and configuration notes below, then install this delivery repository:

```bash
herdr plugin install neverendingstory/herdr-dark-glass
```

### Terminal ownership and Dark Glass profile

Terminal is the sole owner of the window alpha, blur, and ANSI palette. Dark Glass uses the dedicated `Herdr Dark Glass` profile rather than changing a shared profile:

- background `#080E14`
- 46% background opacity, which is **54% transparent**
- `BackgroundBlur = 0.24`, the native Terminal-profile value, not a 24px equivalent
- Dark Glass ANSI colors and its matching text, cursor, and selection colors

Run `setup-dark-glass` from the plugin actions to check for that profile. If it is missing, setup opens the bundled profile visibly for an explicit Terminal import; it does not silently import it. Setup never changes `Clear Light`, `Clear Dark`, or private Terminal defaults. After importing, run `status` to verify that Terminal reports the profile as installed.

For a bright or highly detailed wallpaper, raise opacity only in your imported `Herdr Dark Glass` profile. Keep the bundled profile unchanged so the distributed preset remains reproducible. To remove the profile manually, open **Terminal Settings**, choose **Profiles**, select `Herdr Dark Glass`, and remove it there.

Terminal is still a terminal grid: it cannot provide AppKit vibrancy, per-pane blur, or card blur. Localized opaque active rows, selections, dialogs, and third-party surfaces can remain visible, especially when an application paints its own background.

## Manual 2 — Herdr

### Quick start

Run these actions in this exact order for Dark Glass:

```bash
herdr plugin action invoke setup-dark-glass --plugin linyu.social-glass
herdr plugin action invoke apply-dark-glass --plugin linyu.social-glass
herdr plugin action invoke status --plugin linyu.social-glass
herdr plugin action invoke open-dark-glass-window --plugin linyu.social-glass
```

The first command makes the Terminal profile and OpenCode theme asset available; it does not select a CLI theme, authenticate, launch, install, or upgrade an optional CLI. The next command applies the Herdr preset, `status` reports what is saved, and the final command opens a Terminal window only after confirming that the Dark Glass profile exists.

### Daily use with a zsh alias

After completing the one-time setup and apply workflow above, add this alias to `~/.zshrc`:

```zsh
alias herdrdg='herdr plugin action invoke open-dark-glass-window --plugin linyu.social-glass'
```

Reload the shell configuration and launch Dark Glass:

```zsh
source ~/.zshrc
herdrdg
```

`herdrdg` launches only the verified Dark Glass Terminal profile and starts Herdr; it deliberately does not run setup or apply again. `apply-dark-glass` replaces the complete Herdr configuration and can remove custom keybindings, so back up or merge personal settings before intentionally reapplying the preset.

### All nine actions

```bash
herdr plugin action invoke apply --plugin linyu.social-glass
herdr plugin action invoke apply-island --plugin linyu.social-glass
herdr plugin action invoke apply-dark-glass --plugin linyu.social-glass
herdr plugin action invoke setup-dark-glass --plugin linyu.social-glass
herdr plugin action invoke restore --plugin linyu.social-glass
herdr plugin action invoke open-window --plugin linyu.social-glass
herdr plugin action invoke open-island-window --plugin linyu.social-glass
herdr plugin action invoke open-dark-glass-window --plugin linyu.social-glass
herdr plugin action invoke status --plugin linyu.social-glass
```

- `apply` validates and applies the original Social Glass preset.
- `apply-island` validates and applies the original Island Glass preset.
- `apply-dark-glass` validates and applies the Dark Glass Herdr preset.
- `setup-dark-glass` preflights Terminal before theme mutation; if the dedicated profile is absent it opens a visible import, and it installs the bundled OpenCode theme asset without selecting it.
- `restore` restores the first pre-theme Herdr configuration baseline when one exists.
- `open-window` opens Terminal using the unchanged `Clear Light` profile and starts Herdr.
- `open-island-window` opens the same unchanged `Clear Light` profile with an Island title and per-window OSC 10/11 defaults for soil-brown text (`#5B4636`) on warm cream (`#F8F4E8`); it persists neither color.
- `open-dark-glass-window` verifies the dedicated Terminal profile, then opens it and starts Herdr with the Dark Glass title.
- `status` reports the active Herdr preset or a local modification, Terminal-profile availability, the OpenCode asset state, a saved OpenCode preference, and non-invasive CLI compatibility information.

### What setup and apply preserve

`setup-dark-glass` installs the OpenCode theme at its actual XDG discovery path:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/opencode/themes/herdr-dark-glass.json
```

With the default XDG configuration, that is `~/.config/opencode/themes/herdr-dark-glass.json`. If a different file already occupies that path, setup saves a timestamped private backup in the plugin state before atomically replacing it. An identical installed theme is left alone. Setup never writes OpenCode `tui.json`, `tui.jsonc`, a plugin list, or a theme selection.

All three apply actions validate the fully rendered configuration with Herdr before replacing the active configuration. They preserve the original pre-theme baseline on the first applicable run, make timestamped backups on later runs, and use atomic replacement. They ask Herdr to reload; if that reload fails, they immediately restore the preceding configuration (or remove a newly created configuration) and request a rollback reload.

`restore` first backs up the current configuration, then copies the original baseline back as the complete Herdr configuration and reloads it. If no baseline was captured, restore is unavailable. Restore does not remove the Terminal profile or the OpenCode theme asset. Restore before uninstalling the plugin if you want the prior Herdr configuration back; then remove `Herdr Dark Glass` manually in Terminal Settings and, if desired, remove the OpenCode theme file manually. Inspect any timestamped OpenCode theme backup in the plugin state before deleting it.

### Local title and Dark Glass overrides

One optional `window-title.txt` in the plugin configuration directory returned by `herdr plugin config-dir linyu.social-glass` applies a non-empty, single-line title (maximum 120 bytes and no control characters) to all three presets. It is escaped as TOML data, never sourced.

`HERDR_DARK_GLASS_TERMINAL_PROFILE` may override the profile name used by Dark Glass setup, status, and launch; `HERDR_DARK_GLASS_WINDOW_TITLE` applies only to the Dark Glass launch. The launcher requires both values to be non-empty single lines of at most 120 bytes with no control characters and rejects invalid launch values before invoking Terminal. The Social launcher sends no color overrides, while the Island OSC behavior above remains unchanged.

### Trust, security, and configuration safety

A Herdr plugin can execute local commands. This plugin runs the readable shell scripts in [`scripts/`](scripts/) and uses AppleScript only to query or open macOS Terminal windows. Inspect the manifest and scripts before installing if you do not trust the source. The plugin has no third-party runtime or theme dependency and does not request network credentials.

The apply actions intentionally replace the **entire** Herdr configuration rather than merging individual keys. Backups are local copies of the full Herdr configuration and may contain the same private values as that configuration; protect and remove them according to your own local security policy.

## Manual 3 — CLI inside Herdr Dark Glass

The plugin installs only the OpenCode theme asset. CLI theme choices remain user-owned: make them inside panes running in the Dark Glass Terminal profile.

### OpenCode

Run OpenCode in a Dark Glass pane, use `/themes` to choose `herdr-dark-glass`, then lock dark mode. The theme deliberately leaves terminal-owned backgrounds transparent where OpenCode permits it.

`status` can report only the saved preference from the XDG state file `kv.json`; it always tells you to verify active theme in OpenCode with `/themes`. It never reads or writes `tui.json`, `tui.jsonc`, a plugin list, or a theme selection. A saved preference is not proof of the active theme.

### Claude Code

Run `claude`, then use `/theme` and choose the built-in `dark-ansi` theme. Terminal owns the overall canvas, although Claude Code can retain localized backgrounds. The plugin does not read or write Claude Code settings or credentials.

### Codex CLI

Run `codex` normally. Its full viewport remains terminal-owned. `tui.theme` controls syntax coloring only, and `tui.alternate_screen` controls the buffer only; neither controls the terminal background. The plugin does not access Codex configuration or credentials.

### Grok Build

Use `/theme transparent`. The equivalent aliases are `terminal`, `terminal-default`, `transparent`, and `native`. For one terminal-themed session, run exactly:

```bash
GROK_TERMINAL_THEME=1 GROK_THEME=terminal grok
```

If transparency is unsuitable, use the exact fallback:

```bash
grok --minimal
```

The plugin does not access Grok Build configuration or credentials. Third-party extensions in any CLI can paint localized backgrounds.

### CLI compatibility status and tested baselines

The CLI compatibility portion of `status` locates optional commands with `command -v` and invokes each resolved executable only with `--version`; an absent command or failed version invocation is nonfatal. The plugin scripts do not intentionally install, upgrade, authenticate, start an interactive CLI session, or rewrite CLI configuration. Because `--version` still executes the installed CLI or PATH shim, that subprocess's own behavior remains the responsibility of the CLI provider and is not controlled or guaranteed by this plugin.

These are tested baselines, not minimum versions:

- OpenCode 1.18.31
- Claude Code 2.1.274
- Codex CLI 0.154.0
- Grok Build 1.0.34

Herdr's minimum remains 0.8.2. Social/Island unchanged: the existing Social and Island presets, their visuals, and their launch behavior continue without Dark Glass CLI setup.

### Local tests and project files

From the repository root:

```bash
bash tests/smoke.sh
bash tests/functional.sh
bash -n scripts/*.sh
git diff --check
```

The smoke suite parses all three themes and all nine actions, keeps the hardened static scanner, and focuses on Dark Glass assets, setup, launcher, and CLI compatibility tests. The isolated functional suite covers the three apply paths, title validation, status, rollback, baseline restore, OpenCode state reporting, and the preserved Island OSC behavior without touching the live Herdr configuration.

- `herdr-plugin.toml` — plugin metadata, nine actions, and guide entry point
- `theme/social-glass.toml`, `theme/island-glass.toml`, `theme/dark-glass.toml` — the three Herdr presets
- `scripts/apply-preset.sh` and `scripts/apply.sh`, `scripts/apply-island.sh`, `scripts/apply-dark-glass.sh` — safe preset wrappers and application path
- `scripts/setup-dark-glass.sh` and `scripts/open-dark-glass-window.sh` — Dark Glass setup and verified launcher
- `scripts/open-social-window.sh`, `scripts/open-island-window.sh`, `scripts/restore.sh`, `scripts/status.sh` — existing launch, restore, and status helpers
- `profiles/Herdr Dark Glass.terminal` and `tools/build-terminal-profile.py` — reproducible Terminal profile and generator
- `integrations/opencode/herdr-dark-glass.json` — bundled OpenCode theme asset
- `scripts/cli-compat-status.sh` and its focused tests — read-only optional-CLI reporting
- `tests/smoke.sh`, `tests/functional.sh`, `tests/dark-glass-assets.py`, `tests/dark-glass-setup.sh`, `tests/dark-glass-launcher.sh`, `tests/cli-compat-status.sh` — static and isolated behavioral coverage

### License

MIT. See [LICENSE](LICENSE).
