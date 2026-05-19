# Task M020 #256 최종 보고서

## 작업 개요

- 이슈: #256 Shared HwpPageImageRenderer에 Skia optional backend와 CoreGraphics fallback 추가
- 마일스톤: M020 `v0.2.x Skia Quick Look/Thumbnail Backend`
- 브랜치: `local/task256`
- 목표: Swift bridge와 Shared renderer에 Skia PNG backend를 선택적으로 호출할 수 있는 경로를 추가하고, 실패 시 기존 CoreGraphics render tree 경로로 fallback하는 contract를 구현한다.

## 완료 범위

- `rhwp_render_page_png` C ABI를 Swift에서 안전하게 호출하는 `RhwpDocument.renderPagePNG(at:scale:maxDimension:)` wrapper를 추가했다.
- `HwpPageImageRenderer`에 `coreGraphicsOnly`와 `skiaOptIn` 정책을 추가했다.
- `skiaOptIn`에서는 Skia PNG render를 먼저 시도하고, status failure, empty bytes, PNG decode failure 시 기존 CoreGraphics 경로로 fallback한다.
- `HwpRenderedPage`에 `HwpPageRenderDiagnostics`를 추가해 후속 #257/#258이 `backendUsed`, `fallbackReason`, `pngBytes`, `durationMs`를 읽을 수 있게 했다.
- 기존 Quick Look/Thumbnail/PDF 호출부는 기본 인자 때문에 여전히 `coreGraphicsOnly`로 동작한다.
- 대표 샘플에서 CoreGraphics smoke와 Skia opt-in 비교 smoke를 수행했다.

## 단계별 결과

| 단계 | 산출물 | 요약 |
|---|---|---|
| Stage 1 | `mydocs/working/task_m020_256_stage1.md` | Swift wrapper와 Shared renderer contract, fallback taxonomy, scale 정책 확정 |
| Stage 2 | `Sources/RhwpCoreBridge/RhwpDocument.swift`, `mydocs/working/task_m020_256_stage2.md` | `RhwpPagePNGStatus`, `RhwpRenderedPNG`, `renderPagePNG` wrapper 추가 |
| Stage 3 | `Sources/Shared/HwpPageImageRenderer.swift`, `mydocs/working/task_m020_256_stage3.md` | backend/policy/diagnostics 타입과 Skia opt-in + CoreGraphics fallback 구현 |
| Stage 4 | `mydocs/working/task_m020_256_stage4.md` | CoreGraphics smoke, Skia/CoreGraphics 산출 비교, runtime diagnostics 기록 |
| Stage 5 | `mydocs/report/task_m020_256_report.md` | 최종 contract, 검증 결과, 후속 handoff 정리 |

## 최종 API Contract

`RhwpDocument` wrapper:

```swift
func renderPagePNG(
    at page: Int,
    scale: Double = 0,
    maxDimension: Int = 0
) -> RhwpRenderedPNG
```

Shared renderer policy:

```swift
static func renderPage(
    document: RhwpDocument,
    pageIndex: Int,
    maximumPixelSize: CGSize? = nil,
    policy: HwpPageRenderPolicy = .coreGraphicsOnly
) throws -> HwpRenderedPage
```

`renderFirstPage(fileURL:maximumPixelSize:embeddedThumbnailPolicy:policy:)`도 같은 정책 인자를 받는다. 기본값은 `.coreGraphicsOnly`이다.

## Backend 정책

| policy | 동작 |
|---|---|
| `.coreGraphicsOnly` | Skia를 시도하지 않고 기존 render tree + `CGTreeRenderer` 경로만 사용 |
| `.skiaOptIn` | Skia PNG render를 먼저 시도하고, 실패하면 기존 CoreGraphics 경로로 fallback |

중요한 결론:

- 현재 기본 제품 동작은 Skia 우선이 아니다.
- Skia 우선 + CoreGraphics fallback은 `policy: .skiaOptIn`을 명시한 호출에서만 동작한다.
- Quick Look preview, 다중 page PDF, Finder thumbnail 기본 호출부는 아직 사용자-facing backend 정책을 바꾸지 않았다.

