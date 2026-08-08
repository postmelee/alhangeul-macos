# Task #455 Stage 2 완료보고서

## 단계 목적

일반 인쇄에 결합돼 있던 page SVG의 WebKit navigation, 페이지 크기 산정, `WKWebView.createPDF` 호출과 PDFKit 병합을 UI·파일 저장 책임이 없는 공용 renderer로 분리한다. 인쇄 컨트롤러는 공용 renderer 결과를 기존 macOS print operation에 연결하는 역할만 담당하도록 축소한다.

내부 `PDF로 저장...` 메뉴와 toolbar의 PDF 저장 경로는 Stage 3 범위이므로 이번 단계에서 변경하지 않는다.

## 구현 결과

### 공용 page payload

신규 `RhwpStudioPagePayload`가 인쇄와 이후 PDF 저장에서 공유할 다음 계약을 구현한다.

- `fileName`, `pageCount`, 순서가 보존된 `pages: [String]` 소유
- `pageCount > 0` 검증
- `pages.count == pageCount` 검증
- whitespace만 있는 SVG 거부와 1부터 시작하는 오류 페이지 번호 제공

`RhwpStudioWebView.Coordinator`의 기존 인쇄 payload parser도 이 모델을 사용하도록 변경했다. Stage 1의 예상 파일 목록에는 parser 변경이 빠져 있었지만, message body 검증을 공용 계약으로 일원화하기 위해 필요한 지원 변경이며 PDF 저장 command나 destination 처리에는 영향을 주지 않는다.

### 공용 SVG PDF renderer

신규 `RhwpStudioPagePDFRenderer`는 HostApp 전용 `@MainActor` 객체로 다음 책임을 소유한다.

- offscreen `WKWebView`와 navigation lifecycle
- SVG page별 HTML wrapper 생성과 순차 loading
- SVG의 명시 width/height, viewBox, rendered rect 순서로 페이지 크기 산정
- 유한한 양수 width/height만 허용
- page별 `WKPDFConfiguration.rect`와 `WKWebView.createPDF` 호출
- page별 PDF 결과가 정확히 한 페이지인지 검증
- media box가 유한한 양수 크기인지 검증
- 입력 순서를 유지한 `PDFDocument` 병합과 최종 page count 검증
- 진행 중 중복 render 거부
- 성공 또는 오류 completion 1회 반환과 payload·누적 PDF 상태 정리

기존 인쇄 코드가 DOM scroll size와 SVG rect의 최댓값을 사용하던 방식은 초기 WebView viewport 높이가 가로 SVG의 높이보다 클 때 결과를 세로 페이지로 부풀릴 수 있었다. 공용 renderer는 SVG 자체 dimension을 기준으로 삼아 가로·세로 방향을 보존한다.

renderer는 alert, print/save panel, destination write와 Finder 표시를 소유하지 않는다.

### 인쇄 컨트롤러 분리

`RhwpStudioPrintController`에서 `WKNavigationDelegate`, HTML 생성, metrics 계산, `createPDF`와 page merge 코드를 제거했다. 현재 컨트롤러는 다음 인쇄 전용 책임만 가진다.

- 공용 renderer 호출
- 반환된 `PDFDocument`의 `printOperation` 생성
- job title, print panel과 progress panel 설정
- 인쇄 오류 alert와 completion 처리

인쇄 panel이 열려 있는 동안 전체 SVG payload를 불필요하게 보관하지 않도록 file name만 별도로 캡처한다.

### Stage 2.1 인쇄 방향 보완

작업지시자의 최초 수동 smoke에서 KTX 가로 문서가 세로 용지 안에서 90도 회전한 상태로 표시됐다. 같은 빌드에서 9-page 세로 문서는 세로 방향과 page count가 정상임을 확인했다. renderer의 PDF media box 방향은 보존됐지만, `RhwpStudioPrintController`가 `NSPrintInfo.shared`의 기본 세로 orientation을 그대로 사용한 것이 원인이었다.

