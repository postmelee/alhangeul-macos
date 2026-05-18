#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM_DIR="$ROOT/build.noindex/rhwp-upstream"
TARGET="$ROOT/Sources/HostApp/Resources/rhwp-studio"
EXPECTED_RELEASE_TAG=""
EXPECTED_COMMIT=""
CHECK_MODE="false"
CHECK_TARGET=""

usage() {
  cat >&2 <<EOF
Usage: $0 [UPSTREAM_DIR] [options]
       $0 --upstream-dir DIR --tag TAG --commit COMMIT [options]

Options:
  --upstream-dir DIR  Upstream edwardkim/rhwp checkout. Defaults to build.noindex/rhwp-upstream.
  --tag TAG           rhwp release tag to record in manifest. Defaults to current target manifest tag.
  --commit COMMIT     rhwp resolved commit to verify and record. Defaults to current target manifest commit.
  --target-dir DIR    rhwp-studio resource target. Defaults to bundled HostApp resource.
  --check             Sync into a temporary copy of target and verify without changing target-dir.
  -h, --help          Show this help.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
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

validate_tag() {
  local tag="$1"
  if ! [[ "$tag" =~ ^v[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
    fail "rhwp release tag must look like vMAJOR.MINOR.PATCH, got: $tag"
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --upstream-dir)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --upstream-dir"
        fi
        UPSTREAM_DIR="$2"
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
      --target-dir)
        if [ "$#" -lt 2 ]; then
          fail "missing value for --target-dir"
        fi
        TARGET="$2"
        shift
        ;;
      --check)
        CHECK_MODE="true"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --*)
        fail "unknown option: $1"
        ;;
      *)
        if [ "$UPSTREAM_DIR" != "$ROOT/build.noindex/rhwp-upstream" ]; then
          fail "unexpected positional argument: $1"
        fi
        UPSTREAM_DIR="$1"
        ;;
    esac
    shift
  done
}

cleanup() {
  if [ -n "$CHECK_TARGET" ] && [ -d "$CHECK_TARGET" ]; then
    rm -rf "$CHECK_TARGET"
  fi
}
trap cleanup EXIT

file_size_sum() {
  find "$1" -type f -print0 | perl -0ne 'chomp; $sum += -s $_; END { print $sum || 0, "\n" }'
}

first_asset() {
  local pattern="$1"
  find "$TARGET/assets" -maxdepth 1 -name "$pattern" -type f | sort | head -1
}

parse_args "$@"

if [ -z "$EXPECTED_RELEASE_TAG" ] || [ -z "$EXPECTED_COMMIT" ]; then
  if [ ! -f "$TARGET/manifest.json" ]; then
    fail "missing target manifest for default tag/commit: $TARGET/manifest.json"
  fi
fi

if [ -z "$EXPECTED_RELEASE_TAG" ]; then
  EXPECTED_RELEASE_TAG="$(manifest_field "$TARGET/manifest.json" source_release_tag)" \
    || fail "target manifest missing source_release_tag"
fi

if [ -z "$EXPECTED_COMMIT" ]; then
  EXPECTED_COMMIT="$(manifest_field "$TARGET/manifest.json" source_resolved_commit)" \
    || fail "target manifest missing source_resolved_commit"
fi

validate_tag "$EXPECTED_RELEASE_TAG"

if [ ! -d "$UPSTREAM_DIR/.git" ]; then
  fail "missing upstream checkout: $UPSTREAM_DIR"
fi

expected_commit_resolved="$(git -C "$UPSTREAM_DIR" rev-parse --verify "$EXPECTED_COMMIT^{commit}")"
actual_commit="$(git -C "$UPSTREAM_DIR" rev-parse HEAD)"
if [ "$actual_commit" != "$expected_commit_resolved" ]; then
  echo "unexpected upstream commit: $actual_commit" >&2
  echo "expected: $expected_commit_resolved" >&2
  exit 1
fi

DIST="$UPSTREAM_DIR/rhwp-studio/dist"

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

if [ "$CHECK_MODE" = "true" ]; then
  mkdir -p "$ROOT/build.noindex"
  CHECK_TARGET="$(mktemp -d "$ROOT/build.noindex/rhwp-studio-check.XXXXXX")"
  if [ -d "$TARGET" ]; then
    rsync -a "$TARGET/" "$CHECK_TARGET/"
  fi
  TARGET="$CHECK_TARGET"
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

main_js="$(basename "$(first_asset 'index-*.js')")"
main_css="$(basename "$(first_asset 'index-*.css')")"
main_wasm="$(basename "$(first_asset 'rhwp_bg-*.wasm')")"
[ -n "$main_js" ] && [ -f "$TARGET/assets/$main_js" ] || fail "missing synced main JS asset"
[ -n "$main_css" ] && [ -f "$TARGET/assets/$main_css" ] || fail "missing synced main CSS asset"
[ -n "$main_wasm" ] && [ -f "$TARGET/assets/$main_wasm" ] || fail "missing synced WASM asset"
copied_file_count="$(find "$TARGET" -type f | wc -l | tr -d ' ')"
copied_total_bytes="$(file_size_sum "$TARGET")"

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
  "source_resolved_commit": "$expected_commit_resolved",
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

"$ROOT/scripts/verify-rhwp-studio-assets.sh" \
  --resource-dir "$TARGET" \
  --tag "$EXPECTED_RELEASE_TAG" \
  --commit "$expected_commit_resolved"

if [ "$CHECK_MODE" = "true" ]; then
  echo "OK: rhwp-studio sync check passed for $EXPECTED_RELEASE_TAG at $expected_commit_resolved"
else
  echo "OK: rhwp-studio synced to $TARGET from $EXPECTED_RELEASE_TAG at $expected_commit_resolved"
fi
