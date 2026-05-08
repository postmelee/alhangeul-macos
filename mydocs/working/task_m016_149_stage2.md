# Task M016 #149 Stage 2 보고서

## 단계 목적

Stage 1 inventory 결과를 바탕으로 손상·대용량·미지원 입력의 fallback taxonomy, 사용자 문구, 구현 위치를 확정했다. 이번 단계도 코드 변경 없이 Stage 3/4의 구현 기준을 문서로 고정하는 것이 목적이다.

## 산출물

- `mydocs/working/task_m016_149_stage2.md`: Stage 2 taxonomy와 구현 기준 보고서
- 소스 코드 변경 없음
- 매뉴얼/README 변경 없음

## 본문 변경 정도 / 본문 무손실 여부

제품 소스와 기존 매뉴얼 본문은 변경하지 않았다. 이번 보고서는 Stage 3/4 구현 전에 범위와 판단 기준을 고정하는 신규 단계 문서다.

## 확정 taxonomy

| 분류 | 대표 원인 | HostApp 처리 | Quick Look 처리 | Thumbnail 처리 |
|------|-----------|--------------|-----------------|----------------|
| 빈 문서 | `Data.isEmpty`, `RhwpError.invalidData` | 조기 validation 후 error state 또는 drop banner | plain text fallback | fallback tile |
| 파일 읽기 실패 | `Data(contentsOf:)`, security-scoped URL, resource values 실패 | 파일 접근/읽기 실패 문구 | plain text fallback 또는 provider error 제약 시 fallback 메시지 우선 | fallback tile 우선 |
| 50 MB 초과 | `hwpQuickLookMaxFileSize` 초과 | HostApp hard block 없음 | 기존 plain text fallback 유지 | 기존 fallback tile 유지, full read 전 size check 보강 |
| signature mismatch | HWP CFB magic/HWPX ZIP magic 불일치 | Swift 조기 validation 후보로 구현 | plain text fallback | fallback tile |
| parseFailure | `RhwpError.parseFailure` | WebView document load failure bridge 또는 조기 parser validation 없이 fallback | plain text fallback | fallback tile |
| emptyDocument | `HwpRenderError.emptyDocument` | 해당 없음 | plain text fallback | fallback tile |
| renderTreeUnavailable | `HwpRenderError.renderTreeUnavailable` | 해당 없음 | plain text fallback | fallback tile |
| invalidPageSize | `HwpRenderError.invalidPageSize` | 해당 없음 | plain text fallback | fallback tile |
| bitmap/PDF/PNG encoding failure | `bitmapContextUnavailable`, `imageUnavailable`, `pngEncodingFailed`, `pdfEncodingFailed` | 해당 없음 | "preview를 만들 수 없음" plain text fallback | fallback tile |

## 사용자 문구 기준

### HostApp opening error

- 빈 문서: `비어 있는 문서는 열 수 없습니다.`
- 파일 읽기 실패: `문서를 읽을 수 없습니다. 파일 접근 권한 또는 위치를 확인한 뒤 다시 열어 주세요.`
- signature mismatch: `이 파일은 HWP/HWPX 형식이 아니거나 손상되었습니다.`
- WebView parseFailure bridge: `문서를 열 수 없습니다. HWP/HWPX 형식이 아니거나 파일이 손상되었을 수 있습니다.`

HostApp은 사용자 문구에 byte count, path, internal error domain을 직접 노출하지 않는다. 필요한 진단 값은 `RhwpStudioWebViewFailure.diagnosticDetail` 또는 Stage 보고서 smoke 결과에만 남긴다.

### Quick Look plain text fallback

- 50 MB 초과: 기존 의미를 유지하되 한국어 문구로 정리할 후보는 `이 파일은 50 MB보다 커서 미리보기를 만들지 않습니다.`
- 손상/미지원/빈 문서: `이 파일은 HWP/HWPX 형식이 아니거나 손상되어 미리보기를 만들 수 없습니다.`
- 렌더/인코딩 실패: `이 문서의 미리보기를 만들 수 없습니다. 알한글 앱에서 열어 확인해 주세요.`

Stage 4 구현에서는 `plain text` reply가 Finder에 표시 가능한 최소 fallback이다.

### Thumbnail fallback tile

Thumbnail은 사용자-visible text를 새로 그리지 않고 기존 `drawFallback` tile을 재사용한다. Finder thumbnail의 좁은 화면에서 긴 오류 문구를 그리면 가독성이 낮고, 이미 extension badge가 확장자를 보여주므로 tile fallback만으로 충분하다.

## HostApp validation 기준

HostApp에는 50 MB hard block을 추가하지 않는다. 50 MB 기준은 계속 Quick Look/Thumbnail preview fallback 정책으로 유지한다. WKWebView viewer는 첫 배포의 full app opening 경로이므로, 50 MB 초과를 앱에서 차단하면 preview 제한과 app opening 제한이 섞인다. 대용량 앱 opening 안정성 문제가 Stage 3 smoke에서 확인되면 별도 재승인 범위로 분리한다.

