# Task M040 #372 Stage 2 완료 보고서

## 단계 목적

파일 읽기·빈 파일·미지원 signature 등 HostApp opening failure를 별도 recoverable 상태로 모델링하고, 실패한 새 입력이 마지막 정상 문서 snapshot과 기존 fatal WebView failure를 제거하지 않도록 Store를 commit-on-success 전이로 변경한다. load generation, stale completion, dismiss와 retry 중복 방지는 Foundation-only 상태 machine으로 분리해 deterministic unit test로 고정한다.

## 산출물

- `Sources/HostApp/Services/DocumentOpenRecoveryState.swift`
  - 다섯 opening 입력 경로를 나타내는 `DocumentOpenSource`
  - 경로·원본 bytes 없이 표시 정보만 보관하는 `RecoverableDocumentOpenFailure`
  - load ID, loading, failure, dismiss와 retry를 관리하는 `DocumentOpenRecoveryState`
- `Sources/HostApp/Stores/DocumentViewerStore.swift`
  - chooser closure 주입, source-aware load와 recoverable 상태 노출
  - failure 보존·latest-success-only commit 전이
- `Sources/HostApp/Views/DocumentViewerView.swift`
  - opening 전용 전체 오류 화면 제거
  - native file URL drop source 명시
- `Tests/HostAppTests/DocumentOpenRecoveryTests.swift`
  - failure presentation과 상태 machine 전이 9개 테스트
- `project.yml`, `Alhangeul.xcodeproj/project.pbxproj`
  - recovery state를 HostAppTests selected source로 추가하고 XcodeGen 결과 반영
- `mydocs/working/task_m040_372_stage2.md`

SwiftUI window-local modal은 계획대로 Stage 3에 남겼다.

## 구현 내용

### recoverable failure 모델

`DocumentOpenSource`는 다음 입력 경로를 구분한다.

- `.filePanel`: 메뉴, toolbar, fatal fallback과 retry의 native panel
- `.externalOpen`: Finder/open URL, pending URL과 window initial URL
- `.recentDocument`: 최근 문서 bookmark 복원과 URL load
- `.fileDrop`: native file URL drop
- `.webViewDrop`: WebView host bridge가 전달한 bytes drop

`RecoverableDocumentOpenFailure`는 UUID identity, source, sanitize된 파일명, 제목과 사용자 메시지만 보관한다. 절대 경로가 전달되어도 마지막 path component만 남기며 빈 이름은 `nil`로 정리한다. URL, bookmark, 원본 `Error`와 문서 bytes는 장기 보관하지 않는다.

파일 패널·external open은 `문서를 열 수 없습니다`, 최근 문서는 `최근 문서를 열 수 없습니다`, 두 drop 경로는 `끌어놓은 문서를 열 수 없습니다` 제목을 사용한다. 세부 reason은 기존 `HwpDocumentInputError.localizedDescription` 또는 파일 접근 안내를 재사용한다.

### Foundation-only 상태 machine

`DocumentOpenRecoveryState`가 기존 Store의 `activeDocumentLoadID`와 opening loading/failure 상태를 소유한다.

- `beginLoad`: generation 증가, loading 시작, 이전 recoverable failure 해제
- `isCurrent`: async completion의 generation 확인
- `failLoad`: loading 중인 최신 generation만 failure로 종료
- `completeLoad`: loading 중인 최신 generation만 commit 허용
- `dismissFailure`: failure만 해제
- `beginRetry`: 현재 failure를 한 번만 retry intent로 소비

`failLoad`와 `completeLoad`는 같은 generation이라도 이미 종료된 load를 다시 처리하지 않는다. 이에 따라 failure 뒤 늦은 success, success 뒤 중복 completion과 stale generation이 Store commit 경계에 도달하지 않는다.

Store의 `@Published documentOpenRecoveryState`가 실제 제품 전이에 사용되며, `isLoading`과 `recoverableDocumentOpenFailure`는 해당 상태에서 읽는다. 테스트용 복제 state나 mock transition은 만들지 않았다.

### source-aware load와 chooser seam

Store initializer에 `@MainActor () -> URL?` chooser closure를 추가하고 기본 구현으로 `DocumentOpenPanel.chooseDocumentURL()`을 사용한다. `openDocument()`은 chooser가 URL을 반환한 뒤에만 `.filePanel` load를 시작하므로 panel 취소는 load ID, loading, 문서와 오류 상태를 변경하지 않는다.

