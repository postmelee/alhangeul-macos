#!/bin/bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 --docs-dir <dir> --appcast <file> --output-dir <dir>

Prepares a GitHub Pages artifact directory for Alhangeul.

Required inputs:
  --docs-dir     Source docs directory tracked in the repository.
  --appcast      Generated Sparkle appcast XML to publish as appcast.xml.
  --output-dir   New output directory for the Pages artifact contents.

Options:
  -h, --help     Show this help.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

real_dir() {
  local dir="$1"
  (cd "$dir" && pwd -P)
}

real_file() {
  local file="$1"
  local dir
  local base
  dir="$(dirname "$file")"
  base="$(basename "$file")"
  printf '%s/%s' "$(real_dir "$dir")" "$base"
}

DOCS_DIR=""
APPCAST_FILE=""
OUTPUT_DIR=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --docs-dir)
      shift
      [ "$#" -gt 0 ] || fail "--docs-dir requires a value"
      DOCS_DIR="$1"
      ;;
    --appcast)
      shift
      [ "$#" -gt 0 ] || fail "--appcast requires a value"
      APPCAST_FILE="$1"
      ;;
    --output-dir)
      shift
      [ "$#" -gt 0 ] || fail "--output-dir requires a value"
      OUTPUT_DIR="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
  shift
done

[ -n "$DOCS_DIR" ] || fail "--docs-dir is required"
[ -n "$APPCAST_FILE" ] || fail "--appcast is required"
[ -n "$OUTPUT_DIR" ] || fail "--output-dir is required"

[ -d "$DOCS_DIR" ] || fail "--docs-dir does not exist or is not a directory: $DOCS_DIR"
[ -f "$APPCAST_FILE" ] || fail "--appcast does not exist or is not a file: $APPCAST_FILE"
[ -s "$APPCAST_FILE" ] || fail "--appcast is empty: $APPCAST_FILE"
DOCS_REAL="$(real_dir "$DOCS_DIR")"
APPCAST_REAL="$(real_file "$APPCAST_FILE")"
OUTPUT_PARENT="$(dirname "$OUTPUT_DIR")"
OUTPUT_NAME="$(basename "$OUTPUT_DIR")"
mkdir -p "$OUTPUT_PARENT"
OUTPUT_PARENT_REAL="$(real_dir "$OUTPUT_PARENT")"
OUTPUT_REAL="$OUTPUT_PARENT_REAL/$OUTPUT_NAME"

if [ "$DOCS_REAL" = "$OUTPUT_REAL" ]; then
  fail "--output-dir must be different from --docs-dir"
fi

case "$OUTPUT_REAL/" in
  "$DOCS_REAL/"*)
    fail "--output-dir must not be inside --docs-dir"
    ;;
esac

case "$OUTPUT_REAL/" in
  */build.noindex/*)
    ;;
  *)
    fail "--output-dir must be under build.noindex"
    ;;
esac

if [ ! -f "$DOCS_REAL/index.html" ]; then
  fail "--docs-dir must contain index.html"
fi

if [ ! -f "$DOCS_REAL/updates/index.html" ]; then
  fail "--docs-dir must contain updates/index.html"
fi

if find "$DOCS_REAL" -type l -print -quit | grep -q .; then
  fail "--docs-dir must not contain symbolic links for Pages artifact upload"
fi

TMP_DIR="$(mktemp -d "$OUTPUT_PARENT_REAL/.pages-artifact.XXXXXX")"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cp -R "$DOCS_REAL"/. "$TMP_DIR"/
find "$TMP_DIR" -name .DS_Store -type f -delete
cp "$APPCAST_REAL" "$TMP_DIR/appcast.xml"

[ -f "$TMP_DIR/index.html" ] || fail "prepared artifact is missing index.html"
[ -f "$TMP_DIR/updates/index.html" ] || fail "prepared artifact is missing updates/index.html"
[ -s "$TMP_DIR/appcast.xml" ] || fail "prepared artifact is missing appcast.xml"

rm -rf "$OUTPUT_REAL"
mv "$TMP_DIR" "$OUTPUT_REAL"
trap - EXIT

echo "Prepared Pages artifact at $OUTPUT_REAL"
