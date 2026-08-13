# Task #455 Stage 1 완료보고서

## 단계 목적

bundled `rhwp-studio`의 `file:print-to-pdf`, HostApp toolbar의 `file:export-pdf`, 일반 인쇄 `file:print`가 현재 어떤 command·payload·renderer 경로를 사용하는지 조사하고, 내부 메뉴와 toolbar가 공유할 page SVG payload 및 `WKWebView.createPDF` renderer 계약을 제품 코드 변경 전에 확정한다.

## 산출물

- bundled PDF 메뉴의 초기 disabled markup, upstream document-state 활성화와 browser print 동작 확인
- injected HostBridge의 native interception 범위와 toolbar canonical command 경로 확인
- 현재 HWP bytes/native bitmap PDF export와 page SVG/WebKit print 경로 비교
- `RhwpStudioPagePayload`, 공용 renderer, print/export controller와 coordinator의 책임 경계 확정
- representative HWP/HWPX fixture, page geometry·text·원본 불변 검증 기준과 toolchain 확인
- 구현계획서의 bundled 메뉴 상태 설명을 실제 동작에 맞게 보정

제품 소스, bundled upstream asset, Xcode project와 architecture 문서는 이번 단계에서 변경하지 않았다.

## 조사 기준

- branch: `local/task455`
- baseline commit: `595e629` (`Task #455: 구현 계획서 작성`)
- bundled `rhwp-studio`: release tag `v0.8.2`
- upstream resolved commit: `9b16aa9e23f476e2b335d7c029fc9f24a199d63c`
- manifest: `Sources/HostApp/Resources/rhwp-studio/manifest.json`

## 현재 command 경로

### bundled `PDF로 저장...`

`Sources/HostApp/Resources/rhwp-studio/index.html`에는 다음 상태로 항목이 포함된다.

- command: `file:print-to-pdf`
- 초기 class: `md-item disabled`
- 초기 title: 브라우저 인쇄 창에서 `대상 → PDF로 저장`을 선택하라는 안내

minified upstream command registry에는 같은 command와 `canExecute: hasDocument`가 존재한다. 따라서 static markup은 초기 disabled지만 문서가 열리면 upstream command state가 항목을 활성화할 수 있다. 실행 시 upstream은 자체 print용 page SVG를 iframe surface에 구성하고 안내/progress UI를 거쳐 `window.print()`를 호출한다.

HostBridge의 `nativeCommands`와 `nonMutatingCommands`에는 `file:print-to-pdf`가 없다. capture handler는 `nativeCommands`에 속한 메뉴 event만 차단하므로 이 항목은 HostApp native 저장 경로로 들어오지 않고 upstream browser print handler가 소유한다.

### HostApp toolbar PDF 내보내기

toolbar와 macOS command dispatcher는 `file:export-pdf`를 발생시킨다. 현재 흐름은 다음과 같다.

```text
toolbar/macOS command
  -> file:export-pdf
  -> Coordinator.requestPDFExport
  -> DocumentPDFExportPanel NSSavePanel
  -> pendingPDFDestinationURL
  -> __alhangeulHostBridgeExportPDFDocument()
  -> settleEditorState
  -> requestHwpExportPayload
  -> exportHwpBase64 또는 exportHwp
  -> export-pdf-document { fileName, base64, byteCount }
  -> RhwpStudioPDFExportController
  -> RhwpDocument
  -> HwpPreviewPDFRenderer page bitmap PDF
  -> Data.write(.atomic)
  -> Finder reveal
```

HWPX 원본도 PDF export 시 HWP bytes를 중간 payload로 사용한다. PDF에는 `HwpPreviewPDFRenderer`가 render tree를 bitmap으로 그린 page가 들어가므로 upstream SVG의 text semantics를 이용하지 않는다.

현재 coordinator는 `export-pdf-document`를 받으면 `pendingPDFDestinationURL`을 먼저 비우고 HWP bytes를 decode한다. destination이 없더라도 controller의 동기식 panel overload를 호출할 수 있어, pending request가 없는 예상 밖 response가 새 save panel로 이어질 수 있다. 또한 destination을 비운 뒤 `pdfExportController`가 작업 중인지 중복 command guard가 확인하지 않아 rendering 중 두 번째 요청이 controller reference를 덮어쓸 여지가 있다.

