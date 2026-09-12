#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $0

Compiles RenderTree.swift with an isolated fixture and verifies both current
JSON without the retired dirty field, legacy JSON that still contains it,
a complete TextRun/TextStyle payload, strict known-variant failures, unknown
future variants, malformed envelopes and sanitized nested diagnostics.
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "$#" -ne 0 ]; then
  usage
  exit 2
fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/alhangeul-render-tree-decoder.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

MODULE_CACHE="$TMP_ROOT/swift-module-cache"
BIN="$TMP_ROOT/render-tree-decoder-fixture"
mkdir -p "$MODULE_CACHE"

echo "Decoder runtime: macOS $(sw_vers -productVersion), $(uname -m)"

swiftc -parse-as-library \
  -module-cache-path "$MODULE_CACHE" \
  "$ROOT/Sources/RhwpCoreBridge/RenderTree.swift" \
  "$ROOT/scripts/ci/render_tree_decoder_fixture.swift" \
  -o "$BIN"

"$BIN"
