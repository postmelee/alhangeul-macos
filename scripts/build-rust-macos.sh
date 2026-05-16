#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RHWP_ROOT="$ROOT/Vendor/rhwp"
BRIDGE_ROOT="$ROOT/RustBridge"
CARGO_TOML="$BRIDGE_ROOT/Cargo.toml"
CARGO_LOCK="$BRIDGE_ROOT/Cargo.lock"
OUT="$ROOT/Frameworks"
LOCK_FILE="$ROOT/rhwp-core.lock"
RHWP_REPO="https://github.com/edwardkim/rhwp.git"
GENERATED_H="$OUT/generated_rhwp.h"
MODMAP_DIR="$OUT/modulemap"
EXPECTED_SYMBOLS="$ROOT/rhwp-ffi-symbols.txt"
GENERATED_SYMBOLS="$OUT/generated_rhwp_symbols.txt"
UNIVERSAL_LIB="$OUT/universal/librhwp.a"
STATICLIB_ARTIFACT="Frameworks/universal/librhwp.a"
LOCK_ARTIFACTS=(
  "$STATICLIB_ARTIFACT"
  "Frameworks/generated_rhwp.h"
)
SKIP_STATICLIB_HASH_VERIFY="${ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY:-0}"
UPDATE_LOCK=0
VERIFY_LOCK=0

usage() {
  cat >&2 <<EOF
Usage: $0 [--update-lock | --verify-lock]

Options:
  --update-lock   Build artifacts, then write sha256/size to rhwp-core.lock.
  --verify-lock   Build artifacts, then compare artifacts with rhwp-core.lock.

Environment:
  ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1
                  With --verify-lock, skip only byte-for-byte sha256/size
                  comparison for Frameworks/universal/librhwp.a. Source lock,
                  Cargo.lock, generated header, and FFI symbol checks still run.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --update-lock)
      UPDATE_LOCK=1
      ;;
    --verify-lock)
      VERIFY_LOCK=1
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

if [ "$UPDATE_LOCK" -eq 1 ] && [ "$VERIFY_LOCK" -eq 1 ]; then
  echo "ERROR: --update-lock and --verify-lock cannot be used together" >&2
  usage
  exit 1
fi

require_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: required tool not found: $tool" >&2
    exit 1
  fi
}

require_rust_target() {
  local target="$1"
  if ! rustup target list --installed | grep -qx "$target"; then
    echo "ERROR: Rust target not installed: $target" >&2
    echo "Run: rustup target add $target" >&2
    exit 1
  fi
}

artifact_sha256() {
  local artifact_path="$1"
  shasum -a 256 "$artifact_path" | awk '{print $1}'
}

artifact_size() {
  local artifact_path="$1"
  stat -f%z "$artifact_path"
}

artifact_abs_path() {
  local artifact_path="$1"
  echo "$ROOT/$artifact_path"
}

require_artifact() {
  local artifact_path="$1"
  local abs_path
  abs_path="$(artifact_abs_path "$artifact_path")"
  if [ ! -f "$abs_path" ]; then
    echo "ERROR: missing artifact: $artifact_path" >&2
    exit 1
  fi
}