## Diagnostics

`HwpRenderedPage.diagnostics`는 다음 필드를 제공한다.

| 필드 | 의미 |
|---|---|
| `policy` | 호출자가 요청한 정책 |
| `backendUsed` | 최종 반환 이미지에 실제 사용된 backend |
| `fallbackReason` | Skia를 시도한 뒤 CoreGraphics로 넘어간 이유. fallback이 없으면 nil |
| `pageSize` | 문서 page point size |
| `pixelSize` | 반환 `CGImage` pixel size |
| `pngBytes` | Skia PNG bytes를 받은 경우 byte count |
| `durationMs` | Skia render, PNG decode, CoreGraphics render, total duration |

## Fallback Matrix

| 조건 | `fallbackReason` | 처리 |
|---|---|---|
| `.invalidHandle` | `.invalidDocumentHandle` | CoreGraphics fallback |
| `.invalidOutput` | `.ffiUnavailable` | CoreGraphics fallback |
| `.invalidPageIndex` | `.invalidPageIndex` | CoreGraphics fallback. 일반 호출은 사전 page range guard가 우선 |
| `.invalidOptions` | `.invalidRenderOptions` | CoreGraphics fallback |
| `.failure` | `.skiaRenderFailure` | CoreGraphics fallback |
| `.ok` + empty bytes | `.skiaRenderFailure` | CoreGraphics fallback |
| ImageIO source/image decode 실패 | `.pngDecodeFailure` | CoreGraphics fallback |
| page size non-positive/non-finite | 해당 없음 | 기존 `HwpRenderError.invalidPageSize` throw |

CoreGraphics fallback 자체가 실패하면 기존 `HwpRenderError`를 그대로 throw한다. 반환할 `HwpRenderedPage`가 없으므로 별도 fallback diagnostics는 남기지 않는다.

## Smoke 결과

### CoreGraphics 기본 smoke

```bash
./scripts/validate-stage3-render.sh output/task256-stage4 samples/basic/KTX.hwp samples/basic/request.hwp
```

결과:

| 샘플 | pixels | text runs | Hangul runs | non-white pixels | 결과 |
|---|---:|---:|---:|---:|---|
| `KTX.hwp` | 1123x794 | 437 | 77 | 453754 | 통과 |
| `request.hwp` | 567x794 | 105 | 37 | 69132 | 통과 |

`KTX.hwp`에서는 기존 upstream layout overflow diagnostic이 출력됐지만 smoke 자체는 통과했다.

### Skia/CoreGraphics 비교 smoke

| 샘플 | CG pixels | CG PNG | CG non-white | Skia backend | fallback | Skia raw PNG | Skia encoded PNG | Skia non-white | byte delta | non-white delta | duration |
|---|---:|---:|---:|---|---|---:|---:|---:|---:|---:|---|
| `KTX.hwp` | 1123x794 | 555392 | 453754 | `skia` | nil | 165799 | 181146 | 237867 | 374246 | 215887 | skia 66.536 ms, decode 1.097 ms, total 67.633 ms |
| `request.hwp` | 567x794 | 82129 | 69132 | `skia` | nil | 88793 | 85981 | 72014 | 3852 | 2882 | skia 60.485 ms, decode 0.076 ms, total 60.561 ms |

두 대표 샘플 모두 `skiaOptIn`에서 fallback 없이 `backendUsed: .skia`, `fallbackReason: nil`로 성공했다.

### 추가 샘플 확인

사용자 요청으로 `samples/복학원서.hwp`도 같은 임시 smoke로 확인했다.

| 샘플 | pixels | Skia backend | fallback | Skia raw PNG | Skia encoded PNG | Skia non-white | duration |
|---|---:|---|---|---:|---:|---:|---|
| `복학원서.hwp` | 794x1123 | `skia` | nil | 240643 | 225105 | 168092 | skia 63.657 ms, decode 0.077 ms, total 63.733 ms |

산출물은 `output/task256-stage4-extra/bokhakwonseo-skia-opt-in.png`에 생성했다. `output/`은 commit 대상이 아니다.

## 최종 검증

Stage 5에서 다음 최종 검증을 다시 실행했다.

