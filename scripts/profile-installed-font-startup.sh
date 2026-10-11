#!/bin/bash
# 실제 제품 metadata 경로만 측정한다. OS cold/앱 전체 launch benchmark는 아니다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build.noindex/task567/stage4-2/startup-profile"
mkdir -p "$OUT/module-cache"
swiftc -O -parse-as-library -warnings-as-errors -target "$(uname -m)-apple-macosx12.0" \
  -module-cache-path "$OUT/module-cache" \
  "$ROOT"/Sources/Shared/FontLibrary/*.swift \
  "$ROOT/Tests/InstalledFontStartupProbe/main.swift" \
  -o "$OUT/InstalledFontStartupProbe"
python3 - "$OUT" <<'PY'
import json, pathlib, platform, statistics, subprocess, sys, uuid
out = pathlib.Path(sys.argv[1])
session = out / ('run-' + str(uuid.uuid4()))
session.mkdir()
results, baseline = [], []
for mode, rows in [('coalesced', results), ('legacy', baseline)]:
    for index in range(5):
        output = session / f'{mode}-process-{index + 1}.json'
        command = [str(out / 'InstalledFontStartupProbe'), str(session / (mode + '-state')), str(output)]
        if mode == 'legacy': command += ['--legacy-activation']
        subprocess.run(command, check=True, timeout=60)
        rows.append(json.loads(output.read_text()))
assert all(row['faceCount'] == results[0]['faceCount'] and row['familyCount'] == results[0]['familyCount']
           for row in results + baseline), '측정 중 실제 등록 목록 개수 변경'
summary = {
    'scope': '실제 CoreText metadata / 격리 저장소 / 현재·기존 활성화 경로 각각 새 CLI 프로세스 5회 / Swift -O / OS cold와 제품 전체 launch는 미측정',
    'macOS': platform.mac_ver()[0], 'architecture': platform.machine(), 'runs': results,
    'restoredPrepareMedianMS': statistics.median(row['prepareMS'] for row in results[1:]),
    'scanMedianMS': statistics.median(ms for row in results for ms in row['metadataScanMS']),
    'baselineRuns': baseline,
    'coalescedTotalScanMedianMS': statistics.median(sum(row['metadataScanMS']) for row in results),
    'baselineTotalScanMedianMS': statistics.median(sum(row['metadataScanMS']) for row in baseline),
}
(session / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
print('증거:', session)
print('metadata faces:', results[0]['faceCount'], 'families:', results[0]['familyCount'])
print('restored prepare median ms:', round(summary['restoredPrepareMedianMS'], 3))
print('scan median ms:', round(summary['scanMedianMS'], 3))
print('scan counts:', [row['scanCountAfterActivation'] for row in results])
print('font bytes reads:', [row['directFontBytesReads'] for row in results])
print('baseline scan counts:', [row['scanCountAfterActivation'] for row in baseline])
print('total metadata scan median ms: coalesced', round(summary['coalescedTotalScanMedianMS'], 3),
      'legacy', round(summary['baselineTotalScanMedianMS'], 3))
PY
