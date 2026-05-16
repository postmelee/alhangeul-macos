# Task #153 Stage 1 보고서

## 단계 목적

Finder drag/drop에서 원본 file URL을 확보할 수 있는 native 진입점을 조사하고, Task #144의 source-less JavaScript drop bridge와 충돌하지 않는 구현 방향을 확정한다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/plans/task_m010_153_impl.md` | native URL 우선, JS source-less fallback 유지, duplicate drop 억제 중심의 구현계획서 작성 |
| `mydocs/working/task_m010_153_stage1.md` | AppKit drag/drop 진입점, store 연결 경계, 중복 drop 위험 조사 결과 정리 |
| `mydocs/orders/20260506.md` | Task #153 진행 상태를 Stage 1 보고 승인 대기로 갱신 |

## 조사 범위

| 대상 | 확인 내용 |
|------|----------|
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | `NSViewRepresentable`, `Coordinator`, `RhwpStudioNativeCommandWebView`, `dropped-document` message 처리 구조 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | WebView callback과 `DocumentViewerStore` 연결 방식 |
| `Sources/HostApp/Stores/DocumentViewerStore.swift` | URL 기반 로드, source-less drop 로드, `canRevealInFinder` 조건 |
| `Sources/HostApp/Services/RhwpStudioHostBridgeScript.swift` | capture-phase `drop` listener와 JS fallback payload 생성 방식 |
| AppKit interop reference | file URL drag/drop은 SwiftUI modifier보다 AppKit pasteboard 경계가 적합한지 확인 |

## 조사 결과

### 1. 가장 작은 AppKit 경계

현재 HostApp은 `RhwpStudioWebView`에서 `WKWebView`를 직접 만들고, 실제 인스턴스는 `RhwpStudioNativeCommandWebView` subclass다. 이 subclass는 이미 AppKit/WebKit 전용 파일인 `Sources/HostApp/Views/RhwpStudioWebView.swift` 안에 있고, command shortcut 처리를 위해 native callback 경계를 보유한다.

따라서 전체 SwiftUI view를 AppKit으로 옮기거나 별도 window-level handler를 만들기보다, 우선 `RhwpStudioNativeCommandWebView`에 drag destination 처리를 좁게 추가하는 것이 가장 작은 변경이다. SwiftUI/store에는 `URL` callback만 노출하고 `NSDraggingInfo`, `NSPasteboard` 같은 AppKit 타입은 subclass 내부에 둔다.

### 2. 원본 URL 연결 지점

`DocumentViewerStore.loadDocument(from:)`는 다음 동작을 이미 수행한다.

- security-scoped resource 접근 시작/종료
- `RecentDocumentItem.make(for:)`로 source document 생성
- 파일 data 읽기
- `loadDocument(data:filename:sourceDocument:)`를 통해 `rhwpStudioDocument`와 `sourceDocument` 동시 갱신
- source가 있으면 최근 문서 기록 갱신

`canRevealInFinder`는 `sourceDocument != nil`만 본다. 그러므로 native file URL을 확보한 drag/drop은 새 reveal 상태를 만들 필요 없이 `loadDocument(from:)`로 보내는 것이 맞다.

### 3. JS source-less fallback과 중복 위험

Task #144에서 추가된 injected script는 document capture phase `drop` listener에서 지원 문서를 감지하면 다음을 수행한다.

- `event.preventDefault()`
- `event.stopPropagation()`
- `event.stopImmediatePropagation()`
- `postDroppedDocument(file)`로 bytes/base64 payload 전송

native AppKit drop handler가 먼저 성공 처리하고 WebKit/DOM drop으로 넘기지 않으면 JS fallback은 실행되지 않는 것이 기대 동작이다. 다만 WKWebView 내부 구현상 native override와 DOM drop dispatch의 순서는 실제 smoke로 확인해야 한다. 구현 단계에서는 다음 방어가 필요하다.

- native file URL drop 성공 시 `performDragOperation`에서 `super`를 호출하지 않고 성공을 반환한다.
- 그래도 같은 파일명/짧은 시간 범위의 `dropped-document` message가 들어오면 source URL이 있는 현재 문서를 source-less payload가 덮어쓰지 않도록 guard한다.

### 4. pasteboard URL 추출 후보

Finder drag pasteboard에서는 `NSURL` 객체 읽기를 우선 후보로 둔다.

```swift
let urls = pasteboard.readObjects(
    forClasses: [NSURL.self],
    options: [.urlReadingFileURLsOnly: true]
) as? [URL]
```

선택 기준은 다음이 적절하다.

- `url.isFileURL == true`
- path extension이 `hwp` 또는 `hwpx`
- 여러 파일이면 첫 번째 지원 문서만 처리
- 지원 문서 URL이 없으면 기존 WebKit/JS 흐름으로 넘김

이 방식은 AppKit pasteboard 타입을 HostApp WebView subclass 내부에 가두고, SwiftUI/store 경계에는 `URL`만 전달한다.

## 결정 사항

| 항목 | 결정 |
|------|------|
| native 진입점 | `RhwpStudioNativeCommandWebView` 우선 |
| SwiftUI 경계 | `RhwpStudioWebView` callback으로 `URL`만 전달 |
| store 경계 | `DocumentViewerStore.loadDocument(from:)` 재사용 |
| reveal 정책 | `sourceDocument != nil` 유지 |
| source-less fallback | Task #144의 `loadDroppedDocument(data:filename:)` 유지 |
| 중복 억제 | native URL drop 직후 같은 파일 source-less payload guard 필요 |
| project 설정 | Stage 2에서 새 파일 없이 기존 파일 수정 우선. 새 파일이 필요할 때만 `project.yml` 갱신 |

## 검증 결과

실행 명령:

```bash
git diff --check -- mydocs/plans/task_m010_153_impl.md mydocs/working/task_m010_153_stage1.md
```

결과:

```text
통과. 출력 없음.
```

## 잔여 위험

- `WKWebView`가 내부적으로 drag destination 처리를 강하게 소유하면 subclass override만으로 URL drop을 안정적으로 선점하지 못할 수 있다.
- `performDragOperation`에서 native 성공을 반환해도 WebKit DOM drop이 추가로 발생하는지 수동 smoke 전까지 확정할 수 없다.
- iCloud placeholder, file promise, 여러 파일 동시 drop은 v0.1 smoke 범위 밖으로 남을 수 있다.
- security-scoped bookmark 생성 실패는 fatal로 보지 않더라도 최근 문서 재열기 동작에 영향을 줄 수 있다.

## 다음 단계 영향

Stage 2에서는 `RhwpStudioNativeCommandWebView`에 native file URL drop callback과 pasteboard URL 추출 helper를 추가한다. Stage 3에서는 `DocumentViewerView`/`DocumentViewerStore` 연결과 duplicate drop guard를 구현한다.

## 승인 요청

Stage 1 조사는 완료했다. 이 보고서 기준으로 Stage 2 native file URL drop callback 설계 및 구현에 진입할지 승인 요청한다.
