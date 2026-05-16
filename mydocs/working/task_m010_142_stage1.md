# Task #142 Stage 1 완료 보고서

## 단계 목적

현재 HostApp WKWebView viewer의 저장 command 흐름, source document 소유 위치, shortcut label 표기 위치를 조사하고 Stage 2 구현 경계를 확정한다.

## 산출물

- `mydocs/plans/task_m010_142_impl.md`
  - 저장 command 분리, 즉시 저장, save-as fallback, shortcut label 보정 구현 계획 작성
- `mydocs/working/task_m010_142_stage1.md`
  - 현재 저장 command 흐름과 변경 대상 조사 기록
- `mydocs/orders/20260504.md`
  - #142 비고를 Stage 1 완료 보고서 승인 대기 상태로 갱신

이번 단계에서는 HostApp source와 bundled `rhwp-studio` resource를 변경하지 않았다.

## 조사 결과

### macOS command menu

`HostAppCommands`는 `.saveItem`을 대체하고 `저장` 버튼 하나만 등록한다.

- `저장`은 `RhwpStudioNativeCommandDispatcher.run("file:save")`를 호출한다.
- shortcut은 `.keyboardShortcut("s", modifiers: [.command])`다.
- 현재 `다른 이름으로 저장` command는 없다.

따라서 Stage 2에서는 같은 command group에 `저장`과 `다른 이름으로 저장...`을 함께 두고, 각각 `file:save`, `file:save-as`로 분리한다.

관련 위치:

- `Sources/HostApp/HostApp.swift:139`

### WKWebView injected bridge script

`RhwpStudioHostBridgeScript`의 `nativeCommands`는 현재 `file:open`, `file:save`, `file:print`, `file:share`, `file:export-pdf`만 포함한다.

`nativeCommandForShortcut(event)`는 다음 제약을 가진다.

- repeat, composing, alt, shift가 있으면 무시한다.
- `metaKey` 또는 `ctrlKey` 중 하나가 있으면 command modifier로 취급한다.
- `KeyS`는 항상 `file:save`를 반환한다.

이 구조에서는 `Command+Shift+S`를 처리할 수 없다. Stage 2에서는 `shiftKey`를 저장 command 판정 전에 무조건 배제하지 않고, `Command+S`와 `Command+Shift+S`만 분기해야 한다.

관련 위치:

- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift:13`
- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift:120`

### AppKit key equivalent fallback

`RhwpStudioNativeCommandWebView`는 `performKeyEquivalent(with:)`와 `keyDown(with:)`에서 `handleNativeCommandShortcut(_:)`를 먼저 호출한다.

`nativeCommand(for:)`는 다음 제약을 가진다.

- command 또는 control modifier가 있으면 처리한다.
- option 또는 shift가 있으면 무시한다.
- keyCode 1은 `file:save`로 매핑한다.

따라서 SwiftUI menu command가 잡지 못하는 상황에서도 현재 `Command+Shift+S`는 처리되지 않는다. Stage 2에서는 keyCode 1에서 shift 포함 여부를 확인해 `file:save-as`를 반환하도록 바꾼다.

관련 위치:

- `Sources/HostApp/Views/RhwpStudioWebView.swift:634`
- `Sources/HostApp/Views/RhwpStudioWebView.swift:643`

### 현재 저장 실행 경로

`file:save`는 `RhwpStudioWebView.Coordinator.handleHostCommand(_:)`와 `runNativeCommand(_:in:)` 양쪽에서 `requestSaveDocument(in:suggestedFilename:)`로 이어진다.

`requestSaveDocument`는 항상 다음 순서로 동작한다.

1. `DocumentSavePanel.chooseDestinationURL`로 save panel을 연다.
2. 사용자가 URL을 고르면 `pendingSaveDestinationURL`에 저장한다.
3. JS bridge에 `window.__alhangeulHostBridgeExportHwpDocument?.('save-document')`를 실행한다.
4. `saveDocument(_:)`가 export payload를 받아 `pendingSaveDestinationURL`에 쓴다.

즉, 현재 `file:save`는 이름과 달리 save-as 동작이다. Stage 2에서는 기존 흐름을 `requestSaveAsDocument`로 분리하고, `file:save`에는 source document 기반 즉시 저장 경로를 새로 둔다.

관련 위치:

- `Sources/HostApp/Views/RhwpStudioWebView.swift:273`
- `Sources/HostApp/Views/RhwpStudioWebView.swift:304`
- `Sources/HostApp/Views/RhwpStudioWebView.swift:495`

