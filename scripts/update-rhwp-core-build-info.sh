#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
READ_LOCK="$ROOT/scripts/ci/read-rhwp-core-lock.sh"
VERIFY_BUILD_INFO="$ROOT/scripts/verify-rhwp-core-build-info.sh"
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

if [ ! -x "$VERIFY_BUILD_INFO" ]; then
  echo "ERROR: missing executable build info verifier: $VERIFY_BUILD_INFO" >&2
  exit 1
fi

if [ ! -f "$LOCK_FILE" ]; then
  echo "ERROR: missing lock file: $LOCK_FILE" >&2
  exit 1
fi

lock_scalar() {
  "$READ_LOCK" --lock-file "$LOCK_FILE" "$1"
}

validate_release_tag() {
  local key="$1"
  local value="$2"
  if ! [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._+/:~-]*$ ]]; then
    echo "ERROR: invalid $key in $LOCK_FILE: $value" >&2
    exit 1
  fi
}

validate_commit() {
  local value="$1"
  if ! [[ "$value" =~ ^[0-9a-f]{40}$ ]]; then
    echo "ERROR: invalid rhwp_commit in $LOCK_FILE: $value" >&2
    exit 1
  fi
}

validate_enabled_features() {
  local value="$1"
  if ! [[ "$value" =~ ^[A-Za-z0-9_-]+(,[A-Za-z0-9_-]+)*$ ]]; then
    echo "ERROR: invalid rhwp_enabled_features in $LOCK_FILE: $value" >&2
    exit 1
  fi
}

lock_version="$(lock_scalar lock_version)"
if [ "$lock_version" != "2" ]; then
  echo "ERROR: unsupported rhwp-core.lock version: ${lock_version:-missing}" >&2
  echo "Expected: 2" >&2
  exit 1
fi

ref_kind="$(lock_scalar rhwp_ref_kind)"
case "$ref_kind" in
  release-tag)
    release_tag_key="rhwp_release_tag"
    ;;
  commit)
    release_tag_key="rhwp_latest_checked_release_tag"
    ;;
  *)
    echo "ERROR: unsupported rhwp_ref_kind in $LOCK_FILE: $ref_kind" >&2
    exit 1
    ;;
esac

release_tag="$(lock_scalar "$release_tag_key")"
commit="$(lock_scalar rhwp_commit)"
enabled_features="$(lock_scalar rhwp_enabled_features)"

validate_release_tag "$release_tag_key" "$release_tag"
validate_commit "$commit"
validate_enabled_features "$enabled_features"

OUTPUT_DIR="$(dirname "$OUTPUT")"
if [ ! -d "$OUTPUT_DIR" ]; then
  echo "ERROR: missing output directory: $OUTPUT_DIR" >&2
  exit 1
fi

TMP_OUTPUT="$(mktemp "$OUTPUT.tmp.XXXXXX")"
{
  echo 'enum RhwpCoreBuildInfo {'
  echo "    static let releaseTag = \"$release_tag\""
  echo "    static let commit = \"$commit\""
  echo "    static let enabledFeatures = \"$enabled_features\""
  echo '}'
} > "$TMP_OUTPUT"
chmod 0644 "$TMP_OUTPUT"
"$VERIFY_BUILD_INFO" --lock-file "$LOCK_FILE" --build-info "$TMP_OUTPUT" >/dev/null

if [ -f "$OUTPUT" ] && cmp -s "$TMP_OUTPUT" "$OUTPUT"; then
  echo "OK: RhwpCoreBuildInfo is already up to date: $OUTPUT"
  exit 0
fi

mv "$TMP_OUTPUT" "$OUTPUT"
TMP_OUTPUT=""
echo "Updated: $OUTPUT"
