# Task M040 #459 Stage 3 완료 보고서

## 단계 목적

Stage 1의 인쇄 controller ownership과 Stage 2의 renderer generation을 실제 연속 요청에서 함께 검증한다. 정상·navigation 실패·font preparation 실패·PDF encoding 실패·timeout·WebContent process 종료 뒤 같은 renderer 또는 print lifecycle을 즉시 재사용해도 내부 상태가 completion 호출 전에 idle로 복귀하고, 이전 세대의 늦은 callback이 새 세대의 page·completion을 변경하지 않는 계약을 고정한다.

## 산출물

| 파일 | 변경 내용 |
|------|-----------|
| `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift` | Production WebKit preparation·`createPDF` 호출을 그대로 기본값으로 사용하는 internal 작업 seam 추가 |
| `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift` | 정상·오류·process 종료·stale async result·즉시 재진입 회귀 5개 추가, timeout retry를 completion 내부 재진입으로 보강 |
| `Tests/HostAppTests/RhwpStudioPrintLifecycleTests.swift` | controller completion 직후 같은 `complete` call stack에서 다음 요청을 시작하고 이전 completion identity를 재검증하는 회귀 추가 |
| `mydocs/orders/20260826.md` | Stage 3 완료와 Stage 4 승인 대기 상태 반영 |

`project.yml`과 generated Xcode project에는 신규 source membership이 없어 변경하지 않았다. Public API, Host bridge protocol과 PDF export state도 변경하지 않았다.

## 구현 결과

### 비동기 WebKit 작업 seam

`RhwpStudioPagePDFWebKitOperations`는 renderer 내부의 두 비동기 경계만 표현한다.

| 작업 | Production 기본 구현 | Test에서 확인한 전이 |
|------|----------------------|----------------------|
| Page preparation | 기존 `callAsyncJavaScript`와 같은 script·arguments·content world | Navigation identity fixture에 deterministic metrics 공급, font failure는 live WebKit path 유지 |
| PDF 생성 | 기존 `WKWebView.createPDF(configuration:)` 호출 | 잘못된 PDF data, 이전 generation의 늦은 result와 현재 generation result 순서 제어 |

Renderer initializer에서 seam을 생략하면 `.live()`가 기존 WebKit 호출을 그대로 수행한다. 별도 test-only 조건 분기, mock renderer 또는 public API는 추가하지 않았다. Closure는 `@MainActor`이고 WebKit completion과 맞춘 `@Sendable` signature를 사용한다.

이 seam은 Stage 2의 production token 검사를 우회하지 않는다. 주입된 completion도 기존 `renderCurrentPagePDF(for:)` closure를 통과하며 `didFinish`와 `renderLifecycle.isCurrent(token)`을 다시 확인한다. 따라서 테스트는 제품과 같은 stale callback gate를 검증한다.

### 정상 완료와 completion 내부 재진입

동일 renderer에 2-page portrait·landscape payload를 전달해 정상 완료한 뒤 첫 completion 안에서 1-page payload를 즉시 시작했다. 첫 PDF의 page count·page text와 두 번째 PDF의 page count·text를 모두 확인했다.

`finish`는 사용자 completion보다 먼저 다음 상태를 정리하므로 두 번째 `render`가 `.renderingInProgress`로 거부되지 않는다.

1. Current generation과 page/navigation token 무효화
2. Exactly-once gate 설정과 navigation delegate 해제
3. Watchdog 취소와 `stopLoading()`
4. Stored completion·payload·rendered document·page index 해제
5. 사용자 completion 호출

두 번째 render는 새 generation을 발급하고 delegate, empty PDF document와 page index를 다시 설정한다.

### 종료 유형별 재사용

| 첫 render 종료 | 후속 요청 | 확인 결과 |
|----------------|-----------|-----------|
| 다중 page 정상 완료 | Completion 내부 1-page 정상 render | 새 generation 성공, 두 PDF의 page count·text 보존 |
| Current navigation failure | Completion 내부 두 번째 render | 첫 error 1회, 이전 navigation failure 재호출 무시, current navigation만 완료 |
| 필수 bold 한글 font preparation 실패 | Completion 내부 ASCII page render | Typed `fontPreparationFailed(page: 1)` 뒤 같은 renderer 성공 |
| 잘못된 `createPDF` data | Completion 내부 live WebKit render | Typed `pdfEncodingFailed(1)` 뒤 같은 renderer 성공 |
| Page timeout | 첫 timeout completion 내부 동일 payload render | 두 generation 모두 timeout exactly once, 두 번째 요청 즉시 수락 |
| Owned WebContent process 종료 | Completion 내부 두 번째 live render | 첫 generation은 process 종료 error, 두 번째 generation은 정상 성공 |

