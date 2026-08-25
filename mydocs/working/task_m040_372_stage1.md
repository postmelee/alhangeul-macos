# Task M040 #372 Stage 1 완료 보고서

## 단계 목적

제품 소스를 변경하기 전에 파일 패널, Finder/open URL, 최근 문서, native file URL drop과 WebView dropped bytes의 문서 열기 경로를 추적하고, recoverable opening failure와 기존 fatal WebView failure의 경계·문서 snapshot 보존 계약·Stage 2 테스트 seam을 확정한다.

## 산출물

- `mydocs/working/task_m040_372_stage1.md`
  - 문서 열기 진입점과 현재 실패 표시를 정리했다.
  - recoverable/fatal 분류와 load ID 기반 상태 전이 계약을 확정했다.
  - HostAppTests에 제품 의존을 넓게 복제하지 않는 상태 machine·chooser seam을 확정했다.

production source, test source, `project.yml`과 Xcode project는 이 단계에서 변경하지 않았다.

## 조사 결과

### 문서 열기 진입점

| 입력 경로 | 최초 진입점 | 공통 load 경로 | 입력 정보 | 현재 실패 표시 | 현재 문서 영향 |
| --- | --- | --- | --- | --- | --- |
| 메뉴·toolbar·fatal fallback의 다른 파일 열기 | `DocumentViewerStore.openDocument()` | `loadDocument(from:)` | `NSOpenPanel` URL | `errorMessage` 전체 오류 화면 | 실패 시 제거 |
| Finder/open URL과 새 문서 창 initial URL | `DocumentOpenRouter`·`DocumentWindowRootView` | `loadDocument(from:)` | URL | `errorMessage` 전체 오류 화면 | 실패 시 제거 |
| 최근 문서 | `openRecentDocument(_:)` | bookmark 복원 뒤 `loadDocument(from:)` | `RecentDocumentItem`과 URL | bookmark 실패는 자동 소멸 banner, 이후 실패는 전체 오류 화면 | 이후 실패 시 제거 |
| native file URL drop | `RhwpStudioWebView.onDroppedFileURL` | `loadDocument(from:)` | URL | `errorMessage` 전체 오류 화면 | 실패 시 제거 |
| WebView dropped bytes | host bridge `dropped-document` → `onDroppedDocument` | `loadDroppedDocument(data:filename:)` | bytes와 표시 이름 | 자동 소멸 banner | 실패 시 제거 |

URL 기반 입력은 `loadDocument(from:)`에 수렴하고, bytes drop은 `startDocumentLoad`부터 같은 `HwpDocumentInputValidator`와 protection classification 경로를 공유한다. native URL drop과 bytes drop은 `RhwpStudioWebView`의 2초 suppression marker로 중복 전달을 막지만, source URL/bookmark 유무는 서로 다르므로 Stage 2에서도 하나의 입력 타입으로 합치지 않는다.

입력 경로를 failure 문구와 test에서 구분하기 위해 다음 source 분류를 사용한다.

- `.filePanel`: 메뉴·toolbar·fatal fallback과 recoverable retry에서 선택한 URL
- `.externalOpen`: Finder/open URL, pending URL과 window initial URL
- `.recentDocument`: 최근 문서 bookmark 복원 또는 해당 URL load
- `.fileDrop`: native file URL drop
- `.webViewDrop`: WebView가 전달한 bytes drop

`loadDocument(from:)`에는 source 기본값을 `.externalOpen`으로 두고, 패널·최근 문서·URL drop 호출부는 명시 source를 전달한다. bytes drop은 기존 별도 API를 유지한다.

### 오류 상태 생산자와 소비자

| 상태 | 생산자 | 소비자 | 수명 | Stage 2 처리 |
| --- | --- | --- | --- | --- |
| `errorMessage` | URL 읽기·opening validation catch | `DocumentViewerView`의 전체 `ErrorStateView` 분기 | 다음 load 시작까지 | opening 전용임이 확인되어 제거 |
| `webViewErrorMessage` | nonfatal runtime, 저장·공유·PDF command, 최근 문서 접근, bytes drop 실패 등 | viewer 상단 `WebViewerErrorBanner` | 기본 5초 또는 수동 닫기 | opening failure 용도만 분리하고 나머지 유지 |
| `webViewFailure` | resource/document scheme, navigation, timeout, process, fatal runtime, parser document load | `WebViewerFallbackView` | retry 또는 새 정상 문서 load까지 | 기존 fatal 계약 유지 |
| 신규 recoverable opening failure | 파일 읽기, bookmark 복원, empty/unknown signature | `DocumentViewerView`의 window-local modal | 닫기·retry·다음 load·성공까지 | 새 명시 상태로 추가 |

