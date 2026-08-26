# Task M040 #372 Stage 3 완료 보고서

## 단계 목적

recoverable opening failure가 기존 viewer 또는 fatal fallback을 교체하지 않도록 `DocumentViewerView` root에 window-local 복구 시트를 연결한다. 닫기·다시 시도·Escape·Return 기본 동작과 접근성 label을 제공하고, 다시 시도 시 SwiftUI sheet dismissal과 `NSOpenPanel` modal session이 중첩되지 않도록 retry 전이를 확정한다.

## 산출물

- `Sources/HostApp/Services/DocumentOpenRecoveryState.swift`
  - sheet dismissal 뒤 한 번만 소비되는 retry pending 상태
- `Sources/HostApp/Stores/DocumentViewerStore.swift`
  - retry intent 생성과 sheet `onDismiss` 후 chooser 호출 분리
- `Sources/HostApp/Views/DocumentViewerView.swift`
  - window-local recoverable sheet와 전용 modal view
  - 닫기·다시 시도·키보드·접근성·초기 focus 계약
- `Tests/HostAppTests/DocumentOpenRecoveryTests.swift`
  - retry pending의 단일 소비와 취소·새 load 전이 테스트
- `mydocs/working/task_m040_372_stage3.md`

## 구현 내용

### window-local 복구 시트

`DocumentViewerView`의 기존 `RhwpStudioContainerView` hierarchy는 그대로 두고 root에 `sheet(item:onDismiss:)`를 연결했다. sheet item은 Stage 2에서 모든 opening source가 공통으로 생성하는 `RecoverableDocumentOpenFailure`이므로 파일 패널, Finder/open URL, 최근 문서, native URL drop과 WebView bytes drop이 같은 presentation 경계를 사용한다.

sheet는 다음 정보를 표시한다.

- source별 `failure.title`
- sanitize된 파일명과 실패 reason을 포함한 `failure.message`
- `닫기` cancel action
- `다시 시도` default action

따라서 실패가 발생해도 viewer 전체를 오류 화면으로 교체하지 않고 현재 window 위에만 복구 UI가 나타난다. 다른 window의 Store와 sheet 상태에는 영향을 주지 않는다.

### retry dismissal 핸드셰이크

Stage 2의 `Task.yield()` 기반 retry 호출은 제거했다. 새 전이는 다음 순서를 강제한다.

1. `다시 시도`가 `beginRetry()`를 호출한다.
2. recovery state가 현재 failure를 지우고 `isRetryPending`을 설정한다.
3. failure item이 사라지면서 SwiftUI sheet가 닫힌다.
4. sheet `onDismiss`가 `consumeRetry()`를 한 번만 성공시킨다.
5. 그 뒤 `openDocument()`가 native file panel을 연다.

이 구조는 main actor scheduling 시점에 기대지 않고 SwiftUI가 sheet dismissal을 완료했다고 알린 뒤에만 `NSOpenPanel`을 연다. retry pending은 소비 후 즉시 해제되며, 닫기 또는 새 load 시작도 pending을 취소한다.

### 닫기·중복 action·panel 취소

sheet Binding의 `nil` setter는 `dismissRecoverableDocumentOpenFailure()`로 연결했다. 이에 따라 닫기 버튼과 Escape dismissal은 failure와 retry pending을 함께 해제한다. `onDismiss`가 뒤이어 호출되어도 `consumeRetry()`가 실패하므로 파일 패널은 열리지 않는다.

`beginRetry()`는 현재 failure가 있고 pending이 없을 때만 성공하며, `consumeRetry()`는 pending을 한 번만 소비한다. 빠른 연속 action이나 중복 `onDismiss`가 chooser를 두 번 열 수 없다. 재시도 패널 자체를 취소하면 새 load를 시작하지 않으므로 기존 viewer와 fatal/recoverable 상태 계약을 변경하지 않는다.

### 키보드와 접근성

- 닫기: `.keyboardShortcut(.cancelAction)`과 cancel role
- 다시 시도: `.keyboardShortcut(.defaultAction)`
- 초기 focus 요청: `@FocusState`로 다시 시도 버튼을 sheet 표시 시 focus
- 닫기 접근성 label: `문서 열기 오류 닫기`
- 다시 시도 접근성 label: `파일 다시 선택`
- 장식 icon: accessibility tree에서 제외

Debug 앱 accessibility tree에서 두 버튼의 label을 확인했다. 실제 Return 입력은 재시도 file panel을 열었고, Escape 입력은 sheet만 닫고 panel을 열지 않았다.

## 자동 테스트

기존 dismiss/retry 테스트를 retry pending 계약까지 확장하고 다음 시나리오를 추가했다.

1. retry intent 생성 후 pending이 설정된다.
2. pending은 `consumeRetry()`에서 정확히 한 번만 소비된다.
3. 두 번째 consume은 실패한다.
4. dismiss는 pending을 취소한다.
5. 새 load 시작은 이전 pending을 취소하고 새 generation을 유지한다.

전체 HostAppTests는 Stage 2의 160개에서 161개로 증가했다.

## 실제 앱 UI smoke

`build.noindex/task372-stage3-build/Build/Products/Debug/Alhangeul.app`을 실행하고 `/Users/melee/Documents/test.pdf`를 파일 패널에서 선택했다. Computer Use로 실제 macOS UI와 accessibility tree를 확인했다.

