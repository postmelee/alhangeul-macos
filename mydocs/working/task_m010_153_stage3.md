# Task #153 Stage 3 보고서

## 단계 목적

Stage 2에서 만든 native file URL drop callback을 `RhwpStudioWebView` public callback으로 노출하고, `DocumentViewerView`에서 `DocumentViewerStore.loadDocument(from:)`로 연결한다. 또한 native URL drop 직후 같은 문서에 대한 source-less JavaScript drop payload가 들어와도 source URL 상태를 덮어쓰지 않도록 억제한다.

## 산출물

| 파일 | 변경량 | 내용 |
|------|--------|------|
| `Sources/HostApp/Views/RhwpStudioWebView.swift` | +49/-0 | `onDroppedFileURL` callback 추가, coordinator 연결, native drop marker와 2초 source-less duplicate guard 추가 |
| `Sources/HostApp/Views/DocumentViewerView.swift` | +5/-0 | native dropped file URL을 `store.loadDocument(from:)`로 연결 |
| `mydocs/working/task_m010_153_stage3.md` | 신규 | Stage 3 구현 결과와 검증 결과 정리 |
| `mydocs/orders/20260506.md` | 1행 갱신 | Task #153 상태를 Stage 3 보고 승인 대기로 갱신 |

## 본문 변경 정도 / 본문 무손실 여부

변경은 HostApp viewer 경계에 한정했다. `DocumentViewerStore`는 변경하지 않고 기존 URL 기반 로드 경로를 재사용했다. `Sources/RhwpCoreBridge`, Quick Look/Thumbnail extension, bundled `rhwp-studio` asset, `project.yml`은 변경하지 않았다.

## 구현 내용

### 1. WebView public callback 추가

`RhwpStudioWebView`에 `onDroppedFileURL: (URL) -> Void` callback을 추가했다. `Coordinator`는 Stage 2의 `RhwpStudioNativeCommandWebView.droppedFileURLHandler`를 받아 이 callback을 호출한다.

AppKit 타입은 계속 `RhwpStudioNativeCommandWebView` 내부에 머물고, SwiftUI 경계에는 `URL`만 넘어간다.

### 2. store 연결

`DocumentViewerView`는 native dropped file URL을 `store.loadDocument(from:)`로 전달한다. 이 경로는 기존 native open과 동일하게 다음을 수행한다.

- 파일 data 읽기
- `RecentDocumentItem.make(for:)` 생성
- `sourceDocument` 설정
- 최근 문서 기록
- `canRevealInFinder == true` 상태 진입

따라서 별도 reveal 상태를 만들지 않고 기존 toolbar validation 정책을 유지했다.

### 3. duplicate drop 억제

native file URL drop이 들어오면 coordinator가 파일명과 처리 시각을 `NativeDropMarker`로 기록한다. 이후 2초 안에 같은 파일명의 `dropped-document` JavaScript message가 들어오면 source-less payload를 무시한다.

이 guard는 native URL이 있는 현재 문서 상태를 source-less bytes payload가 덮어써서 `Finder에서 보기`가 다시 비활성화되는 문제를 막기 위한 것이다.

## 검증 결과

실행 명령:

```bash
git diff --check -- Sources/HostApp/Views/RhwpStudioWebView.swift Sources/HostApp/Views/DocumentViewerView.swift Sources/HostApp/Stores/DocumentViewerStore.swift
```

결과:

```text
통과. 출력 없음.
```

추가 실행 명령:

```bash
scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
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
** BUILD SUCCEEDED ** [2.442 sec]
```

Xcode가 CoreSimulatorService와 provisioning profile 관련 환경 경고를 출력했지만 macOS HostApp build는 성공했다.

## 잔여 위험

- 실제 Finder drag/drop에서 `performDragOperation`이 DOM drop보다 먼저 선점하는지는 Stage 4 수동 smoke로 확인해야 한다.
- duplicate guard는 파일명과 짧은 시간 범위를 기준으로 하므로, 같은 파일명을 가진 다른 파일을 매우 빠르게 연속 drop하는 경우 source-less fallback이 억제될 수 있다.
- `Finder에서 보기` 실행이 원본 파일을 Finder에서 선택하는지는 아직 확인하지 않았다.

## 다음 단계 영향

Stage 4에서는 빌드된 앱을 실행해 Finder drag/drop 후 toolbar 상태와 `Finder에서 보기` 동작을 smoke 검증한다. native open 경로와 source-less fallback 정책도 함께 확인한다.

## 승인 요청

Stage 3 구현과 검증을 완료했다. 이 보고서 기준으로 Stage 4 build 및 toolbar smoke 검증에 진입할지 승인 요청한다.
