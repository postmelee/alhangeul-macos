# Task #455 Stage 3 완료보고서

## 단계 목적

bundled `rhwp-studio`의 `PDF로 저장...` 메뉴와 HostApp toolbar의 PDF 버튼을 알한글이 소유하는 하나의 native save UX로 통합한다. PDF 본문은 HWP bytes와 native bitmap renderer를 거치지 않고 upstream page SVG를 공용 `WKWebView.createPDF` renderer로 변환해 저장한다.

## 구현 결과

### 내부 메뉴와 canonical command 통합

HostBridge의 `nativeCommands`와 `nonMutatingCommands`에 `file:print-to-pdf`를 추가했다. 내부 메뉴 event는 upstream browser print handler보다 먼저 차단하며 다음처럼 정규화된다.

```text
bundled file:print-to-pdf
  -> canonical file:export-pdf
  -> Coordinator.requestPDFExport

toolbar file:export-pdf
  -> Coordinator.requestPDFExport
```

내부 메뉴의 초기 `disabled`/`aria-disabled` 상태를 native command 소유 상태에 맞게 제거하고, browser print 안내 title을 `알한글에서 PDF 파일로 저장합니다.`로 교체했다. 메뉴 label과 접근성 이름은 `PDF로 저장`을 유지한다.

### menu observer 회귀와 보완

최초 구현은 upstream이 menu class와 title을 다시 갱신한 뒤 override를 복원하기 위해 document subtree 전체의 `class`, `aria-disabled`, `title` 속성을 관찰했다. 작업지시자 UI smoke에서 앱 창은 열리지만 `웹폰트 로딩 중...`에서 멈추고 문서 영역과 toolbar가 동작하지 않는 회귀가 확인됐다.

Computer Use로 같은 빌드를 재현해 editor chrome은 나타나지만 문서 로딩이 진행되지 않는 상태를 확인했다. 원인은 document 전체 attribute observer가 editor의 빈번한 상태 변경과 자체 DOM 수정까지 다시 감지하는 반복 갱신이었다.

다음과 같이 보완했다.

- 기존 document observer는 child-list 교체 감지만 유지
- attribute observer는 현재 `file:print-to-pdf` menu element 하나에만 연결
- menu element가 교체되면 child-list observer가 새 요소에 attribute observer를 재연결
- `disabled`, `aria-disabled`, `title`, `aria-label`은 현재 값과 다를 때만 변경
- menu attribute 복원은 `requestAnimationFrame`당 한 번으로 제한

보완 후 자동 검증과 Debug build를 다시 수행했고, 작업지시자 재검증에서 앱 로딩과 native PDF 저장 동작이 정상임을 확인했다.

### SVG page payload 전환

`__alhangeulHostBridgeExportPDFDocument()`는 더 이상 `requestHwpExportPayload`, `exportHwpBase64`, `exportHwp`, base64와 byte count를 사용하지 않는다. 일반 인쇄와 같은 `documentPages()` helper를 호출한다.

```json
{
  "type": "export-pdf-document",
  "fileName": "example.hwpx",
  "pageCount": 3,
  "pages": ["<svg ...>", "<svg ...>", "<svg ...>"]
}
```

`documentPages()`는 editor state를 settle한 뒤 `pageCount`와 page별 `getPageSvg`를 순서대로 요청한다. HWP와 HWPX는 동일한 SVG payload 계약을 사용하므로 HWPX의 PDF 저장에서도 `exportHwp` 중간 변환이 없다.

HWP/HWPX 저장과 공유 경로는 기존 bytes contract를 유지한다.

### coordinator 상태와 save UX

PDF 저장 상태를 다음 enum으로 명시했다.

```text
idle
  -> choosingDestination
  -> collectingPages(destinationURL)
  -> exporting
  -> idle
```

- 문서가 없으면 save panel을 열지 않음
- destination 선택 중, page 수집 중, render/write 중 중복 command 거부
- panel 취소 시 `idle` 복귀
- bridge evaluation 실패와 page 수집 오류에서 pending destination 정리
- 예상된 `collectingPages` 상태의 SVG response만 수락
- destination이 없는 예상 밖 response에서 두 번째 panel을 열지 않음
- render/write 성공 또는 실패 completion에서 controller와 상태 정리
- 성공 URL만 Finder에서 표시

`DocumentPDFExportPanel`은 coordinator가 비동기 sheet로 한 번만 사용한다. 기존 controller의 동기 panel overload는 제거했다.

### SVG PDF controller와 atomic write

`RhwpStudioPDFExportController`는 다음 경로만 소유한다.

```text
RhwpStudioPagePayload
  -> RhwpStudioPagePDFRenderer
  -> PDFDocument.dataRepresentation
  -> %PDF signature 검증
  -> Data.write(.atomic)
  -> destination URL
```

controller에서 `RhwpDocument`, `HwpPreviewPDFRenderer`, page bitmap 생성과 save panel 책임을 제거했다. controller 내부 중복 export도 `exportInProgress` 오류로 거부한다.

## 변경 파일

