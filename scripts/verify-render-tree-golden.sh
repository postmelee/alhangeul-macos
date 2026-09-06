#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: render tree golden requires Python 3.11 or later; python3 was not found in PATH" >&2
  exit 1
fi
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'; then
  echo "ERROR: render tree golden requires Python 3.11 or later; select a compatible python3 in PATH" >&2
  exit 1
fi
if [ "${1:-}" = "--check-environment" ]; then
  if [ "$#" -ne 1 ]; then
    echo "ERROR: --check-environment takes no additional arguments" >&2
    exit 2
  fi
  echo "OK: golden Python prerequisite satisfied"
  exit 0
fi
exec python3 "$ROOT/scripts/ci/render-tree-golden.py" verify "$@"
