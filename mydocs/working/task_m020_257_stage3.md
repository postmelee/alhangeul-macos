# Task M020 #257 Stage 3 보고서 - Quick Look PDF Skia opt-in 경로 연결

## 단계 개요

- 이슈: #257 Quick Look preview에서 Skia PNG backend 적용과 다중 페이지 PDF fallback 검증
- 단계: Stage 3. 다중 페이지 PDF Skia opt-in 경로 연결
- 목표: `HwpPreviewPDFRenderer`가 page render policy를 받을 수 있게 하고, Quick Look 다중 페이지 PDF path가 Skia opt-in page image를 사용할 수 있게 한다.

## 변경 내용

### PDF renderer policy 인자 추가

`Sources/Shared/HwpPreviewPDFRenderer.swift`의 render API에 `policy: HwpPageRenderPolicy = .coreGraphicsOnly` 기본 인자를 추가했다.

대상 API:

- `render(fileURL:policy:)`
- `render(context:policy:)`
- `render(previewInfo:policy:)`
- `render(document:pageCount:contentSize:policy:)`

기본값은 모두 `.coreGraphicsOnly`라 기존 script, HostApp PDF export, legacy helper 호출은 기존 동작을 유지한다.

### Page diagnostics 수집

`HwpRenderedPreviewPDF`에 `pageDiagnostics`를 추가하고, page별 `HwpRenderedPage.diagnostics`를 `HwpPreviewPDFPageDiagnostics`로 수집하도록 했다.

수집 필드:

| 필드 | 의미 |
|---|---|
| `pageIndex` | PDF에 삽입한 page index |
| `diagnostics.policy` | page render policy |
| `diagnostics.backendUsed` | 실제 page image backend |
| `diagnostics.fallbackReason` | Skia 실패 후 CoreGraphics fallback 이유 |
| `diagnostics.pngBytes` | Skia PNG byte count |
| `diagnostics.durationMs` | page별 render/decode/fallback 시간 |

### Quick Look PDF path Skia opt-in

`Sources/QLExtension/HwpPreviewProvider.swift`의 `pdfReply(_:)`에서 다음처럼 policy를 명시한다.

```swift
let result = try HwpPreviewPDFRenderer.render(
    context: documentContext,
    policy: .skiaOptIn
)
```

다중 페이지 PDF도 page별로 Skia PNG render를 먼저 시도하고, 실패 시 Shared renderer의 CoreGraphics fallback image를 PDF page에 삽입한다.

### PDF diagnostics summary logging

Quick Look provider에 `logPDFDiagnostics` helper를 추가해 PDF result의 page diagnostics를 요약한다.

로그 필드:

| 필드 | 의미 |
|---|---|
| `pages` | PDF page count |
| `skiaPages` | Skia backend로 성공한 page 수 |
| `coreGraphicsPages` | CoreGraphics backend로 반환된 page 수 |
| `embeddedThumbnailPages` | embedded thumbnail backend page 수 |
| `fallbackPages` | fallback reason이 있는 page 수 |
| `pngBytes` | page별 Skia PNG byte count 합계 |
| `totalRenderMs` | page별 render duration 합계 |

## 보존한 범위

- HostApp의 `HwpPreviewPDFRenderer.render(document:pageCount:contentSize:)` 호출은 기본값 때문에 계속 CoreGraphics path를 사용한다.
- `scripts/quicklook_pdf_renderer_compare.swift`의 `render(previewInfo:)` 호출도 기본값 때문에 기존 CoreGraphics PDF 비교 path를 유지한다.
- Quick Look text fallback classifier 흐름은 변경하지 않았다.
- Finder thumbnail path는 변경하지 않았다.
- vector PDF export 개선은 포함하지 않았다.

## 검증

실행:

```bash
./scripts/check-no-appkit.sh
rg -n "policy: HwpPageRenderPolicy|skiaOptIn|backendUsed|fallbackReason|pageDiagnostics|HwpRenderedPreviewPDF" \
  Sources/Shared Sources/QLExtension scripts
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataTask257 CODE_SIGNING_ALLOWED=NO build
git diff --check
```

결과:

- `check-no-appkit.sh`: 통과.
- `rg`: PDF renderer policy 기본 인자, Quick Look `skiaOptIn` 명시, page diagnostics 수집, PDF summary logging을 확인했다.
- `xcodebuild QLExtension Debug`: 최초 sandbox 실행은 사용자 Swift/clang cache 쓰기 제한으로 실패했다. 동일 명령을 sandbox 밖에서 재실행해 통과했다.
- `xcodebuild HostApp Debug`: 최초 sandbox 실행은 사용자 Swift/clang cache 쓰기 제한으로 실패했다. 동일 명령을 sandbox 밖에서 재실행해 통과했다.
- `git diff --check`: 통과.

## 리스크와 후속

- 다중 페이지 PDF는 page별 Skia PNG render와 decode를 반복하므로 latency와 PDF 생성 시간이 늘 수 있다. 실제 샘플 측정은 Stage 4에서 기록한다.
- `scripts/quicklook_pdf_renderer_compare.swift`는 기본값으로 CoreGraphics PDF path를 유지한다. Skia PDF path 비교가 필요하면 Stage 4에서 task 전용 helper 또는 명시 policy 옵션을 추가할지 판단한다.
- Skia default 전환 여부는 #259 readiness gate에서 판단한다.

## 다음 단계 승인 요청

Stage 4에서 대표 샘플로 Quick Look 단일 PNG와 다중 PDF path의 Skia opt-in 결과, fallback 결과, latency/byte 정보를 기록한다.
