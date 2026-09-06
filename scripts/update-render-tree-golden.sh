#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/verify-render-tree-golden.sh" --check-environment >/dev/null
exec python3 "$ROOT/scripts/ci/render-tree-golden.py" update "$@"
