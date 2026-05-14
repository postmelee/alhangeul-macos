# Task M010 #243 Stage 1 완료보고서

## 단계 목표

종료/창 닫기 저장 확인 기능을 구현하기 전에 현재 HostApp의 창 lifecycle, 앱 종료 hook, 저장 bridge, dirty signal 후보를 조사했다. 이 단계에서는 제품 코드를 변경하지 않고, Stage 2 이후 구현 경계를 확정하는 데 필요한 근거만 정리했다.

## 조사 결과

### 창 lifecycle

- SwiftUI 기본 창은 `WindowGroup` 안에서 `DocumentWindowRootView`가 생성한다.
- `DocumentWindowRootView`는 window 접근을 `WindowAccessor`로 얻고, 현재는 `DocumentWindowLifecycle`에 window reference를 전달해 중복 empty window를 자동 닫는 데만 사용한다.
- 기본 SwiftUI 창에는 현재 `NSWindowDelegate` close guard가 없다.
- `DocumentWindowLifecycle.closeIfNeeded(_:)`는 `window?.close()`를 직접 호출하므로, Stage 3 close guard 도입 시 자동 empty window close가 저장 확인 모달을 띄우지 않도록 bypass 조건이 필요하다.
- 수동 문서 창은 `DocumentWindowPresenter.openDocument(_:)`가 `DocumentViewerStore`, `DocumentWindowRootView`, `NSHostingController`, `NSWindowController`, toolbar controller를 함께 만든다.
- 수동 문서 창의 `window.delegate`는 현재 `DocumentWindowPresenter`이고, `windowWillClose(_:)`에서 controller와 toolbar controller 정리만 수행한다.
- 수동 창도 `windowShouldClose(_:)`는 구현되어 있지 않다.

### 앱 종료 hook

- `AppDelegate`에는 현재 `applicationShouldTerminate(_:)`가 없다.
- 종료 시점에는 `applicationWillTerminate(_:)`에서 notification observer만 제거한다.
- 따라서 앱 종료 저장 확인은 `applicationShouldTerminate(_:)`를 새로 추가해 dirty 문서 존재 여부를 보고, 필요 시 `.terminateLater`와 `reply(toApplicationShouldTerminate:)`를 사용하는 구조가 필요하다.
- 여러 문서 창을 처리하려면 window/store 쌍을 수집할 수 있는 registry가 필요하다. 현재 `DocumentOpenRouter`는 store registry를 갖지만 window reference와 close/termination state를 갖지 않으므로 그대로 쓰기에는 부족하다.

### 저장 bridge

- 저장 command는 두 경로에서 들어온다.
  - macOS 메뉴/단축키: `RhwpStudioNativeCommandDispatcher.run("file:save")`
  - injected script native command: `type: "command", command: "file:save"`
- `RhwpStudioWebView.Coordinator.requestSaveDocument(in:)`는 원본 HWP 파일이 있으면 in-place 저장을 시도하고, 원본이 없거나 HWPX이면 `requestSaveAsDocument(in:)`로 넘어간다.
- `requestSaveAsDocument(in:)`는 `DocumentSavePanel.chooseDestinationURL(...)`을 async로 띄운 뒤 destination이 있을 때만 export bridge를 실행한다.
- 실제 저장은 `save-document` message를 받은 `saveDocument(_:)`에서 처리한다.
- 저장 성공 시 `recordSavedDocument(at:)`가 호출되고, SwiftUI 쪽 `onDocumentSaved`를 통해 `DocumentViewerStore.recordSavedDocument(at:)`가 실행된다.
- 저장 취소는 현재 명시적인 result로 전달되지 않는다. save panel 취소 시 `requestSaveAsDocument(in:)`가 조용히 return하고, `savePayloadWithPanel(_:)`도 URL이 nil이면 아무 것도 하지 않는다.
- 저장 실패도 현재는 `onError(...)` banner로만 전달된다.
- 따라서 close/terminate 흐름에서 저장을 기다리려면 `saved(URL)`, `cancelled`, `failed(String/Error)`를 구분하는 completion/result API가 필요하다.

### dirty state와 변경 신호 후보

