#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RHWP_ROOT="$ROOT/Vendor/rhwp"
BRIDGE_ROOT="$ROOT/RustBridge"
OUT="$ROOT/Frameworks"
LOCK_FILE="$ROOT/rhwp-core.lock"
GENERATED_H="$OUT/generated_rhwp.h"
MODMAP_DIR="$OUT/modulemap"
EXPECTED_SYMBOLS="$ROOT/rhwp-ffi-symbols.txt"
GENERATED_SYMBOLS="$OUT/generated_rhwp_symbols.txt"
UNIVERSAL_LIB="$OUT/universal/librhwp.a"
LOCK_ARTIFACTS=(
  "Frameworks/universal/librhwp.a"
  "Frameworks/generated_rhwp.h"
)
UPDATE_LOCK=0
VERIFY_LOCK=0

usage() {
  cat >&2 <<EOF
Usage: $0 [--update-lock | --verify-lock]

Options:
  --update-lock   Build artifacts, then write sha256/size to rhwp-core.lock.
  --verify-lock   Build artifacts, then compare artifacts with rhwp-core.lock.
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

current_rhwp_commit() {
  git -C "$RHWP_ROOT" rev-parse HEAD
}

write_lock_file() {
  local built_at
  local commit
  built_at="$(TZ=UTC date '+%Y-%m-%dT%H:%M:%SZ')"
  commit="$(current_rhwp_commit)"

  {
    echo 'lock_version = 2'
    echo 'rhwp_repo = "https://github.com/postmelee/rhwp.git"'
    echo 'rhwp_branch = "devel"'
    echo "rhwp_commit = \"$commit\""
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

  local expected_commit
  local actual_commit
  expected_commit="$(lock_scalar rhwp_commit)"
  actual_commit="$(current_rhwp_commit)"
  if [ "$expected_commit" != "$actual_commit" ]; then
    echo "ERROR: rhwp core commit differs from $LOCK_FILE" >&2
    echo "Expected rhwp_commit: $expected_commit" >&2
    echo "Actual rhwp_commit:   $actual_commit" >&2
    echo "Run: git submodule update --init --recursive" >&2
    exit 1
  fi

  local artifact_path
  for artifact_path in "${LOCK_ARTIFACTS[@]}"; do
    require_artifact "$artifact_path"

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
      echo "ERROR: artifact differs from $LOCK_FILE" >&2
      echo "Artifact: $artifact_path" >&2
      echo "Expected sha256: $expected_sha256" >&2
      echo "Actual sha256:   $actual_sha256" >&2
      echo "Expected size:   $expected_size" >&2
      echo "Actual size:     $actual_size" >&2
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

if [ ! -d "$RHWP_ROOT/.git" ] && [ ! -f "$RHWP_ROOT/.git" ]; then
  echo "ERROR: rhwp submodule is missing: $RHWP_ROOT" >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi
if [ ! -f "$BRIDGE_ROOT/Cargo.toml" ]; then
  echo "ERROR: missing Rust bridge crate: $BRIDGE_ROOT" >&2
  exit 1
fi

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
