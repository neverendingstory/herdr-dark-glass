#!/usr/bin/env bash
set -euo pipefail
ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
printf '\033[2J\033[H'
printf '\033[1;38;2;114;135;253mHERDR SOCIAL GLASS\033[0m\n'
printf '\033[38;2;108;111;133mA native, plugin-packaged social screenshot preset.\033[0m\n\n'
awk '!/^[[:space:]]*!\[[^]]*\]\(/' "$ROOT/README.md"
printf '\n\033[2mPress any key to close.\033[0m'
IFS= read -r -n 1 _
