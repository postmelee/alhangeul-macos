# Task #455 구현 계획서

## 작업 개요

- 이슈: #455 `rhwp-studio PDF 저장 메뉴를 SVG 기반 native PDF 내보내기로 통합`
- 마일스톤: v0.1 (`M010`)
- 작업 브랜치: `local/task455`
- 대상 통합 브랜치: `devel`
- 수행계획서: `mydocs/plans/task_m010_455.md`
- 단계 수: 5

현재 toolbar PDF 내보내기는 native `NSSavePanel`, atomic write와 Finder 표시를 사용하지만, upstream editor를 HWP bytes로 다시 export한 뒤 native render tree 기반 page bitmap PDF를 만든다. bundled 파일 메뉴의 `file:print-to-pdf`는 비활성 browser print 항목이라 이 native 경로에도 연결되지 않는다.

반면 일반 인쇄는 upstream embed RPC의 `pageCount`와 `getPageSvg`로 현재 페이지 SVG를 받아 offscreen `WKWebView.createPDF(configuration:)`으로 변환하고 PDFKit으로 합치는 경로를 이미 사용한다. 이번 작업은 이 생성부를 UI 동작에서 분리해 인쇄와 PDF 저장이 함께 사용하도록 만들고, 내부 메뉴와 toolbar의 PDF 저장 요청을 하나의 native command·payload·상태 전이로 통합한다.

## 구현 원칙

1. 내부 `PDF로 저장...`과 toolbar PDF 내보내기는 동일한 native destination 선택과 SVG export 경로를 사용한다.
2. 알한글은 메뉴 interception, `NSSavePanel`, 요청 중복 방지, 오류, atomic write와 Finder 표시를 소유한다.
3. upstream editor는 settle 이후 page count와 페이지별 SVG를 제공하며, HWP/HWPX bytes를 PDF 저장 payload로 사용하지 않는다.
4. PDF 생성기는 page SVG를 offscreen `WKWebView`에 순차 로드하고 각 페이지를 `createPDF`로 변환한 뒤 PDFKit으로 병합한다.
5. 공용 PDF 생성기는 alert, print panel, save panel, 파일 쓰기와 Finder 표시를 소유하지 않는다.
6. 인쇄는 공용 생성 결과를 `PDFDocument.printOperation`에 전달하고, PDF 저장은 같은 결과를 atomic write한다.
7. page count, SVG 개수, 빈 SVG, page metrics와 페이지별 PDF page count를 검증한 뒤에만 완성 PDF를 반환한다.
8. 기존 일반 `file:print` UX, Quick Look/Thumbnail bitmap renderer, HWP/HWPX 저장 exporter를 변경하지 않는다.
9. bundled `rhwp-studio` asset과 upstream embed protocol은 수정하지 않고 injected bridge만 확장한다.
10. `Sources/RhwpCoreBridge`에는 AppKit/WebKit 의존을 추가하지 않는다.
11. `project.yml`을 Xcode project의 원본으로 사용하며 `Alhangeul.xcodeproj`를 직접 편집하지 않는다.

## command 통합 계약

### 진입점

| 사용자 진입점 | upstream command | HostBridge 처리 | native canonical command |
|---------------|------------------|-----------------|--------------------------|
| bundled 파일 메뉴 `PDF로 저장...` | `file:print-to-pdf` | disabled 상태 해제, browser handler 차단 | `file:export-pdf` |
| HostApp toolbar PDF 내보내기 | `file:export-pdf` | 기존 dispatcher 사용 | `file:export-pdf` |
| macOS 일반 인쇄 | `file:print` | 기존 SVG print 요청 유지 | `file:print` |

injected bridge의 `nativeCommands`에는 `file:print-to-pdf`를 포함한다. 메뉴 event capture에서 upstream browser print handler보다 먼저 소비하고 `handleNativeCommand`에서 `file:export-pdf` command message로 정규화한다. Swift coordinator는 진입점에 따른 별도 분기 없이 기존 `requestPDFExport` 하나만 호출한다.

