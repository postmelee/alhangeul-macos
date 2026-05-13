#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM_DIR="${1:-"$ROOT/build.noindex/rhwp-upstream"}"
EXPECTED_RELEASE_TAG="v0.7.11"
EXPECTED_COMMIT="a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae"
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
rsync -a --delete \
  --exclude 'samples/' \
  --exclude 'alhangeul-wkwebview-overrides.css' \
  --exclude 'fonts/FONTS.md' \
  "$DIST/" "$TARGET/"
find "$TARGET" -type f -exec chmod 0644 {} +

# WKWebView file URL loading treats explicit crossorigin subresource requests
# conservatively. Keep bundled same-directory JS/CSS as normal same-origin
# file resources so the studio UI is styled and bootstrapped in HostApp.
/usr/bin/perl -0pi -e 's/\s+crossorigin(?=\s|>)//g' "$TARGET/index.html"
if [ -f "$TARGET/alhangeul-wkwebview-overrides.css" ] \
  && ! grep -q 'alhangeul-wkwebview-overrides.css' "$TARGET/index.html"; then
  /usr/bin/perl -0pi -e \
    's#(<link rel="stylesheet" href="\./assets/index-[^"]+\.css">\n?)#$1  <link rel="stylesheet" href="./alhangeul-wkwebview-overrides.css">\n#' \
    "$TARGET/index.html"
fi

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
  "source_release_tag": "$EXPECTED_RELEASE_TAG",
  "source_resolved_commit": "$EXPECTED_COMMIT",
  "wasm_build_command": "docker-compose --env-file .env.docker run --rm wasm",
  "studio_build_command": "npx tsc && npx vite build --base ./",
  "copied_from": "rhwp-studio/dist",
  "excluded_paths": [
    "samples/"
  ],
  "local_overlay_paths": [
    "alhangeul-wkwebview-overrides.css",
    "fonts/FONTS.md"
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