### 확인 결과

1. 빈 viewer window에서 PDF를 열면 `문서를 열 수 없습니다` sheet가 window-local하게 표시됐다.
2. 메시지에 `파일: test.pdf`와 `이 파일은 HWP/HWPX 형식이 아니거나 손상되었습니다.`가 표시됐다.
3. accessibility tree에 `문서 열기 오류 닫기`, `파일 다시 선택` 버튼이 노출됐다.
4. 닫기를 누르면 sheet가 사라지고 기존 rhwp-studio viewer가 그대로 남았다.
5. 다시 시도를 누르면 sheet가 사라진 뒤 `HWP 문서 열기` panel만 표시됐다. sheet와 panel의 동시 노출은 없었다.
6. 재시도 panel을 취소하면 viewer로 복귀하고 오류 sheet가 다시 나타나지 않았다.
7. sheet에서 Escape를 누르면 sheet만 닫히고 file panel은 열리지 않았다.
8. sheet에서 Return을 누르면 default retry action이 실행되고 sheet dismissal 뒤 file panel이 열렸다.

테스트 입력은 읽기 전용으로 선택했으며 원본 PDF를 수정하지 않았다. Debug Quick Look/Thumbnail 등록은 수행하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- `Sources/RhwpCoreBridge`, Rust FFI, core dependency와 bundled `rhwp-studio` asset은 변경하지 않았다.
- Stage 2의 commit-on-success 문서 전이와 recoverable/fatal 분류는 변경하지 않았다.
- 기존 fatal fallback UI, WebView runtime banner, save/share/PDF export 동작은 변경하지 않았다.
- `project.yml`과 `Alhangeul.xcodeproj`는 변경하지 않았다.
- sample HWP/HWPX와 사용자 PDF는 수정하지 않았다.

## 검증 결과

### HostAppTests

```text
xcodebuild -quiet -project Alhangeul.xcodeproj \
  -scheme HostAppTests \
  -configuration Debug \
  -derivedDataPath build.noindex/task372-stage3-tests \
  -clonedSourcePackagesDirPath build.noindex/task372-stage2-tests/SourcePackages \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO test
```

결과: 통과.

- 전체 161 tests
- 성공 161
- 실패 0
- skip 0
- xcresult: `build.noindex/task372-stage3-tests/Logs/Test/Test-HostAppTests-2026.08.26_00-13-22-+0900.xcresult`

### HostApp Debug build

```text
xcodebuild -quiet -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/task372-stage3-build \
  -clonedSourcePackagesDirPath build.noindex/task372-stage2-tests/SourcePackages \
  -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=NO build
```

결과: 통과. Store의 Bool 반환값 미사용 warning을 명시적 discard로 보정한 뒤 재실행했으며 제품 compile/link 오류와 warning이 없다. Xcode의 일반 destination 선택 안내만 출력됐다.

### 계층·diff 검사

```text
./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies

git diff --check
통과
```

## 완료 기준 확인

- viewer hierarchy를 유지하는 window-local recoverable sheet: 완료
- 제목·파일명·reason·닫기·다시 시도 표시: 완료
- sheet dismissal 뒤 chooser 단일 호출: 완료
- Escape cancel과 Return default action: 실제 UI 확인 완료
- 접근성 label과 다시 시도 초기 focus 계약: 구현 및 accessibility tree 확인 완료
- 중복 retry·dismiss·새 load 상태 전이: 단위 테스트 완료
- panel 취소 후 viewer 복귀: 실제 UI 확인 완료
- 공통 recoverable state를 통한 opening source presentation 통합: 완료
- HostAppTests 161개와 HostApp Debug build: 통과
- AppKit 경계와 diff 검사: 통과

## 잔여 위험

- 정상 HWP/HWPX가 이미 열린 window에서 실패 후 snapshot·unsaved 상태가 유지되는지, retry 성공으로 정상 문서가 한 번만 commit되는지는 Stage 4 대표 입력 smoke에서 확인한다.
- Finder/open URL, 최근 문서, URL drop과 bytes drop은 공통 Store state와 단일 sheet 연결을 사용하지만 실제 입력별 UI smoke는 Stage 4에서 수행한다.
- fatal asset negative copy에서 잘못된 입력 뒤 fallback이 유지되고 정상 retry로 viewer가 복구되는 실제 회귀 검증은 Stage 4 범위다.
- VoiceOver 음성 순서 전체 검증은 수행하지 않았다. macOS accessibility tree의 label 노출과 키보드 동작까지 확인했다.

## 다음 단계 영향

Stage 4에서는 계획된 대표 입력을 실제 HostApp에서 검증하고 문서화한다.

- 정상 HWP 5와 HWPX
- PDF, 0-byte, unknown signature
- 파일 패널, Finder/open URL, 최근 문서, URL drop과 bytes drop
- 기존 문서 snapshot·unsaved 상태 보존과 retry 정상 commit
- viewer asset negative copy의 fatal fallback 회귀
- architecture와 build/run manual 반영

Stage 3의 sheet·retry 상태 전이는 변경하지 않고 실제 입력 smoke에서 발견되는 결함만 승인 범위 안에서 보정한다.

## 승인 요청

Stage 3 window-local 복구 모달과 retry 통합 구현·검증 결과를 검토하고 Stage 4 negative opening smoke와 문서화 진입 승인을 요청한다.
