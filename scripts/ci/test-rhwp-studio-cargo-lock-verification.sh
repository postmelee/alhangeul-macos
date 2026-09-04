#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFIER="$ROOT/scripts/verify-rhwp-studio-assets.sh"
SYNC="$ROOT/scripts/sync-rhwp-studio.sh"
PRODUCTION_RESOURCE="$ROOT/Sources/HostApp/Resources/rhwp-studio"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/rhwp-studio-cargo-lock-test.XXXXXX")"
COMMAND_STDOUT="$TMP_ROOT/command.stdout"
COMMAND_STDERR="$TMP_ROOT/command.stderr"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local expected="$2"
  local description="$3"
  if ! grep -Fq -- "$expected" "$path"; then
    echo "ERROR: $description" >&2
    echo "Expected to contain: $expected" >&2
    echo "Actual content:" >&2
    sed 's/^/  /' "$path" >&2
    exit 1
  fi
}

assert_files_equal() {
  local expected="$1"
  local actual="$2"
  local description="$3"
  if ! cmp -s "$expected" "$actual"; then
    echo "ERROR: $description" >&2
    diff -u "$expected" "$actual" >&2 || true
    exit 1
  fi
}

expect_failure() {
  local description="$1"
  local expected_stderr="$2"
  shift 2
  if "$@" > "$COMMAND_STDOUT" 2> "$COMMAND_STDERR"; then
    fail "$description unexpectedly succeeded"
  fi
  assert_contains "$COMMAND_STDERR" "$expected_stderr" \
    "$description returned an unexpected error"
}

write_pdf_font_fixtures() {
  local font_dir="$1"
  mkdir -p "$font_dir"
  for pdf_font_name in \
    NotoSansKR-Regular.woff2 \
    NotoSansKR-Bold.woff2 \
    NotoSerifKR-Regular.woff2 \
    NotoSerifKR-Bold.woff2
  do
    printf '\167\117\106\062' > "$font_dir/$pdf_font_name"
  done
}

write_resource() {
  local resource_dir="$1"
  local fingerprint="${2:-}"
  local resolved_commit="${3:-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}"
  local fingerprint_line=""

  mkdir -p "$resource_dir/assets"
  write_pdf_font_fixtures "$resource_dir/fonts"
  cat > "$resource_dir/index.html" <<'EOF'
<!doctype html>
<link rel="stylesheet" href="./assets/index-fixture.css">
<link rel="stylesheet" href="./alhangeul-wkwebview-overrides.css">
<script type="module" src="./assets/index-fixture.js"></script>
<span class="sb-color-wrap">
  <button id="btn-text-color">Text color</button>
  <input id="text-color-picker" type="color" />
</span>
EOF
  cat > "$resource_dir/alhangeul-wkwebview-overrides.css" <<'EOF'
select.sb-combo,
select.sb-ls-select {
  appearance: none;
}
@media (pointer: fine) {
  #text-color-picker {
    inset: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
  }
}
EOF
  printf '%s\n' 'console.log("fixture");' > "$resource_dir/assets/index-fixture.js"
  printf '%s\n' 'body { color: black; }' > "$resource_dir/assets/index-fixture.css"
  printf '%s\n' 'fixture-wasm' > "$resource_dir/assets/rhwp_bg-fixture.wasm"
  printf '%s\n' 'fixture-service-worker' > "$resource_dir/registerSW.js"
  printf '%s\n' '{}' > "$resource_dir/manifest.webmanifest"

  if [ -n "$fingerprint" ]; then
    fingerprint_line="  \"source_cargo_lock_sha256\": \"$fingerprint\","
  fi

  cat > "$resource_dir/manifest.json" <<EOF
{
  "name": "rhwp-studio",
  "source_release_tag": "v9.9.9",
  "source_resolved_commit": "$resolved_commit",
$fingerprint_line
  "wasm_build_command": "fixture wasm build",
  "recommended_wasm_build_command": "fixture recommended wasm build",
  "actual_wasm_build_command": "fixture wasm build",
  "studio_build_command": "npx tsc && npx vite build --base ./"
}
EOF
}

