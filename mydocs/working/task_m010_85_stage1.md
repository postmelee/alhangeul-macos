# Task #85 Stage 1 완료 보고서

## 단계 목적

Quick Look 전체 페이지 preview 구현에 앞서 macOS SDK의 PDF preview 지원 방식과 현재 extension 구조를 확인하고, Stage 2와 Stage 3에서 적용할 구현 방향을 확정한다.

## 산출물

- `mydocs/working/task_m010_85_stage1.md`
  - Stage 1 설계 확인 결과와 Stage 2/3 구현 결정을 기록했다.
- 소스 코드는 수정하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

코드와 기존 문서 본문은 변경하지 않았다. 이번 단계는 설계 확인과 단계 보고서 추가만 수행했다.

## 확인 내용

### Quick Look PDF 지원 방식

macOS SDK의 `QLPreviewReply.h`에서 다음 preview 입력 방식을 확인했다.

- `initWithDataOfContentType:contentSize:dataCreationBlock:`
  - 지원 타입에 `UTTypePDF`가 포함된다.
  - 현재 `HwpPreviewProvider`가 PNG preview에서 이미 사용하는 data-based reply 방식과 같은 계열이다.
- `initForPDFWithPageSize:documentCreationBlock:`
  - `PDFDocument`를 반환하는 PDF 전용 reply 방식이다.
- `initWithFileURL:`
  - file URL 기반 preview이며 지원 타입에 PDF가 포함된다.

Swift one-liner로 다음 initializer 사용 가능 여부도 확인했다.

```bash
xcrun swift -e 'import Foundation; import QuickLookUI; import UniformTypeIdentifiers; let _ = QLPreviewReply(dataOfContentType: .pdf, contentSize: .zero) { reply in Data() }'
xcrun swift -e 'import Foundation; import QuickLookUI; import PDFKit; let _ = QLPreviewReply(forPDFWithPageSize: .zero) { reply in PDFDocument() }'
```

두 명령 모두 성공했다. 첫 실행은 Swift module cache 쓰기 권한 때문에 sandbox 밖 실행이 필요했으나, initializer 자체는 정상 확인됐다.

### 현재 Quick Look 구조

현재 `HwpPreviewProvider`는 다음 흐름이다.

1. `providePreview`에서 `MainActor.run`으로 `createPreview`를 호출한다.
2. `HwpPageImageRenderer.renderFirstPage(fileURL:)`로 첫 페이지 bitmap을 만든다.
3. `HwpPageImageRenderer.encodePNG`로 PNG data를 만든다.
4. `QLPreviewReply(dataOfContentType: .png, contentSize: result.size)`를 반환한다.
5. `HwpRenderError.fileTooLarge`는 plain text fallback으로 처리한다.

`Sources/QLExtension/Info.plist`에는 `QLIsDataBasedPreview`가 `true`로 설정되어 있다. 따라서 기존 data-based preview 구조를 유지하면서 content type만 PDF로 바꾸는 방식이 현재 extension 설정과 가장 잘 맞는다.

### Thumbnail 영향 범위

Thumbnail extension은 `HwpThumbnailRenderCache`에서 다음 기존 API를 호출한다.

```swift
HwpPageImageRenderer.renderFirstPage(
    fileURL: request.fileURL,
    maximumPixelSize: request.maximumPixelSize,
    embeddedThumbnailPolicy: .never
)
```

따라서 Stage 2에서 `renderFirstPage`의 기존 signature와 동작을 유지해야 한다. 페이지 번호 기반 helper는 추가하되, Thumbnail 경로의 호출부 변경은 만들지 않는 방향으로 진행한다.

## 구현 결정

### Stage 3 preview reply 방식

1차 구현은 `QLPreviewReply(dataOfContentType: .pdf, contentSize: firstPageSize)`로 진행한다.

이유:

- 현재 Quick Look extension이 data-based preview 구조로 이미 동작한다.
- SDK가 data-based preview의 지원 타입으로 PDF를 명시한다.
- `PDFDocument` reply는 PDFKit 객체 생성 경로가 추가되어 1차 구현에 불필요하다.
- file URL reply는 extension 임시 파일의 생성, 수명, 정리 정책을 별도로 가져야 하므로 1차 구현 범위보다 크다.

### Stage 2 렌더링 helper 방향

`HwpPageImageRenderer`에 문서 핸들과 page index를 받아 bitmap을 만드는 helper를 추가한다. 기존 `renderFirstPage` API는 그대로 유지하고 내부에서 page index `0`을 호출하도록 분리한다.

예상 방향:

