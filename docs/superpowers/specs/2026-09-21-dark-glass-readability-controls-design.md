# Dark Glass Readability Controls Design

**Date:** 2026-09-21

## Goal

Make long-form Markdown consistently readable without giving up Dark Glass, while keeping macOS Terminal as the sole owner of window opacity. Users can cycle four opacity levels with `prefix+u`; the default launch uses the balanced Read level.

## Evidence and diagnosis

The current Terminal profile uses `#080E14` at 46% opacity. Its opaque contrast is already excellent: primary text `#F5F3ED` against `#080E14` is `17.47:1`. The background hue is therefore not the defect.

Two independent contrast failures remain:

1. On a bright desktop, 46% opacity composites to approximately `#8D9093`, reducing primary-text contrast to `2.89:1`. Raising opacity to 60%, 74%, and 88% raises that stress-case ratio to `4.62:1`, `7.71:1`, and `12.87:1` respectively.
2. Glow maps block quotes, H6 headings, rules, and other secondary Markdown text to ANSI bright black. Dark Glass currently maps that slot to `#48524D`, which is only `2.39:1` against the opaque base and `1.76:1` in the 88% bright-backdrop stress case. The canonical Dark Glass muted text `#B9BEB9` yields `10.27:1` against the base and `7.57:1` in that 88% stress case.

The file viewer has one separate fixed-color defect: code comments use `#676767` on `#373737` (`2.10:1`). Changing comments and generic subheadings to `#A0A0A0` raises them to `4.55:1` without coupling the viewer to Dark Glass.

## Scope

### Dark Glass repository

Repository: `/Users/jachael/Documents/byMySide/herdr-dark-glass`

- Add four dedicated Terminal profiles, all using the corrected ANSI bright-black value `#B9BEB9`:
  - `Herdr Dark Glass Glass` — 46% opacity
  - `Herdr Dark Glass Clear` — 60% opacity
  - `Herdr Dark Glass Read` — 74% opacity, the default
  - `Herdr Dark Glass Focus` — 88% opacity
- Retain the existing `Herdr Dark Glass` profile as a legacy compatibility profile; it is not part of the four-level cycle.
- Add a `cycle-dark-glass-opacity` plugin action.
- Bind that action to `prefix+u` in the distributed Dark Glass Herdr preset and document the equivalent custom-command snippet for existing customized configurations.
- Update setup, status, launcher behavior, README, tests, and bump the manifest from `1.2.0` to `1.3.0` for the additive feature.

### herdr-file-viewer repository

Repository: `/Users/jachael/Documents/byMySide/herdr-file-viewer`

- Work from a clean branch based on `main`, never from the existing `feat/global-content-search` commit.
- Raise fixed code-comment and generic-subheading colors in `assets/markdown-style.json` from their low-contrast values to `#A0A0A0`.
- Add a deterministic WCAG contrast regression test, a changelog entry, and the relevant renderer documentation update.
- Push the branch to the repository's existing `origin`; because `main` is protected, publish this part through a PR rather than pushing directly to `main`.

## Dark Glass architecture

### Profile generation

`tools/build-terminal-profile.py` becomes data-driven over a small fixed table of profile name and opacity. A shared palette builder prevents the four files from drifting. Every generated profile keeps:

- background hue `#080E14`;
- blur `0.24`;
- primary text `#F5F3ED`;
- ANSI bright black `#B9BEB9`;
- all other existing Dark Glass colors, font, cursor, and selection settings.

The four generated `.terminal` files are committed assets. The legacy profile remains available for callers that explicitly set `HERDR_DARK_GLASS_TERMINAL_PROFILE=Herdr Dark Glass`.

### Setup and launch

`setup-dark-glass` checks all four profile names. Missing profiles are opened visibly for explicit Terminal import, preserving the existing no-silent-import policy. It never changes Terminal's default or startup profile.

`open-dark-glass-window` defaults to `Herdr Dark Glass Read`. The existing environment override remains supported. It delegates to the already-correct profile-from-birth launcher, so a new window never starts under `Clear Dark`.

### Opacity cycle

A new script, invoked by the plugin action, asks Terminal for the selected tab of the front window and reads that tab's current settings-set name.

- Glass → Clear
- Clear → Read
- Read → Focus
- Focus → Glass
- Legacy `Herdr Dark Glass` → Clear
- Any unrelated profile → Read

Before switching, the script verifies that all four profiles exist. It then changes only the selected tab's `current settings`; it does not call `defaults`, change Terminal's `default settings` or `startup settings`, open a window, or persist a separate state file. The current profile name is the cycle state.

The visible opacity change is the feedback; no macOS notification or title mutation is added.

### Herdr binding

The distributed Dark Glass preset contains:

```toml
[[keys.command]]
key = "prefix+u"
type = "shell"
command = "herdr plugin action invoke cycle-dark-glass-opacity --plugin linyu.social-glass"
```

`prefix+u` is currently unassigned in Herdr's default keymap. `prefix+j` and `prefix+k` remain the default pane-down and pane-up navigation keys.

Setup does not rewrite an existing user's Herdr configuration. Existing customized installations receive the same snippet in the README and can merge it without running `apply-dark-glass` and losing personal keybindings. For this machine, deployment may add exactly this command after backing up the current config and preserving every unrelated setting.

## Error handling

- Non-macOS execution fails with an actionable message.
- Missing profile assets or missing imported settings sets fail before any tab is changed and tell the user to run setup and complete import.
- AppleScript query or switch failure exits nonzero and names the failed operation.
- An unrelated current Terminal profile is never treated as a cycle member; the first invocation selects the safe Read default.
- No partial profile mutation is possible because switching selects an already-imported settings set atomically.

## Testing

### Dark Glass

Tests are written first and must fail against current behavior. They cover:

- generated profile names, opacity values, `#080E14`, blur `0.24`, and corrected ANSI bright black;
- setup opening every missing profile asset without invoking optional CLIs or private TUI state;
- default launch selecting `Herdr Dark Glass Read` from tab creation onward;
- every cycle transition, legacy/unrelated-profile behavior, missing-profile failure, and exact AppleScript argument boundaries;
- no `defaults` command, no startup/default-profile mutation, no extra window creation, and no persistent cycle state;
- manifest action and `prefix+u` preset wiring;
- README commands and four-level documentation;
- the existing smoke, functional, setup, launcher, syntax, and whitespace checks.

The static contrast loop remains the acceptance signal:

- primary text at Read/74% over a white stress backdrop: at least `7:1`;
- corrected muted text at Read/74%: at least `4.5:1`;
- corrected muted text at Focus/88%: at least `7:1`.

### herdr-file-viewer

A focused regression reads the bundled Markdown style, parses its fixed colors, and asserts comments and generic subheadings meet at least `4.5:1` against the code-block background. Then run the focused test, `cargo test`, `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, and `cargo audit`.

## Non-goals

- Herdr does not own or mutate Terminal opacity directly.
- No private Terminal preferences database or `defaults write` is used.
- No automatic rewrite of customized Herdr or file-viewer configuration occurs.
- The Dark Glass plugin does not ship a private replacement Glow style.
- The OpenCode `sub-openai` provider loop diagnosed during this work is separate from the visual feature and is not changed by this design.
