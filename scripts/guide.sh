#!/usr/bin/env bash
set -euo pipefail
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
printf '\033[2J\033[H'
printf '\033[1;38;2;79;125;42mHERDR SOCIAL GLASS 1.1\033[0m\n'
printf '\033[38;2;91;70;54mSocial Glass + Island Glass native workspace presets.\033[0m\n\n'
awk '!/^[[:space:]]*!\[[^]]*\]\(/' "$ROOT/README.md"
printf '\n\033[2mPress any key to close.\033[0m'
IFS= read -r -n 1 _