Stage 3의 HostApp 구현 기준:

- `DocumentViewerStore.loadDocument(from:)`에서 파일 읽기 실패와 empty data 메시지를 정리한다.
- `loadDroppedDocument(data:filename:)`도 같은 taxonomy를 사용해 파일 선택과 drop 메시지를 맞춘다.
- HWP/HWPX signature preflight는 Swift store 단계에 둔다.
  - HWP: CFB magic `D0 CF 11 E0 A1 B1 1A E1`
  - HWPX: ZIP magic `PK\x03\x04`, `PK\x05\x06`, `PK\x07\x08`
- signature preflight는 parser correctness를 보장하지 않고, 명백한 non-HWP/HWPX 입력을 빠르게 걸러내는 guard로만 사용한다.
- `parseFailure` 자체를 Swift native parser로 조기 검증하기 위해 `RhwpDocument`를 HostApp opening마다 열지는 않는다. HostApp MVP viewer의 주 parser는 WKWebView `rhwp-studio`이고, native bridge validation을 강제하면 opening cost와 경로 차이가 생긴다.

## WKWebView parse failure bridge 기준

Stage 3에서는 upstream bundled asset을 직접 수정하지 않고 host script injection으로 document load failure를 포착한다.

확정 방향:

- `RhwpStudioHostBridgeScript.source`에 status message observer를 추가한다.
- `#sb-message`가 `파일 로드 실패:`로 시작하면 native에 `type: "document-load-error"`를 post한다.
- `RhwpStudioWebView`는 `"document-load-error"`를 받아 fatal fallback으로 연결한다.
- failure model은 기존 `RhwpStudioWebViewFailure`를 재사용하되, category에 사용자 문서 입력 실패를 나타내는 항목을 추가한다.
- title/message는 asset/document scheme failure와 다르게 `문서를 열 수 없습니다` 계열로 둔다.
- diagnostic detail에는 upstream message, filename, byteCount, documentRevision, reloadToken을 남긴다.

이 bridge는 handled error를 native에 알려 빈 viewer 상태를 피하기 위한 최소 장치다. upstream bundle 함수 이름이나 minified top-level function을 monkey patch하지 않고 DOM status 변화를 관찰하는 방식으로 둔다.

## Quick Look 구현 기준

Stage 4의 Quick Look 구현 기준:

- `HwpPreviewProvider.createPreview(for:)`가 `fileTooLarge` 외 사용자 문서 실패도 `plain text` fallback으로 mapping한다.
- `RhwpError.invalidData`, `RhwpError.parseFailure`, `HwpRenderError.emptyDocument`, `HwpRenderError.invalidPageSize`, `HwpRenderError.renderTreeUnavailable`은 손상/미지원 문서 fallback으로 본다.
- `HwpRenderError.bitmapContextUnavailable`, `imageUnavailable`, `pngEncodingFailed`, `pdfEncodingFailed`는 렌더/인코딩 실패 fallback으로 본다.
- `pngReply`/`pdfReply` data creation block 내부 throw를 fallback으로 바꾸기 어렵기 때문에, Stage 4에서는 가능한 한 render work를 `createPreview`의 do/catch 안으로 당겨와 fallback reply를 선택할 수 있게 한다.
- 단일 페이지는 PNG data를 미리 만들고, 다중 페이지는 PDF data를 미리 만든 뒤 reply closure가 이미 만든 data를 반환하는 구조를 우선 검토한다.
- 렌더 선계산이 지나치게 부담되면 Stage 4 보고서에 API 제약과 잔여 위험을 명시하고, 가능한 범위의 inspect-time fallback만 적용한다.

## Thumbnail 구현 기준

Stage 4의 Thumbnail 구현 기준:

- `HwpThumbnailProvider`에서 `fileTooLarge` 외 fallback-eligible error도 기존 `drawFallback` tile로 mapping한다.
- `HwpThumbnailRenderRequest.init` 단계의 resource values 실패도 Finder 안정성을 위해 fallback tile 후보로 본다.
- `HwpThumbnailRenderCache`는 성공 결과만 저장하는 현 구조를 유지한다. 실패 결과는 cache하지 않는다.
- `HwpPageImageRenderer.renderFirstPage`는 `embeddedThumbnailPolicy == .never`인 경우 file size를 full data read 전에 확인하도록 보강한다.
- 현재 thumbnail cache는 `.never` 정책을 사용하므로 이 변경으로 50 MB 초과 thumbnail에서 불필요한 full file read를 줄일 수 있다.
- 향후 embedded thumbnail fast path를 다시 켤 경우에는 large file에서도 embedded thumbnail만 추출할지 별도 정책으로 다룬다.

## Shared helper 기준

중복 mapping을 줄이기 위해 `Sources/Shared`에 AppKit/WebKit 없는 helper를 추가하는 방향을 확정한다.

후보 구조:

