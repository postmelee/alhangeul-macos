#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM_DIR="${1:-"$ROOT/build.noindex/rhwp-upstream-task134"}"
EXPECTED_COMMIT="0fb3e6758b8ad11d2f3c3849c83b914684e83863"
TARGET="$ROOT/Sources/HostApp/Resources/rhwp-studio"
DIST="$UPSTREAM_DIR/rhwp-studio/dist"

if [ ! -d "$UPSTREAM_DIR/.git" ]; then
  echo "missing upstream checkout: $UPSTREAM_DIR" >&2
  exit 1
fi

actual_commit="$(git -C "$UPSTREAM_DIR" rev-parse HEAD)"
if [ "$actual_commit" != "$EXPECTED_COMMIT" ]; then
  echo "unexpected upstream commit: $actual_commit" >&2
  echo "expected: $EXPECTED_COMMIT" >&2
  exit 1
fi

if [ ! -f "$UPSTREAM_DIR/pkg/rhwp.js" ] || [ ! -f "$UPSTREAM_DIR/pkg/rhwp_bg.wasm" ]; then
  echo "missing upstream WASM pkg; run from upstream checkout:" >&2
  echo "  docker-compose --env-file .env.docker run --rm wasm" >&2
  exit 1
fi

if [ ! -f "$DIST/index.html" ]; then
  echo "missing rhwp-studio dist; run from upstream rhwp-studio:" >&2
  echo "  npm ci" >&2
  echo "  npx tsc && npx vite build --base ./" >&2
  exit 1
fi

mkdir -p "$TARGET"
rsync -a --delete --exclude 'samples/' "$DIST/" "$TARGET/"

main_js="$(basename "$(find "$TARGET/assets" -maxdepth 1 -name 'index-*.js' -type f | head -1)")"
main_css="$(basename "$(find "$TARGET/assets" -maxdepth 1 -name 'index-*.css' -type f | head -1)")"
main_wasm="$(basename "$(find "$TARGET/assets" -maxdepth 1 -name 'rhwp_bg-*.wasm' -type f | head -1)")"
copied_file_count="$(find "$TARGET" -type f | wc -l | tr -d ' ')"
copied_total_bytes="$(find "$TARGET" -type f -print0 | xargs -0 stat -f '%z' | awk '{s+=$1} END {print s+0}')"

index_sha="$(shasum -a 256 "$TARGET/index.html" | awk '{print $1}')"
js_sha="$(shasum -a 256 "$TARGET/assets/$main_js" | awk '{print $1}')"
css_sha="$(shasum -a 256 "$TARGET/assets/$main_css" | awk '{print $1}')"
wasm_sha="$(shasum -a 256 "$TARGET/assets/$main_wasm" | awk '{print $1}')"

cat > "$TARGET/manifest.json" <<JSON
{
  "name": "rhwp-studio",
  "source_repository": "https://github.com/edwardkim/rhwp.git",
  "source_ref_kind": "release-tag",
  "source_release_tag": "v0.7.9",
  "source_resolved_commit": "$EXPECTED_COMMIT",
  "wasm_build_command": "docker-compose --env-file .env.docker run --rm wasm",
  "studio_build_command": "npx tsc && npx vite build --base ./",
  "copied_from": "rhwp-studio/dist",
  "excluded_paths": [
    "samples/"
  ],
  "copied_file_count": $copied_file_count,
  "copied_total_bytes": $copied_total_bytes,
  "entrypoints": {
    "index_html": {
      "path": "index.html",
      "sha256": "$index_sha"
    },
    "main_js": {
      "path": "assets/$main_js",
      "sha256": "$js_sha"
    },
    "main_css": {
      "path": "assets/$main_css",
      "sha256": "$css_sha"
    },
    "wasm": {
      "path": "assets/$main_wasm",
      "sha256": "$wasm_sha"
    }
  }
}
JSON

"$ROOT/scripts/verify-rhwp-studio-assets.sh" "$TARGET"
