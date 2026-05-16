# Task M050 #222 Stage 1 완료보고서

## 단계 목표

`samples/복학원서.hwp` 워터마크가 Quick Look/native preview에서 본문 위에 렌더되는 원인을 코드와 render tree 기준으로 확정하고, Stage 2에서 수정할 최소 범위를 정한다.

## 확인한 현재 구조

현재 Quick Look 단일 페이지 preview는 `HwpPageImageRenderer`가 `RhwpDocument.renderPageTree` 결과를 받아 `CGTreeRenderer`로 bitmap을 만든다. 따라서 이번 문제의 직접 책임 경로는 bundled rhwp-studio가 아니라 Swift native renderer다.

`RenderTree.swift`의 `ImageNode`는 다음 필드를 디코딩한다.

- `bin_data_id`
- `section_index`
- `para_index`
- `control_index`
- `fill_mode`
- `original_size`
- `original_size_hu`
- `effect`
- `brightness`
- `contrast`
- `transform`
- `crop`

render tree JSON에는 `text_wrap`이 포함되어 있으나 Swift 모델에는 아직 대응 필드가 없다. 이 때문에 renderer는 이미지가 본문 뒤 레이어인지, 본문 앞 레이어인지 구분할 수 없다.

`CGTreeRenderer.renderNode`는 page에서 흰 배경을 채운 뒤 `renderChildren`으로 top-level child를 순서대로 렌더한다. 이미지 노드는 `renderImage`를 즉시 호출하고, 일반 child 순회는 별도 z-order 해석 없이 JSON 순서만 따른다.

## 재현 샘플 render tree 관찰

기존 분석 산출물:

- `/private/tmp/rhwp-bokhak-watermark-analysis/복학원서-page1-render-tree.json`
- `/private/tmp/rhwp-bokhak-watermark-analysis/복학원서-page1-native.png`
- `/private/tmp/rhwp-bokhak-watermark-analysis/복학원서-page1-summary.txt`

page top-level child 순서는 다음과 같다.

| 순서 | id | node | 비고 |
|------|----|------|------|
| 0 | 1 | `PageBackground` | 페이지 배경 |
| 1 | 2 | `Header` | child 없음 |
| 2 | 3 | `Body` | 본문, 표, 텍스트 포함 |
| 3 | 84 | `Image` | 중앙 워터마크, `text_wrap: "BehindText"` |
| 4 | 237 | `Ellipse` | 하단 접수 도장 원 |
| 5 | 243 | `Footer` | child 없음 |

이미지 노드는 두 개다.

| id | 위치 | binDataId | text_wrap | effect | 판단 |
|----|------|-----------|-----------|--------|------|
| 7 | 좌상단 로고, body 내부 | 1 | `BehindText` | `RealPic` | 기존 body 순서 유지 대상 |
| 84 | 중앙 워터마크, page-level | 2 | `BehindText` | `GrayScale` | Stage 2 z-order 보정 대상 |

중앙 워터마크 id 84는 `Body` 다음 top-level sibling으로 배치되어 있다. 현재 renderer는 top-level 순서를 그대로 그리므로 body의 표와 텍스트를 먼저 그리고, 그 위에 워터마크 이미지를 덮어쓴다.

## 원인

원인은 두 가지가 겹친다.

1. Swift `ImageNode`가 `text_wrap`을 디코딩하지 않는다.
2. `CGTreeRenderer`가 page-level child 순서만 따르고 `BehindText` 의미를 z-order로 반영하지 않는다.

따라서 이 문제는 Quick Look UI/chrome 문제가 아니며, body clip이나 layout overflow 문제도 아니다. `BehindText` 속성을 가진 page-level 이미지가 본문 뒤 레이어로 재배치되지 않는 Swift native renderer parity gap이다.

## Stage 2 구현 경계

Stage 2는 다음 범위로 제한한다.

- `ImageNode`에 `textWrap` 필드를 추가해 `text_wrap` 문자열을 보존한다.
- renderer 내부에 `BehindText` 판정 helper를 둔다.
- page-level 렌더링에서 `PageBackground`를 먼저 그리고, top-level `BehindText` 이미지를 body/header/footer/foreground 일반 pass 전에 그린다.
- 일반 pass에서는 이미 앞 pass에서 그린 top-level `BehindText` 이미지를 건너뛰어 중복 렌더를 막는다.
- body 내부 이미지 id 7처럼 nested `BehindText` 이미지는 이번 1차 보정에서 구조 이동하지 않고 기존 parent 순서 안에 둔다.
- `GrayScale`, `brightness`, `contrast` 색상 parity는 upstream core 갱신 문제로 분리하고 이번 stage에서 수정하지 않는다.

## 검증

실행한 명령:

```bash
git diff --check -- mydocs/plans/task_m050_222_impl.md
jq '.children[] | {type:.node_type,id:.id,bbox:.bbox, children:(.children|length)}' /private/tmp/rhwp-bokhak-watermark-analysis/복학원서-page1-render-tree.json
jq '.. | objects | select(.node_type.Image?) | {id, bbox, image:.node_type.Image}' /private/tmp/rhwp-bokhak-watermark-analysis/복학원서-page1-render-tree.json
```

결과:

- 구현계획서 diff check 통과
- `복학원서.hwp` 중앙 워터마크가 page-level `Image` id 84이며 `text_wrap: "BehindText"`임을 확인
- 좌상단 로고 id 7도 `BehindText`지만 body 내부 이미지이므로 Stage 2에서 top-level pass만 보정하는 쪽이 안전하다고 판단

## 다음 단계

Stage 2에서 `RenderTree.swift`와 `CGTreeRenderer.swift`를 수정해 `BehindText` page-level 이미지 렌더 패스를 구현한다.
