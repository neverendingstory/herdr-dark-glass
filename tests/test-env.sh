#!/usr/bin/env bash

find_python_with_tomllib() {
  local resolved
  local candidate

  if [[ -n "${PYTHON_BIN:-}" ]]; then
    resolved="$(command -v "$PYTHON_BIN" 2>/dev/null || true)"
    if [[ -n "$resolved" ]] && "$PYTHON_BIN" -c 'import sys, tomllib; raise SystemExit(sys.version_info < (3, 11))' >/dev/null 2>&1; then
      printf '%s\n' "$resolved"
      return 0
    fi
    printf 'PYTHON_BIN does not provide tomllib: %s\n' "$PYTHON_BIN" >&2
    return 1
  fi

  for candidate in python3.13 python3.12 python3.11 python3; do
    resolved="$(command -v "$candidate" 2>/dev/null || true)"
    if [[ -n "$resolved" ]] && "$candidate" -c 'import sys, tomllib; raise SystemExit(sys.version_info < (3, 11))' >/dev/null 2>&1; then
      printf '%s\n' "$resolved"
      return 0
    fi
  done

  printf 'Python 3.11+ with tomllib is required to run the test suite.\n' >&2
  return 1
}
