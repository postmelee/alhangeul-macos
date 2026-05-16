# Issue #153 구현 계획서

## 구현 요약

Finder에서 WKWebView viewer 영역으로 파일을 끌어놓을 때 AppKit drag pasteboard에서 원본 file URL을 먼저 확보하고, URL이 검증된 경우 기존 `DocumentViewerStore.loadDocument(from:)` 경로로 문서를 로드한다. 이 경로는 `RecentDocumentItem`과 security-scoped bookmark 생성을 이미 수행하므로 `sourceDocument`가 설정되고, 기존 `canRevealInFinder` 정책만으로 `Finder에서 보기` toolbar item이 활성화된다.

Task #144에서 추가한 JavaScript `dropped-document` bridge는 source-less fallback으로 유지한다. native file URL drop이 성공한 이벤트에서는 JS fallback이 같은 파일을 다시 source-less 문서로 덮어쓰지 않도록 중복 억제 상태를 둔다.

## 구현 단계

1. Finder drag/drop native URL 확보 지점 조사
   - `RhwpStudioNativeCommandWebView`가 이미 `WKWebView` subclass로 존재하므로 `NSDraggingDestination` override 지점으로 쓸 수 있는지 확인한다.
   - Finder pasteboard에서 file URL 후보를 얻는 방식과 HWP/HWPX 필터 위치를 정리한다.
   - `RhwpStudioHostBridgeScript`의 capture-phase `drop` listener와 native drop 처리의 중복 가능성을 확인한다.
   - 변경 범위를 HostApp 내부로 제한할 수 있는지 확인한다.

   검증:

   ```bash
   git diff --check -- mydocs/plans/task_m010_153_impl.md mydocs/working/task_m010_153_stage1.md
   ```

2. native file URL drop callback 설계 및 구현
   - `RhwpStudioNativeCommandWebView`에 file URL drop callback을 추가한다.
   - drag pasteboard에서 첫 번째 지원 문서 URL만 선택하고, 지원하지 않는 파일은 기존 WebView/JS 흐름으로 넘긴다.
   - native URL drop이 성공하면 WebKit 기본 drop과 JS capture listener가 처리하지 않도록 `performDragOperation`에서 명확한 성공/실패 값을 반환한다.
   - callback 타입은 AppKit 타입을 SwiftUI/store 밖으로 넓히지 않고 `URL`만 전달한다.

   검증:

   ```bash
   git diff --check -- Sources/HostApp/Views/RhwpStudioWebView.swift
   ```

3. store 연결, duplicate drop 억제, toolbar 정책 보정
   - `RhwpStudioWebView`에 `onDroppedFileURL` callback을 추가하고 `DocumentViewerView`에서 `store.loadDocument(from:)`로 연결한다.
   - native URL drop 직후 들어오는 같은 파일명의 JS `dropped-document` message는 짧은 시간 범위에서 무시하거나, source URL이 있는 현재 문서를 source-less payload가 덮어쓰지 않도록 guard한다.
   - `loadDroppedDocument(data:filename:)`는 source-less fallback 정책을 유지한다.
   - `canRevealInFinder`는 계속 `sourceDocument != nil`로 둔다.

   검증:

   ```bash
   git diff --check -- Sources/HostApp/Views/RhwpStudioWebView.swift Sources/HostApp/Views/DocumentViewerView.swift Sources/HostApp/Stores/DocumentViewerStore.swift
   ```

4. 빌드 및 toolbar smoke 검증
   - 공유 Swift 경계에 AppKit/UIKit 의존이 들어가지 않았는지 확인한다.
   - HostApp Debug build를 수행한다.
   - Finder drag/drop, source-less fallback, native open 경로별 toolbar 상태를 smoke 검증한다.
   - 가능하면 `Finder에서 보기` 실행이 원본 파일을 선택하는지 확인한다.

   검증:

   ```bash
   scripts/check-no-appkit.sh
   xcodebuild -project AlhangeulMac.xcodeproj \
     -scheme HostApp \
     -configuration Debug \
     -derivedDataPath build.noindex/DerivedData \
     CODE_SIGNING_ALLOWED=NO \
     build
   ```

5. 문서 정리와 PR 준비
   - 단계 보고서와 수동 smoke 결과를 정리한다.
   - `mydocs/orders/20260506.md` 상태를 실제 진행 상태에 맞게 갱신한다.
   - 최종 보고서에 source URL 확보 정책, 중복 drop 억제 정책, 검증 결과, 남은 리스크를 기록한다.
   - `publish/task153` PR 준비 전 working tree와 문서 링크를 확인한다.

   검증:

   ```bash
   git diff --check
   git log --oneline devel-webview..local/task153
   ```

## 검증 항목

- `git diff --check` 통과
- `scripts/check-no-appkit.sh` 통과
- `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` 성공
- Finder에서 HWP 파일을 WKWebView viewer 영역에 drag/drop했을 때 문서가 표시됨
- Finder drag/drop 후 `공유하기`, `PDF로 내보내기`, `Finder에서 보기` toolbar item이 enabled 상태가 됨
- `Finder에서 보기` 실행 시 원본 파일이 Finder에서 선택됨
- source-less JS/File drop fallback에서는 `공유하기`와 `PDF로 내보내기`는 enabled, `Finder에서 보기`는 disabled 상태를 유지함
- native open panel 또는 `/usr/bin/open -a` 경로에서는 기존 toolbar item과 최근 문서 동작이 유지됨
- HWPX drag/drop에서 기존 HWPX 베타/저장 제한 정책이 깨지지 않음

## 구현상 주의

- `Sources/RhwpCoreBridge`에는 AppKit/WebKit 의존을 추가하지 않는다.
- Quick Look/Thumbnail extension 코드는 이번 작업 범위에서 변경하지 않는다.
- bundled `rhwp-studio` generated asset은 직접 수정하지 않고 HostApp native/AppKit 경계와 injection bridge만 조정한다.
- `Finder에서 보기`는 native file URL이 확인된 경우에만 활성화한다.
- native drop과 JS source-less bridge가 같은 사용자 drop을 두 번 처리하지 않도록 한다.
- 여러 파일 drop은 v0.1 범위에서 첫 번째 지원 문서만 처리하고, 전체 UX 설계는 별도 작업으로 남긴다.
- iCloud placeholder/file promise처럼 즉시 readable file URL이 아닌 pasteboard 항목은 이번 구현에서 명시적으로 제외하거나 fallback으로 처리한다.
