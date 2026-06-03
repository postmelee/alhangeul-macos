# Task M014 #110 Stage 4 완료 보고서

## 단계 목적

Stage 4는 Stage 3 구현 후 target form sample과 M014 공통 sample set을 다시 측정해 visual diff, renderer smoke, shared Quick Look/PDF path 회귀 여부를 확인하는 단계다. 소스 코드는 변경하지 않고 검증 산출물과 수치만 기록했다.

## 산출물

| 경로 | 요약 |
|------|------|
| `build.noindex/task110-stage4-target/` | `form-01.hwp`, `form-002.hwpx` rhwp-studio/native/diff PNG와 `summary.md` |
| `build.noindex/task110-stage4-regression/` | M014 공통 sample set visual diff PNG와 `summary.md` |
| `build.noindex/task110-stage4-render-debug/` | target sample render tree, core SVG, native PNG, summary |
| `build.noindex/task110-stage4-pdf-compare/` | Quick Look PDF/native renderer compare summary |
| `build.noindex/task110-stage4-quicklook-policy/` | Quick Look CoreGraphics/Skia policy smoke summary |

위 산출물은 모두 재생성 가능한 `build.noindex/` 결과물이므로 커밋하지 않는다.

## target visual diff

첫 sandbox 실행은 Stage 1과 동일하게 WebKit readiness timeout으로 실패했다.

```text
FAIL .../samples/form-01.hwp: [phase:readiness] rhwp-studio page 1 readiness timed out: navigation=pending; events=[]; scheme={resourceRequests=0, documentRequests=0}
FAIL .../samples/hwpx/form-002.hwpx: [phase:readiness] rhwp-studio page 1 readiness timed out: navigation=pending; events=[]; scheme={resourceRequests=0, documentRequests=0}
```

동일 명령을 승인 경로로 재실행해 성공했다.

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task110-stage4-target --page 1 \
  samples/form-01.hwp samples/hwpx/form-002.hwpx
```

| 샘플 | Status | Stage 1 ChangedPercent | Stage 4 ChangedPercent | 변화 |
|------|--------|-----------------------:|-----------------------:|-----:|
| `form-01.hwp` | OK | 0.8066% | 0.6153% | -0.1913%p |
| `form-002.hwpx` | OK | 15.2500% | 16.1230% | +0.8730%p |

세부 수치:

| 샘플 | ChangedPixels | MeanRGBDelta | DiffBounds | NativeMs |
|------|--------------:|-------------:|------------|---------:|
| `form-01.hwp` | `21921/3562815` | 0.3370 | `197,234 1194x1814` | 996.9 |
| `form-002.hwpx` | `574177/3561228` | 17.0864 | `121,159 1345x1962` | 32.9 |

시각 확인:

- `form-01.hwp` native PNG에서 button, checkbox, combo box, radio button, edit box가 표시된다.
- `form-002.hwpx` native PNG에서 checkbox square/check/label이 표시된다.
- `form-002.hwpx`의 diff 증가는 기존 no-op 빈 영역에 checkbox 표시가 추가되며 rhwp-studio와의 세부 위치/크기 차이가 새로 계산된 결과로 판단한다. crash나 blank regression은 아니다.

## regression visual diff

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task110-stage4-regression --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/복학원서.hwp samples/pic-crop-01.hwp \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/draw-group.hwp samples/eq-01.hwp
```

결과:

| 샘플 | Status | ChangedPercent | MeanRGBDelta | 비고 |
|------|--------|----------------:|-------------:|------|
| `request.hwp` | OK | 18.2346% | 10.8057 | 기존 layout 차이 영역 유지 |
| `hwpx-01.hwpx` | OK | 14.1829% | 15.1348 | task121 기준 native PNG hash 동일 |
| `복학원서.hwp` | OK | 7.2398% | 6.7272 | task121 기준 native PNG hash 동일 |
| `pic-crop-01.hwp` | OK | 2.0423% | 0.8092 | task121 기준 native PNG hash 동일 |
| `tac-img-02.hwp` | OK | 4.1085% | 3.6656 | current measurement OK |
| `tac-img-02.hwpx` | OK | 4.1085% | 3.6656 | current measurement OK |
| `draw-group.hwp` | OK | 0.8132% | 0.4881 | current measurement OK |
| `eq-01.hwp` | OK | 6.4707% | 5.9354 | current measurement OK |

`request.hwp`는 이전 task121 visual output과 native PNG hash가 달라 단순 hash 동일성 기준으로 회귀 없음이라고 단정하지 않았다. 다만 이번 Stage 4 visual harness는 모든 공통 sample에서 `OK`를 반환했고, FormObject 구현 범위와 직접 관련된 crash/blank failure는 없었다.