Navigation failure 회귀는 `WKNavigation`을 직접 생성하지 않는다. Tracking `WKWebView`가 실제 `loadHTMLString` 반환 navigation을 보관하고, 첫 navigation failure가 새 navigation을 만든 뒤 이전 failure를 다시 전달한다. WebKit load 취소 자체의 실행 시점에 의존하지 않도록 page preparation과 1-page PDF 결과만 internal seam으로 공급하며 navigation identity 판정은 production lifecycle을 그대로 통과한다.

### Stale async result와 새 generation 겹침

첫 generation이 `createPDF` completion을 보류한 상태에서 owned WebContent process 종료를 전달했다. 첫 completion 안에서 두 번째 render를 시작하고, 두 번째 `createPDF`의 실제 WebKit 결과가 준비될 때까지 current completion도 보류했다.

두 번째 generation이 active인 동안 첫 generation의 늦은 invalid PDF data를 먼저 전달했으며 다음 상태가 유지됐다.

- 새 generation의 completion 호출 0회
- 새 generation의 PDF append·page index 변경 0회
- Stale error 사용자 전달 0회
- Current result 전달 뒤 두 번째 completion 정확히 1회

첫 generation은 `.webContentProcessTerminated`, 두 번째 generation은 text를 포함한 정상 PDF로 끝났고 전체 결과 수는 2개였다. 이 검증은 page index가 같은 두 render 사이에서도 generation token이 stale result를 차단함을 실제 renderer closure 경계에서 확인한다.

### Print lifecycle 즉시 재진입

Fake controller의 completion closure가 active slot을 해제한 직후, 같은 `complete` call stack 안에서 두 번째 요청을 시작했다. 그 상태에서 첫 controller completion을 다시 전달하고 세 번째 요청을 시도했다.

- 두 번째 controller는 정상 시작되어 active identity를 유지했다.
- 첫 controller의 늦은 completion은 두 번째 controller를 해제하지 않았다.
- Active 중 세 번째 요청은 factory 호출 없이 `.printingInProgress`로 거부됐다.
- 두 번째 controller 완료 뒤 세 번째 controller가 정상 시작됐다.

Production `RhwpStudioPrintLifecycle` source 보정은 필요하지 않았다.

## 자동 회귀 결과

### 신규·보강 테스트

| 테스트 | 검증 내용 |
|--------|-----------|
| `testRendererReusesSameInstanceAfterMultiPageSuccessFromCompletion` | 다중 page 정상 완료와 completion 내부 동일 renderer 정상 재진입 |
| `testRendererReentersAfterCurrentNavigationFailureAndIgnoresRepeatedFailure` | Current navigation 실패 뒤 즉시 재진입, 이전 navigation failure 무시 |
| `testRendererReentersAfterFontPreparationFailureFromCompletion` | Font readiness typed error 뒤 동일 renderer 성공 |
| `testRendererReentersAfterPDFEncodingFailureFromCompletion` | Invalid PDF data typed error 뒤 live WebKit render 성공 |
| `testRendererIgnoresStaleCreatePDFResultWhileProcessTerminationRetryIsActive` | Process 종료 뒤 새 generation active 상태에서 이전 `createPDF` result 무시 |
| `testRendererPageTimeoutFinishesExactlyOnceAndAllowsImmediateRetry` | Timeout completion 내부 즉시 retry와 generation별 exactly-once |
| `testImmediateRequestAfterCompletionKeepsNewControllerIdentity` | Print completion 직후 즉시 재진입과 이전 controller identity 방어 |

### 검증 결과

| 검증 | 결과 |
|------|------|
| Renderer·print lifecycle 선택 테스트 | 34/34 통과, 실패·skip 0 |
| 전체 `HostAppTests` | 178/178 통과, 실패·skip 0 |
| HostApp Debug unsigned build | 성공 |
| `xcodegen generate` 2회 | 성공, 두 번째 추가 diff 없음 |
| Xcode project SHA-1 | `192e1cd7c42b3a80213fbdf7f3b8ab396a738ef0` |
| `./scripts/check-no-appkit.sh` | 통과 |
| `./scripts/verify-rhwp-studio-assets.sh` | 통과 |
| `./scripts/check-extension-registration-hygiene.sh` | issue 0, development registration 0 |
| `git diff --check` | 통과 |

결과 bundle:

- 선택 회귀: `build.noindex/task459-stage3-selected/Logs/Test/Test-HostAppTests-2026.08.26_17-56-31-+0900.xcresult`
- 전체 회귀: `build.noindex/task459-stage3-tests/Logs/Test/Test-HostAppTests-2026.08.26_17-57-11-+0900.xcresult`