```bash
./scripts/check-no-appkit.sh
rg -n "coreGraphicsOnly|skiaOptIn|backendUsed|fallbackReason|pngBytes|durationMs|#257|#258" \
  Sources mydocs/report/task_m020_256_report.md mydocs/orders/20260520.md
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask256 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask256 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask256 CODE_SIGNING_ALLOWED=NO build
git diff --check
git status --short --branch
```

결과:

| 명령 | 결과 |
|---|---|
| `./scripts/check-no-appkit.sh` | 통과: `OK: shared Swift code has no AppKit/UIKit dependencies` |
| `rg -n "coreGraphicsOnly\|skiaOptIn\|backendUsed\|fallbackReason\|pngBytes\|durationMs\|#257\|#258" ...` | 통과: source, 최종 보고서, 오늘할일 연결 확인 |
| `xcodebuild ... -scheme HostApp ... build` | 통과: `** BUILD SUCCEEDED ** [0.710 sec]` |
| `xcodebuild ... -scheme QLExtension ... build` | 통과: `** BUILD SUCCEEDED ** [0.321 sec]` |
| `xcodebuild ... -scheme ThumbnailExtension ... build` | 통과: `** BUILD SUCCEEDED ** [0.447 sec]` |
| `git diff --check` | 통과 |

## #257 Handoff

#257 Quick Look 적용에서 사용할 조건:

- 단일 page PNG reply가 `HwpPageImageRenderer.renderPage(..., policy: .skiaOptIn)`을 명시 전달할 수 있다.
- 다중 page PDF path는 기본 유지 또는 별도 opt-in 판단이 필요하다. 현재 contract는 page 단위로 `skiaOptIn`을 받을 수 있다.
- Quick Look logging은 `page.diagnostics.backendUsed`, `fallbackReason`, `pngBytes`, `durationMs`를 기록하면 된다.
- Skia failure가 발생해도 Shared renderer가 CoreGraphics fallback을 먼저 수행하므로, Quick Look text fallback으로 바로 내려가지 않는다.

## #258 Handoff

#258 Thumbnail 적용에서 사용할 조건:

- Thumbnail cache key는 backend 정책과 render option signature를 포함하도록 확장해야 한다.
- 현재 #256은 `maximumPixelSize`를 Skia `scale`로 전달하고 `maxDimension`은 0으로 둔다.
- Thumbnail용 pixel bucket과 `max_dimension` 변환은 #258에서 cache key와 함께 확정한다.
- Thumbnail logging/cache value는 `HwpRenderedPage.diagnostics`를 그대로 읽을 수 있다.

## #259 Handoff

#259 readiness gate에서 볼 항목:

- Skia/CoreGraphics visual diff와 font fallback 차이
- latency, first-call cost, memory pressure
- package size 영향
- Skia default 또는 Skia first 전환 여부

이번 #256 결과만으로 default 전환을 결정하지 않는다.

## 잔여 리스크

- `KTX.hwp`는 Skia와 CoreGraphics의 non-white pixel 차이가 크다. visual diff triage는 #259 범위다.
- fallback 강제 실패 path는 runtime smoke에서 발생하지 않았다. mapping은 source와 Stage 보고서에 고정했다.
- PR 게시 중 `origin/devel`의 #274 merge 이후 GitHub가 conflict를 보고해 `origin/devel`을 병합했다. 충돌은 `mydocs/orders/20260519.md` 한 곳이었고, #274 완료 기록과 #256 Stage 3 대기 기록을 모두 보존해 해결했다.
- `Frameworks/`, `build.noindex/`, `output/`은 로컬 검증 산출물이며 commit하지 않는다.

## 결론

#256은 Shared renderer에 Skia optional backend와 CoreGraphics fallback contract를 구현했다. 기본 제품 동작은 `coreGraphicsOnly`로 유지했고, `skiaOptIn`을 명시한 경우에만 Skia 우선 + CoreGraphics fallback이 동작한다.

후속 #257/#258은 이 contract를 사용해 Quick Look/Thumbnail surface에서 opt-in 적용과 logging/cache 정책을 연결하면 된다.
