# Task M020 #256 Stage 3 보고서

## 단계 목표

`HwpPageImageRenderer`에 `coreGraphicsOnly` 기본 정책과 `skiaOptIn` 선택 정책을 추가하고, Skia PNG render 또는 decode 실패 시 기존 CoreGraphics 경로로 fallback하도록 만든다.

## 변경 요약

| 파일 | 내용 |
|---|---|
| `Sources/Shared/HwpPageImageRenderer.swift` | backend/policy/fallback/diagnostics 타입 추가, `HwpRenderedPage` diagnostics 확장, Skia opt-in 경로와 CoreGraphics fallback helper 구현 |
| `mydocs/orders/20260519.md` | #256 상태를 Stage 3 완료 후 승인 대기로 갱신 |

## 구현 내용

### Backend contract

Stage 1에서 확정한 Shared renderer contract를 source에 추가했다.

| 타입 | 값/필드 |
|---|---|
| `HwpPageRenderBackend` | `.coreGraphics`, `.skia` |
| `HwpPageRenderPolicy` | `.coreGraphicsOnly`, `.skiaOptIn` |
| `HwpPageRenderFallbackReason` | `.ffiUnavailable`, `.invalidDocumentHandle`, `.invalidPageIndex`, `.invalidRenderOptions`, `.invalidPageSize`, `.skiaRenderFailure`, `.pngDecodeFailure`, `.memoryTimeoutFallback` |
| `HwpPageRenderDuration` | `skiaRenderMs`, `pngDecodeMs`, `coreGraphicsRenderMs`, `totalMs` |
| `HwpPageRenderDiagnostics` | `policy`, `backendUsed`, `fallbackReason`, `pageSize`, `pixelSize`, `pngBytes`, `durationMs` |

`HwpRenderedPage`는 `diagnostics`를 포함하도록 확장했다. 기존 `HwpRenderedPage(image:size:)` 호출은 initializer 기본값으로 유지해 compile 호환성을 보존했다.

### Render flow

`renderPage(document:pageIndex:maximumPixelSize:policy:)`는 기존 page range guard와 page size validation을 먼저 수행한다. page size가 non-positive 또는 non-finite이면 기존처럼 `HwpRenderError.invalidPageSize`를 throw한다.

정책별 동작:

| policy | 동작 |
|---|---|
| `.coreGraphicsOnly` | Skia를 시도하지 않고 기존 render tree + `CGTreeRenderer` 경로만 사용 |
| `.skiaOptIn` | `RhwpDocument.renderPagePNG(at:scale:maxDimension:)`를 먼저 호출하고, 성공 시 ImageIO decode 결과를 반환 |

Skia에는 기존 `renderScale(pageSize:maximumPixelSize:)` 값을 `scale`로 전달한다. `maxDimension`은 Stage 1 결정대로 0을 유지했다. Thumbnail pixel bucket과 `maxDimension` 정책은 #258에서 cache key와 함께 확정한다.

### CoreGraphics fallback

기존 CoreGraphics 렌더 본문은 `renderCoreGraphicsPage(...)` helper로 분리했다. Skia 실패 시 같은 helper를 재사용하고, 최종 `HwpRenderedPage.diagnostics`에는 `backendUsed: .coreGraphics`와 Skia 실패 reason을 남긴다.

Fallback mapping:

| 조건 | `fallbackReason` |
|---|---|
| `.invalidHandle` | `.invalidDocumentHandle` |
| `.invalidOutput` | `.ffiUnavailable` |
| `.invalidPageIndex` | `.invalidPageIndex` |
| `.invalidOptions` | `.invalidRenderOptions` |
| `.failure` | `.skiaRenderFailure` |
| `.ok` + empty bytes | `.skiaRenderFailure` |
| ImageIO source/image decode 실패 | `.pngDecodeFailure` |

CoreGraphics fallback 자체가 실패하면 기존 `HwpRenderError`를 그대로 throw한다. 이 경우 반환할 `HwpRenderedPage`가 없으므로 `coreGraphicsFallbackFailure` 별도 reason은 남기지 않는다.

### Diagnostics

Skia 성공 시:

- `policy: .skiaOptIn`
- `backendUsed: .skia`
- `fallbackReason: nil`
- `pngBytes`: Skia PNG byte count
- `durationMs.skiaRenderMs`, `durationMs.pngDecodeMs`, `durationMs.totalMs` 기록

Skia fallback 시:

- `policy: .skiaOptIn`
- `backendUsed: .coreGraphics`
- `fallbackReason`: Skia 실패 reason
- `pngBytes`: Skia bytes를 받은 경우에만 byte count
- `durationMs`: Skia render, PNG decode, CoreGraphics render 시간을 가능한 범위에서 기록

기존 default 호출은 모두 `policy: .coreGraphicsOnly`이므로 사용자-facing Quick Look/Thumbnail 기본 backend는 바꾸지 않았다.

## 검증 결과

### AppKit/UIKit guard

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### contract symbol 확인

```bash
rg -n "coreGraphicsOnly|skiaOptIn|backendUsed|fallbackReason|pngBytes|durationMs|pngDecodeFailure|skiaRenderFailure" Sources
```

결과: `Sources/Shared/HwpPageImageRenderer.swift`에서 새 policy, diagnostics, fallback reason 사용 지점을 확인했다. `Sources/HostApp/Resources/rhwp-studio`의 bundled JS에도 `durationMs` 문자열이 있으나 이번 Swift 변경과 무관하다.

### Xcode project generation

```bash
xcodegen generate
```

결과: 성공. `project.yml` 변경은 없었고, 생성 결과로 tracked diff는 발생하지 않았다.

### HostApp build

첫 sandbox build는 SwiftPM cache 쓰기 권한 때문에 package resolve 단계에서 실패했다.

```text
You don’t have permission to save the file “ManifestLoading” in the folder “manifests”.
```

동일 명령을 승인된 Xcode 실행으로 재시도했다.

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask256 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [4.638 sec]
```

### QLExtension build

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask256 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [0.347 sec]
```

### ThumbnailExtension build

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ThumbnailExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask256 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [1.576 sec]
```

### diff check

```bash
git diff --check
```

결과: 통과.

## 변경 파일

- `Sources/Shared/HwpPageImageRenderer.swift`
- `mydocs/working/task_m020_256_stage3.md`
- `mydocs/orders/20260519.md`

## Stage 4 handoff

Stage 4에서는 대표 샘플에서 `coreGraphicsOnly`와 `skiaOptIn` 산출을 실제로 비교하고, Skia 성공 또는 fallback diagnostics 값을 보고서에 기록한다.

우선 확인할 항목:

- `backendUsed`
- `fallbackReason`
- `pngBytes`
- `durationMs`
- CoreGraphics 기존 smoke 회귀 여부

## 잔여 리스크

- Stage 3은 compile-level 검증까지 수행했다. Skia/CoreGraphics 산출 비교와 대표 샘플 runtime diagnostics 기록은 Stage 4 범위다.
- Embedded thumbnail 경로는 기존 정책을 유지한다. 이 경로는 Skia backend 선택과 별개이며, 현재 default Quick Look/Thumbnail 호출에서는 `.never` 정책으로 사용된다.
- `memoryTimeoutFallback`은 후속 taxonomy 예약값이며, 이번 단계에서 timeout 장치는 추가하지 않았다.

## 승인 요청

Stage 3를 완료한다. 승인 후 Stage 4 렌더 smoke와 Skia/CoreGraphics 산출 비교로 진행한다.
