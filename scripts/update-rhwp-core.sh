#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BRIDGE_ROOT="$ROOT/RustBridge"
CARGO_TOML="$BRIDGE_ROOT/Cargo.toml"
CARGO_LOCK="$BRIDGE_ROOT/Cargo.lock"
LOCK_FILE="$ROOT/rhwp-core.lock"
RHWP_REPO="https://github.com/edwardkim/rhwp.git"
CHECK_ONLY=0
CHANNEL=""
REV=""
TAG=""
WORK_DIR=""
TARGET_COMMIT=""
CARGO_TOML_BACKUP=""
CARGO_LOCK_BACKUP=""
RESTORE_ON_ERROR=0

REQUIRED_APIS=(
  "build_page_render_tree"
  "get_bin_data"
  "render_page_svg_native"
  "get_page_info_native"
  "extract_thumbnail_only"
)

usage() {
  cat >&2 <<EOF
Usage:
  $0 --channel demo --rev <commit-sha> [--check]
  $0 --channel stable --tag <release-tag> [--check]

Options:
  --channel demo    Use a commit-pinned Demo/Preview dependency.
  --channel stable  Use a release tag dependency after compatibility checks.
  --rev SHA         Full 40-character commit SHA for demo channel.
  --tag TAG         Release tag for stable channel.
  --check           Run upstream ref and API checks without editing files.
EOF
}

finish() {
  local status=$?
  if [ "$status" -ne 0 ] && [ "$RESTORE_ON_ERROR" -eq 1 ]; then
    if [ -n "$CARGO_TOML_BACKUP" ] && [ -f "$CARGO_TOML_BACKUP" ]; then
      cp "$CARGO_TOML_BACKUP" "$CARGO_TOML"
    fi
    if [ -n "$CARGO_LOCK_BACKUP" ] && [ -f "$CARGO_LOCK_BACKUP" ]; then
      cp "$CARGO_LOCK_BACKUP" "$CARGO_LOCK"
    fi
  fi
  if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"
  fi
  if [ -n "$CARGO_TOML_BACKUP" ] && [ -f "$CARGO_TOML_BACKUP" ]; then
    rm -f "$CARGO_TOML_BACKUP"
  fi
  if [ -n "$CARGO_LOCK_BACKUP" ] && [ -f "$CARGO_LOCK_BACKUP" ]; then
    rm -f "$CARGO_LOCK_BACKUP"
  fi
  exit "$status"
}
trap finish EXIT

require_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: required tool not found: $tool" >&2
    exit 1
  fi
}

is_full_sha() {
  [[ "$1" =~ ^[0-9a-f]{40}$ ]]
}

normalize_repo() {
  local repo="$1"
  repo="${repo%/}"
  echo "$repo"
}

lock_scalar() {
  local key="$1"
  if [ ! -f "$LOCK_FILE" ]; then
    return
  fi
  awk -F' = ' -v key="$key" '
    $1 == key {
      value = $2
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' "$LOCK_FILE"
}

cargo_lock_rhwp_source() {
  awk -F' = ' '
    /^\[\[package\]\]/ {
      in_package = 0
    }
    $1 == "name" && $2 == "\"rhwp\"" {
      in_package = 1
      next
    }
    in_package && $1 == "source" {
      value = $2
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' "$CARGO_LOCK"
}

require_cargo_lock_rhwp_source() {
  local source
  source="$(cargo_lock_rhwp_source)"
  if [ -z "$source" ]; then
    echo "ERROR: Cargo.lock mismatch: missing rhwp git source in $CARGO_LOCK" >&2
    exit 1
  fi
  echo "$source"
}

cargo_lock_rhwp_commit() {
  local source
  local commit
  source="$(require_cargo_lock_rhwp_source)"
  commit="${source##*#}"
  if ! is_full_sha "$commit"; then
    echo "ERROR: Cargo.lock mismatch: missing resolved rhwp commit in $CARGO_LOCK" >&2
    echo "Source: $source" >&2
    exit 1
  fi
  echo "$commit"
}

cargo_lock_rhwp_repo() {
  local source
  local repo
  source="$(require_cargo_lock_rhwp_source)"
  repo="${source#git+}"
  repo="${repo%%#*}"
  repo="${repo%%\?*}"
  normalize_repo "$repo"
}

cargo_lock_rhwp_query() {
  local source
  local query_source
  source="$(require_cargo_lock_rhwp_source)"
  query_source="${source%%#*}"
  if [[ "$query_source" != *"?"* ]]; then
    echo ""
    return
  fi
  echo "${query_source#*\?}"
}

cargo_lock_rhwp_release_tag() {
  local query
  local value
  query="$(cargo_lock_rhwp_query)"
  if [[ "$query" != *"tag="* ]]; then
    echo ""
    return
  fi
  value="${query#*tag=}"
  value="${value%%&*}"
  echo "$value"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --channel)
        if [ "$#" -lt 2 ]; then
          echo "ERROR: missing value for --channel" >&2
          usage
          exit 1
        fi
        CHANNEL="$2"
        shift
        ;;
      --rev)
        if [ "$#" -lt 2 ]; then
          echo "ERROR: missing value for --rev" >&2
          usage
          exit 1
        fi
        REV="$2"
        shift
        ;;
      --tag)
        if [ "$#" -lt 2 ]; then
          echo "ERROR: missing value for --tag" >&2
          usage
          exit 1
        fi
        TAG="$2"
        shift
        ;;
      --check)
        CHECK_ONLY=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "ERROR: unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
    shift
  done
}

