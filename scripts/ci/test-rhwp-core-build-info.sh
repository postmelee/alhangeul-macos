#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
READ_LOCK="$ROOT/scripts/ci/read-rhwp-core-lock.sh"
WRITER="$ROOT/scripts/update-rhwp-core-build-info.sh"
VERIFIER="$ROOT/scripts/verify-rhwp-core-build-info.sh"
PRODUCTION_LOCK="$ROOT/rhwp-core.lock"
PRODUCTION_BUILD_INFO="$ROOT/Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift"
COMMIT_A="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
COMMIT_B="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/rhwp-build-info-test.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

file_sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  local description="$3"
  if [ "$expected" != "$actual" ]; then
    echo "ERROR: $description" >&2
    echo "Expected: $expected" >&2
    echo "Actual:   $actual" >&2
    exit 1
  fi
}

expect_failure() {
  local description="$1"
  local expected_stderr="$2"
  shift 2
  if "$@" > "$TMP_ROOT/command.stdout" 2> "$TMP_ROOT/command.stderr"; then
    fail "$description unexpectedly succeeded"
  fi
  if ! grep -Fq -- "$expected_stderr" "$TMP_ROOT/command.stderr"; then
    echo "ERROR: $description returned an unexpected error" >&2
    echo "Expected stderr to contain: $expected_stderr" >&2
    echo "Actual stderr:" >&2
    sed 's/^/  /' "$TMP_ROOT/command.stderr" >&2
    exit 1
  fi
}

write_stable_lock() {
  local path="$1"
  local tag="$2"
  local commit="$3"
  local features="$4"
  {
    echo 'lock_version = 2'
    echo 'rhwp_ref_kind = "release-tag"'
    echo "rhwp_release_tag = \"$tag\""
    echo "rhwp_commit = \"$commit\""
    echo "rhwp_enabled_features = \"$features\""
  } > "$path"
}

write_demo_lock() {
  local path="$1"
  local tag="$2"
  local commit="$3"
  local features="$4"
  {
    echo 'lock_version = 2'
    echo 'rhwp_ref_kind = "commit"'
    echo "rhwp_commit = \"$commit\""
    echo "rhwp_enabled_features = \"$features\""
    echo "rhwp_latest_checked_release_tag = \"$tag\""
  } > "$path"
}

write_build_info() {
  local path="$1"
  local tag="$2"
  local commit="$3"
  local features="$4"
  {
    echo 'enum RhwpCoreBuildInfo {'
    echo "    static let releaseTag = \"$tag\""
    echo "    static let commit = \"$commit\""
    echo "    static let enabledFeatures = \"$features\""
    echo '}'
  } > "$path"
}

assert_writer_rejects_without_change() {
  local description="$1"
  local lock_file="$2"
  local expected_stderr="$3"
  local output="$TMP_ROOT/rejected.swift"
  local before_hash
  local after_hash
  printf '%s\n' 'sentinel build info' > "$output"
  before_hash="$(file_sha256 "$output")"
  expect_failure "$description" "$expected_stderr" \
    "$WRITER" --lock-file "$lock_file" --output "$output"
  after_hash="$(file_sha256 "$output")"
  assert_equal "$before_hash" "$after_hash" "$description changed its output"
}

for required_file in "$READ_LOCK" "$WRITER" "$VERIFIER"; do
  if [ ! -x "$required_file" ]; then
    fail "missing executable helper: $required_file"
  fi
done

production_lock_before="$(file_sha256 "$PRODUCTION_LOCK")"
production_build_info_before="$(file_sha256 "$PRODUCTION_BUILD_INFO")"

stable_lock="$TMP_ROOT/stable.lock"
stable_output="$TMP_ROOT/stable.swift"
stable_expected="$TMP_ROOT/stable.expected.swift"
write_stable_lock "$stable_lock" "v0.9.0" "$COMMIT_A" "native-skia"
write_build_info "$stable_expected" "v0.9.0" "$COMMIT_A" "native-skia"
"$WRITER" --lock-file "$stable_lock" --output "$stable_output"
diff -u "$stable_expected" "$stable_output"
"$VERIFIER" --lock-file "$stable_lock" --build-info "$stable_output"
assert_equal "$COMMIT_A" "$("$READ_LOCK" --lock-file "$stable_lock" rhwp_commit)" \
  "lock reader fixture path returned a different commit"

stable_hash_before="$(file_sha256 "$stable_output")"
"$WRITER" --lock-file "$stable_lock" --output "$stable_output"
stable_hash_after="$(file_sha256 "$stable_output")"
assert_equal "$stable_hash_before" "$stable_hash_after" "writer rerun was not byte-identical"

write_build_info "$stable_output" "v0.8.9" "$COMMIT_A" "native-skia"
expect_failure "stale release tag verifier" \
  "RhwpCoreBuildInfo.releaseTag differs from rhwp-core.lock" \
  "$VERIFIER" --lock-file "$stable_lock" --build-info "$stable_output"
"$WRITER" --lock-file "$stable_lock" --output "$stable_output"
"$VERIFIER" --lock-file "$stable_lock" --build-info "$stable_output"

