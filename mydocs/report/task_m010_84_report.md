# Task #84 최종 보고서 - Viewer 다중 페이지 HWP 첫 페이지 초기 로드 누락 수정

## 작업 개요

여러 페이지가 있는 `.hwp` 문서를 HostApp Viewer에서 열었을 때 첫 페이지 또는 두 번째 페이지가 초기 화면에서 보이지 않고, 스크롤 후 다시 돌아와야 늦게 로드되는 문제를 수정했다.

작업 중 실제 UI 재검증으로 두 가지 렌더 회귀도 함께 확인되어 같은 이슈 범위 안에서 처리했다.

- `복학원서.hwp`에서 page frame 오른쪽/아래 바깥으로 텍스트가 보이는 문제
- 문서 전환 후 이전 문서 이미지가 새 문서 이미지 위치에 재사용되는 문제

## 최종 원인

초기 첫 페이지 누락의 핵심 원인은 첫 화면 후보 page tree 준비를 SwiftUI `LazyVStack.onAppear`에만 의존한 구조였다. `onAppear` 호출 타이밍이 초기 layout과 virtualization에 영향을 받으면서 page 0/1이 `ProgressView` 상태로 남을 수 있었다.

초기 가설이었던 `onDisappear` 즉시 unload는 위험한 정책이었으므로 제거를 유지했다. 다만 실제 재현 영상 기준으로는 즉시 unload 제거만으로 충분하지 않았고, 문서 로드 완료 시점의 page 0/1 선로딩이 직접 해결책이었다.

렌더 회귀 원인은 각각 다음과 같다.

- page 바깥 텍스트: render tree 안에 page bbox 밖 node가 존재할 수 있는데, Viewer의 `DocumentPageNSView.draw(_:)`가 view bounds clipping을 명시하지 않았다.
- 문서 전환 이미지 오염: `CGTreeRenderer.imageCache`가 문서 내부 식별자인 `binDataId`만 key로 사용했고, SwiftUI/AppKit view 재사용으로 같은 renderer가 다른 문서를 그릴 때 이전 문서 이미지가 재사용될 수 있었다.

## 변경 내용

### Viewer page tree 생명주기

- `DocumentPageContainer.onDisappear`에서 `store.unloadPage(page)` 즉시 호출을 제거했다.
- `DocumentViewerStore.loadPage(_:)`에 page bounds guard를 추가했다.
- `DocumentViewerStore.loadDocument(data:filename:)`가 새 문서를 로드한 직후 page 0과 page 1 render tree를 선로딩하도록 했다.
- 1페이지 문서는 page 0만 선로딩한다.

### AppKit page view drawing

- `DocumentPageNSView`의 고정 layer 설정을 init 경로에 둔 상태를 유지했다.
- 원인 해결에 필수적이지 않은 window attach redraw, frame size redraw override, layer redraw policy 보정은 제거했다.
- `draw(_:)`에서 `context.clip(to: bounds)`를 먼저 적용해 page view 바깥 drawing을 차단했다.

### Renderer image cache

- `CGTreeRenderer.render(...)`가 렌더 대상 `RhwpDocument` identity 변경을 감지하도록 했다.
- 문서가 바뀌면 `imageCache`를 비워 문서 내부 `binDataId` 충돌로 인한 이미지 재사용을 차단했다.
- 같은 문서 안의 이미지 캐시는 유지해 반복 decode 비용을 줄이는 기존 장점은 보존했다.

## 변경 파일

- `Sources/HostApp/Views/DocumentViewerView.swift`
- `Sources/HostApp/Views/DocumentPageView.swift`
- `Sources/HostApp/Stores/DocumentViewerStore.swift`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `mydocs/plans/task_m010_84.md`
- `mydocs/plans/task_m010_84_impl.md`
- `mydocs/working/task_m010_84_stage1.md` ~ `task_m010_84_stage9.md`
- `mydocs/orders/20260429.md`

## 검증 결과

최종 단계까지 다음 검증을 수행했다.

- `git diff --check`: 통과
- `xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build`: 통과
- `./scripts/validate-stage3-render.sh`: 통과
- `samples/hwp-multi-001.hwp`, `samples/20250130-hongbo.hwp` page 1 render debug: 통과
- `/Users/melee/Documents/samples/table-vpos-01.hwp` page 1/2 render debug: 통과
- `samples/복학원서.hwp` page 1 render debug: 통과
- `samples/복학원서.hwp`, `samples/20250130-hongbo.hwp`, `samples/aift.hwp` page 1 render debug: 통과
- 같은 `CGTreeRenderer` 인스턴스를 세 문서에 순차 재사용하는 임시 pixel 비교 검증: 통과

작업지시자의 실제 UI 확인 결과:

- `table-vpos-01.hwp` 초기 열기에서 첫 번째와 두 번째 페이지가 늦게 로드되는 문제가 해소됐다.
- `복학원서.hwp` 오른쪽/아래 바깥 텍스트가 사라졌다.
- `복학원서.hwp` 이후 `20250130-hongbo.hwp`를 열 때 이전 문서 이미지가 재사용되는 문제가 해소됐다.

## 제외 범위와 후속 이슈

이번 이슈에서는 Viewer 첫 화면 표시 안정성과 그 과정에서 확인된 correctness 회귀만 처리했다.

제외한 범위:

- ThumbnailExtension cache 정책 변경
- Quick Look preview 경로 변경
- Rust core dependency 갱신
- renderer 시각 품질 개선 전반
- 대규모 page cache/LRU 설계

후속 이슈 권장 범위:

- Viewer page tree cache 정책 설계
- 현재 페이지와 주변 page window 유지
- LRU 또는 거리 기반 eviction
- visible page 즉시 제거 금지
- 큰 문서 스크롤 시 메모리 사용량 측정

## 최종 상태

Task #84는 직접 재현된 Viewer 첫 페이지 초기 로드 누락과 관련 렌더 캐시 회귀가 해결된 상태다. PR 게시 전 최종 보고와 오늘할일 상태 갱신까지 완료했다.
