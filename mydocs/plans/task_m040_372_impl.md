# Task M040 #372 구현 계획서

## 작업 개요

- GitHub Issue: #372
- 마일스톤: M040 (`v0.4`)
- 제목: 지원하지 않는 파일 열기 실패를 복구 가능한 모달 UX로 전환
- 작업 브랜치: `local/task372`
- 기준 브랜치: `devel`
- 선행 수행계획: [`task_m040_372.md`](task_m040_372.md)
- 구현 단계: 4단계

지원하지 않거나 손상된 입력을 열 때 현재 viewer와 마지막 정상 문서를 제거하는 동작을 중단한다. HostApp의 파일 읽기·빈 파일·미지원 signature 실패는 별도의 recoverable opening failure 상태로 표현하고, 기존 viewer 위 window-local 모달에서 닫기와 파일 다시 선택을 제공한다. 새 문서는 validation과 보호 분류까지 성공한 뒤에만 현재 문서 상태로 commit하며, 기존 viewer asset·navigation·process fatal fallback은 그대로 유지한다.

## 조사 결과와 구현 근거

### 현재 문서 열기 경로

| 입력 경로 | HostApp 진입점 | 데이터 형태 | 현재 실패 표시 | 현재 문서 영향 |
| --- | --- | --- | --- | --- |
| 메뉴·toolbar·fatal fallback의 다른 파일 열기 | `DocumentViewerStore.openDocument()` | `NSOpenPanel` URL | `errorMessage` 전체 오류 화면 | `clearCurrentDocument()`로 제거 |
| Finder open·외부 open URL | `DocumentOpenRouter` → `loadDocument(from:)` | URL | `errorMessage` 전체 오류 화면 | `clearCurrentDocument()`로 제거 |
| 최근 문서 | `openRecentDocument(_:)` → `loadDocument(from:)` | bookmark 복원 URL | URL 복원 실패는 자동 소멸 banner, 이후 opening 실패는 전체 오류 화면 | opening 실패 시 제거 |
| native file URL drop | `RhwpStudioWebView` callback → `loadDocument(from:)` | URL | `errorMessage` 전체 오류 화면 | `clearCurrentDocument()`로 제거 |
| WebView dropped bytes | `RhwpStudioWebView` callback → `loadDroppedDocument(data:filename:)` | bytes와 표시 이름 | 자동 소멸 banner | `clearCurrentDocument()`로 제거 |

모든 URL 기반 경로는 최종적으로 `loadDocument(from:)`에 모이고, bytes drop은 `startDocumentLoad`부터 같은 validation 경로를 공유한다. 따라서 recoverable 상태 생성은 두 load 진입점의 공통 실패 처리로 정렬하고, 파일 선택 UI는 retry를 시험할 수 있는 좁은 경계로 분리한다.

### 현재 파괴적 상태 전이

`beginDocumentLoad()`는 새 시도 시작 시 `errorMessage`, nonfatal banner, fatal `webViewFailure`와 WebView loading 상태를 즉시 지운다. 이어 파일 읽기 또는 `HwpDocumentInputValidator.validateOpeningData(_:)`가 실패하면 `clearCurrentDocument()`가 payload, source, filename, unsaved 상태와 fatal failure를 제거한다. `DocumentViewerView`는 `errorMessage`가 있으면 `RhwpStudioContainerView` 전체를 `ErrorStateView`로 교체한다.

반면 새 문서의 실제 payload 교체는 protection classification이 끝난 `finishDocumentLoad`에서만 발생한다. 새 입력의 성공 전에는 기존 payload를 바꿀 필요가 없으므로, 실패 처리에서 현재 문서를 지우지 않고 별도 presentation 상태만 commit하면 마지막 정상 snapshot을 자연스럽게 보존할 수 있다.

### recoverable과 fatal 경계

이번 타스크의 recoverable 범위는 HostApp이 WebView에 문서를 전달하기 전에 확인할 수 있는 다음 실패로 제한한다.

- security-scoped URL의 데이터 읽기 실패
- 0-byte 입력
- HWP/HWPX로 판별할 수 없는 signature
- 최근 문서 bookmark 복원 또는 파일 접근 실패처럼 사용자가 다른 파일 선택으로 복구할 수 있는 opening 실패

