# Task M040 #459 Stage 2 완료 보고서

## 단계 목적

`RhwpStudioPagePDFRenderer`의 각 render와 page load에 generation/page/navigation identity를 부여한다. Navigation delegate, preparation JavaScript, `createPDF`, page append와 timeout callback이 현재 token에 속할 때만 renderer 상태와 completion을 변경하게 해 이전 page 또는 이전 render의 늦은 callback을 무해하게 만든다.

## 산출물

| 파일 | 변경 내용 |
|------|-----------|
| `Sources/HostApp/Services/RhwpStudioPagePDFRenderer.swift` | render lifecycle state, generation/page token, navigation identity와 callback current 검증 추가 |
| `Tests/HostAppTests/RhwpStudioPagePDFRendererTests.swift` | page/navigation 세대 전이, stale token, owned WebView process 종료와 중복 render 회귀 5개 추가 |
| `mydocs/orders/20260826.md` | Stage 2 완료와 Stage 3 승인 대기 상태 반영 |

`project.yml`과 generated Xcode project에는 신규 source membership이 필요하지 않아 변경하지 않았다. Lifecycle state와 token은 기존 renderer source 안에 두고 HostAppTests가 같은 production 타입을 직접 검증한다.

## 구현 결과

### Render lifecycle state

`RhwpStudioPagePDFRenderLifecycle`은 다음 상태를 하나의 값 타입으로 관리한다.

| 상태 | 의미 |
|------|------|
| `latestGeneration` | renderer instance에서 되돌아가지 않는 마지막 render generation |
| `activeGeneration` | 현재 진행 중인 render generation, idle이면 `nil` |
| `currentPageToken` | `generation + pageIndex`로 구성된 현재 page identity |
| `currentNavigationIdentity` | `loadHTMLString`이 반환한 현재 `WKNavigation`의 `ObjectIdentifier` |
| `isInitialMainFrameLoadPending` | 현재 page가 허용할 최초 `about:blank` main-frame load 1회 상태 |

전이는 다음과 같다.

1. `beginRender()`가 idle에서만 generation을 증가시키고 active render를 만든다.
2. `beginPage(at:)`가 같은 generation의 page token을 만들고 이전 navigation identity를 지운다.
3. `registerNavigation(_:for:)`는 token이 current일 때만 navigation identity를 연결한다.
4. Navigation lookup과 모든 async closure는 current token 일치 여부를 확인한다.
5. `invalidate(_:)`는 current token만 active generation 전체를 종료할 수 있다.

첫 render의 page 0 token과 두 번째 render의 page 0 token은 page index가 같아도 generation이 다르다. 따라서 이전 timeout이나 async closure는 후속 render의 동일 page index를 종료하지 못한다. 진행 중 `beginRender()`는 generation을 증가시키지 않고 거부되어 기존 `.renderingInProgress` 계약을 유지한다.

### Navigation callback 방어

`loadHTMLString` 반환값을 저장하지 않던 기존 구조를 바꿔 page token과 `WKNavigation` identity를 연결했다.

| Callback | 처리 조건 | Stale 동작 |
|----------|-----------|------------|
| `didFinish` | owned WebView + current navigation identity | preparation 시작 없이 무시 |
| `didFail` | owned WebView + current navigation identity | current completion 변경 없이 무시 |
| provisional failure | owned WebView + current navigation identity | current completion 변경 없이 무시 |
| navigation policy | owned WebView + current page의 initial pending | 허용 범위를 넓히지 않고 cancel |
| WebContent process 종료 | owned WebView + current page token | foreign WebView callback 무시 |

기존 navigation allowlist는 그대로다. Current page의 최초 `about:blank` main-frame load 한 번만 허용하며 HTTP·HTTPS·file·blob·custom URL과 이후 navigation은 계속 차단한다. Page가 바뀌면 initial pending과 navigation identity도 새 token에 맞게 재설정된다.

### Async page work 방어

Navigation 완료 뒤 시작하는 작업은 모두 같은 `RhwpStudioPagePDFRenderToken`을 캡처한다.

