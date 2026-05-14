#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CASK_PATH="$ROOT/Casks/alhangeul.rb"
DRY_RUN=0
VERSION=""
CHECKSUM_FILE=""

usage() {
  cat <<EOF
Usage: $0 [--dry-run] <version> [checksum-file]

Updates Casks/alhangeul.rb with the given version and the sha256 from
the public DMG checksum file. If checksum-file is omitted, the script reads:

  build.noindex/release/alhangeul-macos-<version>.dmg.sha256

Options:
  --dry-run    Validate inputs and print the planned update without editing.
  -h, --help   Show this help.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        fail "unknown option: $1"
        ;;
      *)
        if [ -z "$VERSION" ]; then
          VERSION="$1"
        elif [ -z "$CHECKSUM_FILE" ]; then
          CHECKSUM_FILE="$1"
        else
          fail "unexpected argument: $1"
        fi
        ;;
    esac
    shift
  done

  if [ -z "$VERSION" ]; then
    usage >&2
    exit 1
  fi

  if ! [[ "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
    fail "version must look like semantic version, got: $VERSION"
  fi

  if [ -z "$CHECKSUM_FILE" ]; then
    CHECKSUM_FILE="$ROOT/build.noindex/release/alhangeul-macos-$VERSION.dmg.sha256"
  elif [[ "$CHECKSUM_FILE" != /* ]]; then
    CHECKSUM_FILE="$ROOT/$CHECKSUM_FILE"
  fi
}

read_checksum() {
  if [ ! -f "$CHECKSUM_FILE" ]; then
    fail "checksum file not found: $CHECKSUM_FILE"
  fi

  local checksum_basename
  checksum_basename="$(basename "$CHECKSUM_FILE")"
  case "$checksum_basename" in
    *rehearsal*)
      fail "refusing to update Homebrew Cask from rehearsal checksum: $checksum_basename"
      ;;
  esac

  local checksum_line
  checksum_line="$(sed -n '1p' "$CHECKSUM_FILE")"
  SHA256="$(printf '%s\n' "$checksum_line" | awk '{print tolower($1)}')"
  CHECKSUM_DMG_NAME="$(printf '%s\n' "$checksum_line" | awk '{print $2}')"

  if ! [[ "$SHA256" =~ ^[0-9a-f]{64}$ ]]; then
    fail "checksum file does not start with a valid sha256: $CHECKSUM_FILE"
  fi

  local expected_dmg_name
  expected_dmg_name="alhangeul-macos-$VERSION.dmg"
  if [ -n "$CHECKSUM_DMG_NAME" ] && [ "$CHECKSUM_DMG_NAME" != "$expected_dmg_name" ]; then
    fail "checksum file references $CHECKSUM_DMG_NAME, expected $expected_dmg_name"
  fi
}

validate_cask_shape() {
  if [ ! -f "$CASK_PATH" ]; then
    fail "Cask file not found: $CASK_PATH"
  fi
  if ! grep -Eq '^  version "[^"]+"$' "$CASK_PATH"; then
    fail "Cask version line not found or unsupported"
  fi
  if ! grep -Eq '^  sha256 (:[a-z_]+|"[0-9a-fA-F]{64}")$' "$CASK_PATH"; then
    fail "Cask sha256 line not found or unsupported"
  fi
}

update_cask() {
  echo "Cask: ${CASK_PATH#"$ROOT"/}"
  echo "Version: $VERSION"
  echo "SHA256: $SHA256"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run: no files changed."
    return
  fi

  local tmp
  tmp="$(mktemp "$CASK_PATH.tmp.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT

  awk -v version="$VERSION" -v sha256="$SHA256" '
    /^  version "/ {
      print "  version \"" version "\""
      version_count += 1
      next
    }
    /^  sha256 / {
      print "  sha256 \"" sha256 "\""
      sha_count += 1
      next
    }
    { print }
    END {
      if (version_count != 1 || sha_count != 1) {
        exit 2
      }
    }
  ' "$CASK_PATH" > "$tmp" || fail "failed to update Cask version and sha256"

  mv "$tmp" "$CASK_PATH"
  trap - EXIT
}

main() {
  parse_args "$@"
  read_checksum
  validate_cask_shape
  update_cask
}

main "$@"
