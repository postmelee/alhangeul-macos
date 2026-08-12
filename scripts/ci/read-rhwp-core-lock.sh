#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCK_FILE="$ROOT/rhwp-core.lock"

usage() {
  cat >&2 <<EOF
Usage: $0 [--lock-file FILE] <key>

Reads a top-level scalar value from rhwp-core.lock.

Options:
  --lock-file FILE  Read FILE instead of the repository rhwp-core.lock.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --lock-file)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --lock-file requires a path" >&2
        usage
        exit 1
      fi
      LOCK_FILE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

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

if ! VALUE="$(awk -F' = ' -v key="$KEY" '
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
' "$LOCK_FILE")"; then
  echo "ERROR: missing lock key: $KEY" >&2
  exit 1
fi

if [ -z "$VALUE" ]; then
  echo "ERROR: missing lock key: $KEY" >&2
  exit 1
fi

printf '%s\n' "$VALUE"
