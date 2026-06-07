# Task M014 #122 Stage 1 완료보고서

## 개요

Stage 1은 Swift/CoreGraphics renderer의 현재 image draw 경로를 inventory하고, #122 대상 sample의 baseline visual diff를 고정하는 단계다. 소스 코드는 변경하지 않았고, 기존 script와 local/bundled artifact만 사용해 측정했다.

## 기준

| 항목 | 값 |
|------|----|
| 이슈 | #122 Swift native renderer 이미지 fill mode·타일·배치 렌더링 parity 보강 |
| 브랜치 | `local/task122` |
| 기준 브랜치 | `origin/devel` `cfb60a0` |
| core/studio 기준 | `edwardkim/rhwp v0.7.13`, `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| 수행계획서 | `mydocs/plans/task_m014_122.md` |
| 구현계획서 | `mydocs/plans/task_m014_122_impl.md` |

## Current Path Inventory

### Render tree model

`Sources/RhwpCoreBridge/RenderTree.swift`의 `ImageNode`는 #122에 필요한 입력 필드를 이미 디코딩한다.

- `fillMode`
- `originalSize`
- `originalSizeHU`
- `effect`
- `brightness`
- `contrast`
- `textWrap`
- `crop`

따라서 Stage 3 구현의 중심은 모델 추가가 아니라 현재 입력을 draw 단계에서 제대로 소비하는 것이다.

### Render tree image draw path

`Sources/RhwpCoreBridge/CGTreeRenderer.swift` 기준 render tree image는 다음 흐름을 탄다.

1. `renderImage`가 `binDataId`로 이미지를 가져온다.
2. `preparedImage(for:node:)`가 crop과 effect/brightness/contrast를 적용한다.
3. `imageDestinationRect(for:size:)`가 destination rect를 계산한다.
4. Y축 반전된 국소 좌표계에서 `ctx.draw(drawImage, in: drawRect)`를 호출한다.

현재 핵심 한계는 `imageDestinationRect(for:size:)`다. `fillMode`를 normalize하긴 하지만 `FitToSize`/stretch 계열과 default 모두 `fullRect`를 반환한다. 결과적으로 placement/tile mode가 들어와도 bbox 전체 stretch로 보인다.

### Overlay image draw path

`Sources/RhwpCoreBridge/PageOverlayImages.swift`는 render tree image supplement에서 overlay image model로 다음 필드를 병합한다.

- `fillMode`
- `originalSize`
- `originalSizeHU`
- `crop`
- `effect`
- `brightness`
- `contrast`
- `transform`

`Sources/RhwpCoreBridge/CGTreeRenderer.swift`의 `renderOverlayImage`는 이 overlay model을 다시 `ImageNode`로 변환한 뒤 render tree image와 같은 `preparedImage` / `imageDestinationRect` path를 사용한다. 따라서 Stage 3에서 공통 image draw helper를 만들면 render tree image와 overlay image가 같은 fill/tile/placement 정책을 공유할 수 있다.

### Native compositor path

`Sources/Shared/HwpPageImageRenderer.swift`는 CoreGraphics renderer에서 `document.renderPageTree(at:)`와 `document.pageOverlayImages(at:renderTree:)`를 함께 가져온 뒤 `HwpNativePageCompositor.render`에 넘긴다.

`Sources/Shared/HwpNativePageCompositor.swift`는 다음 순서를 유지한다.

1. page background
2. BehindText overlay
3. flow excluding page overlays
4. InFrontOfText overlay

#122는 이 pass ordering 자체를 바꾸지 않고, 각 image pass 안에서 destination/tile 정책을 보강하는 범위로 유지한다.

## Upstream Contract

upstream `v0.7.13`의 CanvasKit image renderer는 다음 의미로 동작한다.

1. crop이 있으면 source rect를 계산한다.
2. `fillMode == fitToSize`면 bbox 전체에 draw한다.
3. 그 외 모드는 `originalSize`를 tile/image size로 우선 사용하고, 없으면 image pixel size로 폴백한다.
4. bbox로 clip한다.
5. tile mode는 반복 draw한다.
6. placement mode는 bbox 내부 기준 좌표에 원본 크기로 draw한다.

확인한 tile mode:

- `tileAll`
- `tileHorzTop`
- `tileHorzBottom`
- `tileVertLeft`
- `tileVertRight`

확인한 placement mode:

- `leftTop`
- `centerTop`
- `rightTop`
- `leftCenter`
- `center`
- `rightCenter`
- `leftBottom`
- `centerBottom`
- `rightBottom`

Stage 2에서는 이 contract를 Swift/CoreGraphics 좌상단 원점 좌표계와 기존 CGImage Y축 반전 처리에 맞게 helper로 설계한다.

## Baseline Visual Diff

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task122-stage1-baseline --page 1 \
  samples/pic-crop-01.hwp samples/tac-img-02.hwp samples/tac-img-02.hwpx
```

