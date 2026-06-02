# Task M014 #122 Stage 2 완료보고서

## 개요

Stage 2는 코드 변경 전 Swift/CoreGraphics image fill/tile/placement helper 설계를 고정하는 단계다. Stage 1에서 확인한 것처럼 Swift model은 입력 필드를 이미 보존하지만 `CGTreeRenderer`의 draw destination 정책이 bbox 전체 draw로 고정되어 있다. Stage 3 구현은 이 문서의 설계를 기준으로 최소 변경한다.

## 기준

| 항목 | 값 |
|------|----|
| 이슈 | #122 Swift native renderer 이미지 fill mode·타일·배치 렌더링 parity 보강 |
| 브랜치 | `local/task122` |
| 기준 브랜치 | `origin/devel` `cfb60a0` |
| core/studio 기준 | `edwardkim/rhwp v0.7.13`, `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| 선행 단계 | `mydocs/working/task_m014_122_stage1.md` |

## 설계 목표

- render tree image와 overlay image가 같은 fill/tile/placement draw policy를 사용한다.
- 기존 `crop`, `effect`, `brightness`, `contrast`, #116 baked watermark gate는 유지한다.
- `fill_mode == nil`, `FitToSize`, `None`, unknown mode는 현재 bbox 전체 draw 동작을 보존한다.
- known placement/tile mode만 bbox clip + original size 기반 draw로 전환한다.
- Swift/AppKit/CoreGraphics 좌표계에 맞춰 CGImage Y축 반전 문제를 helper 안으로 숨긴다.

## 현재 변경 대상

Stage 3의 코드 변경은 우선 `Sources/RhwpCoreBridge/CGTreeRenderer.swift`에 제한한다.

변경 대상 함수:

- `renderImage(_:bbox:in:)`
- `renderOverlayImage(_:in:document:)`
- `imageDestinationRect(for:size:)`

예상 helper:

- `normalizedImageFillPolicy(_:)`
- `imageNaturalDrawSize(for:decodedImageSize:drawImageSize:)`
- `drawImage(_:node:bbox:in:)`
- `drawImage(_:inTopLeftRect:in:)`
- `drawTiledImage(_:bbox:tileMode:tileSize:in:)`

필요 시 private enum을 `CGTreeRenderer` 내부에 둔다. 새 public API나 bridge ABI 변경은 하지 않는다.

## Fill Mode Normalization

입력 `fillMode`는 문자열이므로 다음 정규화를 적용한다.

1. 앞뒤 whitespace 제거
2. `_`, `-`, 공백 제거
3. lowercase

정책:

| normalized 값 | 정책 | 이유 |
|----------------|------|------|
| `nil`, empty | `.fitToSize` | 현재 render tree picture path 동작 보존 |
| `fittosize`, `stretch`, `stretchtofit` | `.fitToSize` | 기존 Swift 동작과 upstream bbox draw 의미 |
| `none` | `.fitToSize` | upstream WebCanvas가 `ImageFillMode::None`을 `FitToSize`와 같은 branch로 처리하고, 현재 Swift bbox draw와도 일치 |
| `lefttop` | `.placement(.leftTop)` | known placement |
| `centertop` | `.placement(.centerTop)` | known placement |
| `righttop` | `.placement(.rightTop)` | known placement |
| `leftcenter` | `.placement(.leftCenter)` | known placement |
| `center`, `centercenter` | `.placement(.center)` | known placement 및 alias |
| `rightcenter` | `.placement(.rightCenter)` | known placement |
| `leftbottom` | `.placement(.leftBottom)` | known placement |
| `centerbottom` | `.placement(.centerBottom)` | known placement |
| `rightbottom` | `.placement(.rightBottom)` | known placement |
| `tileall` | `.tile(.all)` | known tile |
| `tilehorztop`, `tilehoriztop`, `tilehorizontaltop` | `.tile(.horizontalTop)` | known tile |
| `tilehorzbottom`, `tilehorizbottom`, `tilehorizontalbottom` | `.tile(.horizontalBottom)` | known tile |
| `tilevertleft`, `tileverticalleft` | `.tile(.verticalLeft)` | known tile |
| `tilevertright`, `tileverticalright` | `.tile(.verticalRight)` | known tile |
| 그 외 | `.fitToSize` | 기존 full bbox fallback 보존 |

실제 Swift 구현에서는 정규화 후 lowercase 문자열만 비교하므로 `tilehoriztop`, `tilehorizbottom`, `tileverticalleft`, `tileverticalright` alias도 함께 두는 편이 안전하다.

## Size Policy

known placement/tile mode에서 사용할 draw size 우선순위:

1. `ImageNode.originalSize`가 2개 이상의 positive finite 값이면 사용
2. 아니면 원본 decode 직후 `CGImage.width/height` 사용
3. 이것도 invalid이면 prepared image size 사용
4. 여전히 invalid이면 `.fitToSize` fallback

`originalSizeHU`는 draw size 계산에 사용하지 않는다.

이유:

- upstream render tree 문서상 `original_size`는 fill mode가 배치 모드일 때 원래 크기대로 배치하기 위한 display coordinate 값이다.
- upstream `compute_image_crop_src`는 현재 `original_size_hu`를 crop scale 계산에 사용하지 않고 75 HU/px 표준 룰을 사용한다.
- 현재 Swift `croppedImage`도 `imageCropUnitsPerPixel = 75.0`을 사용하므로 `originalSizeHU`를 새 size policy에 끼워 넣으면 오히려 #106/#116 이후 crop 동작과 충돌할 수 있다.

주의:

- `preparedImage`는 crop/effect가 적용된 이미지일 수 있다.
- tile/placement fallback size는 crop 이후 이미지 크기가 아니라 원본 decoded image size를 우선 사용한다. upstream CanvasKit도 crop source rect와 destination size를 분리한다.
- `originalSize`가 있으면 crop 여부와 관계없이 destination tile/image size는 `originalSize`를 따른다.

## Draw Order

Stage 3의 image draw 순서:

1. `CGImage` decode 또는 cache hit
2. 원본 decoded image size 저장
3. `preparedImage(for:node:applyingAdjustments:)`
   - crop 적용
   - effect/brightness/contrast 적용
   - overlay baked watermark adjustment skip 유지
4. fill policy normalization
5. bbox rect 계산
6. policy별 draw

정책별 draw:

| 정책 | 동작 |
|------|------|
| `.fitToSize` | bbox 전체 draw |
| `.placement` | bbox clip 후 natural size로 placement rect에 draw |
| `.tile` | bbox clip 후 tile loop로 반복 draw |

## CGImage 좌표계 설계

기존 코드는 bbox local coordinate로 이동한 뒤 Y축을 뒤집고 `ctx.draw(image, in:)`를 호출한다. 이 방식은 full bbox draw에는 문제가 없지만, partial placement/tile rect를 단순히 `drawRect`로 전달하면 top/bottom 위치가 뒤집힐 수 있다.

Stage 3에서는 destination rect를 항상 현재 renderer의 top-left page coordinate로 계산한다. 실제 CGImage draw 직전에만 다음 helper로 국소 flip을 적용한다.

```swift
private func drawImage(_ image: CGImage, inTopLeftRect rect: CGRect, in ctx: CGContext) {
    ctx.saveGState()
    ctx.translateBy(x: rect.minX, y: rect.minY + rect.height)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(image, in: CGRect(origin: .zero, size: rect.size))
    ctx.restoreGState()
}
```

이 helper를 사용하면 placement와 tile 계산은 모두 top-left 좌표계로 유지할 수 있다.

## Placement Rect

placement rect는 bbox와 natural size를 기준으로 계산한다.

| Placement | x | y |
|-----------|---|---|
| leftTop | `bbox.minX` | `bbox.minY` |
| centerTop | `bbox.midX - width / 2` | `bbox.minY` |
| rightTop | `bbox.maxX - width` | `bbox.minY` |
| leftCenter | `bbox.minX` | `bbox.midY - height / 2` |
| center | `bbox.midX - width / 2` | `bbox.midY - height / 2` |
| rightCenter | `bbox.maxX - width` | `bbox.midY - height / 2` |
| leftBottom | `bbox.minX` | `bbox.maxY - height` |
| centerBottom | `bbox.midX - width / 2` | `bbox.maxY - height` |
| rightBottom | `bbox.maxX - width` | `bbox.maxY - height` |

draw 전에는 `ctx.clip(to: bbox)`를 적용한다. natural size가 bbox보다 커도 clip으로 잘라낸다.

## Tile Loop

tile mode는 bbox clip 안에서 natural size로 반복 draw한다.

| Tile mode | 시작점/반복 |
|-----------|-------------|
| tileAll | `x = bbox.minX`, `y = bbox.minY`부터 양방향 반복 |
| tileHorzTop | `y = bbox.minY`, `x = bbox.minX`부터 수평 반복 |
| tileHorzBottom | `y = bbox.maxY - tileHeight`, `x = bbox.minX`부터 수평 반복 |
| tileVertLeft | `x = bbox.minX`, `y = bbox.minY`부터 수직 반복 |
| tileVertRight | `x = bbox.maxX - tileWidth`, `y = bbox.minY`부터 수직 반복 |

guard:

- `tileWidth <= 0` 또는 `tileHeight <= 0`이면 `.fitToSize` fallback
- 최대 tile draw count는 upstream CanvasKit과 같은 `4096`으로 둔다.
- 한계에 도달하면 그 지점에서 중단한다. 현재 `CGTreeRenderer`에는 unsupported diagnostics surface가 없으므로 Stage 3에서는 별도 public diagnostic을 추가하지 않는다.

## Transform/Clip Policy

기존 `applyTransform(node.transform, bbox: bbox, in: ctx)` 호출은 유지한다.

순서:

1. renderer는 현재처럼 image별 `ctx.saveGState()`
2. `applyTransform`
3. fill/tile/placement draw helper 호출
4. helper 내부에서 필요한 경우 `ctx.clip(to: bboxRect)`
5. 각 draw call마다 `drawImage(_:inTopLeftRect:in:)`로 CGImage flip
6. renderer image scope의 `ctx.restoreGState()`

upstream CanvasKit도 `withImageTransform(..., () => drawImageOp(...))` 안에서 bbox clip을 수행하므로 이 순서는 upstream과 맞는다.

## Overlay Path Policy

overlay path는 Stage 3에서 별도 구현을 만들지 않는다.

- `renderOverlayImage`는 현재처럼 `RhwpPageOverlayImage`를 `ImageNode`로 변환한다.
- `bakedWatermark == true && source.data != nil`이면 adjustment skip gate를 유지한다.
- 이후 draw helper는 render tree image와 동일하게 호출한다.

이렇게 하면 #282 overlay compositor와 #116 baked watermark gate를 건드리지 않고 fill/tile/placement 정책만 공유할 수 있다.

## Fallback Policy

다음 경우는 기존 bbox 전체 draw로 폴백한다.

- `fillMode`가 nil 또는 empty
- `fitToSize`, `stretch`, `stretchToFit`, `none`
- unknown fill mode
- natural size 계산 실패
- tile size가 0 이하

fallback은 실패를 숨기는 목적이 아니라 기존 sample 회귀를 막기 위한 보수적 정책이다. Stage 1에서 non-null `fill_mode` fixture가 부족했기 때문에 unknown mode를 original-size placement로 바꾸지 않는다.

## Stage 3 구현 단위

예상 변경은 다음 순서로 진행한다.

1. private enum/helper 추가
2. `renderImage`가 원본 decoded size와 prepared image를 함께 넘기도록 수정
3. `renderOverlayImage`도 같은 helper를 사용하도록 수정
4. 기존 `imageDestinationRect(for:size:)`는 제거하거나 `.fitToSize` 전용 helper로 축소
5. `git diff --check`와 build 검증

## 검증 계획

Stage 3 구현 후 최소 검증:

```bash
./scripts/render-debug-compare.sh build.noindex/task122-stage3-render-debug --page 1 \
  samples/pic-crop-01.hwp samples/tac-img-02.hwp

xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task122 CODE_SIGNING_ALLOWED=NO build

git diff --check
./scripts/check-extension-registration-hygiene.sh --check-only
```

Stage 4에서 visual diff와 regression smoke를 별도로 수행한다.

## 리스크

- `none`의 의미는 upstream CanvasKit layer replay와 WebCanvas 사이에 차이가 있을 수 있다. 이번 작업에서는 WebCanvas와 기존 Swift 동작을 우선해 bbox draw로 둔다.
- 현재 sample set에는 non-null `fill_mode` fixture가 부족해 Stage 3에서 tile/placement 개선을 visual diff로 직접 증명하기 어렵다.
- tile/placement rect는 CGImage flip helper가 잘못되면 상하 위치가 반대로 나타날 수 있다.
- tile draw cap에 도달하는 문서는 이번 작업에서 별도 diagnostics가 없으므로, 향후 diagnostic surface가 필요할 수 있다.

## 검증

```bash
git diff --check
```

Stage 2 보고서 작성 후 기준으로 통과했다.

## 다음 단계 요청

Stage 3에서는 이 설계에 따라 `CGTreeRenderer.swift`에 실제 fill/tile/placement draw helper를 구현한다. 구현 범위는 Swift/CoreGraphics renderer 내부로 제한하고, render tree model/overlay model/upstream core는 변경하지 않는다.
