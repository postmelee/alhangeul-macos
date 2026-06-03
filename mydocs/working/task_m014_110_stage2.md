# Task M014 #110 Stage 2 완료 보고서

## 단계 목적

Stage 2는 Stage 3 구현 전 `FormObjectNode` 모델 확장과 type별 static preview/fallback 정책을 고정하는 단계다. Stage 1에서 확인한 `samples/form-01.hwp`, `samples/hwpx/form-002.hwpx` payload와 core SVG reference를 기준으로 Swift/CoreGraphics renderer의 구현 경계를 정리했다.

## 산출물

| 산출물 | 요약 |
|--------|------|
| `mydocs/working/task_m014_110_stage2.md` | FormObject payload 모델, 색상/label/type별 preview/fallback 정책 |

소스 코드는 변경하지 않았다. Stage 3에서 적용할 대상 파일은 `Sources/RhwpCoreBridge/RenderTree.swift`, `Sources/RhwpCoreBridge/CGTreeRenderer.swift`로 제한한다.

## 본문 변경 정도 / 본문 무손실 여부

기존 문서 본문은 변경하지 않았다. 이번 단계의 커밋 대상은 신규 단계 보고서뿐이다.

## 모델 정책

`FormObjectNode`는 현재 `form_type`, `caption`, `text`만 디코딩한다. Stage 3에서는 실제 target payload에 존재하고 정적 preview에 필요한 필드만 optional로 추가한다.

| Swift field | JSON key | Type | 사용 목적 |
|-------------|----------|------|-----------|
| `formType` | `form_type` | `String` | type별 renderer dispatch |
| `caption` | `caption` | `String` | label 후보 |
| `text` | `text` | `String` | label 후보. ComboBox/edit text 우선 |
| `foreColor` | `fore_color` | `String?` | label/stroke color 후보. `#RRGGBB` 우선 |
| `backColor` | `back_color` | `String?` | input/fallback fill color 후보 |
| `value` | `value` | `Int?` | checkbox/radio selected state |
| `enabled` | `enabled` | `Bool?` | disabled tone fallback |
| `name` | `name` | `String?` | unsupported fallback label 후보 |

`section_index`, `para_index`, `control_index`, `cell_location`은 target payload에 있지만 Stage 3 static preview에는 직접 필요하지 않다. 특히 `cell_location`은 future payload에서 object/array shape가 달라질 수 있으므로 이번 모델 확장에는 넣지 않는다.

추가 필드는 모두 optional로 디코딩한다. 기존 `form_type`, `caption`, `text` decode가 실패하지 않는 한 unknown/missing field는 renderer fallback으로 흡수한다.

## Label 정책

Label 우선순위:

1. `text`가 비어 있지 않으면 `text`
2. `caption`이 비어 있지 않으면 `caption`
3. `name`이 비어 있지 않으면 `name`
4. 마지막 fallback은 `formType`

문자열은 앞뒤 whitespace만 정리한다. HTML/XML entity unescape는 Stage 3에서 적용하지 않는다.

근거:

- Stage 1에서 `form-002.hwpx`의 일부 caption은 `R&amp;&amp;D...` 형태로 내려왔다.
- core SVG reference는 이를 SVG text로 다시 escape해 `R&amp;amp;&amp;amp;D...`로 내보내며, rhwp-studio reference도 현재 payload 문자열을 그대로 표시한다.
- 이번 작업의 기준은 bundled `rhwp-studio v0.7.13` parity이므로 Swift만 임의로 `R&&D` 또는 `R&D`로 바꾸지 않는다.

Text drawing은 `drawPlaceholderLabel`의 CoreText font fitting 아이디어를 재사용하되, checkbox/radio처럼 left aligned label이 필요한 control을 위해 별도 helper를 둔다. Helper는 다음 입력을 받는 방향으로 구현한다.

- text
- target rect
- color
- font size
- alignment: left 또는 center
- vertical center 기준

모든 label은 `visibleLabelRect(for:in:)` 기준으로 clipping intersection을 고려한다.

## 색상 정책