write_upstream_checkout() {
  local upstream_dir="$1"
  mkdir -p "$upstream_dir/pkg" "$upstream_dir/rhwp-studio/dist/assets"
  write_pdf_font_fixtures "$upstream_dir/rhwp-studio/dist/fonts"
  printf '%s\n' 'fixture Cargo lock contents' > "$upstream_dir/Cargo.lock"
  printf '%s\n' 'fixture-rhwp-js' > "$upstream_dir/pkg/rhwp.js"
  printf '%s\n' 'fixture-rhwp-wasm' > "$upstream_dir/pkg/rhwp_bg.wasm"
  cat > "$upstream_dir/rhwp-studio/dist/index.html" <<'EOF'
<!doctype html>
<link rel="stylesheet" href="./assets/index-sync.css">
<script type="module" crossorigin src="./assets/index-sync.js"></script>
<span class="sb-color-wrap">
  <button id="btn-text-color">Text color</button>
  <input id="text-color-picker" type="color" />
</span>
EOF
  printf '%s\n' 'console.log("sync fixture");' \
    > "$upstream_dir/rhwp-studio/dist/assets/index-sync.js"
  printf '%s\n' 'body { color: blue; }' \
    > "$upstream_dir/rhwp-studio/dist/assets/index-sync.css"
  printf '%s\n' 'sync-fixture-wasm' \
    > "$upstream_dir/rhwp-studio/dist/assets/rhwp_bg-sync.wasm"
  printf '%s\n' 'sync-service-worker' \
    > "$upstream_dir/rhwp-studio/dist/registerSW.js"
  printf '%s\n' '{}' \
    > "$upstream_dir/rhwp-studio/dist/manifest.webmanifest"

  git -C "$upstream_dir" init -q
  git -C "$upstream_dir" config user.name fixture
  git -C "$upstream_dir" config user.email fixture@example.invalid
  git -C "$upstream_dir" add Cargo.lock pkg rhwp-studio/dist
  git -C "$upstream_dir" commit -qm "fixture upstream"
}

for required_script in "$VERIFIER" "$SYNC"; do
  [ -x "$required_script" ] || fail "missing executable helper: $required_script"
done

production_manifest_before="$TMP_ROOT/production-manifest.before.json"
cp "$PRODUCTION_RESOURCE/manifest.json" "$production_manifest_before"
production_overlay_before="$TMP_ROOT/production-overlay.before.css"
cp "$PRODUCTION_RESOURCE/alhangeul-wkwebview-overrides.css" "$production_overlay_before"

legacy_resource="$TMP_ROOT/legacy-resource"
write_resource "$legacy_resource"
"$VERIFIER" --resource-dir "$legacy_resource" > "$COMMAND_STDOUT"
assert_contains "$COMMAND_STDOUT" "rhwp-studio assets verified" \
  "legacy resource-only verification did not succeed"

# Exercise the same ownership guard used by resource verification and sync.
# Every mutation starts from the valid independent fixture, not production CSS.
color_picker_resource="$TMP_ROOT/color-picker-resource"
write_resource "$color_picker_resource"
color_picker_css="$color_picker_resource/alhangeul-wkwebview-overrides.css"
valid_picker_css="$legacy_resource/alhangeul-wkwebview-overrides.css"
color_picker_checks=1