- 수정 `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
- 수정 `Sources/HostApp/Views/RhwpStudioWebView.swift`
- 수정 `Sources/HostApp/Services/RhwpStudioPDFExportController.swift`
- 수정 `Sources/HostApp/Services/DocumentPDFExportPanel.swift`
- 수정 `Tests/HostAppTests/RhwpStudioHostBridgeScriptTests.swift`
- 신규 `Tests/HostAppTests/RhwpStudioPDFExportControllerTests.swift`
- 수정 `project.yml`
- XcodeGen 생성 결과 `Alhangeul.xcodeproj/project.pbxproj`
- 이 완료보고서와 오늘할일 상태

bundled `rhwp-studio` asset 자체, 일반 인쇄, HWP/HWPX 저장·공유 계약과 원본 문서는 변경하지 않았다.

## 자동 검증 결과

| 검증 | 결과 |
|------|------|
| `xcodegen generate` | 통과. controller test source를 Xcode project에 반영했다. |
| HostAppTests | 통과. 116개 테스트, 실패 0개. |
| bridge command 계약 | 통과. `file:print-to-pdf` capture와 canonical `file:export-pdf`를 확인했다. |
| bridge SVG payload 계약 | 통과. PDF export 함수가 `documentPages()`를 사용하고 HWP bytes field가 없음을 확인했다. |
| menu override observer | 통과. PDF menu element 전용 attribute observer와 child-list 재연결 계약을 확인했다. |
| 실제 PDF export controller | 통과. 2-page portrait/landscape SVG를 임시 destination에 atomic write했다. |
| PDF 형식·본문 | 통과. `%PDF`, 2-page count와 `Portrait export`/`Landscape export` text layer를 확인했다. |
| PDF geometry | 통과. portrait와 landscape media box 방향을 확인했다. |
| controller 중복 요청 | 통과. 첫 render 중 두 번째 export가 `exportInProgress`로 거부됐다. |
| HostApp Debug build | 통과. `CODE_SIGNING_ALLOWED=NO`, `** BUILD SUCCEEDED **`. |
| built app bundled asset | 통과. manifest와 자산이 일치한다. |
| `./scripts/check-no-appkit.sh` | 통과. 공유 Swift 코드에 AppKit/UIKit 의존이 없다. |
| `git diff --check` | 통과. whitespace 오류가 없다. |

HostAppTests 최종 결과는 다음과 같다.

```text
Executed 116 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
```

테스트 실행 중 WebKit 보조 process의 sandbox 진단 로그가 출력됐지만 실제 renderer/controller 테스트와 전체 suite는 정상 완료됐다.

## 의존성 제거 확인

`RhwpStudioPDFExportController.swift`에서 다음 검색 결과는 모두 0건이다.

- `requestHwpExportPayload`
- `exportHwpBase64`
- `exportHwp`
- `base64`, `byteCount`
- `RhwpDocument`
- `HwpPreviewPDFRenderer`

Bridge의 HWP/HWPX 저장과 공유 helper에는 bytes export가 의도적으로 남아 있으나 `exportPDFDocument()` 구간에는 위 항목이 없다.

## 수동 UI smoke 결과

1. 최초 Stage 3 빌드에서 document-wide attribute observer 때문에 앱이 `웹폰트 로딩 중...` 상태에서 멈추는 회귀를 작업지시자와 Computer Use가 확인했다.
2. targeted PDF menu observer로 보완하고 116개 테스트와 HostApp build를 다시 통과했다.
3. 작업지시자가 보완 빌드에서 앱 로딩, 문서 동작과 native PDF 저장 경로가 정상임을 확인했다.

이 확인으로 내부 메뉴와 toolbar가 upstream browser print가 아니라 알한글 save UX를 사용하는 Stage 3 UI 기준을 충족했다.

## 본문 변경 정도와 무손실 확인

- HWP/HWPX 원본 파일: 제품 경로에서 write하지 않음
- current source URL과 source format: PDF 저장 전후 변경하지 않음
- editor clean/dirty 상태: PDF 저장 성공 시에도 mark-clean 또는 source 동기화를 호출하지 않음
- PDF destination: 사용자가 선택한 `.pdf` URL에만 atomic write
- Finder 표시: write 성공 URL에만 수행
- bundled upstream asset: 변경 없음, source와 built app 검증 통과
- 일반 인쇄와 HWP/HWPX 저장·공유: 기존 테스트 통과

## 완료 기준 판단

- bundled PDF menu 활성화와 native capture: 충족
- browser print 안내를 알한글 PDF 저장 안내로 교체: 충족
- 내부 menu와 toolbar의 단일 `requestPDFExport` 진입: 충족
- save panel 단일 소유와 취소·중복·오류 상태 정리: 충족
- HWP/HWPX page SVG payload 사용과 HWP 중간 변환 제거: 충족
- 공용 WebKit renderer와 atomic write 사용: 충족
- 성공 URL만 Finder 표시와 원본/current source 불변: 충족
- 테스트, build와 보완 UI smoke: 충족

## 잔여 위험

- 큰 다중-page 문서는 전체 SVG 문자열을 native message와 renderer에서 보관하므로 memory/time 비용이 남는다.
- bridge가 page 수집을 시작한 뒤 response도 error도 보내지 않는 비정상 hang에는 별도 timeout이 없다.
- 실제 가로·세로 혼합 HWP/HWPX 문서의 PDF geometry는 합성 SVG 자동 테스트로 검증했으며 대표 fixture 수동 검증은 Stage 4에 남아 있다.
- destination permission·disk full과 같은 실제 파일 시스템 실패는 atomic write error로 복구하지만 UI 환경별 smoke는 Stage 4에 남아 있다.

## 다음 단계 영향

Stage 4는 대표 HWP/HWPX fixture로 내부 메뉴와 toolbar 각각의 PDF를 생성해 page count, geometry, searchable text와 original SHA-256/mtime 불변을 자동·수동으로 확인한다. panel 취소와 중복 진입, Finder 표시 및 HWP/HWPX 저장·공유 회귀도 함께 검증한다.

## 승인 요청

Stage 3 `내부 메뉴와 toolbar의 native SVG PDF 저장 통합` 구현과 보완 UI smoke를 완료했다. 완료보고서 승인과 Stage 4 `HWP/HWPX UI·통합·PDF geometry·text·원본 불변 검증` 진행 승인을 요청한다.
