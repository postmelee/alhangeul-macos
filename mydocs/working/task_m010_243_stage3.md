# Task M010 #243 Stage 3 완료보고서

## 단계 목적

개별 문서 창 닫기 요청을 가로채 저장 여부 확인 sheet를 표시하고, 사용자의 선택과 저장 결과에 따라 창 닫기를 계속하거나 중단하도록 구현했다. 앱 전체 종료(`Command+Q`) 시 여러 dirty 문서를 순차 확인하는 흐름은 Stage 4 범위로 남겼다.

## 산출물

- `Sources/HostApp/Services/DocumentCloseConfirmationController.swift` (164 lines)
  - `NSWindowDelegate` 기반 close guard를 추가했다.
  - dirty 문서 창 닫기 요청에서 `저장`, `저장하지 않음`, `취소` 버튼을 가진 sheet를 표시한다.
  - 기존 window delegate의 `windowShouldClose`/`windowWillClose`와 기타 optional delegate message를 forwarding한다.
  - 저장 성공 또는 저장하지 않음 선택 시 programmatic close가 다시 prompt를 띄우지 않도록 `bypassNextClose`를 둔다.
- `Sources/HostApp/HostApp.swift` (482 lines)
  - `DocumentWindowLifecycle`이 resolved `NSWindow`와 `DocumentViewerStore`를 close confirmation controller에 연결하도록 변경했다.
  - SwiftUI 기본 `WindowGroup` 창과 `DocumentWindowPresenter` 수동 창 모두 같은 `DocumentWindowRootView` lifecycle을 지나므로 동일 close guard를 적용받는다.
  - 중복 empty window 자동 close는 prompt 없이 닫히도록 close controller의 bypass close를 사용한다.
- `Sources/HostApp/Views/RhwpStudioWebView.swift` (1349 lines)
  - `RhwpStudioDocumentSaveResult`(`saved`, `cancelled`, `failed`)를 추가했다.
  - 기존 저장 경로에 optional completion을 추가해 close guard가 저장 성공/취소/실패를 구분할 수 있게 했다.
  - 기존 menu/shortcut 저장 UX는 completion 없이 같은 경로를 사용하도록 유지했다.
  - `RhwpStudioNativeCommandDispatcher.saveDocument(in:completion:)`를 추가해 특정 window의 WebView 저장을 요청할 수 있게 했다.
- `Alhangeul.xcodeproj/project.pbxproj`
  - `xcodegen generate`로 신규 `DocumentCloseConfirmationController.swift` source 포함 항목을 반영했다.

## 본문 변경 정도 / 무손실 여부

- HostApp UI/AppKit 경계만 변경했다.
- `Sources/RhwpCoreBridge`는 변경하지 않았다.
- HWP export/write 로직은 복제하지 않고 기존 `RhwpStudioWebView` 저장 경로를 재사용했다.
- `DocumentWindowPresenter.windowWillClose(_:)` cleanup은 close controller가 previous delegate로 forwarding하므로 유지된다.

## 구현 메모

- close confirmation source of truth는 Stage 2에서 추가한 `DocumentViewerStore.hasUnsavedChanges`다.
- `저장` 선택 시 close controller가 `RhwpStudioNativeCommandDispatcher.saveDocument(in:completion:)`를 호출한다.
  - 저장 성공: store의 저장 완료 처리로 dirty state가 해제된 뒤 창을 닫는다.
  - 저장 panel 취소: 창을 유지한다.
  - 저장 실패: 창을 유지하고 error banner를 표시한다.
- `저장하지 않음` 선택 시 `store.clearUnsavedChanges()`를 호출한 뒤 창을 닫는다.
- `취소` 선택 시 창을 유지한다.
- 현재 Stage 3 close guard는 window close 요청만 처리한다. 앱 종료 중 dirty window 순차 확인과 `reply(toApplicationShouldTerminate:)`는 Stage 4에서 구현한다.

## 검증 결과

```bash
git diff --check -- Alhangeul.xcodeproj/project.pbxproj Sources/HostApp/HostApp.swift Sources/HostApp/Views/RhwpStudioWebView.swift Sources/HostApp/Stores/DocumentViewerStore.swift Sources/HostApp/Services mydocs/working/task_m010_243_stage3.md
```

- 결과: 통과. 출력 없음.

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask243Stage3 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

- 신규 source 파일이 기존 `Alhangeul.xcodeproj`에 포함되지 않아 최초 빌드에서 `DocumentCloseConfirmationController` scope 오류가 발생했다.
- 매뉴얼에 따라 `xcodegen generate`를 실행해 `project.yml` 기준으로 project를 재생성했다.
- 저장 handler completion이 non-escaping으로 추론되는 compile 오류를 수정했다.
- sandbox 실행에서는 SwiftPM/clang user cache 쓰기 제한이 있어 승인 경로로 같은 명령을 재실행했다.
- 최종 결과: `** BUILD SUCCEEDED ** [2.878 sec]`
- 참고: Xcode의 CoreSimulator version 경고가 출력되었지만 macOS HostApp build는 완료되었다.

```bash
rg -n "windowShouldClose|DocumentClose|Unsaved|저장하지 않음|저장되지 않은|save.*completion|bypass" Sources/HostApp
```

- 결과: close confirmation controller, HostApp lifecycle 연결, WebView save completion, dirty state 연결 지점을 확인했다.

## 수동 smoke

- foreground 앱 조작이 필요한 sheet 선택 흐름은 이번 단계에서 자동화하지 않았다.
- Debug app build 산출물은 생성되었고, Stage 4 전 또는 최종 검증에서 실제 앱으로 다음 항목을 확인해야 한다.
  - dirty 문서 창 닫기 시 저장 확인 sheet 표시
  - `취소` 선택 시 창 유지
  - `저장하지 않음` 선택 시 창 닫힘
  - `저장` 선택 후 저장 성공 시 창 닫힘
  - save panel 취소 또는 저장 실패 시 창 유지

## 잔여 위험

- interactive sheet 동작은 수동 smoke가 아직 필요하다.
- 앱 종료(`Command+Q`)는 아직 Stage 4 구현 전이므로 전체 종료 요청에서는 dirty 문서 순차 확인을 보장하지 않는다.
- close controller가 window delegate를 proxy하므로, 향후 다른 delegate method를 추가하는 코드가 생기면 forwarding 유지 여부를 재확인해야 한다.

## 다음 단계 영향

- Stage 4는 이번 단계의 `RhwpStudioNativeCommandDispatcher.saveDocument(in:completion:)`와 `DocumentCloseConfirmationController` 정책을 재사용해 앱 종료 시 dirty window 목록을 순차 처리한다.
- termination coordinator는 window close guard와 중복 prompt가 뜨지 않도록 bypass/진행 상태를 공유하거나 별도 termination path를 명확히 분리해야 한다.

## 승인 요청

Stage 4에서 앱 전체 종료 저장 확인 구현으로 넘어갈 수 있도록 검토와 다음 단계 진행 승인을 요청한다.
