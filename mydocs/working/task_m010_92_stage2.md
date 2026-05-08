# Task #92 Stage 2 완료 보고서

## 단계 목적

Stage 1에서 확정한 visible/current page 주변 window + LRU 제거 순서 혼합 정책을 `DocumentViewerStore` 중심으로 구현했다. `LazyVStack.onDisappear`를 즉시 cache 제거 신호로 되돌리지 않고, Store가 page tree 생명주기를 소유하도록 유지했다.

## 변경 내용

### `DocumentViewerStore`

- `pageTrees` cache metadata를 Store 내부 상태로 추가했다.
  - `maxCachedPageTreeCount = 12`
  - `protectedPageWindowRadius = 3`
  - `visiblePages`
  - `pageAccessOrder`
  - `nextPageAccessOrder`
- access/visible metadata는 SwiftUI 표시 상태가 아니므로 `@Published`로 노출하지 않았다.
- 문서 전환 시 `pageTrees`, visible page 기록, access 기록을 함께 초기화하도록 `resetPageCache()`를 추가했다.
- `loadPage(_:)`는 이미 cache된 page라도 access 순서를 갱신하고, 새 page tree가 필요한 경우에만 render tree를 생성한다.
- page load/access 이후 cache 상한을 초과하면 protected page를 제외한 후보를 오래 접근하지 않은 순서로 제거한다.
- protected page는 다음 기준을 합쳐 계산한다.
  - page 0/1
  - `currentPage` 주변 ±3 page
  - 방금 load/access된 page
  - visible page 각각의 주변 ±3 page
- protected page 수가 soft limit보다 많으면 correctness를 우선해 protected page를 제거하지 않고 일시적으로 limit 초과를 허용한다.

### `DocumentViewerView`

- `DocumentPageContainer.onAppear`에서 `markPageVisible(page)`, `setCurrentPage(page)`, `loadPage(page)`를 호출하도록 연결했다.
- `DocumentPageContainer.onDisappear`는 `markPageNotVisible(page)`만 호출한다.
- `onDisappear`에서 `unloadPage(_:)`를 직접 호출하지 않는 Task #84 보정 방향을 유지했다.

## 아키텍처 점검

이번 변경은 macOS SwiftUI/AppKit bridge 관점에서 view lifecycle을 cache 제거의 직접 명령으로 쓰지 않고, Store가 도메인 상태와 cache 정책을 소유하는 방향이다.

SwiftUI `LazyVStack`의 `onAppear/onDisappear`는 실제 viewport 중심 page를 엄밀하게 보장하지 않으므로, view에서는 visible 관측 신호만 전달하고 eviction 판단은 Store의 protected set 계산으로 모았다. 이 구조는 현재 Viewer의 MV-style 상태 흐름과 맞고, 특정 문서 또는 특정 첫 페이지 회귀에만 맞춘 분기 없이 일반 page cache 정책으로 동작한다.

## 검증 결과

### 정적 검증

```bash
git diff --check
```

결과: 통과

### HostApp Debug build

처음 실행한 빌드는 새 worktree에 생성 산출물인 `Frameworks/Rhwp.xcframework`가 없어 실패했다.

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

분류: 코드 회귀가 아니라 worktree 준비 상태 문제

이후 build guide에 따라 Rust macOS framework를 생성했다.

```bash
./scripts/build-rust-macos.sh
```

결과: 통과, `Frameworks/Rhwp.xcframework` 생성 확인

동일 `DerivedData`로 재시도한 빌드는 이전 build description이 남아 같은 framework 탐색 오류가 반복되었다. `Frameworks/Rhwp.xcframework/Info.plist`가 유효한 것을 확인한 뒤 fresh DerivedData로 다시 빌드했다.

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage2 CODE_SIGNING_ALLOWED=NO build
```

결과: 통과

## 변경 범위 확인

- HostApp Viewer store/view cache 정책 변경에 한정했다.
- ThumbnailExtension, Quick Look preview, Rust core, renderer image cache 정책은 변경하지 않았다.
- Task #84에서 적용한 첫 페이지/두 번째 페이지 초기 선로딩과 문서 전환 renderer image cache 보정은 유지했다.

## 잔여 리스크

- `visiblePages`는 SwiftUI lifecycle 기반 soft signal이므로 실제 viewport 중심 page와 완전히 같지는 않다.
- page tree cache 상한은 byte 단위 메모리 측정이 아니라 page count 기준 soft limit다.
- 실제 스크롤 중 eviction 체감 성능과 첫 페이지 `ProgressView` 회귀 여부는 Stage 3에서 Viewer 실행으로 재확인해야 한다.

## 다음 단계

작업지시자 승인 후 Stage 3에서 HostApp build, render smoke, 실제 Viewer 재검증을 진행한다.

## 승인 요청

Stage 2 결과를 승인하면 Stage 3(build, render smoke, 실제 Viewer 재검증)로 진행한다.
