# Task #460 구현 계획서

## 작업 개요

- 이슈: #460 `문서 유래 SVG의 PDF·인쇄 WebView 보안 hardening 검증 및 적용`
- 마일스톤: v0.4 (`M040`)
- 작업 브랜치: `local/task460`
- 대상 통합 브랜치: `devel`
- 수행계획서: `mydocs/plans/task_m040_460.md`
- 단계 수: 5

PR #458에서 PDF 저장과 일반 인쇄는 현재 editor의 page SVG를 `RhwpStudioPagePDFRenderer`에 전달하고, 전용 offscreen `WKWebView.createPDF` 결과를 공유하도록 통합됐다. 현행 renderer는 SVG 문자열을 HTML body에 직접 넣고 content JavaScript를 활성화한 뒤 page world에서 metrics script를 실행한다. 이 작업은 문서 유래 SVG를 능동 콘텐츠 가능성이 있는 입력으로 취급해 WebView 권한과 HTML resource policy를 최소화하면서 page geometry, searchable text와 PDFKit 인쇄 동작을 유지한다.

## 조사 결과와 구현 근거

### 현재 renderer 경계

`RhwpStudioPagePDFRenderer`는 다음 순서로 동작한다.

1. `WKWebViewConfiguration`에서 popup을 비활성화하고 content JavaScript를 활성화한다.
2. `RhwpStudioPagePDFHTML.pageHTML(for:)`이 `<style>`과 raw page SVG를 하나의 HTML 문자열로 만든다.
3. `loadHTMLString(..., baseURL: nil)`로 페이지를 로드한다.
4. navigation 완료 후 `evaluateJavaScript`로 root SVG width, height, viewBox와 bounding rect를 읽는다.
5. WebView frame과 `WKPDFConfiguration.rect`를 설정해 `createPDF`를 호출한다.
6. page별 단일 PDF를 PDFKit으로 최종 `PDFDocument`에 합친다.

PDF 저장과 인쇄 controller는 이 renderer의 결과만 사용하므로, 보안 정책은 두 사용자 경로에 동시에 적용된다. Quick Look/Thumbnail과 main editor WebView는 이 경로를 사용하지 않는다.

### WebKit 공식 API 계약

현재 project deployment target은 macOS 12.0이다. 설치된 macOS SDK WebKit 공개 헤더에서 다음 계약을 확인했다.

- `WKWebpagePreferences.allowsContentJavaScript`는 macOS 11.0부터 제공된다.
- 이 값을 `false`로 두면 inline `<script>`, 외부 script, `javascript:` URL 등 web content가 참조하는 JavaScript가 실행되지 않는다.
- content JavaScript가 꺼져도 앱은 `WKWebView.evaluateJavaScript`, content world overload, `callAsyncJavaScript`와 `WKUserScript`를 계속 실행할 수 있다.
- `WKContentWorld.defaultClient`는 page content world와 전역 상태를 분리하면서 DOM과 built-in DOM API를 조작할 수 있다.
- `WKWebsiteDataStore.nonPersistent()`를 사용한 WebView는 website data를 파일 시스템에 기록하지 않는다.

따라서 metrics 측정을 Swift XML parser로 교체할 필요 없이 content JavaScript를 끄고, HostApp metrics script를 `defaultClient` content world에서 실행하는 방식을 1차 구현안으로 확정한다. deployment target보다 낮은 macOS 11 availability를 다시 검사하는 `#available(macOS 11.0, *)` 분기는 제거한다.

### CSP와 resource 차단 근거

`WKNavigationDelegate`는 top-level과 frame navigation을 제어하지만 image, font, CSS URL 같은 모든 subresource 요청을 관측하는 API가 아니다. 따라서 다음 방어선을 분리한다.

1. content JavaScript 비활성화: SVG script, event handler와 `javascript:` 실행 차단
2. HTML meta CSP: subresource와 script/connect/frame/object/media/worker/form/base 권한 기본 거부
3. navigation policy: 초기 renderer 문서 외 top-level·subframe·new-window navigation 취소
4. non-persistent data store: renderer 세션의 website data 디스크 기록 방지
5. 실제 WebKit 통합 테스트: 합성 SVG가 loopback HTTP endpoint에 요청하지 않는지 검증

