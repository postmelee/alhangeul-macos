#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <output-dir> [--page N] <hwp-or-hwpx> [...]

Generates native renderer PNGs, rhwp core SVG PDF outputs, rasterizes the selected
PDF page, and writes pixel-diff PNGs plus visual-summary-pageN.md.
Page numbers are 1-based. The default page is 1.
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
PAGE_NUMBER=1

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

if [ "$#" -eq 0 ]; then
  echo "ERROR: missing input document" >&2
  usage
  exit 1
fi

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

mkdir -p "$OUT_DIR"
NATIVE_DIR="$OUT_DIR/native-page$PAGE_NUMBER"
SVG_PDF_DIR="$OUT_DIR/svg-pdf-page$PAGE_NUMBER"
VISUAL_DIR="$OUT_DIR/visual-page$PAGE_NUMBER"

"$ROOT/scripts/render-debug-compare.sh" "$NATIVE_DIR" --page "$PAGE_NUMBER" "$@"
"$ROOT/scripts/benchmark-quicklook-svg-pdf.sh" "$SVG_PDF_DIR" --runs 1 "$@"

BIN="$OUT_DIR/visual_compare_quicklook_renderers"
SWIFT_MODULE_CACHE="$OUT_DIR/swift-module-cache-visual"
CLANG_MODULE_CACHE="$OUT_DIR/clang-module-cache-visual"
rm -rf "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"
mkdir -p "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE" "$VISUAL_DIR"

swiftc -parse-as-library \
  -module-cache-path "$SWIFT_MODULE_CACHE" \
  -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
  "$ROOT/scripts/visual_compare_quicklook_renderers.swift" \
  -framework CoreGraphics \
  -framework ImageIO \
  -framework UniformTypeIdentifiers \
  -framework CoreFoundation \
  -o "$BIN"

"$BIN" "$VISUAL_DIR" "$NATIVE_DIR" "$SVG_PDF_DIR" "$PAGE_NUMBER" "$@"
