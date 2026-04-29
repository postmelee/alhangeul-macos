# Task #92 구현 계획서

본 문서는 [`task_m010_92.md`](task_m010_92.md) 수행계획서를 실제 단계 단위로 분해한 것이다. 각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 진행한다.

## 작업 메타

- **Task**: #92 Viewer page tree cache LRU/window eviction 정책 도입
- **Milestone**: M010
- **Branch**: `local/task92`
- **Worktree**: `/tmp/rhwp-mac-task92`
- **기준 이슈**: [#92](https://github.com/postmelee/alhangeul-macos/issues/92)

## Stage 1. Viewer page cache 흐름 분석과 정책 확정

### 목적

Task #84에서 제거한 `onDisappear` 즉시 unload 회귀를 되살리지 않으면서, 큰 문서에서 `pageTrees`가 무제한 유지되지 않도록 할 cache eviction 정책을 확정한다.

### 변경 대상

- `mydocs/plans/task_m010_92.md`
- `mydocs/plans/task_m010_92_impl.md`
- `mydocs/working/task_m010_92_stage1.md`

### 작업

- `DocumentViewerStore.pageTrees`, `currentPage`, `loadPage(_:)`, `unloadPage(_:)`, `preloadInitialPages()` 흐름을 분석한다.
- `DocumentPageContainer.onAppear`가 갱신하는 `currentPage`가 실제 viewport 중심 page가 아니라 최근 appear page에 가깝다는 점을 반영한다.
- eviction 보호 집합을 정의한다.
  - visible page 집합
  - `currentPage` 주변 window
  - 방금 load/access된 page
  - 초기 안정성을 위한 page 0/1
- 정책은 우선 visible/current page 주변 window + page count 상한을 기본 후보로 삼고, LRU는 상한 초과 시 제거 순서를 정하는 보조 정책으로 검토한다.
- `onDisappear`는 즉시 unload 트리거가 아니라 visible page 관측 정보 갱신으로만 사용할지 결정한다.

### 검증

- `git diff --check`
- 분석 결과가 Stage 2 구현 단위로 충분히 구체적인지 확인
- Task #84 회귀 조건인 첫 페이지/두 번째 페이지 초기 `ProgressView` 재발 가능성을 별도로 점검

### 커밋 메시지

```text
Task #92 Stage 1: Viewer page cache 정책 확정
```

## Stage 2. page tree cache eviction 구현

### 목적

Stage 1에서 확정한 정책을 `DocumentViewerStore` 중심으로 구현한다.

### 변경 대상

- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift`
- `mydocs/working/task_m010_92_stage2.md`

### 작업

- `DocumentViewerStore`에 page access 순서와 visible page 관측 상태를 보관하는 최소 상태를 추가한다.
- `loadPage(_:)`가 page tree를 만들거나 기존 page를 재사용할 때 access 정보를 갱신한다.
- `setCurrentPage(_:)` 또는 별도 visible page API에서 protected page 집합을 계산한다.
- cache 상한 초과 시 protected page를 제외하고 오래 접근하지 않은 page tree부터 제거한다.
- `DocumentPageContainer.onAppear/onDisappear`는 visible/access 관측만 수행하고 즉시 `unloadPage(_:)`를 호출하지 않는다.
- 문서 전환 시 page tree, access 기록, visible page 기록을 함께 초기화한다.

### 검증 명령

```bash
git diff --check
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

### 확인 기준

- HostApp Debug build가 성공한다.
- source diff가 HostApp Viewer store/view cache 정책에 한정된다.
- 첫 페이지 초기 선로딩과 문서 전환 renderer image cache 보정은 유지된다.

### 커밋 메시지

```text
Task #92 Stage 2: Viewer page tree cache eviction 구현
```

## Stage 3. build, render smoke, 실제 Viewer 재검증

### 목적

cache eviction 구현이 기존 render pipeline과 Viewer 초기 표시 안정성을 깨지 않았는지 확인한다.

### 변경 대상

- `mydocs/working/task_m010_92_stage3.md`

### 검증 명령

```bash
git diff --check
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh /tmp/rhwp-task92-render
./scripts/render-debug-compare.sh /tmp/rhwp-task92-cache-smoke --page 1 samples/hwp-multi-001.hwp samples/20250130-hongbo.hwp samples/aift.hwp
./scripts/render-debug-compare.sh /tmp/rhwp-task92-table-vpos-page1 --page 1 /Users/melee/Documents/samples/table-vpos-01.hwp
./scripts/render-debug-compare.sh /tmp/rhwp-task92-table-vpos-page2 --page 2 /Users/melee/Documents/samples/table-vpos-01.hwp
```

### 확인 기준

- HostApp Debug build가 성공한다.
- 기존 render smoke가 성공한다.
- 대표 다중 페이지 문서의 page 1/2 render data가 계속 정상 생성된다.
- 실제 Viewer에서는 긴 문서를 상단, 중간, 하단으로 스크롤한 뒤 재진입해 `ProgressView` 회귀가 없는지 작업지시자가 확인한다.

### 커밋 메시지

```text
Task #92 Stage 3: Viewer cache eviction 검증
```

## Stage 4. 최종 보고와 작업 상태 정리

### 목적

최종 결과와 잔여 리스크를 정리하고 PR 게시 직전 상태로 만든다.

### 변경 대상

- `mydocs/working/task_m010_92_stage4.md`
- `mydocs/report/task_m010_92_report.md`
- `mydocs/orders/20260429.md`

### 작업

- 최종 결과 보고서에 정책 선택 근거, 변경 내용, 검증 결과, 제외 범위를 정리한다.
- 오늘할일 #92 상태를 완료로 갱신하고 완료 시각을 기록한다.
- 큰 문서 메모리 실측이 부족하면 후속 profiling 이슈 후보를 명시한다.

### 검증

- `git diff --check`
- `git status --short`

### 커밋 메시지

```text
Task #92 Stage 4 + 최종 보고서: Viewer page cache eviction 완료
```

## 승인 요청 사항

수행계획 보강을 반영해 Stage 1~4 구현 계획을 작성했다. Stage 1은 코드 변경 없이 cache 정책 확정과 분석 보고서 작성으로 진행한다.
