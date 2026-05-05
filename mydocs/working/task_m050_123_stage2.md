# Task #123 Stage 2 완료 보고서 - Body overflow replay 구조 추가

## 단계 목적

`CGTreeRenderer`에서 `Body.clip_rect` 내부 일반 렌더링과 body 좌우 overflow control replay를 분리한다. 이번 단계는 table cell clip 우측 여유 폭 보정은 하지 않고, body pass 정책과 replay 후보 분류 helper를 추가하는 범위다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | `renderBody` helper, body overflow replay pass, replay 후보 분류 helper, page bounds 저장 추가 |
| `mydocs/working/task_m050_123_stage2.md` | Stage 2 구현 결과와 검증 기록 |

변경 규모:

```text
Sources/RhwpCoreBridge/CGTreeRenderer.swift | 112 ++++++++++++++++++++++++++--
1 file changed, 104 insertions(+), 8 deletions(-)
```

`CGTreeRenderer.swift`는 1966줄에서 2062줄로 늘었다.

## 본문 변경 정도 / 본문 무손실 여부

문서 본문이나 샘플 파일은 변경하지 않았다. renderer source 1개와 단계 보고서만 변경했다.

## 구현 내용

### 1. Body 분기 helper 분리

기존 `.body` 분기의 inline clipping 로직을 `renderBody(_:node:in:)`로 분리했다.

동작은 다음 순서다.

1. `BodyNode.clipRect`가 없으면 기존처럼 children만 렌더링
2. `clipRect`가 있으면 body clip을 적용하고 기존 children 렌더링
3. body clip restore
4. body overflow replay 후보가 있으면 별도 pass 실행

### 2. page bounds 저장

`render(tree:in:pageHeight:document:)` 진입 시 root render tree의 bbox를 `pageBounds`에 저장했다.

이 값은 overflow replay pass의 좌우 clip 폭을 계산하는 데 사용한다. rhwp-studio의 `rect(0.0, body_clip.y, canvas_width, body_clip.height)`에 대응하는 Swift 기준이다.

### 3. overflow replay pass 추가

`renderBodyOverflowControls(_:bodyClip:in:)`를 추가했다.

- 후보가 없으면 아무 작업도 하지 않는다.
- 후보가 있으면 `bodyOverflowReplayClipRect(_:)`로 만든 clip을 적용한다.
- replay clip은 body의 `y`/`height`를 유지하고, x/width는 page root bbox 전체를 사용한다.
- 따라서 상하 overflow는 계속 제한하고 좌우 overflow만 허용한다.

### 4. replay 후보 분류 helper 추가

`bodyOverflowReplayCandidates(in:bodyClip:)`는 body children을 훑는다.

- `Column` child는 그 children을 검사한다.
- `Column`이 아닌 body direct child는 직접 후보 여부를 검사한다.
- 후보 조건은 `visible == true`, 텍스트 clip-bound node가 아님, bbox가 body left/right를 벗어남이다.

`isTextClipBoundNode(_:)`는 다음 node를 replay 대상에서 제외한다.

- `Page`, `PageBackground`, `MasterPage`
- `Header`, `Footer`, `Body`, `Column`, `FootnoteArea`
- `TextLine`, `TextRun`, `FootnoteMarker`
- `Unknown`

`Table`, `Rectangle`, `Line`, `Ellipse`, `Path`, `Image`, `Group`, `TextBox`, `Equation`, `FormObject`는 현재 단계에서 좌우 overflow 후보가 될 수 있다. group/table의 children 중복 렌더링과 z-order 영향은 Stage 3에서 다시 좁힌다.

## 검증 결과

검증 전에 새 worktree에 `Frameworks/` generated artifact가 없어 `validate-stage3-render.sh`가 다음 오류로 중단됐다.

```text
ERROR: missing /private/tmp/rhwp-mac-task123/Frameworks/universal/librhwp.a
Run: /private/tmp/rhwp-mac-task123/scripts/build-rust-macos.sh
```

메인 worktree의 기존 generated `Frameworks/`를 `/private/tmp/rhwp-mac-task123/Frameworks`로 복사해 검증을 진행했다. 이 디렉터리는 git ignored 상태이며 커밋 대상이 아니다.

```text
## local/task123...origin/devel [ahead 3]
!! Frameworks/
Frameworks ready
```

