#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFIER="$SCRIPT_DIR/verify-app-execution-endpoint-config.sh"
FIXTURE_ROOT="$(mktemp -d)"
PRODUCTION_ENDPOINT="https://alhangeul-install-events.postmelee.workers.dev/v1/install-events"
ALTERNATE_ORIGIN_ENDPOINT="https://collector.example/v1/install-events"
MISMATCH_ENDPOINT="https://alhangeul-install-events.postmelee.workers.dev/v1/other-events"

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

make_fixture() {
  local name="$1"
  local path="$FIXTURE_ROOT/$name"

  mkdir -p "$path/Sources/HostApp"
  cp "$REPO_ROOT/project.yml" "$path/project.yml"
  cp "$REPO_ROOT/Sources/HostApp/Info.plist" "$path/Sources/HostApp/Info.plist"
  echo "$path"
}

make_built_app() {
  local name="$1"
  local endpoint="$2"
  local app_path="$FIXTURE_ROOT/$name/Alhangeul.app"
  local plist_path="$app_path/Contents/Info.plist"

  mkdir -p "$app_path/Contents"
  ruby - \
    "$REPO_ROOT/Sources/HostApp/Info.plist" \
    "$plist_path" \
    "$endpoint" <<'RUBY'
source_path, output_path, endpoint = ARGV
placeholder = "$(ALHANGEUL_APP_EXECUTION_ENDPOINT)"
contents = File.read(source_path)
abort "source plist placeholder not found" unless contents.include?(placeholder)
File.write(output_path, contents.sub(placeholder, endpoint))
RUBY
  echo "$app_path"
}

make_xml_fallback_path() {
  local path="$FIXTURE_ROOT/xml-fallback-bin"
  local tool
  local tool_path

  mkdir -p "$path"
  for tool in bash dirname ruby uname; do
    tool_path="$(command -v "$tool")"
    [[ -n "$tool_path" ]] || {
      echo "error: required fallback fixture tool not found: $tool" >&2
      exit 1
    }
    ln -s "$tool_path" "$path/$tool"
  done
  echo "$path"
}

replace_once() {
  local path="$1"
  local before="$2"
  local after="$3"

  ruby - "$path" "$before" "$after" <<'RUBY'
path, before, after = ARGV
contents = File.read(path)
abort "fixture source not found: #{before}" unless contents.include?(before)
File.write(path, contents.sub(before, after))
RUBY
}

expect_failure() {
  local name="$1"
  local expected="$2"
  local output="$FIXTURE_ROOT/$name.output"
  shift 2

  if "$@" >"$output" 2>&1; then
    echo "error: fixture unexpectedly passed: $name" >&2
    exit 1
  fi
  if ! grep -Fq "$expected" "$output"; then
    echo "error: fixture failed for an unexpected reason: $name" >&2
    sed -n '1,120p' "$output" >&2
    exit 1
  fi
  echo "Verified failure fixture: $name"
}

"$VERIFIER" --root "$REPO_ROOT"

invalid_base="$(make_fixture invalid-base)"
replace_once \
  "$invalid_base/project.yml" \
  'ALHANGEUL_APP_EXECUTION_ENDPOINT: ""' \
  'ALHANGEUL_APP_EXECUTION_ENDPOINT: https://debug.example/v1/install-events'
expect_failure \
  invalid-base \
  "HostApp base ALHANGEUL_APP_EXECUTION_ENDPOINT must be an empty string" \
  "$VERIFIER" --root "$invalid_base"

invalid_release="$(make_fixture invalid-release)"
replace_once \
  "$invalid_release/project.yml" \
  "$PRODUCTION_ENDPOINT" \
  'http://collector.example/v1/install-events'
expect_failure \
  invalid-release \
  "HostApp Release endpoint must be an absolute HTTPS URL" \
  "$VERIFIER" --root "$invalid_release"

invalid_origin="$(make_fixture invalid-origin)"
replace_once \
  "$invalid_origin/project.yml" \
  "$PRODUCTION_ENDPOINT" \
  "$ALTERNATE_ORIGIN_ENDPOINT"
expect_failure \
  invalid-origin \
  "HostApp Release endpoint origin must be https://alhangeul-install-events.postmelee.workers.dev" \
  "$VERIFIER" --root "$invalid_origin"

invalid_plist="$(make_fixture invalid-plist)"
replace_once \
  "$invalid_plist/Sources/HostApp/Info.plist" \
  "\$(ALHANGEUL_APP_EXECUTION_ENDPOINT)" \
  "$ALTERNATE_ORIGIN_ENDPOINT"
expect_failure \
  invalid-plist \
  "source plist AlhangeulAppExecutionEndpoint must reference \$(ALHANGEUL_APP_EXECUTION_ENDPOINT)" \
  "$VERIFIER" --root "$invalid_plist"

debug_xml_app="$(make_built_app debug-xml "")"
"$VERIFIER" --root "$REPO_ROOT" --debug-app "$debug_xml_app"

release_xml_app="$(make_built_app release-xml "$PRODUCTION_ENDPOINT")"
"$VERIFIER" --root "$REPO_ROOT" --release-app "$release_xml_app"

mismatch_xml_app="$(make_built_app release-mismatch-xml "$MISMATCH_ENDPOINT")"
expect_failure \
  release-mismatch-xml \
  "Release built endpoint does not match project.yml" \
  "$VERIFIER" --root "$REPO_ROOT" --release-app "$mismatch_xml_app"

xml_fallback_path="$(make_xml_fallback_path)"
env PATH="$xml_fallback_path" \
  "$VERIFIER" --root "$REPO_ROOT" --release-app "$release_xml_app"
echo "Verified XML built endpoint fallback without plutil."

if command -v plutil >/dev/null 2>&1; then
  debug_binary_app="$(make_built_app debug-binary "")"
  plutil -convert binary1 "$debug_binary_app/Contents/Info.plist"
  "$VERIFIER" --root "$REPO_ROOT" --debug-app "$debug_binary_app"

  release_binary_app="$(make_built_app release-binary "$PRODUCTION_ENDPOINT")"
  plutil -convert binary1 "$release_binary_app/Contents/Info.plist"
  "$VERIFIER" --root "$REPO_ROOT" --release-app "$release_binary_app"

  expect_failure \
    release-binary-without-plutil \
    "plutil is required to read binary built Info.plist" \
    env PATH="$xml_fallback_path" \
    "$VERIFIER" --root "$REPO_ROOT" --release-app "$release_binary_app"
fi

echo "Analytics endpoint configuration fixtures passed."
