# Task M010 #140 최종 보고서

## 작업 요약

- 이슈: #140 릴리즈 전 Viewer·Quick Look·인쇄 회귀 보정
- 마일스톤: M010 (`v0.1.0 Viewer 기반`)
- 브랜치: `local/task140`
- 대상 브랜치: `devel-webview`
- 핵심 변경: Quick Look/Thumbnail font fallback 회귀 차단, WKWebView toolbar/첫 화면 보정, HostApp print entitlement와 PDFKit 기반 print path 보정

## 완료 내용

### Quick Look/Thumbnail font fallback

`Sources/RhwpCoreBridge/FontFallback.swift`의 주요 한글 serif/sans fallback 순서를 조정했다.

- 바탕/명조/궁서 계열은 `defaultSerif`를 먼저 사용한다.
- 돋움/고딕 계열은 `defaultSans`를 먼저 사용한다.
- 릴리즈 전 Quick Look/Thumbnail에서는 정확한 font family보다 문서 구조와 레이아웃 안정성을 우선한다.

### WKWebView viewer UI

`Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css`에 줄 높이 dropdown override를 추가했다.

- `select.sb-ls-select`를 기존 combo override 대상에 포함했다.
- 줄 높이 group/select/arrow 높이를 24px 기준으로 맞췄다.
- 오른쪽 dropdown 텍스트가 잘리는 문제를 HostApp 전용 CSS에서 보정했다.

`Sources/HostApp/Views/DocumentViewerView.swift`는 문서가 없는 상태에서도 즉시 `RhwpStudioContainerView`를 표시하도록 바꿨다. 앱을 그냥 실행했을 때 첫 화면이 곧바로 WKWebView를 로드한다.

### HostApp 인쇄

`Sources/HostApp/HostApp.entitlements`에 `com.apple.security.print`를 추가했다. 이 변경으로 macOS sandbox에서 HostApp이 출력 미지원 앱으로 차단되는 문제를 해결했다.

`Sources/HostApp/Services/RhwpStudioPrintController.swift`는 직접 `WKWebView.printOperation(with:)`에 의존하지 않도록 변경했다.

- `rhwp-studio`에서 전달된 page SVG를 offscreen WKWebView에 page별로 로드한다.
- page DOM metrics를 읽어 page 크기에 맞춘 `WKPDFConfiguration`을 만든다.
- `WKWebView.createPDF(configuration:)` 결과를 `PDFDocument`에 page 단위로 합친다.
- 최종 출력은 PDFKit의 `PDFDocument.printOperation(for:scalingMode:autoRotate:)`로 실행한다.
- 빈 문서, PDF 변환 실패, print operation 생성 실패는 사용자 alert로 표시한다.

## 변경 파일

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/HostApp.entitlements` | HostApp sandbox print entitlement 추가 |
| `Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css` | WKWebView 줄 높이 dropdown clipping 보정 |
| `Sources/HostApp/Services/RhwpStudioPrintController.swift` | page SVG -> PDFDocument -> PDFKit print operation 경로로 인쇄 재구성 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | 빈 문서 상태에서도 WKWebView container 즉시 표시 |
| `Sources/RhwpCoreBridge/FontFallback.swift` | Quick Look/Thumbnail layout 안정성 우선 fallback 순서 보정 |
| `mydocs/orders/20260503.md` | #140 완료 항목 추가 |
| `mydocs/plans/task_m010_140.md` | 수행 계획서 |
| `mydocs/plans/task_m010_140_impl.md` | 구현 계획서 |
| `mydocs/report/task_m010_140_report.md` | 최종 보고서 |

## 검증 결과

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Release -derivedDataPath build.noindex/verify-task140/DerivedData CONFIGURATION_BUILD_DIR=build.noindex/verify-task140/xcodebuild -quiet build
```

결과: 성공. Xcode의 CoreSimulator/provisioning 관련 경고는 있었지만 build는 완료됐다.

```bash
codesign -d --entitlements :- build.noindex/verify-task140/xcodebuild/AlhangeulMac.app | plutil -p -
```

결과: `com.apple.security.print => true` 포함 확인.

```bash
open -n -a /Users/melee/Documents/projects/rhwp-mac/build.noindex/verify-task140/xcodebuild/AlhangeulMac.app /Users/melee/Documents/projects/rhwp-mac/samples/exam_social.hwp
```

결과: 이전 검증에서 Release app으로 샘플 문서 실행 후 macOS File > Print panel에서 page content preview가 표시됨을 확인했다.

## 문제 분석 기록

- `/Users/melee/Documents/test.pdf`: print entitlement만 추가하고 기존 WKWebView print operation을 사용한 결과물이다. A4 4페이지가 생성됐지만 각 page content stream이 비어 있었다.
- `/Users/melee/Documents/dsa.pdf`: custom NSView 기반 print view 시도 결과물이다. A4 page 안에 `1029x1490` 수준의 content clip rect가 잡혀 확대/클리핑이 발생했다.
- 따라서 entitlement 누락은 print panel 진입 차단의 원인이지만, blank PDF와 scaling 문제는 별도 print rendering path 문제로 보고 PDFKit 표준 print operation 경로로 정리했다.

## 남은 리스크

- 실제 프린터 드라이버별 출력은 사용자 환경에서 추가 확인이 필요하다.
- font fallback 순서 보정은 릴리즈 전 회귀 차단용이며, HWP font metrics 근본 재현은 후속 upstream/core contract 작업으로 분리해야 한다.
- `rhwp-studio` toolbar class 구조가 upstream에서 바뀌면 HostApp override CSS를 재검토해야 한다.
