#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [output-dir] (requires built Frameworks and Poppler)"
  exit 0
fi
OUT_DIR="${1:-$ROOT/build.noindex/quicklook-raw-svg}"
# 실제 core/Swift 경로와 제한된 RawSvg 선택 정책을 함께 검증한다.
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
BIN="$OUT_DIR/quicklook_raw_svg_regression"
SWIFT_MODULE_CACHE="$OUT_DIR/swift-module-cache"
CLANG_MODULE_CACHE="$OUT_DIR/clang-module-cache"
rm -rf "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"
mkdir -p "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"

swiftc -parse-as-library -O -target "$(uname -m)-apple-macosx12.0" \
  -module-cache-path "$SWIFT_MODULE_CACHE" \
  -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
  -I "$MODULEMAP_DIR" \
  "$ROOT"/Sources/RhwpCoreBridge/*.swift \
  "$ROOT"/Sources/Shared/FontLibrary/*.swift \
  "$ROOT"/Sources/Shared/NativeFonts/*.swift \
  "$ROOT/Sources/Shared/HwpExternalImageResolver.swift" \
  "$ROOT/Sources/Shared/HwpPageImageRenderer.swift" \
  "$ROOT/Sources/Shared/HwpNativePageCompositor.swift" \
  "$ROOT/Sources/Shared/HwpPreviewPDFRenderer.swift" \
  "$ROOT/Sources/Shared/HwpPreviewPNGRenderer.swift" \
  "$ROOT/Sources/QLExtension/HwpQuickLookPNGReplyModeResolver.swift" \
  "$ROOT/scripts/quicklook_raw_svg_regression.swift" \
  "$LIB" \
  -framework CoreGraphics \
  -framework CoreText \
  -framework ImageIO \
  -framework UniformTypeIdentifiers \
  -framework JavaScriptCore \
  -framework ApplicationServices \
  -framework Metal \
  -framework QuartzCore \
  -framework IOSurface \
  -framework OpenGL \
  -framework Security \
  -framework CoreFoundation \
  -lc++ \
  -liconv \
  -lz \
  -o "$BIN"

"$BIN" "$ROOT" "$OUT_DIR"

command -v pdftoppm >/dev/null || { echo "ERROR: Poppler (pdftoppm) is required for independent PDF comparison" >&2; exit 1; }
pdftoppm -f 1 -singlefile -scale-to-x 794 -scale-to-y 1123 -png \
  "$ROOT/samples/issue7406/7406_OLE__CHART.pdf" "$OUT_DIR/reference"
swift -module-cache-path "$SWIFT_MODULE_CACHE" "$ROOT/scripts/compare-raw-svg-reference.swift" "$OUT_DIR"
