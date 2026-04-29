# Task #85 Stage 3 완료 보고서

## 단계 목적

Quick Look preview provider가 HWP/HWPX 모든 페이지를 담은 PDF preview reply를 반환하도록 구현한다. PDF는 HWP 구조 변환 산출물이 아니라 기존 native renderer가 만든 page bitmap을 담는 Quick Look 표시용 컨테이너로 제한한다.

## 산출물

- `Sources/Shared/HwpPreviewPDFRenderer.swift`
  - 76 lines
  - 파일 크기 fallback, `RhwpDocument` 생성, page 순회, PDF data 생성 담당
- `Sources/QLExtension/HwpPreviewProvider.swift`
  - 38 lines
  - 기존 PNG reply를 PDF data reply로 전환
- `Sources/Shared/HwpPageImageRenderer.swift`
  - 217 lines
  - `HwpRenderError.pdfEncodingFailed` 추가
- `AlhangeulMac.xcodeproj/project.pbxproj`
  - `xcodegen generate`로 새 Shared source를 HostApp/QLExtension/ThumbnailExtension target에 포함
- `mydocs/working/task_m010_85_stage3.md`
  - Stage 3 변경과 검증 결과 기록

## 본문 변경 정도 / 본문 무손실 여부

HWP/HWPX 원본 처리와 Rust core ABI는 변경하지 않았다. Quick Look preview 응답 포맷만 PNG에서 PDF로 바꿨고, PDF 내부 페이지 이미지는 Stage 2에서 분리한 `HwpPageImageRenderer.renderPage(document:pageIndex:maximumPixelSize:)`의 bitmap 결과를 사용한다.

생성 산출물 `Frameworks/`, `RustBridge/target/`, `build.noindex/`, `output/`은 검증을 위해 사용됐지만 ignored 상태이며 커밋 대상에서 제외했다.

## 변경 내용

### Quick Look PDF renderer 추가

`HwpPreviewPDFRenderer.render(fileURL:)`를 추가했다.

처리 흐름:

1. 파일 크기를 확인해 50 MB 초과면 기존 `HwpRenderError.fileTooLarge`를 throw한다.
2. 파일 data를 한 번 읽고 `RhwpDocument`를 한 번 생성한다.
3. `document.pageCount`가 0이면 `emptyDocument`를 throw한다.
4. 첫 페이지 크기를 Quick Look content size hint로 사용한다.
5. `0..<pageCount`를 순회한다.
6. 각 page index를 `HwpPageImageRenderer.renderPage(document:pageIndex:)`로 bitmap 렌더링한다.
7. 각 bitmap을 page size별 PDF page에 삽입한다.
8. 최종 PDF data와 page count를 `HwpRenderedPreviewPDF`로 반환한다.

중간 page bitmap은 배열에 누적하지 않고 루프 안에서 바로 PDF context에 그린다.

### Quick Look provider PDF reply 전환

`HwpPreviewProvider.createPreview(for:)`는 이제 다음 형태로 reply를 반환한다.

```swift
let result = try HwpPreviewPDFRenderer.render(fileURL: request.fileURL)
return QLPreviewReply(
    dataOfContentType: .pdf,
    contentSize: result.contentSize
) { reply in
    reply.title = request.fileURL.lastPathComponent
    return result.data
}
```

`HwpRenderError.fileTooLarge` plain text fallback은 유지했다.

### Xcode project 재생성

`project.yml`은 변경하지 않았다. `xcodegen generate`를 실행해 새 `Sources/Shared/HwpPreviewPDFRenderer.swift`가 generated Xcode project에 포함되도록 했다.

`Sources/Shared`가 HostApp, QLExtension, ThumbnailExtension target에 공통 포함되는 구조라 새 파일도 세 target source phase에 포함됐다. 파일은 CoreGraphics/Foundation만 의존하므로 AppKit/UIKit 경계에는 영향이 없다.

## 검증 결과

### 변경 범위 확인

```bash
git status --short --branch
```

결과 요약:

```text
 M AlhangeulMac.xcodeproj/project.pbxproj
 M Sources/QLExtension/HwpPreviewProvider.swift
 M Sources/Shared/HwpPageImageRenderer.swift
?? Sources/Shared/HwpPreviewPDFRenderer.swift
```

```bash
git diff --check
```

결과: 통과.

### XcodeGen