1차 CSP 후보는 다음과 같다.

```text
default-src 'none';
script-src 'none';
connect-src 'none';
frame-src 'none';
object-src 'none';
media-src 'none';
worker-src 'none';
manifest-src 'none';
base-uri 'none';
form-action 'none';
style-src 'unsafe-inline';
img-src data:;
font-src data:;
```

wrapper의 inline style과 upstream SVG의 embedded bitmap/font 보존을 위해 `style-src 'unsafe-inline'`, `img-src data:`, `font-src data:`만 예외 후보로 둔다. HTTP/HTTPS, `blob:`, file URL과 임의 custom scheme은 허용하지 않는다. Stage 1에서 실제 bundled SVG 생성 코드와 대표 문서 결과를 조사해 data image/font 필요 범위를 확인하고, 필요하지 않은 directive는 더 좁힌다.

## 구현 원칙

1. 문서 유래 page SVG는 trusted executable markup이 아니라 정적 렌더 입력으로 취급한다.
2. content JavaScript와 외부 resource는 기본 거부하고, 실제 PDF 충실도에 필요한 수동 콘텐츠만 명시적으로 허용한다.
3. HostApp metrics script는 page world가 아닌 `WKContentWorld.defaultClient`에서 실행한다.
4. page SVG 문자열을 범용 sanitizer로 재작성하지 않고 WebKit capability와 document policy를 제한한다.
5. renderer는 기존 page count, geometry, text layer, sequential conversion과 completion 계약을 유지한다.
6. security failure는 silent permission 확대보다 명시적 render 실패 또는 차단을 우선한다.
7. CSP 정적 문자열 검사만으로 완료하지 않고 실제 WKWebView에서 script sentinel과 loopback network 요청 0건을 검증한다.
8. 외부 인터넷, 공개 endpoint와 DNS에 의존하지 않는 자동 테스트를 사용한다.
9. main editor WebView, upstream bundle, `rhwp` core, Quick Look/Thumbnail과 Issue #459 lifecycle은 변경하지 않는다.
10. `project.yml`을 Xcode project 원본으로 사용하고 `Alhangeul.xcodeproj`를 직접 편집하지 않는다.

## WebView 보안 계약

### configuration

`RhwpStudioPagePDFRenderer`가 만드는 WebView configuration은 다음을 만족해야 한다.

- `websiteDataStore = .nonPersistent()`
- `preferences.javaScriptCanOpenWindowsAutomatically = false`
- `defaultWebpagePreferences.allowsContentJavaScript = false`
- 불필요한 user script, script message handler, URL scheme handler 없음
- renderer 외부에서 configuration이나 WebView를 공유하지 않음

content rule list는 기본안에 넣지 않는다. CSP 통합 테스트에서 macOS 12 지원 범위의 외부 subresource 차단이 불충분하다고 확인될 때만 Stage 3 보완안으로 사용한다. `WKContentRuleListStore.default()`는 compile lifecycle과 저장 위치를 추가하므로, 도입할 경우 renderer 시작 전 readiness와 비영구 store 위치를 별도로 설계하고 근거를 Stage 3 보고서에 남긴다.

### HTML wrapper

`RhwpStudioPagePDFHTML.pageHTML(for:)`은 CSP meta를 charset 다음, untrusted SVG보다 앞에 배치한다. SVG가 body 밖 markup을 주입하더라도 먼저 적용된 CSP를 완화할 수 없도록 policy는 단일 상수에서 생성한다.

- `<base>`를 삽입해도 `base-uri 'none'`으로 무효화
- `<form>` 제출은 `form-action 'none'`
- `<script>`와 event handler는 content JavaScript false + `script-src 'none'`
- `<iframe>`, `<object>`, media와 worker는 전용 directive로 거부
- `<image>`, CSS URL과 font는 `data:` 이외 scheme 거부
- inline wrapper CSS와 SVG presentation/style은 유지

