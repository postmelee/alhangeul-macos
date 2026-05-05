# Task #123 Stage 1 완료 보고서 - body overflow 기준 조사

## 단계 목적

rhwp-studio의 body/table clipping 기준과 Swift native renderer의 현행 clip 구조를 비교해, Stage 2에서 구현할 body overflow replay 범위를 확정한다.

이번 단계는 source code를 변경하지 않고 기준 조사와 적용 전략만 정리했다.

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/working/task_m050_123_stage1.md` | Stage 1 조사 결과와 Stage 2 구현 범위 |

참고로 조사한 주요 source 규모:

| 파일 | 라인 수 |
|------|---------|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | 1966 |
| `Sources/RhwpCoreBridge/RenderTree.swift` | 702 |
| `mydocs/plans/task_m050_123_impl.md` | 344 |

## 본문 변경 정도 / 본문 무손실 여부

문서 렌더링 source, 매뉴얼, 샘플 파일은 변경하지 않았다. 신규 단계 보고서만 추가했다.

## 조사 결과

### 1. rhwp-studio reference 확인

로컬 Cargo checkout에서 읽을 수 있는 rhwp source는 다음 경로와 commit이었다.

```text
/Users/melee/.cargo/git/checkouts/rhwp-8c9e2c2358fab379/1e9d78a
commit 1e9d78a1d40c71779d81c6ec6870cd301d912626
```

현재 앱 저장소의 `RustBridge/Cargo.lock`은 `rhwp v0.7.9` resolved commit `0fb3e6758b8ad11d2f3c3849c83b914684e83863`를 가리킨다. 이 commit object는 로컬 checkout에 없어 직접 `git show`로 읽지 못했다. 따라서 이번 단계의 rhwp-studio source 구조 확인은 로컬에 존재하는 `1e9d78a` checkout 기준이며, Stage 2 구현 전에는 앱 저장소의 Swift renderer 구조와 이슈 #123에 명시된 정책을 우선한다.

`src/renderer/web_canvas.rs` 기준 핵심 동작:

- `Body { clip_rect }`는 body clip을 적용할 때 `cr.width + 4.0`으로 우측 여유를 둔다.
- `TableCell.clip`도 셀 bbox width에 `+ 4.0` 우측 여유를 둔다.
- children 렌더링이 끝난 뒤 body clip을 restore하고 `render_overflow_controls(node, cr)`를 호출한다.
- `render_overflow_controls`는 body clip의 좌우 경계를 벗어나는 child control만 다시 렌더링한다.
- replay pass는 `rect(0.0, body_clip.y, canvas_width, body_clip.height)`로 상하만 body 영역에 묶고 좌우는 전체 폭을 허용한다.
- `is_overflow_control`은 `TextLine`, `Column`, `FootnoteArea`, `Header`, `Footer`, `MasterPage`, `Page`, `Body`를 제외하고, bbox가 body left/right를 넘는지로 판정한다.

이 구조는 이번 이슈의 핵심 정책과 일치한다. 텍스트는 body clip 안에 남기고, 좌우 여백 밖 control은 별도 pass에서 다시 그린다. 상하 overflow는 여전히 body 높이로 제한한다.

### 2. Swift 현행 구조

`CGTreeRenderer.renderNode`의 현행 clip 구조:

- `.body`: `BodyNode.clipRect`가 있으면 `ctx.clip(to: cgRect(clip))` 후 모든 children을 한 번에 렌더링한다.
- `.tableCell`: `cell.clip`이 true이면 `ctx.clip(to: cgRect(node.bbox))` 후 children을 렌더링한다.
- body restore 이후 overflow replay pass가 없다.
- table cell clip에는 rhwp-studio의 우측 `+4.0` 여유에 대응하는 보정이 없다.
- `rectangle`, `line`, `ellipse`, `path`, `image`는 자기 자신을 그린 뒤 children을 순회한다.
- `group`은 자체 drawing 없이 `renderChildren`만 수행한다.
- `textRun`, `footnoteMarker`는 직접 텍스트를 그리며 body overflow replay 대상에서 제외해야 한다.

`RenderTree.swift`에서 Swift가 사용할 수 있는 필드:

- `BodyNode.clipRect`
- `TableNode.rowCount`, `colCount`, `borderFillId`, `sectionIndex`, `paraIndex`, `controlIndex`
- `TableCellNode.col`, `row`, span, `borderFillId`, `textDirection`, `clip`, `modelCellIndex`
- `GroupNode.sectionIndex`, `paraIndex`, `controlIndex`
- node 공통 `bbox`, `children`, `visible`

별도 `ClipKind` 필드는 Swift render tree JSON에 없다. Swift 구현은 node type, bbox, parent/child 구조, table/group metadata만으로 replay 여부를 판단해야 한다.

### 3. devel / devel-webview 차이

`origin/devel...origin/devel-webview`에서 `Sources/RhwpCoreBridge/CGTreeRenderer.swift` 차이는 body/table clipping이 아니라 font 경로다.

- `render(...)` 시작 시 `HwpBundledFontRegistry.ensureRegistered()`가 추가됐다.
- `makeTextRunFont`와 footnote marker font 생성이 `resolveAppleFont(...)` 경로로 바뀌었다.
- `.body`와 `.tableCell` 분기 자체는 양쪽 모두 같은 단순 clip 구조다.

따라서 #123의 source 변경은 `devel`에서 먼저 구현한 뒤 `devel-webview`에 선별 적용할 수 있다. 다만 Stage 6 cherry-pick 시 `devel-webview`의 font registration/resolver 변경을 보존해야 한다.

### 4. Stage 2 구현 범위 확정

Stage 2에서는 body overflow replay 구조만 먼저 추가한다.

구현 후보:

- `.body` 분기를 `renderBody(_:node:in:)` helper로 분리
- body clip 내부 pass는 기존처럼 유지
- body restore 후 좌우 overflow control 후보를 별도 pass에서 다시 렌더링
- replay pass clip은 rhwp-studio처럼 `x = 0`, `width = page/canvas width`, `y = bodyClip.y`, `height = bodyClip.height` 계열로 둠
- page/canvas width는 Swift renderer가 보유한 `pageHeight`만으로는 부족하므로, Stage 2에서 page root bbox 또는 render context helper를 검토
- 상하 overflow는 이번 replay 대상에서 제외

Stage 2에서 제외하거나 보류할 항목:

- `TableCell.clip` 우측 여유 `+4.0` 보정은 Stage 4로 분리
- render tree 계약 확장은 Stage 2 기본 범위에서 제외
- header/footer/footnote 영역 replay 제외
- `TextRun`, `TextLine`, `FootnoteMarker` replay 제외

Stage 3에서 다시 볼 항목:

- `table`, `group`, `textBox`처럼 자체 drawing 없이 children을 순회하는 구조 노드의 replay 중복 문제
- `rectangle`, `line`, `ellipse`, `path`, `image`, `equation`처럼 자체 drawing이 있는 node의 children 순회 중복 문제
- replay 후보가 column 직계 child가 아닌 더 깊은 곳에 있는 경우를 얼마나 추적할지

## 검증 결과

### `git status --short --branch`

```text
## local/task123...origin/devel [ahead 2]
```

### `rg -n "render_overflow_controls|ClipKind|WebCanvasRenderer|Body\\(|TableCell" .`

주요 결과:

```text
Sources/RhwpCoreBridge/RenderTree.swift:50:    case tableCell(TableCellNode)
Sources/RhwpCoreBridge/RenderTree.swift:86:        if let v = try? keyed.decode(TableCellNode.self, forKey: .init("TableCell")) { self = .tableCell(v); return }
Sources/RhwpCoreBridge/RenderTree.swift:205:struct TableCellNode: Decodable {
mydocs/report/task_m015_120_report.md:40:사용자가 이슈에 추가한 구현 기준에 따라 rhwp-studio의 현재 렌더 결과와 `WebCanvasRenderer`/view 계층을 reference implementation으로 보았다.
mydocs/report/task_m010_90_report.md:118:`RenderTree.swift`는 `Body.clipRect`와 `TableCellNode.clip`을 디코딩하고, `CGTreeRenderer.swift`는 두 clip을 적용한다.
mydocs/plans/task_m050_123_impl.md:35:- rhwp-studio의 `WebCanvasRenderer.render_overflow_controls`, `ClipKind::Body`, `ClipKind::TableCell` 동작을 기준으로 정리한다.
```

앱 저장소 내부에는 rhwp-studio Rust source가 포함되어 있지 않아, `render_overflow_controls` 실제 구현은 Cargo checkout에서 별도 확인했다.

### `git diff --unified=80 origin/devel...origin/devel-webview -- Sources/RhwpCoreBridge/CGTreeRenderer.swift`

주요 결과:

```text
+        HwpBundledFontRegistry.ensureRegistered()

-        let appleName = mapHWPFontToApple(style.fontFamily)
-        var font = CTFontCreateWithName(appleName as CFString, fontSize, nil)
+        var font = resolveAppleFont(
+            hwpFontFamily: style.fontFamily,
+            bold: style.bold,
+            italic: style.italic,
+            size: fontSize
+        )
```

body/table clip 분기는 양쪽 모두 동일한 구조로 남아 있다.

### `rg -n "case \\.body|case \\.tableCell|case \\.rectangle|case \\.image|case \\.group|case \\.textRun" Sources/RhwpCoreBridge/CGTreeRenderer.swift`

```text
63:        case .body(let body):
73:        case .tableCell(let cell):
83:        case .rectangle(let rect):
99:        case .image(let img):
103:        case .group:
106:        case .textRun(let run):
708:        if case .group = node.nodeType {
```

### `rg -n "enum RenderNodeType|struct BodyNode|struct TableCellNode|struct TableNode|struct GroupNode" Sources/RhwpCoreBridge/RenderTree.swift`

```text
38:enum RenderNodeType: Decodable {
129:struct BodyNode: Decodable {
187:struct TableNode: Decodable {
205:struct TableCellNode: Decodable {
325:struct GroupNode: Decodable {
```

### `git diff --check`

```text
통과
```

## 잔여 위험

- 로컬에서 직접 확인한 rhwp source가 현재 lock의 v0.7.9 commit이 아니라 `1e9d78a` checkout이다. 구현은 이슈 #123에 명시된 정책과 Swift 현행 구조 기준으로 진행하되, 필요하면 Stage 2 이후 실제 산출물 비교로 보정한다.
- Swift render tree에는 `ClipKind`가 없으므로 rhwp-studio의 clip enum을 1:1로 이식할 수 없다.
- replay pass의 page/canvas width 산정은 Stage 2에서 별도 설계가 필요하다.
- `group`/`table` replay는 children 중복 drawing과 z-order 변화 위험이 있다.

## 다음 단계 영향

Stage 2는 `CGTreeRenderer.swift`에 body overflow replay 구조를 추가한다. 우선 범위는 body 좌우 overflow control이며, `TableCell.clip` 우측 여유 폭은 Stage 4로 유지한다.

Stage 2의 구현 기준:

- body clip 내부 기존 렌더링 유지
- body clip restore 이후 replay pass 추가
- replay 후보에서 텍스트 계열 제외
- 상하 body overflow 제외
- AppKit/UIKit 직접 의존 추가 금지

## 승인 요청

Stage 1 완료를 승인 요청한다. 승인 후 Stage 2 `Body overflow control 분류 helper와 replay 구조 추가`로 진행한다.
