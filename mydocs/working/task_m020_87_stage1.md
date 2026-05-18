# Task M020 #87 Stage 1 완료보고서

## 단계 목적

현행 Quick Look PDF preview 경로와 PDFKit lazy 후보 API를 inventory하고, Stage 2에서 만들 probe의 최소 구조를 확정한다.

## 산출물

| 파일 | 요약 |
| --- | --- |
| `mydocs/working/task_m020_87_stage1.md` | 현행 Quick Look PDF reply 흐름, #85/#149/#221 선행 결론, PDFKit compile probe, Stage 2 구조 결정 기록 |

제품 소스는 수정하지 않았다.

## 현행 Quick Look preview 흐름

현재 `HwpPreviewProvider`는 `HwpPreviewPDFRenderer.inspect(fileURL:)`로 파일 data, page count, 첫 페이지 크기를 확인한 뒤 page count에 따라 PNG/PDF reply를 고른다.

코드 기준 흐름:

1. `providePreview`가 `createPreview(for:)`를 호출한다.
2. `createPreview`는 `HwpPreviewPDFRenderer.inspect(fileURL:)`를 먼저 호출한다.
3. `pageCount == 1`이면 `pngReply`를 호출한다.
4. `pageCount >= 2`이면 `pdfReply`를 호출한다.
5. `pngReply`는 `QLPreviewReply` 생성 전에 `RhwpDocument`를 열고 첫 페이지 bitmap과 PNG data를 만든다.
6. `pdfReply`는 `QLPreviewReply` 생성 전에 `HwpPreviewPDFRenderer.render(previewInfo:)`로 전체 PDF data를 만든다.
7. `QLPreviewReply(dataOfContentType:contentSize:)`의 block은 이미 만들어진 data를 반환한다.

따라서 현재 HEAD 기준 Quick Look preview는 data-based reply이며, 다중 페이지 PDF 생성은 reply 생성 전에 전체 page render를 완료한다. 이 구조에서는 첫 페이지만 먼저 표시하고 나머지를 visible page 중심으로 나중에 그리는 true lazy pagination을 제공하지 않는다.

`HwpPreviewPDFRenderer.render`도 `0..<pageCount` 전체를 순회한다. 각 page는 `HwpPageImageRenderer.renderPage(document:pageIndex:)`로 bitmap을 만든 뒤 CoreGraphics PDF context에 삽입된다. 결과는 하나의 `Data`로 닫힌 PDF다.

## 선행 작업 결론 정리

### #85와 현재 HEAD 차이

#85 Stage 5는 `QLPreviewReply(dataOfContentType:contentSize:dataCreationBlock:)`의 block 안으로 PNG/PDF data 생성을 지연해 provider reply 반환 전 작업량을 줄였다. 하지만 #149 Stage 4에서 fallback mapping을 강화하면서 `HwpPreviewProvider`는 PNG/PDF data를 reply 생성 전에 다시 선계산하도록 바뀌었다.

이 변경의 의도는 data block 내부 throw가 raw extension error로 전파되는 범위를 줄이는 것이다. 대신 현재 구조는 #85 최종 보고서의 "data creation block 안으로 지연" 설명보다 더 보수적이고 eager한 경로다.

#87의 문제의식은 여전히 유효하다. 현재 HEAD는 data reply 구조일 뿐 아니라 실제 render data도 선계산하므로 true lazy pagination과는 더 멀다.

### #221 결론과 #87 경계

#221 SVG PDF spike는 core SVG 기반 PDF 생성 후보를 비교했고, 단기에는 현재 Swift native bitmap PDF/PNG fast path를 유지한다는 결론을 냈다. 이 결론은 "무엇을 그릴 것인가"와 "SVG PDF로 바꿀 것인가"의 문제다.

#87은 Quick Look이 `PDFDocument`/`PDFPage`를 받아 page draw 시점에 필요한 page만 요청하는지 확인하는 작업이다. 즉 "언제 그릴 수 있는가"의 문제이므로 #221과 직접 중복되지 않는다.

## PDFKit 후보 API 확인

다음 compile probe는 sandbox의 Swift module cache 쓰기 제한으로 처음에는 실패했고, 같은 명령을 sandbox 밖에서 재실행해 성공을 확인했다.

```bash
xcrun swift -e 'import Foundation; import QuickLookUI; import PDFKit; let _ = QLPreviewReply(forPDFWithPageSize: .zero) { reply in PDFDocument() }'
```

결과: 성공. 출력 없음.

다음 custom `PDFPage` subclass probe도 성공했다.

```bash
xcrun swift -e 'import Foundation; import PDFKit; final class ProbePage: PDFPage { override func draw(with box: PDFDisplayBox, to context: CGContext) { super.draw(with: box, to: context) } }; let document = PDFDocument(); document.insert(ProbePage(), at: 0); print(document.pageCount)'
```

결과:

```text
1
```

확인된 사실:

