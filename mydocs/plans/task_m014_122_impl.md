# Task M014 #122 구현계획서

## 기준

- 이슈: #122
- 브랜치: `local/task122`
- 기준 브랜치: `origin/devel` `cfb60a0`
- 수행계획서 커밋: `f2e995e`
- core 기준: rhwp `v0.7.13`, resolved commit `b3e16ef212af81ef37d973ddb86d6816d3804642`

## 구현 목표

Swift/CoreGraphics native renderer가 이미지 `fill_mode`, `original_size`, `original_size_hu`, `crop` 조합을 upstream `rhwp-studio v0.7.13` renderer와 같은 의미로 소비하게 한다. 구현은 Quick Look preview, Finder thumbnail, PDF/CoreGraphics fallback이 공유하는 `CGTreeRenderer` 경로를 우선 대상으로 삼고, overlay image path도 같은 draw policy를 사용하도록 유지한다.

## 사전 조사 결과

수행계획서 승인 직후 소스 수정 없이 current path inventory와 baseline 측정을 수행했다.

확인한 현재 코드 경로:

- `RenderTree.swift`의 `ImageNode`는 `fill_mode`, `original_size`, `original_size_hu`, `crop`, `effect`, `brightness`, `contrast`, `text_wrap`를 이미 디코딩한다.
- `PageOverlayImages.swift`는 render tree image supplement에서 `fillMode`, `originalSize`, `originalSizeHU`, `crop`을 overlay model로 병합한다.
- `CGTreeRenderer.renderImage`와 `renderOverlayImage`는 모두 `ImageNode`를 통해 `preparedImage`와 `imageDestinationRect`를 호출한다.
- `preparedImage`는 현재 `crop`과 effect/brightness/contrast를 bitmap 준비 단계에서 처리한다.
- `imageDestinationRect(for:size:)`는 `FitToSize`/stretch 계열과 그 외 모드 모두 `fullRect`를 반환하므로 placement/tile mode는 구현되어 있지 않다.

baseline 측정:

| 샘플 | ChangedPercent | MeanRGBDelta | NativeBackend | StudioCapture | 비고 |
|------|---------------:|-------------:|---------------|---------------|------|
| `samples/pic-crop-01.hwp` | `2.0423%` | `0.8092` | `coreGraphics` | `domComposite` | image 2개, `fill_mode=null`, crop 있음 |
| `samples/tac-img-02.hwp` | `4.1085%` | `3.6656` | `coreGraphics` | `canvasDataURL` | image 1개, `fill_mode=null`, crop 있음 |
| `samples/tac-img-02.hwpx` | `4.1085%` | `3.6656` | `coreGraphics` | `domComposite` | image 1개, `fill_mode=null`, crop 있음 |

첫 sandbox 실행은 WebKit readiness timeout으로 실패했고, 같은 harness를 권한 상승 실행해 성공했다.

```text
build.noindex/task122-stage1-baseline/
build.noindex/task122-stage1-baseline-escalated/
build.noindex/task122-stage1-overlay/
build.noindex/task122-stage1-render-debug/
```

추가로 대표 image sample 11개 첫 페이지를 훑었지만 non-null `fill_mode` fixture는 발견하지 못했다. 따라서 Stage 2에서 placement/tile 계산 helper는 upstream contract 기준으로 구현하되, visual diff sample은 기존 crop/effect 회귀 방지 중심으로 해석한다. non-null fill/tile fixture가 필요하면 후속 단계에서 fixture 확보 범위를 작업지시자에게 별도 확인한다.

## upstream 기준 해석

upstream `v0.7.13`의 CanvasKit renderer는 image draw를 다음 흐름으로 처리한다.

1. crop이 있으면 source rect를 만든다.
2. `fillMode == fitToSize`면 bbox 전체에 draw한다.
3. 그 외 모드는 `originalSize`를 우선 tile/image 크기로 쓰고, 없으면 image pixel size로 폴백한다.
4. bbox로 clip한 뒤 tile mode면 반복 draw, 아니면 placement 좌표에 원본 크기로 draw한다.
5. tile mode는 `tileAll`, `tileHorzTop`, `tileHorzBottom`, `tileVertLeft`, `tileVertRight`를 구분한다.
6. placement mode는 `leftTop`, `centerTop`, `rightTop`, `leftCenter`, `center`, `rightCenter`, `leftBottom`, `centerBottom`, `rightBottom`를 구분한다.

Swift/CoreGraphics 구현은 이 의미를 그대로 따르되, 기존 좌상단 원점 context와 CGImage 상하 반전 처리에 맞게 helper boundary를 잡는다.

