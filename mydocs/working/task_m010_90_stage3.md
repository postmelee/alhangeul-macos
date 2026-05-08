# Task #90 Stage 3 완료 보고서 - Swift renderer와 core layout 책임 경계 판단

## 단계 목적

Stage 1-2에서 확인한 `복학원서.hwp` page 1 overflow가 Swift renderer 해석 문제인지, `rhwp` core layout/render tree 산출 문제인지 판단한다. 작업지시자 지시에 따라 core SVG도 같은 구조를 담고 있으면 upstream 보고 대상으로 확정한다.

## 산출물

저장소 source code 변경은 없다. Stage 3은 기존 산출물 분석과 이 보고서만 남긴다.

| 산출물 | 경로 | 비고 |
|--------|------|------|
| render tree JSON | `/tmp/rhwp-task90-bokhak-stage1/복학원서-page1-render-tree.json` | Stage 2 geometry 분석 기준 |
| core SVG | `/tmp/rhwp-task90-bokhak-stage1/복학원서-page1-core.svg` | `rhwp_render_page_svg` 산출 |
| native PNG | `/tmp/rhwp-task90-bokhak-stage1/복학원서-page1-native.png` | Swift `CGTreeRenderer` 산출 |
| summary | `/tmp/rhwp-task90-bokhak-stage1/복학원서-page1-summary.txt` | render debug summary |

macOS 파일명 정규화 때문에 실제 shell 출력에는 decomposed Hangul 파일명이 표시될 수 있다.

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. Stage 3은 제품 source, manual, plan 본문을 변경하지 않았다.

## 분석 결과

### 1. core SVG도 body clip 아래 text 좌표를 포함한다

core SVG는 body clip과 마지막 table cell clip을 모두 정의한다.

```text
<clipPath id="body-clip-3">
  <rect x="56.693333333333335" y="37.81333333333333" width="687.8933333333334" height="1046.88"/>
</clipPath>

<clipPath id="cell-clip-191">
  <rect x="56.693333333333335" y="888.8533333333332" width="642.4533333333334" height="233.70666666666665"/>
</clipPath>
```

body clip bottom은 `1084.7pt`다. 그런데 core SVG의 마지막 안내 문구는 같은 clip stack 아래에서 `y=1085.2`, `y=1101.2`, `y=1117.2` 좌표로 생성되어 있다.

```text
y=1085.2 text='※' clips=['url(#body-clip-3)', 'url(#cell-clip-191)']
y=1085.2 text='군' clips=['url(#body-clip-3)', 'url(#cell-clip-191)']
y=1101.2 text='※' clips=['url(#body-clip-3)', 'url(#cell-clip-191)']
y=1101.2 text='T' clips=['url(#body-clip-3)', 'url(#cell-clip-191)']
y=1117.2 text='o' clips=['url(#body-clip-3)', 'url(#cell-clip-191)']
```

즉 core SVG는 body clip으로 표시상 자를 수 있는 구조를 갖고 있지만, layout 산출 자체는 body 영역 아래에 text를 배치한다. 이는 Stage 2의 render tree geometry와 같은 구조다.

### 2. native PNG는 body clip 아래를 실제로 그리지 않는다

native PNG의 크기는 `794x1123`이다. 픽셀 분석 결과 body clip 아래(`y >= 1085`)에는 non-white pixel이 없다.

```text
body nonWhite=163067 bbox=(57, 158, 722, 1083)
below-body nonWhite=0 bbox=None
page-bottom-row nonWhite=0 bbox=None
```

이는 Swift `CGTreeRenderer`가 `Body.clip_rect`를 적용하고 있다는 Stage 2 코드 확인과 일치한다. 따라서 현재 native renderer가 body clip을 무시해서 하단 텍스트를 그리는 문제는 아니다.

### 3. Swift renderer 책임 가능성은 낮다

Stage 2-3을 합치면 다음이 확인됐다.

- render tree JSON에서 `Table id=173`, `TableCell id=191`, 하단 text run들이 body clip 하단 밖에 배치되어 있다.
- core SVG도 같은 text를 body clip 하단 아래 좌표에 생성한다.
- Swift `RenderTree`는 `Body.clip_rect`와 `TableCell.clip`을 디코딩한다.
- Swift `CGTreeRenderer`는 body clip과 table cell clip을 모두 적용한다.
- native PNG는 body clip 아래를 그리지 않는다.

따라서 이 이슈는 앱 저장소의 Swift renderer clip 누락이나 HostApp/Quick Look/Thumbnail 공통 renderer의 직접 버그라기보다, `rhwp` core의 layout 또는 render tree/SVG 산출 단계에서 table이 body 영역 밖으로 배치되는 문제로 보는 것이 타당하다.

