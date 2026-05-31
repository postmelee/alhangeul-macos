#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PAGE_NUMBER=1

usage() {
  cat >&2 <<EOF
Usage: $0 <output-dir> [--page N] [hwp-or-hwpx ...]

Builds and runs an overlay metadata smoke helper. When no input documents are
provided, the #281 default sample set is used. Page numbers are 1-based.
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

OUT_DIR="$1"
shift

while [ "$#" -gt 0 ]; do
  case "$1" in
    --page)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --page requires a positive integer" >&2
        exit 1
      fi
      PAGE_NUMBER="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

case "$PAGE_NUMBER" in
  ''|*[!0-9]*)
    echo "ERROR: --page must be a positive integer" >&2
    exit 1
    ;;
  0)
    echo "ERROR: --page must be greater than 0" >&2
    exit 1
    ;;
esac

INPUTS=("$@")
if [ "${#INPUTS[@]}" -eq 0 ]; then
  INPUTS=(
    "$ROOT/samples/basic/request.hwp"
    "$ROOT/samples/hwpx/hwpx-01.hwpx"
    "$ROOT/samples/tac-img-02.hwp"
    "$ROOT/samples/tac-img-02.hwpx"
    "$ROOT/samples/hwp-img-001.hwp"
    "$ROOT/samples/img-start-001.hwp"
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
BIN="$OUT_DIR/overlay_metadata_smoke"
SWIFT_MODULE_CACHE="$OUT_DIR/swift-module-cache-overlay-metadata"
CLANG_MODULE_CACHE="$OUT_DIR/clang-module-cache-overlay-metadata"
rm -rf "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"
mkdir -p "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"

swiftc -parse-as-library \
  -module-cache-path "$SWIFT_MODULE_CACHE" \
  -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
  -I "$MODULEMAP_DIR" \
  "$ROOT/Sources/RhwpCoreBridge/RhwpDocument.swift" \
  "$ROOT/Sources/RhwpCoreBridge/RenderTree.swift" \
  "$ROOT/Sources/RhwpCoreBridge/PageOverlayImages.swift" \
  "$ROOT/scripts/overlay_metadata_smoke.swift" \
  "$LIB" \
  -framework CoreGraphics \
  -framework CoreText \
  -framework ImageIO \
  -framework Security \
  -framework CoreFoundation \
  -lc++ \
  -liconv \
  -lz \
  -o "$BIN"

"$BIN" "$OUT_DIR" --page "$PAGE_NUMBER" "${INPUTS[@]}"