HostApp override 갱신 시 `file:print-to-pdf` 항목에서 `disabled`와 `aria-disabled`를 제거하고 title을 `알한글에서 PDF 파일로 저장합니다.`처럼 실제 동작에 맞는 문구로 바꾼다. upstream DOM 갱신 뒤에도 기존 `MutationObserver`가 같은 override를 다시 적용한다. CSS 변경은 disabled 시각 상태가 class 제거만으로 정리되지 않을 때만 HostApp override stylesheet에 한정한다.

### native 저장 상태

```text
idle
  -> choosingDestination
  -> collectingPageSVG(destination)
  -> renderingPagePDF(destination, pageIndex)
  -> writingAtomically(destination)
  -> revealingInFinder(destination)
  -> idle
```

- destination panel 취소: pending request를 만들지 않고 `idle`
- destination 선택 후 bridge evaluation 실패: pending destination과 controller를 한 번만 정리
- SVG payload validation 실패: 파일을 쓰지 않고 오류 표시 후 `idle`
- WebKit navigation/metrics/`createPDF` 실패: 부분 PDF를 쓰지 않고 오류 표시 후 `idle`
- atomic write 실패: Finder를 표시하지 않고 오류 표시 후 `idle`
- 성공: 완성 PDF만 destination에 atomic write하고 Finder 표시 후 `idle`
- choosing, collecting, rendering 또는 writing 중 추가 PDF command: 새 panel과 renderer를 만들지 않음

## page SVG payload 계약

인쇄와 PDF 저장은 같은 page payload 모델을 사용한다.

```json
{
  "type": "export-pdf-document",
  "fileName": "example.hwpx",
  "pageCount": 3,
  "pages": ["<svg ...>...</svg>", "<svg ...>...</svg>", "<svg ...>...</svg>"]
}
```

일반 인쇄는 message type만 `print-document`이고 나머지 payload는 동일하다. JavaScript helper는 다음 순서로 payload를 만든다.

1. active editor의 `change`와 `blur`를 발생시키고 두 animation frame을 기다린다.
2. `requestRhwp("pageCount")`로 양수 page count를 얻는다.
3. `0..<pageCount`를 순회하며 `requestRhwp("getPageSvg", { page }, 30000)`를 호출한다.
4. file name, page count와 page SVG 배열을 native message로 전달한다.

Swift의 `RhwpStudioPagePayload`는 다음을 검증한다.

- page count가 1 이상인지
- page count와 SVG 배열 개수가 같은지
- 각 SVG가 공백을 제외하고 비어 있지 않은지
- 표시 file name이 없으면 현재 문서 이름 또는 `document.hwp`로 보완 가능한지

PDF export helper에서 `requestHwpExportPayload`, `exportHwpBase64`, `exportHwp`와 base64/byte count 전달을 제거한다. 공유와 HWP/HWPX 저장은 기존 bytes exporter를 계속 사용한다.

## SVG에서 PDF로의 변환 계약

`RhwpStudioPagePDFRenderer`를 HostApp 전용 `@MainActor` 객체로 두고 다음 책임만 갖게 한다.

- 재사용 가능한 offscreen `WKWebView` 구성과 navigation lifecycle 관리
- 페이지별 HTML wrapper에 SVG 삽입
- navigation 완료 후 SVG/DOM metrics 조회
- 유효한 page size로 web view frame과 `WKPDFConfiguration.rect` 설정
- `WKWebView.createPDF(configuration:)` 호출
- 페이지별 결과를 `PDFDocument`로 decode하고 하나의 최종 `PDFDocument`로 병합
- 완료 또는 최초 오류를 정확히 한 번 반환하고 내부 상태 정리

