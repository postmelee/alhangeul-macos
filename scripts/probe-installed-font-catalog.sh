#!/bin/bash
# Stage 4: 제품 catalog service의 signed sandbox 재실행/선택 권한 검증.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build.noindex/task565-stage4"
APP="$OUT/InstalledFontCatalogProbe.app"
mkdir -p "$APP/Contents/MacOS" "$OUT/module-cache" "$OUT/installed-font-permission-fixture"
cp "$ROOT/Tests/FontLibraryTests/Fixtures/regular.ttf" "$OUT/installed-font-permission-fixture/regular.ttf"
python3 - "$APP" "$OUT" <<'PY'
import plistlib,sys
from pathlib import Path
app,out=map(Path,sys.argv[1:])
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='com.postmelee.alhangeul.InstalledFontCatalogProbe',CFBundleExecutable='InstalledFontCatalogProbe',CFBundlePackageType='APPL',CFBundleVersion='1',LSMinimumSystemVersion='12.0')))
(out/'catalog.entitlements').write_bytes(plistlib.dumps({'com.apple.security.app-sandbox':True,'com.apple.security.files.user-selected.read-only':True,'com.apple.security.files.bookmarks.app-scope':True}))
PY
swiftc -parse-as-library -warnings-as-errors -target "$(uname -m)-apple-macosx12.0" -module-cache-path "$OUT/module-cache" \
 "$ROOT"/Sources/Shared/FontLibrary/*.swift \
 "$ROOT/Sources/HostApp/Services/FontLibraryService.swift" \
 "$ROOT/Sources/HostApp/Services/FontImportSourceSession.swift" \
 "$ROOT"/Sources/HostApp/Services/InstalledFont*.swift \
 "$ROOT/Tests/InstalledFontCatalogProbe/main.swift" -o "$APP/Contents/MacOS/InstalledFontCatalogProbe"
codesign --force --options runtime --timestamp=none --sign "${PROBE_SIGN_ID:?승인된 로컬 서명 인증서를 지정하세요}" --entitlements "$OUT/catalog.entitlements" "$APP"
codesign --verify --strict "$APP"
if [[ "${1:-}" == "--choose" ]]; then
 "$APP/Contents/MacOS/InstalledFontCatalogProbe" --choose "$OUT/installed-font-permission-fixture"
else
 "$APP/Contents/MacOS/InstalledFontCatalogProbe"
fi