validate_args() {
  case "$CHANNEL" in
    demo)
      if [ -z "$REV" ] || [ -n "$TAG" ]; then
        echo "ERROR: demo channel requires --rev and does not accept --tag" >&2
        usage
        exit 1
      fi
      if ! is_full_sha "$REV"; then
        echo "ERROR: demo --rev must be a full 40-character lowercase commit SHA" >&2
        exit 1
      fi
      ;;
    stable)
      if [ -z "$TAG" ] || [ -n "$REV" ]; then
        echo "ERROR: stable channel requires --tag and does not accept --rev" >&2
        usage
        exit 1
      fi
      ;;
    *)
      echo "ERROR: --channel must be demo or stable" >&2
      usage
      exit 1
      ;;
  esac
}

init_work_repo() {
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rhwp-core.XXXXXX")"
  git -C "$WORK_DIR" init -q
  git -C "$WORK_DIR" remote add origin "$RHWP_REPO"
}

fetch_target() {
  init_work_repo

  if [ "$CHANNEL" = "demo" ]; then
    if ! git -C "$WORK_DIR" fetch --depth 1 origin "$REV"; then
      echo "ERROR: dependency fetch failure: could not fetch demo commit $REV" >&2
      exit 1
    fi
    git -C "$WORK_DIR" checkout -q --detach FETCH_HEAD
  else
    if ! git -C "$WORK_DIR" fetch --depth 1 origin "refs/tags/$TAG:refs/tags/$TAG"; then
      echo "ERROR: release lookup failure: could not fetch release tag $TAG" >&2
      exit 1
    fi
    git -C "$WORK_DIR" checkout -q --detach "$TAG"
  fi

  TARGET_COMMIT="$(git -C "$WORK_DIR" rev-parse HEAD)"
}

check_required_apis() {
  local missing=0
  local api
  for api in "${REQUIRED_APIS[@]}"; do
    if ! git -C "$WORK_DIR" grep -q "$api" -- src; then
      echo "ERROR: missing core API: $api" >&2
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    echo "ERROR: missing core API: target $TARGET_COMMIT does not satisfy RustBridge requirements" >&2
    exit 1
  fi
}

