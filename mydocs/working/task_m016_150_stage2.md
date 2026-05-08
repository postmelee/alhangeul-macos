# Task M016 #150 Stage 2 완료 보고서

## 단계 목적

Stage 3 구현 전에 WKWebView viewer failure model, fatal fallback state, recovery action, runtime asset validator의 책임 경계를 확정했다.

이번 단계도 제품 코드 변경 전 설계 단계다. Stage 1 inventory에서 확인한 `String?` banner 중심 오류 경로를 fatal loading failure와 transient command error로 나누는 구현안을 정했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m016_150_stage2.md` | fallback/diagnostics 설계, failure category, retry/reopen/reveal action, Stage 3 구현 입력 정리 |
| `mydocs/orders/20260507.md` | #150 상태를 Stage 2 완료 및 Stage 3 승인 대기로 갱신 |

## failure model 설계

Stage 3에서는 HostApp 전용 model을 추가한다. 위치는 `Sources/HostApp/Services` 또는 `Sources/HostApp/Stores` 중 실제 사용 범위가 좁은 쪽으로 둔다. `RhwpCoreBridge`에는 추가하지 않는다.

```swift
enum RhwpStudioWebViewFailureCategory: String, Equatable {
    case resourcePreflight
    case resourceScheme
    case documentScheme
    case navigation
    case processTerminated
    case timeout
    case runtime
}

struct RhwpStudioWebViewFailure: Identifiable, Equatable {
    let id: UUID
    let category: RhwpStudioWebViewFailureCategory
    let title: String
    let message: String
    let diagnosticDetail: String
    let isFatal: Bool
}
```

`isFatal`은 확장 여지를 위해 두지만, Stage 3에서 `RhwpStudioWebViewFailure`로 store에 들어오는 값은 원칙적으로 문서 영역을 대체할 fatal fallback이다. transient command error는 기존 banner 문자열 경로를 유지한다.

## category별 사용자 메시지와 diagnostics

| category | 사용자 title | 사용자 message 방향 | diagnosticDetail |
|----------|--------------|--------------------|------------------|
| resource preflight | 웹 viewer 자산을 찾을 수 없습니다 | 설치본에 viewer 필수 파일이 빠져 있어 문서를 표시할 수 없음 | bundle resource directory, missing requirement, matched JS/CSS/WASM count |
| resource scheme | 웹 viewer 자산을 읽을 수 없습니다 | viewer asset 요청을 처리하지 못함 | `alhangeul-studio` URL, relative path, resolved file path, NSError domain/code |
| document scheme | 문서 데이터를 viewer에 전달할 수 없습니다 | 현재 문서 payload 또는 revision이 맞지 않아 viewer가 문서를 가져오지 못함 | `alhangeul-document` URL, requested revision, current revision, payload byte count |
| navigation | 웹 viewer 탐색에 실패했습니다 | WebKit이 viewer 진입 URL 또는 내부 navigation을 완료하지 못함 | failing URL, WebKit/NSURLError domain/code, localized description |
| processTerminated | 웹 viewer 프로세스가 종료되었습니다 | WebKit content process가 종료되어 다시 로드가 필요함 | last loaded URL, current document revision/reload token |
| timeout | 웹 viewer 로딩이 지연되고 있습니다 | 지정 시간 안에 viewer 로딩이 끝나지 않음 | timeout seconds, loading URL, current document revision/reload token |
| runtime | 웹 viewer 실행 중 오류가 발생했습니다 | JS/WASM runtime 오류로 viewer가 정상 상태가 아님 | error message, source URL, line/column, promise rejection reason |

## fatal fallback과 banner 책임 분리

| 상태 | 책임 | 표시 방식 |
|------|------|-----------|
| `errorMessage` | 문서 파일 자체를 HostApp이 읽지 못한 경우 | 기존 `ErrorStateView` 전체 오류 |
| `webViewFailure` | WKWebView viewer loading/render bootstrap이 실패한 경우 | 새 fatal fallback view로 문서 영역 대체 |
| `webViewErrorMessage` | 저장, 공유, 인쇄, PDF export, unsupported drop 등 일시적 command error | 기존 `WebViewerErrorBanner` |
| `isWebViewLoading` | WebView load 진행 상태 | 기존 loading overlay 유지 |

Stage 3에서는 `DocumentViewerStore`에 `@Published var webViewFailure: RhwpStudioWebViewFailure?`를 추가하고, 기존 `webViewErrorMessage`는 banner 전용으로 좁힌다. fatal failure가 들어오면 `isWebViewLoading`은 false로 내려가야 하며, banner와 동시에 보이지 않도록 view 조건을 분리한다.

## recovery action 설계

fallback UI에는 다음 action을 둔다.

| action | 표시 조건 | 연결 위치 | 동작 |
|--------|-----------|-----------|------|
| 다시 시도 | 항상 표시 | `DocumentViewerStore.retryWebViewLoad()` | fatal failure와 banner를 지우고 reload token을 증가시켜 같은 payload를 다시 load |
| 다른 파일 열기 | 항상 표시 | `DocumentViewerStore.openDocument()` | 기존 open panel 흐름 재사용 |
| Finder에서 보기 | `store.canRevealInFinder`일 때만 표시 | `DocumentViewerStore.revealCurrentDocumentInFinder()` | 원본 URL을 Finder에서 표시 |

같은 문서 retry는 `documentRevision`을 임의로 증가시키기보다 별도 `webViewReloadToken`을 추가하는 방향으로 정한다. 이유는 다음과 같다.

- 현재 `LoadIdentity.document(revision)` guard 때문에 같은 revision은 다시 load되지 않는다.
- `documentRevision`은 문서 payload 변경 의미에 가깝기 때문에 단순 retry 신호로 쓰면 의미가 흐려진다.
- `webViewReloadToken`을 `RhwpStudioWebView` 입력과 `LoadIdentity`에 포함하면 문서가 없는 empty viewer retry와 문서가 있는 viewer retry를 같은 방식으로 처리할 수 있다.

예상 형태:

```swift
@Published private(set) var webViewReloadToken: Int = 0

