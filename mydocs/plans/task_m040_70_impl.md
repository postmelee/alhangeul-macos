# Issue #70 구현 계획서

## 타스크

- GitHub Issue: #70
- 마일스톤: M040 (`v0.4.0`)
- 제목: HostApp 디버그 사이드바를 About 패널로 이전하고 확장 상태 조회를 보정
- 작업 브랜치: `local/task70`
- 수행계획서: `mydocs/plans/task_m040_70.md`

## 구현 원칙

- viewer 본문은 문서 표시와 문서 열기 흐름에 집중시키고, 디버깅성 앱/확장 정보는 About 화면으로 이동한다.
- 문서명, 현재 쪽수, 확대율은 기존 하단 상태바와 toolbar 흐름을 유지한다.
- About 진입점은 macOS 표준 앱 메뉴의 `알한글에 관하여`로 제공한다.
- macOS 12 deployment target을 유지하므로 About 화면은 SwiftUI view와 최소 AppKit window bridge로 구현한다.
- 확장 상태는 번들에 포함된 정보와 시스템 PlugInKit 등록 조회 결과를 분리해 표시한다.
- 앱 내부에서 `pluginkit` 조회가 실패할 수 있는 상황을 실제 미등록으로 오인하지 않도록 상태 문구와 모델을 보정한다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 추가하지 않는다.
- `project.yml`이 Xcode project 원본이라는 정책을 유지하고, 필요할 때만 `xcodegen generate`를 수행한다.

## Stage 1. viewer 루트 UI 단순화

### 목표

- 왼쪽 디버깅 사이드바를 제거하고 HostApp viewer를 문서 표시 중심 구조로 정리한다.
- 사이드바 제거 후에도 사용자에게 필요한 문서 정보와 열기/확대 조작이 유지되는지 확인한다.

### 작업

- `ContentView`에서 `SidebarView`, `ExtensionStatusRow`, 사이드바 `Divider` 의존을 제거한다.
- `ContentView`의 루트 구조를 `DocumentViewerView(store:)` 중심으로 단순화한다.
- `ContentView`가 더 이상 `ExtensionStatusModel`을 직접 받지 않도록 생성 경계를 검토한다.
- `HostApp.swift`에서 `ContentView` 초기화 인자를 변경한다.
- 문서 없음, 로딩, 에러, 문서 표시 상태의 레이아웃이 사이드바 없이 깨지지 않는지 확인한다.

### 완료 기준

- viewer 왼쪽 사이드바가 더 이상 표시되지 않는다.
- 문서 열기 toolbar, zoom toolbar, 하단 상태바가 유지된다.
- `ExtensionStatusModel` UI가 About 영역으로 이전될 준비가 된다.

### 검증

- `git diff --check`
- Swift compile 검증은 Stage 3 이후 통합 빌드에서 수행한다.

### 커밋 메시지

- `Task #70 Stage 1: viewer 디버그 사이드바 제거`

## Stage 2. About 메뉴와 정보 화면 추가

### 목표

- `알한글 > 알한글에 관하여`에서 앱 버전과 확장 정보를 확인할 수 있는 About 화면을 제공한다.
- macOS 12 호환성을 유지하면서 SwiftUI 기반의 제품 정보 화면을 띄운다.

### 작업

- `AboutView`를 신규 추가해 앱 이름, 버전, 빌드, 확장 정보 섹션을 구성한다.
- About 창을 표시하는 작은 AppKit bridge를 HostApp 소유 영역에 추가한다.
  - `NSWindowController` 또는 동등한 최소 window owner를 사용한다.
  - `NSHostingController(rootView:)`로 SwiftUI About 화면을 호스팅한다.
  - 중복 About 창이 여러 개 열리지 않도록 기존 창 재사용 또는 전면 표시 정책을 둔다.
- `HostApp.swift`의 `.commands`에 `CommandGroup(replacing: .appInfo)`를 추가해 `알한글에 관하여` 항목을 연결한다.
- 기존 앱 메뉴, 문서 열기 메뉴, 보기 메뉴 단축키와 충돌하지 않도록 확인한다.

### 완료 기준

- 앱 메뉴에 `알한글에 관하여`가 노출된다.
- 메뉴 선택 시 About 화면이 표시된다.
- About 화면에 앱 버전과 빌드 번호가 표시된다.
- About 화면에 Quick Look 미리보기와 Thumbnail 확장 이름 및 bundle identifier가 표시된다.

### 검증

- `git diff --check`
- 코드 리뷰로 `.commands` 구성과 window owner 수명 확인

### 커밋 메시지

- `Task #70 Stage 2: About 메뉴와 정보 화면 추가`

## Stage 3. 확장 상태 조회와 표시 보정

### 목표

- 확장 번들 포함 여부, 시스템 등록 여부, 등록 조회 실패를 구분해 About 화면에 표시한다.
- 현재 확인된 문제처럼 `pluginkit` 조회 실패를 bundle ID 불일치나 실제 미등록으로 오해하지 않게 한다.