- `QLPreviewReply(forPDFWithPageSize:documentCreationBlock:)`는 현재 SDK에서 Swift compile 가능하다.
- `PDFPage.draw(with:to:)` override와 `PDFDocument.insert(_:at:)` 조합은 compile 가능하다.
- 이 compile probe는 Quick Look이 실제로 visible page 중심으로 draw를 호출한다는 증거는 아니다. Quick Look 안에서의 호출 시점은 Stage 3/4 관측이 필요하다.

## Info.plist와 extension 형태

`Sources/QLExtension/Info.plist`는 현재 `QLIsDataBasedPreview = true`를 선언한다. `NSExtensionPointIdentifier`는 `com.apple.quicklook.preview`이고 principal class는 `$(PRODUCT_MODULE_NAME).HwpPreviewProvider`다.

Stage 3에서 PDFKit reply probe를 extension에 넣을 때는 이 설정을 유지한 상태에서 `QLPreviewReply(forPDFWithPageSize:)`가 실제로 동작하는지 먼저 확인한다. 만약 Quick Look이 data-based 설정과 PDFDocument reply를 함께 받아들이지 않는다면, 그 자체가 #87의 중요한 관측 결과가 된다. 설정 변경은 #88 view-based 전환과 가까운 범위이므로 Stage 3에서 임의로 확장하지 않는다.

## Stage 2 최소 구조 결정

Stage 2는 제품 extension에 들어가기 전 standalone helper로 시작한다.

결정한 구조:

- 파일: `scripts/quicklook-pdfkit-lazy-probe.swift`
- 입력: page count, output directory
- 객체:
  - `ProbePDFPage: PDFPage`
  - `ProbePDFDocument: PDFDocument` 또는 inserted page 기반 `PDFDocument`
- 기록:
  - document page count
  - page bounds
  - 직접 `draw(with:to:)` 호출 순서
  - 실패 지점
- 출력:
  - `/private/tmp/rhwp-task87-pdfkit-probe/summary.txt`

Stage 2의 목표는 PDFKit 객체 구조와 draw hook logging을 안정화하는 것이다. Quick Look lazy 동작 자체는 Stage 3의 gated extension probe와 Stage 4 smoke에서 판단한다.

## 검증 결과

```bash
rg -n "QLPreviewReply|forPDFWithPageSize|PDFDocument|PDFPage|HwpPreviewProvider|HwpPreviewPDFRenderer" \
  Sources mydocs/report/task_m010_85_report.md mydocs/report/task_m020_221_report.md mydocs/working/task_m010_85_stage1.md mydocs/working/task_m010_85_stage5.md
```

결과: 관련 코드와 선행 문서를 확인했다. 주요 확인 지점은 다음과 같다.

- `Sources/QLExtension/HwpPreviewProvider.swift`: 현재 PNG/PDF reply 분기와 eager data 생성
- `Sources/Shared/HwpPreviewPDFRenderer.swift`: 전체 page loop 기반 PDF data 생성
- `mydocs/working/task_m010_85_stage5.md`: data block 지연 구조와 true lazy 한계
- `mydocs/report/task_m020_221_report.md`: SVG PDF 전환 보류와 native bitmap fast path 유지 결론

```bash
xcrun swift -e 'import Foundation; import QuickLookUI; import PDFKit; let _ = QLPreviewReply(forPDFWithPageSize: .zero) { reply in PDFDocument() }'
```

결과: 성공.

```bash
xcrun swift -e 'import Foundation; import PDFKit; final class ProbePage: PDFPage { override func draw(with box: PDFDisplayBox, to context: CGContext) { super.draw(with: box, to: context) } }; let document = PDFDocument(); document.insert(ProbePage(), at: 0); print(document.pageCount)'
```

결과:

```text
1
```

```bash
git diff --check -- mydocs/plans/task_m020_87_impl.md mydocs/working/task_m020_87_stage1.md
```

결과: 통과.

## 잔여 위험

- compile 가능성은 Quick Look runtime lazy 가능성을 보장하지 않는다.
- `QLIsDataBasedPreview = true` 설정에서 PDFDocument reply가 어떤 방식으로 처리되는지는 실제 extension smoke 전까지 단정할 수 없다.
- `PDFPage.draw(with:to:)`가 호출되더라도 Quick Look이 초기 표시 전에 여러 page를 preload할 수 있다.
- 현재 HEAD는 #149 이후 eager data 생성 경로라서, Stage 4에서 기존 data reply 기준 latency를 측정하면 #85 Stage 5 보고서의 수치와 다를 수 있다.

## 다음 단계 영향

Stage 2는 standalone helper를 작성해 `PDFDocument` 구성과 custom `PDFPage.draw(with:to:)` logging을 먼저 안정화한다. 제품 Quick Look provider 변경은 Stage 3으로 미룬다.

## 승인 요청

Stage 1 완료 검토와 Stage 2 `standalone PDFKit lazy probe helper 작성` 진행 승인을 요청한다.
