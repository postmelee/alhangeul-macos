#!/bin/bash
# 실제 제품 metadata 경로만 측정한다. OS cold/앱 전체 launch benchmark는 아니다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build.noindex/task567/stage4-1/startup-profile"
mkdir -p "$OUT/module-cache"
swiftc -O -parse-as-library -warnings-as-errors -target "$(uname -m)-apple-macosx12.0" \
  -module-cache-path "$OUT/module-cache" \
  "$ROOT"/Sources/Shared/FontLibrary/*.swift \
  "$ROOT/Sources/HostApp/Services/FontLibraryService.swift" \
  "$ROOT/Sources/HostApp/Services/FontLibraryChanges.swift" \
  "$ROOT/Sources/HostApp/Services/FontImportSourceSession.swift" \
  "$ROOT"/Sources/HostApp/Services/InstalledFont*.swift \
  "$ROOT/Tests/InstalledFontStartupProbe/main.swift" \
  -o "$OUT/InstalledFontStartupProbe"
python3 - "$OUT" <<'PY'
import json, pathlib, platform, statistics, subprocess, sys, uuid
out = pathlib.Path(sys.argv[1])
session = out / ('run-' + str(uuid.uuid4()))
session.mkdir()
results = []
for index in range(5):
    output = session / f'process-{index + 1}.json'
    subprocess.run([str(out / 'InstalledFontStartupProbe'), str(session / 'state'), str(output)], check=True, timeout=60)
    results.append(json.loads(output.read_text()))
summary = {
    'scope': '실제 CoreText metadata / 격리 저장소 / 새 CLI 프로세스 5회 / Swift -O / OS cold와 제품 전체 launch는 미측정',
    'macOS': platform.mac_ver()[0], 'architecture': platform.machine(), 'runs': results,
    'restoredPrepareMedianMS': statistics.median(row['prepareMS'] for row in results[1:]),
    'scanMedianMS': statistics.median(ms for row in results for ms in row['metadataScanMS']),
}
(session / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
print('증거:', session)
print('metadata faces:', results[0]['faceCount'], 'families:', results[0]['familyCount'])
print('restored prepare median ms:', round(summary['restoredPrepareMedianMS'], 3))
print('scan median ms:', round(summary['scanMedianMS'], 3))
print('scan counts:', [row['scanCountAfterActivation'] for row in results])
print('font bytes reads:', [row['directFontBytesReads'] for row in results])
PY
