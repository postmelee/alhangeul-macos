#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <output-dir> <hwp-or-hwpx> [...]

Measures the current native bitmap PDF path and the rhwp core SVG generation path
for the same HWP/HWPX inputs. Outputs per-file detail files and summary.txt.
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

OUT_DIR="$1"
shift
INPUTS=("$@")

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
BIN="$OUT_DIR/quicklook_pdf_renderer_compare"
SWIFT_MODULE_CACHE="$OUT_DIR/swift-module-cache-quicklook-pdf"
CLANG_MODULE_CACHE="$OUT_DIR/clang-module-cache-quicklook-pdf"
rm -rf "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"
mkdir -p "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"

swiftc -parse-as-library \
  -module-cache-path "$SWIFT_MODULE_CACHE" \
  -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
  -I "$MODULEMAP_DIR" \
  "$ROOT/Sources/RhwpCoreBridge/RhwpDocument.swift" \
  "$ROOT/Sources/RhwpCoreBridge/RenderTree.swift" \
  "$ROOT/Sources/RhwpCoreBridge/FontFallback.swift" \
  "$ROOT/Sources/RhwpCoreBridge/FontResourceRegistry.swift" \
  "$ROOT/Sources/RhwpCoreBridge/CGTreeRenderer.swift" \
  "$ROOT/Sources/Shared/HwpPageImageRenderer.swift" \
  "$ROOT/Sources/Shared/HwpPreviewPDFRenderer.swift" \
  "$ROOT/scripts/quicklook_pdf_renderer_compare.swift" \
  "$LIB" \
  -framework CoreGraphics \
  -framework CoreText \
  -framework ImageIO \
  -framework UniformTypeIdentifiers \
  -framework Security \
  -framework CoreFoundation \
  -o "$BIN"

"$BIN" "$OUT_DIR" "${INPUTS[@]}"