```bash
xcodegen generate
```

결과:

```text
Created project at /tmp/rhwp-mac-task85/AlhangeulMac.xcodeproj
```

새 source 포함 확인:

```bash
rg -n "HwpPreviewPDFRenderer" AlhangeulMac.xcodeproj/project.pbxproj Sources
```

결과 요약:

- `AlhangeulMac.xcodeproj/project.pbxproj`에 `HwpPreviewPDFRenderer.swift` file reference 추가
- HostApp/QLExtension/ThumbnailExtension source phase에 포함
- `HwpPreviewProvider`가 `HwpPreviewPDFRenderer.render(fileURL:)`를 호출

### AppKit/UIKit 경계 확인

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### render smoke

```bash
./scripts/validate-stage3-render.sh
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=449097 png=/private/tmp/rhwp-mac-task85/output/stage3-render/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=53220 png=/private/tmp/rhwp-mac-task85/output/stage3-render/request-page1.png
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=108 hangulRuns=71 hangulScalars=1203 nonWhitePixels=159757 png=/private/tmp/rhwp-mac-task85/output/stage3-render/exam_kor-page1.png
```

### HostApp Debug build

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [3.865 sec]
```

### PDF page count smoke

`build.noindex/preview_pdf_check.swift`를 임시 smoke 용도로 작성해 `HwpPreviewPDFRenderer.render(fileURL:)` 결과를 `PDFDocument(data:)`로 다시 열고 page count를 비교했다. 이 파일과 컴파일 산출물은 ignored `build.noindex/` 아래에 있어 커밋 대상이 아니다.

컴파일/실행 요약:

```bash
swiftc -parse-as-library \
  -I Frameworks/modulemap \
  Sources/RhwpCoreBridge/RhwpDocument.swift \
  Sources/RhwpCoreBridge/RenderTree.swift \
  Sources/RhwpCoreBridge/FontFallback.swift \
  Sources/RhwpCoreBridge/CGTreeRenderer.swift \
  Sources/Shared/HwpPageImageRenderer.swift \
  Sources/Shared/HwpPreviewPDFRenderer.swift \
  build.noindex/preview_pdf_check.swift \
  Frameworks/universal/librhwp.a \
  -framework CoreGraphics \
  -framework CoreText \
  -framework ImageIO \
  -framework Security \
  -framework CoreFoundation \
  -framework UniformTypeIdentifiers \
  -framework PDFKit \
  -o build.noindex/preview_pdf_check
```

실행 결과:

```text
OK KTX.hwp: sourcePages=1 previewPages=1 pdfPages=1 bytes=488798
OK hwp-multi-001.hwp: sourcePages=10 previewPages=10 pdfPages=10 bytes=1495345
OK hwpx-01.hwpx: sourcePages=9 previewPages=9 pdfPages=9 bytes=1457195
```

## 잔여 위험

- Stage 3은 PDF page count와 build를 확인했지만, 실제 Quick Look UI에서 스크롤 가능한 다중 페이지 표시까지는 Stage 4에서 확인해야 한다.
- PDF page에 삽입된 bitmap의 시각 방향과 배율은 Quick Look 또는 PDF raster 결과로 추가 확인해야 한다.
- 모든 페이지를 한 번에 PDF data로 생성하므로 긴 문서에서는 초기 preview 지연과 메모리 사용량이 증가할 수 있다. 아직 page cap은 적용하지 않았다.
- `HwpPreviewPDFRenderer.swift`가 Shared source라 Thumbnail target에도 컴파일된다. 현재 의존은 CoreGraphics/Foundation으로 제한되어 있지만, 후속 변경 시 Thumbnail extension 영향도 함께 검증해야 한다.

## 다음 단계 영향

- Stage 4에서 실제 `qlmanage -p` Quick Look preview smoke를 수행한다.
- 기존 thumbnail smoke도 수행해 Shared source 추가가 thumbnail build/runtime 경로에 회귀를 만들지 않았는지 확인한다.
- 문서가 Quick Look preview를 첫 페이지 PNG로 설명하는 부분을 현재 PDF preview 경로에 맞게 갱신해야 한다.

## 승인 요청

Stage 3 구현과 검증 결과를 승인 요청한다. 승인 후 Stage 4 `Quick Look/Thumbnail 통합 검증과 문서 정리`로 진행한다.
