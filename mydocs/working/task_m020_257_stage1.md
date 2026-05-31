# Task M020 #257 Stage 1 보고서 - Quick Look Skia 적용 범위 확정

## 단계 개요

- 이슈: #257 Quick Look preview에서 Skia PNG backend 적용과 다중 페이지 PDF fallback 검증
- 단계: Stage 1. Quick Look render 호출부 inventory
- 목표: Quick Look 단일 PNG reply, 다중 PDF reply, fallback classifier 흐름을 확인하고 Stage 2-3에서 변경할 API와 logging 범위를 고정한다.

## 확인한 현재 구조

### 단일 페이지 PNG reply

`Sources/QLExtension/HwpPreviewProvider.swift`의 `pngReply(_:)`는 `HwpPreviewPDFRenderer.load(fileURL:)`가 만든 `HwpPreviewDocumentContext`를 받아 첫 페이지를 렌더링한다.

현재 호출은 다음 형태다.

```swift
let page = try HwpPageImageRenderer.renderPage(
    document: documentContext.document,
    pageIndex: 0
)
```

`policy` 기본값 때문에 현재는 `coreGraphicsOnly`로 동작한다. Stage 2에서는 이 호출에 `policy: .skiaOptIn`을 명시한다.

### 다중 페이지 PDF reply

`HwpPreviewProvider.pdfReply(_:)`는 `HwpPreviewPDFRenderer.render(context:)`를 호출한다. `HwpPreviewPDFRenderer.render(document:pageCount:contentSize:)`는 모든 page에 대해 `HwpPageImageRenderer.renderPage(document:pageIndex:)`를 호출한 뒤 `CGContext` PDF page에 bitmap을 삽입한다.

현재 다중 PDF renderer도 `policy` 기본값 때문에 `coreGraphicsOnly`다. Stage 3에서는 render API에 `policy: HwpPageRenderPolicy = .coreGraphicsOnly` 기본 인자를 추가해 기존 helper/script 호환성을 유지하고, Quick Look provider에서 `policy: .skiaOptIn`을 명시한다.

### Shared renderer contract

#256 결과로 `HwpPageImageRenderer.renderPage`는 이미 다음 contract를 제공한다.

| 항목 | 현재 타입/필드 | #257 사용 |
|---|---|---|
| policy | `HwpPageRenderPolicy.coreGraphicsOnly`, `.skiaOptIn` | Quick Look provider가 명시 전달 |
| backend | `HwpPageRenderBackend.coreGraphics`, `.skia`, `.embeddedThumbnail` | Quick Look 로그와 보고서에서 사용 |
| fallback | `HwpPageRenderFallbackReason` | Skia 실패 후 CoreGraphics fallback 원인 기록 |
| diagnostics | `HwpRenderedPage.diagnostics` | `backendUsed`, `fallbackReason`, `pngBytes`, `durationMs`, `pixelSize` 기록 |

`skiaOptIn`에서 Skia PNG render가 실패하거나 PNG decode가 실패하면 Shared renderer가 CoreGraphics fallback을 수행한다. 따라서 Quick Look provider는 별도 Skia error UI를 만들지 않고 기존 fallback classifier를 유지하면 된다.

## 확정한 구현 방향

1. `HwpPreviewProvider.pngReply(_:)`
   - `HwpPageImageRenderer.renderPage(..., policy: .skiaOptIn)`을 명시한다.
   - `page.diagnostics`를 읽어 `backendUsed`, `fallbackReason`, `pngBytes`, `durationMs.totalMs`, `pixelSize`를 로그에 남긴다.
   - 반환 형식은 기존과 동일하게 `.png` reply를 유지한다.

2. `HwpPreviewPDFRenderer`
   - `HwpRenderedPreviewPDF`에 page별 diagnostics summary를 추가한다.
   - `render(context:)`, `render(previewInfo:)`, `render(document:pageCount:contentSize:)`에 `policy` 기본 인자를 추가한다.
   - 내부 page loop에서 `HwpPageImageRenderer.renderPage(..., policy: policy)`를 호출한다.
   - 기존 scripts와 helper는 기본값으로 계속 `coreGraphicsOnly`를 사용하므로 compile/runtime 호환을 유지한다.