첫 실행은 sandbox 내부 WebKit readiness timeout으로 실패했다.

```text
rhwp-studio page 1 readiness timed out: navigation=pending; events=[]; scheme={resourceRequests=0, documentRequests=0}
```

같은 명령을 권한 상승 실행한 결과는 성공했다.

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task122-stage1-baseline-escalated --page 1 \
  samples/pic-crop-01.hwp samples/tac-img-02.hwp samples/tac-img-02.hwpx
```

| 파일 | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | DiffBounds | StudioCapture | NativeBackend | NativeMs |
|------|--------------:|---------------:|-------------:|------------:|------------|---------------|---------------|---------:|
| `pic-crop-01.hwp` | `72763/3562815` | `2.0423%` | `0.8092` | `186` | `121,234 1345x1814` | `domComposite` | `coreGraphics` | `1021.7` |
| `tac-img-02.hwp` | `146377/3562815` | `4.1085%` | `3.6656` | `255` | `121,159 1345x1965` | `canvasDataURL` | `coreGraphics` | `23.7` |
| `tac-img-02.hwpx` | `146377/3562815` | `4.1085%` | `3.6656` | `255` | `121,159 1345x1965` | `domComposite` | `coreGraphics` | `4.2` |

산출물:

```text
build.noindex/task122-stage1-baseline/
build.noindex/task122-stage1-baseline-escalated/
```

해석:

- `pic-crop-01.hwp`는 image crop/fill 계열 sample로 diff가 낮다.
- `tac-img-02.hwp`와 `tac-img-02.hwpx`는 같은 diff 수치를 보인다.
- `tac-img-02.hwp`는 reference capture가 `canvasDataURL`, `tac-img-02.hwpx`는 `domComposite`다.
- Stage 4 이후 비교 시 같은 capture mode 차이를 함께 기록해야 한다.

## Overlay Metadata Smoke

명령:

```bash
./scripts/overlay-metadata-smoke.sh build.noindex/task122-stage1-overlay --page 1 \
  samples/pic-crop-01.hwp samples/tac-img-02.hwp samples/tac-img-02.hwpx
```

결과:

| 파일 | UpstreamImages | Overlay | Behind | Front | Renderable | BinLinked | TreeImages | TreeEmbeddedAvailable | Wraps |
|------|---------------:|--------:|-------:|------:|-----------:|----------:|-----------:|-----------------------|-------|
| `pic-crop-01.hwp` | `2` | `0` | `0` | `0` | `0` | `0` | `2` | `2/2` | `Square:2` |
| `tac-img-02.hwp` | `1` | `0` | `0` | `0` | `0` | `0` | `1` | `1/1` | `TopAndBottom:1` |
| `tac-img-02.hwpx` | `1` | `0` | `0` | `0` | `0` | `0` | `1` | `1/1` | `TopAndBottom:1` |

산출물:

```text
build.noindex/task122-stage1-overlay/
```

해석:

- 이번 baseline sample 3개에는 PageLayerTree overlay image가 없다.
- #122의 Stage 3 구현은 render tree image path에서 먼저 효과가 나고, overlay path는 같은 helper를 공유하는지 회귀 smoke로 확인하는 방식이 맞다.

## Render Tree Debug

명령:

```bash
./scripts/render-debug-compare.sh build.noindex/task122-stage1-render-debug --page 1 \
  samples/pic-crop-01.hwp samples/tac-img-02.hwp samples/tac-img-02.hwpx
