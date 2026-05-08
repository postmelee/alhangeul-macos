# Task M016 #150 구현계획서

수행계획서: `mydocs/plans/task_m016_150.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #150 WKWebView viewer asset loading 실패 fallback 보강
- 마일스톤: M016 (`v0.1 출시 전 보강`)
- 브랜치: `local/task150`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 주 대상: `Sources/HostApp`의 WKWebView viewer loading/error 경로
- 기준 bundled asset: `Sources/HostApp/Resources/rhwp-studio` (`rhwp-studio` `v0.7.10`)
- 목표: HostApp viewer가 resource asset, document scheme, WebKit navigation/runtime 실패를 구분해 사용자 fallback과 진단 정보를 표시하고, 정상/negative smoke 결과를 남긴다.

## 구현 원칙

- 제품 경로는 bundled `rhwp-studio`만 사용한다. 개발 서버나 네트워크 fallback은 추가하지 않는다.
- #149 범위인 손상·대용량 HWP/HWPX parser/opening fallback은 이번 작업에서 구현하지 않는다.
- #151 범위인 설치본 Quick Look/Thumbnail gate는 건드리지 않고, HostApp WKWebView smoke 입력만 넘긴다.
- `Sources/RhwpCoreBridge`에는 AppKit/WebKit 의존을 추가하지 않는다. 이번 변경은 HostApp 전용 계층에 둔다.
- runtime asset validator는 사용자 fallback에 필요한 최소 필수 항목만 확인한다. release provenance/hash 검증은 `scripts/verify-rhwp-studio-assets.sh`가 계속 소유한다.
- hash가 들어간 asset 파일명은 고정하지 않고 `index-*.js`, `index-*.css`, `rhwp_bg-*.wasm` 패턴 기준으로 확인한다.
- 사용자 화면은 빈 WKWebView 위 banner만 남기지 않고, fatal loading failure인 경우 문서 영역을 대체하는 fallback 상태와 recovery action을 제공한다.
- 개발자 진단 문자열에는 가능한 한 scheme URL, 상대 asset path, WebKit domain/code, document revision을 남긴다.

## Stage 1. 현행 WKWebView loading/failure 경로 inventory

### 목표

- 현재 HostApp viewer에서 정상 로드와 실패가 어느 코드 경로로 전달되는지 변경 없이 정리한다.
- Stage 2 설계에서 구분할 failure taxonomy와 실제 구현 파일을 확정한다.

### 작업

- `DocumentViewerStore`의 `errorMessage`, `webViewErrorMessage`, `isWebViewLoading`, `documentRevision` 흐름을 정리한다.
- `DocumentViewerView`의 loading overlay와 `WebViewerErrorBanner` 표시 조건을 정리한다.
- `RhwpStudioWebView.Coordinator`의 `update`, `didFinish`, `didFail`, `didFailProvisionalNavigation`, timeout, process termination, script message `"error"` 처리를 정리한다.
- `RhwpStudioResourceLocator`가 현재 `index.html`만 preflight하는 한계를 기록한다.
- `RhwpStudioResourceSchemeHandler`와 `RhwpStudioDocumentSchemeHandler`의 error domain/message를 비교한다.
- `RhwpStudioHostBridgeScript`가 native로 전달하는 JS error가 어떤 runtime failure를 포착할 수 있는지 확인한다.
- `scripts/verify-rhwp-studio-assets.sh`의 build/release-time 검증 항목과 runtime validator로 옮기지 않을 항목을 분리한다.
- Stage 1 보고서에 현재 failure matrix와 Stage 2 설계 입력을 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m016_150_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "webViewErrorMessage|setWebViewError|isWebViewLoading|didFail|didFailProvisionalNavigation|webViewWebContentProcessDidTerminate|loadTimeout|WKURLSchemeHandler|resourceError|sendFailure|message: \\\"error\\\"" \
  Sources/HostApp/Stores/DocumentViewerStore.swift \
  Sources/HostApp/Views/DocumentViewerView.swift \
  Sources/HostApp/Views/RhwpStudioWebView.swift \
  Sources/HostApp/Services/RhwpStudioResourceLocator.swift \
  Sources/HostApp/Services/RhwpStudioResourceSchemeHandler.swift \
  Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift \
  Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift
scripts/verify-rhwp-studio-assets.sh
git diff --check
```

### 완료 기준

- 현행 loading/failure 경로가 resource preflight, resource scheme, document scheme, navigation/runtime, JS/WASM으로 분류된다.
- Stage 2에서 구현할 사용자 fallback 상태와 진단 문자열 입력이 확정된다.

### 커밋 메시지

```text
Task #150 Stage 1: WKWebView failure 경로 inventory 정리
```

## Stage 2. fallback 상태와 diagnostics 설계

### 목표

- Stage 3 구현 전에 fatal loading failure와 transient web command error를 구분하는 설계를 확정한다.
- 사용자가 실패 후 취할 수 있는 recovery action과 negative smoke 방식을 고정한다.

