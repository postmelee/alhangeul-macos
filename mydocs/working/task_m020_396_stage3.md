# Task M020 #396 Stage 3 완료 보고서

## 단계 목적

manifest 기반으로 기존 visual diff harness를 CoreGraphics/Skia opt-in 양쪽에 실행하고, 비교 가능한 baseline summary를 생성하는 helper/report 구조를 구현한다.

Stage 3 재개 전에 `local/task396`을 최신 `devel` 위로 rebase해 #398 결과를 반영했다. 이에 따라 `복학원서.hwp`는 더 이상 local font modal contamination 제외 sample이 아니라, clean capture metadata를 확인한 뒤 layout overflow/displayText 민감성을 별도로 보는 known-risk sample로 갱신했다.

## 산출물

| 파일/경로 | 내용 |
|-----------|------|
| `scripts/preview-renderer-baseline.sh` | manifest 기반 baseline helper shell entrypoint |
| `scripts/preview_renderer_baseline.py` | manifest 검증, suite/page filtering, policy별 harness 실행, pair summary 집계 |
| `scripts/preview_renderer_baseline_manifest.json` | `복학원서.hwp` knownRisk를 #398 이후 clean capture/layout overflow 기준으로 갱신 |
| `mydocs/tech/skia_preview_renderer_baseline.md` | #398 이후 `복학원서.hwp` 해석 정책 갱신 |
| `build.noindex/task396-helper-smoke/` | quick suite CoreGraphics/Skia helper smoke 산출물 |
| `mydocs/working/task_m020_396_stage3.md` | Stage 3 완료 보고서 |
| `mydocs/orders/20260630.md` | #396 재개와 Stage 3 승인 대기 상태 기록 |

현재 주요 파일 라인 수:

```text
7 scripts/preview-renderer-baseline.sh
542 scripts/preview_renderer_baseline.py
540 scripts/preview_renderer_baseline_manifest.json
122 mydocs/tech/skia_preview_renderer_baseline.md
```

## 구현 내용

`scripts/preview-renderer-baseline.sh`는 얇은 shell entrypoint로 두고, 실제 orchestration은 `scripts/preview_renderer_baseline.py`가 담당한다.

지원 CLI:

```text
./scripts/preview-renderer-baseline.sh <output-dir>
  --suite quick|extended|all
  --manifest scripts/preview_renderer_baseline_manifest.json
  --page-mode first|manifest
  --policy-pair coreGraphicsOnly,skiaOptIn
  --dry-run
  --validate-only
```

주요 동작:

1. manifest JSON 구조와 sample path를 검증한다.
2. `--suite`로 sample을 필터링한다.
3. `--page-mode first`면 각 sample의 첫 page만 실행하고, `manifest`면 manifest의 page list를 모두 실행한다.
4. output root 아래에 policy/page별 harness output을 분리한다.
   - `runs/coreGraphicsOnly/page-1/`
   - `runs/skiaOptIn/page-1/`
5. 기존 `preview-visual-diff-harness.sh`를 policy별로 호출한다.
6. 각 harness의 `summary.md`를 파싱해 top-level `summary.md`를 생성한다.
7. harness run 하나가 실패해도 다른 policy/page run은 계속 실행하고, exit code와 failure row를 summary에 남긴다.

Top-level summary column:

- sample id/category/page
- knownRisk
- policy별 status
- policy별 `StudioCapture`
- policy별 `ChangedPercent`
- policy별 `MeanRGBDelta`
- policy별 `NativeMs`
- policy별 backend/fallback
- `SkiaMinusCGChangedPercent`
- `NativeSizeDriftPx`
- triage
- policy별 artifact summary link

## #398 반영

Stage 2 당시 `복학원서.hwp`는 `capture-contamination` sentinel이었다. #398 merge 후 automation load와 contamination metadata가 들어왔으므로 Stage 3에서 manifest를 다음처럼 갱신했다.

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| category | `known-risk-capture` | `known-risk-layout` |
| knownRisk | `capture-contamination`, `display-text-sensitive` | `clean-capture-sentinel`, `layout-overflow-watch`, `display-text-sensitive` |
| 해석 | reference capture가 정리되기 전 visual metric 제외 | `captureContaminated=false` 확인 후 layout overflow/displayText를 renderer triage로 분리 |

## 본문 변경 정도 / 본문 무손실 여부

