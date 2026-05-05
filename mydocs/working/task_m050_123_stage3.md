# Task #123 Stage 3 완료 보고서 - control replay 대상 보강

## 단계 목적

Stage 2에서 추가한 body overflow replay 후보 분류를 node type 기준으로 더 명확히 좁힌다. 목표는 text/일반 구조 node가 우연히 replay되는 일을 막고, 실제 control 후보만 body 좌우 overflow replay 대상으로 남기는 것이다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | replay 제외 목록 기반 분류를 명시적인 control whitelist 기반 분류로 변경 |
| `mydocs/working/task_m050_123_stage3.md` | Stage 3 구현 결과와 검증 기록 |

변경 규모:

```text
Sources/RhwpCoreBridge/CGTreeRenderer.swift | 26 ++++++++++++--------------
1 file changed, 12 insertions(+), 14 deletions(-)
```

## 본문 변경 정도 / 본문 무손실 여부

문서 본문이나 샘플 파일은 변경하지 않았다. renderer source 1개와 단계 보고서만 변경했다.

## 구현 내용

### 1. replay 후보 분류를 whitelist로 전환

Stage 2의 `isTextClipBoundNode(_:)`는 replay에서 제외할 node를 나열하는 방식이었다. Stage 3에서는 이를 `isBodyOverflowControlNode(_:)`로 바꾸고, replay 가능한 control node만 명시한다.

replay 후보 조건은 다음과 같다.

1. `node.visible == true`
2. `isBodyOverflowControlNode(node) == true`
3. node bbox가 body clip의 좌우 경계를 벗어남

### 2. node type별 정책

| node type | Stage 3 정책 | 이유 |
|-----------|--------------|------|
| `Table` | replay 후보 | body 좌우를 벗어나는 표 control 표시 필요 |
| `Line`, `Rectangle`, `Ellipse`, `Path` | replay 후보 | 도형 control 표시 필요 |
| `Image` | replay 후보 | 그림 control 표시 필요 |
| `Group` | replay 후보 | 묶음 개체는 children을 포함한 control로 취급 |
| `TextBox` | replay 후보 | 글상자는 자체 구조 node지만 control로 취급 |
| `Equation` | replay 후보 | 수식 control은 native drawing 경로가 있음 |
| `FormObject` | replay 후보 | 현재 drawing은 없지만 control 계열로 분류 유지 |
| `Page`, `PageBackground`, `MasterPage` | 제외 | page/root 구조나 배경은 body overflow replay 대상이 아님 |
| `Header`, `Footer`, `FootnoteArea` | 제외 | 본문 body overflow 정책과 별도 영역 |
| `Body`, `Column` | 제외 | 구조 node 자체는 replay하지 않음 |
| `TextLine`, `TextRun`, `FootnoteMarker` | 제외 | 텍스트는 body clip 안에 유지해야 함 |
| `TableCell` | 제외 | 셀 단독 replay는 table 구조와 clip 정책을 깨뜨릴 수 있음 |
| `Unknown` | 제외 | 알 수 없는 node를 clip 바깥으로 다시 그리지 않음 |

### 3. 중복 렌더링 리스크 축소 범위

Stage 3는 후보 타입을 명시해 구조 node가 우연히 replay되는 위험을 줄였다. 다만 `Table`, `Group`, `TextBox`를 replay하면 그 children도 다시 그려질 수 있다. 이 동작은 rhwp-studio의 control 단위 replay와 방향이 같지만, 반투명 도형이나 복합 group에서는 body clip 안쪽과 replay pass가 겹치는 영역이 진해질 수 있다.

이번 단계에서는 render-debug summary 확장을 하지 않았다. 현재 검증 샘플에서는 기존 summary와 smoke가 Stage 2와 같은 수준으로 통과했고, replay 후보 진단을 저장소 script에 추가할 필요성은 아직 확정되지 않았다.

## 검증 결과

