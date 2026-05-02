#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCE_DIR="${1:-"$ROOT/Sources/HostApp/Resources/rhwp-studio"}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -d "$RESOURCE_DIR" ] || fail "missing resource directory: $RESOURCE_DIR"
[ -f "$RESOURCE_DIR/index.html" ] || fail "missing index.html"
[ -f "$RESOURCE_DIR/manifest.json" ] || fail "missing manifest.json"
[ -f "$RESOURCE_DIR/registerSW.js" ] || fail "missing registerSW.js"
[ -f "$RESOURCE_DIR/manifest.webmanifest" ] || fail "missing manifest.webmanifest"

js_count="$(find "$RESOURCE_DIR/assets" -maxdepth 1 -name 'index-*.js' -type f | wc -l | tr -d ' ')"
css_count="$(find "$RESOURCE_DIR/assets" -maxdepth 1 -name 'index-*.css' -type f | wc -l | tr -d ' ')"
wasm_count="$(find "$RESOURCE_DIR/assets" -maxdepth 1 -name 'rhwp_bg-*.wasm' -type f | wc -l | tr -d ' ')"

[ "$js_count" = "1" ] || fail "expected one main JS asset, found $js_count"
[ "$css_count" = "1" ] || fail "expected one main CSS asset, found $css_count"
[ "$wasm_count" = "1" ] || fail "expected one WASM asset, found $wasm_count"

if [ -d "$RESOURCE_DIR/samples" ]; then
  fail "samples/ must not be bundled in HostApp rhwp-studio resources"
fi

grep -q 'src="./assets/index-' "$RESOURCE_DIR/index.html" || fail "index.html does not use relative JS asset path"
grep -q 'href="./assets/index-' "$RESOURCE_DIR/index.html" || fail "index.html does not use relative CSS asset path"

if grep -Eq ' (src|href)="/' "$RESOURCE_DIR/index.html"; then
  fail "index.html contains root-relative src/href paths"
fi

grep -q '"source_resolved_commit": "0fb3e6758b8ad11d2f3c3849c83b914684e83863"' "$RESOURCE_DIR/manifest.json" || fail "manifest commit does not match v0.7.9 resolved commit"
grep -q '"studio_build_command": "npx tsc && npx vite build --base ./"' "$RESOURCE_DIR/manifest.json" || fail "manifest does not record relative-base build command"

echo "OK: rhwp-studio assets verified at $RESOURCE_DIR"
