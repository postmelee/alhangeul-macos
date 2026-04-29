# Task #90 최종 결과 보고서

## 작업 요약

- **이슈**: [#90 복학원서.hwp page bbox 밖 layout overflow 렌더 품질 조사](https://github.com/postmelee/alhangeul-macos/issues/90)
- **마일스톤**: v0.1 (M010)
- **브랜치**: `local/task90`
- **Worktree**: `/Users/melee/Documents/projects/rhwp-mac`
- **단계 수**: 4단계
- **완료 시각**: 2026-04-29 12:40 KST
- **목적**: `복학원서.hwp` page 1의 page/body 경계 밖 layout overflow가 앱 renderer 문제인지, `rhwp` core layout/render tree 산출 문제인지 분리

## 단계별 진행

| Stage | Commit | 내용 |
|-------|--------|------|
| 1 | `54cbb79` | 기준 산출물 재생성과 overflow 재현 |
| 2 | `c023651` | overflow node와 page geometry 분석 |
| 3 | `d8e1006` | Swift renderer와 core layout 책임 경계 판단 |
| 4 | 본 커밋 | 최종 보고서, 후속 이슈, PR 자료 정리 |

## 최종 결론

Task #90의 문제는 앱 Quick Look/View/Thumbnail 표시 계층의 clip 누락 문제가 아니라 **upstream `edwardkim/rhwp` core layout/render tree/SVG 산출 문제**로 판단한다.

앱 저장소에서 즉시 수정할 source code는 없다. 이번 PR은 rhwp 위키의 Investigation / Spike PR 패턴처럼, 본 증상을 직접 수정하지 않고 원인 분석 결과와 후속 추적 경로를 보존하는 조사 PR로 마무리한다.

## 핵심 근거

### 재현 산출물

Stage 1에서 다음 명령으로 현재 core pin 기준 산출물을 생성했다.

```bash
./scripts/render-debug-compare.sh /tmp/rhwp-task90-bokhak-stage1 --page 1 samples/복학원서.hwp
```

필수 산출물:

| 산출물 | 경로 |
|--------|------|
| render tree JSON | `/tmp/rhwp-task90-bokhak-stage1/복학원서-page1-render-tree.json` |
| core SVG | `/tmp/rhwp-task90-bokhak-stage1/복학원서-page1-core.svg` |
| native PNG | `/tmp/rhwp-task90-bokhak-stage1/복학원서-page1-native.png` |
| summary | `/tmp/rhwp-task90-bokhak-stage1/복학원서-page1-summary.txt` |

sample hash:

```text
da81b4010331bcac290f900c7cf224c97ee8355399614725ce46c197ff1a22a4  samples/복학원서.hwp
```

현재 core commit:

```text
e91ecea3174a0da0ad7a1ea495cacc4f8772c31d
```

diagnostic:

```text
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Table, y=1130.6, bottom=1084.7, overflow=45.9px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=PartialParagraph, y=1094.3, bottom=1084.7, overflow=9.6px
LAYOUT_OVERFLOW: page=0, col=0, para=16, type=Shape, y=1094.3, bottom=1084.7, overflow=9.6px
```

### geometry 분석

Stage 2에서 render tree JSON을 분석한 결과:

- page rect: `x=0.0 y=0.0 width=793.7 height=1122.5`
- body clip: `x=56.7 y=37.8 width=687.9 height=1046.9 bottom=1084.7`
- body clip overflow nodes: 23
- visible text runs beyond body clip: 4
- 대표 overflow node:
  - `Table id=173 bottom=1122.6 bodyExB=37.9`
  - `TableCell id=191 bottom=1122.6 bodyExB=37.9`

diagnostic의 `bottom=1084.7`은 page bottom이 아니라 body clip bottom과 일치한다.

### core SVG와 native PNG 비교

Stage 3에서 core SVG도 같은 layout 구조를 포함하는지 확인했다.

- core SVG body clip bottom: `1084.7pt`
- core SVG text coordinates: `y=1085.2`, `y=1101.2`, `y=1117.2`
- 해당 text elements는 `body-clip-3`과 `cell-clip-191` 아래에 존재한다.

native PNG 픽셀 분석:

```text
body nonWhite=163067 bbox=(57, 158, 722, 1083)
below-body nonWhite=0 bbox=None
page-bottom-row nonWhite=0 bbox=None
```

즉 Swift native renderer는 body clip 아래를 실제로 그리지 않는다. 문제는 Swift `CGTreeRenderer`가 clip을 누락한 것이 아니라, core가 이미 body 영역 밖 좌표를 산출한 것이다.

## 기각한 가설

### Quick Look clip 누락

Quick Look shared renderer에 page-level clip을 임시 적용해 비교했다.

결과:

```text
baseline.png SHA256   3c92bfa12771115431fb5b501e248240ae73eb43387e8191536c2db40e340a37
experiment.png SHA256 3c92bfa12771115431fb5b501e248240ae73eb43387e8191536c2db40e340a37
differentPixels=0
maxChannelDelta=0
```

따라서 #90의 Quick Look 표시 문제를 page-level clip 추가로 해결할 수 없다고 판단했다. 실험 코드는 사용자 확인 후 되돌렸고 최종 source 변경에는 포함하지 않았다.

### Swift renderer clip 누락

`RenderTree.swift`는 `Body.clipRect`와 `TableCellNode.clip`을 디코딩하고, `CGTreeRenderer.swift`는 두 clip을 적용한다. native PNG도 body clip 아래 non-white pixel이 없었다.

따라서 Swift renderer clip 누락 가설은 기각한다.

### #84 clip 되돌림 필요

#84의 HostApp Viewer page bounds clip은 page view 바깥 drawing을 숨기는 view containment 안전장치다. core layout overflow를 고치는 기능은 아니지만, viewer가 자기 bounds 밖으로 그리지 않게 하는 장기 안전장치로 유지할 수 있다.

## 후속 추적

### upstream

이미 열린 upstream 이슈가 같은 계열 문제를 다룬다.

- [edwardkim/rhwp #421 복학원서.hwp BehindText 그림 후속 본문 문단 배치가 한컴과 다름](https://github.com/edwardkim/rhwp/issues/421)

메인테이너가 워터마크 효과 이미지 속성 구현과 맞물린 일련 작업으로 처리하겠다고 답변한 상태다. #90에서는 별도 upstream 신규 이슈를 만들지 않고 #421을 추적 대상으로 둔다.

### 우리 저장소 후속

사용자 관찰상 PR #81 이후 표시 양상이 더 오른쪽으로 이동해 잘려 보였을 가능성이 있다. 다만 이 부분은 old core bridge를 재빌드해 pre/post 비교해야 확정할 수 있다.

후속 이슈:

- [#94 PR #81 전후 rhwp core pin 복학원서.hwp 렌더 회귀 A/B 비교](https://github.com/postmelee/alhangeul-macos/issues/94)

비교 대상 core pin:

```text
pre-#81:  1e9d78a1d40c71779d81c6ec6870cd301d912626
post-#81: e91ecea3174a0da0ad7a1ea495cacc4f8772c31d
```

## 변경 파일 목록과 영향 범위

### 문서

- `mydocs/orders/20260429.md`
- `mydocs/plans/task_m010_90.md`
- `mydocs/plans/task_m010_90_impl.md`
- `mydocs/working/task_m010_90_stage1.md`
- `mydocs/working/task_m010_90_stage2.md`
- `mydocs/working/task_m010_90_stage3.md`
- `mydocs/working/task_m010_90_stage4.md`
- `mydocs/report/task_m010_90_report.md`

### GitHub Issue

- [#94 PR #81 전후 rhwp core pin 복학원서.hwp 렌더 회귀 A/B 비교](https://github.com/postmelee/alhangeul-macos/issues/94)

### 제외/미변경

- 앱 제품 source code 변경 없음
- RustBridge ABI 변경 없음
- `edwardkim/rhwp` core 직접 수정 없음
- Quick Look/Thumbnail/HostApp Viewer 동작 변경 없음
- release, signing, notarization 작업 없음

## 검증 결과

| 검증 항목 | 결과 |
|-----------|------|
| `git diff --check` | OK |
| `./scripts/validate-stage3-render.sh /tmp/rhwp-task90-stage4-render-smoke` | OK |
| `samples/복학원서.hwp` render debug 산출물 생성 | OK |
| render tree geometry 분석 | OK |
| core SVG 구조 분석 | OK |
| native PNG body clip 아래 pixel 분석 | OK |
| Quick Look page-level clip 임시 실험 | baseline과 동일, code revert 완료 |

render smoke:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=449097
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=53220
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=108 hangulRuns=71 hangulScalars=1203 nonWhitePixels=159757
```

## 잔여 위험과 후속 작업

- upstream #421이 해결되기 전까지 `복학원서.hwp`의 실제 layout 배치 차이는 남는다.
- PR #81 전후 core pin 변경이 증상 악화의 직접 원인인지 확정하려면 #94에서 pre/post bridge 재빌드와 산출물 비교가 필요하다.
- core SVG는 clip을 포함하므로 단순 visual screenshot만으로는 문제 원인이 충분히 설명되지 않을 수 있다. upstream 공유 시 render tree/SVG 좌표 근거를 함께 제공해야 한다.

## 작업지시자 승인 요청

#90은 조사 목적을 충족했다. 승인 후 `publish/task90` 원격 push와 devel 대상 draft PR 생성을 진행한다.
