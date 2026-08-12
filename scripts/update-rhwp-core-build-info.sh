#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
READ_LOCK="$ROOT/scripts/ci/read-rhwp-core-lock.sh"
BUILD_INFO_COMMON="$ROOT/scripts/ci/rhwp-core-build-info-common.sh"
LOCK_FILE="$ROOT/rhwp-core.lock"
OUTPUT="$ROOT/Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift"
TMP_OUTPUT=""

usage() {
  cat >&2 <<EOF
Usage: $0 [--lock-file FILE] [--output FILE]

Writes deterministic RhwpCoreBuildInfo Swift source from a complete
rhwp-core.lock. Stable tags and demo commit pins are supported.

Options:
  --lock-file FILE  Read FILE instead of the repository rhwp-core.lock.
  --output FILE     Write FILE instead of the repository Swift build info.
EOF
}

cleanup() {
  if [ -n "$TMP_OUTPUT" ] && [ -f "$TMP_OUTPUT" ]; then
    rm -f "$TMP_OUTPUT"
  fi
}
trap cleanup EXIT

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
    --output)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --output requires a path" >&2
        usage
        exit 1
      fi
      OUTPUT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ ! -x "$READ_LOCK" ]; then
  echo "ERROR: missing executable lock reader: $READ_LOCK" >&2
  exit 1
fi

if [ ! -r "$BUILD_INFO_COMMON" ]; then
  echo "ERROR: missing build info common helper: $BUILD_INFO_COMMON" >&2
  exit 1
fi

if [ ! -f "$LOCK_FILE" ]; then
  echo "ERROR: missing lock file: $LOCK_FILE" >&2
  exit 1
fi

# shellcheck source=scripts/ci/rhwp-core-build-info-common.sh
source "$BUILD_INFO_COMMON"
rhwp_build_info_load_lock "$LOCK_FILE" "$READ_LOCK"

OUTPUT_DIR="$(dirname "$OUTPUT")"
if [ ! -d "$OUTPUT_DIR" ]; then
  echo "ERROR: missing output directory: $OUTPUT_DIR" >&2
  exit 1
fi

TMP_OUTPUT="$(mktemp "$OUTPUT.tmp.XXXXXX")"
rhwp_build_info_render_swift > "$TMP_OUTPUT"
chmod 0644 "$TMP_OUTPUT"

if [ -f "$OUTPUT" ] && cmp -s "$TMP_OUTPUT" "$OUTPUT"; then
  echo "OK: $OUTPUT is already up to date with $LOCK_FILE"
  exit 0
fi

mv "$TMP_OUTPUT" "$OUTPUT"
TMP_OUTPUT=""
echo "Updated: $OUTPUT"
