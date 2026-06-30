# Skia Preview Renderer Baseline

## 목적

이 문서는 #396에서 도입하는 Quick Look/Thumbnail Skia 품질 검증용 대표 manifest와 threshold/triage 정책을 정의한다.

기존 정책 문서 [`skia_quicklook_thumbnail_backend.md`](skia_quicklook_thumbnail_backend.md)는 backend 선택과 fallback contract를 설명한다. 이 문서는 그 정책을 검증할 sample suite와 report 해석 기준만 다룬다. Skia default 전환, renderer 동작 변경, upstream `rhwp` 수정은 범위가 아니다.

## Manifest 위치와 기본 규칙

대표 manifest는 `scripts/preview_renderer_baseline_manifest.json`이다.

기본 규칙:

- `pageIndexBase`는 `1`이다. 기존 `preview-visual-diff-harness.sh --page`가 1-based이기 때문이다.
- `policyPair`는 `coreGraphicsOnly`, `skiaOptIn`이다.
- `suite`는 배열이며, quick sample은 extended에도 포함할 수 있다.
- `surfaces`는 `visual`, `quicklook`, `thumbnail` 중 하나 이상을 가진다.
- `threshold`는 자동 hard gate가 아니라 triage metadata다.
- `knownRisk`가 있는 sample은 summary에서 별도 column으로 노출해야 한다.

필수 sample field:

| 필드 | 의미 |
|------|------|
| `id` | report와 artifact path에서 사용할 안정 식별자 |
| `path` | repo root 상대 sample path |
| `category` | renderer feature category |
| `suite` | `quick`, `extended` 포함 여부 |
| `pages` | 1-based page list. quick 실행은 기본적으로 첫 page만 사용 |
| `surfaces` | 이 sample을 해석할 surface |
| `knownRisk` | regression, capture contamination, size drift 같은 known signal |
| `threshold` | warning threshold 후보 |
| `notes` | sample 선정 이유와 기존 측정 근거 |

## Suite 정책

| suite | 규모 | 실행 시점 | 목적 |
|-------|------|-----------|------|
| `quick` | 5 samples | renderer 관련 단계 검증, PR review, smoke | #390에서 확인한 핵심 신호를 빠르게 재측정 |
| `extended` | 20 samples | 수동 readiness sweep, Skia default 판단 전 | category별 대표성을 확보하고 failure 계열을 좁힘 |

quick suite는 다음 5개로 고정한다.

| id | path | 역할 |
|----|------|------|
| `request-basic-quick` | `samples/basic/request.hwp` | 건강한 단일 page 기준선 |
| `ktx-regression-sentinel` | `samples/basic/KTX.hwp` | #390 Skia visual regression sentinel |
| `bokhakwonseo-capture-sentinel` | `samples/복학원서.hwp` | #398 clean capture sentinel / layout overflow와 displayText 민감 sample |
| `hwp-multi-001-page-loop` | `samples/hwp-multi-001.hwp` | HWP multi-page preview loop |
| `hwpx-01-path` | `samples/hwpx/hwpx-01.hwpx` | HWPX path |

extended suite는 quick 5개에 image, equation/shape, form/field, text/font, table category를 추가한 20개다. 전수 비교가 아니라 대표 sweep이며, 실패 category가 나오면 그 category 안에서 별도 follow-up으로 확장한다.

## Threshold / Triage 정책

자동 hard fail은 pixel diff 비율 하나로 결정하지 않는다. 다음 signal은 hard fail 후보로 본다.

- crash, hang, timeout
- empty output 또는 PNG decode failure
- page size나 aspect ratio mismatch
- 본문, 표, 이미지, 수식, form control의 주요 구조 누락
- 전체 page offset, 잘림, 반전, 투명 배경
- Skia 실패 후 CoreGraphics fallback도 실패

`ChangedPercent`는 다음처럼 해석한다.

