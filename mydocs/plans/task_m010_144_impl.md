# Issue #144 구현 계획서

## 구현 요약

HostApp WKWebView viewer 내부 drag/drop 로드가 Swift `DocumentViewerStore` 상태를 우회해 titlebar toolbar가 비활성으로 남는 문제를 보정한다. 문서 로드의 native 상태 기준을 유지하면서 WebView 내부 drag/drop 결과를 HostApp bridge로 전달하고, toolbar validation이 실제 문서 로드 상태에 맞게 갱신되도록 한다.

핵심 정책은 문서 존재 여부와 원본 파일 URL 보유 여부를 분리하는 것이다. `공유`와 `PDF로 내보내기`는 viewer export bridge로 동작하므로 source-less document라도 활성화할 수 있어야 한다. `Finder에서 보기`는 원본 URL을 신뢰할 수 있는 경우에만 활성화한다.

## 구현 단계

1. drag/drop 로드 경로와 toolbar validation 조사
   - bundled `rhwp-studio`의 `File.arrayBuffer()` drag/drop 로드 경로를 확인한다.
   - `RhwpStudioHostBridgeScript`, `RhwpStudioWebView.Coordinator`, `DocumentViewerStore`, `DocumentWindowToolbarController` 사이의 상태 전달 경계를 정리한다.
   - JavaScript `File` 객체만으로 원본 filesystem URL을 얻을 수 있는지 확인한다.
   - Stage 2에서 쓸 상태 모델을 `문서 있음`과 `원본 URL 있음`으로 분리할지 확정한다.

2. WebView drag/drop native bridge 추가
   - HostApp injected bridge script에서 drag/drop 또는 document-loaded 이벤트를 감지할 수 있는 최소 hook을 추가한다.
   - WebView 내부에서 로드된 파일의 filename, bytes, source metadata를 Swift로 전달하는 message type을 정의한다.
   - `RhwpStudioWebView.Coordinator`가 해당 message를 받아 store callback으로 전달하도록 한다.
   - bundled `rhwp-studio` 파일 자체를 직접 수정하지 않고 HostApp injection 경로를 우선 사용한다.

3. DocumentViewerStore 상태 갱신 및 toolbar validation 보정
   - drag/drop으로 받은 payload를 `RhwpStudioDocumentPayload` 또는 동등한 store 상태로 기록한다.
   - source URL이 없을 때도 `hasDocument`가 true가 되도록 하되, `canRevealInFinder`는 source URL 보유 여부를 유지한다.
   - toolbar가 store 상태 변경 후 재검증되도록 AppKit toolbar validation refresh 경로를 추가하거나 기존 SwiftUI update 흐름으로 충분한지 확인한다.
   - 최근 문서 기록은 원본 URL을 신뢰할 수 있는 경우에만 갱신한다.

4. 빌드 및 수동 smoke 검증
   - `xcodebuild` Debug HostApp build를 수행한다.
   - 앱 빈 상태에서 HWP 샘플을 viewer에 drag/drop한 뒤 `공유`, `PDF로 내보내기`, `Finder에서 보기` 활성 상태를 확인한다.
   - native open panel 또는 `/usr/bin/open -a` 경로에서 기존 toolbar와 최근 문서 동작이 유지되는지 확인한다.
   - HWPX 샘플은 저장 정책을 우회하지 않는 범위에서 toolbar 상태만 확인한다.

5. 문서 정리와 최종 보고 준비
   - 단계 보고서와 검증 결과를 정리한다.
   - `mydocs/orders/20260505.md` 상태를 실제 진행 상태에 맞게 갱신한다.
   - 최종 보고서에 변경 파일, 검증 명령, 남은 리스크를 기록한다.
   - `publish/task144` PR 준비 전 working tree와 문서 링크를 확인한다.

## 검증 항목

- `git diff --check` 통과
- `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` 성공
- drag/drop HWP 로드 후 viewer에 문서가 표시되고 `공유` toolbar item이 enabled 상태로 바뀜
- drag/drop HWP 로드 후 `PDF로 내보내기` toolbar item이 enabled 상태로 바뀜
- source URL을 확보하지 못하는 drag/drop 경로에서는 `Finder에서 보기`가 disabled로 남거나, source URL을 확보한 설계에서는 해당 원본 파일을 Finder에서 선택함
- native open panel 경로에서는 세 toolbar item과 최근 문서 동작이 기존처럼 유지됨
- HWPX drag/drop에서 기존 HWPX 베타/저장 제한 정책이 깨지지 않음

## 구현상 주의

- `Sources/RhwpCoreBridge`에는 AppKit/WebKit 의존을 추가하지 않는다.
- Quick Look/Thumbnail extension 코드는 이번 작업 범위에서 변경하지 않는다.
- bundled `rhwp-studio` generated JS를 직접 수정하면 upstream sync에 취약하므로 HostApp injected user script 또는 native wrapper 변경을 우선한다.
- WebView 내부 문서와 Swift store 문서가 서로 다른 bytes를 보지 않도록, drag/drop hook은 실제 로드 직전 또는 직후 한 번만 native state를 갱신하게 한다.
- `Finder에서 보기`는 원본 path가 불명확한 `File` 객체만으로 활성화하지 않는다.
- toolbar item validation은 `NSToolbarItemValidation` 호출 타이밍이 늦을 수 있으므로 store 상태 변경 후 사용자에게 비활성 상태가 남는지 수동으로 확인한다.
