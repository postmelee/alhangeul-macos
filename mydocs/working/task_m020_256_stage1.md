# Task M020 #256 Stage 1 보고서

## 단계 목표

Swift wrapper와 Shared renderer contract inventory를 수행해 Stage 2-3에서 구현할 타입, API, fallback mapping을 확정한다. 이 단계에서는 Swift source를 변경하지 않는다.

## 확인한 현재 상태

| 영역 | 확인 결과 |
|---|---|
| core provenance | `rhwp-core.lock`은 `rhwp v0.7.12`, commit `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5`, `rhwp_enabled_features = "native-skia"` 기준이다. |
| FFI symbol | `rhwp-ffi-symbols.txt`에 `rhwp_render_page_png`가 포함되어 있다. |
| Rust ABI | `rhwp_render_page_png(handle,page,scale,max_dimension,out_data,out_len) -> RhwpRenderStatus` 형태다. 성공 시 Rust-owned PNG buffer를 반환하고, Swift는 `rhwp_free_bytes`로 해제해야 한다. |
| status taxonomy | `RHWP_RENDER_OK`, `INVALID_HANDLE`, `INVALID_OUTPUT`, `INVALID_PAGE_INDEX`, `INVALID_OPTIONS`, `FAILURE` 6개 값이다. |
| Swift bridge | `RhwpDocument`는 `rhwp_free_string`, `rhwp_free_bytes` 해제 패턴을 이미 갖고 있다. AppKit/UIKit import는 없다. |
| Shared renderer | `HwpRenderedPage`는 현재 `image`, `size`만 가진다. `HwpPageImageRenderer.renderPage`는 render tree + `CGTreeRenderer` 경로만 수행한다. |
| 호출부 | `HwpPreviewProvider`, `HwpPreviewPDFRenderer`, `HwpThumbnailRenderCache`가 `renderPage` 또는 `renderFirstPage`를 호출한다. |

## 확정 Contract

Stage 2-3에서 다음 타입 의미를 구현한다. 타입명은 아래 후보를 우선하되, 실제 Swift 스타일에 맞게 파일 내 선언 순서는 조정할 수 있다.

| 타입 | 후보 값/필드 | 의미 |
|---|---|---|
| `HwpPageRenderBackend` | `.coreGraphics`, `.skia` | 최종 산출물에 실제 사용된 backend |
| `HwpPageRenderPolicy` | `.coreGraphicsOnly`, `.skiaOptIn` | renderer 선택 정책 |
| `HwpPageRenderFallbackReason` | 아래 mapping 표 참조 | Skia 시도 후 fallback한 이유 |
| `HwpPageRenderDuration` | `skiaRenderMs`, `pngDecodeMs`, `coreGraphicsRenderMs`, `totalMs` | 가능한 구간별 측정값 |
| `HwpPageRenderDiagnostics` | `policy`, `backendUsed`, `fallbackReason`, `pageSize`, `pixelSize`, `pngBytes`, `durationMs` | 후속 #257/#258 로그와 cache 판단에 넘길 진단 |

`HwpRenderedPage`는 다음 형태로 확장한다.

```swift
struct HwpRenderedPage: @unchecked Sendable {
    let image: CGImage
    let size: CGSize
    let diagnostics: HwpPageRenderDiagnostics
}
```

기존 호출부 호환을 위해 `diagnostics`는 initializer 기본값 또는 `HwpPageRenderDiagnostics.coreGraphicsDefault(...)` helper로 채운다. `HwpRenderedPage(image:size:)` 호출부가 현재 2곳 있으므로 Stage 3에서 모두 compile-safe하게 갱신한다.

## Swift Wrapper 설계

`RhwpDocument`에는 다음 의미의 wrapper를 추가한다.

```swift
struct RhwpRenderedPNG {
    let data: Data
    let status: RhwpRenderStatus
}

func renderPagePNG(
    at page: Int,
    scale: Double = 0,
    maxDimension: Int = 0
) -> RhwpRenderedPNG
```

세부 정책:

- Swift wrapper는 page range를 중복 검증하지 않고 ABI status를 보존한다. 단, 음수 page는 `invalidPageIndex`에 해당하는 Swift-side failure로 처리한다.
- `scale`은 finite이고 0 이상이어야 한다. `maxDimension`은 0 이상이어야 한다.
- 성공 status라도 pointer nil 또는 length 0이면 Stage 3에서 `skiaRenderFailure`로 취급한다.
- 반환 pointer가 있으면 `Data(bytes:count:)`로 즉시 복사하고 `defer`에서 `rhwp_free_bytes(ptr, len)`를 호출한다.
- `Sources/RhwpCoreBridge`에는 Foundation/Rhwp 외 UI framework를 추가하지 않는다.

Swift enum 이름 충돌을 피하기 위해 C enum `RhwpRenderStatus` 자체를 직접 외부 contract로 노출하기보다, wrapper 결과에서 status를 받고 Stage 3에서 Shared fallback reason으로 매핑한다.

## Fallback Mapping