func retryWebViewLoad() {
    webViewFailure = nil
    webViewErrorMessage = nil
    webViewReloadToken += 1
}
```

`RhwpStudioWebView.Coordinator.LoadIdentity`는 `empty(reloadToken)`과 `document(revision:reloadToken:)` 또는 동등한 struct로 바꾼다.

## runtime asset validator 기준

Stage 3 runtime validator는 사용자 fallback에 필요한 최소 항목만 확인한다.

필수 항목:

- `rhwp-studio` directory 존재
- `index.html` 존재
- `alhangeul-wkwebview-overrides.css` 존재
- `assets/index-*.js` 정확히 1개
- `assets/index-*.css` 정확히 1개
- `assets/rhwp_bg-*.wasm` 정확히 1개

runtime validator에서 다루지 않을 항목:

- `manifest.json` provenance
- `source_release_tag` / `source_resolved_commit`
- `registerSW.js`, `manifest.webmanifest`
- `samples/` 미포함 여부
- `crossorigin` 제거, root-relative path 금지
- third-party license/font notices

위 항목은 계속 `scripts/verify-rhwp-studio-assets.sh`와 release/rehearsal 검증이 소유한다.

## resource/document diagnostics 형식

`RhwpStudioResourceSchemeHandler`와 `RhwpStudioDocumentSchemeHandler`의 NSError는 계속 domain을 분리한다.

추가할 detail 후보:

| handler | 추가 detail |
|---------|-------------|
| resource scheme | failing URL, normalized relative path, resolved file path, resource directory path |
| document scheme | failing URL, requested revision 문자열, current revision, payload byte count, payload filename |

`WKURLSchemeTask.didFailWithError`가 subresource failure를 항상 `WKNavigationDelegate`까지 전달한다는 보장은 없다. 따라서 필수 JS/CSS/WASM은 resource preflight로 먼저 잡고, scheme handler detail은 WebKit이 surfacing하는 경우와 negative smoke 진단용으로 남긴다.

document scheme은 HostApp이 만드는 URL에 항상 revision query를 붙이므로, Stage 3에서는 revision query 누락을 failure로 취급하는 방향을 우선한다. current payload fallback 허용은 진단을 흐리므로 v0.1 release hardening 기준과 맞지 않는다.

## JS/runtime error bridge 범위

기존 `RhwpStudioHostBridgeScript.source`는 `.atDocumentEnd`에서 host command bridge를 설치한다. Stage 3에서는 초기 JS/WASM runtime error 포착을 위해 document-start script를 추가하는 방향으로 정한다.

설계:

- `RhwpStudioHostBridgeScript`에 `runtimeErrorSource` 또는 별도 enum을 추가한다.
- `.atDocumentStart` script에서 `window.onerror`와 `window.addEventListener("unhandledrejection", ...)`를 설치한다.
- native message type은 기존 command error용 `"error"`와 분리해 `"runtime-error"`로 둔다.
- `"error"`는 저장/공유/인쇄/PDF export 같은 transient command error로 계속 banner 처리한다.
- `"runtime-error"`는 `RhwpStudioWebViewFailure(category: .runtime, isFatal: true)`로 연결한다.

초기 runtime failure는 fatal fallback으로 다루되, 이후 Stage 4 smoke에서 benign runtime message가 과하게 fatal 처리되는지 확인한다.

## fallback UI 방향

`DocumentViewerView`에 새 `WebViewerFallbackView`를 추가한다. card 중첩 없이 문서 영역 중앙에 상태를 보여준다.

표시 정보:

- SF Symbol: `exclamationmark.triangle`
- title: category별 사용자 title
- message: 사용자용 message
- action: `다시 시도`, `다른 파일 열기`, 조건부 `Finder에서 보기`
- diagnostic: `DisclosureGroup("진단 정보")` 또는 secondary text 영역으로 `diagnosticDetail` 표시

`RhwpStudioWebView`는 fatal failure 상태에서는 표시하지 않는다. retry 시 store가 failure를 지우고 reload token을 증가시키면 같은 document payload로 WebView load가 다시 시작된다.

## Stage 3 코드 변경 입력

Stage 3에서 구현할 항목:

1. `RhwpStudioWebViewFailureCategory` / `RhwpStudioWebViewFailure` 추가
2. `DocumentViewerStore`에 `webViewFailure`, `webViewReloadToken`, `setWebViewFailure`, `retryWebViewLoad` 추가
3. `DocumentViewerView`에 fatal fallback view와 action callback 연결
4. `RhwpStudioWebView` 입력에 `reloadToken`과 fatal failure callback 추가
5. `RhwpStudioResourceLocator`에 최소 runtime asset validator 추가
6. `RhwpStudioResourceSchemeHandler` error detail 보강
7. `RhwpStudioDocumentSchemeHandler` revision/payload diagnostics 보강 및 missing revision failure 처리
8. `RhwpStudioHostBridgeScript` document-start runtime error bridge 추가
9. 기존 command error는 banner 전용 `webViewErrorMessage`로 유지

## 본문 변경 정도 / 본문 무손실 여부

- 제품 코드 변경 없음.
- 기존 문서 본문 삭제 없음.
- `mydocs/orders/20260507.md`는 #150 비고만 Stage 2 완료 상태로 갱신했다.

## 검증 결과

```bash
git status --short --branch
```

초기 상태:

```text
## local/task150
```

```bash
rg -n "resource preflight|resource scheme|document scheme|navigation|runtime|다시 시도|다른 파일 열기|Finder|index-\\*\\.js|rhwp_bg-\\*\\.wasm" \
  mydocs/working/task_m016_150_stage2.md
