# Herdr Social Glass

A screenshot-friendly light glass preset packaged as a local Herdr 0.8.0 plugin.
It uses only Herdr's built-in Catppuccin Latte theme and macOS Terminal's existing
`Clear Light` profile. It installs no third-party runtime or theme dependency.

## Visual system

- translucent outer Terminal surface with native macOS blur and rounded chrome
- Catppuccin Latte UI with a lavender accent
- transparent Herdr panel background so the outer glass surface remains visible
- clean pane gaps and borders, no pane scrollbars
- top tab bar and a fully hidden collapsed sidebar
- two-line agent/workspace cards when the sidebar is expanded

## Actions

```bash
herdr plugin action invoke apply --plugin linyu.social-glass
herdr plugin action invoke open-window --plugin linyu.social-glass
herdr plugin action invoke status --plugin linyu.social-glass
herdr plugin action invoke restore --plugin linyu.social-glass
```

Open the in-Herdr guide:

```bash
herdr plugin pane open --plugin linyu.social-glass --entrypoint guide
```

## Local installation

```bash
herdr plugin link ~/projects/herdr-social-glass
```

The first `apply` action saves the current Herdr config as the restore baseline.
Every later apply/restore action also creates a timestamped backup in the plugin
state directory. The preset replaces `~/.config/herdr/config.toml` intentionally;
use the restore action to return to the baseline.

## Screenshot recipe

1. Open the Social Glass Terminal window.
2. Keep at most two panes visible; use `Ctrl+B`, then `Z` for a single-pane feature shot.
3. Use `Ctrl+B`, then `B` when the expanded agent sidebar adds useful context.
4. Capture with 8–12% of the colorful desktop visible outside the window.
5. Avoid raw logs, secrets, compaction notices, and very long paths in the frame.
6. Increase Terminal text size once or twice before captures intended for mobile feeds.

## Files

- `theme/social-glass.toml` — portable Herdr preset
- `scripts/apply.sh` — validate, back up, apply, and reload
- `scripts/restore.sh` — restore the original baseline
- `scripts/open-social-window.sh` — open Terminal with the `Clear Light` profile
- `scripts/status.sh` — report whether the preset is active
- `scripts/guide.sh` — popup guide inside Herdr