## Stage 구성

| Stage | 목표 | 산출물 |
|-------|------|--------|
| Stage 1 | current path inventory와 baseline 정리 | `task_m014_122_stage1.md` |
| Stage 2 | fill/tile/placement helper 설계 | `task_m014_122_stage2.md` |
| Stage 3 | CoreGraphics image draw 구현 | `CGTreeRenderer.swift` 중심 변경 |
| Stage 4 | overlay path parity와 visual diff 회귀 smoke | `task_m014_122_stage4.md` |
| Stage 5 | 최종 보고와 PR 게시 준비 | `task_m014_122_report.md` |

## Stage 1 세부 계획

이미 수행한 사전 조사를 단계 보고서로 정리한다.

- Swift model, overlay supplement, compositor, renderer 호출 경로를 파일/라인 기준으로 기록
- upstream CanvasKit/WebCanvas fill/tile contract 요약
- baseline visual diff, overlay metadata smoke, render debug 산출물 위치 기록
- 현재 sample set의 한계, 특히 non-null `fill_mode` fixture 부족을 리스크로 남김

검증:

```bash
git diff --check
```

## Stage 2 세부 계획

코드 변경 전 helper 설계를 문서로 고정한다.

- normalized fill mode enum 또는 private helper 범위 결정
- `FitToSize`/stretch/null/unknown fallback 정책 결정
- `original_size`, `original_size_hu`, image pixel size 우선순위 결정
- placement rect 계산 규칙 결정
- tile draw loop, clip rect, max tile draw guard 필요 여부 결정
- crop/effect/baked watermark gate와 fill/tile draw 순서 확정

검증:

```bash
git diff --check
```

## Stage 3 세부 계획

`CGTreeRenderer`에 최소 구현을 적용한다.

- `imageDestinationRect` 단일 rect 반환 구조를 draw policy/helper 구조로 교체
- render tree image와 overlay image가 같은 helper를 사용하게 유지
- placement mode는 bbox clip 후 원본 크기 draw
- tile mode는 bbox clip 후 축별 반복 draw
- unknown mode는 기존 full bbox draw fallback 유지
- 기존 `preparedImage`의 crop/effect/baked watermark gate는 변경하지 않음

검증:

```bash
./scripts/render-debug-compare.sh build.noindex/task122-stage3-render-debug --page 1 \
  samples/pic-crop-01.hwp samples/tac-img-02.hwp

xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task122 CODE_SIGNING_ALLOWED=NO build

git diff --check
./scripts/check-extension-registration-hygiene.sh --check-only
```

## Stage 4 세부 계획

visual diff와 overlay/renderer 회귀를 확인한다.

- 계획서 baseline 3개 sample 재측정
- #116 regression sample set에서 image/effect/watermark 회귀 확인
- overlay metadata smoke로 overlay path가 계속 renderable인지 확인
- sandbox WebKit readiness 실패는 권한 상승 실행 필요 조건으로 보고서에 남김

검증:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task122-stage4-baseline --page 1 \
  samples/pic-crop-01.hwp samples/tac-img-02.hwp samples/tac-img-02.hwpx

./scripts/preview-visual-diff-harness.sh build.noindex/task122-stage4-regression --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp samples/복학원서.hwp

./scripts/overlay-metadata-smoke.sh build.noindex/task122-stage4-overlay --page 1 \
  samples/pic-crop-01.hwp samples/tac-img-02.hwp samples/tac-img-02.hwpx

git diff --check
```

## Stage 5 세부 계획

최종 결과를 정리하고 PR 게시 준비를 수행한다.

- 최종 보고서에 구현 범위, baseline/after 수치, fixture 한계, 후속 필요 항목 기록
- 오늘할일 완료 처리
- 최종 검증 명령 재실행
- `publish/task122` 브랜치와 PR 준비는 최종 보고 승인 후 진행

검증:

```bash
git status --short
git log --oneline -5
```

## 승인 필요 사항

1. Stage 1은 이미 수행한 소스 수정 없는 조사/측정 결과를 단계 보고서로 정리한다.
2. Stage 2는 코드 변경 전 fill/tile/placement helper 설계를 문서로 고정한다.
3. non-null `fill_mode` fixture가 현재 sample 첫 페이지 조사에서 부족하므로, 이번 PR의 visual diff는 기존 crop/effect 회귀 방지 중심으로 해석하고 placement/tile 자체는 upstream contract 기반 helper/단위 판단으로 구현한다.
