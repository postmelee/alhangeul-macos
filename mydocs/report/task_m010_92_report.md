# Task #92 최종 보고서 - Viewer page tree cache LRU/window eviction 정책 도입

## 작업 개요

HostApp Viewer에서 다중 페이지 HWP/HWPX 문서를 스크롤할 때 `DocumentViewerStore.pageTrees`가 문서가 열려 있는 동안 무제한 유지되지 않도록 page tree cache eviction 정책을 도입했다.

Task #84에서 첫 페이지 초기 표시 문제를 해결하면서 `onDisappear` 즉시 unload를 제거한 것은 correctness 관점에서 맞는 방향이었다. 이번 작업은 그 보정을 되돌리지 않고, Store가 current/visible page 주변 window와 LRU 접근 순서를 함께 사용해 안전하게 cache를 정리하도록 만드는 데 초점을 뒀다.

작업 중 문서 전환 후 이전 문서의 scroll offset이 새 문서에 유지되는 문제가 추가로 확인되어 같은 Viewer lifecycle 범위에서 함께 보정했다.

## 최종 원인과 정책 판단

큰 문서에서 메모리 증가가 남은 원인은 한 번 로드한 page tree를 제거하는 명시 정책이 없었기 때문이다.

다만 SwiftUI `LazyVStack.onDisappear`를 곧바로 `unloadPage(_:)`에 연결하는 방식은 첫 페이지/두 번째 페이지가 초기 화면에서 `ProgressView`로 남는 회귀를 다시 만들 수 있다. `onAppear/onDisappear`는 실제 viewport 중심 page를 엄밀히 보장하지 않고, lazy layout과 virtualization에 따라 선행 또는 지연 호출될 수 있기 때문이다.

따라서 확정 정책은 다음 혼합 방식이다.

- Store가 cache 정책을 소유한다.
- View lifecycle은 visible page 관측 신호로만 사용한다.
- page 0/1, `currentPage` 주변, visible page 주변, 방금 접근한 page는 protected page로 취급한다.
- cache 상한을 초과하면 protected page를 제외한 page tree를 오래 접근하지 않은 순서로 제거한다.
- protected page 수가 상한보다 많으면 correctness를 우선해 일시적으로 soft limit 초과를 허용한다.

## 변경 내용

### Page tree cache eviction

- `DocumentViewerStore`에 cache metadata를 추가했다.
  - `maxCachedPageTreeCount = 12`
  - `protectedPageWindowRadius = 3`
  - `visiblePages`
  - `pageAccessOrder`
  - `nextPageAccessOrder`
- cache metadata는 SwiftUI 표시 상태가 아니므로 `@Published`로 노출하지 않았다.
- 문서 전환 시 page tree, visible page 기록, access 기록을 함께 초기화한다.
- `loadPage(_:)`는 이미 cache된 page라도 access 순서를 갱신한다.
- `loadPage(_:)` 이후 protected page 집합을 계산하고 soft limit 초과 시 LRU 순서로 eviction한다.
- `DocumentPageContainer.onDisappear`는 즉시 unload를 수행하지 않고 `markPageNotVisible(_:)`만 호출한다.

### 문서 전환 scroll reset

- `DocumentViewerStore`에 `documentRevision`을 추가했다.
- 새 문서가 성공적으로 로드될 때 `documentRevision`을 증가시킨다.
- `DocumentPagesView`의 `ScrollView`에 `.id(store.documentRevision)`을 부여했다.
- 이전 문서에서 내려가 있던 `NSScrollView` offset이 새 문서 표시 위치로 재사용되지 않도록 했다.

## 변경 파일

- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/HostApp/Views/DocumentViewerView.swift`
- `mydocs/plans/task_m010_92.md`
- `mydocs/plans/task_m010_92_impl.md`
- `mydocs/working/task_m010_92_stage1.md`
- `mydocs/working/task_m010_92_stage2.md`
- `mydocs/working/task_m010_92_stage3.md`
- `mydocs/working/task_m010_92_stage3_followup.md`
- `mydocs/working/task_m010_92_stage4.md`
- `mydocs/report/task_m010_92_report.md`
- `mydocs/orders/20260429.md`

## 검증 결과

### 자동 검증

- `git diff --check`: 통과
- `./scripts/build-rust-macos.sh`: 통과
- `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage2 CODE_SIGNING_ALLOWED=NO build`: 통과
- `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage3 CODE_SIGNING_ALLOWED=NO build`: 통과
- `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage3Followup CODE_SIGNING_ALLOWED=NO build`: 통과
- `./scripts/validate-stage3-render.sh /tmp/rhwp-task92-render`: 통과
- `./scripts/render-debug-compare.sh /tmp/rhwp-task92-cache-smoke --page 1 samples/hwp-multi-001.hwp samples/20250130-hongbo.hwp samples/aift.hwp`: 통과
- `./scripts/render-debug-compare.sh /tmp/rhwp-task92-table-vpos-page1 --page 1 /Users/melee/Documents/samples/table-vpos-01.hwp`: 통과
- `./scripts/render-debug-compare.sh /tmp/rhwp-task92-table-vpos-page2 --page 2 /Users/melee/Documents/samples/table-vpos-01.hwp`: 통과

`render-debug-compare.sh`는 최초 sandbox 실행에서 `qlmanage` SVG rasterize가 실패했으나, 권한 상승 재실행으로 diff PNG 산출물까지 생성했다.

### 수동 검증

작업지시자가 다음 흐름의 해결을 확인했다.

- `samples/tac-img-02.hwp`를 열고 아래로 스크롤한 뒤 `samples/20250130-hongbo.hwp`를 열 때 첫 페이지 상단부터 표시된다.
- 문서 전환 후 이전 scroll offset 때문에 아래 page가 먼저 보이는 문제가 해소됐다.

Stage 3 자동 검증과 기존 수동 확인을 통해 다음 관련 회귀도 함께 점검했다.

- `table-vpos-01.hwp` page 1/2 render data 생성 정상
- `20250130-hongbo.hwp`, `aift.hwp` 대표 문서 render data 생성 정상
- Task #84에서 처리한 첫 페이지 초기 선로딩과 문서 전환 renderer image cache 보정 유지

## 제외 범위

이번 이슈는 HostApp Viewer의 page tree cache와 문서 전환 scroll state에 한정했다.

제외한 범위:

- ThumbnailExtension cache 정책 변경
- Quick Look preview lazy rendering 전환
- Rust core dependency 갱신
- renderer 시각 품질 개선
- byte 단위 page tree 메모리 사용량 측정
- Instruments 기반 runtime memory profiling

## 잔여 리스크와 후속 후보

현재 cache 상한은 page tree 개수 기준 soft limit다. 실제 메모리 절감 효과는 page tree별 byte size나 Instruments 측정으로 수치화하지 않았다.

후속 이슈 후보:

- 긴 문서 기준 Viewer 스크롤 메모리 사용량을 Instruments 또는 lightweight runtime telemetry로 측정
- page count 기반 soft limit 12가 실제 문서 크기별로 적절한지 조정
- 필요 시 byte 기반 cache budget 또는 viewport 중심 page 산정 도입 검토

## 최종 상태

Task #92는 Viewer page tree cache eviction 정책 도입, 문서 전환 scroll reset 보정, 자동 검증, 작업지시자 수동 검증까지 완료된 상태다. PR 게시 전 최종 보고와 오늘할일 상태 갱신까지 완료했다.
