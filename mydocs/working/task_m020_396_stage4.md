# Task M020 #396 Stage 4 완료 보고서

## 단계 목적

Stage 2-3에서 만든 `preview-renderer-baseline` manifest/helper를 실제 산출물 경로에서 실행해 quick smoke 반복 가능성과 extended 후보 suite의 실행 가능성을 확인한다.

#398 merge 이후 기준을 반영해 `복학원서.hwp`는 capture contamination sample이 아니라 `clean-capture-sentinel`, `layout-overflow-watch`, `display-text-sensitive` known-risk sample로 검증했다.

## 산출물

| 경로 | 내용 |
|------|------|
| `build.noindex/task396-baseline-quick/` | quick suite 공식 baseline 실행 산출물 |
| `build.noindex/task396-baseline-extended-sample/` | extended suite 전체 후보 실행 산출물 |
| `build.noindex/task396-baseline-extended-retry/` | readiness 실패 샘플 재시도 산출물 |
| `mydocs/working/task_m020_396_stage4.md` | Stage 4 완료 보고서 |
| `mydocs/orders/20260630.md` | Stage 4 승인 대기 상태 갱신 |

## 기본 검증

다음 명령을 실행했다.

```bash
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
./scripts/check-no-appkit.sh
python3 -m json.tool scripts/preview_renderer_baseline_manifest.json >/dev/null
./scripts/preview-renderer-baseline.sh --validate-only --suite extended --page-mode manifest
```

결과:

```text
OK: RhwpCoreBuildInfo matches rhwp-core.lock
OK: rhwp-studio assets verified
OK: Sources/RhwpCoreBridge has no forbidden AppKit/UIKit imports
extended validate: samples=20, samplePages=21
```

## Quick suite 결과

실행:

```bash
./scripts/preview-renderer-baseline.sh build.noindex/task396-baseline-quick --suite quick
```

결과:

```text
coreGraphicsOnly page-1: exitCode=0, inputs=5
skiaOptIn page-1: exitCode=0, inputs=5
```

대표 summary:

| id | CG changed | Skia changed | Skia-CG delta | triage |
|----|------------|--------------|---------------|--------|
| `request-basic-quick` | `17.6908%` | `11.6265%` | `-6.0643pp` | `warn:skia-changed` |
| `ktx-regression-sentinel` | `30.8921%` | `46.3795%` | `+15.4874pp` | `warn:skia-delta` |
| `bokhakwonseo-capture-sentinel` | `7.2888%` | `6.9406%` | `-0.3482pp` | `known-risk` |
| `hwp-multi-001-page-loop` | `14.1976%` | `13.9298%` | `-0.2678pp` | `warn:skia-changed` |
| `hwpx-01-path` | `14.0216%` | `13.8212%` | `-0.2004pp` | `warn:skia-changed` |

확인 사항:

- quick suite는 CoreGraphics/Skia 양쪽 모두 exit 0으로 반복 실행 가능하다.
- `KTX.hwp`는 예상대로 `warn:skia-delta`다. Skia opt-in changed percent가 CoreGraphics보다 `+15.4874pp` 높게 나와 #390에서 확인한 visual regression blocker가 baseline summary에 다시 드러났다.
- `복학원서.hwp`는 `domComposite;ui=clean` + `known-risk`다. 즉 모달/토스트/local font UI가 capture를 오염시킨 상태가 아니라, clean capture 위에서 layout/display text 민감 sample로 분리된다.
- quick suite의 `NativeSizeDriftPx`는 모든 row가 `0`이었다.

## Extended suite 결과

실행:

```bash
./scripts/preview-renderer-baseline.sh build.noindex/task396-baseline-extended-sample --suite extended
```

결과:

```text
coreGraphicsOnly page-1: exitCode=1, inputs=20
coreGraphicsOnly page-2: exitCode=0, inputs=1
skiaOptIn page-1: exitCode=1, inputs=20
skiaOptIn page-2: exitCode=0, inputs=1
```

page-1 전체 batch에서 readiness failure가 섞여 exit 1이 되었지만, helper는 실패 phase와 실패 sample을 summary에 보존했다. page-2 run은 CoreGraphics/Skia 모두 exit 0이었다.

주요 triage:

| id | page | 결과 |
|----|------|------|
| `ktx-regression-sentinel` | 1 | `warn:skia-delta`, `+15.4874pp` |
| `bokhakwonseo-capture-sentinel` | 1 | `known-risk`, `domComposite;ui=clean`, `-0.3482pp` |
| `field-01-field` | 1 | `warn:skia-delta`, `+8.9979pp` |
| `hwp-multi-001-page-loop` | 2 | `ok`, `-0.2265pp` |
| `shortcut-control-mark` | 1 | `known-risk`, `display-text-sensitive` |

Extended readiness failure:

| policy | sample | phase | 해석 |
|--------|--------|-------|------|
| `coreGraphicsOnly` | `hwpx/form-002.hwpx` | `readiness` document load timeout | 양쪽 renderer 공통 실패로 Skia 품질 실패가 아님 |
| `coreGraphicsOnly` | `table-complex.hwp` | `readiness` ready request timeout | 재시도에서 통과해 긴 batch 실행 중 transient readiness failure로 분류 |
| `skiaOptIn` | `pic-crop-01.hwp` | `readiness` ready request timeout | 재시도에서 통과해 긴 batch 실행 중 transient readiness failure로 분류 |
| `skiaOptIn` | `hwpx/form-002.hwpx` | `readiness` document load timeout | 양쪽 renderer 공통 실패로 Skia 품질 실패가 아님 |

