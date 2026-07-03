# Task #392 Stage 3 보고서: Thumbnail Skia maxDimension opt-in 적용

## 단계 목적

- Thumbnail Skia opt-in 경로에서 Swift의 `maximumPixelSize`를 Rust Skia PNG export의 `maxDimension` 인자로 전달한다.
- `maxDimension`을 전달하는 경우에는 기존 `scale` 기반 확대와 충돌하지 않도록 `scale: 0`을 사용해 upstream 자동 크기 결정을 따른다.
- 캐시 재사용으로 이전 렌더 결과가 섞이지 않도록 thumbnail render signature의 maxDimension 정책 버전을 갱신한다.

## 산출물

| 파일 | 변경 내용 |
| --- | --- |
| `Sources/Shared/HwpPageImageRenderer.swift` | Skia render attempt에 `maxDimension` 전달, `maxDimension > 0`이면 Rust bridge 호출 시 `scale: 0` 사용, `maximumPixelSize`의 긴 변을 안전한 정수 maxDimension으로 변환하는 helper 추가 |
| `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | `maxDimensionPolicyVersion`을 `skia-max-dimension-thumbnail-v1`로 갱신 |

변경 범위는 `git diff --stat` 기준 2개 파일, 19 insertions, 5 deletions이다.

## 구현 내용

- `HwpPageImageRenderer.renderPage`의 `.skiaOptIn` 분기에서 `skiaMaxDimension(from: maximumPixelSize)` 값을 `renderSkiaPage`에 전달했다.
- `renderSkiaPage`는 `maxDimension > 0`일 때 `document.renderPagePNG(at:scale:maxDimension:)`에 `scale: 0`과 실제 `maxDimension`을 넘긴다.
- `maxDimension == 0`인 호출은 기존 동작 보존을 위해 `scale: Double(scale)`, `maxDimension: 0`을 유지한다.
- `skiaMaxDimension(from:)` helper는 nil, non-finite, 0 이하 입력을 `0`으로 처리하고, 유효한 입력은 긴 변을 `ceil`한 뒤 `Int32.max`로 상한 처리한다.
- thumbnail cache signature suffix를 `skia-max-dimension-thumbnail-v1`로 변경해 기존 `skia-max-dimension-0` 결과와 캐시 키가 분리되도록 했다.

## Stage 1 대비 smoke 결과

Stage 3 smoke 명령:

```sh
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-stage3-thumbnail-policy samples/basic/request.hwp samples/basic/KTX.hwp
```

요약:

| 샘플 | 정책 | Stage 1 Pixel | Stage 3 Pixel | 해석 |
| --- | --- | --- | --- | --- |
| `request.hwp` | `coreGraphicsOnly` | `732x1024` | `732x1024` | CoreGraphics 경로 변화 없음 |
| `request.hwp` | `skiaOptIn` | `732x1025` | `567x794` | 1024px 초과는 사라졌지만 upstream Skia가 자연 해상도 이상으로 확대하지 않는 동작이 관찰됨 |
| `KTX.hwp` | `coreGraphicsOnly` | `1024x725` | `1024x725` | CoreGraphics 경로 변화 없음 |
| `KTX.hwp` | `skiaOptIn` | `1025x725` | `1024x725` | 긴 변 1024px 상한에 맞게 조정됨 |

캐시와 signature:

- resolver contract: 모든 case `OK`
- render rows: 16건 모두 `OK`
- fallback: 0건
- 캐시 패턴: 각 정책에서 `miss`, `exactHit`, `largerBucketHit(1024x1024)`, `largerBucketHit(1024x1024)`
- signature suffix: `skia-max-dimension-thumbnail-v1`

## 검증

| 명령 | 결과 |
| --- | --- |
| `git diff --check` | 성공 |
| `./scripts/check-no-appkit.sh` | 성공 |
| `./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-stage3-thumbnail-policy samples/basic/request.hwp samples/basic/KTX.hwp` | 성공. resolver `OK`, renders 16건 `OK`, fallback 없음 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask392Stage3 CODE_SIGNING_ALLOWED=NO build` | 성공. CoreSimulator out-of-date 경고는 있었지만 `BUILD SUCCEEDED`로 종료 |

## 잔여 위험과 다음 단계

- `request.hwp`의 Skia 결과가 `567x794`로 낮아진 것은 실패는 아니지만, thumbnail 품질 관점에서는 판단이 필요하다. upstream Skia `maxDimension` 경로가 자연 해상도 이상 확대하지 않는 동작으로 보인다.
- 이번 단계는 빠른 샘플 2개만 검증했다. Stage 4에서 대표 샘플 smoke와 pixel/cache/signature 결과를 더 넓게 확인해야 한다.
- signature suffix는 backend policy와 함께 캐시 키에 포함되므로 CoreGraphics와 Skia는 계속 분리된다. 다만 suffix 자체가 공통 필드라 기존 CoreGraphics thumbnail cache도 함께 무효화된다.

## 승인 요청

Stage 4에서는 대표 샘플로 확장 smoke를 수행하고, `maxDimension` 경로를 유지할지 또는 보완 이슈가 필요한지 판단한다.
