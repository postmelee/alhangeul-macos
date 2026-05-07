# Task M016 #150 Stage 1 완료 보고서

## 단계 목적

현행 HostApp WKWebView viewer의 loading/failure 경로를 변경 없이 조사해 Stage 2 fallback/diagnostics 설계의 입력을 확정했다.

이번 단계는 코드 변경이 아니라 inventory 단계다. 사용자 화면에 드러나는 오류 상태, 내부 scheme handler 오류, `rhwp-studio` asset 검증 스크립트의 책임을 분리해 정리했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m016_150_stage1.md` | WKWebView loading/failure 경로 matrix, 현재 한계, Stage 2 설계 입력 정리 |
| `mydocs/orders/20260507.md` | #150 상태를 Stage 1 완료 및 Stage 2 승인 대기로 갱신 |

## 현재 경로 요약

| 영역 | 현재 동작 | 확인한 한계 |
|------|----------|-------------|
| `DocumentViewerStore` | 파일 bytes 읽기 실패는 `errorMessage`로 전체 오류 화면에 연결되고, WKWebView 내부 오류는 `webViewErrorMessage` 문자열로 관리된다. | fatal WebView failure와 저장/공유/인쇄 같은 일시적 command error가 같은 문자열 경로를 공유한다. retry/reload API가 없다. |
| `DocumentViewerView` | `errorMessage`는 `ErrorStateView`, `webViewErrorMessage`는 상단 `WebViewerErrorBanner`로 표시된다. | WebView fatal failure도 빈 viewer 위 2줄 banner에 머무른다. recovery action이 없다. |
| `RhwpStudioWebView` | `RhwpStudioResourceLocator.loadURL(for:)` 성공 후 WebView load를 시작하고 15초 timeout을 건다. navigation failure, process termination, timeout, script `"error"`를 `onError(String?)`로 전달한다. | category/detail/fatal 여부가 사라지고 localized string만 store로 전달된다. `LoadIdentity`가 같으면 reload가 skip되어 같은 문서 retry 설계가 필요하다. |
| `RhwpStudioResourceLocator` | `rhwp-studio` directory와 `index.html` 존재만 preflight한다. | JS/CSS/WASM, override CSS 누락은 load 이후 scheme/runtime failure로 늦게 드러난다. |
| `RhwpStudioResourceSchemeHandler` | `alhangeul-studio://app` resource를 bundle `Resources/rhwp-studio` 아래 파일로 resolve하고 MIME type을 붙여 응답한다. | 누락 오류는 상대 path 문자열만 담고, failing URL/file path/category가 구조화되어 있지 않다. |
| `RhwpStudioDocumentSchemeHandler` | `alhangeul-document://current?revision=...` 요청을 current payload와 매칭해 bytes를 응답한다. | 실패 message는 document scheme domain과 failing URL만 가진다. requested/current revision 진단이 없고, revision query가 없으면 current payload를 허용한다. |
| `RhwpStudioHostBridgeScript` | dropped document read, export, print 같은 host command 실패를 native `"error"` message로 전달한다. | `window.onerror`와 `unhandledrejection` listener가 없다. injection도 `.atDocumentEnd`라 초기 JS/WASM failure 포착 범위가 제한된다. |
| `scripts/verify-rhwp-studio-assets.sh` | source `rhwp-studio` asset에 대해 JS/CSS/WASM count, relative path, `crossorigin`/root-relative path, manifest provenance를 검증한다. | release/build-time 검증이며 런타임 사용자 fallback과 직접 연결되지는 않는다. |

## failure matrix

| failure 구분 | 현재 감지 지점 | 현재 사용자 표시 | Stage 2 입력 |
|--------------|---------------|----------------|--------------|
| resource preflight | `RhwpStudioResourceLocator.resourceDirectoryURL`, `indexHTMLURL` | 상단 banner: locator `localizedDescription` | directory/index/JS/CSS/WASM/override CSS를 최소 preflight로 확장하고 fatal fallback으로 연결 |
| resource scheme | `RhwpStudioResourceSchemeHandler.webView(_:start:)` | WebKit navigation/runtime error 또는 timeout으로 섞일 수 있음 | URL, relative path, file path, scheme category를 error detail로 보존 |
| document scheme | `RhwpStudioDocumentSchemeHandler.webView(_:start:)` | WebKit fetch failure 또는 `rhwp-studio` runtime error로 보일 수 있음 | requested revision, current revision/payload 존재 여부를 detail에 포함 |
| navigation failure | `didFail`, `didFailProvisionalNavigation` | `error.localizedDescription` banner | WebKit domain/code, failing URL, fatal 여부를 포함한 failure model 필요 |
| process termination | `webViewWebContentProcessDidTerminate` | "웹 viewer 프로세스가 종료되었습니다. 문서를 다시 열어 주세요." banner | fatal fallback과 retry/reopen action으로 승격 |
| load timeout | 15초 `Task.sleep` 이후 | loading URL 포함 timeout banner | fatal timeout category와 retry action 필요 |
| JS/WASM runtime | host command 실패 일부만 `"error"` message | command error와 loading/runtime error가 같은 banner | `window.onerror`/`unhandledrejection` 보강 및 loading 중 runtime failure 구분 필요 |