다음 실패는 기존 `RhwpStudioWebViewFailure` 정책을 유지한다.

- bundled viewer asset preflight와 resource loading 실패
- document scheme 또는 navigation policy 실패
- navigation timeout과 WebContent process 종료
- WebView가 문서를 받은 뒤 보고한 parser `document-load-error`

`document-load-error`에는 signature가 맞지만 내부 구조가 손상된 입력도 포함될 수 있으나, 이를 recoverable로 낮추면 #150에서 확정한 fatal fallback 계약까지 변경된다. 이 경로는 Stage 1에서 실제 callback과 분류를 다시 확인해 경계를 기록하되, 별도 승인 없이 구현 범위에 추가하지 않는다.

## 구현 원칙

1. recoverable opening failure는 `errorMessage`, 자동 소멸 `webViewErrorMessage`, fatal `webViewFailure`와 구분된 명시적 상태로 둔다.
2. 새 입력은 validation과 protection classification이 성공한 뒤에만 payload, source, filename, revision, unsaved 상태를 교체한다.
3. 실패한 입력은 현재 정상 문서 snapshot과 기존 fatal failure를 변경하지 않는다.
4. 새 load 시도는 이전 async task를 cancel하고 load ID를 갱신하되, UI 상태는 성공 또는 해당 load ID의 실패가 확정될 때만 전이한다.
5. 성공한 새 문서 load는 recoverable failure와 기존 fatal failure를 함께 해제하고 새 문서를 표시한다.
6. recoverable 상태에는 표시 이름, 제목, 사용자 안내 문구와 입력 경로 종류만 보관하며 절대 경로나 원본 bytes는 보관하지 않는다.
7. 닫기는 recoverable 상태만 해제한다. retry는 상태를 먼저 해제한 다음 다음 main actor turn에서 파일 패널을 한 번만 연다.
8. 파일 패널 취소는 현재 문서, loading, recoverable/fatal 상태를 새로 변경하지 않는다.
9. 같은 창에는 recoverable 모달을 하나만 표시하며, stale load의 실패나 완료는 최신 상태를 덮어쓰지 못한다.
10. `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 추가하지 않고, Xcode target 변경은 `project.yml`에서만 수행한 뒤 `xcodegen generate` 결과를 반영한다.

## 상태 모델과 전이 계약

### recoverable opening failure

HostApp 전용 값 타입 `RecoverableDocumentOpenFailure`를 두는 방향을 기본안으로 한다. 구현 시 기존 명명 체계에 맞춰 파일 위치나 이름은 조정할 수 있지만 아래 의미는 유지한다.

- `source`: 파일 패널·open URL·최근 문서·URL drop·bytes drop 중 사용자 문구와 테스트에 필요한 입력 경로
- `filename`: 경로를 제거하고 sanitize한 표시 이름 또는 `nil`
- `title`: 짧은 modal 제목
- `message`: 사용자가 다음 행동을 판단할 수 있는 설명
- stable identity: SwiftUI presentation과 중복 상태 교체에 필요한 식별자

모델은 원본 `Error`, URL, bookmark, bytes를 보유하지 않는다. 진단 세부 정보가 필요하면 개발 로그에서만 기록하고, modal에는 사용자 행동에 필요한 정보만 표시한다.

### 문서 snapshot

실패 시 보존 대상으로 다음 store 상태를 하나의 논리적 snapshot으로 취급한다.

- `rhwpStudioDocument`
- `sourceDocument`
- `filename`
- `documentRevision`
- `hasUnsavedChanges`
- `webViewReloadToken`
- 기존 `webViewFailure`

`isLoading`, `isWebViewLoading`, nonfatal banner와 recoverable presentation은 시도별 UI 상태이므로 snapshot과 분리한다. 특히 새 시도 시작 시 fatal failure를 지우지 않고, 정상 문서 commit이 성공했을 때에만 지운다. 이 규칙으로 fatal fallback의 ‘다른 파일 열기’에서 잘못된 파일을 다시 골라도 기존 진단 화면이 사라지지 않으며, 정상 파일을 고르면 새 문서로 복구할 수 있다.

### 전이 표

| 이벤트 | 문서 snapshot | recoverable 상태 | fatal 상태 | loading |
| --- | --- | --- | --- | --- |
| 새 load 시작 | 유지 | 이전 opening 실패 해제 | 유지 | 시작 |
| 최신 load의 읽기·validation 실패 | 유지 | 최신 실패 표시 | 유지 | 종료 |
| stale load 실패·완료 | 유지 | 변경 없음 | 변경 없음 | 최신 load 기준 유지 |
| 모달 닫기 | 유지 | 해제 | 유지 | 변경 없음 |
| retry 선택 | 유지 | 먼저 해제 | 유지 | 패널 선택 후 load 시작 |
| retry 패널 취소 | 유지 | 해제 상태 유지 | 유지 | 시작하지 않음 |
| 최신 load 성공 | 새 문서로 교체 | 해제 | 해제 | 종료 |

`errorMessage`가 opening failure에만 사용되고 다른 활성 경로가 없는지 Stage 1에서 확인한다. opening 전용으로 확인되면 제거하거나 더 이상 view 분기에 사용하지 않고, 다른 용도가 남아 있으면 해당 용도만 보존한다. 제품 동작과 무관한 dead state 제거는 이번 변경 범위 안에서 최소화한다.

## 파일 선택과 modal presentation 계약

### 파일 선택 경계

`DocumentOpenPanel.chooseDocumentURL()`의 직접 static 호출은 retry 호출 횟수와 취소 동작을 deterministic하게 검증하기 어렵다. Stage 2에서는 다음 중 의존 범위가 작은 방식을 inventory 결과에 따라 확정한다.

- store initializer에 `@MainActor () -> URL?` chooser closure를 주입하고 기본값으로 `DocumentOpenPanel.chooseDocumentURL` 사용
- 동일 의미의 작은 protocol 또는 adapter를 HostApp services에 추가

기본 선택은 closure 주입이다. 한 기능을 위해 AppKit service 계층을 확장하지 않고도 ‘한 번 호출’, ‘취소’, ‘선택 URL 전달’을 검증할 수 있기 때문이다. chooser는 main actor에서만 호출하고 URL 선택 뒤 기존 `loadDocument(from:)` 경로를 그대로 사용한다.

### retry 순서

retry 버튼은 다음 순서를 지킨다.

1. 현재 recoverable 상태를 해제한다.
2. SwiftUI modal dismissal이 반영되도록 다음 main actor turn까지 양보한다.
3. chooser를 정확히 한 번 호출한다.
4. URL이 있으면 기존 load pipeline을 시작하고, `nil`이면 아무 상태도 추가로 바꾸지 않는다.

실제 구현은 `Task { @MainActor in await Task.yield(); ... }` 또는 동등하게 modal session 중첩을 방지하는 좁은 scheduling helper를 사용한다. 무기한 delay나 임의 sleep은 사용하지 않는다. 중복 탭으로 두 panel이 열리지 않도록 recoverable state 해제와 action guard를 같은 main actor 전이에서 처리한다.

### window-local UI

`DocumentViewerView`의 기존 viewer/fatal fallback hierarchy는 유지하고 그 바깥에 recoverable presentation을 연결한다. SwiftUI `sheet(item:)`를 기본안으로 하며, macOS 12 지원과 실제 dismissal/panel 순서에서 문제가 확인될 때만 동등한 window-local overlay로 조정한다.

modal은 다음 요소를 제공한다.

- 실패 유형과 파일명을 반영한 제목·설명
- `닫기`: cancel role 또는 Escape로 실행
- `다시 시도`: 기본 action, 해제 후 파일 패널 호출
- VoiceOver에서 의미가 분명한 label과 keyboard focus

modal 표시 중에도 아래 viewer는 제거하지 않는다. 기존 문서가 없으면 empty viewer를 유지한다. fatal fallback 위에서 recoverable modal이 표시되는 경우 modal을 닫으면 동일 fatal fallback으로 돌아온다.

## 테스트 설계

### 자동 검증 경계

`DocumentViewerStore`를 현재 HostAppTests에 직접 포함하면 RecentDocument, AppKit, WebView failure, bridge model 등 의존 파일이 넓게 따라온다. Stage 1에서 target source 구성을 확인한 뒤 다음 우선순위로 최소 seam을 선택한다.

1. chooser와 opening failure mapping을 순수 Foundation 타입·closure로 분리한다.
2. snapshot 보존과 load ID 전이는 실제 store API를 시험할 수 있도록 필요한 제품 타입만 HostAppTests에 포함한다.
3. store 직접 테스트의 target 확장이 과도하면 상태 전이 helper를 순수 타입으로 추출하고, store 연결은 focused integration smoke로 보완한다.

테스트 편의를 위해 제품 상태를 이중화하거나 별도 mock store를 만들지 않는다. 어떤 seam을 선택하든 실제 store가 같은 전이 함수를 사용해야 하며, `project.yml`의 test source 목록 변경과 생성된 Xcode project diff를 Stage 2 보고서에 기록한다.

### 필수 상태 전이 테스트

- 정상 문서 snapshot 뒤 PDF signature 실패 시 payload/source/filename/revision/unsaved 상태 유지
- 빈 bytes와 unknown signature가 서로 적절한 사용자 안내로 매핑
- URL 읽기 실패와 최근 문서 접근 실패가 recoverable 상태로 수렴
- bytes drop 실패도 현재 문서를 보존하고 자동 소멸 banner 대신 recoverable 상태 표시
- 닫기가 recoverable 상태만 해제
- retry가 chooser를 정확히 한 번 호출
- retry 패널 취소가 기존 snapshot과 fatal 상태를 유지
- retry에서 정상 HWP/HWPX를 선택하면 새 문서로 commit하고 recoverable/fatal 상태 해제
- 연속 load에서 이전 protection classification 또는 실패가 최신 load를 덮어쓰지 않음
- fatal `RhwpStudioWebViewFailure` 상태에서 잘못된 파일 실패 후 기존 fatal 상태 유지

UI의 sheet 렌더링 자체는 unit test에 과도하게 결합하지 않는다. button callback, presentation binding과 접근성 문구는 compile/test와 HostApp smoke로 검증한다.

## 예상 변경 파일

- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift`
- `Sources/HostApp/Services/DocumentOpenPanel.swift` 또는 chooser 주입 경계 파일
- `Sources/HostApp/Services/RecoverableDocumentOpenFailure.swift` (신규 예상)
- `Tests/HostAppTests/DocumentOpenRecoveryTests.swift` (신규 예상)
- `project.yml`
- `Alhangeul.xcodeproj/project.pbxproj` (`xcodegen generate` 결과만)
- `mydocs/tech/project_architecture.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/working/task_m040_372_stage1.md`
- `mydocs/working/task_m040_372_stage2.md`
- `mydocs/working/task_m040_372_stage3.md`
- `mydocs/working/task_m040_372_stage4.md`
- `mydocs/report/task_m040_372_report.md`
- `mydocs/orders/20260825.md`