- Preparation JavaScript success/failure
- Page metrics parsing error
- `WKWebView.createPDF` success/failure
- PDF page decode·page count·bounds 검증
- Page append
- Page timeout task

각 결과 적용 직전에 `renderLifecycle.isCurrent(token)`을 다시 확인한다. Page append는 renderer의 `renderingPageIndex`도 token의 page index와 일치해야 한다. 첫 callback이 다음 page로 전환하거나 render를 종료하면 같은 navigation에서 늦게 도착한 중복 callback은 자동으로 stale이 된다.

오류 문구의 page number도 mutable `renderingPageIndex` 대신 캡처 token에서 계산한다. 늦은 callback이 발생해도 다음 page 번호를 잘못 보고하지 않는다.

### 종료와 delegate 경계

`finish(_:for:)`는 current token의 `invalidate`에 성공한 경우에만 실행된다. 종료 순서는 다음과 같다.

1. Active generation, page token, navigation identity와 initial pending 무효화
2. `didFinish` exactly-once gate 설정
3. `WKNavigationDelegate` 해제
4. Page timeout 취소
5. `stopLoading()` 호출
6. Completion·payload·PDF document·page index cleanup
7. 사용자 completion 1회 호출

다음 `render`는 새 generation을 만든 뒤 delegate를 다시 연결한다. Cleanup의 `stopLoading()`이 늦은 navigation failure를 만들더라도 delegate가 분리되고 token도 이미 무효화되어 현재 completion에 영향을 주지 않는다.

Owned WebView identity를 실제 delegate test에서 검증하기 위해 renderer initializer에 `@MainActor` WebView factory seam을 추가했다. Production 기본 factory는 기존과 동일한 frame·전달받은 hardened configuration으로 `WKWebView`를 만들고, 테스트는 생성된 동일 instance를 관찰할 뿐 configuration이나 renderer 동작을 복제하지 않는다.

## 자동 회귀 결과

### 신규·보강 테스트

| 테스트 | 검증 내용 |
|--------|-----------|
| `testRenderLifecycleTracksPageAndNavigationIdentityWithinGeneration` | 같은 generation의 page 이동, old navigation 무효화와 active 중복 begin 거부 |
| `testRenderLifecycleRejectsStaleTokenAcrossRenderGenerations` | generation 증가와 이전 token의 current render invalidate 차단 |
| `testRenderLifecycleScopesInitialMainFrameLoadToCurrentPage` | page별 initial main-frame 허용 상태 1회 소비 |
| `testRendererIgnoresWebContentTerminationFromUnownedWebView` | foreign WebView process callback 무시, current timeout 유지 |
| `testRendererRejectsConcurrentRenderWithoutReplacingCurrentGeneration` | 진행 중 두 번째 render 즉시 `.renderingInProgress`, 첫 render 유지 |

기존 process termination 테스트는 factory가 관찰한 owned WebView를 전달하도록 바로잡았다. 기존 테스트는 임의로 새 `WKWebView()`를 전달해 실제 renderer ownership과 다른 callback을 current로 취급하고 있었다.

### 검증 결과

| 검증 | 결과 |
|------|------|
| Renderer 선택 테스트 | 24/24 통과, 실패·skip 0 |
| 전체 `HostAppTests` | 172/172 통과, 실패·skip 0 |
| HostApp Debug unsigned build | 성공 |
| `xcodegen generate` | 성공 |
| XcodeGen 재생성 전후 project SHA-1 | `192e1cd7c42b3a80213fbdf7f3b8ab396a738ef0`, 추가 diff 없음 |
| `./scripts/check-no-appkit.sh` | 통과 |
| `./scripts/verify-rhwp-studio-assets.sh` | 통과 |
| `git diff --check` | 통과 |

최종 결과 bundle:

- Renderer 선택: `build.noindex/task459-stage2-tests-final/Logs/Test/Test-HostAppTests-2026.08.26_17-44-35-+0900.xcresult`
- 전체 회귀: `build.noindex/task459-stage2-full-tests-final/Logs/Test/Test-HostAppTests-2026.08.26_17-44-59-+0900.xcresult`

