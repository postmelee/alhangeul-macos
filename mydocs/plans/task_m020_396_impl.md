# Task M020 #396 구현계획서

수행계획서: `mydocs/plans/task_m020_396.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #396 `업스트림 renderer baseline 방식을 Quick Look/Thumbnail Skia 품질 검증에 이식`
- 추적 이슈: #387 Preview/Thumbnail Skia readiness 후속 개선 추적
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task396`
- 목표: 업스트림 renderer baseline의 manifest/report/sweep 구조를 macOS Quick Look/Thumbnail Skia 품질 검증에 맞게 이식하고, `CoreGraphics default + Skia opt-in` 비교를 반복 가능한 quick smoke/extended sweep 체계로 정리한다.

## 구현 원칙

- #396은 Skia default 전환 작업이 아니라 default 전환 판단 기준을 만드는 작업이다.
- 전체 `samples/` 전수 비교를 기본 gate로 강제하지 않는다. 대표 manifest 기반 quick smoke와 수동 extended sweep을 분리한다.
- 기존 `scripts/preview-visual-diff-harness.sh`와 `scripts/preview_visual_diff_harness.swift`를 우선 재사용한다.
- 새로운 helper는 orchestration/report aggregation에 집중하고, renderer 동작 변경은 하지 않는다.
- `ChangedPercent` 단일 수치로 pass/fail을 확정하지 않는다. failure phase, size mismatch, fallback, artifact path, known risk를 같이 기록한다.
- `복학원서.hwp`처럼 reference capture contamination이 있는 샘플은 품질 회귀가 아니라 capture/known-risk로 분리한다.
- WebKit/sandbox readiness failure와 renderer failure를 반드시 구분한다.

## Stage 1. upstream/local baseline 구조 inventory

### 목표

업스트림 renderer baseline 체계와 현재 macOS visual diff harness를 비교해, #396에서 가져올 요소와 새로 필요한 adapter 범위를 고정한다.

### 대상

- 업스트림 조사 결과
  - `.github/workflows/render-diff.yml`
  - `.github/workflows/full-renderer-sweep.yml`
  - `scripts/renderer_baseline.py`
  - `scripts/renderer_baseline_manifest.json`
  - `tests/svg_snapshot.rs`
- 현재 저장소
  - `scripts/preview-visual-diff-harness.sh`
  - `scripts/preview_visual_diff_harness.swift`
  - `mydocs/tech/skia_quicklook_thumbnail_backend.md`
  - `mydocs/report/task_m020_390_report.md`
  - `mydocs/working/task_m020_390_stage*.md`
  - `mydocs/working/task_m020_396_stage1.md`

### 작업

1. 업스트림 baseline 요소를 `manifest`, `capture`, `diff metric`, `threshold`, `artifact`, `workflow tier`로 분해한다.
2. 현재 visual diff harness summary column과 output directory 구조를 inventory한다.
3. #390의 `KTX.hwp`, `복학원서.hwp`, Thumbnail 1px dimension 결과를 baseline 요구사항으로 변환한다.
4. macOS Quick Look/Thumbnail surface에서 업스트림 방식과 달라야 하는 adapter 지점을 정리한다.
5. Stage 1 보고서에 Stage 2 manifest schema와 Stage 3 helper 방향을 확정한다.

### 검증

```bash
rg -n "render-diff|full-renderer-sweep|renderer_baseline|native-skia|canvaskit|pixelmatch|svg_snapshot" \
  mydocs/working/task_m020_396_stage1.md
rg -n "ChangedPercent|MeanRGBDelta|NativeMs|StudioCapture|NativeBackend|fallback|KTX|복학원서|dimension" \
  scripts/preview_visual_diff_harness.swift mydocs/report/task_m020_390_report.md \
  mydocs/working/task_m020_396_stage1.md
git diff --check
```

### 완료 조건

- 업스트림에서 이식할 요소와 이식하지 않을 요소가 구분되어 있다.
- 현재 harness output과 #396 target report의 gap이 문서화되어 있다.
- Stage 2 manifest schema 초안 입력이 준비되어 있다.