`loadDocument(from:source:)`는 기본 source를 `.externalOpen`으로 두어 `DocumentOpenRouter`와 window initial URL의 기존 호출을 유지한다. native URL drop은 view callback에서 `.fileDrop`을 명시하고, bytes drop은 기존 별도 API에서 `.webViewDrop` failure를 생성한다.

최근 문서는 bookmark 복원부터 하나의 load attempt로 취급한다. `beginDocumentLoad` 뒤 resolve하고, 실패하면 `.recentDocument` recoverable failure로 종료한다. 성공하면 같은 load ID를 URL read와 validation에 전달하므로 중복 generation을 만들지 않는다.

### commit-on-success Store 전이

`beginDocumentLoad()`는 다음 동작만 수행한다.

1. 이전 protection classification task cancel
2. recovery state의 새 load 시작
3. 기존 nonfatal banner 정리
4. WebView loading flag 종료

기존 문서 payload, source, filename, revision, unsaved 상태와 fatal `webViewFailure`는 변경하지 않는다.

URL read와 `HwpDocumentInputValidator` 실패는 공통 `failDocumentLoad`에서 `RecoverableDocumentOpenFailure`를 만들고 recovery state만 종료한다. 기존 두 failure 경로의 `clearCurrentDocument()`와 bytes drop 자동 소멸 banner를 제거했다. `clearCurrentDocument()`는 호출이 남지 않아 함수 자체도 제거했다.

protection classification 뒤 `finishDocumentLoad`는 먼저 `completeLoad(loadID:)`의 commit 허용을 확인한다. 최신 loading generation일 때만 다음 문서 snapshot을 교체한다.

- `filename`
- `sourceDocument`
- `documentRevision`
- `hasUnsavedChanges`
- `rhwpStudioDocument`

정상 commit에서만 recoverable failure와 기존 fatal `webViewFailure`가 해제된다. 따라서 fatal fallback에서 잘못된 파일을 고르면 fatal 상태가 유지되고, 정상 파일 성공 시에만 새 문서로 복구된다.

### retry 준비

`dismissRecoverableDocumentOpenFailure()`는 recoverable failure만 해제한다. `retryDocumentOpen()`은 `beginRetry()`가 failure를 소비한 경우에만 main actor task를 만들고, `Task.yield()` 뒤 chooser를 호출한다. 같은 failure에 대한 두 번째 retry는 상태 machine에서 거부된다.

Stage 2에서는 Store action까지만 준비했다. SwiftUI sheet dismissal과 실제 button 연결은 Stage 3에서 수행한다.

### opening 전용 전체 오류 화면 제거

`errorMessage` producer는 URL opening catch 한 곳, consumer는 `DocumentViewerView` 한 곳뿐이었다. recoverable 상태로 대체하면서 published property와 `ErrorStateView` 분기를 제거했다. `DocumentViewerView`는 항상 기존 `RhwpStudioContainerView` hierarchy를 유지한다.

`webViewErrorMessage`의 저장·공유·PDF·Finder·nonfatal runtime banner와 `webViewFailure`의 fatal fallback은 변경하지 않았다.

## 자동 테스트

`DocumentOpenRecoveryTests`에 다음 9개 테스트를 추가했다.

1. 절대 경로 파일명 sanitize와 사용자 메시지 생성
2. 빈 파일명 생략
3. 다섯 source의 제목 mapping
4. 새 load generation 증가와 이전 failure 해제
5. 최신 failure 종료와 동일 generation의 늦은 completion 거부
6. stale failure 무시
7. 최신 completion 한 번만 commit 허용, stale·중복 completion 거부
8. dismiss가 failure만 해제하고 generation 유지
9. retry intent 한 번만 허용, chooser 취소에 해당하는 no-new-load 상태 유지

HostAppTests에는 `DocumentOpenRecoveryState.swift` 한 파일만 추가했다. Store 전체와 AppKit, WebView, Rhwp bridge 의존을 test target에 복제하지 않았다.

## Xcode project 변경

`project.yml`의 HostAppTests selected source에 `DocumentOpenRecoveryState.swift`를 추가한 뒤 `xcodegen generate`를 실행했다. 생성된 project diff는 다음 항목뿐이다.

- 제품·HostAppTests에 recovery state source reference와 build file 추가
- HostAppTests에 `DocumentOpenRecoveryTests.swift` reference와 build file 추가

`Alhangeul.xcodeproj`를 직접 수정하지 않았다. 재차 `xcodegen generate`를 실행해 결과가 deterministic함을 확인했다.

## 본문 변경 정도 / 본문 무손실 여부