페이지 변환은 입력 순서대로 직렬 처리한다. 각 SVG는 margin·padding이 없는 흰 배경 HTML에 삽입하고, SVG의 실제 layout rect와 document scroll size에서 유한하고 양수인 width/height를 얻는다. width/height가 유효하지 않으면 방향·크기를 임의로 바꾸는 silent fallback보다 명시적 page metrics 오류를 우선한다. 기존 `794x1123` 기본값을 유지해야 하는 호환 사례가 Stage 1에서 확인되면 어떤 SVG에 적용하는지 제한 조건을 단계 보고서에 기록한다.

각 `createPDF` 결과는 PDFKit으로 열 수 있고 정확히 한 page를 가져야 한다. 결과 page의 media box가 유효한지 확인한 뒤 최종 document에 추가한다. 최종 page count가 payload page count와 같을 때만 성공한다. 이 구조로 page별 세로/가로 방향과 서로 다른 page size를 보존한다.

renderer completion은 `Result<PDFDocument, Error>`로 반환한다. renderer는 `NSAlert`, `NSSavePanel`, `NSPrintOperation`, 파일 쓰기와 Finder 표시를 호출하지 않는다.

## controller 책임 분리

### `RhwpStudioPrintController`

- `RhwpStudioPagePayload`를 공용 renderer에 전달한다.
- 성공한 `PDFDocument`로 기존 `PDFDocument.printOperation`을 실행한다.
- print operation 동안 renderer, PDF document와 operation의 수명을 유지한다.
- print 전용 오류 문구와 `NSAlert`는 기존 정책을 유지한다.

### `RhwpStudioPDFExportController`

- `RhwpStudioPagePayload`와 선택된 destination URL을 받는다.
- 공용 renderer 결과에서 유효한 PDF data를 얻는다.
- data가 비어 있거나 PDF representation을 만들 수 없으면 실패한다.
- destination에 `.atomic` option으로 쓰고 성공 URL을 반환한다.
- save panel은 coordinator가 먼저 열므로 controller 내부의 동기식 panel overload는 제거한다.
- Finder 표시는 coordinator가 성공 URL을 받은 뒤 실행한다.

### `RhwpStudioWebView.Coordinator`

- toolbar와 canonical native command의 destination 선택을 `requestPDFExport`로 통합한다.
- destination 선택 후에만 `__alhangeulHostBridgeExportPDFDocument()`를 호출한다.
- `export-pdf-document` response를 bytes가 아니라 `RhwpStudioPagePayload`로 검증한다.
- pending destination과 PDF controller lifetime을 관리하고 성공·실패마다 한 번만 정리한다.
- `print-document`도 동일한 payload parser를 사용하되 print pending state와는 분리한다.

## Stage 1. PDF command와 SVG 생성 계약 확정

### 목표

제품 코드 변경 전에 bundled 메뉴 event, toolbar dispatcher, destination 선택, bytes PDF export와 SVG print 경로를 current `devel` 기준으로 기록하고 공용화 계약을 확정한다.

### 작업

- bundled `file:print-to-pdf` 항목의 disabled class, title과 upstream browser handler를 확인한다.
- injected bridge의 capture listener, `nativeCommands`, override observer와 canonical command 위치를 확인한다.
- toolbar `file:export-pdf`에서 panel, pending destination, bridge helper와 native response까지의 현재 흐름을 기록한다.
- PDF export가 `exportHwp` → `RhwpDocument` → `HwpPreviewPDFRenderer` bitmap 경로를 쓰는 지점을 확인한다.
- print가 `pageCount`/`getPageSvg` → offscreen `WKWebView.createPDF` → PDFKit merge를 쓰는 지점을 확인한다.
- page SVG payload, page metrics, renderer/controller 책임과 오류 경계를 확정한다.
- Stage 4 대표 HWP/HWPX, 단일·다중·가로 fixture와 원본 보호 방법을 확정한다.
- 수행계획 대비 변경 파일 또는 단계 경계가 달라지면 구현계획서를 보정한다.

### 검증 시나리오