`fore_color`, `back_color`는 JSON에서 `#RRGGBB` string으로 내려온다. Stage 3에는 `CGTreeRenderer` 내부 private helper로 hex color string parser를 둔다.

Parsing 정책:

- 지원: `#RRGGBB`
- fallback: parse 실패 시 type별 기본 색상
- alpha: `enabled == false`일 때 전체 control 또는 label에 낮은 alpha/gray tone 적용
- HWP `ColorRef`용 `colorRefToCGColor(_:)`와 섞지 않는다. FormObject color string은 HTML-style RGB이므로 별도 parser로 처리한다.

기본 색상은 core SVG reference에 맞춘다.

| 용도 | 기본값 |
|------|--------|
| label/text | `#000000` |
| checkbox/radio stroke | `#606060` |
| input/button stroke | `#a0a0a0` |
| input fill | `#ffffff` |
| combo button fill | `#e0e0e0` |
| push button fill | `#d0d0d0` |
| push button label | `#808080` |
| fallback fill | `#f7f7f7` |
| fallback stroke | `#6a7785` |

`back_color`는 `Edit`, generic fallback, unknown type에서만 직접 fill 후보로 사용한다. `PushButton`, `CheckBox`, `RadioButton`, `ComboBox`는 core SVG의 static control chrome을 우선한다.

## Type dispatch 정책

`form_type`은 case-insensitive로 normalize한다. `PushButton`, `push_button`, `pushbutton`처럼 형태가 달라도 같은 type으로 처리할 수 있도록 소문자와 alnum 중심 key를 사용한다.

지원 type:

| Normalized type | Stage 3 renderer |
|-----------------|------------------|
| `pushbutton` | `renderPushButtonFormObject` |
| `checkbox` | `renderCheckBoxFormObject` |
| `radiobutton` | `renderRadioButtonFormObject` |
| `combobox` | `renderComboBoxFormObject` |
| `edit` | `renderEditFormObject` |

그 외 type은 `renderUnsupportedFormObject`로 fallback한다.

## Type별 preview 정책

### PushButton

Core SVG reference:

- bbox 전체에 gray rect
- stroke `#a0a0a0`, stroke width `0.5`
- caption centered
- label color `#808080`

Swift 정책:

- `validTopLeftRect`로 bbox 유효성 확인
- bbox clip
- fill `#d0d0d0`
- stroke `#a0a0a0`, 0.5~1pt
- label은 `text/caption/name/type` 우선순위에 따라 center alignment
- font size는 `min(max(rect.height * 0.45, 9), 12)` 범위로 시작하고 helper가 width에 맞게 축소

### CheckBox

Core SVG reference:

- bbox left에 13pt square
- `value=1`이면 check polyline
- label은 square 오른쪽에 12pt font로 vertical center

Swift 정책:

- square size는 `min(13, max(8, rect.height - 4))`
- square origin은 `rect.minX + 2`, `rect.midY - size / 2`
- fill white, stroke `#606060`
- selected 판단은 `value ?? 0 != 0`
- selected이면 3-point check path를 stroke width 1.5로 그림
- label rect는 square 오른쪽 `3~4pt` padding 이후부터 bbox 끝까지
- label은 left alignment, 기본 12pt, `foreColor` fallback `#000000`

### RadioButton

Core SVG reference:

- bbox left에 radius 6.5 circle
- `value=0`이면 empty circle
- label은 circle 오른쪽에 12pt font

Swift 정책:

- radius는 `min(6.5, max(4, (rect.height - 4) / 2))`
- circle center는 `rect.minX + 2 + radius`, `rect.midY`
- selected 판단은 `value ?? 0 != 0`
- selected이면 inner dot radius를 outer radius의 0.45로 그림
- label rect는 circle 오른쪽 `3~4pt` padding 이후부터 bbox 끝까지

### ComboBox

Core SVG reference:

- bbox full white rect
- right side button rect
- down arrow polygon
- text label은 left inset에서 vertical center

Swift 정책:

