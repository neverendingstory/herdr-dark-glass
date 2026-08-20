#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for script in "$ROOT"/scripts/*.sh; do
  bash -n "$script"
done
python3 - "$ROOT/herdr-plugin.toml" "$ROOT/theme/social-glass.toml" <<'PY'
import sys, tomllib
manifest = tomllib.load(open(sys.argv[1], "rb"))
theme = tomllib.load(open(sys.argv[2], "rb"))
assert manifest["id"] == "linyu.social-glass"
assert manifest["version"] == "1.0.0"
assert manifest["min_herdr_version"] == "0.8.0"
assert manifest["platforms"] == ["macos"]
assert len(manifest["actions"]) == 4
assert theme["theme"]["name"] == "catppuccin-latte"
assert theme["theme"]["custom"]["panel_bg"] == "reset"
assert theme["ui"]["sidebar_collapsed_mode"] == "hidden"
assert theme["ui"]["tab_bar_position"] == "top"
PY
printf 'smoke tests passed\n'
