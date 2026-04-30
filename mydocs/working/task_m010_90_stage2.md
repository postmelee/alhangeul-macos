# Task #90 Stage 2 완료 보고서 - overflow node와 page geometry 분석

## 단계 목적

Stage 1에서 생성한 `복학원서.hwp` page 1 render tree JSON을 기준으로 page bbox와 body clip을 넘는 node를 구조적으로 식별한다. diagnostic의 `para=16` overflow가 render tree geometry와 어떤 관계인지 확인하고, Swift renderer가 사용할 수 있는 clip 정보가 render tree에 존재하는지 점검한다.

## 산출물

저장소 source code 변경은 없다. Stage 2는 `/tmp/rhwp-task90-bokhak-stage1/복학원서-page1-render-tree.json` 분석 결과와 이 보고서만 남긴다.

| 항목 | 값 |
|------|----|
| 전체 node 수 | 252 |
| page rect | `x=0.0, y=0.0, width=793.7, height=1122.5` |
| body clip | `x=56.7, y=37.8, width=687.9, height=1046.9, right=744.6, bottom=1084.7` |
| page rect overflow node | 9개 |
| body clip overflow node | 23개 |
| body clip 밖 visible text run | 4개 |

## 본문 변경 정도 / 본문 무손실 여부

해당 없음. Stage 2는 제품 source, manual, plan 본문을 변경하지 않았다.

## 분석 결과

### 1. diagnostic의 `bottom=1084.7`은 body clip 하단과 일치

render tree의 root page height는 `1122.5pt`이고, body clip 하단은 `37.8 + 1046.9 = 1084.7pt`다.

Stage 1 diagnostic:

```text
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Table, y=1130.6, bottom=1084.7, overflow=45.9px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=PartialParagraph, y=1094.3, bottom=1084.7, overflow=9.6px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Shape, y=1094.3, bottom=1084.7, overflow=9.6px
```

따라서 diagnostic의 기준 경계는 page bottom `1122.5pt`가 아니라 body clip bottom `1084.7pt`에 가깝다. Table diagnostic의 `y=1130.6`은 render tree table bbox bottom `1122.6`과 완전히 같지는 않으므로, core layout cursor 또는 logical table bottom 값이 render tree bbox와 별도로 계산되는 것으로 보인다.

### 2. 대표 overflow는 `para_index=16` table과 마지막 row cell

대표 node:

```text
id=173 type=Table bbox=(56.7,842.3,642.5,280.2) bottom=1122.6 bodyExB=37.9 para_index=16 control_index=0
chain=0:Page > 3:Body > 4:Column > 173:Table

id=191 type=TableCell bbox=(56.7,888.9,642.5,233.7) bottom=1122.6 bodyExB=37.9 row=2 col=0 clip=True model_cell_index=5
chain=0:Page > 3:Body > 4:Column > 173:Table > 191:TableCell
```

`id=173` table은 body clip 하단을 약 `37.9pt` 넘고, page bottom도 약 `0.1pt` 넘는다. 같은 table의 마지막 row cell인 `id=191`도 동일하게 body clip과 page bottom을 넘는다.

해당 cell 안에서 body clip 밖으로 나가는 visible text run은 다음 4개다.

```text
id=226 TextRun bottom=1086.8 bodyExB=2.1 text='    ※ 군필자는 병무행정(분)실에서 휴․복학 만기일 이내에 예비군 전입신고를 하기 바람.'
chain=0:Page > 3:Body > 4:Column > 173:Table > 191:TableCell > 225:TextLine > 226:TextRun

id=230 TextRun bottom=1102.8 bodyExB=18.1 text='※ '
chain=0:Page > 3:Body > 4:Column > 173:Table > 191:TableCell > 227:TextLine > 230:TextRun

id=231 TextRun bottom=1102.8 bodyExB=18.1 text='Those who completed their military service must make a reserve force transfer no...'
chain=0:Page > 3:Body > 4:Column > 173:Table > 191:TableCell > 227:TextLine > 231:TextRun

id=233 TextRun bottom=1118.8 bodyExB=34.1 text='       of absence/return to school registration period, at the Military Affairs ...'
chain=0:Page > 3:Body > 4:Column > 173:Table > 191:TableCell > 232:TextLine > 233:TextRun
```

즉 사용자에게 보이는 오른쪽 아래 하단 문구 문제는 `para_index=16` table 내부 마지막 row의 안내 문구들이 body 영역 밖에 배치된 현상과 직접 연결된다.

### 3. `para_index=16`에는 table 외 다른 관련 node도 있다

`para_index=16` 관련 node:

```text
id=237 Ellipse bbox=(611.4,950.9,89.5,84.4) bottom=1035.4 control_index=1
chain=0:Page > 237:Ellipse

id=173 Table bbox=(56.7,842.3,642.5,280.2) bottom=1122.6 control_index=0
chain=0:Page > 3:Body > 4:Column > 173:Table

id=234 TextLine bbox=(56.7,800.7,687.9,283.9) bottom=1084.7
chain=0:Page > 3:Body > 4:Column > 234:TextLine

id=235 TextRun bbox=(56.7,800.7,13.0,283.9) bottom=1084.7 text='󰠜󰠜'
chain=0:Page > 3:Body > 4:Column > 234:TextLine > 235:TextRun
```