update_cargo_toml() {
  local dependency_line="$1"
  local tmp_file
  tmp_file="$CARGO_TOML.tmp.$$"
  if ! awk -v dependency_line="$dependency_line" '
    /^\[dependencies\]/ {
      in_dependencies = 1
      print
      next
    }
    /^\[/ {
      in_dependencies = 0
    }
    in_dependencies && $1 == "rhwp" && $2 == "=" {
      print dependency_line
      changed = 1
      next
    }
    {
      print
    }
    END {
      if (changed != 1) {
        exit 2
      }
    }
  ' "$CARGO_TOML" > "$tmp_file"; then
    rm -f "$tmp_file"
    echo "ERROR: could not replace rhwp dependency in $CARGO_TOML" >&2
    exit 1
  fi
  mv "$tmp_file" "$CARGO_TOML"
}

backup_cargo_files() {
  CARGO_TOML_BACKUP="$(mktemp "${TMPDIR:-/tmp}/rhwp-cargo-toml.XXXXXX")"
  cp "$CARGO_TOML" "$CARGO_TOML_BACKUP"
  if [ -f "$CARGO_LOCK" ]; then
    CARGO_LOCK_BACKUP="$(mktemp "${TMPDIR:-/tmp}/rhwp-cargo-lock.XXXXXX")"
    cp "$CARGO_LOCK" "$CARGO_LOCK_BACKUP"
  fi
  RESTORE_ON_ERROR=1
}

update_cargo_lock() {
  if ! cargo generate-lockfile --manifest-path "$CARGO_TOML"; then
    echo "ERROR: dependency fetch failure: cargo lockfile generation failed for rhwp" >&2
    exit 1
  fi
}

verify_cargo_lock() {
  local actual_repo
  local actual_commit
  actual_repo="$(cargo_lock_rhwp_repo)"
  actual_commit="$(cargo_lock_rhwp_commit)"

  if [ "$(normalize_repo "$actual_repo")" != "$(normalize_repo "$RHWP_REPO")" ]; then
    echo "ERROR: Cargo.lock mismatch: rhwp repo is not $RHWP_REPO" >&2
    echo "Actual: $actual_repo" >&2
    exit 1
  fi
  if [ "$actual_commit" != "$TARGET_COMMIT" ]; then
    echo "ERROR: Cargo.lock mismatch: resolved commit differs from target" >&2
    echo "Expected: $TARGET_COMMIT" >&2
    echo "Actual:   $actual_commit" >&2
    exit 1
  fi
  if [ "$CHANNEL" = "stable" ]; then
    local actual_tag
    actual_tag="$(cargo_lock_rhwp_release_tag)"
    if [ "$actual_tag" != "$TAG" ]; then
      echo "ERROR: Cargo.lock mismatch: release tag differs from target" >&2
      echo "Expected: $TAG" >&2
      echo "Actual:   $actual_tag" >&2
      exit 1
    fi
  fi
}

write_lock_skeleton() {
  local latest_checked_release_tag
  local latest_checked_release_commit
  latest_checked_release_tag="$(lock_scalar rhwp_latest_checked_release_tag)"
  latest_checked_release_commit="$(lock_scalar rhwp_latest_checked_release_commit)"

  {
    echo 'lock_version = 2'
    echo "rhwp_repo = \"$RHWP_REPO\""
    if [ "$CHANNEL" = "demo" ]; then
      echo 'rhwp_ref_kind = "commit"'
      echo "rhwp_commit = \"$TARGET_COMMIT\""
      echo 'rhwp_release_transition_status = "demo-commit-pin"'
      if [ -n "$latest_checked_release_tag" ]; then
        echo "rhwp_latest_checked_release_tag = \"$latest_checked_release_tag\""
      fi
      if [ -n "$latest_checked_release_commit" ]; then
        echo "rhwp_latest_checked_release_commit = \"$latest_checked_release_commit\""
      fi
    else
      echo 'rhwp_ref_kind = "release-tag"'
      echo "rhwp_release_tag = \"$TAG\""
      echo "rhwp_commit = \"$TARGET_COMMIT\""
    fi
    echo 'built_at = ""'
    echo 'ffi_symbols_file = "rhwp-ffi-symbols.txt"'
    echo
    echo '[[artifacts]]'
    echo 'path = "Frameworks/universal/librhwp.a"'
    echo 'sha256 = ""'
    echo 'size = 0'
    echo
    echo '[[artifacts]]'
    echo 'path = "Frameworks/generated_rhwp.h"'
    echo 'sha256 = ""'
    echo 'size = 0'
  } > "$LOCK_FILE"
}

print_check_summary() {
  echo "Checked rhwp core target:"
  echo "  channel: $CHANNEL"
  if [ "$CHANNEL" = "demo" ]; then
    echo "  rev:     $REV"
  else
    echo "  tag:     $TAG"
  fi
  echo "  commit:  $TARGET_COMMIT"
}

parse_args "$@"
validate_args
require_tool git
require_tool awk
if [ "$CHECK_ONLY" -eq 0 ]; then
  require_tool cargo
fi

if [ ! -f "$CARGO_TOML" ]; then
  echo "ERROR: missing Rust bridge crate: $CARGO_TOML" >&2
  exit 1
fi

fetch_target
check_required_apis

if [ "$CHECK_ONLY" -eq 1 ]; then
  print_check_summary
  exit 0
fi

backup_cargo_files

if [ "$CHANNEL" = "demo" ]; then
  update_cargo_toml "rhwp = { git = \"$RHWP_REPO\", rev = \"$TARGET_COMMIT\" }"
else
  update_cargo_toml "rhwp = { git = \"$RHWP_REPO\", tag = \"$TAG\" }"
fi

update_cargo_lock
verify_cargo_lock
write_lock_skeleton
RESTORE_ON_ERROR=0

print_check_summary
echo "Updated: $CARGO_TOML"
echo "Updated: $CARGO_LOCK"
echo "Updated: $LOCK_FILE"
echo "Next: ./scripts/build-rust-macos.sh --update-lock && ./scripts/check-no-appkit.sh"