### 일반 인쇄

`file:print`는 HostBridge가 upstream handler보다 먼저 가로채며 다음 경로를 사용한다.

```text
file:print
  -> printDocument
  -> documentPages
  -> settleEditorState
  -> requestRhwp("pageCount")
  -> requestRhwp("getPageSvg", { page }) 반복
  -> print-document { fileName, pageCount, pages }
  -> RhwpStudioPrintController
  -> offscreen WKWebView에 SVG page별 load
  -> DOM metrics
  -> WKWebView.createPDF
  -> PDFKit PDFDocument merge
  -> PDFDocument.printOperation
```

즉, Issue #455가 요구하는 page SVG와 `WKWebView.createPDF` 조합은 일반 인쇄에 이미 존재한다. 다만 WebKit navigation, page metrics, PDFKit merge와 print panel 책임이 `RhwpStudioPrintController` 한 객체에 결합돼 PDF 저장에서 재사용할 수 없다.

## current/target 비교

| 항목 | current 내부 메뉴 | current toolbar | target 내부 메뉴·toolbar |
|------|-------------------|-----------------|---------------------------|
| command | `file:print-to-pdf` | `file:export-pdf` | 둘 다 canonical `file:export-pdf` |
| menu/event owner | upstream registry/browser handler | HostApp dispatcher | HostBridge capture + HostApp |
| destination UX | browser print panel 안의 PDF 대상 | native `NSSavePanel` | native `NSSavePanel` |
| editor settle | upstream PDF handler 내부 | HostBridge export helper | 공통 HostBridge page helper |
| native payload | 없음 | HWP base64 bytes | `{ fileName, pageCount, pages: [SVG] }` |
| PDF 생성 | upstream iframe + `window.print()` | `RhwpDocument` + bitmap renderer | offscreen `WKWebView.createPDF` + PDFKit merge |
| HWPX 중간 HWP | 해당 없음 | 있음 | 없음 |
| write/Finder | browser print UX | atomic write + Finder | atomic write + Finder |

일반 `file:print`는 target에서도 macOS print panel을 유지하되 PDF 본문 생성만 공용 SVG renderer를 사용한다.

## 확정한 command 계약

| 진입점 | capture 대상 | native로 전달할 command | 후속 처리 |
|--------|--------------|--------------------------|-----------|
| bundled `PDF로 저장...` | `file:print-to-pdf` | `file:export-pdf`로 정규화 | `requestPDFExport` |
| toolbar PDF 내보내기 | `file:export-pdf` | `file:export-pdf` | `requestPDFExport` |
| 일반 인쇄 | `file:print` | 별도 print payload 생성 | `printDocument` |

HostBridge는 `file:print-to-pdf`를 native/non-mutating set에 추가한다. menu의 disabled/aria-disabled 상태를 제거하고 browser print 안내 title을 알한글 native PDF 저장 안내로 교체한다. 기존 capture listener가 `mousedown`과 `click`을 upstream handler보다 먼저 차단한 뒤 canonical command message를 전송한다. 기존 `MutationObserver`는 upstream DOM/state 갱신 이후 override를 다시 적용한다.

## 확정한 page payload 계약

인쇄와 PDF 저장은 message type만 다르고 같은 payload 모델을 사용한다.

```json
{
  "type": "export-pdf-document",
  "fileName": "example.hwpx",
  "pageCount": 3,
  "pages": ["<svg ...>", "<svg ...>", "<svg ...>"]
}
```

Swift `RhwpStudioPagePayload`의 validation은 다음으로 확정했다.

1. `pageCount >= 1`
2. `pages.count == pageCount`
3. 모든 SVG가 whitespace 제거 후 non-empty
4. file name이 없으면 current document name 또는 `document.hwp` 보완

PDF export helper는 `requestHwpExportPayload`, `base64`, `byteCount`를 사용하지 않는다. share와 HWP/HWPX save helper는 기존 bytes contract를 그대로 유지한다.

## 확정한 renderer/controller 경계