HTML 전체나 SVG를 escape하면 SVG 자체가 렌더되지 않으므로 raw insertion은 유지하되, 실행·resource capability를 wrapper policy에서 차단한다.

### HostApp metrics 실행

기존 `pageMetricsScript`의 DOM 계산 우선순위는 유지한다.

1. percentage가 아닌 유효한 explicit width/height resolved value
2. 양수 viewBox width/height
3. 양수 bounding client rect
4. 그 외 invalid metrics 오류

호출은 `evaluateJavaScript(_:in:in:completionHandler:)`와 `.defaultClient` content world를 사용한다. content JavaScript가 비활성화돼도 HostApp script는 실행된다는 SDK 계약을 통합 테스트로 재확인한다. app-owned script 결과가 실패할 때 content JavaScript를 다시 켜는 fallback은 두지 않는다.

### navigation

renderer의 navigation policy는 초기 `loadHTMLString`에 필요한 내부 main-frame navigation만 허용하고 다음을 취소한다.

- HTTP/HTTPS와 file URL top-level navigation
- subframe navigation
- `targetFrame == nil`인 new-window 요청
- SVG의 `<a>`, meta refresh, form 또는 `javascript:`로 발생한 후속 navigation

`didFinish`/`didFail` generation과 중복 callback 수명 보강은 Issue #459 범위이므로 이 작업에서 일반화하지 않는다. 다만 정책 취소가 정상 초기 load를 실패시키거나 completion을 중복 호출하지 않는 최소 회귀 테스트는 포함한다.

## 테스트 설계

### script와 event handler

합성 SVG는 PDF에 `SAFE`라는 text node를 포함하고 `<script>`, root `onload`, image `onload`가 실행되면 text를 `EXECUTED`로 바꾸도록 구성한다. renderer 결과에서 `SAFE`가 검색되고 `EXECUTED`가 없으면 content JavaScript 차단과 HostApp metrics 실행을 한 경로에서 확인할 수 있다.

별도로 `javascript:` URL과 `foreignObject` 안의 HTML event handler를 포함해 page content script가 실행되지 않는지 확인한다. 테스트는 product WebView에 script message handler를 추가하지 않아 공격 표면을 바꾸지 않는다.

### 외부 resource와 navigation

`Network.framework`의 `NWListener`로 `127.0.0.1` 임시 port에 test-local HTTP endpoint를 열고 요청 수를 기록한다. HostAppTests는 이미 Network framework를 링크한다. 합성 SVG/HTML에 다음 참조를 넣고 renderer가 성공한 뒤 짧은 안정화 구간까지 요청 수 0건을 확인한다.

- `<image href="http://127.0.0.1:PORT/image.png">`
- `<use href="http://127.0.0.1:PORT/sprite.svg#id">`
- inline style 또는 `<style>`의 `url(http://127.0.0.1:PORT/...)`
- iframe/object와 meta refresh 또는 link navigation

`URLProtocol`은 WKWebView networking process 요청을 신뢰성 있게 가로채지 못할 수 있으므로 보안 완료 조건에 사용하지 않는다. loopback listener 준비 실패나 port race는 요청 0건 성공으로 간주하지 않고 테스트 자체 실패로 처리한다.

### data와 blob

- known-good `data:image/png;base64,...` fixture가 PDF raster에 남는지 확인
- `data:image/svg+xml,...` 중첩 SVG의 script/event가 실행되지 않는지 확인
- literal `blob:` 참조는 허용되지 않고 외부 요청·navigation을 만들지 않는지 확인
- upstream 대표 문서의 image와 text가 CSP 적용 전 기준과 비교해 누락되지 않는지 확인

### PDF·인쇄 회귀

