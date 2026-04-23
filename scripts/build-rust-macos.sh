#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RHWP_ROOT="$ROOT/Vendor/rhwp"
BRIDGE_ROOT="$ROOT/RustBridge"
OUT="$ROOT/Frameworks"
GENERATED_H="$OUT/generated_rhwp.h"
MODMAP_DIR="$OUT/modulemap"
EXPECTED_SYMBOLS="$ROOT/rhwp-ffi-symbols.txt"
GENERATED_SYMBOLS="$OUT/generated_rhwp_symbols.txt"

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

require_tool cargo
require_tool rustup
require_tool cbindgen
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
  -output "$OUT/universal/librhwp.a"
xcrun lipo -info "$OUT/universal/librhwp.a"

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
du -sh "$OUT/universal/librhwp.a" "$OUT/Rhwp.xcframework"
