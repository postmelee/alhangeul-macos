# Task M010 #243 Stage 2 완료보고서

## 단계 목적

WKWebView 안에서 발생한 문서 변경 후보를 HostApp으로 전달하고, `DocumentViewerStore`가 저장되지 않은 변경 여부를 소유하도록 구현했다. 이번 단계는 dirty state와 WebView bridge 연결만 다루며, 창 닫기/앱 종료 저장 확인 모달은 Stage 3 이후 범위로 남겼다.

## 산출물

- `Sources/HostApp/Stores/DocumentViewerStore.swift` (273 lines)
  - `hasUnsavedChanges` published state를 추가했다.
  - `markDocumentEdited()`와 `clearUnsavedChanges()`를 추가했다.
  - 새 문서 load, 현재 문서 clear, 저장 완료 시 dirty state를 false로 정리한다.
- `Sources/HostApp/Views/DocumentViewerView.swift` (229 lines)
  - `RhwpStudioWebView.onDocumentEdited`를 store의 `markDocumentEdited()`로 연결했다.
- `Sources/HostApp/Views/RhwpStudioWebView.swift` (1268 lines)
  - `onDocumentEdited` callback을 `NSViewRepresentable`와 coordinator에 추가했다.
  - injected script의 `document-edited` message를 받아 현재 문서가 있을 때만 callback을 호출한다.
- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` (736 lines)
  - `document-edited` native message 전송 함수를 추가했다.
  - keyboard editing, `beforeinput`/`input`/`change`, `cut`/`paste`, drop, mutating command 후보를 dirty signal로 연결했다.
  - native file/save/print/share/export, view/zoom, copy/find/goto 등 non-mutating command는 dirty marking에서 제외했다.

## 본문 변경 정도 / 무손실 여부

- 제품 코드는 HostApp 경계에만 변경했다.
- `Sources/RhwpCoreBridge`는 변경하지 않았다.
- bundled `rhwp-studio` minified asset은 직접 수정하지 않고 injected script만 보강했다.
- 기존 저장, 인쇄, 공유, PDF export command flow는 유지했다.

## 구현 메모

- dirty source of truth는 `DocumentViewerStore.hasUnsavedChanges`로 고정했다.
- 중복 dirty message 억제는 store에서 처리한다. 이미 dirty 상태이면 `markDocumentEdited()`가 no-op이므로, 저장 후 재편집 신호를 잃지 않는다.
- injected script는 `document-changed` 내부 event bus에 직접 의존하지 않는다. 해당 bus는 bundled asset closure 내부에 있어 public API로 안정적으로 접근하기 어렵기 때문이다.
- `document-edited` message는 현재 native store에 문서가 없는 경우 무시한다. 이로써 viewer 빈 화면이나 load 전 이벤트가 dirty state를 만들지 않는다.

## 검증 결과

```bash
git diff --check -- Sources/HostApp/Stores/DocumentViewerStore.swift Sources/HostApp/Views/DocumentViewerView.swift Sources/HostApp/Views/RhwpStudioWebView.swift Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift
```

- 결과: 통과. 출력 없음.

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask243Stage2 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

- 최초 sandbox 실행은 Swift Package dependency `Sparkle`을 GitHub에서 resolve하지 못해 실패했다.
- 네트워크 허용으로 같은 명령을 재실행했고, `Sparkle 2.9.1` resolve 후 HostApp 빌드가 성공했다.
- 최종 결과: `** BUILD SUCCEEDED ** [12.305 sec]`
- 참고: CoreSimulator version 경고가 출력되었지만 macOS HostApp 빌드는 완료되었다.

```bash
rg -n "hasUnsavedChanges|mark.*Unsaved|document-edited|onDocumentEdited|dirty|unsaved" Sources/HostApp
```

- 결과: `DocumentViewerStore`, `DocumentViewerView`, `RhwpStudioWebView`, `RhwpStudioHostBridgeScript`의 신규 dirty 연결 지점만 확인했다.

## 수동 smoke

- Stage 2 단독 변경에는 dirty state를 화면에 노출하는 UI가 없다.
- Debug app 실행을 통한 수동 smoke는 Stage 3에서 close confirmation sheet가 연결된 뒤 저장/저장하지 않음/취소 흐름과 함께 수행한다.

## 잔여 위험

- injected DOM/command hook 기반 dirty 감지는 보수적이므로 일부 false positive가 가능하다.
- bundled viewer 내부 command 중 DOM event로 드러나지 않는 변경이 있으면 false negative가 남을 수 있다.
- 현재 단계에는 save completion API와 close/termination guard가 없으므로 사용자에게 저장 확인 모달은 아직 표시되지 않는다.

## 다음 단계 영향

- Stage 3에서 `hasUnsavedChanges`를 window close guard 조건으로 사용한다.
- `clearUnsavedChanges()`는 Stage 3의 "저장하지 않음" 선택과 저장 성공 continuation에서 재사용한다.
- 저장 성공, 저장 취소, 저장 실패를 구분하는 completion API가 Stage 3의 핵심 진입점이다.

## 승인 요청

Stage 3에서 저장 completion API와 개별 창 닫기 저장 확인 모달 구현으로 넘어갈 수 있도록 검토와 다음 단계 진행 승인을 요청한다.