예상 파일은 단계 조사 결과에 따라 줄어들거나 이름이 바뀔 수 있다. 범위 밖 core, bundled `rhwp-studio` asset, Quick Look/Thumbnail 코드는 변경하지 않는다.

## Stage 1. opening failure 상태 전이 계약 확정

### 목표

제품 소스 변경 전에 모든 문서 열기 진입점과 실패 callback을 추적하고, recoverable/fatal 경계·snapshot 보존·테스트 seam을 확정한다.

### 작업

- 파일 패널, Finder/open URL, 최근 문서, native URL drop, WebView dropped bytes의 호출 경로와 오류 표시를 표로 확정한다.
- `errorMessage`, `webViewErrorMessage`, `webViewFailure`의 모든 생산자와 소비자를 조사한다.
- `beginDocumentLoad`, `startDocumentLoad`, `finishDocumentLoad`, cancel/load ID 전이를 sequence 단위로 정리한다.
- parser `document-load-error`가 발생하는 bridge callback을 확인하고 이번 타스크에서는 fatal 유지임을 기록한다.
- HostAppTests source 구성과 store 의존 그래프를 확인해 chooser 주입 및 상태 전이 테스트 seam을 확정한다.
- 조사 결과와 최종 계약을 `mydocs/working/task_m040_372_stage1.md`에 기록한다.