- `file:print-to-pdf`가 bundled DOM에는 있으나 native command set에는 없고 비활성임을 확인
- toolbar PDF command만 native destination panel을 여는 현재 상태 확인
- 현재 PDF export helper가 HWP bytes를 native로 전달함을 확인
- 현재 print helper가 편집 settle 후 page SVG 배열을 전달함을 확인
- `RhwpStudioPrintController`만 `WKWebView.createPDF`를 호출함을 확인
- `KTX.hwp`, `hwp-multi-001.hwp`, `hwpx/hwpx-01.hwpx`의 역할과 원본 hash 기록 방식을 확정

### 완료 기준

- 두 PDF 저장 진입점이 canonical `file:export-pdf`로 수렴하는 위치가 결정된다.
- bytes 기반 old path에서 제거할 호출과 유지할 공유/저장 경로가 구분된다.
- 공용 renderer의 input, output, lifecycle과 error contract가 결정된다.
- Stage 2가 변경할 파일과 검증 항목이 확정된다.

### 검증

- `rg -n "file:print-to-pdf|file:export-pdf|exportPDFDocument|requestPDFExport" Sources/HostApp`
- `rg -n "documentPages|getPageSvg|exportHwp|createPDF|HwpPreviewPDFRenderer" Sources/HostApp`
- `rg -n -o '.{0,240}(file:print-to-pdf|printToPdf|window.print).{0,360}' Sources/HostApp/Resources/rhwp-studio/assets/*.js`
- `pdfinfo -v`
- `pdftotext -v`
- `git diff --check`

### 커밋 메시지

- `Task #455 Stage 1: PDF 저장 명령과 SVG 생성 계약 확정`

## Stage 2. 공용 page SVG PDF renderer 분리와 인쇄 회귀 보정

### 목표

page payload validation과 `WKWebView.createPDF` 변환을 인쇄 UI에서 분리하고, 기존 일반 인쇄가 공용 renderer를 사용하도록 전환한다.

### 작업

- Foundation-only `RhwpStudioPagePayload`와 validation error를 추가한다.
- page count mismatch, 빈 page 배열, 빈 SVG와 정상 payload 단위 테스트를 추가한다.
- `RhwpStudioPagePDFRenderer`에 offscreen WebView, HTML wrapper, metrics, page별 `createPDF`, PDFKit merge와 단일 완료 lifecycle을 구현한다.
- 유효하지 않은 metrics, navigation 실패, page PDF decode 실패, page count mismatch를 명시적 오류로 구분한다.
- `RhwpStudioPrintController`에서 WebKit navigation/render 구현을 제거하고 공용 renderer 결과로 print operation만 실행하게 한다.
- print error presenter와 print operation lifetime을 유지한다.
- HostAppTests에 payload source/test를 포함하도록 `project.yml`을 수정하고 XcodeGen으로 project를 재생성한다.

### 검증 시나리오

- 정상 1 page/다중 page payload validation 성공
- 0 page, page count mismatch, whitespace-only SVG validation 실패
- portrait와 landscape metrics가 width/height를 뒤집지 않고 유지됨
- page별 PDF가 정확히 한 page가 아니면 최종 document에 추가하지 않음
- 중간 navigation/`createPDF` 실패 시 completion 1회와 renderer 상태 정리
- 일반 인쇄가 공용 renderer를 거쳐 기존 PDFKit print panel을 표시

### 완료 기준

- `RhwpStudioPrintController`가 직접 `WKNavigationDelegate`와 page merge를 소유하지 않는다.
- 공용 renderer가 UI/파일 저장 책임 없이 page SVG를 `PDFDocument`로 변환한다.
- payload 단위 테스트와 HostApp build가 통과한다.
- 대표 문서의 일반 print preview가 비어 있지 않다.

### 검증

- `xcodegen generate`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task455/stage2-tests CODE_SIGNING_ALLOWED=NO test`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task455/stage2-build CODE_SIGNING_ALLOWED=NO build`
- `scripts/verify-rhwp-studio-assets.sh build.noindex/task455/stage2-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio`
- `./scripts/check-no-appkit.sh`
- 대표 HWP 일반 print panel과 content preview smoke
- `git diff --check`

