# Task M015 #108 Stage 2 완료 보고서

## 단계 목적

`CGTreeRenderer`가 도형/이미지 노드를 그린 뒤 children을 계속 렌더하도록 보강했다.

이번 단계의 목표 순서는 core PageLayerTree builder와 같은 own node draw 후 children draw다.

## 산출물

변경 파일:

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `mydocs/working/task_m015_108_stage2.md`

코드 변경 규모:

```text
Sources/RhwpCoreBridge/CGTreeRenderer.swift | 5 +++++
```

핵심 변경 위치:

```text
79  case .rectangle(let rect):
80      renderRectangle(rect, bbox: node.bbox, in: ctx)
81      renderChildren(node, in: ctx)

83  case .line(let line):
84      renderLine(line, bbox: node.bbox, in: ctx)
85      renderChildren(node, in: ctx)

87  case .ellipse(let ell):
88      renderEllipse(ell, bbox: node.bbox, in: ctx)
89      renderChildren(node, in: ctx)

91  case .path(let path):
92      renderPath(path, bbox: node.bbox, in: ctx)
93      renderChildren(node, in: ctx)

95  case .image(let img):
96      renderImage(img, bbox: node.bbox, in: ctx)
97      renderChildren(node, in: ctx)
```

## 본문 변경 정도 / 본문 무손실 여부

문서 본문 변경은 없다.

Swift renderer의 순회 정책만 변경했다. `RenderTree.swift` 모델, Rust bridge, core dependency, sample 파일은 변경하지 않았다.

## 변경 내용

다음 node type에서 자기 자신을 렌더한 뒤 `renderChildren(node, in: ctx)`를 호출하도록 변경했다.

- `Rectangle`
- `Line`
- `Ellipse`
- `Path`
- `Image`

기존 동작 유지 사항:

- `Page`, `Body`, `TableCell`, `Group`, default 구조 노드 순회 방식은 변경하지 않았다.
- `Body.clipRect`와 `TableCell.clip` 처리 위치는 유지했다.
- `TextRun`, `FootnoteMarker`, `Equation`, `FormObject` 렌더링 범위는 넓히지 않았다.
- 이미지 `crop/effect/brightness/contrast`는 #106 범위로 남겼고 이번 변경에 포함하지 않았다.

## 검증 결과

검증 명령:

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift
./scripts/check-no-appkit.sh
git diff --check -- Sources/RhwpCoreBridge/CGTreeRenderer.swift mydocs/working/task_m015_108_stage2.md
```

핵심 출력:

```text
## local/task108
 M Sources/RhwpCoreBridge/CGTreeRenderer.swift
```

```diff
 case .rectangle(let rect):
     renderRectangle(rect, bbox: node.bbox, in: ctx)
+    renderChildren(node, in: ctx)

 case .line(let line):
     renderLine(line, bbox: node.bbox, in: ctx)
+    renderChildren(node, in: ctx)

 case .ellipse(let ell):
     renderEllipse(ell, bbox: node.bbox, in: ctx)
+    renderChildren(node, in: ctx)

 case .path(let path):
     renderPath(path, bbox: node.bbox, in: ctx)
+    renderChildren(node, in: ctx)

 case .image(let img):
     renderImage(img, bbox: node.bbox, in: ctx)
+    renderChildren(node, in: ctx)
```

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

`git diff --check`는 오류 없이 통과했다.

## 잔여 위험

- Stage 2는 코드 구조 검증까지만 수행했다. 실제 `BookReview.hwp` 텍스트 표시 개선 여부는 Stage 3 render smoke에서 확인해야 한다.
- 도형 내부 clipping 일반화는 적용하지 않았다. 도형 경계 밖 children이 있는 문서에서는 core SVG와 차이가 남을 수 있다.
- `Image` children도 순회 대상에 포함했으므로, 이미지 위에 배치된 children이 있는 샘플은 Stage 3 이후 smoke에서 draw order를 확인해야 한다.

## 다음 단계 영향

Stage 3에서는 변경 후 `samples/basic/BookReview.hwp`를 `render-debug-compare.sh`로 다시 렌더링하고, native PNG에서 텍스트가 표시되는지 확인한다.

Stage 1의 기준 산출물과 Stage 3 산출물을 비교해 `TextRun`이 실제 native renderer 출력에 반영됐는지 기록한다.

## 승인 요청

Stage 2 코드 보강과 기본 검증을 완료했다.

Stage 3 `BookReview.hwp` render smoke 검증으로 진행할지 승인 요청한다.
