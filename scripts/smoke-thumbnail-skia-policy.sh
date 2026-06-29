#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <output-dir> [--request NAME:WIDTHxHEIGHT@SCALE] <hwp-or-hwpx> [...]

Builds and runs a Finder Thumbnail policy smoke helper for the supplied
HWP/HWPX inputs. It measures CoreGraphics and Skia opt-in thumbnail rendering,
then writes summary.txt and per-file detail files with cache hit/miss events.
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

RUNNER_ARGS=("$OUT_DIR")
while [ "$#" -gt 0 ]; do
  case "$1" in
    --request)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --request requires NAME:WIDTHxHEIGHT@SCALE" >&2
        exit 1
      fi
      RUNNER_ARGS+=("--request" "$2")
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "ERROR: unknown option $1" >&2
      usage
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi
RUNNER_ARGS+=("$@")

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
BIN="$OUT_DIR/thumbnail_skia_policy_smoke"
SWIFT_MODULE_CACHE="$OUT_DIR/swift-module-cache-thumbnail-skia-policy"
CLANG_MODULE_CACHE="$OUT_DIR/clang-module-cache-thumbnail-skia-policy"
rm -rf "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"
mkdir -p "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"

swiftc -parse-as-library \
  -module-cache-path "$SWIFT_MODULE_CACHE" \
  -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
  -I "$MODULEMAP_DIR" \
  "$ROOT/Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift" \
  "$ROOT/Sources/RhwpCoreBridge/RhwpDocument.swift" \
  "$ROOT/Sources/RhwpCoreBridge/RenderTree.swift" \
  "$ROOT/Sources/RhwpCoreBridge/PageOverlayImages.swift" \
  "$ROOT/Sources/RhwpCoreBridge/FontFallback.swift" \
  "$ROOT/Sources/RhwpCoreBridge/FontResourceRegistry.swift" \
  "$ROOT/Sources/RhwpCoreBridge/CGTreeRenderer.swift" \
  "$ROOT/Sources/Shared/HwpPageImageRenderer.swift" \
  "$ROOT/Sources/Shared/HwpNativePageCompositor.swift" \
  "$ROOT/Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift" \
  "$ROOT/scripts/thumbnail_skia_policy_smoke.swift" \
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

"$BIN" "${RUNNER_ARGS[@]}"
