# Task M050 #123 Stage 4 보고서

## 단계 목표

- `TableCell.clip`의 Swift native renderer 클립 정책을 rhwp-studio 기준과 맞춘다.
- 셀 내부 텍스트의 마지막 글리프가 우측 경계에서 잘리는 경우를 줄이되, 상하/좌측 클립 정책은 이번 단계에서 넓히지 않는다.

## 기준 확인

rhwp-studio `WebCanvasRenderer` 기준은 `TableCell` clip에 대해 다음 정책을 사용한다.

- clip 대상: `RenderNodeType::TableCell(ref tc) if tc.clip`
- clip rect: `node.bbox.x`, `node.bbox.y`, `node.bbox.width + 4.0`, `node.bbox.height`
- 의도: 셀 우측 여유를 두어 레이아웃 반올림 오차로 마지막 글리프가 잘리는 것을 방지

Swift 현행 구조는 `TableCellNode`의 `clip`, `row`, `col`, span, `modelCellIndex`, `bbox`를 이미 갖고 있다. 이번 단계의 우측 여유 폭 보정에는 추가 render tree 계약이 필요하지 않다.

## 변경 내용

### `Sources/RhwpCoreBridge/CGTreeRenderer.swift`

- `tableCellClipRightSlack = 4.0` 상수를 추가했다.
- `.tableCell` 분기를 `renderTableCell(_:node:in:)` helper로 분리했다.
- `cell.clip == true`일 때 기존 `cgRect(node.bbox)` 대신 `tableCellClipRect(for:)`를 사용한다.
- `tableCellClipRect(for:)`는 bbox의 x/y/height는 유지하고 width만 `bbox.width + 4.0`으로 보정한다.
- clip이 꺼진 셀은 기존처럼 children을 그대로 렌더링한다.

`RenderTree.swift` 변경은 하지 않았다. 현재 필요한 정보는 `TableCellNode.clip`과 node `bbox`만으로 충분하다.

## 범위에서 제외한 항목

- 셀 상단/하단 overflow는 확장하지 않았다.
- 셀 좌측 overflow도 확장하지 않았다.
- 표 border 자체의 geometry나 text run layout은 변경하지 않았다.
- Body clip 자체의 우측 `+4.0` 보정은 이번 Stage 4 범위가 아니므로 건드리지 않았다.

## 검증

### 정적 검증

```bash
git diff --check
./scripts/check-no-appkit.sh
```

결과:

- `git diff --check`: 통과
- `check-no-appkit.sh`: `OK: shared Swift code has no AppKit/UIKit dependencies`

### 대표 샘플 render-debug

```bash
./scripts/render-debug-compare.sh /private/tmp/rhwp-task123-stage4-bokhak samples/복학원서.hwp
```

결과:

- 통과
- 산출물:
  - RenderTree JSON: `/private/tmp/rhwp-task123-stage4-bokhak/복학원서-page1-render-tree.json`
  - Core SVG: `/private/tmp/rhwp-task123-stage4-bokhak/복학원서-page1-core.svg`
  - Native PNG: `/private/tmp/rhwp-task123-stage4-bokhak/복학원서-page1-native.png`
  - Summary: `/private/tmp/rhwp-task123-stage4-bokhak/복학원서-page1-summary.txt`
- 핵심 summary:
  - `PageSizePt`: `793.7x1122.5`
  - `RenderTreeJSONBytes`: `189498`
  - `CoreSVGBytes`: `380803`
  - `NativePNGSize`: `794x1123`
  - `NativeNonWhitePixels`: `261878`
  - `TextRuns`: `102`
  - `HangulRuns`: `25`
  - `HangulScalars`: `143`
  - `MissingHangulGlyphs`: `0`
- `qlmanage` 기반 Core SVG raster diff는 기존처럼 생성되지 않았다.
  - `DiffReason`: `qlmanage rasterize failed`
  - 이번 변경의 Swift 렌더 smoke 판정에는 영향을 주지 않는 환경성 제한으로 분리한다.
- 기존 core layout overflow 진단은 동일하게 출력되었다.
  - `LAYOUT_OVERFLOW_DRAW`
  - `LAYOUT_OVERFLOW`

### smoke 렌더 검증

```bash
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task123-stage4-smoke samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
```

결과:

- `KTX.hwp`: 통과
  - `size=1123x794`
  - `textRuns=436`
  - `hangulRuns=76`
  - `hangulScalars=209`
  - `nonWhitePixels=452179`
- `request.hwp`: 통과
  - `size=567x794`
  - `textRuns=104`
  - `hangulRuns=36`
  - `hangulScalars=309`
  - `nonWhitePixels=67667`
- `exam_kor.hwp`: 통과
  - `size=1123x1588`
  - `textRuns=133`
  - `hangulRuns=86`
  - `hangulScalars=1368`
  - `nonWhitePixels=182000`

`KTX.hwp`에서는 기존처럼 core layout overflow 진단이 출력되었다. Stage 4 변경은 셀 우측 클립 폭만 조정하므로 해당 진단은 별도 layout 문제로 유지한다.

## 남은 리스크

- 우측 `4.0pt` 여유 폭은 rhwp-studio와 동일한 상수지만, Core Graphics/Core Text의 실제 glyph rasterization 차이를 모든 표 샘플에서 증명한 것은 아니다.
- nested table이나 셀 내부 control이 body overflow replay와 함께 중복 drawing될 가능성은 Stage 3의 남은 리스크와 연결된다.
- render-debug summary에는 table cell clip 후보 수나 실제 clip rect 로그가 없다. 필요하면 후속 단계에서 디버그 요약을 확장할 수 있다.

## 다음 단계

Stage 5에서 `devel` 기준 통합 검증을 수행한다.

- `Sources/RhwpCoreBridge` 경계 검증 재실행
- 기본 render smoke와 대표 샘플 render-debug 재실행
- HostApp Debug build 확인
- Stage 1-4 source commit 범위와 `devel-webview` 선별 적용 대상 정리
