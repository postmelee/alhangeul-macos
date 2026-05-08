# Issue #142 구현 계획서

## 구현 요약

HostApp WKWebView viewer의 저장 command를 macOS 관례에 맞게 `저장`과 `다른 이름으로 저장`으로 분리한다. `Command+S`는 가능한 경우 원본 문서 URL에 즉시 쓰고, `Command+Shift+S`는 기존 save panel 기반 저장을 실행한다. WKWebView 내부 shortcut label은 HostApp 주입 script에서 macOS 표기로 보정한다.

## 구현 단계

1. source document 전달 경로 확장
   - `DocumentViewerView`에서 `store.sourceDocument`를 `RhwpStudioWebView`에 전달한다.
   - `RhwpStudioWebView.Coordinator`가 `currentSourceDocument`를 보관하도록 한다.
   - save panel 저장 성공 후 `DocumentViewerStore`가 source document와 filename/recent documents를 갱신할 수 있는 public method를 추가한다.

2. native command 분리
   - `file:save`는 즉시 저장 command로 유지한다.
   - `file:save-as`를 native command set에 추가한다.
   - SwiftUI command menu에 `저장`(`Command+S`)과 `다른 이름으로 저장...`(`Command+Shift+S`)을 등록한다.
   - WKWebView injected JS와 AppKit fallback key handler에서 `Command+S`와 `Command+Shift+S`를 구분한다.

3. 즉시 저장 구현
   - `file:save`는 source document가 있으면 `exportHwp` payload를 받아 원본 URL에 `DocumentSavePanel.write`로 저장한다.
   - security-scoped bookmark resolving과 `startAccessingSecurityScopedResource()`를 저장 시점에 다시 수행한다.
   - source document가 없거나 원본 write 준비가 실패하면 `file:save-as` 흐름으로 fallback한다.
   - export 실패 시 pending destination 상태를 정리하고 error banner에 표시한다.

4. 다른 이름으로 저장 구현
   - 기존 `requestSaveDocument`를 `requestSaveAsDocument` 성격으로 정리한다.
   - save panel에서 선택한 URL에 저장 완료 후 `onDocumentSavedAs` callback으로 store의 source document를 갱신한다.
   - 이후 `Command+S`가 새 URL을 대상으로 즉시 저장되도록 한다.

5. shortcut label 보정
   - `RhwpStudioHostBridgeScript`에 `rewriteShortcutLabelsForMac()`를 추가한다.
   - `.md-shortcut`, `.tb-split-shortcut`, `[title*="Ctrl+"]`, `[title*="Alt+"]`에 한정해 표시 문자열을 바꾼다.
   - `Ctrl+`은 `Command+`, `Alt+`는 `Option+`로 보정한다.
   - `data-cmd`, class name, id에 들어 있는 `ctrl`은 변경하지 않는다.
   - DOM 변경 이후에도 유지되도록 기존 `MutationObserver`에서 native command enable과 shortcut label 보정을 함께 수행한다.

## 검증 항목

- Debug HostApp build 성공
- `Command+S`와 `Command+Shift+S`가 각각 다른 native command로 routing되는 코드 확인
- 원본 source document가 있는 경우 즉시 저장 경로가 save panel을 열지 않는지 수동 확인
- source document가 없는 경우 즉시 저장 요청이 save panel로 fallback되는지 수동 확인
- save panel 저장 후 source document 갱신 코드가 이후 즉시 저장 대상으로 쓰이는지 확인
- WKWebView 내부 메뉴/tooltip에서 `Ctrl+` 표기가 `Command+`로 보이는지 수동 확인

## 구현상 주의

- `Sources/RhwpCoreBridge`에는 AppKit/WebKit 의존을 추가하지 않는다.
- bundled `rhwp-studio/index.html`은 직접 대량 수정하지 않고 HostApp 주입 script에서 macOS 표기를 보정한다.
- `Command+Shift+S`는 WebView 내부의 disabled `table:block-sum` 표시와 충돌할 수 있으므로 HostApp native command가 capture phase에서 먼저 처리하게 한다.
- 저장 실패 시 원본 파일을 손상시키지 않도록 export payload 생성 후 write를 수행한다.
- dirty-state가 없으므로 저장 여부 판단은 하지 않고 command 실행 시 항상 export/write한다.