3. `HwpPreviewProvider.pdfReply(_:)`
   - `HwpPreviewPDFRenderer.render(context:policy: .skiaOptIn)`을 호출한다.
   - PDF result의 page diagnostics를 요약해 backend별 page 수, fallback page 수, PDF bytes를 로그에 남긴다.

4. fallback 정책
   - file size guard, empty document, invalid first page size는 기존 `HwpPreviewPDFRenderer.load`에서 유지한다.
   - Shared renderer까지 도달한 Skia 실패는 CoreGraphics fallback을 우선한다.
   - CoreGraphics fallback까지 실패하면 기존 `HwpDocumentFallbackClassifier`와 text reply 흐름을 유지한다.

## 검증 후보

Stage 2:

```bash
./scripts/check-no-appkit.sh
rg -n "skiaOptIn|backendUsed|fallbackReason|pngBytes|durationMs|Preview PNG" Sources/QLExtension Sources/Shared
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

Stage 3:

```bash
./scripts/check-no-appkit.sh
rg -n "policy: HwpPageRenderPolicy|skiaOptIn|backendUsed|fallbackReason|pageDiagnostics|HwpRenderedPreviewPDF" \
  Sources/Shared Sources/QLExtension scripts
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

Stage 4:

```bash
./scripts/validate-stage3-render.sh output/task257-stage4 samples/basic/request.hwp samples/basic/KTX.hwp
./scripts/compare-quicklook-pdf-renderers.sh output/task257-quicklook-pdf samples/hwp-multi-001.hwp samples/hwpx/hwpx-01.hwpx
```

설치본 smoke는 LaunchServices/PlugInKit 캐시 영향을 받으므로 Debug build 검증과 분리해 `smoke-clean-quicklook-install.sh` 결과로 기록한다.

## 리스크와 보류 판단

- 다중 페이지 PDF는 page별 Skia PNG decode를 반복하므로 성능 이득을 단정하지 않는다. #257에서는 Skia opt-in 경로를 연결하고 결과를 기록하되, default 전환 판단은 #259로 넘긴다.
- 단일 페이지 PNG reply도 현재 Shared renderer가 Skia PNG를 `CGImage`로 decode한 뒤 다시 PNG로 encode한다. direct PNG reply 최적화는 #256 contract 밖의 별도 개선 후보로 남긴다.
- 현재 upstream rhwp pin의 PUA/image/watermark 개선 범위는 #278에서 새 release tag 반영 후 재검증한다.

## Stage 1 검증

실행:

```bash
rg -n "HwpPreviewProvider|HwpPreviewPDFRenderer|HwpPageImageRenderer|renderPage\\(|skiaOptIn|backendUsed|fallbackReason|pngBytes|durationMs" \
  Sources/QLExtension Sources/Shared scripts --glob '!**/Resources/**'
rg -n "#257|Stage 1|skiaOptIn|Quick Look|backendUsed|fallbackReason|durationMs" \
  mydocs/plans/task_m020_257_impl.md mydocs/working/task_m020_257_stage1.md mydocs/orders/20260521.md
git diff --check
```

결과:

- Quick Look 단일 PNG와 다중 PDF 호출부가 모두 현재 기본 `coreGraphicsOnly` 경로임을 확인했다.
- #256 diagnostics contract가 Quick Look logging에 필요한 필드를 이미 제공함을 확인했다.
- `HwpPreviewPDFRenderer`에 기본 인자 방식으로 policy를 추가하면 기존 script/helper 호환성을 유지할 수 있음을 확인했다.
- Stage 1에서는 Swift source를 변경하지 않았다.

## 다음 단계 승인 요청

Stage 2에서 `Sources/QLExtension/HwpPreviewProvider.swift`를 변경해 단일 페이지 PNG reply에 `policy: .skiaOptIn`을 명시하고 diagnostics logging을 추가한다.