### `RhwpStudioPagePDFRenderer`

- HostApp 전용 `@MainActor` 객체
- offscreen `WKWebView`, navigation lifecycle, HTML wrapper, page metrics 소유
- page별 `WKPDFConfiguration.rect`와 `createPDF` 호출
- page PDF decode와 최종 `PDFDocument` 순서 보존 merge
- 최초 성공 또는 오류 completion을 정확히 한 번 반환
- alert, print/save panel, file write와 Finder 표시를 소유하지 않음

page metrics는 유한하고 양수인 width/height만 허용한다. current `RhwpStudioPrintPageSize`는 missing value를 `794x1123`으로 fallback하고 non-finite 값을 명시적으로 거르지 않는다. Stage 2는 invalid metrics를 오류로 처리하는 것을 기본으로 하며, 실제 upstream SVG 호환 때문에 fallback이 필요하다고 확인된 경우에만 제한 조건을 기록한다.

각 SVG의 `createPDF` data는 PDFKit으로 열리고 정확히 한 page여야 한다. current print controller는 page document가 1 page 이상이면 모든 page를 append하므로 input SVG 하나가 여러 PDF page를 만들 때 payload page count와 결과가 어긋날 수 있다. 공용 renderer는 page별 1 page와 최종 `PDFDocument.pageCount == payload.pageCount`를 확인한다.

### `RhwpStudioPrintController`

- 공용 renderer 결과를 `PDFDocument.printOperation`으로 연결
- print operation, print 전용 alert와 job title 소유
- WebKit navigation, HTML, metrics와 page merge 책임 제거

### `RhwpStudioPDFExportController`

- 공용 renderer 결과의 PDF data representation 확인
- 선택된 destination에 `.atomic` write
- success URL 또는 error 반환
- save panel overload와 native bitmap renderer 의존 제거

### `RhwpStudioWebView.Coordinator`

- destination panel과 단일 pending PDF request 소유
- pending destination이 있는 response만 수락
- choosing, collecting, rendering과 writing 동안 중복 command 차단
- print/export가 같은 page payload parser를 사용하도록 연결
- 성공 URL만 Finder에서 표시하고 원본/current source 상태는 변경하지 않음

## 대표 fixture와 검증 baseline

| fixture | SHA-256 | bytes | 기존 page baseline | first page baseline | Stage 4 역할 |
|---------|---------|------:|--------------------:|---------------------|--------------|
| `samples/basic/KTX.hwp` | `6c1a027d67b33c03f469b56548b4c7d6bca36b1c1190c7cc5eac88e35c403cf1` | 66,048 | 1 | `1123x794`, landscape | 단일 가로 page size/orientation |
| `samples/hwp-multi-001.hwp` | `cb810b94394d8116de0aff1be70d5c63f381090a55050c77f02d4ba67e89523e` | 492,032 | 10 | `794x1123`, portrait | HWP 다중 page count/nonblank |
| `samples/hwpx/hwpx-01.hwpx` | `e17464a1514e3d83391d32a5db30f662f3d0db4b7c61bbaacf4450a729f70f20` | 484,352 | 9 | `794x1123`, portrait | HWPX, HWP 중간 export 제거 |

page baseline은 기존 Task #85와 #438 보고서의 검증 결과를 사용한다. Stage 4는 임시 복사본만 편집하고 원본 SHA-256과 mtime을 전후 비교한다. `pdfinfo`와 `pdftotext`는 모두 Poppler `26.07.0`이 설치돼 있어 page geometry와 text layer 자동 확인에 사용할 수 있다.

## 다음 단계 변경 범위

Stage 2는 다음 파일에 한정한다.

- 신규 `Sources/HostApp/Services/RhwpStudioPagePayload.swift`
- 신규 `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift`
- `Sources/HostApp/Services/RhwpStudioPrintController.swift` renderer 소비 구조로 축소
- 신규 `Tests/HostAppTests/RhwpStudioPagePayloadTests.swift`
- `project.yml` HostAppTests source 반영과 XcodeGen 생성 결과