lock_scalar() {
  local key="$1"
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

existing_lock_scalar() {
  local key="$1"
  if [ -f "$LOCK_FILE" ]; then
    lock_scalar "$key"
  fi
}

lock_artifact_value() {
  local artifact_path="$1"
  local key="$2"
  awk -F' = ' -v artifact_path="$artifact_path" -v key="$key" '
    /^\[\[artifacts\]\]/ {
      in_artifact = 1
      matched = 0
      next
    }
    in_artifact && $1 == "path" {
      value = $2
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      if (value == artifact_path) {
        matched = 1
      }
      next
    }
    in_artifact && matched && $1 == key {
      value = $2
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' "$LOCK_FILE"
}

print_staticlib_hash_skip_warning() {
  local artifact_path="$1"
  cat >&2 <<EOF
WARNING: skipping byte-for-byte hash verification for $artifact_path
         Only the Rust static archive sha256/size comparison is skipped.
         Source provenance, Cargo.lock, generated header, and FFI symbols remain verified.
EOF
}

print_staticlib_hash_mismatch_note() {
  cat >&2 <<EOF
Note: $STATICLIB_ARTIFACT is a Rust static archive. Its byte hash can differ
      across Rust, Xcode, macOS runner, archive tool, or build path changes even
      when source provenance and ABI checks still match. Do not update
      rhwp-core.lock just to satisfy an unreviewed runner/toolchain difference.
      GitHub-hosted CI/release workflows may set
      ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 under the documented policy.
EOF
}

normalize_repo() {
  local repo="$1"
  repo="${repo%/}"
  echo "$repo"
}

cargo_toml_rhwp_line() {
  awk '
    /^\[dependencies\]/ {
      in_dependencies = 1
      next
    }
    /^\[/ {
      in_dependencies = 0
    }
    in_dependencies && $1 == "rhwp" && $2 == "=" {
      print
      exit
    }
  ' "$CARGO_TOML"
}

rhwp_dependency_mode() {
  local line
  line="$(cargo_toml_rhwp_line)"
  if [[ "$line" == *"path"* ]]; then
    echo "path"
  elif [[ "$line" == *"git"* ]]; then
    echo "git"
  else
    echo "ERROR: unsupported rhwp dependency in $CARGO_TOML" >&2
    echo "Expected path or git dependency." >&2
    exit 1
  fi
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
    echo "Run: cargo update --manifest-path $CARGO_TOML -p rhwp" >&2
    exit 1
  fi
  echo "$source"
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

cargo_lock_rhwp_commit() {
  local source
  local commit
  source="$(require_cargo_lock_rhwp_source)"
  commit="${source##*#}"
  if ! [[ "$commit" =~ ^[0-9a-f]{40}$ ]]; then
    echo "ERROR: Cargo.lock mismatch: missing resolved rhwp commit in $CARGO_LOCK" >&2
    echo "Source: $source" >&2
    exit 1
  fi
  echo "$commit"
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

cargo_lock_rhwp_ref_kind() {
  local query
  query="$(cargo_lock_rhwp_query)"
  if [[ "$query" == *"tag="* ]]; then
    echo "release-tag"
  elif [[ "$query" == *"rev="* ]]; then
    echo "commit"
  else
    echo "unknown"
  fi
}

cargo_lock_rhwp_release_tag() {
  local query
  local tag
  query="$(cargo_lock_rhwp_query)"
  if [[ "$query" != *"tag="* ]]; then
    echo ""
    return
  fi
  tag="${query#*tag=}"
  tag="${tag%%&*}"
  echo "$tag"
}

path_dependency_rhwp_repo() {
  local repo
  repo="$(git config -f "$ROOT/.gitmodules" --get submodule.Vendor/rhwp.url || true)"
  if [ -z "$repo" ]; then
    repo="$RHWP_REPO"
  fi
  normalize_repo "$repo"
}

path_dependency_rhwp_branch() {
  local branch
  branch="$(git -C "$RHWP_ROOT" rev-parse --abbrev-ref HEAD)"
  if [ "$branch" = "HEAD" ]; then
    branch="$(existing_lock_scalar rhwp_branch)"
  fi
  if [ -z "$branch" ]; then
    branch="devel"
  fi
  echo "$branch"
}

current_rhwp_repo() {
  case "$(rhwp_dependency_mode)" in
    path)
      path_dependency_rhwp_repo
      ;;
    git)
      cargo_lock_rhwp_repo
      ;;
  esac
}

current_rhwp_commit() {
  case "$(rhwp_dependency_mode)" in
    path)
      git -C "$RHWP_ROOT" rev-parse HEAD
      ;;
    git)
      cargo_lock_rhwp_commit
      ;;
  esac
}

current_rhwp_ref_kind() {
  case "$(rhwp_dependency_mode)" in
    path)
      local ref_kind
      ref_kind="$(existing_lock_scalar rhwp_ref_kind)"
      if [ -z "$ref_kind" ]; then
        ref_kind="branch"
      fi
      echo "$ref_kind"
      ;;
    git)
      cargo_lock_rhwp_ref_kind
      ;;
  esac
}