- synthetic portrait `200 × 300`, landscape `300 × 200`, mixed 2-page media box 유지
- page count와 `%PDF` signature 유지
- PDFKit text extraction에서 한글·영문 sentinel 확인
- page raster nonblank와 embedded data image 존재 확인
- `PDFDocument.printOperation(... autoRotate: true)` 생성
- `RhwpStudioPrintOrientationPolicy`의 전체 세로·전체 가로·혼합 정책 회귀
- KTX 가로 1쪽, 대표 HWP/HWPX 9쪽의 page count, geometry, text, nonblank raster 비교
- 실제 인쇄 패널에서 세로·가로·혼합 preview 방향 확인

## 예상 변경 파일

- `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift`
- `Sources/HostApp/Services/RhwpStudioPagePDFSecurityPolicy.swift` (CSP/navigation 정책을 분리할 때 신규)
- `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift`
- `Tests/HostAppTests/RhwpStudioPagePDFSecurityPolicyTests.swift` (pure policy가 분리될 때 신규)
- `Tests/HostAppTests/RhwpStudioPagePDFNetworkProbe.swift` (loopback helper 분리가 필요할 때 신규)
- `project.yml` (HostAppTests 신규 production source 명시 시)
- `Alhangeul.xcodeproj/project.pbxproj` (`xcodegen generate` 결과만)
- `mydocs/tech/project_architecture.md`
- `mydocs/working/task_m040_460_stage1.md` ~ `task_m040_460_stage5.md`
- `mydocs/report/task_m040_460_report.md`
- `mydocs/orders/20260808.md`

테스트 helper는 가능하면 test target 안에 두고 production API를 늘리지 않는다. CSP·navigation policy가 renderer 내부 private 구현으로도 명확하면 별도 production 파일을 만들지 않는다. 파일 경계는 Stage 1 결과에 따라 확정한다.

## Stage 1. WebKit·upstream SVG 보안 계약 확정

### 목표

production code 변경 전에 SDK 계약, 현행 renderer의 trust boundary, CSP directive와 upstream SVG resource 요구를 확정한다.

### 작업

- macOS 12 deployment target과 WebKit header availability를 기록한다.
- `allowsContentJavaScript = false`에서도 app-owned JavaScript와 default client world DOM 접근이 가능한 공식 계약을 확인한다.
- 현행 configuration, HTML wrapper, metrics, navigation과 completion 흐름을 조사한다.
- bundled SVG 생성 코드와 대표 HWP/HWPX page 결과에서 image, font, style, data/blob/external URL 사용 여부를 조사한다.
- CSP 1차 후보를 directive별로 검토하고 inline style/data image/font의 최소 예외를 확정한다.
- navigation delegate가 담당할 top-level/subframe 범위와 CSP가 담당할 subresource 범위를 구분한다.
- loopback `NWListener` test helper의 lifecycle, timeout과 요청 0건 판정 조건을 확정한다.
- 수행계획 대비 변경 파일과 Stage 경계가 달라지면 이 구현계획서를 보정한다.

### 검증 시나리오

- macOS SDK header에 content JavaScript false와 app evaluate JavaScript의 독립 계약이 존재함
- default client world에서 page DOM 접근 가능 계약 확인
- non-persistent store가 file system write를 하지 않는 계약 확인
- current renderer만 PDF/print 공용 offscreen WebView를 소유함
- main editor와 Quick Look/Thumbnail이 변경 범위 밖임
- 실제 SVG 요구에 근거 없는 external/blob 허용 directive가 없음

### 완료 기준

- content JavaScript, metrics content world, CSP, navigation과 data store의 책임이 확정된다.
- data URI 최소 허용 범위와 blob/HTTP/HTTPS 거부가 근거와 함께 기록된다.
- Stage 2 production 변경 파일과 Stage 3 network test 구조가 확정된다.
- `_stage1.md` 보고서와 필요한 구현계획 보정이 완료된다.

### 검증

- `rg -n "allowsContentJavaScript|evaluateJavaScript|defaultClientWorld" <macOS SDK WebKit headers>`
- `rg -n "RhwpStudioPagePDFRenderer|pageHTML|pageMetricsScript|createPDF" Sources/HostApp Tests/HostAppTests`
- `rg -n "data:image|data:font|blob:|https?://|<image|@font-face" Sources/HostApp/Resources/rhwp-studio/assets`
- 대표 SVG 조사 결과와 허용 scheme 표 대조
- `git diff --check`