### source document ownership

현재 source document는 `DocumentViewerStore`가 소유한다.

- `sourceDocument`는 `@Published private(set)`이다.
- 문서를 열 때 `RecentDocumentItem.make(for:)`로 URL과 security-scoped bookmark를 저장한다.
- 최근 문서 목록과 `NSDocumentController` 기록도 `RecentDocumentStore.record(_:)`가 담당한다.

`RhwpStudioWebView`에는 현재 `document` payload만 전달되고 source document는 전달되지 않는다. 따라서 Stage 2에서 `RhwpStudioWebView` init 인자에 `sourceDocument`와 save-as 완료 callback을 추가하는 편이 가장 좁은 변경이다.

관련 위치:

- `Sources/HostApp/Stores/DocumentViewerStore.swift:5`
- `Sources/HostApp/Stores/DocumentViewerStore.swift:30`
- `Sources/HostApp/Stores/DocumentViewerStore.swift:97`
- `Sources/HostApp/Services/RecentDocumentStore.swift:20`
- `Sources/HostApp/Views/DocumentViewerView.swift:24`

### shortcut label 표기 위치

`Ctrl+` shortcut label은 bundled `rhwp-studio/index.html`에 하드코딩되어 있다.

확인된 주요 위치:

- `.md-shortcut`: 파일/편집/보기/입력/서식/쪽/표 메뉴
- `.tb-split-shortcut`: 찾기 split menu
- toolbar/style bar button `title`: 오려두기, 복사하기, 붙이기, 찾기, 굵게, 기울임, 밑줄

`Ctrl` 문자열이 들어간 command id/class도 존재한다.

- `data-cmd="view:ctrl-mark"`
- `class="icon-ctrl-mark"`

이 값들은 조판 부호/control mark 의미라 shortcut 표기 보정 대상이 아니다. Stage 2에서는 DOM text/title만 보정하고 attribute name/id/class/data-cmd는 그대로 둔다.

관련 위치:

- `Sources/HostApp/Resources/rhwp-studio/index.html:24`
- `Sources/HostApp/Resources/rhwp-studio/index.html:76`
- `Sources/HostApp/Resources/rhwp-studio/index.html:384`
- `Sources/HostApp/Resources/rhwp-studio/index.html:501`

## 확정안

Stage 2 구현은 다음 방향으로 진행한다.

1. `file:save-as`를 새 native command로 추가한다.
2. `Command+S`는 `file:save`, `Command+Shift+S`는 `file:save-as`로 routing한다.
3. `file:save`는 source document URL이 있을 때 export payload를 받아 원본 URL에 즉시 쓴다.
4. source document가 없거나 원본 URL 접근에 실패하면 `file:save-as`로 fallback한다.
5. `file:save-as`는 기존 save panel 흐름을 유지하되, 저장 완료 후 store의 source document를 새 URL로 갱신한다.
6. shortcut label은 injected bridge script에서 `.md-shortcut`, `.tb-split-shortcut`, shortcut 관련 `title` attribute만 macOS 표기로 바꾼다.

## 검증 결과

```bash
git status --short --branch
```

결과: Stage 1 조사 시작 시 `local/task142` 브랜치였고 작업트리는 clean이었다.

```bash
rg -n "file:save|file:open|file:print|file:export-pdf|keyboardShortcut|nativeCommandForShortcut|requestSaveDocument|pendingSaveDestinationURL|sourceDocument|RhwpStudioWebView\\(" Sources/HostApp -g '!Resources/rhwp-studio/**'
```

결과: 저장 command 연결점은 `HostApp.swift`, `RhwpStudioHostBridgeScript.swift`, `RhwpStudioWebView.swift`, `DocumentViewerStore.swift`, `DocumentViewerView.swift`로 확인했다.

```bash
rg -n "Ctrl\\+|title=\\\".*Ctrl|md-shortcut|tb-split-shortcut" Sources/HostApp/Resources/rhwp-studio/index.html
```

결과: shortcut label은 `index.html`의 visible text/title에 집중되어 있고, `view:ctrl-mark` 같은 command id는 표시 문자열과 분리해 다뤄야 함을 확인했다.

## Stage 2 변경 대상 확정

- `Sources/HostApp/HostApp.swift`
- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
- `Sources/HostApp/Views/RhwpStudioWebView.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift`
- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `mydocs/working/task_m010_142_stage2.md`

Stage 2 완료 후 Debug build와 shortcut routing smoke를 진행한다.
