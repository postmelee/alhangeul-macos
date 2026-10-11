#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build.noindex/task567/stage3-1/webkit-probe"
APP="$OUT/StudioFontProviderProbe.app"
mkdir -p "$APP/Contents/MacOS" "$OUT/module-cache"
python3 - "$APP" <<'PY'
import plistlib,sys
from pathlib import Path
app=Path(sys.argv[1])
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(dict(
    CFBundleIdentifier='com.postmelee.alhangeul.StudioFontProviderProbe',
    CFBundleExecutable='StudioFontProviderProbe',CFBundlePackageType='APPL',
    CFBundleVersion='1',LSMinimumSystemVersion='12.0',LSUIElement=True)))
PY
swiftc -parse-as-library -warnings-as-errors -target "$(uname -m)-apple-macosx12.0" \
  -module-cache-path "$OUT/module-cache" \
  "$ROOT"/Sources/Shared/FontLibrary/*.swift \
  "$ROOT"/Sources/HostApp/Services/StudioFont*.swift \
  "$ROOT/Tests/StudioFontProviderProbe/main.swift" \
  -o "$APP/Contents/MacOS/StudioFontProviderProbe"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
trap '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" >/dev/null 2>&1 || true' EXIT
"$APP/Contents/MacOS/StudioFontProviderProbe" "$ROOT/Tests/FontLibraryTests/Fixtures/regular.ttf"