### 4. 표시 계층 clipping은 완화책일 뿐 layout 수정은 아니다

HostApp Viewer Stage 7에서 page bounds clip을 추가한 것은 page view 바깥 drawing을 숨기는 표시 계층 보정이다. Quick Look/Thumbnail/native bitmap 경로도 bitmap context와 body clip 때문에 page/body 밖 drawing이 보이지 않을 수 있다.

하지만 table과 text run의 logical 위치가 이미 body clip 밖으로 산출되므로, 표시 계층 clipping은 잘못 배치된 layout을 올바르게 재배치하지 않는다. 오른쪽 아래 문구가 정상 위치에 보여야 한다면 `rhwp` core layout에서 table pagination/body overflow 처리를 수정해야 한다.

## 결론

Task #90의 현재 문제는 **upstream `edwardkim/rhwp` core layout/render tree 산출 문제로 확정**한다.

앱 저장소에서 즉시 수정할 항목은 없다. 후속 조치는 upstream 보고용 최소 재현 자료를 정리하는 것이다. 보고에는 다음 항목을 포함한다.

- sample: `samples/복학원서.hwp`
- sample SHA-256: `da81b4010331bcac290f900c7cf224c97ee8355399614725ce46c197ff1a22a4`
- core commit: `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`
- diagnostic:
  - `LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Table, y=1130.6, bottom=1084.7, overflow=45.9px`
  - `LAYOUT_OVERFLOW: page=0, col=0, para=16, type=PartialParagraph, y=1094.3, bottom=1084.7, overflow=9.6px`
  - `LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Shape, y=1094.3, bottom=1084.7, overflow=9.6px`
- render tree evidence:
  - body clip bottom `1084.7pt`
  - `Table id=173` bottom `1122.6pt`
  - `TableCell id=191` bottom `1122.6pt`
  - visible text runs below body clip
- core SVG evidence:
  - body clip bottom `1084.7pt`
  - text elements at `y=1085.2`, `y=1101.2`, `y=1117.2` under `body-clip-3` and `cell-clip-191`

## 검증 결과

Stage 3 계획서의 검증 명령과 보조 분석을 실행했다.

```bash
git status --short --branch
sed -n '1,160p' /tmp/rhwp-task90-bokhak-stage1/복학원서-page1-summary.txt
sips -g pixelWidth -g pixelHeight /tmp/rhwp-task90-bokhak-stage1/복학원서-page1-native.png
git diff --check
```

결과 요약:

```text
## local/task90
PageSizePt: 793.7x1122.5
RenderTreeJSONBytes: 189402
CoreSVGBytes: 341594
NativePNGSize: 794x1123
TextRuns: 102
MissingHangulGlyphs: 0
git diff --check 통과
```

core SVG 구조 분석:

```text
TextElements: 710
TextElementsBelowBodyClip: 197
아래 좌표의 text elements는 body-clip-3과 cell-clip-191 아래에 존재:
y=1085.2
y=1101.2
y=1117.2
```

native PNG 픽셀 분석:

```text
body nonWhite=163067 bbox=(57, 158, 722, 1083)
below-body nonWhite=0 bbox=None
page-bottom-row nonWhite=0 bbox=None
```

`qlmanage` rasterize는 Stage 1에서 sandbox 오류로 실패했고, Stage 3에서 외부 실행을 재시도했으나 승인 검토 timeout으로 실행되지 않았다. pixel diff는 선택 산출물이므로 Stage 3 결론에는 사용하지 않았다.

## 잔여 위험

- 한컴 viewer 또는 다른 reference renderer와의 직접 비교는 아직 수행하지 않았다. upstream 보고 시 기대 결과를 명확히 하려면 사용자가 관찰한 스크린샷 또는 reference render를 함께 첨부하는 편이 좋다.
- core SVG는 clip을 포함하므로 일반 SVG viewer에서는 overflow text가 표시상 잘릴 수 있다. 보고 시에는 visual screenshot뿐 아니라 SVG/render tree 좌표 증거를 함께 제시해야 한다.
- 앱 저장소에서 page/body clip을 더 강하게 적용하는 것은 표시 완화책일 뿐이며, layout 재배치 문제를 해결하지 않는다.

## 다음 단계 영향

Stage 4에서는 최종 보고서에 upstream 보고 대상으로 확정한 결론을 정리하고, upstream 이슈 초안에 들어갈 최소 재현 자료를 작성한다. 앱 저장소 source 수정 단계는 추가하지 않는다.

## 승인 요청

Stage 3 완료를 승인 요청한다. 승인 후 Stage 4 `검증과 후속 조치 자료 정리`로 진행한다.