`errorMessage`의 producer는 `DocumentViewerStore.loadDocument(from:)`의 opening catch 한 곳이고 consumer는 `DocumentViewerView` 한 곳뿐이다. 다른 기능의 일반 오류 상태로 사용되지 않으므로 Stage 2에서 published property와 전체 `ErrorStateView` 분기를 함께 제거한다.

`webViewErrorMessage`는 여러 nonfatal 기능이 공유하므로 유지한다. 최근 문서 bookmark 복원 실패와 bytes drop opening validation 실패만 recoverable 상태로 이동한다. 저장, 공유, PDF export command, Finder reveal, post-load recoverable runtime의 banner 동작은 변경하지 않는다.

### 현재 파괴적 load sequence

현재 URL과 bytes load는 다음 순서로 동작한다.

1. `beginDocumentLoad()`가 `activeDocumentLoadID`를 증가시킨다.
2. 이전 `documentLoadTask`를 cancel한다.
3. `isLoading = true`로 바꾸고 `errorMessage`, banner, fatal failure와 WebView loading을 지운다.
4. URL 경로는 `RecentDocumentItem`을 만든 뒤 `Data(contentsOf:)`로 읽는다.
5. `startDocumentLoad`가 empty·HWP/HWP3/HWPX signature를 검증한다.
6. detached task에서 protection classification을 수행한다.
7. task cancel과 load ID가 모두 유효한 경우에만 `finishDocumentLoad`가 새 payload를 commit한다.
8. 4~5단계 실패는 현재 load ID인지 확인한 뒤 `clearCurrentDocument()`를 호출한다.

`finishDocumentLoad` 전에는 새 입력이 기존 payload를 대체하지 않는다. 파괴적 동작은 실패 catch의 `clearCurrentDocument()`와 새 시도 시작 시 fatal failure를 지우는 동작에 한정된다. 따라서 기존 async commit 경계는 유지하고 실패·begin 전이만 좁게 보정한다.

### 확정 상태 전이 계약

문서 snapshot은 다음 상태를 묶어 의미한다.

- `rhwpStudioDocument`
- `sourceDocument`
- `filename`
- `documentRevision`
- `hasUnsavedChanges`
- `webViewReloadToken`
- 기존 fatal `webViewFailure`

| 이벤트 | 문서 snapshot | recoverable 상태 | fatal 상태 | loading |
| --- | --- | --- | --- | --- |
| 새 load 시작 | 유지 | 이전 recoverable 해제 | 유지 | 시작 |
| 최신 load의 읽기·validation 실패 | 유지 | 최신 실패 표시 | 유지 | 종료 |
| stale load 실패·완료 | 유지 | 변경 없음 | 변경 없음 | 최신 load 기준 유지 |
| recoverable 닫기 | 유지 | 해제 | 유지 | 변경 없음 |
| retry 시작 | 유지 | 먼저 해제 | 유지 | chooser 선택 전에는 변경 없음 |
| retry chooser 취소 | 유지 | 해제 상태 유지 | 유지 | 시작하지 않음 |
| 최신 load 성공 | 새 문서로 교체 | 해제 | 해제 | 종료 |

`beginDocumentLoad`는 load ID 갱신, 이전 task cancel, loading 시작과 이전 recoverable/nonfatal banner 정리만 수행한다. 문서 snapshot과 fatal failure는 건드리지 않는다. 성공한 `finishDocumentLoad`에서만 payload/source/filename/revision/unsaved 상태를 교체하고 fatal/recoverable 상태를 해제한다.

fatal fallback에서 ‘다른 파일 열기’를 선택한 뒤 잘못된 파일을 고르면 기존 fatal 진단 화면 위에 recoverable modal을 표시한다. modal을 닫거나 retry chooser를 취소하면 같은 fatal 화면으로 돌아간다. 정상 파일이 protection classification까지 성공하면 새 payload를 commit하면서 fatal 상태를 해제한다.

### recoverable/fatal 분류

| 실패 | 분류 | 근거 |
| --- | --- | --- |
| `Data(contentsOf:)` 읽기·권한·위치 실패 | recoverable | 다른 파일 선택 또는 권한 회복으로 재시도 가능 |
| 최근 문서 bookmark 복원 실패 | recoverable | 현재 문서는 유효하며 다른 파일 선택 가능 |
| 0-byte 입력 | recoverable | `HwpDocumentInputError.emptyDocument`가 WebView 전달 전에 확정 |
| HWP/HWP3/HWPX가 아닌 signature | recoverable | `unsupportedOrCorrupt`가 WebView 전달 전에 확정 |
| bundled asset preflight·resource scheme | fatal 유지 | viewer 실행 기반 자체가 유효하지 않음 |
| document scheme·navigation·timeout·process 종료 | fatal 유지 | #150에서 확정한 WebView failure 계약 |
| fatal runtime | fatal 유지 | viewer 정상 상태를 보장할 수 없음 |
| parser `document-load-error` | fatal 유지 | WebView가 문서를 받은 뒤 생성하는 `RhwpStudioWebViewFailure.documentLoad` 경로 |

