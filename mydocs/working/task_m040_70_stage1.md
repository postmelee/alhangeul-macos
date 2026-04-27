# Issue #70 Stage 1 완료 보고서

## 타스크

- GitHub Issue: #70
- 마일스톤: M040
- 제목: HostApp 디버그 사이드바를 About 패널로 이전하고 확장 상태 조회를 보정
- 작업 브랜치: `local/task70`
- Stage: 1. viewer 루트 UI 단순화
- 완료 시각: 2026-04-26 16:57 KST

## 목표

HostApp viewer의 왼쪽 디버깅 사이드바를 제거하고, 문서 표시 영역을 앱의 주 화면으로 단순화한다. 문서 열기, 확대/축소 toolbar, 하단 상태바는 유지한다.

## 변경 내용

`Sources/HostApp/Views/ContentView.swift`:

- `ContentView`의 루트 `HStack`과 `Divider`를 제거했다.
- `SidebarView`와 `ExtensionStatusRow`를 제거했다.
- `ContentView`의 입력을 `DocumentViewerStore`만 받도록 단순화했다.
- `DocumentViewerView(store:)`와 기존 toolbar를 유지했다.

`Sources/HostApp/HostApp.swift`:

- `ContentView(store:extensionStatus:)` 호출을 `ContentView(store:)`로 변경했다.
- 사이드바 표시만을 위해 유지하던 `ExtensionStatusModel` `@StateObject`와 초기 `refresh()` 호출을 제거했다.

## 확인 결과

- viewer 왼쪽 사이드바 표시 경로가 제거됐다.
- 문서 열기 toolbar와 zoom toolbar는 `ContentView`에 그대로 남아 있다.
- 문서명, 현재 쪽수, 확대율을 표시하는 하단 상태바는 `DocumentViewerView` 내부 구현을 유지한다.
- `ExtensionStatusModel`과 `BuildInfo` 타입 자체는 삭제하지 않았다. Stage 2/3에서 About 화면과 확장 상태 표시 보정에 재사용할 수 있다.

## 검증

### diff check

```bash
git diff --check
```

결과:

- 통과

### AppKit 경계 검사

```bash
./scripts/check-no-appkit.sh
```

결과:

- `OK: shared Swift code has no AppKit/UIKit dependencies`

### HostApp Debug build

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

- `BUILD SUCCEEDED`
- CoreSimulator 관련 warning이 출력됐지만 macOS HostApp compile/link는 성공했다.

## 미진행 항목

- `알한글 > 알한글에 관하여` 메뉴와 About 화면 추가는 Stage 2 범위로 남겼다.
- 확장 등록 상태 조회 실패와 실제 미등록 상태 구분은 Stage 3 범위로 남겼다.
- 앱 실행 화면의 시각 확인은 About 화면이 붙은 뒤 통합 검증 단계에서 함께 수행한다.

## 다음 단계

Stage 2에서 앱 메뉴의 About 항목과 SwiftUI 기반 정보 화면을 추가한다.

## 승인 요청

Stage 1 완료를 보고하며, Stage 2 진행 승인을 요청한다.
