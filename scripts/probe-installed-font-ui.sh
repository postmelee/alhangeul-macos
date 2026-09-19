#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build.noindex/task565-stage5"
APP="$OUT/InstalledFontUIProbe.app"
mkdir -p "$APP/Contents/MacOS" "$OUT/module-cache"
python3 - "$ROOT" "$APP" <<'PY'
import plistlib
import sys
from pathlib import Path
root, app = map(Path, sys.argv[1:])
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(
    CFBundleIdentifier='com.postmelee.alhangeul.InstalledFontUIProbe',
    CFBundleExecutable='InstalledFontUIProbe', CFBundlePackageType='APPL',
    CFBundleVersion='1', LSMinimumSystemVersion='12.0',
    ProbeRepositoryRoot=str(root), NSHighResolutionCapable=True)))
PY
swiftc -parse-as-library -warnings-as-errors -target "$(uname -m)-apple-macosx12.0" \
  -module-cache-path "$OUT/module-cache" \
  "$ROOT"/Sources/Shared/FontLibrary/*.swift \
  "$ROOT/Sources/HostApp/Services/FontLibraryService.swift" \
  "$ROOT/Sources/HostApp/Services/FontImportSourceSession.swift" \
  "$ROOT/Sources/HostApp/Services/MacFontDiscovery.swift" \
  "$ROOT"/Sources/HostApp/Services/InstalledFont*.swift \
  "$ROOT"/Sources/HostApp/Views/InstalledFont*.swift \
  "$ROOT/Sources/HostApp/Views/FontLibrarySettingsModel.swift" \
  "$ROOT/Sources/HostApp/Views/FontLibrarySettingsView.swift" \
  "$ROOT/Sources/HostApp/Views/MacFontImportView.swift" \
  "$ROOT/Tests/InstalledFontUIProbe/main.swift" \
  -o "$APP/Contents/MacOS/InstalledFontUIProbe"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
"$APP/Contents/MacOS/InstalledFontUIProbe" "$@"
