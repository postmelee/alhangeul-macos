#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 [output-dir] [hwp-or-hwpx ...]

Builds and runs a native renderer smoke check for the first page of each input.
When no output directory is provided, output is written to:
  $ROOT/output/stage3-render

When no input documents are provided, the default repository samples are used:
  samples/basic/KTX.hwp
  samples/basic/request.hwp
  samples/exam_kor.hwp

The check verifies document open, render tree, Hangul text/glyphs, page size,
native PNG generation, and non-blank bitmap output. It is a smoke test, not a
pixel equivalence test against rhwp core SVG or Hancom viewer output.
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

OUT_DIR="${1:-$ROOT/output/stage3-render}"

if [ "$#" -gt 0 ]; then
  shift
fi

SAMPLES=("$@")
if [ "${#SAMPLES[@]}" -eq 0 ]; then
  SAMPLES=(
    "$ROOT/samples/basic/KTX.hwp"
    "$ROOT/samples/basic/request.hwp"
    "$ROOT/samples/exam_kor.hwp"
  )
fi

LIB="$ROOT/Frameworks/universal/librhwp.a"
MODULEMAP_DIR="$ROOT/Frameworks/modulemap"
if [ ! -f "$LIB" ]; then
  echo "ERROR: missing $LIB" >&2
  echo "Run: $ROOT/scripts/build-rust-macos.sh" >&2
  exit 1
fi
if [ ! -f "$MODULEMAP_DIR/module.modulemap" ]; then
  echo "ERROR: missing $MODULEMAP_DIR/module.modulemap" >&2
  echo "Run: $ROOT/scripts/build-rust-macos.sh" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
BIN="$OUT_DIR/stage3_render_check"
SWIFT_MODULE_CACHE="$OUT_DIR/swift-module-cache"
CLANG_MODULE_CACHE="$OUT_DIR/clang-module-cache"
# Swift/Clang module caches contain absolute paths and can outlive workspace moves.
rm -rf "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"
mkdir -p "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"

swiftc -parse-as-library \
  -module-cache-path "$SWIFT_MODULE_CACHE" \
  -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
  -I "$MODULEMAP_DIR" \
  "$ROOT/Sources/RhwpCoreBridge/RhwpDocument.swift" \
  "$ROOT/Sources/RhwpCoreBridge/RenderTree.swift" \
  "$ROOT/Sources/RhwpCoreBridge/FontFallback.swift" \
  "$ROOT/Sources/RhwpCoreBridge/CGTreeRenderer.swift" \
  "$ROOT/scripts/stage3_render_check.swift" \
  "$LIB" \
  -framework CoreGraphics \
  -framework CoreText \
  -framework ImageIO \
  -framework Security \
  -framework CoreFoundation \
  -o "$BIN"

"$BIN" "$OUT_DIR" "${SAMPLES[@]}"