| ABI/Swift 조건 | Shared fallback reason | 처리 |
|---|---|---|
| C ABI symbol/wrapper 부재에 준하는 상태 | `ffiUnavailable` | 현재 link 기준에서는 예상하지 않지만 taxonomy는 유지 |
| `RHWP_RENDER_INVALID_HANDLE` | `invalidDocumentHandle` | CoreGraphics fallback 시도 |
| Swift 음수 page 또는 `RHWP_RENDER_INVALID_PAGE_INDEX` | `invalidPageIndex` | 기존 `pageOutOfRange`와 같은 입력 오류 성격. Stage 3에서는 기존 guard를 우선 유지 |
| `RHWP_RENDER_INVALID_OUTPUT` | `ffiUnavailable` | CoreGraphics fallback 시도 |
| `RHWP_RENDER_INVALID_OPTIONS` | `invalidRenderOptions` | CoreGraphics fallback 시도 |
| `RHWP_RENDER_FAILURE` | `skiaRenderFailure` | CoreGraphics fallback 시도 |
| OK + nil/0 bytes | `skiaRenderFailure` | CoreGraphics fallback 시도 |
| OK + bytes but `CGImageSource`/`CGImage` decode 실패 | `pngDecodeFailure` | CoreGraphics fallback 시도 |
| page size non-positive/non-finite | `invalidPageSize` | Skia 우회가 아니라 기존 입력 오류로 처리 |
| timeout/memory pressure | `memoryTimeoutFallback` | 이번 이슈에서는 예약 taxonomy만 유지 |

`coreGraphicsFallbackFailure`는 Stage 3에서 별도 reason으로 `HwpRenderedPage`에 남길 수 없다. CoreGraphics fallback도 실패하면 기존 error를 throw해 `HwpDocumentFallbackClassifier`가 처리한다.

## Backend Policy와 Scale 정책

기본 API:

```swift
static func renderPage(
    document: RhwpDocument,
    pageIndex: Int,
    maximumPixelSize: CGSize? = nil,
    policy: HwpPageRenderPolicy = .coreGraphicsOnly
) throws -> HwpRenderedPage
```

`renderFirstPage`도 같은 `policy` 기본 인자를 추가한다. 기존 호출부는 인자를 전달하지 않으므로 기본 CoreGraphics 동작을 유지한다.

초기 Skia option mapping:

- `renderScale(pageSize:maximumPixelSize:)`를 그대로 계산한다.
- `scale`은 계산된 `renderScale`을 전달한다. 값이 1이면 명시 scale 1을 넘길 수 있다.
- `max_dimension`은 Stage 3에서는 기본 0으로 둔다. Thumbnail의 pixel bucket 기반 `max_dimension` 정책은 #258에서 cache key와 함께 확정한다.
- page size와 pixel size는 diagnostics에 모두 남긴다.

이 정책은 #258의 `maximumPixelSize -> max_dimension` 전환 여지를 남기기 위한 보수안이다.

## 호출부 영향

| 호출부 | Stage 3 영향 |
|---|---|
| `HwpPreviewProvider.pngReply` | 기본 인자 유지로 CoreGraphics. #257에서 `skiaOptIn` 전달 후보 |
| `HwpPreviewPDFRenderer.render` | 기본 인자 유지로 CoreGraphics. 다중 page Skia 적용은 #257 판단 |
| `HwpThumbnailRenderCache.renderedPage` | 기본 인자 유지로 CoreGraphics. #258에서 policy와 cache key 확장 |
| `HwpThumbnailRenderCache` cache value | `HwpRenderedPage`에 diagnostics가 추가되어도 cache key는 아직 변경하지 않는다 |

## Stage 2-3 작업 지시

Stage 2:

1. `RhwpDocument.swift`에 PNG wrapper와 Swift-side status helper를 추가한다.
2. wrapper는 `Data` 복사와 `rhwp_free_bytes` 해제를 보장한다.
3. `check-no-appkit.sh`를 실행한다.

Stage 3:

1. `HwpPageImageRenderer.swift`에 backend/policy/fallback/diagnostics 타입을 추가한다.
2. CoreGraphics render 본문을 private helper로 분리한다.
3. `skiaOptIn` 경로에서 Skia render, PNG decode, CoreGraphics fallback을 순서대로 수행한다.
4. 기존 API 호출부는 default policy로 compile 호환시킨다.

## 검증 결과

실행 명령:

```bash
rg -n "rhwp_render_page_png|RhwpRenderStatus|rhwp_free_bytes|HwpRenderedPage|HwpPageImageRenderer|renderPage\(" \
  Sources RustBridge rhwp-ffi-symbols.txt rhwp-core.lock
rg -n "backendUsed|fallbackReason|pngBytes|durationMs|coreGraphicsOnly|skiaOptIn" \
  mydocs/plans/task_m020_256.md mydocs/plans/task_m020_256_impl.md mydocs/working/task_m020_256_stage1.md
git diff --check
```

결과: 통과.

## 변경 파일

| 파일 | 내용 |
|---|---|
| `mydocs/working/task_m020_256_stage1.md` | Stage 1 inventory와 contract 확정 기록 |
| `mydocs/orders/20260519.md` | #256 상태를 Stage 1 완료 후 승인 대기로 갱신 |

## 잔여 리스크

- `Frameworks/`는 이 worktree에 아직 생성되어 있지 않다. Stage 2 또는 Stage 3 compile 검증 전에 `./scripts/build-rust-macos.sh`가 필요할 수 있다.
- `RhwpRenderStatus` Swift import의 enum case 표기 방식은 generated header 기준 compile에서 최종 확인해야 한다.
- `max_dimension`을 Stage 3에서 0으로 두면 Thumbnail용 pixel bucket 최적화는 #258까지 남는다.
- Skia 성공/실패 smoke는 Stage 4에서 실제 산출물로 확인해야 한다.

## 승인 요청

Stage 1을 완료한다. 승인 후 Stage 2 `RhwpDocument` Skia PNG wrapper 추가로 진행한다.