### 커밋 메시지

```text
Task #396 Stage 1: renderer baseline 구조 inventory
```

## Stage 2. 대표 샘플 manifest와 threshold/triage policy 설계

### 목표

Quick Look/Thumbnail Skia 품질 검증용 대표 manifest와 sample별 threshold/triage policy를 문서와 JSON 초안으로 고정한다.

### 대상

- `scripts/preview_renderer_baseline_manifest.json`
- `mydocs/tech/skia_preview_renderer_baseline.md`
- `mydocs/working/task_m020_396_stage2.md`
- 필요 시 `mydocs/tech/skia_quicklook_thumbnail_backend.md`

### 작업

1. manifest schema를 정의한다.
   - `id`
   - `path`
   - `category`
   - `suite`: `quick`, `extended`
   - `pages`
   - `surfaces`: `quicklook`, `thumbnail`, `visual`
   - `knownRisk`
   - `threshold`
   - `notes`
2. quick smoke 샘플 3-5개를 확정한다.
3. extended sweep 샘플 15-25개 후보를 category별로 고정한다.
4. `KTX.hwp`는 regression sentinel, `복학원서.hwp`는 known-risk/capture sentinel로 분리한다.
5. threshold는 hard gate가 아니라 triage 정책으로 문서화한다.
6. JSON manifest 유효성과 샘플 파일 존재를 검증한다.

### 검증

```bash
python3 -m json.tool scripts/preview_renderer_baseline_manifest.json >/dev/null
python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path("scripts/preview_renderer_baseline_manifest.json").read_text())
missing = [item["path"] for item in data["samples"] if not Path(item["path"]).is_file()]
if missing:
    raise SystemExit("missing samples: " + ", ".join(missing))
print(f"samples={len(data['samples'])}")
PY
rg -n "quick|extended|KTX|복학원서|threshold|known-risk|ChangedPercent|MeanRGBDelta" \
  scripts/preview_renderer_baseline_manifest.json mydocs/tech/skia_preview_renderer_baseline.md \
  mydocs/working/task_m020_396_stage2.md
git diff --check
```

### 완료 조건

- manifest JSON이 유효하다.
- 모든 manifest sample path가 존재한다.
- quick smoke와 extended sweep이 분리되어 있다.
- sample별 known risk와 triage policy가 문서화되어 있다.

### 커밋 메시지

```text
Task #396 Stage 2: Skia baseline manifest 설계
```

## Stage 3. baseline 실행 helper와 report 구조 구현

### 목표

manifest 기반으로 기존 visual diff harness를 CoreGraphics/Skia opt-in 양쪽에 실행하고, 비교 가능한 summary를 생성하는 helper/report 구조를 구현한다.

### 대상

- `scripts/preview-renderer-baseline.sh`
- 필요 시 `scripts/preview_renderer_baseline.py`
- `scripts/preview_renderer_baseline_manifest.json`
- `mydocs/working/task_m020_396_stage3.md`

### 작업

1. `preview-renderer-baseline.sh` CLI를 구현한다.
   - `--suite quick|extended|all`
   - `--manifest`
   - `--page-mode first|manifest`
   - `--policy-pair coreGraphicsOnly,skiaOptIn`
2. helper가 output directory 아래에 CoreGraphics/Skia harness output을 분리 생성하게 한다.
3. helper가 summary markdown을 생성하거나 집계 helper를 호출하게 한다.
4. summary에는 sample id, category, policy별 status, `ChangedPercent`, `MeanRGBDelta`, `NativeMs`, size mismatch, fallback, known risk, artifact path를 남긴다.
5. 실패 시 phase를 보존하고 다음 샘플 진행 또는 명확한 exit 정책을 둔다.
6. `--help`와 dry-run 또는 manifest validation mode를 제공할 수 있으면 추가한다.

### 검증