### 검증 시나리오

- 정상 문서가 있는 창과 없는 창의 읽기·signature 실패 결과가 각각 정의되어 있다.
- fatal fallback의 다른 파일 열기에서 실패·취소·성공 결과가 모두 정의되어 있다.
- native URL drop과 bytes drop의 source/bookmark 차이를 유지하면서 실패 presentation은 같아진다.
- async protection classification이 연속 load와 충돌하지 않는 load ID 규칙이 명시되어 있다.
- 자동 테스트가 실제 제품 전이를 사용하면서 HostAppTests 의존 확장을 최소화한다.

### 완료 기준

- recoverable/fatal 분류표와 상태 전이표가 stage 보고서에 포함된다.
- Stage 2에서 사용할 모델 위치, chooser seam, test target source 변경 범위가 확정된다.
- 승인된 수행계획과 다른 범위 확대가 없다.
- Stage 1 보고서와 조사 문서만 변경되고 제품 소스는 변경되지 않는다.

### 검증

```sh
rg -n "errorMessage|webViewErrorMessage|webViewFailure|loadDocument|loadDroppedDocument|document-load-error" Sources Tests project.yml
git diff --check
git status --short --branch
```

### 커밋 메시지

`Task #372 Stage 1: opening failure 상태 전이 계약 확정`