parser `document-load-error`는 host bridge가 `#sb-message`의 `파일 로드 실패:` 변화를 관찰해 native message를 전송한다. `RhwpStudioWebView.Coordinator.handleDocumentLoadError`는 loading을 끝내고 `.documentLoadError(...)`를 만들며, `RhwpStudioWebViewFailure`의 기본 `isFatal`은 `true`다. Store는 이를 `webViewFailure`로 보관하고 view는 전체 `WebViewerFallbackView`를 표시한다. 이 경로를 recoverable로 낮추는 변경은 이번 범위에 포함하지 않는다.

### 정상 문서가 없는 창과 window lifecycle

- initial URL이 있는 새 창은 `closeRedundantEmptyWindowIfNeeded`의 `initialURL == nil` guard 때문에 opening 실패 후에도 유지된다.
- pending URL을 받은 빈 창은 `openPendingURL`이 true를 반환하므로 prepare 직후 닫히지 않는다.
- 실패 시 `hasDocument`가 false에서 false로 유지되므로 `onChange(of: hasDocument)`가 추가 close를 유발하지 않는다.
- 따라서 `clearCurrentDocument()` 제거 뒤 정상 문서가 없는 창도 empty viewer와 recoverable modal을 유지하고 retry/drop을 받을 수 있다.

## Stage 2 구현 경계 확정

### 제품 모델과 store API

다음 두 Foundation-only 타입을 하나의 작은 service 파일 또는 동일 역할의 최소 파일로 둔다.

1. `DocumentOpenSource`
   - 위 다섯 입력 경로를 구분한다.
2. `RecoverableDocumentOpenFailure`
   - stable identity, source, sanitize된 표시 이름, 제목과 사용자 메시지만 가진다.
   - URL, bookmark, 원본 `Error`와 bytes는 보관하지 않는다.

Store에는 다음 경계를 추가한다.

- `@Published private(set) var recoverableDocumentOpenFailure`
- initializer의 `@MainActor () -> URL?` chooser closure, 기본값은 `DocumentOpenPanel.chooseDocumentURL`
- `dismissRecoverableDocumentOpenFailure()`
- modal을 먼저 닫고 chooser scheduling을 요청하는 `retryDocumentOpen()`
- source를 받는 `loadDocument(from:source:)`

`openDocument()`은 chooser가 URL을 반환한 뒤에만 `.filePanel` load를 시작한다. chooser 취소 시 load ID, loading과 모든 오류 상태를 변경하지 않는다.

### 최소 상태 machine seam

HostAppTests는 현재 제품 모듈을 host하지 않고 선택한 pure service source를 직접 컴파일한다. `DocumentViewerStore`를 직접 추가하면 다음 의존이 연쇄된다.

- `RecentDocumentStore`와 AppKit bookmark/recent API
- `RhwpStudioDocumentPayload`와 save contract
- `RhwpStudioWebViewFailure`가 들어 있는 resource locator
- `RhwpStudioSavedDocument`가 들어 있는 WebView source
- `RhwpDocumentProtection`과 `Rhwp.xcframework`
- `HwpDocumentInputValidator`가 함께 참조하는 render/bridge error 타입

이 연쇄를 Stage 2 테스트만을 위해 HostAppTests에 복제하지 않는다. 대신 load ID, loading, recoverable presentation, dismiss와 단일 retry 허용 여부를 관리하는 Foundation-only `DocumentOpenRecoveryState`를 제품 코드에서 실제 사용하고, 해당 파일만 HostAppTests source에 추가한다.

상태 machine은 begin/current/fail/succeed/dismiss/beginRetry 전이를 제공하고, failure 전이에서는 문서 replacement 명령을 만들지 않는다. Store는 오직 current success 전이에서 `finishDocumentLoad`를 호출한다. 이 구조로 stale completion, failure presentation과 retry 중복 방지를 같은 제품 코드에서 deterministic하게 검증한다.

문서 snapshot 자체는 Store에 남기되 다음 두 근거로 검증한다.

- failure handler에서 `clearCurrentDocument()`를 제거하고 document fields를 쓰는 유일한 opening 경로를 `finishDocumentLoad`로 제한한다.
- Stage 4에서 정상 문서 뒤 PDF·빈 파일·unknown signature의 payload/source/revision/unsaved 보존을 실제 HostApp smoke로 확인한다.

Stage 2 자동 테스트는 최소한 다음을 포함한다.