- `DocumentViewerStore`에는 현재 `hasDocument`, `canRunWebViewCommands` 등 문서/명령 가능 상태는 있지만 저장되지 않은 변경 상태는 없다.
- 저장 성공 시 `recordSavedDocument(at:)`가 source document와 filename만 갱신하며 dirty state를 해제할 대상도 없다.
- bundled `rhwp-studio` minified asset 내부에는 `document-changed` event bus 사용이 다수 존재한다.
- 하지만 해당 event bus 객체는 asset closure 내부 로컬 변수이며, 현재 injected `RhwpStudioHostBridgeScript`에서 직접 subscribe할 공개 window API가 보이지 않는다.
- 따라서 Stage 2 dirty 감지는 asset 직접 수정 없이 injected script에서 DOM/input/command 후보를 관찰하는 방식이 현실적이다.
- 후보:
  - `beforeinput`, `input`, `change`, `paste`, `cut`, editing keydown
  - drag/drop으로 새 문서 bytes를 처리하는 경로는 이번 범위에서 문서 교체 전 확인 제외
  - toolbar/menu `.md-item[data-cmd]`, `.tb-btn[data-cmd]`, `.tb-split-item[data-cmd]` 중 mutating command
- 제외해야 할 command:
  - Host native command set의 `file:open`, `file:save`, `file:save-as`, `file:print`, `file:share`, `file:export-pdf`
  - zoom/view-only 계열 command
- false positive는 저장 확인 모달이 불필요하게 뜨는 문제로 제한되지만, false negative는 변경사항 유실로 이어질 수 있으므로 Stage 2에서는 보수적 dirty marking이 맞다.

## 구현 경계 확정

### 작은 AppKit bridge

SwiftUI view가 source of truth인 store를 계속 소유하고, AppKit 경계는 window close/termination 제어에만 둔다.

- 기본 SwiftUI 창: `WindowAccessor`가 얻은 `NSWindow`에 store와 close guard를 연결한다.
- 수동 문서 창: `DocumentWindowPresenter`가 store/window 생성 시 같은 close guard를 등록한다.
- close guard는 `windowShouldClose(_:)` 또는 delegate/proxy 구조를 사용하되, 기존 `DocumentWindowPresenter.windowWillClose(_:)` 정리 책임을 보존해야 한다.
- AppDelegate termination은 close guard registry에서 dirty window/store 목록을 받아 순차 처리한다.

### Store와 bridge 책임

- `DocumentViewerStore`가 `hasUnsavedChanges`를 소유한다.
- `RhwpStudioHostBridgeScript`는 `document-edited` message만 native로 보낸다.
- `RhwpStudioWebView`는 `onDocumentEdited` callback을 받아 store에 전달한다.
- 저장 성공, 새 문서 load, 저장하지 않고 닫기 승인 시 store가 dirty state를 false로 정리한다.

### 저장 completion

기존 저장 command UX는 유지하되, close/termination 전용으로 completion을 받을 수 있는 narrow API를 추가한다.

- 저장 성공: 저장 URL 반환 후 dirty 해제와 close/termination continuation 진행
- 저장 취소: 창/앱 종료 중단
- 저장 실패: error banner 표시 후 창/앱 종료 중단
- 이미 저장 진행 중이거나 save panel 표시 중이면 중복 close/terminate 요청을 무시하거나 기존 저장 흐름이 끝날 때까지 대기하는 방식을 Stage 3에서 확정한다.

## 리스크와 후속 확인

- `document-changed` event bus를 injected script가 직접 볼 수 없으므로 dirty 감지는 DOM/command hook 기반으로 시작한다.
- DOM hook 기반 dirty 감지는 일부 toolbar command의 mutating 여부를 완벽히 알기 어렵다. Stage 2에서 command allow/block list를 소스 검색으로 보강해야 한다.
- 기존 `DocumentWindowPresenter`가 `NSWindowDelegate`를 독점하므로 close guard를 추가할 때 delegate chain 또는 proxy 설계를 잘못하면 controller cleanup이 누락될 수 있다.
- `DocumentWindowLifecycle.closeIfNeeded(_:)`는 중복 empty window를 programmatic close 하므로, dirty 문서가 아닌 경우에도 close confirmation이 끼어들지 않아야 한다.
- 앱 종료 중 sheet가 여러 창에 순차 표시될 때 `reply(toApplicationShouldTerminate:)`가 정확히 한 번만 호출되도록 coordinator 상태가 필요하다.

## 검증

```bash
git status --short --branch
rg -n 'applicationShouldTerminate|applicationWillTerminate|windowWillClose|WindowAccessor|DocumentWindowLifecycle|DocumentWindowPresenter|requestSaveDocument|saveDocument\(|recordSavedDocument|document-changed|nativeCommands' Sources/HostApp/HostApp.swift Sources/HostApp/Views/RhwpStudioWebView.swift Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift
git diff --check -- mydocs/working/task_m010_243_stage1.md
```

## 변경 파일

- `mydocs/working/task_m010_243_stage1.md`

제품 소스는 변경하지 않았다.

## 다음 단계

Stage 2에서 `DocumentViewerStore` dirty state, `document-edited` native message, `RhwpStudioWebView` callback 연결을 구현한다.
