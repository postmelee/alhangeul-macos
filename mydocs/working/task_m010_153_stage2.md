# Task #153 Stage 2 보고서

## 단계 목적

`RhwpStudioNativeCommandWebView`에 Finder drag pasteboard의 file URL을 읽는 native drop 경계를 추가하고, 지원 문서 URL을 `URL` callback으로 전달할 수 있는 최소 AppKit 구현을 만든다.

## 산출물

| 파일 | 변경량 | 내용 |
|------|--------|------|
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | +91/-0 | `RhwpStudioNativeCommandWebView`에 file URL drag type 등록, `NSDraggingInfo` override, pasteboard URL 추출, HWP/HWPX 필터, `droppedFileURLHandler` callback 추가 |
| `mydocs/working/task_m010_153_stage2.md` | 신규 | Stage 2 구현 결과와 검증 결과 정리 |
| `mydocs/orders/20260506.md` | 1행 갱신 | Task #153 상태를 Stage 2 보고 승인 대기로 갱신 |

## 본문 변경 정도 / 본문 무손실 여부

소스 변경은 HostApp 전용 `RhwpStudioWebView.swift` 내부의 private `WKWebView` subclass에 한정했다. bundled `rhwp-studio` asset, `Sources/RhwpCoreBridge`, Quick Look/Thumbnail extension, `project.yml`은 변경하지 않았다.

## 구현 내용

### 1. native drag type 등록

`RhwpStudioNativeCommandWebView` 초기화 시 `registerForDraggedTypes([.fileURL])`를 호출해 Finder file URL drag를 AppKit 경계에서 받을 수 있도록 했다.

### 2. 지원 문서 URL 판별

`NSDraggingInfo.draggingPasteboard`에서 `NSURL` 객체를 읽고 다음 조건을 만족하는 첫 번째 URL만 사용한다.

- file URL
- path extension이 `hwp` 또는 `hwpx`

지원하지 않는 pasteboard 항목은 기존 WebKit/JavaScript 흐름으로 넘긴다.

### 3. callback 경계

subclass 내부 callback은 `((URL) -> Void)?` 타입의 `droppedFileURLHandler`로 두었다. `NSDraggingInfo`, `NSPasteboard`, `NSURL`은 private subclass 내부에 머물고, 다음 단계에서 SwiftUI/store 경계에는 `URL`만 전달한다.

### 4. 기존 fallback 보존

현재 Stage 2에서는 handler를 아직 store에 연결하지 않았다. 따라서 handler가 nil이면 `draggingEntered`, `draggingUpdated`, `prepareForDragOperation`, `performDragOperation` 모두 기존 `super` 흐름으로 넘긴다. Stage 3에서 handler를 연결한 뒤 native URL drop이 성공하면 `performDragOperation`이 `true`를 반환해 WebKit/JS fallback 중복 처리를 막는 구조다.

## 검증 결과

실행 명령:

```bash
git diff --check -- Sources/HostApp/Views/RhwpStudioWebView.swift
```

결과:

```text
통과. 출력 없음.
```

추가 실행 명령:

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED ** [2.240 sec]
```

Xcode가 CoreSimulatorService와 provisioning profile 관련 환경 경고를 출력했지만 macOS HostApp build는 성공했다.

## 잔여 위험

- Stage 2는 native URL callback 경계만 만든 상태라 실제 store 연결과 toolbar 활성화는 아직 구현하지 않았다.
- `WKWebView`가 DOM drop을 추가로 발생시키는지 여부는 Stage 3 연결 후 수동 smoke에서 확인해야 한다.
- file promise, iCloud placeholder, 여러 파일 동시 drop은 이번 단계에서 처리하지 않았다.

## 다음 단계 영향

Stage 3에서는 `RhwpStudioWebView` public callback과 `DocumentViewerView` 연결을 추가해 native URL drop을 `DocumentViewerStore.loadDocument(from:)`로 보낸다. 또한 native URL drop 직후 들어오는 같은 파일명의 source-less `dropped-document` message를 억제하는 guard를 구현한다.

## 승인 요청

Stage 2 구현과 검증을 완료했다. 이 보고서 기준으로 Stage 3 store 연결, duplicate drop 억제, toolbar 정책 보정에 진입할지 승인 요청한다.