첫 페이지만 기준으로 job orientation을 설정하면 페이지마다 방향이 다른 문서를 잘못 강제할 수 있으므로 `RhwpStudioPrintOrientationPolicy`를 별도로 추가해 전체 PDF 페이지를 분류한다.

- 모든 비정사각형 페이지가 가로이면 `.landscape`로 초기화
- 모든 비정사각형 페이지가 세로이면 `.portrait`로 초기화
- 가로·세로가 혼합되면 orientation을 반환하지 않아 사용자의 현재 job 설정을 보존
- 정사각형 페이지는 방향 판정에 영향을 주지 않음
- 모든 경우 기존 `autoRotate: true`를 유지

수정된 Debug 앱에서 작업지시자가 KTX 인쇄 패널을 다시 확인해 가로 방향 보완이 반영된 것을 확인했다.

### 프로젝트와 테스트 구성

- `project.yml`의 HostAppTests source에 공용 payload와 renderer를 추가했다.
- `xcodegen generate`로 `Alhangeul.xcodeproj/project.pbxproj`를 재생성했다.
- payload validation 단위 테스트 4개를 추가했다.
- 실제 offscreen `WKWebView.createPDF`를 실행하는 renderer 테스트 2개를 추가했다.
- 전체 가로, 전체 세로, 혼합 방향, 정사각형과 empty document를 검증하는 orientation policy 테스트 5개를 추가했다.

## 변경 파일

- 신규 `Sources/HostApp/Services/RhwpStudioPagePayload.swift`
- 신규 `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift`
- 신규 `Sources/HostApp/Services/RhwpStudioPrintOrientationPolicy.swift`
- 수정 `Sources/HostApp/Services/RhwpStudioPrintController.swift`
- 수정 `Sources/HostApp/Views/RhwpStudioWebView.swift`
- 신규 `Tests/HostAppTests/RhwpStudioPagePayloadTests.swift`
- 신규 `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift`
- 신규 `Tests/HostAppTests/RhwpStudioPrintOrientationPolicyTests.swift`
- 수정 `project.yml`
- XcodeGen 생성 결과 `Alhangeul.xcodeproj/project.pbxproj`
- 이 완료보고서와 오늘할일 상태

bundled `rhwp-studio` asset, HostBridge PDF command, `RhwpStudioPDFExportController`, HWP/HWPX 저장·공유 경로와 원본 문서는 변경하지 않았다.

## 자동 검증 결과

| 검증 | 결과 |
|------|------|
| `xcodegen generate` | 통과. `project.yml` 변경을 Xcode project에 반영했다. |
| HostAppTests | 통과. 111개 테스트, 실패 0개. |
| 실제 WebKit renderer 테스트 | 통과. 합성 portrait/landscape SVG 2개가 2-page PDF로 생성되고 방향이 보존됐다. |
| PDF signature와 text layer | 통과. `%PDF` signature와 `Portrait`, `Landscape` 추출 문자열을 확인했다. |
| PDFKit print operation 생성 | 통과. renderer 결과에서 `PDFDocument.printOperation`을 생성할 수 있다. |
| 인쇄 방향 정책 테스트 | 통과. 전체 가로/세로만 orientation을 설정하고 혼합 방향은 강제하지 않는다. |
| HostApp Debug build | 통과. `CODE_SIGNING_ALLOWED=NO`, `** BUILD SUCCEEDED **`. |
| built app의 bundled asset 검증 | 통과. `Alhangeul.app/Contents/Resources/rhwp-studio` manifest와 자산이 일치한다. |
| `./scripts/check-no-appkit.sh` | 통과. 공유 Swift 코드에 AppKit/UIKit 의존이 없다. |
| `git diff --check` | 통과. whitespace 오류가 없다. |

HostAppTests 최종 결과는 다음과 같다.

```text
Executed 111 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
```

테스트 실행 중 WebKit 보조 process가 sandbox의 LaunchServices, RunningBoard와 linkd에 접근하지 못했다는 진단 로그가 출력됐지만 renderer 테스트와 전체 test suite는 정상 완료됐다.

