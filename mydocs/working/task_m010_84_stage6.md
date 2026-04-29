# Issue #84 Stage 6 완료 보고서

## 단계 목적

Stage 5 실제 UI 재검증으로 첫 페이지 초기 표시 문제의 핵심 해결책이 `DocumentViewerStore`의 초기 page tree 선로딩임이 확인됐다. 초기 가설에서 도입한 `DocumentPageNSView` window attach redraw 보정 중 원인 해결에 필수적이지 않은 부분을 제거한다.

## 변경 내용

`Sources/HostApp/Views/DocumentPageView.swift`에서 `DocumentPageNSView.viewDidMoveToWindow()` override를 제거했다.

제거한 동작:

- window attach 시점 즉시 `invalidateDrawing()` 호출
- 다음 main runloop에서 추가 `invalidateDrawing()` 호출

유지한 동작:

- `DocumentPageNSView`의 고정 layer 설정은 `init` 경로에서 수행한다.
- `configure(...)`는 render tree/page size/zoom/document 갱신 후 redraw를 요청한다.
- `setFrameSize(_:)`는 frame size 변경 시 redraw를 요청한다.
- `DocumentViewerStore`의 page 0/1 초기 선로딩은 유지한다.

## 판단 근거

작업지시자의 재검증에서 Stage 5 선로딩 보정 후 초기 표시 문제가 해소됐다. 반면 Stage 3의 window attach redraw 보정만으로는 첨부 영상에서 page 1/2가 `ProgressView` 상태로 남았다. 따라서 window attach redraw는 실제 원인 해결에 필수적이지 않고, 추측성 lifecycle 보정에 해당한다고 판단했다.

`configure(...)`와 frame size 변경 redraw는 일반적인 `NSView` drawing 갱신 경로에 가까워 유지했다. 문서 변경, zoom 변경, SwiftUI frame 갱신 시 drawing input이 바뀌면 view가 다시 그려져야 하기 때문이다.

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
./scripts/render-debug-compare.sh /tmp/rhwp-stage6-table-vpos-page1-task84 --page 1 /Users/melee/Documents/samples/table-vpos-01.hwp
./scripts/render-debug-compare.sh /tmp/rhwp-stage6-table-vpos-page2-task84 --page 2 /Users/melee/Documents/samples/table-vpos-01.hwp
```

결과: 통과

| Sample | Page | PageCount | RenderTreeJSONBytes | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|--------|------|-----------|---------------------|----------------------|----------|------------|---------------------|
| table-vpos-01.hwp | 1 | 5 | 143246 | 89133 | 90 | 45 | 0 |
| table-vpos-01.hwp | 2 | 5 | 92899 | 86141 | 67 | 38 | 0 |

## 후속 이슈 권고

이번 수정은 첫 화면 표시 안정성을 우선한 correctness 수정이다. 즉시 unload 제거와 page tree 선로딩으로 문서가 열려 있는 동안 render tree가 더 오래 유지될 수 있으므로, 큰 문서 메모리 관리는 별도 후속 이슈로 분리하는 것이 적절하다.

후속 이슈 권장 범위:

- Viewer page tree cache 정책 설계
- 현재 페이지와 주변 page window 유지
- LRU 또는 거리 기반 eviction
- 현재 visible page 즉시 제거 금지
- 큰 문서 스크롤 시 메모리 사용량 측정

## 다음 단계

Stage 7에서 최종 보고서 작성, 오늘할일 상태 갱신, 잔여 리스크 정리를 수행한다.