```bash
./scripts/preview-renderer-baseline.sh --help
python3 -m json.tool scripts/preview_renderer_baseline_manifest.json >/dev/null
./scripts/preview-renderer-baseline.sh build.noindex/task396-helper-smoke --suite quick --page-mode first
rg -n "CoreGraphics|Skia|ChangedPercent|MeanRGBDelta|NativeMs|fallback|knownRisk|KTX|복학원서|summary" \
  build.noindex/task396-helper-smoke mydocs/working/task_m020_396_stage3.md
git diff --check
```

### 완료 조건

- helper가 quick suite를 실행할 수 있다.
- CoreGraphics와 Skia opt-in output이 같은 run 아래에 남는다.
- summary가 sample별 artifact와 metric을 연결한다.
- 실패 phase가 report에 남는다.

### 커밋 메시지

```text
Task #396 Stage 3: Skia baseline 실행 helper 구현
```

## Stage 4. quick smoke와 확장 후보 검증

### 목표

Stage 2-3에서 만든 manifest/helper를 실제로 실행해 quick smoke 반복 가능성과 extended 후보의 실행 가능성을 검증한다.

### 대상

- `build.noindex/task396-baseline-quick/`
- `build.noindex/task396-baseline-extended-sample/`
- `mydocs/working/task_m020_396_stage4.md`

### 작업

1. 기본 검증 command를 실행한다.
2. quick suite를 실행하고 summary를 기록한다.
3. 가능한 범위에서 extended suite 일부 또는 전체를 실행한다.
4. sandbox/WebKit readiness failure가 발생하면 sandbox 밖 재실행 조건과 결과를 기록한다.
5. `KTX.hwp` regression sentinel과 `복학원서.hwp` known-risk sentinel이 summary에서 의도대로 분류되는지 확인한다.
6. #392/#389/#393에 넘길 후속 판단 입력을 정리한다.

### 검증

```bash
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
./scripts/preview-renderer-baseline.sh build.noindex/task396-baseline-quick --suite quick
./scripts/preview-renderer-baseline.sh build.noindex/task396-baseline-extended-sample --suite extended
rg -n "OK|FAIL|KTX|복학원서|knownRisk|ChangedPercent|MeanRGBDelta|NativeMs|fallback|readiness|summary" \
  build.noindex/task396-baseline-quick build.noindex/task396-baseline-extended-sample \
  mydocs/working/task_m020_396_stage4.md
git diff --check
```

### 완료 조건

- quick suite 산출물이 생성되어 있다.
- extended 후보 실행 결과 또는 실행 제한 사유가 기록되어 있다.
- known-risk와 hard-fail 분류가 summary에 나타난다.
- 환경 실패와 renderer 실패가 분리되어 있다.

### 커밋 메시지

```text
Task #396 Stage 4: Skia baseline suite 검증
```

## Stage 5. 최종 기준 정리와 PR 준비

### 목표

#396 결과를 최종 보고서로 정리하고 PR 게시 준비를 완료한다.

### 대상

- `mydocs/report/task_m020_396_report.md`
- `mydocs/orders/20260629.md`
- 필요 시 `mydocs/working/task_m020_396_stage5.md`

### 작업

1. 최종 보고서에 manifest, helper, quick/extended 실행 결과, 후속 관계를 정리한다.
2. 오늘할일 #396 상태를 완료 처리한다.
3. #387 추적 이슈, #392, #389, #393, #394와의 관계를 정리한다.
4. PR body 초안을 준비할 수 있도록 stage별 요약과 검증 결과를 정리한다.

### 검증

```bash
rg -n "#396|#387|#389|#392|#393|#394|Skia|CoreGraphics|Quick Look|Thumbnail|baseline|manifest|quick|extended" \
  mydocs/report/task_m020_396_report.md mydocs/orders/20260629.md
git diff --check
git status --short --branch
git log --oneline devel..local/task396
```

### 완료 조건

- 최종 보고서가 존재하고 #396의 검증 체계를 설명한다.
- 오늘할일 #396이 완료 상태다.
- PR 게시 준비가 가능하다.

### 커밋 메시지

```text
Task #396 Stage 5 + 최종 보고서: Skia baseline suite 정리
```