cat > "$color_picker_css" <<'EOF'
select.sb-combo,
select.sb-ls-select {
  appearance: none;
}
/* The anchor declarations may be compact or reordered. */
@media(pointer:fine){#text-color-picker{pointer-events:none;height:100%;width:100%;inset:0;}}
EOF
"$VERIFIER" --resource-dir "$color_picker_resource" > "$COMMAND_STDOUT"
assert_contains "$COMMAND_STDOUT" "rhwp-studio assets verified" \
  "compact reordered color picker declarations did not succeed"
color_picker_checks=$((color_picker_checks + 1))

while IFS='|' read -r description expected_error transform; do
  sed "$transform" "$valid_picker_css" > "$color_picker_css"
  expect_failure "$description" "$expected_error" \
    "$VERIFIER" --resource-dir "$color_picker_resource"
  color_picker_checks=$((color_picker_checks + 1))
done <<'EOF'
missing inset|must declare color picker inset: 0 exactly once|/^[[:space:]]*inset:/d
missing width|must declare color picker width: 100% exactly once|/^[[:space:]]*width:/d
missing height|must declare color picker height: 100% exactly once|/^[[:space:]]*height:/d
missing pointer-events|must declare color picker pointer-events: none exactly once|/^[[:space:]]*pointer-events:/d
zero-sized anchor|unsupported color picker declaration: width: 0|s/width: 100%/width: 0/
input intercepts pointer|unsupported color picker declaration: pointer-events: auto|s/pointer-events: none/pointer-events: auto/
duplicate declaration|must declare color picker width: 100% exactly once|s/width: 100%;/width: 100%; width: 100%;/
duplicate rule|exactly one #text-color-picker anchor rule|s/#text-color-picker {/#text-color-picker {} #text-color-picker {/
missing rule|exactly one #text-color-picker anchor rule|/#text-color-picker[[:space:]]*{/,/}/d
unexpected picker dimension|unsupported color picker declaration: min-height: 1px|s/inset: 0;/inset: 0; min-height: 1px;/
non-picker width|must not own upstream control dimensions: width: 100%|s/appearance: none;/appearance: none; width: 100%;/
non-picker height|must not own upstream control dimensions: height: 100%|s/appearance: none;/appearance: none; height: 100%;/
non-picker min-height|must not own upstream control dimensions: min-height: 1px|s/appearance: none;/appearance: none; min-height: 1px;/
non-picker alignment|must not own upstream control dimensions: align-items: center|s/appearance: none;/appearance: none; align-items: center;/
leading grouped selector|standalone #text-color-picker selector|s/#text-color-picker {/.other, #text-color-picker {/
trailing grouped selector|standalone #text-color-picker selector|s/#text-color-picker {/#text-color-picker, .other {/
descendant selector|standalone #text-color-picker selector|s/#text-color-picker {/.other #text-color-picker {/
wrong media|scope the color picker anchor to pointer: fine|s/pointer: fine/pointer: coarse/
comment is not a declaration|must declare color picker inset: 0 exactly once|s/inset: 0;/\/\* inset: 0; \*\//
EOF

cp "$valid_picker_css" "$color_picker_css"
printf '\n#style-bar { color: red; }\n' >> "$color_picker_css"
expect_failure "upstream toolbar layout selector" \
  "must not own upstream toolbar layout selectors" \
  "$VERIFIER" --resource-dir "$color_picker_resource"
color_picker_checks=$((color_picker_checks + 1))

cp "$valid_picker_css" "$color_picker_css"
sed 's/id="text-color-picker" type="color"/type="color" id="text-color-picker"/' \
  "$legacy_resource/index.html" > "$color_picker_resource/index.html"
"$VERIFIER" --resource-dir "$color_picker_resource" > "$COMMAND_STDOUT"
assert_contains "$COMMAND_STDOUT" "rhwp-studio assets verified" \
  "reordered color input attributes did not succeed"
color_picker_checks=$((color_picker_checks + 1))

while IFS='|' read -r description expected_error transform; do
  sed "$transform" "$legacy_resource/index.html" > "$color_picker_resource/index.html"
  expect_failure "$description" "$expected_error" \
    "$VERIFIER" --resource-dir "$color_picker_resource"
  color_picker_checks=$((color_picker_checks + 1))
done <<'EOF'
missing color button|missing the text color button|s/id="btn-text-color"/id="retired-text-color"/
missing color input|missing the text color input|s/id="text-color-picker"/id="retired-color-picker"/
wrong input type with decoy|missing the text color input|s/type="color" \/>/type="text" \/><input type="color" \/>/
data-id is not id|missing the text color input|s/id="text-color-picker"/data-id="text-color-picker"/
EOF
echo "OK: rhwp-studio color picker/ownership fixtures passed ($color_picker_checks cases)"

missing_font_resource="$TMP_ROOT/missing-font-resource"
write_resource "$missing_font_resource"
rm "$missing_font_resource/fonts/NotoSansKR-Regular.woff2"
expect_failure "resource without required PDF font" \
  "missing PDF font: $missing_font_resource/fonts/NotoSansKR-Regular.woff2" \
  "$VERIFIER" --resource-dir "$missing_font_resource"

invalid_font_resource="$TMP_ROOT/invalid-font-resource"
write_resource "$invalid_font_resource"
printf '%s\n' 'not-woff2' \
  > "$invalid_font_resource/fonts/NotoSerifKR-Bold.woff2"
expect_failure "resource with invalid PDF font signature" \
  "PDF font is not WOFF2: $invalid_font_resource/fonts/NotoSerifKR-Bold.woff2" \
  "$VERIFIER" --resource-dir "$invalid_font_resource"

symlink_font_resource="$TMP_ROOT/symlink-font-resource"
write_resource "$symlink_font_resource"
rm "$symlink_font_resource/fonts/NotoSansKR-Bold.woff2"
ln -s NotoSansKR-Regular.woff2 \
  "$symlink_font_resource/fonts/NotoSansKR-Bold.woff2"
expect_failure "resource with symlinked PDF font" \
  "PDF font must not be a symlink: $symlink_font_resource/fonts/NotoSansKR-Bold.woff2" \
  "$VERIFIER" --resource-dir "$symlink_font_resource"

upstream_dir="$TMP_ROOT/upstream"
write_upstream_checkout "$upstream_dir"
upstream_commit="$(git -C "$upstream_dir" rev-parse HEAD)"
expected_fingerprint="$(shasum -a 256 "$upstream_dir/Cargo.lock" | awk '{print $1}')"

strict_resource="$TMP_ROOT/strict-resource"
write_resource "$strict_resource" "$expected_fingerprint" "$upstream_commit"
"$VERIFIER" \
  --resource-dir "$strict_resource" \
  --upstream-dir "$upstream_dir" \
  > "$COMMAND_STDOUT"
assert_contains "$COMMAND_STDOUT" \
  "upstream checkout HEAD matches $upstream_commit" \
  "strict fingerprint verification did not bind the checkout commit"
assert_contains "$COMMAND_STDOUT" \
  "manifest source_cargo_lock_sha256 matches $upstream_dir/Cargo.lock" \
  "strict fingerprint verification did not report the compared Cargo.lock"

unknown_commit_resource="$TMP_ROOT/unknown-commit-resource"
write_resource "$unknown_commit_resource" "$expected_fingerprint" \
  "cccccccccccccccccccccccccccccccccccccccc"
expect_failure "strict verification with unavailable expected commit" \
  "expected upstream commit is not available in checkout: cccccccccccccccccccccccccccccccccccccccc" \
  "$VERIFIER" --resource-dir "$unknown_commit_resource" --upstream-dir "$upstream_dir"

malformed_resource="$TMP_ROOT/malformed-resource"
write_resource "$malformed_resource" "not-a-sha256"
expect_failure "malformed manifest fingerprint" \
  "manifest source_cargo_lock_sha256 must be a lowercase sha256 hex string" \
  "$VERIFIER" --resource-dir "$malformed_resource"

mismatch_resource="$TMP_ROOT/mismatch-resource"
write_resource "$mismatch_resource" \
  "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" \
  "$upstream_commit"
expect_failure "upstream fingerprint mismatch" \
  "manifest source_cargo_lock_sha256 does not match upstream root Cargo.lock" \
  "$VERIFIER" --resource-dir "$mismatch_resource" --upstream-dir "$upstream_dir"
assert_contains "$COMMAND_STDERR" "Manifest value:" \
  "fingerprint mismatch omitted the manifest value"
assert_contains "$COMMAND_STDERR" "Actual value:" \
  "fingerprint mismatch omitted the actual value"
assert_contains "$COMMAND_STDERR" "$upstream_dir/Cargo.lock" \
  "fingerprint mismatch omitted the Cargo.lock path"

expect_failure "strict verification without manifest fingerprint" \
  "manifest missing source_cargo_lock_sha256 required for upstream comparison" \
  "$VERIFIER" --resource-dir "$legacy_resource" --upstream-dir "$upstream_dir"

missing_lock_upstream="$TMP_ROOT/missing-lock-upstream"
mkdir -p "$missing_lock_upstream"
expect_failure "strict verification without upstream Cargo.lock" \
  "missing upstream root Cargo.lock: $missing_lock_upstream/Cargo.lock" \
  "$VERIFIER" --resource-dir "$strict_resource" --upstream-dir "$missing_lock_upstream"

expect_failure "strict verification without upstream directory" \
  "missing upstream directory: $TMP_ROOT/missing-upstream" \
  "$VERIFIER" \
    --resource-dir "$strict_resource" \
    --upstream-dir "$TMP_ROOT/missing-upstream"

non_checkout_upstream="$TMP_ROOT/non-checkout-upstream"
mkdir -p "$non_checkout_upstream"
cp "$upstream_dir/Cargo.lock" "$non_checkout_upstream/Cargo.lock"
expect_failure "strict verification without Git checkout" \
  "upstream directory is not a git checkout: $non_checkout_upstream" \
  "$VERIFIER" --resource-dir "$strict_resource" --upstream-dir "$non_checkout_upstream"

expect_failure "upstream option without value" \
  "missing value for --upstream-dir" \
  "$VERIFIER" --upstream-dir

printf '%s\n' 'stale checkout marker' > "$upstream_dir/stale-checkout-marker.txt"
git -C "$upstream_dir" add stale-checkout-marker.txt
git -C "$upstream_dir" commit -qm "advance fixture checkout without changing Cargo.lock"
stale_upstream_head="$(git -C "$upstream_dir" rev-parse HEAD)"
expect_failure "strict verification with stale checkout" \
  "upstream checkout HEAD does not match expected commit" \
  "$VERIFIER" --resource-dir "$strict_resource" --upstream-dir "$upstream_dir"
assert_contains "$COMMAND_STDERR" "Expected commit: $upstream_commit" \
  "stale checkout diagnostic omitted the expected commit"
assert_contains "$COMMAND_STDERR" "Actual HEAD:     $stale_upstream_head" \
  "stale checkout diagnostic omitted the actual HEAD"
assert_contains "$COMMAND_STDERR" "Checkout:        $upstream_dir" \
  "stale checkout diagnostic omitted the checkout path"

sync_target="$TMP_ROOT/sync-target"
write_resource "$sync_target"
upstream_commit="$stale_upstream_head"
"$SYNC" \
  --check \
  --upstream-dir "$upstream_dir" \
  --target-dir "$sync_target" \
  --tag v9.9.9 \
  --commit "$upstream_commit" \
  --actual-wasm-build-command "fixture wasm build" \
  > "$COMMAND_STDOUT"
assert_contains "$COMMAND_STDOUT" \
  "manifest source_cargo_lock_sha256 matches $upstream_dir/Cargo.lock" \
  "sync self-check did not compare the generated fingerprint"
assert_contains "$COMMAND_STDOUT" "rhwp-studio sync check passed" \
  "sync check did not complete"

"$VERIFIER" > "$COMMAND_STDOUT"
assert_files_equal "$production_manifest_before" "$PRODUCTION_RESOURCE/manifest.json" \
  "fixture verification changed the production rhwp-studio manifest"
assert_files_equal "$production_overlay_before" "$PRODUCTION_RESOURCE/alhangeul-wkwebview-overrides.css" \
  "fixture verification changed the production WKWebView override"

echo "OK: rhwp-studio Cargo.lock fingerprint verification fixtures passed"
