#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCK_FILE="$ROOT/rhwp-core.lock"

usage() {
  cat >&2 <<EOF
Usage: $0 <key>

Reads a top-level scalar value from rhwp-core.lock.
EOF
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

KEY="$1"

if ! [[ "$KEY" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "ERROR: invalid lock key: $KEY" >&2
  exit 1
fi

if [ ! -f "$LOCK_FILE" ]; then
  echo "ERROR: missing lock file: $LOCK_FILE" >&2
  exit 1
fi

VALUE="$(awk -F' = ' -v key="$KEY" '
  $1 == key {
    value = $2
    gsub(/^"/, "", value)
    gsub(/"$/, "", value)
    print value
    found = 1
    exit
  }
  END {
    if (!found) {
      exit 2
    }
  }
' "$LOCK_FILE")"

if [ -z "$VALUE" ]; then
  echo "ERROR: missing lock key: $KEY" >&2
  exit 1
fi

printf '%s\n' "$VALUE"