```

동일 basename인 `tac-img-02.hwp`와 `tac-img-02.hwpx`는 output stem이 겹치므로 별도 output directory로 다시 실행했다.

```bash
./scripts/render-debug-compare.sh build.noindex/task122-stage1-render-debug-hwp --page 1 \
  samples/tac-img-02.hwp

./scripts/render-debug-compare.sh build.noindex/task122-stage1-render-debug-hwpx --page 1 \
  samples/tac-img-02.hwpx
```

확인한 image node:

| 파일 | Image count | fill_mode | original_size | original_size_hu | crop | text_wrap |
|------|------------:|-----------|---------------|------------------|------|-----------|
| `pic-crop-01.hwp` | `2` | `null` | `null` | 있음 | 있음 | `Square` |
| `tac-img-02.hwp` | `1` | `null` | `null` | 있음 | 있음 | `TopAndBottom` |
| `tac-img-02.hwpx` | `1` | `null` | `null` | 있음 | 있음 | `TopAndBottom` |

추가로 대표 image sample 11개 첫 페이지를 훑었지만 non-null `fill_mode` fixture는 찾지 못했다.

```bash
./scripts/render-debug-compare.sh build.noindex/task122-stage1-fill-scan --page 1 \
  samples/hwp-img-001.hwp samples/img-start-001.hwp \
  samples/pic-in-head-01.hwp samples/pic-in-head-02.hwp samples/pic-in-table-01.hwp \
  samples/20250130-hongbo.hwp samples/aift.hwp samples/biz_plan.hwp \
  samples/k-water-rfp.hwp samples/kps-ai.hwp samples/복학원서.hwp
```

결과 요약:

| 샘플군 | image count | non-null fill_mode |
|--------|------------:|-------------------:|
| Stage 1 baseline 3개 | `4` | `0` |
| 추가 scan 11개 | `18` | `0` |

## 판단

1. Swift model은 #122 입력을 이미 보존한다.
2. 실제 결함 지점은 `CGTreeRenderer`의 draw destination/tile policy 부재다.
3. render tree image와 overlay image는 이미 같은 `ImageNode` path로 수렴하므로, Stage 3 구현은 공통 helper로 묶는 것이 맞다.
4. 현재 sample set은 crop/effect 회귀 측정에는 충분하지만, placement/tile mode 자체를 pixel diff로 증명하기에는 non-null `fill_mode` fixture가 부족하다.
5. Stage 2는 upstream CanvasKit/WebCanvas contract를 기준으로 helper 설계를 먼저 고정하고, Stage 3 구현 후 기존 sample에서는 회귀가 없는지 확인하는 방향이 타당하다.

## 리스크

- non-null `fill_mode` fixture가 없으면 tile/placement 자체의 visual diff 개선 수치를 이번 PR에서 직접 증명하기 어렵다.
- `original_size_hu`와 `original_size`의 우선순위를 잘못 잡으면 현재 `fill_mode=null` sample에는 영향이 없더라도 후속 fixture에서 크기 회귀가 생길 수 있다.
- `tac-img-02.hwp`와 `tac-img-02.hwpx`처럼 basename이 같은 파일은 일부 debug script output stem이 겹치므로 단계별 산출물 directory를 분리해야 한다.
- WebKit reference capture는 sandbox 내부에서 readiness timeout이 날 수 있어, Stage 4 visual diff는 권한 상승 실행 필요 조건을 명시해야 한다.

## 검증

```bash
git diff --check
```

Stage 1 보고서 작성 후 기준으로 통과했다.

## 다음 단계 요청

Stage 2에서는 코드 변경 전 `CGTreeRenderer`의 fill/tile/placement helper 설계를 문서로 고정한다. 특히 다음 항목을 확정한다.

- fill mode normalization
- `FitToSize`/stretch/null/unknown fallback
- `original_size`, `original_size_hu`, image pixel size 우선순위
- crop/effect/baked watermark gate와 draw policy 적용 순서
- tile loop와 clip/max tile guard 정책
