#!/usr/bin/env bash
set -euo pipefail

ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
exec bash "$ROOT/scripts/apply-preset.sh" dark-glass