- `renderFirstPage(fileURL:)` 유지
- `renderFirstPage(fileURL:maximumPixelSize:embeddedThumbnailPolicy:)` 유지
- `renderPage(document:pageIndex:maximumPixelSize:)` 계열 helper 추가
- page bounds, invalid size, render tree nil을 명확히 error 처리

### Stage 3 PDF 생성 방향

`HwpPreviewPDFRenderer`를 `Sources/Shared`에 추가하는 방향을 우선한다. 역할은 Quick Look provider가 사용할 PDF preview data 생성으로 제한한다.

예상 흐름:

1. 파일 크기 확인 후 50 MB 초과 시 기존 `fileTooLarge` fallback 유지
2. 파일 data를 한 번 읽고 `RhwpDocument`를 한 번 생성
3. `document.pageCount`가 0이면 `emptyDocument`
4. 첫 페이지 size를 content size hint로 사용
5. `0..<document.pageCount` 순회
6. 각 페이지를 bitmap으로 렌더링
7. PDF page를 열고 bitmap을 해당 page rect에 삽입
8. PDF data를 `QLPreviewReply(dataOfContentType: .pdf, ...)`에서 반환

각 페이지 bitmap은 배열로 보관하지 않고 루프 안에서 바로 PDF context에 그린다. 최종 PDF data는 한 번에 반환해야 하므로 누적되지만, 중간 bitmap 누적은 피한다.

### 페이지 수 제한

초기 구현에는 임의 page cap을 넣지 않는다. 이슈 목표가 전체 페이지 preview이므로 모든 페이지 표시를 기본값으로 둔다. Stage 3 또는 Stage 4 검증에서 extension 안정성 문제가 실제로 확인되면, 작업지시자에게 page cap 또는 fallback 정책을 별도로 재승인받는다.

## 검증 결과

```bash
git status --short --branch
```

결과:

```text
## local/task85...origin/devel [ahead 2]
```

```bash
rg -n "QLPreviewReply|dataOfContentType|forPDF|PDFDocument" \
  /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/QuickLookUI.framework
```

결과 요약:

- `QLPreviewReply.h`에 data-based preview initializer 존재
- data-based preview 지원 타입에 `UTTypePDF` 포함
- `initForPDFWithPageSize:documentCreationBlock:` 존재
- `PDFDocument` 관련 category가 존재

```bash
sed -n '1,220p' Sources/QLExtension/HwpPreviewProvider.swift
sed -n '1,260p' Sources/Shared/HwpPageImageRenderer.swift
sed -n '1,220p' Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift
git diff --check
```

결과:

- 현재 Quick Look은 단일 PNG data reply 구조임을 확인했다.
- 현재 `HwpPageImageRenderer`는 page index 0 전용 구현임을 확인했다.
- Thumbnail cache는 `renderFirstPage(fileURL:maximumPixelSize:embeddedThumbnailPolicy:)`를 직접 호출함을 확인했다.
- `git diff --check` 통과.

추가 확인:

```bash
xcrun swift -e 'import Foundation; import QuickLookUI; import UniformTypeIdentifiers; let _ = QLPreviewReply(dataOfContentType: .pdf, contentSize: .zero) { reply in Data() }'
xcrun swift -e 'import Foundation; import QuickLookUI; import PDFKit; let _ = QLPreviewReply(forPDFWithPageSize: .zero) { reply in PDFDocument() }'
```

결과:

- 두 명령 모두 성공.

## 잔여 위험

- PDF data reply는 최종 PDF data를 한 번에 반환하므로 매우 긴 문서에서는 응답 지연과 메모리 사용량이 증가할 수 있다.
- Stage 2에서 `HwpPageImageRenderer`를 일반화할 때 기존 Thumbnail cache 경로가 영향을 받을 수 있다. 기존 signature와 첫 페이지 동작을 유지해야 한다.
- Stage 3에서 PDF page에 bitmap을 그릴 때 CoreGraphics 좌표계와 이미지 Y축 방향을 다시 확인해야 한다.
- 실제 Quick Look 실행은 등록 상태와 캐시 영향을 받으므로 Stage 4에서 Release package 기준 검증 필요 여부를 재판단한다.

## 다음 단계 영향

- Stage 2는 `HwpPageImageRenderer` 내부 렌더링 본문을 page index 기반 helper로 분리한다.
- Stage 3은 `Sources/Shared/HwpPreviewPDFRenderer.swift` 추가와 `HwpPreviewProvider`의 `.pdf` data reply 전환을 기준으로 진행한다.
- page cap은 아직 구현하지 않는다.

## 승인 요청

Stage 1 설계 확정 결과를 승인 요청한다. 승인 후 Stage 2 `페이지 번호 기반 렌더링 helper 분리`로 진행한다.
