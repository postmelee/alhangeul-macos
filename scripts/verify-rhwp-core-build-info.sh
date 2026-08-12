#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
READ_LOCK="$ROOT/scripts/ci/read-rhwp-core-lock.sh"
BUILD_INFO_COMMON="$ROOT/scripts/ci/rhwp-core-build-info-common.sh"
LOCK_FILE="$ROOT/rhwp-core.lock"
BUILD_INFO="$ROOT/Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift"
EXPECTED_BUILD_INFO=""

usage() {
  cat >&2 <<EOF
Usage: $0 [--lock-file FILE] [--build-info FILE]

Verifies that Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift mirrors the
current rhwp-core.lock release baseline, resolved commit, and enabled features.

Options:
  --lock-file FILE  Read FILE instead of the repository rhwp-core.lock.
  --build-info FILE Verify FILE instead of the repository Swift build info.
EOF
}

cleanup() {
  if [ -n "$EXPECTED_BUILD_INFO" ] && [ -f "$EXPECTED_BUILD_INFO" ]; then
    rm -f "$EXPECTED_BUILD_INFO"
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
    --build-info)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --build-info requires a path" >&2
        usage
        exit 1
      fi
      BUILD_INFO="$2"
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

if [ ! -f "$BUILD_INFO" ]; then
  echo "ERROR: missing Swift build info: $BUILD_INFO" >&2
  exit 1
fi

# shellcheck source=scripts/ci/rhwp-core-build-info-common.sh
source "$BUILD_INFO_COMMON"
rhwp_build_info_load_lock "$LOCK_FILE" "$READ_LOCK"

EXPECTED_BUILD_INFO="$(mktemp "${TMPDIR:-/tmp}/rhwp-core-build-info-verify.XXXXXX")"
rhwp_build_info_render_swift > "$EXPECTED_BUILD_INFO"

if ! cmp -s "$BUILD_INFO" "$EXPECTED_BUILD_INFO"; then
  echo "ERROR: $BUILD_INFO is not the canonical build info for $LOCK_FILE" >&2
  diff -u "$BUILD_INFO" "$EXPECTED_BUILD_INFO" >&2 || true
  echo "Update: $ROOT/scripts/update-rhwp-core-build-info.sh --lock-file $LOCK_FILE --output $BUILD_INFO" >&2
  exit 1
fi

echo "OK: $BUILD_INFO matches $LOCK_FILE"