제품 앱 source, renderer source, RustBridge ABI, sample 문서는 변경하지 않았다. 변경 범위는 helper script, manifest/policy 문서, 작업 보고서/오늘할일 문서다.

## 검증 결과

정적/입력 검증:

```bash
./scripts/preview-renderer-baseline.sh --help
python3 -m json.tool scripts/preview_renderer_baseline_manifest.json >/dev/null
./scripts/preview-renderer-baseline.sh --validate-only --suite quick --page-mode first
./scripts/preview-renderer-baseline.sh --validate-only --suite extended --page-mode manifest
python3 -m py_compile scripts/preview_renderer_baseline.py
git diff --check
```

결과:

```text
quick validate: samples=5, samplePages=5
extended validate: samples=20, samplePages=21
```

Dry-run:

```bash
./scripts/preview-renderer-baseline.sh build.noindex/task396-helper-dry-run --suite quick --page-mode first --dry-run
```

결과:

```text
dry-run: runs=2 samples=5
```

Helper quick smoke:

```bash
./scripts/preview-renderer-baseline.sh build.noindex/task396-helper-smoke --suite quick --page-mode first
```

결과:

```text
coreGraphicsOnly page-1: exitCode=0, inputs=5
skiaOptIn page-1: exitCode=0, inputs=5
```

Quick suite aggregate:

| id | CG changed | Skia changed | Skia-CG delta | triage |
|----|------------|--------------|---------------|--------|
| `request-basic-quick` | `17.6908%` | `11.6265%` | `-6.0643pp` | `warn:skia-changed` |
| `ktx-regression-sentinel` | `30.8921%` | `46.3795%` | `+15.4874pp` | `warn:skia-delta` |
| `bokhakwonseo-capture-sentinel` | `7.2888%` | `6.9406%` | `-0.3482pp` | `known-risk` |
| `hwp-multi-001-page-loop` | `14.1976%` | `13.9298%` | `-0.2678pp` | `warn:skia-changed` |
| `hwpx-01-path` | `14.0216%` | `13.8212%` | `-0.2004pp` | `warn:skia-changed` |

`복학원서.hwp` capture metadata 확인:

```text
automationLoad=true
captureMode=domComposite
overlayIncluded=true
captureContaminated=false
modalCount=0
toastCount=0
localFontUIVisible=false
StudioCapture=domComposite;ui=clean
```

Stage 3 keyword 검증:

```bash
rg -n "CoreGraphics|Skia|coreGraphicsOnly|skiaOptIn|ChangedPercent|MeanRGBDelta|NativeMs|fallback|knownRisk|KnownRisk|KTX|복학원서|summary|domComposite;ui=clean" \
  build.noindex/task396-helper-smoke mydocs/working/task_m020_396_stage3.md \
  scripts/preview_renderer_baseline_manifest.json mydocs/tech/skia_preview_renderer_baseline.md
```

결과: helper 산출물, Stage 보고서, manifest/policy 문서에서 핵심 keyword 확인.

## 잔여 위험

- Stage 3 helper는 visual diff orchestration에 집중한다. Quick Look extension 등록 smoke와 Thumbnail cache/signature smoke 연결은 Stage 4에서 수행한다.
- `warn:skia-changed`는 Skia가 CoreGraphics보다 악화됐다는 뜻이 아니라, reference 대비 changed percent가 sample threshold를 넘었다는 triage signal이다. 실제 default 전환 판단은 Stage 4에서 image artifact와 surface smoke를 함께 본다.
- `KTX.hwp`는 예상대로 `warn:skia-delta`를 유지한다. 이는 #390의 visual regression blocker가 helper summary에 다시 드러난 것이다.
- `복학원서.hwp`는 clean capture로 복구됐지만 `LAYOUT_OVERFLOW` warning이 남아 있다. 이 warning은 capture contamination이 아니라 renderer/layout risk로 이어서 본다.

## 다음 단계 영향

Stage 4에서는 helper를 기준으로 quick suite를 공식 산출물 경로에서 다시 실행하고, 가능한 범위에서 extended suite 일부 또는 전체를 실행한다. 또한 `KTX.hwp` regression sentinel, `복학원서.hwp` clean-capture/layout sentinel, Thumbnail 1px dimension watch가 summary에서 의도대로 분류되는지 확인한다.

## 승인 요청

Stage 3는 완료했다. Stage 4 `quick smoke와 확장 후보 검증`으로 진행해도 되는지 승인 요청한다.
