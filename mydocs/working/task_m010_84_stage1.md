# Issue #84 Stage 1 완료 보고서

## 단계 목적

SwiftUI `LazyVStack`/`ScrollView`의 초기 layout 또는 virtualization 과정에서 첫 페이지가 조기에 disappear 처리되어 `pageTrees[0]`이 삭제되는 경로를 제거한다.

## 변경 내용

`Sources/HostApp/Views/DocumentViewerView.swift`의 `DocumentPageContainer`에서 `onDisappear` 즉시 unload 호출을 제거했다.

기존 동작:

- 페이지가 appear 되면 `store.loadPage(page)`가 render tree를 로드한다.
- 페이지가 disappear 되면 `store.unloadPage(page)`가 render tree를 즉시 제거한다.
- 다중 페이지 문서 초기 layout 중 첫 페이지가 조기에 disappear 처리되면 첫 페이지 cache가 사라지고 `ProgressView` 상태로 되돌아갈 수 있다.

변경 후 동작:

- 페이지가 appear 될 때 render tree를 로드하는 동작은 유지한다.
- 문서를 열어 둔 동안 로드된 page tree는 유지한다.
- 문서를 새로 열 때는 기존 `DocumentViewerStore.loadDocument(from:)`의 `pageTrees.removeAll()`로 문서 단위 cache가 정리된다.

## 범위 확인

- ThumbnailExtension cache 경로는 변경하지 않았다.
- Quick Look preview 경로는 변경하지 않았다.
- Shared renderer와 RustBridge는 변경하지 않았다.
- `DocumentViewerStore.unloadPage(_:)`는 삭제하지 않고 남겼다. 후속 메모리 정책 설계가 필요할 때 재사용할 수 있도록 하기 위해서다.

## 검증

```bash
git diff --check
```

결과: 통과

소스 diff 확인:

- `Sources/HostApp/Views/DocumentViewerView.swift`에서 `onDisappear { store.unloadPage(page) }` 제거만 발생했다.

## 잔여 리스크

한 번 로드된 페이지 tree가 문서가 열려 있는 동안 유지되므로 긴 문서에서는 메모리 사용량이 이전보다 늘 수 있다. 다만 이번 버그의 직접 원인은 aggressive unload 정책이므로, 메모리 상한이나 LRU/window eviction은 별도 타스크로 분리하는 것이 맞다.

## 다음 단계

Stage 2에서 HostApp Debug build와 render smoke 검증을 수행한다.