내부 PDF menu와 toolbar 저장 경로는 Stage 3까지 변경하지 않는다. Stage 2에서는 공용 renderer를 일반 인쇄에 먼저 적용해 SVG→PDF 생성부와 print UI 분리의 회귀를 독립적으로 확인한다.

## 구현계획서 보정

`mydocs/plans/task_m010_455_impl.md`의 두 문장을 실제 bundled 동작에 맞게 보정했다.

- 보정 전 의미: `file:print-to-pdf`가 계속 비활성인 browser print 항목
- 보정 후 의미: static markup은 초기 disabled지만 문서가 열리면 upstream `canExecute: hasDocument`가 활성화하고 browser print를 실행

command 통합, page payload, renderer 책임과 5단계 구성은 조사 결과와 일치해 단계 재분할은 필요하지 않다.

## 본문 변경 정도와 무손실 확인

- 제품 소스: 변경 없음
- bundled `rhwp-studio` asset: 변경 없음
- Xcode project와 의존성: 변경 없음
- architecture: 변경 없음
- 구현계획서: 현재 menu state 설명 2개 문장 보정
- 조사 문서: 이 Stage 1 완료보고서 신규 작성
- 오늘할일: Stage 1 완료보고서 승인 대기로 상태 갱신

read-only 조사와 문서 변경만 수행했으므로 HWP/HWPX 본문과 앱 동작의 무손실 조건에 영향이 없다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `rg -n "file:print-to-pdf\|file:export-pdf"` 관련 HostApp/asset 조회 | 통과. 내부 메뉴 command와 toolbar/native command가 분리된 상태를 확인했다. |
| bundled asset의 `file:print-to-pdf`, `window.print`, `canExecute: hasDocument` 주변 조회 | 통과. upstream browser print ownership을 확인했다. |
| `rg -n "documentPages\|getPageSvg\|exportHwp\|createPDF\|HwpPreviewPDFRenderer" Sources/HostApp` | 통과. bytes export와 SVG print 두 renderer 경로를 확인했다. |
| `shasum -a 256` representative fixture 3개 | 통과. Stage 4 원본 보호 baseline을 기록했다. |
| `pdfinfo -v`, `pdftotext -v` | 통과. Poppler `26.07.0` 확인. |
| `git diff --check` | 통과. 보고서와 관련 문서에 whitespace 오류가 없다. |

이번 단계는 read-only 조사 단계이므로 build와 test는 수행하지 않는다. Stage 2부터 payload unit tests, HostApp build와 일반 print smoke를 수행한다.

## 잔여 위험

- upstream menu state 갱신이 class/aria-disabled 외 다른 attribute나 inline style을 적용하는지는 Stage 3 실제 UI smoke에서 확인해야 한다.
- current page metrics는 DOM scroll size와 SVG rect의 최댓값을 사용한다. SVG viewBox, CSS pixel과 PDF point의 일치 여부는 Stage 2 renderer와 Stage 4 `pdfinfo` 결과로 검증해야 한다.
- `WKWebView.createPDF`가 upstream SVG의 `<text>`를 searchable text로 유지하는지는 actual output이 필요하다. Stage 4에서 `pdftotext`와 Preview 선택을 확인한다.
- 다중 페이지는 전체 SVG 문자열을 native message에 보관한 뒤 순차 render하므로 큰 문서의 memory/time 비용이 남는다. Issue 범위에서는 중복 요청을 막고 page PDF를 누적하되 불필요한 HWP bytes 사본은 제거한다.
- 공용 renderer 전환 뒤에도 일반 print preview가 blank가 아닌지 Stage 2 수동 smoke가 필요하다.

## 다음 단계 영향

Stage 2는 이 보고서의 page payload와 renderer/controller 경계를 구현한다. 내부 menu와 toolbar의 PDF 저장 경로는 변경하지 않고, 일반 인쇄를 공용 renderer의 첫 소비자로 전환해 WebKit lifecycle, page count와 print preview 회귀를 먼저 검증한다.

## 승인 요청

Stage 1 조사와 PDF command·SVG 생성 계약 확정을 완료했다. Stage 2 `공용 page SVG PDF renderer 분리와 인쇄 회귀 보정` 구현 진행 승인을 요청한다.