```

결과: Stage 2 보고서에 failure category, recovery action, runtime validator 기준이 모두 포함됨을 확인했다.

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- `WKURLSchemeTask.didFailWithError`가 subresource failure를 native navigation error로 항상 전달하지 않을 수 있다. 이 리스크는 필수 asset preflight와 JS runtime bridge로 줄인다.
- `runtime-error`를 모두 fatal로 처리하면 benign JS 오류까지 fallback으로 승격할 수 있다. Stage 4 normal smoke에서 과도한 fatal 처리 여부를 확인해야 한다.
- `webViewReloadToken` 추가는 SwiftUI update와 `LoadIdentity`가 함께 맞아야 효과가 있다. Stage 3 구현 때 같은 문서 retry가 실제 load를 다시 시작하는지 확인해야 한다.
- document scheme missing revision을 failure로 바꾸면 혹시 upstream이 revision 없는 fetch를 시도하는 경우 깨질 수 있다. 현재 HostApp이 생성하는 document URL에는 revision이 있으므로 release hardening 기준에서는 명시 실패가 낫다.

## 다음 단계 영향

Stage 3은 설계된 failure model과 UI/action을 코드로 구현한다. 구현 후 Debug build와 `scripts/verify-rhwp-studio-assets.sh`를 통과해야 하며, Stage 4에서 실제 asset 제거 negative smoke를 수행한다.

## 승인 요청

Stage 2 완료를 승인하면 Stage 3 `런타임 asset/document failure 보강 구현`으로 진행한다.
