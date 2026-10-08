#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${FONT_SETTINGS_PROBE_OUT:-$ROOT/build.noindex/task565-stage5}"
OUT="$(python3 - "$ROOT" "$OUT" <<'PY'
from pathlib import Path
import sys
root, out = map(lambda p: Path(p).resolve(), sys.argv[1:])
if not out.is_relative_to(root / 'build.noindex'):
    raise SystemExit('UI probe output must be under build.noindex')
print(out)
PY
)"
APP="$OUT/InstalledFontUIProbe.app"
mkdir -p "$APP/Contents/MacOS" "$OUT/module-cache"
python3 - "$ROOT" "$APP" "$OUT" <<'PY'
import plistlib
import sys
from pathlib import Path
root, app, out = map(Path, sys.argv[1:])
identifier = 'com.postmelee.alhangeul.FontSettingsUIProbe' if out != root / 'build.noindex/task565-stage5' else 'com.postmelee.alhangeul.InstalledFontUIProbe'
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(
    CFBundleIdentifier=identifier,
    CFBundleExecutable='InstalledFontUIProbe', CFBundlePackageType='APPL',
    CFBundleVersion='1', LSMinimumSystemVersion='12.0',
    ProbeRepositoryRoot=str(root), ProbeDataRoot=str(out / 'ui-data'), NSHighResolutionCapable=True)))
PY
swiftc -parse-as-library -warnings-as-errors -target "$(uname -m)-apple-macosx12.0" \
  -module-cache-path "$OUT/module-cache" \
  "$ROOT"/Sources/Shared/FontLibrary/*.swift \
  "$ROOT/Sources/HostApp/Services/FontLibraryService.swift" \
  "$ROOT/Sources/HostApp/Services/FontLibraryChanges.swift" \
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
trap '"/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" -u "$APP" >/dev/null 2>&1 || true' EXIT
"$APP/Contents/MacOS/InstalledFontUIProbe" "$@"