## render-debug 재측정

명령:

```bash
./scripts/render-debug-compare.sh build.noindex/task110-stage4-render-debug --page 1 \
  samples/form-01.hwp samples/hwpx/form-002.hwpx
```

결과:

| 샘플 | FormObject | Placeholder | NativePNGSize | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|------|-----------:|------------:|---------------|---------------------:|---------:|-----------:|--------------------:|
| `form-01.hwp` | 5 | 0 | `794x1123` | 4760 | 15 | 1 | 0 |
| `form-002.hwpx` | 36 | 0 | `794x1123` | 189203 | 135 | 62 | 0 |

Stage 3과 같은 native non-white count를 유지했다.

`render-debug-compare`의 optional core SVG raster diff는 Stage 1/3과 같이 `qlmanage` sandbox initialization 실패로 생성되지 않았다. 스크립트 exit code는 0이었다.

## Quick Look / PDF shared path smoke

PDF compare:

```bash
./scripts/compare-quicklook-pdf-renderers.sh build.noindex/task110-stage4-pdf-compare \
  samples/form-01.hwp samples/hwpx/form-002.hwpx
```

| 샘플 | Status | Pages | CurrentReply | NativePDFSeconds | NativePDFBytes | CoreSVGFailures |
|------|--------|------:|--------------|-----------------:|---------------:|-----------------|
| `form-01.hwp` | OK | 1 | png | 1.096652 | 21499 | - |
| `form-002.hwpx` | OK | 10 | pdf | 0.385595 | 2244428 | - |

Quick Look policy smoke:

```bash
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task110-stage4-quicklook-policy \
  samples/form-01.hwp samples/hwpx/form-002.hwpx
```

| 샘플 | Load | Reply | Pages | CGStatus | CGBackend | CGFallback | SkiaStatus | SkiaBackend | SkiaFallback |
|------|------|-------|------:|----------|-----------|-----------:|------------|-------------|-------------:|
| `form-01.hwp` | OK | png | 1 | OK | `skia:0,cg:1,embedded:0` | 0 | OK | `skia:1,cg:0,embedded:0` | 0 |
| `form-002.hwpx` | OK | pdf | 10 | OK | `skia:0,cg:10,embedded:0` | 0 | OK | `skia:10,cg:0,embedded:0` | 0 |

`preview-visual-diff-harness`와 `quicklook_skia_policy_smoke`는 `HwpPageImageRenderer`를 통해 native bitmap path를 호출한다. `ThumbnailExtension`도 `HwpThumbnailRenderCache`에서 `HwpPageImageRenderer.renderFirstPage(..., embeddedThumbnailPolicy: .never)`를 사용하므로 이번 FormObject 구현은 thumbnail rendering과 같은 CoreGraphics renderer path에 걸린다. 실제 Finder/PlugInKit 등록 smoke는 수행하지 않았고, registration hygiene check로 개발 extension 등록 오염 여부만 확인했다.

## policy / hygiene

명령:

```bash
./scripts/check-extension-registration-hygiene.sh --check-only
./scripts/check-no-appkit.sh
git diff --check
```

결과:

```text
Issues:
  - (none)
Warnings:
  - development/test Alhangeul.app bundles exist under build.noindex or DerivedData; this is only a problem if they are registered.
  - Quick Look preview provider path was not reported by PlugInKit.
  - Thumbnail provider path was not reported by PlugInKit.
```

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

`git diff --check`도 통과했다.

## 잔여 위험

- `form-002.hwpx`는 checkbox 표시가 추가되며 visual diff percentage가 상승했다. 이는 no-op 제거에 따른 expected movement로 판단하지만, checkbox label fitting과 position parity는 후속 정밀 renderer parity 항목으로 남는다.
- Finder 실제 thumbnail 등록/캐시 smoke는 이번 단계에서 실행하지 않았다. 개발 extension 등록 오염을 피하기 위해 registration hygiene check만 수행했다.
- `request.hwp`는 이전 task121 visual output과 native PNG hash가 달라 hash 기반 회귀 판단에서 제외했다.
- `qlmanage` 기반 optional SVG raster diff는 sandbox 환경 문제로 생성되지 않았다.

## 다음 단계 영향

Stage 5에서는 최종 보고서에 지원된 FormObject type, fallback 정책, target visual diff 전후 수치, shared Quick Look/PDF smoke 결과, Finder 실제 등록 smoke 미실행 사유를 정리한다. 오늘할일 상태도 완료로 갱신해야 한다.

## 승인 요청

Stage 4 visual diff, renderer smoke, shared path 검증을 완료했다. Stage 5 최종 보고서 작성과 PR 게시 준비 단계로 진행해도 되는지 승인 요청한다.
