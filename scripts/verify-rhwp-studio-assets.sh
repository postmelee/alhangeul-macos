#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCE_DIR="$ROOT/Sources/HostApp/Resources/rhwp-studio"
EXPECTED_RELEASE_TAG=""
EXPECTED_COMMIT=""
UPSTREAM_DIR=""

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

usage() {
  cat >&2 <<EOF
Usage: $0 [RESOURCE_DIR] [options]
       $0 [--resource-dir DIR] [--tag TAG] [--commit COMMIT] [--upstream-dir DIR]

Options:
  --resource-dir DIR  rhwp-studio resource directory. Defaults to bundled HostApp resource.
  --tag TAG           Expected rhwp release tag. Defaults to manifest source_release_tag.
  --commit COMMIT     Expected rhwp resolved commit. Defaults to manifest source_resolved_commit.
  --upstream-dir DIR  Compare manifest source_cargo_lock_sha256 with DIR/Cargo.lock.
                      When set, DIR must be a Git checkout at the expected commit;
                      the manifest fingerprint and upstream Cargo.lock are required.
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

validate_sha256() {
  local key="$1"
  local value="$2"
  if ! [[ "$value" =~ ^[0-9a-f]{64}$ ]]; then
    fail "manifest $key must be a lowercase sha256 hex string"
  fi
}

verify_local_override_ownership() {
  local override_css="$1"
  local forbidden_selector_pattern
  local forbidden_dimension_pattern

  forbidden_selector_pattern='^[[:space:]]*(#style-bar|#style-name|\.sb-font-lang|\.sb-font|\.sb-size-group|\.sb-size|\.sb-size-unit|\.sb-size-arrows|\.sb-ls-group|\.sb-ls-arrows|\.sb-arrow)([[:space:]>+~,:{]|$)'
  forbidden_dimension_pattern='^[[:space:]]*(width|height|min-height|align-items)[[:space:]]*:'

  grep -Eq '^[[:space:]]*select\.sb-combo[[:space:],{]' "$override_css" \
    || fail "Alhangeul WKWebView override must retain select.sb-combo presentation"
  grep -Eq '^[[:space:]]*select\.sb-ls-select[[:space:],{]' "$override_css" \
    || fail "Alhangeul WKWebView override must retain select.sb-ls-select presentation"
  grep -Fq 'appearance: none;' "$override_css" \
    || fail "Alhangeul WKWebView override must disable native select appearance"

  if grep -En "$forbidden_selector_pattern" "$override_css"; then
    fail "Alhangeul WKWebView override must not own upstream toolbar layout selectors"
  fi

  if grep -En "$forbidden_dimension_pattern" "$override_css"; then
    fail "Alhangeul WKWebView override must not own upstream control dimensions"
  fi
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
      --upstream-dir)
        if [ "$#" -lt 2 ] || [ -z "$2" ]; then
          fail "missing value for --upstream-dir"
        fi
        UPSTREAM_DIR="$2"
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
[ -d "$RESOURCE_DIR/assets" ] || fail "missing assets directory: $RESOURCE_DIR/assets"

verify_local_override_ownership "$RESOURCE_DIR/alhangeul-wkwebview-overrides.css"

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
grep -Fq "\"source_resolved_commit\": \"$EXPECTED_COMMIT\"" "$RESOURCE_DIR/manifest.json" || fail "manifest commit does not match expected commit $EXPECTED_COMMIT"
source_cargo_lock_sha256=""
if source_cargo_lock_sha256="$(manifest_field "$RESOURCE_DIR/manifest.json" source_cargo_lock_sha256)"; then
  validate_sha256 source_cargo_lock_sha256 "$source_cargo_lock_sha256"
elif [ -n "$UPSTREAM_DIR" ]; then
  fail "manifest missing source_cargo_lock_sha256 required for upstream comparison"
fi

if [ -n "$UPSTREAM_DIR" ]; then
  [ -d "$UPSTREAM_DIR" ] || fail "missing upstream directory: $UPSTREAM_DIR"
  upstream_cargo_lock="$UPSTREAM_DIR/Cargo.lock"
  [ -f "$upstream_cargo_lock" ] || fail "missing upstream root Cargo.lock: $upstream_cargo_lock"
  if ! upstream_head="$(git -C "$UPSTREAM_DIR" rev-parse --verify 'HEAD^{commit}' 2>/dev/null)"; then
    fail "upstream directory is not a git checkout: $UPSTREAM_DIR"
  fi
  if ! expected_upstream_commit="$(git -C "$UPSTREAM_DIR" rev-parse --verify "$EXPECTED_COMMIT^{commit}" 2>/dev/null)"; then
    fail "expected upstream commit is not available in checkout: $EXPECTED_COMMIT"
  fi
  if [ "$upstream_head" != "$expected_upstream_commit" ]; then
    echo "FAIL: upstream checkout HEAD does not match expected commit" >&2
    echo "Expected commit: $expected_upstream_commit" >&2
    echo "Actual HEAD:     $upstream_head" >&2
    echo "Checkout:        $UPSTREAM_DIR" >&2
    exit 1
  fi
  echo "OK: upstream checkout HEAD matches $expected_upstream_commit"
  actual_cargo_lock_sha256="$(shasum -a 256 "$upstream_cargo_lock" | awk '{print $1}')"
  if [ "$source_cargo_lock_sha256" != "$actual_cargo_lock_sha256" ]; then
    echo "FAIL: manifest source_cargo_lock_sha256 does not match upstream root Cargo.lock" >&2
    echo "Manifest value: $source_cargo_lock_sha256" >&2
    echo "Actual value:   $actual_cargo_lock_sha256" >&2
    echo "Cargo.lock:     $upstream_cargo_lock" >&2
    exit 1
  fi
  echo "OK: manifest source_cargo_lock_sha256 matches $upstream_cargo_lock"
fi
wasm_build_command="$(manifest_field "$RESOURCE_DIR/manifest.json" wasm_build_command)" \
  || fail "manifest missing wasm_build_command"
recommended_wasm_build_command="$(manifest_field "$RESOURCE_DIR/manifest.json" recommended_wasm_build_command)" \
  || fail "manifest missing recommended_wasm_build_command"
actual_wasm_build_command="$(manifest_field "$RESOURCE_DIR/manifest.json" actual_wasm_build_command)" \
  || fail "manifest missing actual_wasm_build_command"
[ "$wasm_build_command" = "$actual_wasm_build_command" ] || fail "manifest wasm_build_command must match actual_wasm_build_command"
[ -n "$recommended_wasm_build_command" ] || fail "manifest recommended_wasm_build_command is empty"
[ -n "$actual_wasm_build_command" ] || fail "manifest actual_wasm_build_command is empty"
grep -q '"studio_build_command": "npx tsc && npx vite build --base ./"' "$RESOURCE_DIR/manifest.json" || fail "manifest does not record relative-base build command"

echo "OK: rhwp-studio assets verified at $RESOURCE_DIR"
