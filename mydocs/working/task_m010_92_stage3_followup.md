# Task #92 Stage 3 Follow-up 보고서

## 발견 현상

`samples/tac-img-02.hwp`를 열고 아래로 스크롤한 뒤 `samples/20250130-hongbo.hwp`를 열면 새 문서의 첫 페이지가 아니라 아래쪽 page 위치가 먼저 보이는 현상이 보고되었다.

## 판단

현재 Task #92 범위에서 다루는 것이 맞다.

이 현상은 page tree cache eviction 자체의 오류라기보다, 같은 Viewer `ScrollView`가 이전 문서의 scroll offset을 새 문서에도 유지하는 문제다. Stage 2에서 `LazyVStack` lifecycle과 Store cache 정책을 조정했으므로, 새 문서 로드 시 Viewer scroll state가 문서 identity에 맞게 초기화되는지까지 같은 작업 범위에서 보정하는 것이 적절하다.

## 원인 분석

- `DocumentViewerStore.loadDocument(data:filename:)`는 새 문서 로드 시 `currentPage = 0`과 page 0/1 preload를 수행한다.
- 하지만 `DocumentPagesView`의 `ScrollView` identity는 문서 전환과 무관하게 유지된다.
- SwiftUI가 기존 `NSScrollView`의 scroll offset을 재사용하면, 새 문서도 이전 문서에서 내려가 있던 위치로 표시될 수 있다.
- 이 상태에서 아래쪽 page의 `onAppear`가 먼저 발생하면 `currentPage`도 해당 page로 갱신되어 첫 페이지로 복귀하지 않는다.

## 변경 내용

### `DocumentViewerStore`

- `@Published private(set) var documentRevision: Int`를 추가했다.
- 새 문서가 성공적으로 로드될 때 `documentRevision`을 증가시킨다.

### `DocumentViewerView`

- `DocumentPagesView`의 `ScrollView`에 `.id(store.documentRevision)`을 부여했다.
- 새 문서 revision마다 `ScrollView` identity를 교체해 이전 문서의 scroll offset을 재사용하지 않게 했다.

## 구현 판단

`ScrollViewReader.scrollTo(0, anchor: .top)` 방식도 가능하지만, 현재 Viewer는 vertical/horizontal 양방향 scroll을 쓰고 있고 macOS `NSScrollView` backing state가 남는 것이 문제다. 따라서 새 문서 identity가 바뀔 때 scroll container 자체를 새로 만드는 `.id(...)` 방식이 더 단순하고 일반적이다.

문서별 특수 분기나 특정 샘플 파일 조건은 추가하지 않았다.

## 검증 결과

### 정적 검증

```bash
git diff --check
```

결과: 통과

### HostApp Debug build

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedDataStage3Followup CODE_SIGNING_ALLOWED=NO build
```

결과: 통과

수동 확인 대상 앱:

```text
/tmp/rhwp-mac-task92/build.noindex/DerivedDataStage3Followup/Build/Products/Debug/AlhangeulMac.app
```

### 실제 Viewer 수동 확인 필요 항목

- `samples/tac-img-02.hwp`를 열고 아래로 스크롤
- `samples/20250130-hongbo.hwp`를 열었을 때 첫 페이지 상단부터 보이는지 확인
- 기존 `table-vpos-01.hwp` page 1/2 초기 표시 회귀가 없는지 확인

## 잔여 리스크

자동 render smoke는 scroll offset reset을 직접 검증하지 못한다. 최종 판정은 실제 Viewer에서 문서 전환 흐름을 수동 확인해야 한다.