## build-time verifier와 runtime validator 경계

`scripts/verify-rhwp-studio-assets.sh`는 현재 통과한다.

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

이 스크립트가 계속 소유할 항목:

- `manifest.json`의 `source_release_tag`/`source_resolved_commit` provenance
- `registerSW.js`, `manifest.webmanifest`, `samples/` 미포함 여부
- `index.html`의 relative path, `crossorigin` 제거, root-relative path 금지
- expected `rhwp-studio` release tag/commit

runtime validator로 옮길 후보:

- `rhwp-studio` directory 존재
- `index.html` 존재
- `alhangeul-wkwebview-overrides.css` 존재
- `assets/index-*.js` 정확히 1개
- `assets/index-*.css` 정확히 1개
- `assets/rhwp_bg-*.wasm` 정확히 1개

runtime validator는 사용자 fallback을 빠르게 띄우기 위한 최소 검증으로 제한하고, provenance/hash 성격은 release verifier에 남기는 편이 맞다.

## Stage 2 설계 입력

1. `String?` 기반 `webViewErrorMessage`만으로는 fatal loading failure와 transient command error를 분리할 수 없다. HostApp 전용 failure model이 필요하다.
2. 새 failure model은 최소한 category, 사용자 title/message, diagnostic detail, fatal 여부를 가져야 한다.
3. `DocumentViewerStore`에는 banner용 message와 fatal fallback용 state를 분리해 둔다.
4. retry는 현재 `LoadIdentity.document(revision)` guard 때문에 같은 payload를 그대로 다시 load하지 못한다. Stage 2에서 `documentRevision` 증가, 별도 reload token, `WKWebView.reload()` 중 하나를 선택해야 한다.
5. fallback UI action은 "다시 시도", "다른 파일 열기", "Finder에서 원본 보기"를 우선 후보로 둔다. Finder action은 `sourceDocument`가 있을 때만 노출한다.
6. `RhwpStudioResourceLocator`에 JS/CSS/WASM/override CSS 최소 preflight를 넣으면 asset 누락을 WebKit timeout 전에 사용자 fallback으로 바꿀 수 있다.
7. document scheme은 revision query 누락을 허용할지 재검토해야 한다. v0.1 fallback 기준에서는 requested/current revision을 진단에 남기는 편이 필요하다.
8. JS/WASM runtime failure 포착은 현재 host command error 수준에 머문다. 초기 로딩 오류를 잡으려면 `.atDocumentStart` listener 또는 별도 early script가 필요한지 Stage 2에서 결정해야 한다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 코드 변경 없음.
- 기존 문서 본문 삭제 없음.
- `mydocs/orders/20260507.md`는 #150 비고만 Stage 1 완료 상태로 갱신했다.

## 검증 결과

```bash
git status --short --branch
```

결과:

```text
## local/task150
```

```bash
rg -n "webViewErrorMessage|setWebViewError|isWebViewLoading|didFail|didFailProvisionalNavigation|webViewWebContentProcessDidTerminate|loadTimeout|WKURLSchemeHandler|resourceError|sendFailure|message: \\\"error\\\"" \
  Sources/HostApp/Stores/DocumentViewerStore.swift \
  Sources/HostApp/Views/DocumentViewerView.swift \
  Sources/HostApp/Views/RhwpStudioWebView.swift \
  Sources/HostApp/Services/RhwpStudioResourceLocator.swift \
  Sources/HostApp/Services/RhwpStudioResourceSchemeHandler.swift \
  Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift \
  Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift
```

결과: store/view/webview/resource/document scheme handler에서 현재 loading/error entrypoint를 확인했다.

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

## 잔여 위험

- Stage 1은 정적 inventory라 실제 asset 누락 시 사용자 화면을 실행 검증하지 않았다. negative smoke는 Stage 4에서 수행한다.
- 현재 `rhwp-studio` bundle 내부 JS의 초기화 failure가 어떤 native callback으로 드러나는지는 코드만으로 완전히 보장할 수 없다. Stage 3/4에서 JS error bridge와 negative smoke로 확인해야 한다.
- document scheme failure는 정상 앱 흐름에서 자연스럽게 만들기 어렵다. Stage 4에서 과도한 테스트 훅 없이 재현 가능한 범위를 판단해야 한다.

## 다음 단계 영향

Stage 2에서는 다음 설계를 확정한다.

- `RhwpStudioWebViewFailure` 또는 동등한 HostApp 전용 failure model
- fatal fallback state와 banner message 분리
- retry/reopen/reveal action의 store/view 책임
- runtime asset validator 최소 기준
- resource/document scheme diagnostic detail 형식
- JS error/rejection bridge 보강 범위

## 승인 요청

Stage 1 완료를 승인하면 Stage 2 `fallback 상태와 diagnostics 설계`로 진행한다.