current_rhwp_release_tag() {
  case "$(rhwp_dependency_mode)" in
    path)
      existing_lock_scalar rhwp_release_tag
      ;;
    git)
      cargo_lock_rhwp_release_tag
      ;;
  esac
}

ensure_rhwp_source_available() {
  if [ "$(rhwp_dependency_mode)" = "path" ]; then
    if [ ! -d "$RHWP_ROOT/.git" ] && [ ! -f "$RHWP_ROOT/.git" ]; then
      echo "ERROR: rhwp submodule is missing: $RHWP_ROOT" >&2
      echo "Run: git submodule update --init --recursive" >&2
      exit 1
    fi
  fi
}

write_lock_file() {
  local built_at
  local repo
  local commit
  local ref_kind
  local branch
  local release_tag
  local release_status
  local latest_checked_release_tag
  local latest_checked_release_commit
  built_at="$(TZ=UTC date '+%Y-%m-%dT%H:%M:%SZ')"
  repo="$(current_rhwp_repo)"
  commit="$(current_rhwp_commit)"
  ref_kind="$(current_rhwp_ref_kind)"
  release_tag="$(current_rhwp_release_tag)"
  release_status="$(existing_lock_scalar rhwp_release_transition_status)"
  latest_checked_release_tag="$(existing_lock_scalar rhwp_latest_checked_release_tag)"
  latest_checked_release_commit="$(existing_lock_scalar rhwp_latest_checked_release_commit)"

  if [ -z "$ref_kind" ]; then
    ref_kind="commit"
  fi
  if [ -z "$release_status" ] && [ "$ref_kind" != "release-tag" ]; then
    release_status="blocked-missing-bridge-apis"
  fi
  if [ "$ref_kind" = "branch" ]; then
    branch="$(path_dependency_rhwp_branch)"
  else
    branch=""
  fi

  {
    echo 'lock_version = 2'
    echo "rhwp_repo = \"$repo\""
    echo "rhwp_ref_kind = \"$ref_kind\""
    if [ "$ref_kind" = "branch" ]; then
      echo "rhwp_branch = \"$branch\""
    fi
    if [ "$ref_kind" = "release-tag" ] && [ -n "$release_tag" ]; then
      echo "rhwp_release_tag = \"$release_tag\""
    fi
    echo "rhwp_commit = \"$commit\""
    if [ "$ref_kind" != "release-tag" ]; then
      echo "rhwp_release_transition_status = \"$release_status\""
      if [ -n "$latest_checked_release_tag" ]; then
        echo "rhwp_latest_checked_release_tag = \"$latest_checked_release_tag\""
      fi
      if [ -n "$latest_checked_release_commit" ]; then
        echo "rhwp_latest_checked_release_commit = \"$latest_checked_release_commit\""
      fi
    fi
    echo "built_at = \"$built_at\""
    echo 'ffi_symbols_file = "rhwp-ffi-symbols.txt"'
    echo

    local artifact_path
    for artifact_path in "${LOCK_ARTIFACTS[@]}"; do
      require_artifact "$artifact_path"
      local abs_path
      abs_path="$(artifact_abs_path "$artifact_path")"
      echo '[[artifacts]]'
      echo "path = \"$artifact_path\""
      echo "sha256 = \"$(artifact_sha256 "$abs_path")\""
      echo "size = $(artifact_size "$abs_path")"
      if [ "$artifact_path" != "${LOCK_ARTIFACTS[${#LOCK_ARTIFACTS[@]}-1]}" ]; then
        echo
      fi
    done
  } > "$LOCK_FILE"
}