write_build_info "$stable_output" "v0.9.0" "$COMMIT_B" "native-skia"
expect_failure "stale commit verifier" \
  "RhwpCoreBuildInfo.commit differs from rhwp-core.lock" \
  "$VERIFIER" --lock-file "$stable_lock" --build-info "$stable_output"
"$WRITER" --lock-file "$stable_lock" --output "$stable_output"
"$VERIFIER" --lock-file "$stable_lock" --build-info "$stable_output"

write_build_info "$stable_output" "v0.9.0" "$COMMIT_A" "svg"
expect_failure "stale features verifier" \
  "RhwpCoreBuildInfo.enabledFeatures differs from rhwp-core.lock" \
  "$VERIFIER" --lock-file "$stable_lock" --build-info "$stable_output"
"$WRITER" --lock-file "$stable_lock" --output "$stable_output"
"$VERIFIER" --lock-file "$stable_lock" --build-info "$stable_output"

demo_lock="$TMP_ROOT/demo.lock"
demo_output="$TMP_ROOT/demo.swift"
demo_expected="$TMP_ROOT/demo.expected.swift"
write_demo_lock "$demo_lock" "v0.9.1" "$COMMIT_B" "native-skia,svg"
write_build_info "$demo_expected" "v0.9.1" "$COMMIT_B" "native-skia,svg"
"$WRITER" --lock-file "$demo_lock" --output "$demo_output"
diff -u "$demo_expected" "$demo_output"
"$VERIFIER" --lock-file "$demo_lock" --build-info "$demo_output"

invalid_lock="$TMP_ROOT/invalid.lock"

write_stable_lock "$invalid_lock" "v0.9.0" "$COMMIT_A" "native-skia"
sed 's/lock_version = 2/lock_version = 1/' "$invalid_lock" > "$TMP_ROOT/invalid-version.lock"
assert_writer_rejects_without_change "unsupported lock version" \
  "$TMP_ROOT/invalid-version.lock" "unsupported rhwp-core.lock version"

sed 's/rhwp_ref_kind = "release-tag"/rhwp_ref_kind = "branch"/' \
  "$invalid_lock" > "$TMP_ROOT/invalid-ref-kind.lock"
assert_writer_rejects_without_change "unsupported ref kind" \
  "$TMP_ROOT/invalid-ref-kind.lock" "unsupported rhwp_ref_kind"

sed '/^rhwp_release_tag = /d' "$invalid_lock" > "$TMP_ROOT/missing-stable-tag.lock"
assert_writer_rejects_without_change "missing stable release tag" \
  "$TMP_ROOT/missing-stable-tag.lock" "missing lock key: rhwp_release_tag"

sed '/^rhwp_commit = /d' "$invalid_lock" > "$TMP_ROOT/missing-commit.lock"
assert_writer_rejects_without_change "missing commit" \
  "$TMP_ROOT/missing-commit.lock" "missing lock key: rhwp_commit"

sed '/^rhwp_enabled_features = /d' "$invalid_lock" > "$TMP_ROOT/missing-features.lock"
assert_writer_rejects_without_change "missing enabled features" \
  "$TMP_ROOT/missing-features.lock" "missing lock key: rhwp_enabled_features"

write_demo_lock "$TMP_ROOT/missing-demo-tag.lock" "v0.9.1" "$COMMIT_B" "native-skia"
sed '/^rhwp_latest_checked_release_tag = /d' \
  "$TMP_ROOT/missing-demo-tag.lock" > "$TMP_ROOT/missing-demo-tag.filtered.lock"
assert_writer_rejects_without_change \
  "missing demo latest checked release tag" "$TMP_ROOT/missing-demo-tag.filtered.lock" \
  "missing lock key: rhwp_latest_checked_release_tag"

write_stable_lock "$TMP_ROOT/invalid-tag.lock" 'v0.9.0"bad' "$COMMIT_A" "native-skia"
assert_writer_rejects_without_change "invalid release tag" \
  "$TMP_ROOT/invalid-tag.lock" "invalid rhwp_release_tag"

write_stable_lock "$TMP_ROOT/invalid-commit.lock" "v0.9.0" "ABC123" "native-skia"
assert_writer_rejects_without_change "invalid commit" \
  "$TMP_ROOT/invalid-commit.lock" "invalid rhwp_commit"

write_stable_lock "$TMP_ROOT/invalid-features.lock" "v0.9.0" "$COMMIT_A" "native-skia, bad"
assert_writer_rejects_without_change "invalid enabled features" \
  "$TMP_ROOT/invalid-features.lock" "invalid rhwp_enabled_features"

expect_failure "writer unknown argument" "unknown argument: --unknown" "$WRITER" --unknown
expect_failure "verifier unknown argument" "unknown argument: --unknown" "$VERIFIER" --unknown
expect_failure "lock reader missing option value" "--lock-file requires a path" \
  "$READ_LOCK" --lock-file

production_lock_after="$(file_sha256 "$PRODUCTION_LOCK")"
production_build_info_after="$(file_sha256 "$PRODUCTION_BUILD_INFO")"
assert_equal "$production_lock_before" "$production_lock_after" \
  "fixture test changed the production rhwp-core.lock"
assert_equal "$production_build_info_before" "$production_build_info_after" \
  "fixture test changed the production RhwpCoreBuildInfo.swift"

echo "OK: RhwpCoreBuildInfo writer and verifier fixtures passed"
