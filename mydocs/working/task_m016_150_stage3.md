# Task M016 #150 Stage 3 완료 보고서

## 단계 목적

WKWebView viewer의 asset/document/runtime loading failure를 fatal fallback 상태로 승격하고, 사용자가 같은 문서를 다시 시도하거나 다른 파일을 열 수 있는 복구 경로를 구현했다.

Stage 2 설계대로 기존 `webViewErrorMessage`는 저장/공유/인쇄/PDF export 같은 일시적 command error banner 경로로 남기고, viewer bootstrap 자체가 실패한 경우는 `RhwpStudioWebViewFailure` 기반 fallback view로 분리했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `Sources/HostApp/Services/RhwpStudioResourceLocator.swift` | runtime 필수 asset validator, failure category/model, diagnostic key 추가 |
| `Sources/HostApp/Services/RhwpStudioResourceSchemeHandler.swift` | resource scheme failure detail 보강 |
| `Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift` | document scheme revision/payload diagnostics 보강 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | document-start JS runtime error bridge 추가 |
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | reload token, fatal failure callback, navigation/process/timeout/runtime failure 연결 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | `webViewFailure`, `webViewReloadToken`, retry state 추가 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | fatal fallback UI와 recovery action 추가 |
| `Sources/HostApp/Views/ContentView.swift` | viewer fatal/loading 상태에서 share/export command 비활성화 |
| `Sources/HostApp/HostApp.swift` | AppKit toolbar validation에 viewer command 가능 상태 반영 |
| `mydocs/working/task_m016_150_stage3.md` | Stage 3 구현 및 검증 보고 |
| `mydocs/orders/20260507.md` | #150 상태를 Stage 3 완료 및 Stage 4 승인 대기로 갱신 |

## 구현 요약

### failure model

`RhwpStudioWebViewFailureCategory`와 `RhwpStudioWebViewFailure`를 추가했다.

현재 category:

- `resourcePreflight`
- `resourceScheme`
- `documentScheme`
- `navigation`
- `processTerminated`
- `timeout`
- `runtime`

각 failure는 사용자용 title/message와 진단용 `diagnosticDetail`을 가진다. Stage 3에서는 이 model에 들어오는 failure를 모두 문서 영역을 대체하는 fatal fallback으로 처리한다.

### runtime asset validator

`RhwpStudioResourceLocator.loadURL(for:)` 진입 전에 다음 항목을 검증한다.

- `rhwp-studio` directory
- `index.html`
- `alhangeul-wkwebview-overrides.css`
- `assets/index-*.js` 정확히 1개
- `assets/index-*.css` 정확히 1개
- `assets/rhwp_bg-*.wasm` 정확히 1개

provenance, manifest, source release tag/commit, service worker 제거 여부 같은 release artifact 검증은 계속 `scripts/verify-rhwp-studio-assets.sh`가 소유한다.

### scheme diagnostics

`RhwpStudioResourceSchemeHandler`는 resource URL, normalized relative path, resolved file path, resource directory path, underlying error를 `NSError.userInfo`에 담도록 보강했다.

`RhwpStudioDocumentSchemeHandler`는 revision query 누락을 failure로 처리하고, requested revision, current revision, payload byte count, filename을 진단 정보로 남긴다.

### WebView fallback 연결

`RhwpStudioWebView`에 `reloadToken`과 `onFailure` callback을 추가했다. 다음 entrypoint는 `RhwpStudioWebViewFailure`로 store에 전달된다.

- resource preflight 실패
- navigation/provisional navigation 실패
- 허용되지 않은 navigation 차단
- WebKit content process 종료
- 15초 load timeout
- document-start JS `error` / `unhandledrejection`

기존 native host command 실패 message type `"error"`는 banner 전용 `webViewErrorMessage` 경로를 유지한다.

### recovery action

fallback UI에는 다음 action을 연결했다.

| action | 동작 |
|--------|------|
| 다시 시도 | `webViewFailure`와 banner를 지우고 `webViewReloadToken`을 증가시켜 같은 payload를 다시 load |
| 다른 파일 열기 | 기존 open panel 흐름 재사용 |
| Finder에서 보기 | 원본 문서 URL이 있을 때만 Finder reveal |

viewer가 loading 중이거나 fatal fallback 상태이면 toolbar의 share/PDF export command도 비활성화된다.

## 본문 변경 정도 / 본문 무손실 여부

- HostApp WKWebView viewer 경로만 수정했다.
- `Sources/RhwpCoreBridge`에는 변경 없음.
- `Alhangeul.xcodeproj` 직접 수정 없음.
- 기존 문서 본문 삭제 없음.
- Stage 3 구현 중 새 Swift 파일을 추가하지 않고, 현재 Xcode project가 이미 컴파일하는 `RhwpStudioResourceLocator.swift` 안에 failure model을 함께 두었다. `project.yml`이 원본이라는 규칙을 유지하기 위한 조치다.

## 검증 결과

```bash
git diff --check
```

결과: 통과.

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [3.863 sec]
```

Xcode가 CoreSimulator 관련 경고를 출력했지만 macOS HostApp build는 성공했다. 이번 단계의 판단 기준에는 영향을 주지 않는다.

## 잔여 위험

- 실제 asset 제거, document scheme mismatch, runtime error를 설치본에서 강제로 발생시키는 negative smoke는 아직 수행하지 않았다. Stage 4에서 확인한다.
- `runtime-error`를 fatal로 승격했기 때문에 benign JS 오류가 있을 경우 fallback이 과하게 뜰 수 있다. 정상 문서 smoke와 negative smoke에서 조정 여부를 판단해야 한다.
- `WKURLSchemeTask.didFailWithError`가 모든 subresource failure를 navigation delegate로 전달한다고 볼 수는 없다. 필수 asset은 preflight로 먼저 잡고, scheme diagnostics는 WebKit이 surfacing하는 범위의 진단 보강으로 둔다.

## 다음 단계 영향

Stage 4에서는 빌드 산출물 기준으로 다음 smoke를 수행한다.

- 정상 HWP/HWPX 문서 load에서 fallback이 뜨지 않는지 확인
- 필수 asset 누락 또는 rename 상황에서 `resourcePreflight` fallback이 뜨는지 확인
- 가능한 범위에서 document scheme/runtime failure가 진단 정보로 연결되는지 확인
- retry/open/reveal action이 UI 상태를 올바르게 복구하는지 확인

## 승인 요청

Stage 3 완료를 승인하면 Stage 4 `fallback negative smoke 및 회귀 확인`으로 진행한다.