## Stage 2. recoverable opening 상태와 store 전이 구현

### 목표

recoverable failure 모델, chooser 주입 경계와 commit-on-success store 전이를 구현하고 snapshot 보존을 자동 테스트로 고정한다.

### 작업

- `RecoverableDocumentOpenFailure`와 source/error mapping을 구현한다.
- store에 recoverable published state, dismiss와 retry action을 추가한다.
- 파일 선택 chooser를 주입 가능한 좁은 경계로 바꾼다.
- `beginDocumentLoad`가 현재 snapshot과 fatal 상태를 보존하고 async stale completion을 차단하도록 정리한다.
- URL 읽기, opening validation, 최근 문서 복원과 bytes drop 실패를 recoverable 상태로 수렴시킨다.
- 성공한 `finishDocumentLoad`에서만 새 snapshot을 commit하고 recoverable/fatal 상태를 해제한다.
- Stage 1에서 확정한 seam으로 `DocumentOpenRecoveryTests`를 추가하고 `project.yml`을 갱신한다.
- `xcodegen generate`로 Xcode project를 재생성한다.

### 검증 시나리오

- 정상 snapshot 뒤 PDF·빈 bytes·unknown signature 실패가 snapshot을 변경하지 않는다.
- retry chooser 호출 횟수와 취소 결과가 deterministic하다.
- 정상 입력 성공 시 revision이 한 번 증가하고 새 payload/source/filename으로 교체된다.
- 이전 load의 늦은 protection 결과는 최신 load를 commit하거나 loading을 종료하지 않는다.
- fatal fallback 상태에서 opening 실패는 fatal 상태를 보존하고, 정상 입력 성공은 fatal 상태를 해제한다.
- bytes drop 실패는 source URL을 임의로 만들지 않고 동일 recoverable presentation을 사용한다.

### 완료 기준

- opening failure가 더 이상 `clearCurrentDocument()`를 호출하지 않는다.
- opening failure를 위한 전체 화면 `errorMessage` 분기가 제거되거나 비활성화된다.
- 필수 상태 전이 테스트가 통과한다.
- `project.yml`과 생성된 project diff가 일치하며 xcodeproj 직접 수정이 없다.
- Stage 2 소스·테스트와 `task_m040_372_stage2.md`가 한 커밋으로 묶인다.

### 검증

```sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task372-stage2-tests CODE_SIGNING_ALLOWED=NO test
./scripts/check-no-appkit.sh
git diff --check
git status --short --branch
```

