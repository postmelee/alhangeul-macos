#!/bin/bash
# Task #565 Stage 3 독립 probe. 제품 소스/사용자 설치 글꼴은 수정하지 않는다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build.noindex/task565-stage3"
CORE="${RHWP_PROBE_CORE:?고정 rhwp checkout 경로를 지정하세요}"
EXPECTED="$(sed -n 's/^rhwp_commit = "\(.*\)"/\1/p' "$ROOT/rhwp-core.lock")"
[[ "$(git -C "$CORE" rev-parse HEAD)" == "$EXPECTED" ]]
[[ -z "$(git -C "$CORE" status --porcelain -- rhwp-studio/src)" ]]
APP="$OUT/InstalledFontConnectionProbe${PROBE_APP_SUFFIX:-}.app"
STATIC="$APP/Contents/Resources"
mkdir -p "$STATIC/fonts" "$APP/Contents/MacOS" "$OUT/module-cache" "$OUT/results"
RESULTS="${FONT_CONNECTION_RESULTS:-$OUT/results}"
mkdir -p "$RESULTS"
TOOLS="$OUT/tools/node_modules"
[[ -f "$TOOLS/canvaskit-wasm/bin/canvaskit.js" ]]
cat > "$OUT/wasm-url.js" <<'JS'
export default 'probe://app/canvaskit.wasm';
JS
"$TOOLS/.bin/esbuild" "$ROOT/Tests/InstalledFontConnectionProbe/probe.js" --bundle --format=iife --external:fs --external:path \
  --alias:@rhwp="$CORE/rhwp-studio/src" --alias:@="$CORE/rhwp-studio/src" \
  --alias:@/view/canvaskit-wasm-url="$OUT/wasm-url.js" \
  --alias:@noble/hashes="$TOOLS/@noble/hashes" \
  --alias:canvaskit-wasm="$TOOLS/canvaskit-wasm/bin/canvaskit.js" \
  --outfile="$STATIC/app.js"
cp "$TOOLS/canvaskit-wasm/bin/canvaskit.wasm" "$STATIC/canvaskit.wasm"
for font in NotoSansKR-Regular D2Coding-Regular SourceHanSerifK-OldHangul-subset; do
  cp "$ROOT/Sources/HostApp/Resources/rhwp-studio/fonts/$font.woff2" "$STATIC/fonts/"
done
cat > "$STATIC/index.html" <<'HTML'
<!doctype html><meta charset="utf-8"><title>Mac 설치 글꼴 연결 실험</title>
<style>body{font:18px system-ui;margin:24px;background:#f3f6fa}canvas{background:white;width:1000px;height:300px}p{color:#42536a}</style>
<h2>Mac 설치 글꼴 → rhwp CanvasKit</h2><p>독립 실험 · 제품 설정 화면 아님</p>
<canvas width="1000" height="300"></canvas><script src="app.js"></script>
HTML
python3 - "$APP" <<'PY'
import plistlib,sys
from pathlib import Path
p=Path(sys.argv[1]); (p/'Contents/Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='com.postmelee.alhangeul.InstalledFontConnectionProbe',CFBundleExecutable='InstalledFontConnectionProbe',CFBundlePackageType='APPL',CFBundleVersion='1',LSMinimumSystemVersion='12.0')))
PY
swiftc -warnings-as-errors -target "$(uname -m)-apple-macosx12.0" -module-cache-path "$OUT/module-cache" \
 "$ROOT/Tests/InstalledFontConnectionProbe/main.swift" -o "$APP/Contents/MacOS/InstalledFontConnectionProbe"
if [[ -n "${PROBE_SIGN_ID:-}" ]]; then
  cat > "$OUT/sandbox.entitlements" <<'XML'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.app-sandbox</key><true/><key>com.apple.security.network.client</key><true/></dict></plist>
XML
  codesign --force --options runtime --timestamp=none --sign "$PROBE_SIGN_ID" --entitlements "$OUT/sandbox.entitlements" "$APP"
  codesign --verify --strict "$APP"
  "$APP/Contents/MacOS/InstalledFontConnectionProbe" --sandbox
else
  codesign --force --sign - "$APP"
  codesign --verify --strict "$APP"
  "$APP/Contents/MacOS/InstalledFontConnectionProbe" "$STATIC" "$RESULTS"
fi
