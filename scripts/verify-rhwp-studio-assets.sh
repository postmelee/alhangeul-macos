#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCE_DIR="$ROOT/Sources/HostApp/Resources/rhwp-studio"
EXPECTED_RELEASE_TAG=""
EXPECTED_COMMIT=""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

usage() {
  cat >&2 <<EOF
Usage: $0 [RESOURCE_DIR] [options]
       $0 [--resource-dir DIR] [--tag TAG] [--commit COMMIT]

Options:
  --resource-dir DIR  rhwp-studio resource directory. Defaults to bundled HostApp resource.
  --tag TAG           Expected rhwp release tag. Defaults to manifest source_release_tag.
  --commit COMMIT     Expected rhwp resolved commit. Defaults to manifest source_resolved_commit.
  -h, --help          Show this help.
EOF
}

manifest_field() {
  local manifest_path="$1"
  local key="$2"
  awk -F'"' -v key="$key" '
    $0 ~ "\"" key "\"" {
      print $4
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 2
      }
    }
  ' "$manifest_path"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --resource-dir)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --resource-dir"
        fi
        RESOURCE_DIR="$2"
        shift
        ;;
      --tag)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --tag"
        fi
        EXPECTED_RELEASE_TAG="$2"
        shift
        ;;
      --commit)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --commit"
        fi
        EXPECTED_COMMIT="$2"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --*)
        fail "unknown option: $1"
        ;;
      *)
        if [ "$RESOURCE_DIR" != "$ROOT/Sources/HostApp/Resources/rhwp-studio" ]; then
          fail "unexpected positional argument: $1"
        fi
        RESOURCE_DIR="$1"
        ;;
    esac
    shift
  done
}

parse_args "$@"

[ -d "$RESOURCE_DIR" ] || fail "missing resource directory: $RESOURCE_DIR"
[ -f "$RESOURCE_DIR/index.html" ] || fail "missing index.html"
[ -f "$RESOURCE_DIR/manifest.json" ] || fail "missing manifest.json"
[ -f "$RESOURCE_DIR/registerSW.js" ] || fail "missing registerSW.js"
[ -f "$RESOURCE_DIR/manifest.webmanifest" ] || fail "missing manifest.webmanifest"
[ -f "$RESOURCE_DIR/alhangeul-wkwebview-overrides.css" ] || fail "missing Alhangeul WKWebView override stylesheet"

if [ -z "$EXPECTED_RELEASE_TAG" ]; then
  EXPECTED_RELEASE_TAG="$(manifest_field "$RESOURCE_DIR/manifest.json" source_release_tag)" \
    || fail "manifest missing source_release_tag"
fi

if [ -z "$EXPECTED_COMMIT" ]; then
  EXPECTED_COMMIT="$(manifest_field "$RESOURCE_DIR/manifest.json" source_resolved_commit)" \
    || fail "manifest missing source_resolved_commit"
fi

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
grep -q 'href="./alhangeul-wkwebview-overrides.css"' "$RESOURCE_DIR/index.html" || fail "index.html does not load Alhangeul WKWebView override stylesheet"

if grep -q 'crossorigin' "$RESOURCE_DIR/index.html"; then
  fail "index.html contains crossorigin attributes that break WKWebView file URL asset loading"
fi

if grep -Eq ' (src|href)="/' "$RESOURCE_DIR/index.html"; then
  fail "index.html contains root-relative src/href paths"
fi

grep -Fq "\"source_release_tag\": \"$EXPECTED_RELEASE_TAG\"" "$RESOURCE_DIR/manifest.json" || fail "manifest release tag does not match $EXPECTED_RELEASE_TAG"
grep -Fq "\"source_resolved_commit\": \"$EXPECTED_COMMIT\"" "$RESOURCE_DIR/manifest.json" || fail "manifest commit does not match $EXPECTED_RELEASE_TAG resolved commit"
grep -q '"studio_build_command": "npx tsc && npx vite build --base ./"' "$RESOURCE_DIR/manifest.json" || fail "manifest does not record relative-base build command"

echo "OK: rhwp-studio assets verified at $RESOURCE_DIR"
