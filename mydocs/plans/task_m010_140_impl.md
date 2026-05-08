# Issue #140 구현 계획서

## 구현 요약

릴리즈 전 확인된 HostApp viewer, Quick Look/Thumbnail, 인쇄 회귀를 한 번에 정리한다. 변경은 HostApp과 bridge font fallback 정책에 한정하며, `rhwp-studio` upstream core나 Xcode project 직접 수정은 하지 않는다.

## 구현 단계

1. Quick Look/Thumbnail font fallback 회귀 차단
   - `Sources/RhwpCoreBridge/FontFallback.swift`의 주요 한글 serif/sans fallback 정책에서 시스템 기본 font를 먼저 선택한다.
   - bundled Korean font 우선으로 생기는 metrics 차이를 줄여 문서 구조 확인 목적의 preview 안정성을 높인다.

2. WKWebView viewer UI 보정
   - `Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css`에서 `select.sb-ls-select`를 기존 combo override 대상에 포함한다.
   - 줄 높이 dropdown group, select, arrow 높이를 24px 기준으로 고정한다.
   - `Sources/HostApp/Views/DocumentViewerView.swift`에서 오류 상태가 아니면 항상 `RhwpStudioContainerView`를 표시해 앱 첫 화면이 바로 WebView를 로드하도록 한다.

3. HostApp print 권한 보정
   - `Sources/HostApp/HostApp.entitlements`에 `com.apple.security.print`를 추가한다.
   - codesign entitlements로 Release app bundle에 print entitlement가 포함되는지 확인한다.

4. PDFKit 기반 인쇄 경로 보정
   - `RhwpStudioPrintController`에서 `WKWebView.printOperation(with:)` 직접 호출을 제거한다.
   - page SVG를 offscreen WKWebView에 page별로 로드하고 `createPDF(configuration:)`으로 PDF page data를 생성한다.
   - 생성된 page를 `PDFDocument`에 합친 뒤 `PDFDocument.printOperation(for:scalingMode:autoRotate:)`로 표준 macOS print panel을 실행한다.
   - 빈 payload, PDF 변환 실패, print operation 생성 실패는 `NSAlert`로 사용자에게 알린다.

## 검증 항목

- Release HostApp build 성공
- HostApp app bundle entitlements에 `com.apple.security.print` 포함
- `samples/exam_social.hwp` 실행 후 native print panel 표시
- print preview에서 page content 표시
- 이전 blank PDF와 custom print view 확대 문제 분석 결과를 보고서에 기록

## 구현상 주의

- `Sources/RhwpCoreBridge`에는 AppKit/WebKit 의존을 추가하지 않는다.
- `project.yml` 또는 `AlhangeulMac.xcodeproj` 변경 없이 기존 target/resource 구성 안에서 해결한다.
- 인쇄 관련 임시 controller가 print operation 중 해제되지 않도록 `printOperation`과 payload 상태를 controller가 보유한다.
