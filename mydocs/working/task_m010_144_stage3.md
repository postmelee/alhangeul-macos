# Issue #144 Stage 3 보고서

## 단계 목적

Stage 2에서 추가한 `dropped-document` bridge message를 Swift `DocumentViewerStore` 상태에 연결하고, titlebar AppKit toolbar가 store 변경 후 즉시 validation을 다시 수행하도록 보정한다. 원본 URL이 없는 Web `File` 기반 drag/drop에서는 `Finder에서 보기`를 활성화하지 않는 정책을 유지한다.

## 산출물

- `Sources/HostApp/Stores/DocumentViewerStore.swift`
  - 총 167줄
  - source-less dropped document load API 추가
- `Sources/HostApp/Views/DocumentViewerView.swift`
  - 총 116줄
  - `onDroppedDocument` callback을 store에 연결
- `Sources/HostApp/HostApp.swift`
  - 총 463줄
  - AppKit toolbar validation refresh용 Combine 구독 추가
- `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift`
  - 총 482줄
  - 지원 문서 drop은 native-first load가 되도록 기존 WebView drop handler 전파 차단
- `mydocs/working/task_m010_144_stage3.md`
  - Stage 3 완료 보고서

## 본문 변경 정도 / 본문 무손실 여부

- 변경 규모: 4 files changed, 48 insertions(+)
- `Sources/RhwpCoreBridge`, Quick Look, Thumbnail extension source 변경 없음
- bundled `rhwp-studio` generated asset 변경 없음
- 최근 문서 기록과 `Finder에서 보기` 활성 조건은 원본 URL이 있는 기존 native open/recent 경로에만 유지했다.

## 구현 내용

### source-less dropped document state

`DocumentViewerStore.loadDroppedDocument(data:filename:)`를 추가했다. 이 API는 dropped bytes를 기존 private `loadDocument(data:filename:sourceDocument:)`로 전달하되 `sourceDocument: nil`을 사용한다.

결과 상태:

- `rhwpStudioDocument != nil`이 되어 `hasDocument == true`
- `sourceDocument == nil`이 되어 `canRevealInFinder == false`
- 최근 문서 기록은 수행하지 않음
- filename은 path component를 제거한 안전한 표시 이름으로 정규화

### WebView callback 연결

`DocumentViewerView`에서 `RhwpStudioWebView.onDroppedDocument`를 받아 main actor에서 `store.loadDroppedDocument(data:filename:)`를 호출하도록 연결했다. 이로써 WKWebView 내부 drop이 Swift store 상태 변경으로 이어진다.

### native-first drop handling

지원 확장자 drop의 경우 injected bridge script가 capture phase에서 `preventDefault()`, `stopPropagation()`, `stopImmediatePropagation()`을 호출하도록 보정했다. Stage 2 상태에서는 bundled viewer와 native bridge가 같은 drop을 각각 읽을 수 있었으나, Stage 3에서는 Swift store가 문서 로드의 source of truth가 되도록 기존 viewer drop handler 전파를 막는다.

drop 중 추가된 `drag-over` class는 native bridge에서 직접 제거한다.

### toolbar validation refresh

`DocumentWindowToolbarController`에 `store.objectWillChange` 구독을 추가했다. store 상태 변경이 들어오면 main queue 다음 tick에서 `window.toolbar?.validateVisibleItems()`를 호출한다.

이 보정으로 `hasDocument`와 `isWebViewLoading` 변화가 titlebar toolbar의 `공유`, `PDF로 내보내기`, `Finder에서 보기` validation에 즉시 반영된다.

## 검증 결과

실행 명령:

```bash
git diff --check
```

결과: 통과. 출력 없음.

실행 명령:

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과:

```text
** BUILD SUCCEEDED ** [2.574 sec]
```

빌드 중 CoreSimulatorService와 `~/Library/Logs/CoreSimulator` 접근 경고가 출력되었다. macOS HostApp build는 성공했다.

구현 중 다음 build 오류를 확인하고 수정했다.

- `DocumentViewerStore.loadDroppedDocument(data:filename:)`의 `filename` 파라미터가 property를 shadowing해 `self.filename`으로 명시 수정
- `DocumentWindowToolbarController`의 Combine 구독이 `NSObject` `super.init()` 전에 `self`를 캡처해 초기화 순서 수정

## 잔여 위험

- Stage 3는 build 검증까지 완료했다. 실제 사용자가 보는 toolbar 활성 상태는 Stage 4에서 앱 실행 후 HWP/HWPX drag/drop smoke로 확인해야 한다.
- JS `File` 기반 drop에는 원본 filesystem URL이 없으므로 `Finder에서 보기`는 의도적으로 비활성 상태로 남는다. Finder reveal까지 활성화하려면 AppKit dragging destination 기반 URL 확보가 별도 후속 설계로 필요하다.
- large file drop 시 JS에서 base64로 한 번 인코딩한 뒤 Swift store가 다시 document route로 WebView에 전달하므로 메모리 사용량은 파일 크기에 비례한다. v0.1 smoke 범위에서는 기존 viewer file load와 같은 사용자 동작을 보정하는 수준으로 유지한다.

## 다음 단계 영향

Stage 4에서 다음 수동 smoke를 수행한다.

- Debug 또는 release app 실행
- 빈 viewer에 HWP 파일 drag/drop
- 문서 표시 후 `공유`와 `PDF로 내보내기` toolbar item이 활성화되는지 확인
- JS-only drag/drop에서 `Finder에서 보기`가 비활성으로 남는지 확인
- native open panel 또는 Finder open 경로에서 세 toolbar item과 최근 문서 동작이 유지되는지 확인

## 승인 요청

Stage 3 store 상태 갱신 및 toolbar validation 보정을 완료했다. Stage 4의 앱 실행 및 수동 smoke 검증으로 진입하려면 작업지시자 승인이 필요하다.
