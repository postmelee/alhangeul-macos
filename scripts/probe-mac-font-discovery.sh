#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build.noindex/mac-font-discovery-probe"
mkdir -p "$OUT/module-cache"
swiftc -parse-as-library -warnings-as-errors -target "$(uname -m)-apple-macosx12.0" \
  -module-cache-path "$OUT/module-cache" \
  "$ROOT"/Sources/Shared/FontLibrary/*.swift \
  "$ROOT/Sources/HostApp/Services/FontLibraryService.swift" \
  "$ROOT/Sources/HostApp/Services/FontImportSourceSession.swift" \
  "$ROOT/Sources/HostApp/Services/MacFontDiscovery.swift" \
  "$ROOT/Tests/MacFontDiscoveryProbe/main.swift" -o "$OUT/probe"
"$OUT/probe"
