# Issue #144 Stage 1 보고서

## 단계 목적

WKWebView 내부 drag/drop 로드 후 titlebar toolbar의 `공유`, `Finder에서 보기`, `PDF로 내보내기`가 비활성으로 남는 원인을 코드 경로 기준으로 확정한다. Stage 2에서 구현할 bridge/state 보정 범위를 정하고, 원본 파일 URL이 없는 Web `File` 기반 로드에서 `Finder에서 보기`를 활성화할 수 있는지 판단한다.

## 산출물

- 조사 보고서: `mydocs/working/task_m010_144_stage1.md`
- 앱 소스 변경 없음
- 조사 대상:
  - `Sources/HostApp/Stores/DocumentViewerStore.swift`
  - `Sources/HostApp/HostApp.swift`
  - `Sources/HostApp/Views/ContentView.swift`
  - `Sources/HostApp/Views/DocumentViewerView.swift`
  - `Sources/HostApp/Views/RhwpStudioWebView.swift`
  - `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
  - `Sources/HostApp/Resources/rhwp-studio/assets/index-CCXookfl.js`

## 본문 변경 정도 / 본문 무손실 여부

- 코드 본문 변경: 없음
- 리소스 본문 변경: 없음
- 문서 추가만 수행하므로 기존 동작 손실 없음

## 조사 결과

### 확인된 버그 상태

릴리스 앱에서 HWP 파일을 viewer 영역에 drag/drop하면 WebView 내부 viewer는 문서를 정상 렌더링한다. 그러나 native toolbar validation 기준인 Swift store에는 문서가 기록되지 않아 `공유`, `Finder에서 보기`, `PDF로 내보내기`가 비활성으로 남는 문제가 실제로 재현되었다.

### native 상태 기준

`DocumentViewerStore`는 `rhwpStudioDocument`와 `sourceDocument`를 분리해 보관한다.

- `hasDocument`는 `rhwpStudioDocument != nil`이다. (`Sources/HostApp/Stores/DocumentViewerStore.swift:15`)
- `canRevealInFinder`는 `sourceDocument != nil`이다. (`Sources/HostApp/Stores/DocumentViewerStore.swift:19`)
- native open path인 `loadDocument(from:)`는 파일 URL로 `RecentDocumentItem`을 만들고 data를 읽은 뒤 `loadDocument(data:filename:sourceDocument:)`로 들어간다. 이 private load path가 `filename`, `sourceDocument`, `documentRevision`, `rhwpStudioDocument`를 모두 갱신한다. (`Sources/HostApp/Stores/DocumentViewerStore.swift:30`, `Sources/HostApp/Stores/DocumentViewerStore.swift:104`)
- 최근 문서 기록은 `sourceDocument`가 있을 때만 수행된다. (`Sources/HostApp/Stores/DocumentViewerStore.swift:124`)

따라서 Swift store에 `rhwpStudioDocument`가 생기면 `공유`와 `PDF로 내보내기`는 활성화할 수 있고, `sourceDocument`가 있을 때만 `Finder에서 보기`를 활성화할 수 있다.

### toolbar validation 기준

titlebar AppKit toolbar와 SwiftUI toolbar는 같은 상태 기준을 쓴다.

- AppKit toolbar: `공유`와 `PDF로 내보내기`는 `store.hasDocument && !store.isWebViewLoading`, `Finder에서 보기`는 `store.canRevealInFinder`를 반환한다. (`Sources/HostApp/HostApp.swift:367`)
- SwiftUI toolbar: 동일하게 `store.hasDocument`, `store.isWebViewLoading`, `store.canRevealInFinder`로 disabled 상태를 결정한다. (`Sources/HostApp/Views/ContentView.swift:19`)

`DocumentWindowToolbarController`는 현재 store 변경을 구독해 `NSToolbar.validateVisibleItems()`를 직접 호출하지 않는다. WebView bridge에서 비동기로 store가 갱신되는 경우 즉시 validation refresh가 필요할 수 있다. (`Sources/HostApp/HostApp.swift:288`)

### WebView bridge 경계

`DocumentViewerView`는 `RhwpStudioWebView`에 `document: store.rhwpStudioDocument`와 `sourceDocument: store.sourceDocument`를 전달한다. callback은 load state, error, open document, saved document만 있다. WebView 내부에서 새 문서가 로드되었다는 callback은 없다. (`Sources/HostApp/Views/DocumentViewerView.swift:24`)

`RhwpStudioWebView.Coordinator`의 message handler는 현재 다음 message type만 처리한다.

- `command`
- `save-document`
- `share-document`
- `print-document`
- `export-pdf-document`
- `error`

drag/drop 또는 document-loaded 계열 message type은 없다. (`Sources/HostApp/Views/RhwpStudioWebView.swift:261`)

`RhwpStudioHostBridgeScript`는 native command와 export bridge를 주입하지만 drag/drop event나 viewer document loaded event를 native로 통지하지 않는다. (`Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift:13`, `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift:365`)

### bundled viewer drag/drop 경로

bundled `rhwp-studio` JS의 `Wa()`는 file input과 `scroll-container` drop handler를 등록한다. drop handler는 `event.dataTransfer?.files[0]`을 읽어 확장자를 확인한 뒤 `Ya(file)`를 호출한다. `Ya(file)`는 `file.arrayBuffer()`를 `Uint8Array`로 변환하고 `Xa(bytes, file.name, null, startTime)`로 전달한다. `Xa`는 `X.loadDocument(bytes, filename)`를 호출해 Web/WASM 내부 상태만 갱신한다. (`Sources/HostApp/Resources/rhwp-studio/assets/index-CCXookfl.js:1`)

이 경로의 세 번째 인자는 `null`이므로 viewer 내부에도 native에서 신뢰 가능한 filesystem URL이나 file handle이 없다. 또한 `window.webkit.messageHandlers.alhangeulHost.postMessage`를 호출하지 않으므로 Swift store가 갱신될 기회가 없다.

### 원본 URL 판단

브라우저/WebView의 `File` 객체는 파일명과 bytes를 제공하지만, sandbox와 privacy 정책상 일반적으로 원본 filesystem URL을 신뢰 가능한 형태로 제공하지 않는다. 이번 drag/drop 경로가 JS `DataTransfer.files`만 사용하는 이상 `Finder에서 보기`를 활성화하면 잘못된 URL을 만들거나 없는 원본을 있다고 표시할 위험이 있다.

따라서 Stage 2 기본 정책은 다음과 같이 확정한다.

- drag/drop으로 받은 bytes와 filename을 Swift store에 반영해 `hasDocument == true`로 만든다.
- source URL을 확보하지 못한 JS-only drag/drop에서는 `sourceDocument == nil`을 유지한다.
- 그 결과 `공유`와 `PDF로 내보내기`는 활성화하고, `Finder에서 보기`는 비활성으로 유지한다.
- Finder reveal까지 요구하려면 Web bridge가 아니라 AppKit drag destination 경로에서 pasteboard file URL을 잡는 별도 설계가 필요하다.

## 검증 결과

실행 명령:

```bash
git status --short --branch
```

결과:

```text
## local/task144
```

실행 명령:

```bash
git diff --check
```

결과: 통과. 출력 없음.

Stage 1은 조사 및 문서화 단계라 `xcodebuild`는 실행하지 않았다. Stage 2 이후 앱 소스 변경이 들어가면 구현 계획서의 build/smoke 검증 항목을 적용한다.

## 잔여 위험

- injected user script에서 drop을 가로채는 방식은 bundled viewer의 기존 drop handler와 중복 로드를 만들 수 있다. Stage 2에서는 한 번만 native state를 갱신하도록 capture phase, `stopImmediatePropagation()`, 또는 document-loaded 통지 방식 중 하나를 코드로 확정해야 한다.
- JS-only drag/drop에서는 원본 URL을 확보하지 않으므로 `Finder에서 보기` 비활성 유지가 맞다. 사용자가 drag/drop 후 Finder reveal까지 기대한다면 별도 AppKit drop handling 단계가 필요하다.
- AppKit titlebar toolbar는 store 변경 시 즉시 재검증되지 않을 수 있다. Stage 2에서 Combine 구독 또는 window toolbar refresh를 추가 검토한다.

## 다음 단계 영향

Stage 2는 다음 변경을 중심으로 진행한다.

- HostApp injected bridge script에 drag/drop load bridge 추가
- `RhwpStudioWebView.Coordinator`에 새 message type과 callback 추가
- `DocumentViewerStore`에 source-less document load API 추가
- AppKit toolbar validation refresh 보정

이 변경은 HostApp 영역에 한정하고, `Sources/RhwpCoreBridge`, Quick Look, Thumbnail extension은 변경하지 않는다.

## 승인 요청

Stage 1 조사를 완료했다. Stage 2에서 WebView drag/drop native bridge와 source-less store 갱신 구현으로 진입하려면 작업지시자 승인이 필요하다.