### `git status --short --branch`

```text
## local/task123...origin/devel [ahead 3]
 M Sources/RhwpCoreBridge/CGTreeRenderer.swift
```

### `git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift`

주요 변경:

```text
+    private var pageBounds: BBox?
+        self.pageBounds = tree.bbox

         case .body(let body):
-            if let clip = body.clipRect {
-                ctx.saveGState()
-                ctx.clip(to: cgRect(clip))
-                renderChildren(node, in: ctx)
-                ctx.restoreGState()
-            } else {
-                renderChildren(node, in: ctx)
-            }
+            renderBody(body, node: node, in: ctx)
```

### `./scripts/check-no-appkit.sh`

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### `./scripts/validate-stage3-render.sh /private/tmp/rhwp-task123-stage2-smoke samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp`

```text
LAYOUT_OVERFLOW_DRAW: section=0 pi=28 line=0 y=768.5 col_bottom=755.9 overflow=12.5px
LAYOUT_OVERFLOW: page=0, col=0, para=28, type=PartialParagraph, y=776.5, bottom=755.9 overflow=20.5px
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452089 png=/private/tmp/rhwp-task123-stage2-smoke/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=67667 png=/private/tmp/rhwp-task123-stage2-smoke/request-page1.png
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=182000 png=/private/tmp/rhwp-task123-stage2-smoke/exam_kor-page1.png
```

`KTX.hwp`의 layout overflow diagnostic은 기존 계열 출력으로 보며, 명령은 통과했다.

### `./scripts/render-debug-compare.sh /private/tmp/rhwp-task123-stage2-bokhak samples/복학원서.hwp`

```text
LAYOUT_OVERFLOW_DRAW: section=0 pi=16 line=1 y=1326.6 col_bottom=1084.7 overflow=241.9px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=PartialParagraph, y=1336.2, bottom=1084.7 overflow=251.5px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Shape, y=1336.2, bottom=1084.7 overflow=251.5px
OK 복학원서.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task123-stage2-bokhak/복학원서-page1-render-tree.json coreSVG=/private/tmp/rhwp-task123-stage2-bokhak/복학원서-page1-core.svg nativePNG=/private/tmp/rhwp-task123-stage2-bokhak/복학원서-page1-native.png summary=/private/tmp/rhwp-task123-stage2-bokhak/복학원서-page1-summary.txt
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
DiffReason: qlmanage rasterize failed; see /private/tmp/rhwp-task123-stage2-bokhak/복학원서-page1-core.svg.qlmanage.log
```

`복학원서.hwp`의 하단 layout overflow diagnostic은 #90에서 분리한 core layout 계열 이슈로 남아 있다. 이번 Stage 2의 body 좌우 overflow replay 구조 추가와 직접 충돌하지 않는다.

### `git diff --check`

```text
통과
```

## 잔여 위험

- 현재 replay는 body clip 안에서 이미 그린 후보를 body clip 밖 pass에서 다시 그리므로, 반투명 shape나 복합 group은 중복 drawing으로 진해질 수 있다. Stage 3에서 node type별 replay 정책과 중복 위험을 좁힌다.
- replay 후보가 `Column` 직계 child에 있을 때를 기본으로 처리한다. 더 깊은 구조의 overflow control이 있으면 Stage 3에서 재귀 탐색 여부를 판단한다.
- `TableCell.clip` 우측 여유 폭은 아직 적용하지 않았다. Stage 4에서 별도 보정한다.
- `FormObject`는 현재 renderer에서 실제 drawing이 없으므로 replay 후보여도 표시 변화가 없을 수 있다.

## 다음 단계 영향

Stage 3에서는 이번 단계에서 넓게 열어 둔 replay 후보를 node type별로 보강한다.

확인할 항목:

- `table`, `group`, `textBox`처럼 구조 노드인 후보가 중복 렌더링을 만드는지
- `rectangle`, `line`, `ellipse`, `path`, `image`, `equation`처럼 자체 drawing이 있는 node의 children 순회 영향
- `pageBackground`, `header`, `footer`, `footnoteArea`, text 계열 제외 정책이 충분한지
- 필요 시 render-debug summary에 replay 후보 진단을 추가할지

## 승인 요청

Stage 2 완료를 승인 요청한다. 승인 후 Stage 3 `control node replay 정확도 보강`으로 진행한다.
