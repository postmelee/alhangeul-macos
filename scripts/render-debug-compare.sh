#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0 <output-dir> [--page N] <hwp-or-hwpx> [...]

Creates render tree JSON, rhwp core SVG, native renderer PNG, summary files,
and optional core raster PNG / pixel diff files when local SVG rasterization works.
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
RUN_ARGS=("$@")

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

INPUTS=("$@")
if [ "${#INPUTS[@]}" -eq 0 ]; then
  echo "ERROR: missing input document" >&2
  usage
  exit 1
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
OUT_ABS="$(cd "$OUT_DIR" && pwd)"
BIN="$OUT_DIR/render_debug_compare"
SWIFT_MODULE_CACHE="$OUT_DIR/swift-module-cache-debug"
CLANG_MODULE_CACHE="$OUT_DIR/clang-module-cache-debug"
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
  "$ROOT/scripts/render_debug_compare.swift" \
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

"$BIN" "$OUT_DIR" "${RUN_ARGS[@]}"

summary_value() {
  local summary="$1"
  local key="$2"
  awk -F': ' -v key="$key" '$1 == key { print $2; exit }' "$summary"
}

replace_optional_summary() {
  local summary="$1"
  local core_png="$2"
  local diff_png="$3"
  local reason="$4"
  local tmp="$summary.tmp"

  awk '
    /^CoreRasterPNG:/ { stop = 1 }
    /^Diff:/ { stop = 1 }
    !stop { print }
  ' "$summary" > "$tmp"

  {
    echo "CoreRasterPNG: $core_png"
    echo "DiffPNG: $diff_png"
    echo "Diff: not generated"
    echo "DiffReason: $reason"
  } >> "$tmp"

  mv "$tmp" "$summary"
}

rasterize_svg_with_qlmanage() {
  local svg="$1"
  local output_png="$2"
  local size="$3"
  local generated="$OUT_ABS/$(basename "$svg").png"
  local log_file="$OUT_ABS/$(basename "$svg").qlmanage.log"

  rm -f "$generated" "$output_png" "$log_file"
  if ! qlmanage -t -x -s "$size" -o "$OUT_ABS" "$svg" >"$log_file" 2>&1; then
    return 1
  fi
  if [ ! -s "$generated" ]; then
    return 1
  fi
  mv -f "$generated" "$output_png"
}

for input in "${INPUTS[@]}"; do
  filename="$(basename "$input")"
  basename_no_ext="${filename%.*}"
  output_base="$basename_no_ext-page$PAGE_NUMBER"
  core_svg="$OUT_ABS/$output_base-core.svg"
  native_png="$OUT_ABS/$output_base-native.png"
  core_png="$OUT_ABS/$output_base-core.png"
  diff_png="$OUT_ABS/$output_base-diff.png"
  summary="$OUT_ABS/$output_base-summary.txt"

  if [ ! -s "$core_svg" ] || [ ! -s "$native_png" ] || [ ! -s "$summary" ]; then
    continue
  fi

  native_size="$(summary_value "$summary" "NativePNGSize")"
  native_width="${native_size%x*}"
  native_height="${native_size#*x}"
  raster_size="$native_height"
  if [ "$native_width" -gt "$native_height" ]; then
    raster_size="$native_width"
  fi

  if command -v qlmanage >/dev/null 2>&1; then
    if rasterize_svg_with_qlmanage "$core_svg" "$core_png" "$raster_size"; then
      "$BIN" --diff-png "$native_png" "$core_png" "$diff_png" "$summary"
    else
      replace_optional_summary "$summary" "$core_png" "$diff_png" "qlmanage rasterize failed; see $OUT_ABS/$(basename "$core_svg").qlmanage.log"
    fi
  else
    replace_optional_summary "$summary" "$core_png" "$diff_png" "qlmanage not found"
  fi
done