- `Sources/RhwpCoreBridge`, Rust FFI, core dependency와 bundled `rhwp-studio` asset은 변경하지 않았다.
- 기존 정상 document commit, recent 기록, save/edit 상태와 WebView fatal/nonfatal 분류는 유지했다.
- opening failure에서 문서 snapshot을 지우는 동작만 제거했다.
- Stage 3 modal UI와 Stage 4 smoke·문서화 범위는 앞당기지 않았다.
- sample HWP/HWPX와 사용자 PDF는 수정하지 않았다.

## 검증 결과

### XcodeGen

```text
xcodegen generate
Created project at .../Alhangeul.xcodeproj
```

결과: 통과. 재생성 후 예상 diff 외 추가 변경 없음.

### HostAppTests

```text
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task372-stage2-tests \
  CODE_SIGNING_ALLOWED=NO test
```

결과: 통과.

- 전체 160 tests
- 실패 0, unexpected 0
- 신규 `DocumentOpenRecoveryTests` 9개 포함

첫 sandbox 실행은 Sparkle package repository의 DNS 접근이 차단돼 package resolution 전에 종료됐다. 허용된 네트워크·Xcode 캐시 환경에서 같은 명령을 다시 실행해 통과했으며 제품·테스트 실패가 아니다.

### HostApp Debug build

```text
xcodebuild -quiet -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task372-stage2-build \
  -clonedSourcePackagesDirPath build.noindex/task372-stage2-tests/SourcePackages \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO build
```

초기 compile에서 chooser closure가 nonisolated 함수 타입으로 추론돼 `DocumentOpenPanel.chooseDocumentURL()`의 main actor isolation 오류가 확인됐다. stored closure와 initializer parameter를 `@MainActor () -> URL?`로 보정한 뒤 재실행했다.

결과: 통과. Store, View, extensions와 Sparkle dependency compile/link 완료.

### 계층·문서 검사

```text
./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies

git diff --check
통과

rg -n --glob '*.swift' "errorMessage|clearCurrentDocument\\(" Sources/HostApp Tests/HostAppTests
검색 결과 없음
```

## 완료 기준 확인

- opening failure의 `clearCurrentDocument()` 호출 제거: 완료
- opening 전용 전체 화면 `errorMessage` 분기 제거: 완료
- recoverable source/failure/state model 구현: 완료
- chooser 주입과 retry intent 구현: 완료
- stale load와 latest-success-only commit 전이 구현: 완료
- focused 상태 전이 테스트: 완료, 9개 통과
- 전체 HostAppTests: 완료, 160개 통과
- HostApp Debug build와 AppKit 경계 검사: 완료
- `project.yml`과 XcodeGen project 일치: 완료

## 잔여 위험

- Stage 2에는 recoverable 상태를 표시할 UI가 아직 없으므로, opening failure는 상태로 보존되지만 사용자에게 modal이 보이지 않는다. Stage 3에서 즉시 연결한다.
- Store snapshot 필드는 HostAppTests selected-source 범위를 넓히지 않기 위해 직접 unit test하지 않았다. failure handler에 문서 field write가 없고 success handler만 commit하는 구조로 제한했으며, 실제 snapshot 무손실은 Stage 4 smoke에서 확인한다.
- `Task.yield()` 뒤 sheet dismissal과 `NSOpenPanel.runModal()`의 실제 순서는 Stage 3 macOS smoke가 필요하다.
- fatal fallback branch는 protection classification 동안 기존 loading overlay를 표시하지 않는다. 새 문서 성공·실패 전이에는 영향이 없으며 Stage 3에서 사용자 동작을 확인한다.
- recent bookmark failure가 진행 중 load를 supersede하는 동작은 generation 계약에 맞지만 실제 menu 재진입은 Stage 3/4 smoke로 확인한다.

## 다음 단계 영향

Stage 3에서는 다음 범위만 진행한다.

- `DocumentViewerView` root의 window-local recoverable sheet 또는 동등 overlay
- 제목, 파일명·reason, 닫기와 다시 시도 action
- modal dismissal 뒤 chooser 한 번 호출
- Escape/default action과 접근성 label·focus
- 파일 패널, external/recent, URL drop과 bytes drop의 presentation 정합성 확인

Store의 commit-on-success, parser `document-load-error` fatal 분류와 기존 WebView fallback은 변경하지 않는다.

## 승인 요청

Stage 2 recoverable opening 상태와 Store 전이 구현·검증 결과를 검토하고 Stage 3 window-local 복구 모달과 retry 통합 진입 승인을 요청한다.
