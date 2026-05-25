#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCE_DIR="$ROOT/Sources/HostApp/Resources/rhwp-studio"
PAGE_NUMBER=1
VIEWPORT_SIZE="1400x1800"
SETTLE_MS=120

usage() {
  cat >&2 <<EOF
Usage: $0 <output-dir> [--page N] [--viewport WIDTHxHEIGHT] [--settle-ms N] [--resource-dir DIR] <hwp-or-hwpx> [...]

Captures bundled rhwp-studio reference PNGs and metadata JSON files for the
selected page. Page numbers are 1-based. The default page is 1.
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
    --viewport)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --viewport requires WIDTHxHEIGHT" >&2
        exit 1
      fi
      VIEWPORT_SIZE="$2"
      shift 2
      ;;
    --settle-ms)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --settle-ms requires a non-negative integer" >&2
        exit 1
      fi
      SETTLE_MS="$2"
      shift 2
      ;;
    --resource-dir)
      if [ "$#" -lt 2 ]; then
        echo "ERROR: --resource-dir requires a directory" >&2
        exit 1
      fi
      RESOURCE_DIR="$2"
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

case "$SETTLE_MS" in
  ''|*[!0-9]*)
    echo "ERROR: --settle-ms must be a non-negative integer" >&2
    exit 1
    ;;
esac

case "$VIEWPORT_SIZE" in
  *x*)
    ;;
  *)
    echo "ERROR: --viewport must use WIDTHxHEIGHT" >&2
    exit 1
    ;;
esac

"$ROOT/scripts/verify-rhwp-studio-assets.sh" --resource-dir "$RESOURCE_DIR"

mkdir -p "$OUT_DIR"
BIN="$OUT_DIR/preview_visual_diff_harness"
SWIFT_MODULE_CACHE="$OUT_DIR/swift-module-cache-preview"
CLANG_MODULE_CACHE="$OUT_DIR/clang-module-cache-preview"
rm -rf "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"
mkdir -p "$SWIFT_MODULE_CACHE" "$CLANG_MODULE_CACHE"

swiftc -parse-as-library \
  -module-cache-path "$SWIFT_MODULE_CACHE" \
  -Xcc -fmodules-cache-path="$CLANG_MODULE_CACHE" \
  "$ROOT/scripts/preview_visual_diff_harness.swift" \
  -framework AppKit \
  -framework CoreGraphics \
  -framework Foundation \
  -framework ImageIO \
  -framework WebKit \
  -o "$BIN"

"$BIN" "$OUT_DIR" \
  --resource-dir "$RESOURCE_DIR" \
  --page "$PAGE_NUMBER" \
  --viewport "$VIEWPORT_SIZE" \
  --settle-ms "$SETTLE_MS" \
  "$@"