### 커밋 메시지

- `Task #460 Stage 1: page SVG WebKit 보안 계약 확정`

## Stage 2. content JavaScript·CSP 격리 구현

### 목표

renderer WebView를 비영구·content JavaScript 비활성 configuration으로 바꾸고, CSP와 default client world metrics를 적용한다.

### 작업

- `WKWebsiteDataStore.nonPersistent()`를 configuration에 적용한다.
- `defaultWebpagePreferences.allowsContentJavaScript = false`를 직접 설정하고 불필요한 availability 분기를 제거한다.
- HTML wrapper에 확정된 CSP meta를 untrusted SVG보다 먼저 삽입한다.
- metrics evaluation을 `WKContentWorld.defaultClient`에서 실행한다.
- result-based WebKit callback을 기존 exactly-once completion과 error mapping에 맞게 연결한다.
- script, event handler, `javascript:`와 nested data SVG sentinel fixture를 추가한다.
- CSP 문자열과 HTML 배치가 drift하지 않도록 pure assertion을 추가한다.
- 신규 production helper가 생기면 `project.yml` HostAppTests source를 갱신하고 project를 재생성한다.

### 검증 시나리오

- inline `<script>`, root/image event handler와 `javascript:`가 text sentinel을 바꾸지 않음
- content JavaScript false에서도 default client metrics가 정상 반환됨
- explicit width/height, viewBox와 bounding rect 우선순위 유지
- embedded data PNG와 searchable text가 PDF에 유지됨
- invalid metrics와 WebContent process termination의 기존 실패 completion 유지

### 완료 기준

- production renderer에 content JavaScript를 켜는 코드가 없다.
- CSP가 모든 untrusted SVG보다 먼저 적용된다.
- app-owned metrics는 isolated content world에서 정상 동작한다.
- script/event 합성 SVG와 기존 renderer tests가 통과한다.

### 검증

- `xcodegen generate`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task460/stage2-tests CODE_SIGNING_ALLOWED=NO test`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task460/stage2-build CODE_SIGNING_ALLOWED=NO build`
- `scripts/verify-rhwp-studio-assets.sh build.noindex/task460/stage2-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio`
- `./scripts/check-no-appkit.sh`
- `rg -n "allowsContentJavaScript = true|#available\(macOS 11" Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift`
- `git diff --check`

### 커밋 메시지

- `Task #460 Stage 2: SVG content JavaScript와 CSP 격리`

## Stage 3. 외부 resource·navigation 차단 검증

### 목표

CSP가 HTTP/HTTPS subresource 요청을 실제로 차단하고 renderer 외 navigation이 발생하지 않음을 WebKit 통합 테스트로 증명한다.

### 작업

- 초기 renderer load만 허용하는 navigation policy를 추가한다.
- new-window, subframe와 HTTP/HTTPS/file/custom scheme navigation을 취소한다.
- test-local `NWListener` request probe를 구현하고 준비 완료 후 SVG를 render한다.
- image, use, CSS URL, iframe/object, meta refresh fixture를 추가한다.
- renderer 성공과 요청 수 0건을 함께 검증한다.
- CSP만으로 차단되지 않는 macOS 12 경로가 확인되면 content rule list 또는 더 좁은 공개 WebKit 정책을 추가한다.
- 정책 취소가 renderer completion을 중복 호출하거나 정상 initial load를 막지 않는지 확인한다.

### 검증 시나리오

- HTTP/HTTPS image/use/style/font 참조의 loopback 요청 0건
- iframe/object/connect와 meta refresh가 navigation/request를 만들지 않음
- target frame 없는 새 창 요청이 허용되지 않음
- 정상 inline SVG page는 기존과 동일하게 PDF 변환 성공
- listener 미준비·port bind 실패는 security success가 아니라 test failure로 처리