### 커밋 메시지

- `Task #455 Stage 2: page SVG PDF renderer와 인쇄 경로 공용화`

## Stage 3. 내부 메뉴와 toolbar의 native SVG PDF 저장 통합

### 목표

bundled `PDF로 저장...`과 toolbar를 하나의 destination 선택·SVG payload·공용 renderer·atomic write 경로로 연결하고 HWP bytes 기반 PDF export를 제거한다.

### 작업

- bridge native command와 non-mutating set에 `file:print-to-pdf`를 추가한다.
- HostApp override가 bundled PDF menu의 disabled/aria-disabled 상태와 browser print title을 native 저장 UX에 맞게 보정한다.
- `file:print-to-pdf` event를 canonical `file:export-pdf` command message로 변환한다.
- PDF export helper를 editor settle + page SVG payload 방식으로 변경하고 HWP bytes/base64 fields를 제거한다.
- HostBridgeScript tests에 command interception, canonical command와 page SVG payload assertions를 추가한다.
- coordinator가 `export-pdf-document`를 공용 page payload로 decode하게 하고 print와 parser를 공유한다.
- `RhwpStudioPDFExportController`가 공용 renderer와 atomic write만 수행하도록 교체한다.
- panel은 destination 선택 전에 한 번만 표시하고 취소·중복·bridge 실패·render 실패·write 실패에서 pending 상태를 정리한다.
- 성공 URL만 Finder에서 표시하며 원본 HWP/HWPX와 current source 상태는 변경하지 않는다.
- old PDF export에서 `RhwpDocument`와 `HwpPreviewPDFRenderer` 의존을 제거한다.

### 검증 시나리오

- 내부 menu click과 toolbar action이 모두 `requestPDFExport` 1개 경로로 진입
- 내부 menu title이 browser print 안내가 아닌 알한글 PDF 저장 안내로 표시
- 두 진입점 모두 같은 `NSSavePanel`과 `.pdf` filename 정규화 사용
- HWP/HWPX PDF payload 모두 page SVG이며 HWP bytes/base64 field가 없음
- export path에서 `exportHwp`, `exportHwpBase64`, `RhwpDocument`, `HwpPreviewPDFRenderer` 호출 0건
- panel 취소, 중복 command, bridge evaluation failure, invalid payload와 atomic write failure에서 상태 누수 없음
- 성공 시 유효한 `%PDF` data와 Finder 표시
- 공유와 HWP/HWPX 저장 exporter는 기존 bytes contract 유지

### 완료 기준

- bundled PDF menu가 활성화되고 browser print dialog 대신 native save panel을 연다.
- 내부 menu와 toolbar가 같은 SVG renderer와 atomic write 경로를 사용한다.
- PDF 저장에서 HWP/HWPX bytes 중간 변환과 bitmap renderer 의존이 제거된다.
- 기존 print, share, HWP/HWPX save tests와 HostApp build가 통과한다.

### 검증

- `xcodegen generate`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task455/stage3-tests CODE_SIGNING_ALLOWED=NO test`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task455/stage3-build CODE_SIGNING_ALLOWED=NO build`
- `scripts/verify-rhwp-studio-assets.sh build.noindex/task455/stage3-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio`
- `rg -n "file:print-to-pdf|file:export-pdf|documentPages|getPageSvg" Sources/HostApp Tests/HostAppTests`
- `rg -n "requestHwpExportPayload|exportHwpBase64|HwpPreviewPDFRenderer|RhwpDocument" Sources/HostApp/Services/RhwpStudioPDFExportController.swift Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
- `./scripts/check-no-appkit.sh`
- `git diff --check`

### 커밋 메시지

- `Task #455 Stage 3: native SVG PDF 저장 경로 통합`

## Stage 4. HWP/HWPX PDF 저장 통합 검증

### 목표

