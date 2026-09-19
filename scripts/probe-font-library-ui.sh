#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build.noindex/task565-stage2"
APP="$OUT/FontLibraryUIProbe.app"
mkdir -p "$APP/Contents/MacOS" "$OUT/module-cache"
python3 - "$ROOT" "$APP" <<'PY'
import plistlib
import sys
from pathlib import Path
root, app = map(Path, sys.argv[1:])
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(
    CFBundleIdentifier='com.postmelee.alhangeul.FontLibraryUIProbe',
    CFBundleExecutable='FontLibraryUIProbe', CFBundlePackageType='APPL',
    CFBundleVersion='1', LSMinimumSystemVersion='12.0',
    ProbeRepositoryRoot=str(root), NSHighResolutionCapable=True)))
PY
swiftc -parse-as-library -warnings-as-errors -target "$(uname -m)-apple-macosx12.0" \
  -module-cache-path "$OUT/module-cache" \
  "$ROOT"/Sources/Shared/FontLibrary/*.swift \
  "$ROOT/Sources/HostApp/Services/FontLibraryService.swift" \
  "$ROOT/Sources/HostApp/Services/FontImportSourceSession.swift" \
  "$ROOT/Sources/HostApp/Services/MacFontDiscovery.swift" \
  "$ROOT/Sources/HostApp/Views/FontLibrarySettingsModel.swift" \
  "$ROOT/Sources/HostApp/Views/FontLibrarySettingsView.swift" \
  "$ROOT/Sources/HostApp/Views/MacFontImportView.swift" \
  "$ROOT/Tests/FontLibraryUIProbe/main.swift" \
  -o "$APP/Contents/MacOS/FontLibraryUIProbe"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
"$APP/Contents/MacOS/FontLibraryUIProbe" "$@"