| 구간 | 의미 | 조치 |
|------|------|------|
| `0-1%` | antialiasing 또는 작은 rasterizer 차이 가능성 | summary 기록 |
| `1-5%` | text edge, 1px rounding, 일부 object 차이 가능성 | diff PNG 눈검증 |
| `5-10%` | 구조 차이 가능성 있음 | sample별 known difference 또는 follow-up 분류 |
| `10%+` | 큰 구조 차이 가능성이 높음 | default 전환 차단 후보 |

기본 warning threshold:

| 항목 | 기본값 | 의미 |
|------|--------|------|
| `maxAllowedSizeDriftPx` | `0` | 기본 visual/Quick Look 비교는 size drift를 허용하지 않음 |
| `maxChangedPercentWarn` | `10.0` | 구조 차이 가능성 warning |
| `maxSkiaMinusCGChangedPercentWarn` | `5.0` | 같은 reference 대비 Skia가 CoreGraphics보다 악화되는지 보는 warning |
| `maxMeanRGBDeltaWarn` | `20.0` | 평균 RGB delta warning |

Thumbnail surface가 포함된 quick sample은 #390의 1px dimension 차이를 반영해 `maxAllowedSizeDriftPx: 1`을 둔다. 이 값은 cache 성공 기준이 아니라 visual triage 기준이다. 잘림, aspect ratio 변경, 구조 누락은 1px drift 허용과 별개로 hard fail 후보가 된다.

## Known Risk 정책

| knownRisk | 처리 |
|-----------|------|
| `regression-sentinel` | quick/extended 모두에서 유지하고 Skia-CG `ChangedPercent` delta를 항상 노출 |
| `capture-contamination` | reference capture가 정리되기 전에는 renderer 품질 점수로 사용하지 않음 |
| `clean-capture-sentinel` | #398 이후 automation capture metadata가 clean인지 확인하고 visual metric을 renderer triage 입력으로 사용 |
| `layout-overflow-watch` | capture contamination이 아니라 renderer/layout warning으로 별도 해석 |
| `size-drift-watch` | 1px thumbnail drift를 triage warning으로 기록하되 cache 실패와 분리 |
| `display-text-sensitive` | diff 수치가 낮아도 사용자-facing text와 control mark를 눈검증 |

`KTX.hwp`는 `regression-sentinel`이다. #390에서 Skia changed percent는 `46.3795%`, CoreGraphics는 `30.8921%`였고 delta는 `+15.4874pp`였다. 이 sample이 악화된 상태라면 Skia default 전환은 막는다.

`복학원서.hwp`는 #398 이후 `clean-capture-sentinel`이다. #390에서는 rhwp-studio reference PNG에 `로컬 글꼴 감지` overlay가 포함되어 CoreGraphics/Skia 모두 99%대 changed percent가 나왔지만, #398에서 automation load와 local font UI contamination metadata를 추가해 `captureContaminated=false` 기준을 확보했다. 따라서 이 sample은 더 이상 local font modal contamination 때문에 제외하지 않고, 남은 `LAYOUT_OVERFLOW`와 displayText 민감성을 renderer/layout triage로 분리해 해석한다.

## Surface 해석

| surface | Stage 2 의미 | Stage 3 helper에서의 1차 처리 |
|---------|--------------|-------------------------------|
| `visual` | rhwp-studio reference와 native renderer PNG diff | 기존 `preview-visual-diff-harness.sh`로 실행 |
| `quicklook` | Quick Look preview default 전환 판단에 반영 | visual 결과와 Quick Look smoke 결과를 연결 |
| `thumbnail` | Finder thumbnail default 전환 판단에 반영 | visual 결과와 thumbnail policy smoke 결과를 연결 |

Stage 3의 1차 구현은 `visual` orchestration과 pair summary에 집중한다. Quick Look extension 등록 smoke와 Thumbnail cache/signature smoke는 이미 있는 script 결과를 Stage 4에서 연결한다.

## Stage 3 Helper 입력 계약

Stage 3 helper는 manifest를 읽어 다음을 수행해야 한다.