verify_lock_file() {
  if [ ! -f "$LOCK_FILE" ]; then
    echo "ERROR: missing lock file: $LOCK_FILE" >&2
    exit 1
  fi

  local lock_version
  lock_version="$(lock_scalar lock_version)"
  if [ "$lock_version" != "2" ]; then
    echo "ERROR: unsupported rhwp-core.lock version: ${lock_version:-missing}" >&2
    echo "Expected: 2" >&2
    exit 1
  fi

  local expected_repo
  local actual_repo
  expected_repo="$(lock_scalar rhwp_repo)"
  actual_repo="$(current_rhwp_repo)"
  if [ "$(normalize_repo "$expected_repo")" != "$(normalize_repo "$actual_repo")" ]; then
    echo "ERROR: Cargo.lock mismatch: rhwp repo differs from $LOCK_FILE" >&2
    echo "Expected rhwp_repo: $expected_repo" >&2
    echo "Actual rhwp_repo:   $actual_repo" >&2
    exit 1
  fi

  local expected_ref_kind
  local actual_ref_kind
  expected_ref_kind="$(lock_scalar rhwp_ref_kind)"
  actual_ref_kind="$(current_rhwp_ref_kind)"
  if [ "$expected_ref_kind" != "$actual_ref_kind" ]; then
    echo "ERROR: Cargo.lock mismatch: rhwp ref kind differs from $LOCK_FILE" >&2
    echo "Expected rhwp_ref_kind: $expected_ref_kind" >&2
    echo "Actual rhwp_ref_kind:   $actual_ref_kind" >&2
    exit 1
  fi

  if [ "$expected_ref_kind" = "release-tag" ]; then
    local expected_release_tag
    local actual_release_tag
    expected_release_tag="$(lock_scalar rhwp_release_tag)"
    actual_release_tag="$(current_rhwp_release_tag)"
    if [ "$expected_release_tag" != "$actual_release_tag" ]; then
      echo "ERROR: Cargo.lock mismatch: rhwp release tag differs from $LOCK_FILE" >&2
      echo "Expected rhwp_release_tag: $expected_release_tag" >&2
      echo "Actual rhwp_release_tag:   $actual_release_tag" >&2
      exit 1
    fi
  fi

  local expected_commit
  local actual_commit
  expected_commit="$(lock_scalar rhwp_commit)"
  actual_commit="$(current_rhwp_commit)"
  if [ "$expected_commit" != "$actual_commit" ]; then
    echo "ERROR: Cargo.lock mismatch: rhwp core commit differs from $LOCK_FILE" >&2
    echo "Expected rhwp_commit: $expected_commit" >&2
    echo "Actual rhwp_commit:   $actual_commit" >&2
    if [ "$(rhwp_dependency_mode)" = "path" ]; then
      echo "Run: git submodule update --init --recursive" >&2
    else
      echo "Run: cargo update --manifest-path $CARGO_TOML -p rhwp" >&2
    fi
    exit 1
  fi

  local artifact_path
  for artifact_path in "${LOCK_ARTIFACTS[@]}"; do
    require_artifact "$artifact_path"

    if [ "$artifact_path" = "$STATICLIB_ARTIFACT" ] && [ "$SKIP_STATICLIB_HASH_VERIFY" = "1" ]; then
      print_staticlib_hash_skip_warning "$artifact_path"
      continue
    fi

    local abs_path
    local expected_sha256
    local actual_sha256
    local expected_size
    local actual_size

    abs_path="$(artifact_abs_path "$artifact_path")"
    expected_sha256="$(lock_artifact_value "$artifact_path" sha256)"
    expected_size="$(lock_artifact_value "$artifact_path" size)"
    actual_sha256="$(artifact_sha256 "$abs_path")"
    actual_size="$(artifact_size "$abs_path")"

    if [ -z "$expected_sha256" ] || [ -z "$expected_size" ]; then
      echo "ERROR: missing lock metadata for artifact: $artifact_path" >&2
      echo "Run: ./scripts/build-rust-macos.sh --update-lock" >&2
      exit 1
    fi

    if [ "$expected_sha256" != "$actual_sha256" ] || [ "$expected_size" != "$actual_size" ]; then
      echo "ERROR: artifact hash mismatch: artifact differs from $LOCK_FILE" >&2
      echo "Artifact: $artifact_path" >&2
      echo "Expected sha256: $expected_sha256" >&2
      echo "Actual sha256:   $actual_sha256" >&2
      echo "Expected size:   $expected_size" >&2
      echo "Actual size:     $actual_size" >&2
      if [ "$artifact_path" = "$STATICLIB_ARTIFACT" ]; then
        print_staticlib_hash_mismatch_note
      fi
      echo "Run: ./scripts/build-rust-macos.sh --update-lock if this artifact is intentional." >&2
      exit 1
    fi
  done

  echo "Verified: $LOCK_FILE"
}

