#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$#" -ne 1 ] || [ "${1:-}" = "--help" ]; then
  echo "Usage: $0 <Alhangeul.app>"
  echo "Checks the embedded CFPlugIn directly; does not register or index files."
  if [ "${1:-}" = "--help" ]; then exit 0; fi
  exit 1
fi
APP_PATH="$(cd "$1" && pwd)"
python3 "$ROOT/scripts/ci/check-spotlight-bundle.py" --app "$APP_PATH"
SPOTLIGHT_TEST_DIR="$(mktemp -d "$ROOT/build.noindex/spotlight-check.XXXXXX")"
trap 'rm -rf "$SPOTLIGHT_TEST_DIR"' EXIT
CHECKER="$SPOTLIGHT_TEST_DIR/checker"
IMPORTER="$APP_PATH/Contents/Library/Spotlight/Alhangeul.mdimporter"
xcrun clang -mmacosx-version-min=12.0 "$ROOT/scripts/ci/spotlight_importer_check.c" \
  -framework CoreFoundation -framework CoreServices -o "$CHECKER"
"$CHECKER" "$IMPORTER" "$ROOT/samples/re-05-mixed-koen-hancom.hwp" 한글
"$CHECKER" "$IMPORTER" "$ROOT/samples/hwpx/ref/ref_text.hwpx" ""
"$CHECKER" "$IMPORTER" "$SPOTLIGHT_TEST_DIR/missing.hwp" --no-text
printf 'invalid synthetic file' > "$SPOTLIGHT_TEST_DIR/invalid.hwp"
"$CHECKER" "$IMPORTER" "$SPOTLIGHT_TEST_DIR/invalid.hwp" --no-text
: > "$SPOTLIGHT_TEST_DIR/empty.hwp"
"$CHECKER" "$IMPORTER" "$SPOTLIGHT_TEST_DIR/empty.hwp" --no-text
"$CHECKER" "$IMPORTER" "$SPOTLIGHT_TEST_DIR" --no-text
ln -s "$ROOT/samples/re-05-mixed-koen-hancom.hwp" "$SPOTLIGHT_TEST_DIR/link.hwp"
"$CHECKER" "$IMPORTER" "$SPOTLIGHT_TEST_DIR/link.hwp" --no-text
mkfifo "$SPOTLIGHT_TEST_DIR/pipe.hwp"
"$CHECKER" "$IMPORTER" "$SPOTLIGHT_TEST_DIR/pipe.hwp" --no-text
python3 - "$SPOTLIGHT_TEST_DIR/large.hwp" <<'PY'
import sys
with open(sys.argv[1], 'wb') as stream:
    stream.truncate(32 * 1024 * 1024 + 1)
PY
"$CHECKER" "$IMPORTER" "$SPOTLIGHT_TEST_DIR/large.hwp" --no-text
