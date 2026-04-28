# Issue #84 Stage 5 완료 보고서

## 단계 목적

작업지시자의 실제 UI 테스트 영상에서 Stage 3 redraw 보강 후에도 첫 번째와 두 번째 페이지가 초기 `ProgressView` 상태로 남는 문제가 확인됐다. 문서 로드 직후 첫 화면 후보 페이지의 render tree를 store가 선로딩하도록 보정한다.

## 영상 기반 재판정

첨부 영상의 1초/2초 프레임에서 상태바는 `1/5쪽`을 표시하지만 본문 page 1은 렌더된 문서가 아니라 `ProgressView`가 올라간 흰 페이지로 남아 있었다. 이는 `DocumentPageNSView.draw(_:)`가 실패한 상태가 아니라, `DocumentPageContainer`가 아직 `store.pageTrees[0]`을 받지 못한 placeholder 상태로 판단했다.

따라서 원인 가설을 다음처럼 정정했다.

- 부정확한 가설: 초기 `NSView` redraw 부족만으로 첫 페이지가 늦게 보인다.
- 정정한 가설: 첫 화면 후보 page tree 준비를 SwiftUI `LazyVStack.onAppear`에만 의존해 초기 표시 타이밍이 불안정하다.

## 변경 내용

`Sources/HostApp/Stores/DocumentViewerStore.swift`를 보강했다.

- `loadDocument(data:filename:)`에서 새 `RhwpDocument` 생성과 기본 상태 초기화 후 `preloadInitialPages()`를 호출한다.
- `preloadInitialPages()`는 문서가 열리면 page 0과 page 1 render tree를 즉시 준비한다.
- 1페이지 문서는 page 0만 선로딩하도록 `min(2, pageCount)`를 사용한다.
- `loadPage(_:)`에 `page >= 0, page < pageCount` guard를 추가해 잘못된 page index 요청을 무시한다.
- `DocumentPageContainer.onAppear`는 이후 스크롤로 진입하는 페이지의 보조 로드 경로로 유지한다.

이 보정은 첫 화면에 필요한 데이터 준비 책임을 SwiftUI lazy lifecycle에서 store의 문서 로드 완료 흐름으로 옮긴다.

## 검증 명령과 결과

```bash
git diff --check
```

결과: 통과

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: 통과 (`** BUILD SUCCEEDED **`)

비고: CoreSimulator 연결 및 provisioning profile 경고가 출력됐지만 macOS HostApp build는 성공했다.

```bash
./scripts/validate-stage3-render.sh /tmp/rhwp-stage5-render-task84
```

결과: 통과

| Sample | Page | Native size | TextRuns | HangulRuns | NonWhitePixels |
|--------|------|-------------|----------|------------|----------------|
| KTX.hwp | 1 | 1123x794 | 435 | 76 | 450455 |
| request.hwp | 1 | 567x794 | 104 | 36 | 54724 |
| exam_kor.hwp | 1 | 1123x1588 | 69 | 51 | 96464 |

```bash
./scripts/render-debug-compare.sh /tmp/rhwp-stage5-first-page-task84 --page 1 samples/hwp-multi-001.hwp samples/20250130-hongbo.hwp
```

결과: 통과

| Sample | PageCount | RenderTreeJSONBytes | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|--------|-----------|---------------------|----------------------|----------|------------|---------------------|
| hwp-multi-001.hwp | 9 | 468702 | 142561 | 277 | 113 | 0 |
| 20250130-hongbo.hwp | 4 | 92327 | 77596 | 58 | 33 | 0 |

```bash
./scripts/render-debug-compare.sh /tmp/rhwp-stage5-table-vpos-page1-task84 --page 1 /Users/melee/Documents/samples/table-vpos-01.hwp
./scripts/render-debug-compare.sh /tmp/rhwp-stage5-table-vpos-page2-task84 --page 2 /Users/melee/Documents/samples/table-vpos-01.hwp
```

결과: 통과

| Sample | Page | PageCount | RenderTreeJSONBytes | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|--------|------|-----------|---------------------|----------------------|----------|------------|---------------------|
| table-vpos-01.hwp | 1 | 5 | 143246 | 89133 | 90 | 45 | 0 |
| table-vpos-01.hwp | 2 | 5 | 92899 | 86141 | 67 | 38 | 0 |

## 범위 확인

- ThumbnailExtension cache 정책은 변경하지 않았다.
- Quick Look preview 경로는 변경하지 않았다.
- Rust core dependency와 renderer 품질 로직은 변경하지 않았다.
- 대규모 LRU/page cache 정책은 후속 설계 대상으로 남겼다.

## 잔여 리스크

자동 검증은 Viewer App의 실제 초기 화면 표시를 직접 캡처하지 않는다. 작업지시자가 동일 실행 경로로 `/Users/melee/Documents/samples/table-vpos-01.hwp`를 다시 열어 page 1/2가 첫 화면에서 즉시 표시되는지 확인해야 최종 완료 판정을 할 수 있다.

## 다음 단계

작업지시자의 실제 UI 재검증 결과를 확인한 뒤 Stage 6 최종 보고서와 오늘할일 상태 갱신을 진행한다.