`id=237` ellipse는 page 직속 shape이며 body clip 밖으로 나가지 않는다. `id=234/235`는 body clip 하단에 정확히 맞는다. Stage 2 기준에서 실제 body clip 하단을 넘는 핵심 node는 `id=173` table과 그 하위 `id=191` cell 및 cell 내부 마지막 text lines다.

### 4. right overflow 후보는 대부분 빈 text run이다

page rect 오른쪽을 넘는 node도 9개 있었지만, 큰 overflow 후보의 text는 빈 문자열이다.

예:

```text
id=9 TextRun bbox=(400.6,125.7,687.9,13.3) right=1088.5 pageExR=294.8 text=''
id=107 TextRun bbox=(400.6,603.8,687.9,13.3) right=1088.5 pageExR=294.8 text=''
id=168 TextRun bbox=(400.6,758.3,687.9,13.3) right=1088.5 pageExR=294.8 text=''
id=172 TextRun bbox=(400.6,821.8,687.9,13.3) right=1088.5 pageExR=294.8 text=''
```

Stage 2의 주된 사용자 표시 문제는 오른쪽 overflow보다 하단 body clip overflow에 더 가깝다. 오른쪽 overflow 후보는 Stage 3에서 core SVG/native PNG를 눈으로 비교할 때 visible artifact가 있는지 별도로 확인한다.

### 5. clip 정보는 render tree와 Swift renderer 양쪽에 존재한다

Swift 모델:

```text
RenderTree.swift:129-132
BodyNode.clipRect -> "clip_rect"

RenderTree.swift:203-214
TableCellNode.clip -> "clip"
```

Swift renderer:

```text
CGTreeRenderer.swift:59-64
Body.clipRect가 있으면 ctx.clip(to: cgRect(clip)) 후 children 렌더

CGTreeRenderer.swift:69-74
TableCell.clip이 true면 ctx.clip(to: cgRect(node.bbox)) 후 children 렌더
```

따라서 Stage 2 기준으로는 render tree에 body clip과 table cell clip 정보가 있고, `CGTreeRenderer`도 두 clip을 모두 적용한다. 다만 `id=191` table cell 자체의 bbox가 body clip 밖까지 확장되어 있으므로, cell clip은 cell 내부 overflow를 막지만 body 밖 배치를 고치지는 않는다. body clip은 표시상 하단 overflow를 자를 수 있으나, render tree/layout 자체가 body 영역 밖으로 확장된 사실은 그대로 남는다.

## 검증 결과

Stage 2 계획서의 검증 명령을 실행했다.

```bash
git status --short --branch
sed -n '1,220p' Sources/RhwpCoreBridge/RenderTree.swift
sed -n '1,140p' Sources/RhwpCoreBridge/CGTreeRenderer.swift
rg -n "\"clip_rect\"|\"clip\"|\"TextRun\"|\"bbox\"" /tmp/rhwp-task90-bokhak-stage1/복학원서-page1-render-tree.json
git diff --check
```

결과 요약:

```text
## local/task90
RenderTree.swift에서 Body.clip_rect, TableCell.clip 디코딩 확인
CGTreeRenderer.swift에서 Body.clipRect와 TableCell.clip 적용 확인
render tree JSON에서 clip_rect, clip, TextRun, bbox 필드 확인
git diff --check 통과
```

분석 보조 명령으로 structured JSON traversal을 수행했고, 주요 출력은 본 보고서의 `분석 결과` 섹션에 반영했다.

## 잔여 위험

- Stage 2는 geometry 분석 단계라 core SVG와 native PNG의 실제 시각 차이는 아직 판정하지 않았다.
- Table diagnostic의 overflow 값 `45.9px`와 render tree bbox 기준 body overflow `37.9pt`가 완전히 같지는 않다. Stage 3에서 core SVG와 native PNG를 함께 확인해 logical layout overflow와 실제 drawing overflow를 분리해야 한다.
- 오른쪽 page overflow 후보 중 다수는 빈 text run이지만, Stage 3에서 visible artifact가 없는지 확인해야 한다.

## 다음 단계 영향

Stage 3에서는 다음 판단을 우선한다.

- core SVG에서도 하단 table 안내 문구가 body 영역 밖까지 존재하는지 확인한다.
- native PNG가 body clip을 적용해 하단 overflow를 자르는지, 또는 표시 계층에 따라 page bounds 밖까지 보일 수 있는지 확인한다.
- clip 정보가 이미 Swift renderer에 반영되어 있으므로, 앱 저장소 수정 후보는 단순 clip 누락보다는 core layout/render tree bbox 산출 또는 표시 계층 clipping 정책의 문제로 좁혀질 가능성이 크다.

## 승인 요청

Stage 2 완료를 승인 요청한다. 승인 후 Stage 3 `Swift renderer와 core layout 책임 경계 판단`으로 진행한다.
