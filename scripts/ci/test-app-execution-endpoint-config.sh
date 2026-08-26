#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFIER="$SCRIPT_DIR/verify-app-execution-endpoint-config.sh"
FIXTURE_ROOT="$(mktemp -d)"

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
  local root="$2"
  local expected="$3"
  local output="$FIXTURE_ROOT/$name.output"

  if "$VERIFIER" --root "$root" >"$output" 2>&1; then
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
  "$invalid_base" \
  "HostApp base ALHANGEUL_APP_EXECUTION_ENDPOINT must be an empty string"

invalid_release="$(make_fixture invalid-release)"
replace_once \
  "$invalid_release/project.yml" \
  'https://alhangeul-install-events.postmelee.workers.dev/v1/install-events' \
  'http://collector.example/v1/install-events'
expect_failure \
  invalid-release \
  "$invalid_release" \
  "HostApp Release endpoint must be an absolute HTTPS URL"

invalid_plist="$(make_fixture invalid-plist)"
replace_once \
  "$invalid_plist/Sources/HostApp/Info.plist" \
  "\$(ALHANGEUL_APP_EXECUTION_ENDPOINT)" \
  'https://collector.example/v1/install-events'
expect_failure \
  invalid-plist \
  "$invalid_plist" \
  "source plist AlhangeulAppExecutionEndpoint must reference \$(ALHANGEUL_APP_EXECUTION_ENDPOINT)"

echo "Analytics endpoint configuration fixtures passed."