1. JSON 구조와 sample path를 검증한다.
2. `--suite quick|extended|all`로 sample을 필터링한다.
3. `--page-mode first|manifest`로 page list를 결정한다.
4. `coreGraphicsOnly`, `skiaOptIn`을 같은 output root 아래에서 실행한다.
5. sample별 `ChangedPercent`, `MeanRGBDelta`, `NativeMs`, size drift, fallback, known risk, artifact path를 같은 summary에 모은다.
6. `knownRisk` sample은 failure와 별도 column으로 표시한다.

이 계약은 Skia default 전환 기준이 아니라 반복 가능한 측정 구조다. default 판단은 Stage 4 실행 결과와 #392/#389/#393 후속 입력을 종합해 별도 승인으로 결정한다.

## 실행 Runbook

Quick smoke:

```bash
./scripts/preview-renderer-baseline.sh build.noindex/skia-baseline-quick --suite quick
```

Extended sweep:

```bash
./scripts/preview-renderer-baseline.sh build.noindex/skia-baseline-extended --suite extended
```

입력만 검증할 때:

```bash
./scripts/preview-renderer-baseline.sh --validate-only --suite extended --page-mode manifest
```

기본 해석 순서:

1. top-level `summary.md`의 `Runs`에서 policy/page별 exit code를 본다.
2. `Pair Summary`에서 `Triage`, `KnownRisk`, `SkiaMinusCGChangedPercent`, `NativeSizeDriftPx`를 먼저 본다.
3. `FAIL` row는 `Phase` 또는 status prefix의 `[phase:...]`를 기준으로 `readiness`, `render`, `comparison`을 분리한다.
4. `warn:skia-delta`는 Skia가 같은 reference 대비 CoreGraphics보다 악화된 signal이다. default 전환 blocker 후보로 본다.
5. `warn:skia-changed`는 reference 대비 changed percent가 threshold를 넘었다는 signal이다. Skia가 CoreGraphics보다 나쁘다는 뜻은 아니므로 diff PNG 눈검증으로 본다.
6. `known-risk`는 무시가 아니라 별도 해석이다. `clean-capture-sentinel`처럼 capture가 clean한 경우에는 visual metric을 renderer triage 입력으로 쓴다.

## 2026-06-30 Baseline 해석

Task #396 Stage 4 기준 quick suite는 CoreGraphics/Skia 양쪽 모두 exit 0이다. extended suite는 page-1 batch에서 readiness failure가 섞여 exit 1이었지만, helper가 실패 phase와 sample을 summary에 보존했다.

주요 기준:

| sample | 기준 해석 |
|--------|-----------|
| `KTX.hwp` | quick/extended 모두 `warn:skia-delta`, `+15.4874pp`. Skia default 전환 blocker 성격의 regression sentinel |
| `복학원서.hwp` | quick/extended 모두 `domComposite;ui=clean`, `known-risk`. capture contamination이 아니라 layout overflow/displayText 민감성으로 해석 |
| `field-01.hwp` | extended에서 `warn:skia-delta`, `+8.9979pp`. text/form field 계열 Skia regression 후보 |
| `form-002.hwpx` | CoreGraphics/Skia 양쪽에서 persistent `readiness` document load timeout. renderer 품질 실패로 세지 않음 |
| `table-complex.hwp`, `pic-crop-01.hwp` | extended full batch에서는 readiness timeout이 있었지만 소규모 재시도에서 통과. transient readiness failure로 기록 |

현재 운영 기준:

- PR smoke에는 quick suite를 우선 사용한다.
- extended suite는 Skia default 판단 전 수동 sweep으로 사용한다.
- extended suite를 CI hard gate로 올리기 전에는 retry/flake 정책이 필요하다.
- `form-002.hwpx`는 rhwp-studio automation readiness 개선 전까지 renderer 품질 판단에서 제외하거나 persistent readiness failure로 별도 표기한다.
- Thumbnail/Finder cache 판단은 이 visual suite만으로 완료하지 않는다. #392, #389 후속 작업의 surface smoke가 필요하다.
