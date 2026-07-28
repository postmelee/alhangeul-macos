#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <output-dir> <hwp-or-hwpx> [...]

Builds and runs a Quick Look policy smoke helper for the supplied HWP/HWPX
inputs. It measures the current Quick Look reply shape with CoreGraphics and
Skia opt-in policies, then writes summary.txt and per-file detail files.
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
BIN="$OUT_DIR/quicklook_skia_policy_smoke"
SWIFT_MODULE_CACHE="$OUT_DIR/swift-module-cache-quicklook-skia-policy"
CLANG_MODULE_CACHE="$OUT_DIR/clang-module-cache-quicklook-skia-policy"
rm -rf "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"
mkdir -p "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"

swiftc -parse-as-library \
  -DDEBUG \
  -module-cache-path "$SWIFT_MODULE_CACHE" \
  -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
  -I "$MODULEMAP_DIR" \
  "$ROOT/Sources/RhwpCoreBridge/RhwpDocument.swift" \
  "$ROOT/Sources/RhwpCoreBridge/RenderTree.swift" \
  "$ROOT/Sources/RhwpCoreBridge/PageOverlayImages.swift" \
  "$ROOT/Sources/RhwpCoreBridge/FontFallback.swift" \
  "$ROOT/Sources/RhwpCoreBridge/FontResourceRegistry.swift" \
  "$ROOT/Sources/RhwpCoreBridge/CGTreeRenderer.swift" \
  "$ROOT/Sources/Shared/HwpExternalImageResolver.swift" \
  "$ROOT/Sources/Shared/HwpPageImageRenderer.swift" \
  "$ROOT/Sources/Shared/HwpNativePageCompositor.swift" \
  "$ROOT/Sources/Shared/HwpPreviewPDFRenderer.swift" \
  "$ROOT/Sources/Shared/HwpPreviewPNGRenderer.swift" \
  "$ROOT/Sources/QLExtension/HwpQuickLookPNGReplyModeResolver.swift" \
  "$ROOT/scripts/quicklook_skia_policy_smoke.swift" \
  "$LIB" \
  -framework CoreGraphics \
  -framework CoreText \
  -framework ImageIO \
  -framework UniformTypeIdentifiers \
  -framework Security \
  -framework CoreFoundation \
  -lc++ \
  -liconv \
  -lz \
  -o "$BIN"

"$BIN" "$OUT_DIR" "${INPUTS[@]}"