### 작업

- `ExtensionStatusModel`의 상태 모델을 About 화면에 적합하게 조정한다.
  - 확장 bundle identifier와 표시명을 유지한다.
  - 가능하면 현재 앱 번들 내부 `.appex` 존재 여부를 별도 속성으로 제공한다.
  - PlugInKit 조회 성공 시 등록됨/미등록을 구분한다.
  - PlugInKit 조회 실패 시 `시스템 등록 확인 불가` 계열의 상태로 분리한다.
- `pluginkit` 호출 결과에서 stdout/stderr/termination status를 수집해 상태 판단을 더 명확히 한다.
- About 화면에 `상태 새로고침` 액션을 배치한다.
- 상태 문구가 제품 UI에서 지나치게 디버깅 로그처럼 보이지 않도록 짧은 설명 중심으로 정리한다.

### 완료 기준

- 확장 ID는 기존 `com.postmelee.alhangeulmac.*` 계열로 유지된다.
- 앱 번들에 내장된 확장과 PlugInKit 등록 조회 결과가 별도 의미로 표시된다.
- 조회 실패 상태가 실제 미등록 상태와 구분된다.
- About 화면에서 상태 새로고침이 동작한다.

### 검증

- `git diff --check`
- `./scripts/check-no-appkit.sh`
- 설치본 또는 Debug 실행본에서 About 상태 문구 수동 확인

### 커밋 메시지

- `Task #70 Stage 3: 확장 상태 표시 보정`

## Stage 4. 통합 검증과 보고

### 목표

- UI 변경과 About 상태 표시를 빌드/정적 검사/수동 확인으로 검증한다.
- 단계별 완료보고서와 최종 보고서를 작성해 변경 결과와 남은 한계를 기록한다.

### 작업

- `./scripts/check-no-appkit.sh`로 bridge 경계 위반 여부를 확인한다.
- 필요 시 `xcodegen generate`를 실행한다.
- HostApp Debug build를 수행한다.
- 가능한 경우 앱을 실행해 다음 흐름을 확인한다.
  - viewer 왼쪽 사이드바 미노출
  - 문서 열기와 zoom toolbar 유지
  - 하단 상태바 문서명/쪽수/확대율 유지
  - `알한글 > 알한글에 관하여` 메뉴 동작
  - About 화면 앱 버전/빌드/확장 정보 표시
  - 확장 등록 조회 실패와 실제 미등록 상태가 문구상 구분됨
- 단계별 완료보고서와 최종 결과보고서를 작성한다.
- 오늘할일 상태를 최종 결과에 맞춰 갱신한다.

### 완료 기준

- HostApp build가 성공한다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 의존이 추가되지 않는다.
- 사용자-facing viewer 화면에서 디버깅 사이드바가 사라진다.
- About 화면이 앱/빌드/확장 정보를 담당한다.
- 최종 보고서에 검증 결과와 PlugInKit 조회의 환경 의존성이 기록된다.

### 검증

- `git status --short --branch`
- `git diff --check`
- `./scripts/check-no-appkit.sh`
- `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build`
- 필요한 경우 수동 실행 검증 결과 기록

### 커밋 메시지

- `Task #70 Stage 4 + 최종 보고서: 통합 검증과 보고`

## Stage 5. 초기 상태바 레이아웃 보정

### 목표

- 사이드바 제거 후 빈 문서 상태에서 하단 상태바가 창 전체 하단이 아니라 콘텐츠 중앙 영역 하단에 붙어 보이는 문제를 보정한다.
- `문서 없음` 상태 텍스트가 viewer 창의 왼쪽 하단에 안정적으로 표시되도록 한다.

### 작업

- `DocumentViewerView` 루트 콘텐츠가 창 전체 폭과 높이를 차지하도록 frame 제약을 추가한다.
- `StatusBarView`가 전체 폭을 사용하도록 frame 제약을 추가한다.
- Debug 앱을 실행해 빈 문서 초기 화면에서 왼쪽 사이드바 미노출과 `문서 없음` 하단 위치를 확인한다.

### 완료 기준

- 빈 문서 초기 화면에서 `문서 없음`이 창 왼쪽 하단에 표시된다.
- 중앙 문서 열기 안내는 기존처럼 중앙에 유지된다.
- 문서 열기 toolbar와 zoom toolbar가 유지된다.
- HostApp Debug build가 성공한다.

### 검증

- `git diff --check`
- `./scripts/check-no-appkit.sh`
- `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build`
- Debug 앱 실행 후 초기 화면 수동 확인

### 커밋 메시지

- `Task #70 Stage 5: 초기 상태바 레이아웃 보정`

## 승인 요청 사항

Stage 5 보정까지 반영한 최종 결과 기준으로 PR 게시 승인을 요청한다.
