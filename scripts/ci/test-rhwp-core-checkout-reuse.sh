#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/rhwp-core-reuse.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
REAL_GIT="$(command -v git)"
mkdir -p "$TMP_ROOT/app/scripts" "$TMP_ROOT/app/RustBridge" "$TMP_ROOT/bin" "$TMP_ROOT/upstream/src"
cp "$ROOT/scripts/update-rhwp-core.sh" "$TMP_ROOT/app/scripts/"
cp "$ROOT/RustBridge/Cargo.toml" "$TMP_ROOT/app/RustBridge/"
cp "$ROOT/rhwp-core.lock" "$TMP_ROOT/app/"
export REUSE_TEST_REAL_GIT="$REAL_GIT" REUSE_TEST_REMOTE="$TMP_ROOT/upstream"
cat > "$TMP_ROOT/bin/git" <<'SH'
#!/bin/bash
if [ "${1:-}" = ls-remote ]; then
  exec "$REUSE_TEST_REAL_GIT" ls-remote --tags "$REUSE_TEST_REMOTE" "${4}" "${5}"
fi
exec "$REUSE_TEST_REAL_GIT" "$@"
SH
chmod +x "$TMP_ROOT/bin/git"
export PATH="$TMP_ROOT/bin:$PATH"
cat > "$TMP_ROOT/upstream/src/lib.rs" <<'RS'
// API detection fixture; this is never built.
// build_page_render_tree get_bin_data render_page_svg_native
// get_page_info_native extract_thumbnail_only
RS
printf 'fixture lock\n' > "$TMP_ROOT/upstream/Cargo.lock"
git -C "$TMP_ROOT/upstream" init -q
git -C "$TMP_ROOT/upstream" config user.name fixture
git -C "$TMP_ROOT/upstream" config user.email fixture@example.invalid
git -C "$TMP_ROOT/upstream" add .
git -C "$TMP_ROOT/upstream" commit -qm fixture
git -C "$TMP_ROOT/upstream" tag -a v9.9.9 -m fixture
sha="$(git -C "$TMP_ROOT/upstream" rev-parse HEAD)"
linked="$TMP_ROOT/linked"
git -C "$TMP_ROOT/upstream" worktree add -q --detach "$linked" "$sha"
script="$TMP_ROOT/app/scripts/update-rhwp-core.sh"
run_check() { bash "$script" --channel stable --tag v9.9.9 --check --upstream-dir "$1"; }
reject() {
  local expected="$1"; shift
  if "$@" > "$TMP_ROOT/result" 2>&1; then echo "ERROR: expected rejection: $expected" >&2; exit 1; fi
  grep -Fq "$expected" "$TMP_ROOT/result"
}
before="$(shasum -a 256 "$TMP_ROOT/app/RustBridge/Cargo.toml" "$TMP_ROOT/app/rhwp-core.lock")"
run_check "$linked" > "$TMP_ROOT/result"
grep -Fq "$sha" "$TMP_ROOT/result"
[ -f "$linked/.git" ] && [ -f "$linked/src/lib.rs" ]
printf 'dirty\n' >> "$linked/src/lib.rs"
reject 'modified core source or lock' run_check "$linked"
git -C "$linked" restore src/lib.rs
reject 'not a git checkout' run_check "$TMP_ROOT/bin"
reject 'not a git checkout' run_check "$TMP_ROOT/absent"
reject 'does not match verified target commit' bash "$script" --channel demo \
  --rev aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa --check --upstream-dir "$linked"
git -C "$linked" config user.name fixture
git -C "$linked" config user.email fixture@example.invalid
printf '// no required API\n' > "$linked/src/lib.rs"
git -C "$linked" add src/lib.rs
git -C "$linked" commit -qm missing-api
missing_sha="$(git -C "$linked" rev-parse HEAD)"
reject 'missing core API' bash "$script" --channel demo --rev "$missing_sha" --check --upstream-dir "$linked"
[ "$before" = "$(shasum -a 256 "$TMP_ROOT/app/RustBridge/Cargo.toml" "$TMP_ROOT/app/rhwp-core.lock")" ]
[ -d "$linked" ]
echo 'PASS: annotated tag/worktree reuse; dirty/stale/non-checkout/API rejection; input preservation'