최초 navigation failure fixture는 실제 첫 load를 인위적으로 실패시킨 직후 두 번째 실제 load 완료까지 기다려 WebKit cancellation timing에 의존했고 5초 timeout 뒤 결과 배열을 인덱싱해 test process도 중단했다. Navigation identity가 검증 대상임을 다시 좁혀 두 번째 page 작업만 internal seam으로 결정적으로 완료하고, 기대 결과 수를 guard한 뒤 인덱싱하도록 보정했다. 보정한 단일 test, 선택 34개와 전체 178개를 새로 실행해 모두 통과했다.

남은 macOS 12/XCTest 14 minimum version link warning과 WebKit sandbox service 진단은 기존 test environment 출력이며 실패·skip은 없었다. Invalid PDF fixture에서는 의도한 CoreGraphics PDF parse error log가 한 번 출력됐다.

## 기존 PDF 계약 회귀

전체 renderer test에서 다음 계약이 유지됐다.

- Portrait·landscape geometry, mixed orientation과 page count
- 한글·수식 selectable text, search와 `ToUnicode`
- Noto Sans/Serif regular·bold font resource와 fallback
- Document script와 event handler 비실행
- CSP와 HTTP·HTTPS·file·external resource 차단
- Data PNG·nested data SVG 보존
- Font preparation failure exactly once
- Concurrent render의 `.renderingInProgress`
- Timeout·process 종료 typed error와 retry

## 본문 변경 정도 / 본문 무손실 여부

- HWP/HWPX bytes, page SVG payload, HTML template, CSP, font preparation script, PDF geometry·font와 page append 로직은 변경하지 않았다.
- WebKit production 호출은 internal operation container의 `.live()` 구현으로 옮겼을 뿐 script, configuration과 completion 처리 순서는 동일하다.
- Print controller/lifecycle production source, PDF export, Host bridge, bundled `rhwp-studio`, Rust core, Quick Look·Thumbnail은 변경하지 않았다.
- 실제 print panel, printer spool과 사용자 문서는 사용하지 않았다.
- 모든 build/test 산출물은 ignored `build.noindex/task459-stage3-*` 아래에 생성했다.
- Development extension registration은 남지 않았다.

## 잔여 위험

- `WKNavigationAction`에는 generation/navigation identity가 없어 이전 policy callback을 application token만으로 완전히 식별할 수 없는 Stage 2 한계가 유지된다. Allowlist는 current page의 `about:blank` main-frame 1회보다 넓어지지 않는다.
- `webViewWebContentProcessDidTerminate`에도 process generation identity가 없다. Owned WebView와 current page token을 요구하지만 같은 WebView의 과거 process에서 극단적으로 늦게 온 종료 callback 자체를 API가 구분해 주지는 않는다.
- Navigation failure 통합 회귀는 실제 `WKNavigation` identity를 사용하지만 page 결과는 deterministic operation seam으로 공급한다. 실제 normal WebKit navigation·preparation·PDF 생성은 다른 통합 테스트와 전체 renderer test가 검증한다.
- 실제 `NSPrintOperation` panel의 사용자 취소·실패 UI는 자동화하지 않았다. Controller completion이 단일 lifecycle 경계로 수렴하는 계약과 fake controller identity 회귀를 사용했다.
- Stage 4에서 이 검증 한계와 ownership·cleanup 순서를 architecture 문서에 장기 계약으로 기록해야 한다.

## 다음 단계 영향

Stage 4에서는 Stage 3 source/test 동작을 바꾸지 않고 architecture와 최종 수용 근거를 정리한다.

- Print lifecycle의 active controller 단일 ownership과 identity 기반 해제
- Renderer generation/page/navigation token과 async current 판정
- `finish` cleanup 순서와 completion 내부 재진입 계약
- 동일 renderer의 정상·오류·timeout·process 종료 뒤 재사용 계약
- `WKNavigationAction`, process termination과 actual `NSPrintOperation`의 자동 검증 한계
- 전체 test/build, XcodeGen 정합성, source·asset·extension 변경 범위 최종 확인

Stage 4에서 제품 source나 test 보정이 필요해지면 문서 단계에 섞지 않고 Stage 3 보정으로 되돌아가야 한다.

## 승인 요청

Stage 3의 종료 cleanup, 동일 renderer·print lifecycle 재사용, completion 내부 즉시 재진입, stale async result 차단과 전체 검증 결과를 검토하고 Stage 4 architecture 계약·최종 수용 검증 진입 승인을 요청한다.
