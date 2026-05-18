# Task M020 #87 Stage 2 완료보고서

## 단계 목적

Quick Look extension에 probe를 넣기 전에 standalone 환경에서 `PDFDocument`와 custom `PDFPage.draw(with:to:)` hook을 구성하고, draw 호출을 page index별로 기록할 수 있는지 확인한다.

## 산출물

| 파일 | 요약 | 라인 수 |
| --- | --- | ---: |
| `scripts/quicklook-pdfkit-lazy-probe.swift` | `PDFDocument`에 custom `ProbePDFPage`를 삽입하고, `dataRepresentation` 및 직접 draw 호출을 summary로 기록하는 standalone helper | 354 |
| `mydocs/working/task_m020_87_stage2.md` | Stage 2 구현과 검증 결과 기록 | - |

제품 소스, Quick Look extension, `Sources/RhwpCoreBridge`는 수정하지 않았다.

## 구현 내용

`scripts/quicklook-pdfkit-lazy-probe.swift`를 추가했다.

주요 동작:

1. `--pages`, `--output`, 선택적 `--width`, `--height` 인자를 받는다.
2. `ProbePDFPage: PDFPage`가 page number와 bounds를 보유한다.
3. `ProbePDFPage.draw(with:to:)`가 호출될 때 `DrawRecorder`에 phase, page number, display box, page bounds, clip bounds를 기록한다.
4. `PDFDocument`에 page count만큼 custom page를 삽입한다.
5. `PDFDocument.dataRepresentation()` phase와 직접 `page.draw(with:to:)` phase를 분리해 호출한다.
6. `summary.txt`에 page count, page bounds, phase별 draw event 수, draw event table을 기록한다.

초기 구현은 Swift script mode에서 `@main` 사용이 top-level code 오류로 실패했다. 구현계획서의 검증 명령인 `xcrun swift scripts/quicklook-pdfkit-lazy-probe.swift ...`를 그대로 유지하기 위해 top-level `do/try/catch` 실행 방식으로 보정했다.

## 관측 결과

실행 명령:

```bash
xcrun swift scripts/quicklook-pdfkit-lazy-probe.swift --pages 5 --output /private/tmp/rhwp-task87-pdfkit-probe
```

결과:

```text
OK pages=5 drawEvents=10 summary=/private/tmp/rhwp-task87-pdfkit-probe/summary.txt
```

summary 핵심값:

```text
PagesRequested: 5
DocumentPageCount: 5
PageSize: 612.0x792.0
DataRepresentationBytes: 5444
InsertDrawEvents: 0
DataRepresentationDrawEvents: 5
DirectDrawEvents: 5
TotalDrawEvents: 10
```

의미:

- page 삽입 자체는 draw를 호출하지 않았다.
- `PDFDocument.dataRepresentation()`은 custom page 5개를 모두 `draw(with:to:)`로 materialize했다.
- 직접 `page.draw(with:to:)` 호출도 page별로 정확히 1회씩 기록됐다.
- 따라서 Stage 3/4에서는 Quick Look이 `PDFDocument`를 실제 page view로 소비하는지, 아니면 내부에서 `dataRepresentation`과 유사하게 전체 page를 materialize하는지 구분해야 한다.

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. 이번 단계는 probe helper와 단계 보고서 추가이며 기존 문서 본문과 제품 코드는 수정하지 않았다.

## 검증 결과

```bash
xcrun swift scripts/quicklook-pdfkit-lazy-probe.swift --pages 5 --output /private/tmp/rhwp-task87-pdfkit-probe
```

결과:

```text
OK pages=5 drawEvents=10 summary=/private/tmp/rhwp-task87-pdfkit-probe/summary.txt
```

```bash
test -s /private/tmp/rhwp-task87-pdfkit-probe/summary.txt
```

결과: 통과.

```bash
git diff --check -- scripts/quicklook-pdfkit-lazy-probe.swift mydocs/working/task_m020_87_stage2.md
```

결과: 통과.

추가 확인:

```bash
sed -n '1,80p' /private/tmp/rhwp-task87-pdfkit-probe/summary.txt
```

결과: page bounds와 draw event table이 생성됐고, `dataRepresentation` phase 5회와 `directDraw` phase 5회가 기록됐다.

## 잔여 위험

- standalone helper는 Quick Look runtime의 page request 정책을 검증하지 않는다.
- `PDFDocument.dataRepresentation()`이 전체 page draw를 호출한다는 결과는 Stage 3에서 중요한 위험 신호지만, Quick Look이 반드시 같은 경로를 사용한다고 단정할 수는 없다.
- 현재 helper는 synthetic blank/custom page만 다룬다. HWP/HWPX 실제 render 비용과 cancellation은 Stage 3/4 probe에서 별도로 확인해야 한다.
- `xcrun swift`는 Swift module cache를 쓰기 때문에 sandbox 밖 실행이 필요했다.

## 다음 단계 영향

Stage 3에서는 `HwpPreviewProvider` 기본 경로를 유지한 채 opt-in gate로만 `QLPreviewReply(forPDFWithPageSize:)` probe를 선택하도록 만든다. Stage 2에서 확인한 것처럼 `dataRepresentation` 여부를 phase별로 구분해 기록해야 한다.

## 승인 요청

Stage 2 완료 검토와 Stage 3 `Quick Look extension gated PDFKit reply probe 추가` 진행 승인을 요청한다.