- `HwpDocumentFallbackReason`
  - `fileTooLarge`
  - `emptyOrInvalid`
  - `unsupportedOrCorrupt`
  - `renderUnavailable`
  - `encodingFailed`
  - `fileAccessFailed`
- `HwpDocumentFallbackClassifier`
  - `static func reason(for error: Error) -> HwpDocumentFallbackReason?`
  - `static func quickLookMessage(for reason: HwpDocumentFallbackReason) -> String`
  - `static func shouldUseThumbnailFallback(for error: Error) -> Bool`

이 helper는 Foundation 수준으로 유지하고 AppKit/UIKit/WebKit 의존을 넣지 않는다. `RhwpError`와 `HwpRenderError` mapping은 여기서 소유하되, 실제 `QLPreviewReply` 생성과 `QLThumbnailReply` drawing은 각 extension provider가 계속 소유한다.

## Stage 3/4 변경 범위

### Stage 3 변경 대상

- `Sources/HostApp/Stores/DocumentViewerStore.swift`
  - input validation helper 호출
  - 파일 선택/drop/recent 문구 정리
- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
  - status message observer와 `document-load-error` post
- `Sources/HostApp/Views/RhwpStudioWebView.swift`
  - `"document-load-error"` handling
- `Sources/HostApp/Services/RhwpStudioResourceLocator.swift`
  - `RhwpStudioWebViewFailureCategory`에 사용자 문서 입력 failure 추가 필요 시
- `Sources/Shared/...` 신규 helper
  - signature preflight와 fallback classification

### Stage 4 변경 대상

- `Sources/QLExtension/HwpPreviewProvider.swift`
  - fallback mapping과 pre-rendered reply 구조 검토/구현
- `Sources/Shared/HwpPreviewPDFRenderer.swift`
  - 필요 시 pre-render path 보조
- `Sources/Shared/HwpPageImageRenderer.swift`
  - size check before full read
  - fallback classification helper 추가 위치 조정
- `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`
  - fallback-eligible error tile mapping
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
  - 실패 cache 없음 유지 확인. 필요 시 변경 없음

## 제외 범위

- HostApp 50 MB hard block은 이번 Stage 3/4 구현에 포함하지 않는다.
- Rust `rhwp` parser 수정은 포함하지 않는다.
- upstream `rhwp-studio` asset 파일 자체를 직접 수정하지 않는다.
- Quick Look progressive/lazy preview 구현은 포함하지 않는다.
- Thumbnail fallback tile에 오류 텍스트를 그리지 않는다.

## 검증 결과

구현계획서 Stage 2 검증 명령을 실행했다.

```bash
git status --short --branch
```

결과: `## local/task149`

```bash
rg -n "LocalizedError|errorDescription|Fallback|fallback|textReply|drawFallback|RhwpStudioWebViewFailure|HwpRenderError|RhwpError|fileTooLarge|parseFailure" \
  Sources mydocs/working/task_m016_149_stage1.md mydocs/plans/task_m016_149_impl.md
```

결과: 성공. 기존 error/fallback 관련 구조와 Stage 1/구현계획서의 결정 지점을 확인했다. minified bundled asset match는 출력이 매우 길어 보고서에는 요약만 남긴다.

Stage 2 보고서 작성 후 다음 검증도 실행했다.

```bash
rg -n "빈 문서|파일 읽기 실패|50 MB|signature|parseFailure|renderTreeUnavailable|invalidPageSize|plain text|fallback tile|HostApp hard block" \
  mydocs/working/task_m016_149_stage2.md
git diff --check
```

결과: 성공. 필수 검색어가 Stage 2 보고서에 모두 포함되어 있고 whitespace 문제도 없다.

## 잔여 위험

- `#sb-message` MutationObserver 방식은 upstream UI text에 의존한다. 다만 minified function patch보다 안정적이고 asset 직접 수정이 없다는 장점이 있다.
- Quick Look pre-render 방식은 provider 응답 시점의 작업량을 늘릴 수 있다. 50 MB 제한이 있으나 페이지 수가 큰 문서에서는 체감 지연이 있을 수 있다.
- `HwpPageImageRenderer.renderFirstPage`의 size check 이동은 embedded thumbnail 정책과 관련이 있다. 현재 `.never` 호출에는 이득이 명확하지만 향후 embedded thumbnail fast path를 켜면 정책 재검토가 필요하다.
- shared helper가 너무 커지면 target별 응답 정책까지 삼킬 수 있다. helper는 classification까지만 소유하고 UI/reply 생성은 target provider에 남긴다.

## 다음 단계 영향

Stage 3은 HostApp input validation과 WKWebView document-load-error bridge를 구현한다. Stage 4는 Shared fallback classifier, Quick Look plain text fallback, Thumbnail fallback tile mapping, 대용량 full read 방지 순서로 진행한다.

## 승인 요청

Stage 2 taxonomy와 구현 기준 확정을 승인해 주시면 Stage 3 HostApp opening fallback 보강으로 진행하겠다.