실제 WKWebView editor와 native save panel에서 두 진입점, 최신 편집 상태, page geometry, 텍스트 layer, 원본 불변성과 실패 경로를 검증한다.

### 대표 fixture

| fixture | 역할 |
|---------|------|
| `samples/basic/KTX.hwp` | 단일 가로 페이지와 media box 방향 확인 |
| `samples/hwp-multi-001.hwp` | HWP 다중 페이지 page count/nonblank 확인 |
| `samples/hwpx/hwpx-01.hwpx` | HWPX 다중 페이지와 HWP 중간 export 제거 확인 |
| 필요 시 짧은 한글 편집이 가능한 대표 HWP/HWPX 복사본 | 최신 편집 반영과 `pdftotext` 검색 확인 |

모든 편집·저장은 `build.noindex/task455/` 또는 별도 임시 디렉터리의 복사본을 대상으로 하고 repository fixture를 직접 수정하지 않는다. smoke 전후 원본 SHA-256과 수정 시각을 기록한다.

### 작업

- clean derived data에서 전체 HostAppTests와 HostApp Debug build를 실행한다.
- 내부 `PDF로 저장...`과 toolbar PDF 내보내기를 각각 실행해 같은 native panel과 결과 경로를 확인한다.
- HWP와 HWPX 복사본에서 대표 텍스트를 편집한 직후 PDF를 저장한다.
- `pdfinfo`와 PDFKit으로 page count, page size와 portrait/landscape 방향을 확인한다.
- 페이지를 PNG로 rasterize하거나 PDFKit thumbnail을 만들어 각 page가 nonblank인지 확인한다.
- `pdftotext -layout`과 PDFKit search로 대표 한글 text가 검색되는지 확인하고 Preview에서 선택 가능 여부를 확인한다.
- output PDF가 유효하고 원본 HWP/HWPX SHA-256·수정 시각이 유지되는지 확인한다.
- panel 취소, 기존 PDF 덮어쓰기와 의도한 write failure의 사용자 오류·상태 정리를 확인한다.
- 기존 일반 print panel과 content preview를 다시 확인한다.

### 검증 시나리오

- bundled menu HWP export와 toolbar HWP export 결과의 page count/geometry 일치
- bundled menu HWPX export와 toolbar HWPX export 결과의 page count/geometry 일치
- 편집 직후 저장한 PDF에 새 텍스트 반영
- HWP/HWPX original hash와 mtime 불변
- 단일 landscape page의 width > height 유지
- 다중 페이지 PDF page count가 upstream page count와 일치하고 모든 page nonblank
- 대표 한글 text 검색·선택 성공
- 취소 시 output 0건, 실패 시 부분·손상 destination 없음
- 일반 인쇄 preview 회귀 없음

### 완료 기준

- 두 PDF 저장 진입점이 HWP/HWPX에서 동일한 native SVG 경로로 동작한다.
- 현재 편집 상태가 결과에 반영되고 원본 문서는 변경되지 않는다.
- 대표 PDF의 page count, page size·orientation과 nonblank 기준이 통과한다.
- 대표 text가 PDFKit 또는 `pdftotext`에서 검색되고 Preview에서 선택 가능하다.
- 전체 tests, build와 asset 검증이 통과한다.

텍스트 검색·선택이 upstream SVG 표현 때문에 실패하면 bitmap 경로로 되돌리지 않는다. 시각 결과와 PDF 구조를 보존하고 실패 근거를 기록한 뒤 upstream SVG text semantics 후속 이슈 분리 여부를 작업지시자에게 보고한다.

### 검증

- `xcodegen generate`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task455/stage4-tests CODE_SIGNING_ALLOWED=NO test`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task455/stage4-build CODE_SIGNING_ALLOWED=NO build`
- `scripts/verify-rhwp-studio-assets.sh build.noindex/task455/stage4-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio`
- `shasum -a 256` 원본/복사본/output 기록
- `pdfinfo` page count/page size 검사
- `pdftotext -layout` 대표 한글 text 검사
- PDF page raster/thumbnail nonblank 검사
- `./scripts/check-no-appkit.sh`
- `git diff --check`