### 커밋 메시지

`Task #372 Stage 2: recoverable opening 상태와 store 전이 구현`

## Stage 3. window-local 복구 모달과 retry 통합

### 목표

기존 viewer 또는 fatal fallback을 유지한 채 window-local 복구 모달을 표시하고, 닫기·retry·키보드·접근성 동작을 모든 입력 경로에 연결한다.

### 작업

- `DocumentViewerView` root에 recoverable state 기반 `sheet(item:)` 또는 검증된 동등 overlay를 연결한다.
- 제목, 파일명, 설명, 닫기와 다시 시도 action을 구현한다.
- retry가 modal dismissal 뒤 다음 main actor turn에서 chooser를 한 번만 호출하도록 연결한다.
- Escape/cancel, 기본 action, VoiceOver label과 초기 focus를 macOS 12+ 범위에서 확인한다.
- 파일 패널, Finder/open, 최근 문서, URL drop과 bytes drop의 표시 문구와 재진입 동작을 정렬한다.
- modal 중복 표시, 빠른 연속 action과 panel 취소를 확인한다.

### 검증 시나리오

- 마지막 정상 문서가 있는 창에서 미지원 파일 실패 시 문서가 modal 뒤에 그대로 남는다.
- 닫기 후 기존 문서를 계속 조작할 수 있다.
- 다시 시도는 기존 sheet와 `NSOpenPanel` modal session을 중첩하지 않는다.
- 패널 취소는 기존 문서와 fatal/recoverable 상태를 예상대로 유지한다.
- 정상 문서가 없는 창에서도 modal을 닫거나 retry하고 다시 drop할 수 있다.
- fatal fallback의 다른 파일 열기에서 잘못된 입력은 fatal 화면을 보존하고 정상 입력은 새 viewer로 전환한다.

### 완료 기준

- recoverable opening failure가 전체 viewer를 교체하지 않는다.
- 닫기·다시 시도·키보드·접근성 동작이 window-local하게 작동한다.
- 모든 opening 진입점이 같은 presentation 계약을 사용한다.
- HostAppTests와 HostApp Debug build가 통과한다.
- Stage 3 소스·테스트와 `task_m040_372_stage3.md`가 한 커밋으로 묶인다.

### 검증

```sh
xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task372-stage3-tests CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task372-stage3-build CODE_SIGNING_ALLOWED=NO build
./scripts/check-no-appkit.sh
git diff --check
git status --short --branch
```

### 커밋 메시지

`Task #372 Stage 3: window-local 복구 모달과 retry 통합`

## Stage 4. negative opening smoke와 문서화

### 목표

대표 실패·정상·fatal 입력을 실제 HostApp에서 검증하고, 최종 상태 계약과 재현 절차를 architecture·build/run 문서에 반영한다.

### 대표 입력

- 정상 HWP 5 문서
- 정상 HWPX 문서
- PDF 파일
- 0-byte 파일
- HWP/HWPX와 다른 unknown signature 파일
- viewer asset 하나를 의도적으로 누락한 Debug negative copy

fixture를 새로 만들 경우 `build.noindex/task372-smoke/` 아래에 두고 원본 문서를 수정하지 않는다. 사용한 입력은 경로, 크기, SHA-256과 검증 전후 수정 시각을 stage 보고서에 기록한다.

### 작업

- 정상 문서가 있는 창과 없는 새 창에서 PDF·빈 파일·unknown signature를 파일 패널과 drag/drop으로 시도한다.
- 닫기 뒤 기존 문서 조작, retry 패널 취소, retry 정상 HWP/HWPX 교체를 확인한다.
- 최근 문서와 Finder/open URL 실패 경로가 같은 recoverable 계약을 따르는지 확인한다.
- asset negative copy에서 기존 fatal fallback과 진단 정보가 유지되는지 회귀 확인한다.
- `mydocs/tech/project_architecture.md`에 recoverable opening 상태와 fatal WebView 경계를 반영한다.
- `mydocs/manual/build_run_guide.md`에 negative opening smoke 절차와 기대 결과를 반영한다.
- 전체 자동 검증을 실행하고 `mydocs/working/task_m040_372_stage4.md`에 결과를 기록한다.