### 완료 기준

- 합성 SVG의 외부 HTTP/HTTPS 요청이 실제 WKWebView에서 0건이다.
- renderer가 허용하는 navigation 조건이 코드와 테스트에 명시된다.
- 추가 WebKit 방어선이 필요하면 도입 근거와 lifecycle이 Stage 보고서에 기록된다.
- 외부 인터넷 없이 HostAppTests가 반복 통과한다.

### 검증

- targeted external resource/navigation HostAppTests 반복 실행
- 전체 `HostAppTests`
- HostApp Debug build
- `rg -n "http://|https://|blob:|default-src|connect-src|frame-src|object-src" Sources/HostApp/Services Tests/HostAppTests`
- `./scripts/check-no-appkit.sh`
- `git diff --check`

### 커밋 메시지

- `Task #460 Stage 3: SVG 외부 resource와 navigation 차단`

## Stage 4. PDF·인쇄 보안 회귀 검증

### 목표

강화된 policy가 synthetic page와 실제 HWP/HWPX의 geometry, text, image와 인쇄 방향을 손상하지 않는지 통합 검증한다.

### 대표 fixture

- synthetic portrait `200 × 300`
- synthetic landscape `300 × 200`
- synthetic mixed portrait/landscape 2-page
- script/event/external/data/blob 악성 합성 SVG
- `samples/basic/KTX.hwp` 가로 1-page
- `samples/hwp-multi-001.hwp` 또는 PR #458에서 사용한 대표 다중 HWP
- `samples/hwpx/hwpx-01.hwpx` 대표 9-page HWPX

실제 경로와 sample 이름은 저장소 존재 여부를 Stage 1에서 재확인하고, 원본 SHA-256을 기록한 복사본만 사용한다.

### 작업

- synthetic page의 media box, page count, text와 raster assertions를 보강한다.
- data PNG/font가 필요한 실제 문서의 시각 요소가 CSP 적용 뒤 유지되는지 비교한다.
- toolbar와 내부 menu PDF 저장이 동일한 hardened renderer를 사용하는지 확인한다.
- 일반 인쇄가 같은 renderer 결과와 기존 orientation policy를 유지하는지 확인한다.
- 세로·가로·혼합 문서의 실제 인쇄 패널 preview를 확인한다.
- 원본 HWP/HWPX bytes, current source와 dirty state가 PDF/print smoke에서 변경되지 않는지 확인한다.

### 검증 시나리오

- KTX PDF media box가 가로이고 회전된 세로 축소 결과가 아님
- 대표 HWP/HWPX page count와 각 page 크기가 PR #458 기준을 유지
- 합성/실문서 text가 PDFKit 또는 `pdftotext -layout`에서 검색됨
- page raster가 nonblank이며 embedded image가 누락되지 않음
- mixed document는 job orientation을 강제하지 않고 PDFKit auto-rotate 유지
- print panel preview와 저장 PDF가 동일한 page geometry를 사용
- smoke 전후 원본 hash와 수정 시각 동일

### 완료 기준

- 보안 fixture의 실행·network 차단과 정상 문서의 PDF 충실도가 함께 통과한다.
- HWP/HWPX PDF 저장과 인쇄에서 page count, geometry, searchable text와 nonblank raster 회귀가 없다.
- 대표 문서 원본이 변경되지 않는다.
- 전체 tests, Debug build와 bundled asset 검증이 통과한다.

### 검증

- `xcodegen generate`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task460/stage4-tests CODE_SIGNING_ALLOWED=NO test`
- `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task460/stage4-build CODE_SIGNING_ALLOWED=NO build`
- `scripts/verify-rhwp-studio-assets.sh build.noindex/task460/stage4-build/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio`
- `pdfinfo` page count/media box 검사
- `pdftotext -layout` 한글·영문 sentinel 검사
- PDF page raster/thumbnail nonblank와 embedded image 비교
- `shasum -a 256` 원본/복사본/output 기록
- 실제 PDF 저장과 인쇄 패널 수동 smoke
- `./scripts/check-no-appkit.sh`
- `git diff --check`

### 커밋 메시지

- `Task #460 Stage 4: hardened PDF·인쇄 경로 회귀 검증`