### 작업

- `RhwpStudioWebViewFailure` 또는 동등한 HostApp 전용 error model 설계를 정한다.
  - category: resource preflight, resource scheme, document scheme, navigation, process termination, timeout, runtime
  - 사용자용 title/message
  - 진단용 detail
  - fatal 여부
- 기존 `webViewErrorMessage` banner와 새 fatal fallback state의 책임을 분리한다.
- retry 동작을 정한다.
  - 같은 payload를 다시 로드할 수 있도록 `DocumentViewerStore`에 retry/reload API를 둘지 결정한다.
  - 현재 구조에서는 같은 문서를 다시 로드하려면 revision 또는 별도 reload token 갱신이 필요하므로 이를 구현 범위에 포함할지 판단한다.
- fallback UI action을 정한다.
  - 다시 시도
  - 다른 파일 열기
  - Finder에서 원본 보기 (`sourceDocument`가 있을 때만)
- runtime asset validator의 최소 기준을 정한다.
  - `rhwp-studio` directory
  - `index.html`
  - `alhangeul-wkwebview-overrides.css`
  - 정확히 하나의 `assets/index-*.js`
  - 정확히 하나의 `assets/index-*.css`
  - 정확히 하나의 `assets/rhwp_bg-*.wasm`
- JS error bridge 보강 범위를 정한다.
  - `window.onerror`
  - `unhandledrejection`
  - loading 중 runtime failure와 로드 후 command error를 구분할 수 있는지 확인
- Stage 2 보고서에 Stage 3 코드 변경 설계를 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m016_150_stage2.md`

### 검증

```bash
git status --short --branch
rg -n "resource preflight|resource scheme|document scheme|navigation|runtime|다시 시도|다른 파일 열기|Finder|index-\\*\\.js|rhwp_bg-\\*\\.wasm" \
  mydocs/working/task_m016_150_stage2.md
git diff --check
```

### 완료 기준

- fatal fallback state와 banner message의 역할이 분리된다.
- retry/reopen/reveal action의 구현 위치가 확정된다.
- runtime validator와 release asset verifier의 책임 경계가 중복 없이 정리된다.

### 커밋 메시지

```text
Task #150 Stage 2: fallback diagnostics 설계
```

## Stage 3. 런타임 asset/document failure 보강 구현

### 목표

- 필수 `rhwp-studio` asset 누락, resource scheme 실패, document scheme 실패, navigation/runtime 실패를 구분해 사용자 fallback과 진단 정보로 연결한다.

### 작업

- `RhwpStudioResourceLocator`에 runtime 필수 asset preflight를 추가한다.
  - directory/index/override CSS 존재 확인
  - main JS/CSS/WASM asset count 확인
  - 실패 시 사용자 메시지와 진단 detail을 담은 HostApp 전용 error 반환
- `RhwpStudioResourceSchemeHandler`의 error에 URL, relative path, scheme, underlying file path를 포함한다.
- `RhwpStudioDocumentSchemeHandler`의 failure에 requested revision/current payload 상태를 포함한다.
- `RhwpStudioWebView`의 navigation/provisional/process termination/timeout/runtime error 처리를 새 failure model로 연결한다.
- `RhwpStudioHostBridgeScript`에 필요한 경우 `window.onerror`와 `unhandledrejection` 전달을 추가한다.
- `DocumentViewerStore`에 fatal WebView failure 상태와 retry/reopen/reveal action에 필요한 API를 추가한다.
- `DocumentViewerView`에 fatal fallback view를 추가하고 기존 loading overlay, banner와 충돌하지 않게 표시 조건을 정리한다.
- 기존 저장/공유/인쇄/PDF export command error는 가능한 한 banner 수준으로 유지해 문서 화면을 불필요하게 대체하지 않는다.
- Stage 3 보고서에 변경 파일, 사용자 메시지, 진단 문자열 예시를 기록한다.

### 예상 변경 파일

- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift`
- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `Sources/HostApp/Services/RhwpStudioResourceLocator.swift`
- `Sources/HostApp/Services/RhwpStudioResourceSchemeHandler.swift`
- `Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift`
- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` (필요 시)
- `mydocs/working/task_m016_150_stage3.md`

### 검증

```bash
git status --short --branch
scripts/verify-rhwp-studio-assets.sh
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

### 완료 기준

- 정상 asset bundle에서 HostApp Debug build가 성공한다.
- 필수 asset preflight 실패가 빈 화면 대신 fatal fallback 상태로 연결된다.
- resource/document/navigation/runtime 실패 메시지가 서로 구분된다.
- retry 또는 reopen action이 UI에 노출된다.

### 커밋 메시지

```text
Task #150 Stage 3: WKWebView fallback 구현
```

## Stage 4. negative smoke와 Release bundle 연결 검증

### 목표

- 정상 bundle과 인위적 실패 bundle에서 HostApp fallback 동작을 확인하고, release asset verifier와 smoke 절차의 관계를 문서화한다.