### 검증 시나리오

- PDF·0-byte·unknown signature마다 recoverable modal이 표시되고 현재 snapshot이 유지된다.
- URL drop과 bytes drop 모두 실패 뒤 재시도할 수 있다.
- retry에서 HWP와 HWPX가 각각 정상 commit된다.
- normal open, save/recent/Finder 연동과 unsaved 표시가 회귀하지 않는다.
- asset negative copy는 recoverable modal이 아니라 기존 fatal fallback을 표시한다.
- smoke 원본 파일의 SHA-256과 수정 시각이 검증 전후 동일하다.

### 완료 기준

- Issue #372 수용 기준의 자동 검증과 실제 앱 smoke가 모두 통과한다.
- recoverable/fatal 경계와 재현 절차가 필수 문서에 반영된다.
- Debug Quick Look/Thumbnail 등록을 만들지 않으며, 임시 HostApp 실행 산출물은 `build.noindex/`에만 존재한다.
- Stage 4 소스·문서와 `task_m040_372_stage4.md`가 한 커밋으로 묶인다.

### 검증

```sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostAppTests -configuration Debug -derivedDataPath build.noindex/task372-final-tests CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/task372-final-build CODE_SIGNING_ALLOWED=NO build
./scripts/check-no-appkit.sh
shasum -a 256 <smoke-inputs>
git diff --check
git status --short --branch
```

### 커밋 메시지

`Task #372 Stage 4: negative opening smoke와 문서화`

## 전체 수용 기준

- 미지원·빈·읽기 실패 입력이 기존 viewer를 전체 오류 화면으로 교체하지 않는다.
- 실패한 새 입력은 마지막 정상 payload, source, filename, revision과 unsaved 상태를 보존한다.
- window-local modal에서 닫기와 다시 시도가 제공된다.
- retry modal dismissal과 `NSOpenPanel`이 중첩되지 않고 chooser가 한 번만 호출된다.
- 패널 취소 뒤 기존 문서 또는 fatal fallback이 그대로 유지된다.
- 정상 HWP/HWPX 재시도 성공 시 새 문서가 한 번만 commit된다.
- 파일 패널, Finder/open, 최근 문서, URL drop과 bytes drop이 같은 recoverable 계약을 따른다.
- viewer asset·navigation·timeout·process·parser fatal failure의 기존 fallback 계약이 유지된다.
- HostAppTests, HostApp Debug build와 bridge AppKit 경계 검사가 통과한다.

## 범위 이탈 처리

Stage 조사나 구현 중 다음 항목이 필요해지면 해당 단계에서 중단하고 작업지시자 승인을 다시 받는다.

- parser `document-load-error`를 recoverable로 재분류
- core 또는 bundled `rhwp-studio` parsing 동작 변경
- 기존 fatal fallback UI나 분류 변경
- Quick Look/Thumbnail 동작 변경
- 지원 문서 형식 추가
- release, signing, notarization 또는 배포 작업

## 단계 승인 게이트

- 각 Stage는 구현·검증·`task_m040_372_stage{N}.md` 작성과 단계 커밋까지 완료한 뒤 결과를 보고한다.
- 작업지시자의 명시적 승인 전에는 다음 Stage를 시작하지 않는다.
- 단계에서 계획과 다른 설계 판단이나 범위 확대가 필요하면 구현 전에 차이와 영향을 보고한다.
- Stage 4 승인 뒤에만 `task-final-report` 절차로 최종 보고서, 오늘할일 완료, 최종 커밋, publish branch와 PR 게시를 진행한다.

## 승인 요청 사항

1. 위 recoverable/fatal 경계와 commit-on-success 상태 전이 승인
2. chooser closure 주입을 기본안으로 한 retry·취소 테스트 경계 승인
3. 기존 viewer 위 window-local sheet와 modal dismissal 후 파일 패널 호출 순서 승인
4. 4단계 구현·검증 계획 승인
5. 승인 후 Stage 1 조사와 단계 보고서 작성 진행 승인
