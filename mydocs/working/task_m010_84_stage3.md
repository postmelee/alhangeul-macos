# Issue #84 Stage 3 완료 보고서

## 단계 목적

`table-vpos-01.hwp`처럼 page 1/2 render tree와 native PNG는 정상 생성되지만 실제 Viewer 초기 화면에서 상단 페이지 drawing이 늦게 나타나는 경로를 보정한다.

## 추가 재현 분석

작업지시자가 `/Users/melee/Documents/samples/table-vpos-01.hwp`로 직접 테스트한 결과, 첫 번째와 두 번째 페이지가 초기 화면에서 보이지 않고 스크롤 후 늦게 표시됐다.

해당 파일의 page 1/2 render data를 확인했다.

| Page | PageCount | RenderTreeJSONBytes | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|------|-----------|---------------------|----------------------|----------|------------|---------------------|
| 1 | 5 | 143246 | 89133 | 90 | 45 | 0 |
| 2 | 5 | 92899 | 86141 | 67 | 38 | 0 |

`renderPageTree(at:)` 시간도 page 1 약 0.006초, page 2 약 0.005초 수준이었다. 따라서 남은 문제는 render tree 생성 지연이나 thumbnail cache 재사용이 아니라, `NSViewRepresentable`로 만든 `DocumentPageNSView`가 초기 frame/window attach 이후 drawing invalidation을 충분히 받지 못하는 문제로 판단했다.

## 변경 내용

`Sources/HostApp/Views/DocumentPageView.swift`의 `DocumentPageNSView`를 보강했다.

- `wantsLayer`, `layerContentsRedrawPolicy`, layer background 같은 고정 view 설정은 `DocumentPageNSView` 초기화 경로로 분리했다.
- drawing invalidation을 `invalidateDrawing()` helper로 분리했다.
- `configure(...)`에서 `needsDisplay`와 `layer?.setNeedsDisplay()`를 함께 요청한다.
- `setFrameSize(_:)`에서 frame size가 바뀌면 redraw를 요청한다.
- `viewDidMoveToWindow()`에서 window attach 시점에 즉시 redraw를 요청하고, 다음 main runloop에서도 한 번 더 redraw를 요청한다.

이 보정은 SwiftUI가 `NSView`를 먼저 만들고 실제 크기 또는 window 연결을 뒤늦게 확정하는 경우, 초기 dirty request가 빈 frame 또는 미연결 view 상태에서 소비되는 위험을 줄인다.

## 범위 확인

- `CGTreeRenderer`, `RenderTree`, `RhwpDocument`는 변경하지 않았다.
- ThumbnailExtension cache 정책은 변경하지 않았다.
- Quick Look preview 경로는 변경하지 않았다.
- Stage 1의 `onDisappear` 즉시 unload 제거는 유지했다.

## 검증

```bash
git diff --check
```

결과: 통과

```bash
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
```

결과: 통과 (`** BUILD SUCCEEDED **`)

소스 diff 확인:

- 변경은 `DocumentPageNSView` lifecycle redraw 보정에 한정됐다.

## 잔여 리스크

실제 초기 표시 여부는 SwiftUI/AppKit lifecycle과 창 크기에 영향을 받으므로 자동 render debug만으로 완전히 증명하기 어렵다. Stage 4에서 build와 render debug를 다시 수행하고, 작업지시자의 실제 앱 테스트 결과를 최종 보고서에 반영한다.

## 다음 단계

Stage 4에서 HostApp Debug build와 `table-vpos-01.hwp` page 1/2 포함 render debug 검증을 수행한다.