### `git status --short --branch`

```text
## local/task123...origin/devel [ahead 4]
 M Sources/RhwpCoreBridge/CGTreeRenderer.swift
```

### `./scripts/check-no-appkit.sh`

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### `./scripts/render-debug-compare.sh /private/tmp/rhwp-task123-stage3-bokhak samples/복학원서.hwp`

```text
LAYOUT_OVERFLOW_DRAW: section=0 pi=16 line=1 y=1326.6 col_bottom=1084.7 overflow=241.9px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=PartialParagraph, y=1336.2, bottom=1084.7, overflow=251.5px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Shape, y=1336.2, bottom=1084.7, overflow=251.5px
OK 복학원서.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task123-stage3-bokhak/복학원서-page1-render-tree.json coreSVG=/private/tmp/rhwp-task123-stage3-bokhak/복학원서-page1-core.svg nativePNG=/private/tmp/rhwp-task123-stage3-bokhak/복학원서-page1-native.png summary=/private/tmp/rhwp-task123-stage3-bokhak/복학원서-page1-summary.txt
```

summary 핵심값:

```text
PageSizePt: 793.7x1122.5
RenderTreeJSONBytes: 189498
CoreSVGBytes: 380803
NativePNGSize: 794x1123
NativeNonWhitePixels: 261878
TextRuns: 102
HangulRuns: 25
HangulScalars: 143
MissingHangulGlyphs: 0
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task123-stage3-bokhak/복학원서-page1-core.svg.qlmanage.log
```

`복학원서.hwp`의 하단 layout overflow diagnostic은 Stage 2와 동일하게 출력됐고, render-debug 명령은 통과했다.

### `./scripts/validate-stage3-render.sh /private/tmp/rhwp-task123-stage3-smoke samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp`

```text
LAYOUT_OVERFLOW_DRAW: section=0 pi=28 line=0 y=768.5 col_bottom=755.9 overflow=12.5px
LAYOUT_OVERFLOW: page=0, col=0, para=28, type=PartialParagraph, y=776.5, bottom=755.9, overflow=20.5px
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452089 png=/private/tmp/rhwp-task123-stage3-smoke/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=67667 png=/private/tmp/rhwp-task123-stage3-smoke/request-page1.png
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=182000 png=/private/tmp/rhwp-task123-stage3-smoke/exam_kor-page1.png
```

`KTX.hwp`의 layout overflow diagnostic은 기존 계열 출력으로 보고, 명령은 통과했다.

### `test -s /private/tmp/rhwp-task123-stage3-bokhak/복학원서-page1-summary.txt`

```text
통과
```

### `git diff --check`

```text
통과
```

## 잔여 위험

- `Table`, `Group`, `TextBox`는 control 단위 replay 과정에서 children도 다시 그리므로 겹치는 영역의 중복 drawing 가능성이 남아 있다.
- 현재 후보 탐색은 body의 `Column` 직계 children 또는 body direct child 기준이다. 더 깊은 구조의 control bbox만 body 좌우를 넘는 경우는 후속 검토가 필요할 수 있다.
- `FormObject`는 현재 renderer에서 실제 drawing이 없어 replay 후보여도 표시 변화가 없다.
- render-debug summary에 replay 후보 수를 기록하지 않았으므로, replay 발생 여부는 현재 code path와 산출물 비교로 추적해야 한다.

## 다음 단계 영향

Stage 4에서는 `TableCell.clip` 우측 여유 폭 보강 여부를 검토한다. Stage 3에서 `TableCell`을 body overflow replay 후보에서 제외했으므로, 셀 내부 clipping 정책은 Stage 4의 `tableCellClipRect` 같은 별도 helper로 다루는 편이 안전하다.

## 승인 요청

Stage 3 완료를 승인 요청한다. 승인 후 Stage 4 `TableCell clip 우측 여유 폭 보강`으로 진행한다.