최초 구현 선택 test에서 WebView factory 기본 closure가 main actor annotation을 잃었다는 compiler warning을 확인했다. Factory parameter와 test factory 타입을 명시적으로 `@MainActor`로 보정한 뒤 동일 renderer test를 다시 실행했고 해당 warning은 사라졌다. 남은 macOS 12/XCTest 14 minimum version link warning은 기존 test environment warning이며 실행 결과에는 영향이 없다.

## 기존 PDF 계약 회귀

전체 renderer 선택 테스트에서 다음 계약이 모두 유지됐다.

- Portrait·landscape page geometry와 mixed orientation
- 한글·수식 text selection, search와 `ToUnicode`
- Owned Noto Sans/Serif regular·bold font resource
- Document script와 event handler 비실행
- CSP 기반 HTTP·HTTPS·file·external resource 차단
- Data PNG·nested data SVG 보존
- Font preparation failure exactly once
- Page timeout exactly once와 동일 renderer retry
- PDF page count·bounds·metrics 검증

## 본문 변경 정도 / 본문 무손실 여부

- HWP/HWPX bytes, page SVG, HTML template, CSP, font preparation script와 PDF geometry 계산은 변경하지 않았다.
- `RhwpStudioPrintLifecycle`, Host bridge, PDF export controller·state와 print operation은 변경하지 않았다.
- Bundled `rhwp-studio`, Rust core, Quick Look·Thumbnail과 sample 문서는 변경하지 않았다.
- 실제 print panel, printer spool과 사용자 문서는 사용하지 않았다.
- 모든 build/test 산출물은 ignored `build.noindex/task459-stage2-*` 아래에만 생성했다.

## 잔여 위험

- `WKNavigationAction`은 `WKNavigation` identity나 application generation을 제공하지 않는다. `decidePolicyFor`는 owned WebView와 current page에 묶인 pending state를 사용하지만, WebKit이 이전 load의 policy callback을 새 page 시작 뒤 전달하는 극단적 순서는 action 자체만으로 완전히 식별할 수 없다. 종료 시 delegate 분리와 page별 pending reset으로 노출을 줄이고, allowlist는 `about:blank` main-frame 1회보다 넓어지지 않는다.
- `webViewWebContentProcessDidTerminate`도 navigation identity를 전달하지 않는다. Owned WebView와 현재 page token이 있을 때만 current render를 종료하도록 했으며, 같은 WebView의 과거 process에 대한 극단적 지연 callback은 WebKit API만으로 직접 구분할 수 없다.
- `WKNavigation`과 preparation/`createPDF` completion을 arbitrary 순서로 직접 생성하는 public API가 없어, stale async 적용 차단은 production closure가 사용하는 lifecycle token 전이를 단위 테스트하는 방식이다. 실제 정상 WebKit render와 timeout/process 경로는 integration test가 보완한다.
- Stage 2는 cleanup 순서를 구현했지만 정상·각 failure·timeout 직후 completion 안에서 즉시 재진입하는 조합 전체는 Stage 3 통합 회귀에서 추가 검증해야 한다.

## 다음 단계 영향

Stage 3에서는 새 generation/token 구현을 바꾸지 않고 종료·재사용 조합을 확장한다.

- 정상 1-page·다중-page 완료 뒤 동일 renderer 재사용
- Navigation·font preparation·PDF encoding·timeout·process 종료 뒤 재진입
- 첫 completion 안에서 즉시 두 번째 render 시작
- 이전 navigation/async/timeout callback과 새 render가 겹치는 fixture
- Stage 1 print lifecycle과 renderer 연속 요청의 통합 회귀
- 기존 보안·font·selectable text·geometry 전체 검증

새 기능, public API, PDF export request ID 또는 Host bridge protocol 변경은 Stage 3에 추가하지 않는다.

## 승인 요청

Stage 2의 generation/page/navigation lifecycle, stale callback 차단, delegate cleanup과 검증 결과를 검토하고 Stage 3 종료 cleanup·재사용 통합 회귀 진입 승인을 요청한다.