require_tool cargo
require_tool rustup
require_tool cbindgen
require_tool git
require_tool shasum
require_tool awk
require_tool stat
require_tool xcodebuild
require_tool xcrun
require_rust_target aarch64-apple-darwin
require_rust_target x86_64-apple-darwin

export MACOSX_DEPLOYMENT_TARGET=12.0

if [ ! -f "$CARGO_TOML" ]; then
  echo "ERROR: missing Rust bridge crate: $CARGO_TOML" >&2
  exit 1
fi
ensure_rhwp_source_available

mkdir -p "$OUT"

echo "[1/4] Rust staticlib (arm64 + x86_64)..."
cargo build --release --manifest-path "$BRIDGE_ROOT/Cargo.toml" --target aarch64-apple-darwin
cargo build --release --manifest-path "$BRIDGE_ROOT/Cargo.toml" --target x86_64-apple-darwin

echo "[2/4] Universal binary..."
mkdir -p "$OUT/universal"
xcrun lipo -create \
  "$BRIDGE_ROOT/target/aarch64-apple-darwin/release/librhwp_mac_bridge.a" \
  "$BRIDGE_ROOT/target/x86_64-apple-darwin/release/librhwp_mac_bridge.a" \
  -output "$UNIVERSAL_LIB"
xcrun lipo -info "$UNIVERSAL_LIB"

echo "[3/4] cbindgen header check..."
cbindgen --quiet --config "$BRIDGE_ROOT/cbindgen.toml" --crate rhwp_mac_bridge \
  --output "$GENERATED_H" "$BRIDGE_ROOT"
grep -oE '\brhwp_[a-z_]+' "$GENERATED_H" | sort -u > "$GENERATED_SYMBOLS"
if ! diff -u "$EXPECTED_SYMBOLS" "$GENERATED_SYMBOLS"; then
  echo "ERROR: generated FFI symbol set differs from $EXPECTED_SYMBOLS" >&2
  echo "Generated header: $GENERATED_H" >&2
  exit 1
fi
echo "FFI symbols:"
cat "$GENERATED_SYMBOLS"

for field in width_pt height_pt; do
  if ! grep -q "\b$field\b" "$GENERATED_H"; then
    echo "ERROR: generated header is missing RhwpPageSize.$field" >&2
    echo "Generated header: $GENERATED_H" >&2
    exit 1
  fi
done

echo "[4/4] XCFramework..."
rm -rf "$OUT/Rhwp.xcframework" "$MODMAP_DIR"
mkdir -p "$MODMAP_DIR"
cp "$GENERATED_H" "$MODMAP_DIR/rhwp.h"
cat > "$MODMAP_DIR/module.modulemap" <<'EOF'
module Rhwp {
  header "rhwp.h"
  export *
}
EOF

xcodebuild -create-xcframework \
  -library "$OUT/universal/librhwp.a" -headers "$MODMAP_DIR" \
  -output "$OUT/Rhwp.xcframework"

echo "Done: $OUT/Rhwp.xcframework"
du -sh "$UNIVERSAL_LIB" "$OUT/Rhwp.xcframework"

if [ "$UPDATE_LOCK" -eq 1 ]; then
  write_lock_file
  echo "Updated: $LOCK_FILE"
elif [ "$VERIFY_LOCK" -eq 1 ]; then
  verify_lock_file
fi
