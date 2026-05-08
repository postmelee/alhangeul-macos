# Issue #92 Stage 1 완료 보고서

## 단계 목적

Task #84에서 제거한 `onDisappear` 즉시 unload 회귀를 되살리지 않으면서, 큰 문서에서 `DocumentViewerStore.pageTrees`가 무제한 유지되지 않도록 할 cache eviction 정책을 확정한다.

## 현재 흐름 분석

현재 Viewer의 page tree cache 소유자는 `DocumentViewerStore`다.

- `pageTrees: [Int: RenderNode]`가 page index별 render tree를 보관한다.
- 문서를 새로 열면 `loadDocument(from:)`에서 `pageTrees.removeAll()`과 `currentPage = 0`을 수행한다.
- `loadDocument(data:filename:)`는 새 `RhwpDocument`를 만들고 `preloadInitialPages()`로 page 0/1을 선로딩한다.
- `DocumentPageContainer.onAppear`는 `store.setCurrentPage(page)`와 `store.loadPage(page)`를 호출한다.
- Task #84 이후 `onDisappear` 즉시 `unloadPage(_:)` 호출은 제거된 상태다.

이 구조에서 `currentPage`는 실제 viewport 중심 page가 아니라 최근 `onAppear`된 page에 가깝다. SwiftUI `LazyVStack`의 virtualization 때문에 여러 page가 appear될 수 있고, appear/disappear 타이밍은 실제 사용자가 바라보는 page와 정확히 일치하지 않는다.

따라서 `currentPage` 단독 기준 eviction이나 `onDisappear` 즉시 unload는 macOS SwiftUI lifecycle 관점에서 부정확하다. view lifecycle은 관측 신호로만 사용하고, 실제 cache 제거는 store가 보호 집합과 access 순서를 기준으로 판단해야 한다.

## 정책 비교

### 순수 LRU

장점:

- 구현이 단순하다.
- 오래 접근하지 않은 page부터 제거하므로 빠른 왕복 스크롤에 어느 정도 대응한다.

단점:

- 현재 화면 주변 page라는 문서 viewer 특성을 직접 반영하지 않는다.
- 첫 표시/현재 표시 page가 access 순서만으로 충분히 보호되지 않으면 UI 회귀 위험이 있다.

### 주변 page window

장점:

- 문서 viewer에서 일반적인 현재 page 주변 유지 모델과 잘 맞는다.
- 사용자가 인접 page로 이동할 때 재로딩을 줄일 수 있다.

단점:

- 현재 `currentPage`가 정확한 viewport 중심 page가 아니므로 anchor가 불안정할 수 있다.
- 빠른 왕복 스크롤에서는 window 밖이지만 최근 본 page가 바로 제거될 수 있다.

### 혼합 정책

visible/current page 주변 window를 우선 보호하고, cache 상한을 넘었을 때 protected page 밖 후보를 LRU 순서로 제거한다.

장점:

- 문서 viewer의 주변 page 유지 모델과 LRU의 최근 접근 보호를 모두 반영한다.
- `onDisappear` 즉시 unload를 되살리지 않고 correctness를 우선할 수 있다.
- Store가 cache 정책을 소유하므로 SwiftUI view lifecycle에 데이터 생명주기를 직접 결합하지 않는다.

단점:

- 순수 LRU보다 상태가 조금 늘어난다.
- visible page 관측값이 lazy layout 이벤트에 영향을 받으므로 protected set은 soft signal로 다뤄야 한다.

## 확정 정책

Stage 2에서는 혼합 정책을 구현한다.

- cache owner: `DocumentViewerStore`
- cache key: page index
- cache 상한: page tree count 기준 soft limit
- 기본 soft limit: 12 page trees
- 주변 window 보호 반경: current/visible page 기준 앞뒤 3페이지
- 제거 순서: protected page를 제외한 page 중 access 순서가 가장 오래된 page부터 제거
- protected page:
  - visible page 집합
  - `currentPage` 주변 ±3 page
  - visible page 각각의 주변 ±3 page
  - 방금 load/access된 page
  - 초기 안정성을 위한 page 0/1
- protected page 수가 soft limit보다 많으면 protected page 제거 없이 일시적으로 limit 초과를 허용한다.

## Stage 2 구현 지침

`DocumentViewerStore`에 다음 비공개 상태를 추가한다.

- `private let maxCachedPageTreeCount = 12`
- `private let protectedPageWindowRadius = 3`
- `private var visiblePages: Set<Int> = []`
- `private var pageAccessOrder: [Int: UInt64] = [:]`
- `private var nextPageAccessOrder: UInt64 = 0`

`visiblePages`, `pageAccessOrder`, `nextPageAccessOrder`는 SwiftUI view가 직접 표시할 상태가 아니므로 `@Published`로 노출하지 않는다. 불필요한 view invalidation을 줄이고, cache metadata를 store 내부 구현 detail로 유지한다.

추가할 공개 API:

- `markPageVisible(_ page: Int)`
- `markPageNotVisible(_ page: Int)`

기존 API 보정:

- `loadDocument(from:)` 또는 내부 helper에서 page tree, access 기록, visible page 기록을 함께 초기화한다.
- `loadPage(_:)`는 이미 로드된 page라도 access 순서를 갱신한다.
- `loadPage(_:)`가 새 page tree를 만들거나 기존 page access를 기록한 뒤 eviction을 수행한다.
- `setCurrentPage(_:)`는 current page와 access 기록을 갱신하되, 즉시 unload를 직접 수행하지 않는다.
- `unloadPage(_:)`는 필요하면 내부 helper로 축소하거나 후속 정책 hook으로 유지한다.

`DocumentPageContainer` 보정:

- `onAppear`: `markPageVisible(page)`, `setCurrentPage(page)`, `loadPage(page)` 호출
- `onDisappear`: `markPageNotVisible(page)`만 호출
- `onDisappear`에서 `unloadPage(_:)`를 직접 호출하지 않는다.

## 검증

```bash
git diff --check
```

결과: 통과

## 잔여 리스크

visible page 집합은 SwiftUI `LazyVStack` lifecycle 이벤트 기반 관측값이므로 실제 viewport와 완전히 같지는 않다. 이번 구현은 correctness를 우선해 visible/current 주변 window를 넓게 보호하고 soft limit 초과를 허용한다.

정확한 viewport 중심 page 계산이 필요해지면 `GeometryReader`/`PreferenceKey` 기반 active page 산정 또는 별도 scroll position 추적을 후속 작업으로 분리한다.

page tree별 실제 메모리 사용량은 현재 자동화되어 있지 않다. 이번 작업은 page count 기반 상한으로 시작하고, 필요하면 Instruments 또는 별도 계측으로 byte 기반 정책을 후속 검토한다.

## 다음 단계

작업지시자 승인 후 Stage 2에서 `DocumentViewerStore` 중심의 cache eviction 구현을 진행한다.
