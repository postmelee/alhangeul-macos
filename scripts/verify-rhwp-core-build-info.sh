#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
READ_LOCK="$ROOT/scripts/ci/read-rhwp-core-lock.sh"
BUILD_INFO="$ROOT/Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift"

usage() {
  cat >&2 <<EOF
Usage: $0

Verifies that Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift mirrors the
current rhwp-core.lock release tag, resolved commit, and enabled features.
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 0 ]; then
  usage
  exit 1
fi

if [ ! -x "$READ_LOCK" ]; then
  echo "ERROR: missing executable lock reader: $READ_LOCK" >&2
  exit 1
fi

if [ ! -f "$BUILD_INFO" ]; then
  echo "ERROR: missing Swift build info: $BUILD_INFO" >&2
  exit 1
fi

swift_scalar() {
  local key="$1"
  awk -v key="$key" '
    $0 ~ "static[[:space:]]+let[[:space:]]+" key "[[:space:]]*=" {
      value = $0
      sub(/^.*=[[:space:]]*"/, "", value)
      sub(/".*$/, "", value)
      print value
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 2
      }
    }
  ' "$BUILD_INFO"
}

compare_scalar() {
  local lock_key="$1"
  local swift_key="$2"
  local expected
  local actual

  expected="$("$READ_LOCK" "$lock_key")"
  if ! actual="$(swift_scalar "$swift_key")"; then
    echo "ERROR: missing RhwpCoreBuildInfo.$swift_key in $BUILD_INFO" >&2
    exit 1
  fi

  if [ "$expected" != "$actual" ]; then
    echo "ERROR: RhwpCoreBuildInfo.$swift_key differs from rhwp-core.lock" >&2
    echo "Lock key:       $lock_key" >&2
    echo "Expected value: $expected" >&2
    echo "Actual value:   $actual" >&2
    echo "Update:         $BUILD_INFO" >&2
    exit 1
  fi
}

compare_scalar rhwp_release_tag releaseTag
compare_scalar rhwp_commit commit
compare_scalar rhwp_enabled_features enabledFeatures

echo "OK: RhwpCoreBuildInfo matches rhwp-core.lock"