- begin이 generation을 증가시키고 이전 failure를 해제
- current failure만 표시되고 loading 종료
- stale failure와 stale success 무시
- dismiss가 failure만 해제
- `beginRetry`가 같은 failure에 한 번만 chooser action을 허용
- chooser 취소가 새 load를 시작하지 않음
- current success만 commit 허용 신호를 만들고 failure를 해제
- error source별 제목·표시 이름·메시지 mapping

### retry modal과 panel 순서

Stage 2는 retry intent와 chooser closure를 준비하고, 실제 SwiftUI modal 연결은 Stage 3에 둔다. Stage 3 retry action은 main actor에서 다음 순서를 사용한다.

1. recovery state의 `beginRetry`로 중복 action을 차단하고 failure를 해제한다.
2. `Task { @MainActor in await Task.yield() }` 또는 동등한 다음-turn scheduling으로 sheet dismissal 반영을 기다린다.
3. chooser closure를 정확히 한 번 호출한다.
4. URL이 있으면 `.filePanel` source로 load하고, `nil`이면 현재 상태를 유지한다.

임의 sleep이나 중첩 `NSOpenPanel.runModal()`은 사용하지 않는다.

## 본문 변경 정도 / 본문 무손실 여부

- production code, test code, `project.yml`, Xcode project와 bundled `rhwp-studio` asset은 변경하지 않았다.
- 승인된 구현계획서의 4단계와 범위를 변경하지 않았다.
- sample HWP/HWPX와 사용자 PDF는 이 단계에서 열거나 수정하지 않았다.
- `xcodebuild -showBuildSettings` 추가 탐색은 sandbox 밖 기본 DerivedData·SourcePackages 경로를 사용해 package resolution 전에 중단됐다. Stage 1 완료 검증 명령은 아니며 저장소 변경은 발생하지 않았다. Stage 2부터는 계획대로 `build.noindex/task372-*` 경로를 명시한다.

## 검증 결과

1. opening 경로 검색: 통과
   - 파일 패널, external/pending/initial URL, 최근 문서, native URL drop과 bytes drop 진입점 확인
2. 오류 상태 생산자·소비자 검색: 통과
   - `errorMessage`가 URL opening failure 전용임을 확인
   - `webViewErrorMessage`의 nonfatal 공용 용도와 `webViewFailure` fatal 용도 확인
3. load lifecycle 검색: 통과
   - `clearCurrentDocument()` 호출이 URL과 bytes opening failure 두 곳뿐임을 확인
   - `finishDocumentLoad`가 유일한 정상 opening snapshot commit 경계임을 확인
4. parser failure 검색: 통과
   - host bridge observer → Coordinator → fatal `.documentLoad` 경로 확인
5. HostAppTests 구성 검색: 통과
   - standalone selected-source target이며 Store와 관련 AppKit/bridge 모델이 포함되지 않음을 확인
6. `git diff --check`: 통과
7. `git status --short --branch`: `local/task372`, Stage 1 보고서 외 변경 없음

## 잔여 위험

- `Data(contentsOf:)`는 main actor에서 동기 수행되므로 매우 큰 입력의 반응성 문제는 남지만 이번 타스크 범위가 아니다.
- fatal fallback을 보존한 채 protection classification을 수행하는 동안 fallback branch에는 기존 loading overlay가 보이지 않는다. 정상 commit과 실패 modal 기능에는 영향이 없으며 Stage 3 smoke에서 사용자 혼동 여부를 확인한다.
- recent bookmark resolution은 load ID 생성 전 실패한다. recoverable state는 표시하되 진행 중인 별도 load를 취소하지 않도록 main actor 순서를 확인해야 한다.
- `Task.yield()` 뒤 sheet dismissal이 macOS 12에서 충분한지는 Stage 3 실제 modal/panel smoke로 검증한다.
- 상태 machine 자동 테스트와 Store의 단순 연결만으로 snapshot 무손실을 완전히 대체하지 않으므로 Stage 4 실제 앱 smoke가 필수다.

## 다음 단계 영향

Stage 2에서는 다음 범위만 구현한다.

- Foundation-only `DocumentOpenSource`, `RecoverableDocumentOpenFailure`, `DocumentOpenRecoveryState`
- chooser closure 주입과 source-aware load 진입점
- opening failure의 recoverable 전이와 `clearCurrentDocument()` 제거
- 성공 시에만 새 snapshot과 fatal 해제
- HostAppTests에 recovery state source와 focused unit test 추가
- `project.yml` 갱신과 `xcodegen generate`

SwiftUI sheet와 modal dismissal 후 `NSOpenPanel` 호출 연결은 계획대로 Stage 3에 유지한다. parser `document-load-error`와 기존 fatal fallback은 변경하지 않는다.

## 승인 요청

Stage 1 조사 결과와 확정된 recoverable/fatal·snapshot·테스트 seam 계약을 검토하고 Stage 2 recoverable opening 상태와 store 전이 구현 진입 승인을 요청한다.