## Readiness 실패 재시도

CoreGraphics 재시도:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task396-baseline-extended-retry/coreGraphicsOnly --page 1 --policy coreGraphicsOnly \
  samples/hwpx/form-002.hwpx samples/table-complex.hwp
```

결과:

| sample | result | metric |
|--------|--------|--------|
| `form-002.hwpx` | FAIL, `[phase:readiness]` document load timeout | - |
| `table-complex.hwp` | OK | `ChangedPercent=8.8441%`, `MeanRGBDelta=7.7621`, `NativeMs=1035.5` |

Skia 재시도:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task396-baseline-extended-retry/skiaOptIn --page 1 --policy skiaOptIn \
  samples/pic-crop-01.hwp samples/hwpx/form-002.hwpx
```

결과:

| sample | result | metric |
|--------|--------|--------|
| `pic-crop-01.hwp` | OK | `ChangedPercent=3.0393%`, `MeanRGBDelta=1.9914`, `NativeMs=35.4` |
| `form-002.hwpx` | FAIL, `[phase:readiness]` document load timeout | - |

재시도 판단:

- `form-002.hwpx`는 CoreGraphics/Skia 양쪽에서 반복적으로 `document load timed out`이다. renderer backend 차이가 아니라 rhwp-studio automation/document readiness 쪽 제한으로 본다.
- `table-complex.hwp`와 `pic-crop-01.hwp`는 소규모 재시도에서 통과했다. extended full batch에서는 WebKit automation readiness가 긴 run 중 일부 sample에서 흔들릴 수 있으므로, Stage 5에서는 report 소비자가 renderer failure와 environment/readiness failure를 혼동하지 않게 문서화해야 한다.

## Sentinel 해석

`KTX.hwp`:

- quick/extended 모두 `warn:skia-delta`다.
- `NativeSizeDriftPx=0`이므로 이번 산출물에서 보인 핵심 문제는 크기 mismatch가 아니라 pixel delta다.
- Skia default 전환 판단에서는 계속 blocker 성격의 regression sentinel로 남겨야 한다.

`복학원서.hwp`:

- quick/extended 모두 `domComposite;ui=clean`, `known-risk`다.
- `captureContaminated=false`, `modalCount=0`, `toastCount=0`, `localFontUIVisible=false` metadata가 확인된다.
- 남은 `LAYOUT_OVERFLOW` warning은 capture contamination이 아니라 layout/display text 민감성으로 후속 triage해야 한다.

`field-01.hwp`:

- extended suite에서 `warn:skia-delta`로 새로 드러났다.
- Skia changed percent `12.2456%`, CoreGraphics `3.2477%`, delta `+8.9979pp`다.
- KTX 다음 단계에서 Skia text/form field 계열 대표 regression 후보로 같이 봐야 한다.

## 후속 이슈 입력

- #392 Thumbnail maxDimension mapping: 이번 preview baseline의 quick sentinel은 `NativeSizeDriftPx=0`이지만, extended `exam-math-equation`에서 `NativeSizeDriftPx=1`이 한 번 보였다. Finder Thumbnail surface의 maxDimension/cache 경로는 별도 smoke가 필요하므로 #392는 계속 유효하다.
- #389 Thumbnail diagnostic/cache logging: visual suite는 document render 비교에 집중하고 Finder cache 동작은 보지 못한다. cache/signature 관측성은 별도 작업으로 유지해야 한다.
- #393 direct PNG fast path: KTX/field delta가 남아 있으므로 direct PNG fast path는 default 전환 수단이 아니라 opt-in 검증 축으로 유지하는 편이 맞다.

## 완료 조건 판단

- quick suite 공식 산출물을 생성했고 CoreGraphics/Skia 모두 exit 0이다.
- extended suite 전체 후보를 실행했고, 성공 row와 readiness failure row를 같은 summary에 보존했다.
- `KTX.hwp` regression sentinel과 `복학원서.hwp` known-risk sentinel이 의도대로 분류된다.
- renderer warning, known-risk, readiness failure가 분리되어 Stage 5 문서화 입력으로 사용할 수 있다.

## 잔여 위험

- `form-002.hwpx`는 persistent readiness failure다. 이 sample은 renderer 품질 판단에서 제외하거나, rhwp-studio automation readiness 개선 후 다시 포함해야 한다.
- extended full batch는 긴 run에서 일부 transient readiness failure가 발생할 수 있다. 현재 helper는 이를 phase로 보존하지만, CI gate로 쓰기 전에는 retry/flake 정책이 추가로 필요하다.
- `warn:skia-changed`는 Skia가 CoreGraphics보다 나쁘다는 뜻이 아니다. reference 대비 threshold 초과 signal이며, default 전환 판단에는 `warn:skia-delta`, size drift, fallback, artifact 확인을 함께 봐야 한다.

## 승인 요청

Stage 4는 완료했다. Stage 5 `문서화/운영 가이드 정리`로 진행해도 되는지 승인 요청한다.