### 커밋 메시지

- `Task #455 Stage 4: HWP/HWPX SVG PDF 저장 통합 검증`

## Stage 5. PDF ownership 문서와 잔여 제한 정리

### 목표

구현된 command, page SVG renderer, 저장 ownership과 Quick Look/Thumbnail bitmap 경계를 architecture 문서와 최종 인계 자료에 반영한다.

### 작업

- `mydocs/tech/project_architecture.md`에서 HostApp PDF export의 HWP bytes/native bitmap 설명을 page SVG/`WKWebView.createPDF` 구조로 갱신한다.
- 내부 menu와 toolbar의 canonical command, native panel과 pending state를 기록한다.
- upstream page SVG, HostApp renderer, print controller와 export controller의 책임을 구분한다.
- HostApp PDF export와 일반 print는 공용 SVG renderer를 사용하지만 Quick Look/Thumbnail은 기존 render tree bitmap 경로를 유지함을 명시한다.
- HWPX가 `exportHwp`를 거치지 않는 점과 원본 불변 정책을 기록한다.
- page metrics, 대용량 문서 순차 처리, upstream SVG text semantics의 확인 결과와 잔여 제한을 정리한다.
- Stage 1~4 검증 결과를 단계 보고서와 최종 결과보고서 입력으로 정리한다.

### 검증 시나리오

- architecture의 command/payload/state 흐름이 구현과 일치
- PDF export와 Quick Look/Thumbnail renderer 책임이 혼동 없이 구분
- HWP/HWPX bytes exporter가 PDF 경로에 남아 있지 않음
- page count/geometry/text/original invariants와 실패 기준이 문서화됨
- Stage별 명령, 결과와 잔여 위험이 최종 보고서에서 재추적 가능

### 완료 기준

- architecture 문서가 실제 native SVG PDF 경로와 일치한다.
- 알한글과 upstream의 ownership 경계가 명확하다.
- 검증된 text semantics와 잔여 제한이 구분된다.
- 전체 diff와 단계 결과가 최종 보고서 작성 단계에 인계 가능한 상태다.

### 검증

- `rg -n "PDF|page SVG|createPDF|file:print-to-pdf|Quick Look|Thumbnail" mydocs/tech/project_architecture.md mydocs/working/task_m010_455_stage*.md`
- `rg -n "HwpPreviewPDFRenderer|exportHwp|exportHwpBase64" Sources/HostApp/Services/RhwpStudioPDFExportController.swift Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
- `git diff --check`
- Stage 4 전체 검증 결과 재확인

### 커밋 메시지

- `Task #455 Stage 5: native SVG PDF ownership과 제한 정리`

## 단계 승인 게이트

- Stage 1 완료 후 command matrix, current/target payload와 renderer/controller contract를 보고하고 Stage 2 승인을 요청한다.
- Stage 2 완료 후 공용 renderer, payload tests와 일반 인쇄 회귀 결과를 보고하고 Stage 3 승인을 요청한다.
- Stage 3 완료 후 내부 메뉴·toolbar 통합, bytes 경로 제거와 자동 검증 결과를 보고하고 Stage 4 승인을 요청한다.
- Stage 4 완료 후 HWP/HWPX 실제 PDF, page geometry, text layer와 원본 불변 결과를 보고하고 Stage 5 승인을 요청한다.
- Stage 5 완료 후 architecture와 잔여 위험을 보고하고 최종 결과보고서 및 PR 게시 단계 승인을 별도로 요청한다.

## 승인 요청 사항

이 구현계획서의 canonical command, page SVG payload, 공용 `WKWebView.createPDF` renderer와 5단계 구성을 기준으로 Stage 1을 진행해도 되는지 승인을 요청한다. 승인 전에는 HostApp 제품 코드, 테스트 target과 architecture 문서를 변경하지 않는다.