- fill white, stroke `#a0a0a0`
- button width는 `min(max(rect.height * 0.8, 12), rect.width * 0.35)`
- button fill `#e0e0e0`, stroke `#a0a0a0`
- arrow는 button center에 downward triangle
- label은 left inset `3pt`, right는 button 영역 전까지
- label 우선순위는 `text` 우선. target `form-01.hwp`의 `계절 선택`은 이 경로로 표시된다.

### Edit

Core SVG reference:

- white rect
- gray stroke
- target `form-01.hwp`의 Edit object 자체에는 text가 없다.

Swift 정책:

- fill은 `backColor`가 parse되면 사용하되, `#f0f0f0` 같은 system default가 들어온 경우에도 input은 white fill을 기본으로 둔다.
- stroke `#a0a0a0`
- label/value text가 있으면 left inset에서 그리되, empty면 rect만 표시한다.

### Unsupported

지원하지 않는 type은 empty no-op으로 두지 않는다.

- fill `#f7f7f7`
- stroke `#6a7785`, solid line
- label은 `FORM <type>` 또는 `name` 기반으로 center 표시
- Placeholder fallback과 구분하기 위해 dashed stroke를 쓰지 않는다.

## Renderer 경계 정책

Stage 3 implementation boundary:

- `CGTreeRenderer.renderNode`의 `.formObject` no-op을 `renderFormObject(formObject, bbox:in:)` 호출로 교체한다.
- `shouldRenderFlowContent` gate는 `.textRun`, `.placeholder`, `.rawSvg`와 같은 방식으로 유지한다.
- bbox validity는 `validTopLeftRect(for:)` 사용
- clipping은 각 renderer helper에서 `ctx.saveGState()`, `ctx.clip(to:)`, `ctx.restoreGState()` 패턴 유지
- CoreText label draw helper는 `resolveAppleFont(hwpFontFamily: "Apple SD Gothic Neo", ...)`를 사용
- `RhwpCoreBridge`에 AppKit/UIKit/WebKit 직접 의존을 추가하지 않는다.
- `Placeholder`, `RawSvg`, `Image`, `Equation`, 일반 text rendering은 Stage 3에서 의도적으로 변경하지 않는다.

## 검증 결과

문서/whitespace 검증:

```text
git diff --check
```

통과했다.

## 잔여 위험

- Target page에는 disabled control fixture가 없다. `enabled=false` tone은 synthetic 또는 후속 fixture 없이 보수적 fallback으로만 구현된다.
- `back_color`를 모든 known control에 그대로 적용하면 core SVG reference와 어긋날 수 있어, Stage 3에서는 known control chrome 기본값을 우선한다.
- HTML/XML entity를 unescape하지 않는 정책은 v0.7.13 parity에는 맞지만 사용자-facing 문자열 품질은 낮을 수 있다. 이 문제는 upstream payload 정규화 또는 별도 이슈에서 다루는 편이 안전하다.
- `cell_location`을 모델에 넣지 않으므로 cell-aware diagnostics는 Stage 3 결과에서 바로 제공하지 않는다.
- FormObject helper가 추가되면 `form-01.hwp`는 native non-white pixel이 크게 늘고 visual diff bounds가 변한다. 개선 여부는 rhwp-studio reference에 가까워지는지와 non-blank를 함께 봐야 한다.

## 다음 단계 영향

Stage 3에서는 다음 순서로 구현한다.

1. `RenderTree.swift`의 `FormObjectNode`에 optional field 추가
2. `CGTreeRenderer.renderNode`의 `.formObject` no-op 제거
3. color string parser와 label helper 추가
4. type dispatch와 five known type helper 구현
5. target sample render-debug와 HostApp build smoke 실행

Stage 3의 핵심 acceptance는 `form-01.hwp`에서 버튼/체크박스/콤보박스/라디오/입력칸이 보이고, `form-002.hwpx`에서 checkbox square/check/label이 no-op으로 사라지지 않는 것이다.

## 승인 요청

Stage 2 설계를 완료했다. Stage 3에서 `RenderTree.swift`와 `CGTreeRenderer.swift`에 FormObject 정적 preview 구현을 적용해도 되는지 승인 요청한다.
