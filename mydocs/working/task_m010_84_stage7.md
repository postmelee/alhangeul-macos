# Issue #84 Stage 7 완료 보고서

## 단계 목적

첫 페이지 초기 로드 수정 이후 `복학원서.hwp`에서 page 오른쪽/아래 바깥으로 텍스트 일부가 새는 Viewer 렌더 회귀를 수정한다.

## 재현 분석

작업지시자가 첨부한 2026-04-29 09:21 스크린샷에서 `복학원서.hwp`의 오른쪽 아래에 page frame 바깥 텍스트가 표시됐다.

`samples/복학원서.hwp` page 1 render debug 결과:

- native PNG는 정상 크기 `794x1123` 안에 렌더됐다.
- render tree에는 page bbox 밖으로 나가는 node가 존재했다.
- `LAYOUT_OVERFLOW` 로그가 table, partial paragraph, shape에 대해 출력됐다.

따라서 core/native render data 자체가 오른쪽 아래로 잘못 확장된 문제라기보다, Viewer의 `DocumentPageNSView` drawing이 view bounds를 명시적으로 clip하지 않아 page frame 바깥에 표시된 문제로 판단했다.

## 변경 내용

`Sources/HostApp/Views/DocumentPageView.swift`를 보정했다.

- `DocumentPageNSView.configureLayer()`에서 `layerContentsRedrawPolicy = .onSetNeedsDisplay`를 제거했다.
- `DocumentPageNSView.setFrameSize(_:)` redraw override를 제거했다.
- `invalidateDrawing()`은 `needsDisplay = true`만 수행하도록 축소했다.
- `draw(_:)`에서 `context.clip(to: bounds)`를 먼저 적용한 뒤 page background fill과 render tree drawing을 수행한다.

유지한 내용:

- `DocumentViewerStore`의 page 0/1 초기 선로딩은 유지했다.
- `DocumentPageContainer.onDisappear` 즉시 unload 제거는 유지했다.
- `DocumentPageNSView`의 고정 layer 설정을 init 경로에 두는 구조는 유지했다.

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
./scripts/validate-stage3-render.sh /tmp/rhwp-stage7-render-task84
```

결과: 통과

| Sample | Page | Native size | TextRuns | HangulRuns | NonWhitePixels |
|--------|------|-------------|----------|------------|----------------|
| KTX.hwp | 1 | 1123x794 | 435 | 76 | 450455 |
| request.hwp | 1 | 567x794 | 104 | 36 | 54724 |
| exam_kor.hwp | 1 | 1123x1588 | 69 | 51 | 96464 |

```bash
./scripts/render-debug-compare.sh /tmp/rhwp-stage7-bokhak-task84 --page 1 samples/복학원서.hwp
```

결과: 통과

| Sample | Page | PageCount | RenderTreeJSONBytes | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|--------|------|-----------|---------------------|----------------------|----------|------------|---------------------|
| 복학원서.hwp | 1 | 1 | 189402 | 163193 | 102 | 25 | 0 |

```bash
./scripts/render-debug-compare.sh /tmp/rhwp-stage7-table-vpos-page1-task84 --page 1 /Users/melee/Documents/samples/table-vpos-01.hwp
./scripts/render-debug-compare.sh /tmp/rhwp-stage7-table-vpos-page2-task84 --page 2 /Users/melee/Documents/samples/table-vpos-01.hwp
```

결과: 통과

| Sample | Page | PageCount | RenderTreeJSONBytes | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|--------|------|-----------|---------------------|----------------------|----------|------------|---------------------|
| table-vpos-01.hwp | 1 | 5 | 143246 | 89133 | 90 | 45 | 0 |
| table-vpos-01.hwp | 2 | 5 | 92899 | 86141 | 67 | 38 | 0 |

## 잔여 리스크

자동 render debug는 native renderer 결과를 확인하지만, SwiftUI/AppKit Viewer 화면을 직접 캡처하지 않는다. `복학원서.hwp`의 page frame 바깥 텍스트가 사라졌는지는 작업지시자가 동일 앱 실행 경로로 실제 UI에서 재확인해야 한다.

## 다음 단계

작업지시자의 실제 UI 재검증 결과를 확인한 뒤 Stage 8 최종 보고서와 오늘할일 상태 갱신을 진행한다.
