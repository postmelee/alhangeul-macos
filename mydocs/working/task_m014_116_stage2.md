# Task M014 #116 Stage 2 보고서

## 단계 목적

Stage 1에서 확인한 최신 `v0.7.13` overlay metadata를 기준으로 `복학원서.hwp` 중앙 watermark의 Swift/CoreGraphics 보정 경로를 설계했다. 기존 이슈 본문은 `JPEG + bakedWatermark=false` 전제였지만, 현재 payload는 `image/png + bakedWatermark=true`이므로 구현 범위를 중복 image adjustment 방지로 좁혔다.

## 최신 이슈 정리

작업 전 관련 이슈를 다시 점검했고, 오래된 전제와 현재 관찰값이 충돌하는 내용을 이슈 코멘트로 남겼다.

- #116: https://github.com/postmelee/alhangeul-macos/issues/116#issuecomment-4581800700
- #296: https://github.com/postmelee/alhangeul-macos/issues/296#issuecomment-4581800594

관련 이슈 판단:

| 이슈 | 상태 | #116 영향 |
|------|------|-----------|
| #296 | open | 향후 core update compatibility follow-up으로 유지. 현재 `v0.7.13` duplicate adjustment gate는 #116에서 처리 |
| #122 | open | 다음 image fill/tile/placement parity. #116 blocker 아님 |
| #121, #110 | open | renderer parity 후속. 현재 watermark 후처리와 별도 |
| edwardkim/rhwp#976 | closed | 현재 baked PNG payload의 upstream 배경 |
| edwardkim/rhwp#1016 | open | resolved payload 일반화 이슈. 현재 대상 fixture는 이미 baked PNG로 관찰됨 |
| edwardkim/rhwp#1017 | open | z-order/replay policy 축. 이번 중복 보정 gate와 분리 |
| edwardkim/rhwp#421/#516/#535 | closed | 과거 blocker였지만 현재 직접 blocker로 보지 않음 |

## 경로 확인

현재 Swift/CoreGraphics path:

1. `HwpNativePageCompositor`가 `RhwpPageOverlayImageSet.behind`를 `CGTreeRenderer.renderOverlayImages`로 전달한다.
2. `CGTreeRenderer.renderOverlayImage`는 `RhwpPageOverlayImage`를 임시 `ImageNode`로 변환한다.
3. `RhwpPageOverlayImage.bakedWatermark`는 `ImageNode`에 전달되지 않는다.
4. `preparedImage(for:node:)`는 crop 적용 후 항상 `adjustedImage(for:node:)`를 호출한다.
5. `adjustedImage`는 `effect=grayScale`, `brightness=-50`, `contrast=70`을 다시 적용한다.

따라서 `bakedWatermark=true`인 resolved PNG가 Swift에서 한 번 더 어두워질 수 있다.

## 설계 결정

Stage 3 구현은 `CGTreeRenderer`의 overlay path에 한정한다.

1. `preparedImage(for:node:)`에 adjustment 적용 여부를 전달할 수 있는 인자를 추가한다.
2. 일반 render tree image path는 기본값으로 기존 동작을 유지한다.
3. overlay path에서는 `image.bakedWatermark && image.source.data != nil`일 때만 adjustment를 생략한다.
4. crop, transform, destination rect, fill mode 계산은 기존과 동일하게 유지한다.
5. `ImageNode` 모델에 `bakedWatermark`를 추가하지 않는다. render tree JSON에는 해당 의미가 없고, 이번 결정은 compact overlay resolved payload contract에만 의존하기 때문이다.

`image.source.data != nil` 조건을 추가한 이유:

- 현재 `복학원서.hwp` 중앙 watermark는 overlay JSON에 실제 resolved PNG bytes가 포함되어 있고 `byteCount=253602`이다.
- 그러나 overlay JSON이 없거나 base64 decode가 실패하면 `decodedOverlayImage`는 `binDataId`로 원본 문서 리소스를 다시 읽을 수 있다.
- 이 fallback 입력이 이미 baked된 bytes라는 보장이 없으므로, 이 경우에는 기존 effect/brightness/contrast 보정을 유지하는 편이 안전하다.

## 보류 결정

JPEG white/near-white transparency fallback은 이번 Stage 3에 넣지 않는다.

이유:

- 현재 target fixture가 더 이상 `JPEG + bakedWatermark=false`가 아니다.
- 일반 JPEG 사진이나 흰 배경 그림에 오탐 적용될 위험이 있다.
- `bakedWatermark=false` 양성 fixture가 확보된 뒤 별도 조건과 threshold를 설계하는 편이 안전하다.

## Stage 3 구현 계획

예상 변경:

```swift
private func preparedImage(
    for image: CGImage,
    node: ImageNode,
    applyingAdjustments: Bool = true
) -> CGImage {
    let cropped = croppedImage(for: image, crop: node.crop)
    guard applyingAdjustments else { return cropped }
    return adjustedImage(for: cropped, node: node)
}
```

overlay path:

```swift
let appliesAdjustments = !(image.bakedWatermark && image.source.data != nil)
let drawImage = preparedImage(for: cgImage, node: node, applyingAdjustments: appliesAdjustments)
```

## 검증 계획

Stage 3 구현 후 실행한다.

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task116-after-baked-gate --page 1 \
  samples/복학원서.hwp

./scripts/preview-visual-diff-harness.sh build.noindex/task116-regression --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp

./scripts/overlay-metadata-smoke.sh build.noindex/task116-overlay-metadata --page 1 \
  samples/복학원서.hwp

xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task116 CODE_SIGNING_ALLOWED=NO build

git diff --check
```

비교 기준:

- `복학원서.hwp` native output의 중앙 watermark가 Stage 1보다 덜 어둡고 rhwp-studio reference에 가까워지는지 확인한다.
- `ChangedPercent`, `MeanRGBDelta`를 Stage 1 baseline과 비교한다.
- 기존 image sample set에서 일반 image effect/crop/fill 경로가 회귀하지 않는지 확인한다.

## 다음 단계

Stage 3에서는 위 설계대로 최소 구현을 진행한다.
