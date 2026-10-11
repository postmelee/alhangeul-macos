#!/bin/bash
set -euo pipefail

# 지정한 로컬 인증서로 테스트 앱만 서명한다. 배포·공증·LaunchServices 등록은 하지 않는다.
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 'Developer ID Application: ... (TEAMID)'" >&2
  exit 2
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build.noindex/font-library-container-probe"
APP="$OUT/FontLibraryContainerProbe.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUT/module-cache"
cp "$ROOT/Tests/FontLibraryTests/Fixtures/regular.ttf" "$APP/Contents/Resources/regular.ttf"
python3 - "$ROOT" "$APP" <<'PY'
import plistlib
import sys
from pathlib import Path
root, app = map(Path, sys.argv[1:])
info = plistlib.loads((root / 'Sources/HostApp/Info.plist').read_bytes())
entitlements = plistlib.loads((root / 'Sources/HostApp/HostApp.entitlements').read_bytes())
group = info['AlhangeulFontLibraryGroupIdentifier']
assert group in entitlements['com.apple.security.application-groups']
probe_info = dict(CFBundleIdentifier='com.postmelee.alhangeul.FontLibraryContainerProbe',
                  CFBundleExecutable='FontLibraryContainerProbe', CFBundlePackageType='APPL',
                  CFBundleVersion='1', LSMinimumSystemVersion='12.0', LSUIElement=True,
                  AlhangeulFontLibraryGroupIdentifier=group)
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps(probe_info))
(app.parent / 'probe.entitlements').write_bytes(plistlib.dumps({
    'com.apple.security.app-sandbox': True,
    'com.apple.security.application-groups': [group],
}))
PY
swiftc -parse-as-library -target "$(uname -m)-apple-macosx12.0" -module-cache-path "$OUT/module-cache" \
  "$ROOT"/Sources/Shared/FontLibrary/*.swift \
  "$ROOT/Tests/FontLibraryContainerProbe/main.swift" \
  -o "$APP/Contents/MacOS/FontLibraryContainerProbe"
codesign --force --options runtime --timestamp=none --sign "$1" \
  --entitlements "$OUT/probe.entitlements" "$APP"
codesign --verify --strict "$APP"
"$APP/Contents/MacOS/FontLibraryContainerProbe"
