# Task #84 구현 계획서

본 문서는 [`task_m010_84.md`](task_m010_84.md) 수행계획서를 실제 단계 단위로 분해한 것이다. 각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 진행한다.

## 작업 메타

- **Task**: #84 Viewer 다중 페이지 HWP 첫 페이지 초기 로드 누락 수정
- **Milestone**: M010
- **Branch**: `local/task84`
- **Worktree**: `/tmp/rhwp-mac-task84`
- **기준 이슈**: [#84](https://github.com/postmelee/alhangeul-macos/issues/84)

## Stage 1. Viewer page tree 즉시 unload 제거

### 목적

SwiftUI `LazyVStack`/`ScrollView`의 초기 layout 또는 virtualization 과정에서 첫 페이지가 조기에 disappear 처리되어 `pageTrees[0]`이 삭제되는 경로를 제거한다.

### 변경 대상

- `Sources/HostApp/Views/DocumentViewerView.swift`
- `mydocs/working/task_m010_84_stage1.md`

### 작업

- `DocumentPageContainer.onDisappear`에서 `store.unloadPage(page)` 호출을 제거한다.
- `DocumentViewerStore.unloadPage(_:)`는 이번 단계에서 삭제하지 않는다. 후속 메모리 정책 설계 여지를 남기고 소스 변경 범위를 최소화한다.
- ThumbnailExtension, QLExtension, Shared renderer 경로는 변경하지 않는다.

### 검증

- `git diff --check`
- 소스 diff가 `DocumentViewerView.swift`의 즉시 unload 제거에 한정되는지 확인

### 커밋 메시지

```text
Task #84 Stage 1: Viewer page tree 즉시 unload 제거
```

## Stage 2. 빌드 및 렌더 smoke 검증

### 목적

Stage 1 변경이 HostApp compile/link와 기존 render smoke 경로를 깨지 않았는지 확인한다.

### 변경 대상

- `mydocs/working/task_m010_84_stage2.md`

### 검증 명령

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh
./scripts/render-debug-compare.sh /tmp/rhwp-viewer-first-page-task84 --page 1 samples/hwp-multi-001.hwp samples/20250130-hongbo.hwp
```

### 확인 기준

- HostApp Debug build가 성공한다.
- 기본 render smoke가 성공한다.
- 대표 다중 페이지 `.hwp`의 page 1 render tree, core SVG, native PNG가 생성된다.

### 커밋 메시지

```text
Task #84 Stage 2: Viewer 첫 페이지 로드 수정 검증
```

## Stage 3. 보고서와 작업 상태 정리

### 목적

최종 결과와 잔여 리스크를 정리하고 PR 게시 직전 상태로 만든다.

### 변경 대상

- `mydocs/working/task_m010_84_stage3.md`
- `mydocs/report/task_m010_84_report.md`
- `mydocs/orders/20260429.md`

### 작업

- 최종 결과 보고서에 원인, 수정 내용, 검증 결과, 제외 범위를 정리한다.
- 오늘할일 #84 상태를 완료로 갱신하고 완료 시각을 기록한다.
- `git status`로 미커밋 변경이 없는지 확인한다.

### 검증

- `git diff --check`
- `git status --short`

### 커밋 메시지

```text
Task #84 Stage 3 + 최종 보고서: Viewer 첫 페이지 로드 수정 완료
```

## 승인 요청 사항

위 3단계 구현 계획으로 Stage 1을 진행해도 되는지 승인 요청한다. 승인 전에는 `Sources/HostApp/Views/DocumentViewerView.swift`를 수정하지 않는다.