## Stage 5. SVG trust boundary 문서화와 최종 검증

### 목표

architecture의 PDF/print renderer 설명을 실제 보안 계약과 맞추고, 전체 타스크 범위를 clean 환경에서 최종 검증한다.

### 작업

- `project_architecture.md`의 page SVG renderer에 untrusted input 경계를 기록한다.
- content JavaScript, default client metrics, CSP, 허용 data resource와 navigation 정책을 문서화한다.
- CSP와 WebKit 공개 API가 보장하는 범위, data URI와 renderer의 알려진 제한을 기록한다.
- main editor, Quick Look/Thumbnail, upstream/core가 변경 범위 밖임을 대조한다.
- Stage 2~4 전체 tests/build/smoke 결과를 재검증한다.
- 잔여 위험이 별도 작업을 요구하면 범위를 작업지시자에게 보고하고 후속 이슈 필요 여부를 확인한다.

### 검증 시나리오

- architecture의 renderer 흐름이 실제 configuration/CSP/navigation 코드와 일치
- HTTP/HTTPS/blob 기본 거부와 제한적 data 허용 설명이 tests와 일치
- PDF export와 print controller가 같은 hardened renderer를 사용
- `Sources/RhwpCoreBridge`, bundled studio asset과 main editor security policy에 의도하지 않은 변경 없음
- clean HostAppTests와 Debug build 통과

### 완료 기준

- Issue #460 완료 조건과 각 Stage 검증 결과가 문서·코드·테스트에서 추적된다.
- 보안 계약과 알려진 제한이 architecture에 기록된다.
- 전체 검증이 clean derived data에서 통과한다.
- 최종 결과보고서 작성 단계로 진행 가능한 상태가 된다.

### 검증

- clean `xcodegen generate`
- clean `HostAppTests`
- clean HostApp Debug build
- built app bundled studio asset 검증
- script/event/external/data/blob targeted tests 재실행
- `./scripts/check-no-appkit.sh`
- `git diff --check`
- 변경 파일이 Issue #460 범위에 한정됐는지 `git diff --stat devel...HEAD` 대조

### 커밋 메시지

- `Task #460 Stage 5: SVG trust boundary 문서화와 최종 검증`

## 단계 승인 게이트

- 각 Stage의 source/test 변경과 `mydocs/working/task_m040_460_stage{N}.md`를 함께 커밋한다.
- 단계 보고서 작성과 검증에는 명시 호출형 `task-stage-report` 절차를 사용한다.
- 현재 Stage 완료보고와 작업지시자 승인 없이 다음 Stage를 시작하지 않는다.
- 검증 실패는 단계 안에서 해결하고, 단계 범위가 달라지면 구현계획서 보정 승인을 먼저 받는다.
- Stage 4 실제 인쇄 패널 시각 확인처럼 작업지시자의 UI 확인이 필요한 항목은 자동 검증 결과와 분리해 요청한다.
- 모든 Stage 승인 뒤에만 최종 결과보고서와 PR 게시 단계로 진행한다.

## 승인 요청 사항

- content JavaScript를 비활성화하고 HostApp metrics만 `WKContentWorld.defaultClient`에서 실행하는 구현 계약을 승인 요청한다.
- CSP에서 HTTP/HTTPS/blob을 거부하고 inline style과 실제 필요가 확인된 data image/font만 허용하는 정책을 승인 요청한다.
- CSP + navigation delegate + non-persistent store를 기본 방어선으로 사용하고, content rule list는 통합 테스트에서 차단 공백이 확인될 때만 추가하는 결정을 승인 요청한다.
- loopback `NWListener`로 실제 WKWebView 외부 요청 0건을 검증하는 테스트 방향을 승인 요청한다.
- 이 구현계획을 기준으로 Stage 1 조사와 보안 계약 확정 작업 진행 승인을 요청한다.