## 수동 UI smoke 결과

Computer Use 자동 키 입력은 macOS가 `Computer Use was not approved to use Alhangeul`로 앱 제어를 거부해 작업지시자가 Debug 앱의 실제 print panel을 직접 검증했다.

| 문서 | 최초 결과 | 보완 후 결과 |
|------|-----------|--------------|
| `samples/basic/KTX.hwp` | 실패. 세로 용지 안에서 가로 본문이 90도 회전해 표시됨 | 통과. 전체 페이지 방향 정책 적용 후 가로 인쇄 방향 보완 확인 |
| 작업지시자가 함께 확인한 9-page 세로 문서 | 통과. 세로 preview와 본문 표시 확인 | 기존 세로 정책 단위 테스트와 전체 회귀 테스트 통과 |

최초 실패는 Stage 2 완료로 간주하지 않고 Stage 2.1 보완으로 처리했다. 보완 빌드는 제품과 동일한 renderer와 print operation 경로를 사용하며, 작업지시자의 재검증 확인 뒤 이 보고서에 최종 반영했다.

## 본문 변경 정도와 무손실 확인

- HWP/HWPX 원본 파일: 접근·수정 없음
- current document source state: 변경 없음
- bundled upstream asset: 변경 없음, source와 built app 검증 통과
- 일반 인쇄: SVG payload 계약과 renderer 구현만 교체
- PDF 저장: 기존 HWP bytes/native bitmap 경로 유지
- HWP/HWPX 저장과 공유: 변경 없음

이번 단계는 destination write를 수행하지 않으므로 원본 덮어쓰기와 Finder 표시 동작에 영향을 주지 않는다.

## 완료 기준 판단

- `RhwpStudioPrintController`에서 WebKit navigation과 page merge 책임 제거: 충족
- 공용 renderer가 UI/파일 저장 책임 없이 page SVG를 `PDFDocument`로 변환: 충족
- payload 단위 테스트와 HostApp build 통과: 충족
- 대표 문서의 일반 print preview nonblank 시각 확인: 충족
- 전체 가로 KTX 문서의 print orientation 확인: Stage 2.1 보완 후 충족
- 혼합 방향 문서의 job orientation 비강제 단위 테스트: 충족

자동 WebKit PDF 생성 결과의 page geometry·text layer, PDFKit print operation과 실제 print panel을 함께 확인했다.

## 잔여 위험

- 실제 upstream 문서 SVG가 사용하는 CSS unit, font와 외부 resource가 합성 SVG와 다를 수 있다.
- 실제 가로·세로 혼합 문서의 한 print job 동작은 단위 정책만 검증했으며 UI smoke가 남아 있다.
- 다중 페이지 문서는 전체 SVG 문자열을 payload로 보유하므로 문서 규모에 따른 memory/time 비용이 남는다.
- 내부 메뉴와 toolbar는 아직 서로 다른 기존 경로이며, PDF 저장은 여전히 HWP bytes와 bitmap renderer를 사용한다.

## 다음 단계 영향

Stage 3는 이번 단계의 `RhwpStudioPagePayload`와 `RhwpStudioPagePDFRenderer`를 PDF 저장 경로에서 재사용한다. 구체적으로 bundled `file:print-to-pdf`와 toolbar `file:export-pdf`를 canonical native command로 통합하고, destination 선택 뒤 page SVG payload를 수집해 공용 renderer와 atomic write로 연결한다.

HWPX도 `exportHwp` 중간 변환 없이 upstream page SVG를 사용하게 되며, 기존 일반 인쇄는 이번 단계의 공용 renderer 경로를 유지한다.

## 승인 요청

Stage 2 `공용 page SVG PDF renderer 분리와 인쇄 회귀 보정` 및 Stage 2.1 `전체 페이지 기반 인쇄 방향 보완` 구현과 검증을 완료했다. 완료보고서 승인과 Stage 3 `내부 메뉴와 toolbar의 native SVG PDF 저장 통합` 진행 승인을 요청한다.
