#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RHWP_ROOT="$ROOT/Vendor/rhwp"
LOCK_FILE="$ROOT/rhwp-core.lock"

if [ ! -d "$RHWP_ROOT/.git" ] && [ ! -f "$RHWP_ROOT/.git" ]; then
  echo "ERROR: rhwp submodule is missing: $RHWP_ROOT" >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

git -C "$RHWP_ROOT" fetch origin devel --tags
git -C "$RHWP_ROOT" checkout devel
git -C "$RHWP_ROOT" merge --ff-only origin/devel

COMMIT="$(git -C "$RHWP_ROOT" rev-parse HEAD)"

cat > "$LOCK_FILE" <<EOF
lock_version = 2
rhwp_repo = "https://github.com/edwardkim/rhwp.git"
rhwp_branch = "devel"
rhwp_commit = "$COMMIT"
built_at = ""
ffi_symbols_file = "rhwp-ffi-symbols.txt"

[[artifacts]]
path = "Frameworks/universal/librhwp.a"
sha256 = ""
size = 0

[[artifacts]]
path = "Frameworks/generated_rhwp.h"
sha256 = ""
size = 0
EOF

echo "Updated rhwp core to $COMMIT"
echo "Next: ./scripts/build-rust-macos.sh --update-lock && ./scripts/check-no-appkit.sh"