### 작업

- Debug build 산출물에서 정상 sample open smoke를 수행한다.
- `scripts/verify-rhwp-studio-assets.sh`를 source resource와 Debug app bundle resource 양쪽에 대해 실행한다.
- Debug app 산출물을 `/private/tmp` 또는 `build.noindex` 아래 복사한 뒤 asset 일부를 제거해 negative smoke를 수행한다.
  - `assets/index-*.js` 제거 또는 이름 변경
  - `assets/rhwp_bg-*.wasm` 제거 또는 이름 변경
  - 필요 시 `index.html` 제거
- document scheme failure는 코드 훅을 남기지 않는 범위에서 가능한 재현 방법을 찾는다. 재현이 과도하면 Stage 4 보고서에 미수행 이유와 수동 검증 한계를 명시한다.
- HostApp WKWebView smoke 절차가 부족하면 `mydocs/manual/build_run_guide.md`에 negative smoke 보강을 최소 추가한다.
- Stage 4 보고서에 정상/negative smoke 명령, 결과, 관찰된 사용자 메시지를 기록한다.

### 예상 변경 파일

- `mydocs/manual/build_run_guide.md` (필요 시)
- `mydocs/working/task_m016_150_stage4.md`

### 검증

```bash
git status --short --branch
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
/usr/bin/open -n -a "$PWD/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app" "$PWD/samples/hwp_table_test.hwp"
/usr/bin/open -a "$PWD/build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app" "$PWD/Sources/HostApp/Resources/sample.hwpx"
pgrep -x Alhangeul
git diff --check
```

negative smoke 후보:

```bash
APP_COPY="/private/tmp/Alhangeul-task150-negative.app"
rm -rf "$APP_COPY"
ditto build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app "$APP_COPY"
find "$APP_COPY/Contents/Resources/rhwp-studio/assets" -maxdepth 1 -name 'rhwp_bg-*.wasm' -type f -delete
/usr/bin/open -n -a "$APP_COPY" "$PWD/samples/hwp_table_test.hwp"
```

### 완료 기준

- 정상 Debug app에서 HWP/HWPX sample open smoke가 통과하거나, 실패 사유가 명확히 기록된다.
- asset 제거 negative smoke에서 fallback 상태가 표시된다.
- release verifier와 runtime fallback의 책임 경계가 보고서 또는 build guide에 남는다.

### 커밋 메시지

```text
Task #150 Stage 4: WKWebView fallback smoke 검증
```

## Stage 5. 최종 보고와 M16 release gate 연결

### 목표

- #150의 구현 결과, 검증 결과, 남은 한계를 최종 보고서로 정리하고 #149, #151, #146에 넘길 정보를 분리한다.

### 작업

- 최종 결과보고서에 변경 파일과 사용자 영향 범위를 표로 정리한다.
- 정상/negative smoke 결과와 실행하지 못한 검증이 있으면 사유를 기록한다.
- #149와 겹치지 않도록 손상·대용량 문서 fallback 미포함 범위를 명시한다.
- #151 설치본 smoke gate에서 재사용할 HostApp WKWebView smoke 입력을 정리한다.
- #146 known limitations에 넘길 fallback/한계 문구가 있으면 후보를 기록한다.
- 오늘할일 #150 행을 완료로 갱신한다.

### 예상 변경 파일

- `mydocs/report/task_m016_150_report.md`
- `mydocs/orders/20260507.md`

### 검증

```bash
git status --short --branch
rg -n "WKWebView|asset|fallback|negative smoke|#149|#151|#146|완료" \
  mydocs/report/task_m016_150_report.md \
  mydocs/orders/20260507.md \
  mydocs/working/task_m016_150_stage*.md
git diff --check
```

### 완료 기준

- 최종 보고서가 #150의 사용자 fallback, 진단, 검증 결과, 잔여 리스크를 포함한다.
- 오늘할일 #150 행이 완료 상태와 완료 시각을 가진다.
- PR 생성 전 `git status --short`가 비어 있다.

### 커밋 메시지

```text
Task #150 Stage 5 + 최종 보고서: WKWebView fallback 보강 완료
```

## 전체 수용 기준

- 정상 `rhwp-studio` bundle에서 HostApp Debug build가 성공하고 HWP/HWPX sample open smoke를 수행할 수 있다.
- `rhwp-studio` 필수 asset 누락 시 빈 화면 대신 사용자 fallback 상태가 표시된다.
- document scheme 실패와 asset/resource failure가 다른 메시지/진단으로 구분된다.
- WebKit navigation failure, timeout, process termination이 fatal fallback으로 연결된다.
- 사용자가 실패 상태에서 다시 시도하거나 다른 파일을 열 수 있다.
- release provenance/hash 검증은 `scripts/verify-rhwp-studio-assets.sh`에 남고, runtime validator는 제품 fallback에 필요한 최소 asset만 확인한다.
- #149, #151, #146의 남은 release gate와 겹치는 범위가 최종 보고서에 명시된다.
