#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

SHARED_FILES=(
  "$ROOT/Sources/RhwpCoreBridge/RhwpDocument.swift"
  "$ROOT/Sources/RhwpCoreBridge/RenderTree.swift"
  "$ROOT/Sources/RhwpCoreBridge/FontFallback.swift"
  "$ROOT/Sources/RhwpCoreBridge/FontResourceRegistry.swift"
  "$ROOT/Sources/RhwpCoreBridge/CGTreeRenderer.swift"
)

HITS=""
for file in "${SHARED_FILES[@]}"; do
  FOUND=$(grep -nE 'AppKit|NSColor|NSImage|NSFont|NSView|UIKit|UIColor|UIImage|UIFont|UIBezier' "$file" 2>/dev/null || true)
  if [ -n "$FOUND" ]; then
    HITS+="$file:"$'\n'"$FOUND"$'\n'
  fi
done

if [ -n "$HITS" ]; then
  echo "FAIL: shared Swift code must not depend on AppKit/UIKit"
  printf '%s' "$HITS"
  exit 1
fi

echo "OK: shared Swift code has no AppKit/UIKit dependencies"
