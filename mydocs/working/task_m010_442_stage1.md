# Task M010 #442 Stage 1 완료보고서

## 단계 목적

rhwp-studio v0.8.2 반영 후 HostApp 상단 툴바가 겹치는 원인을 upstream source, bundled asset, local WKWebView override와 HostApp 최소 창 조건에서 교차 확인한다. 조사 결과를 바탕으로 upstream과 Alhangeul local CSS의 selector/property ownership, 최소 구현 범위, 재발 방지 guard와 breakpoint 검증 기준을 구현계획서로 확정한다.

## 산출물

- `mydocs/plans/task_m010_442_impl.md`
  - 273줄
  - upstream v0.7.18→v0.8.2 layout 변화와 local override cascade 분석
  - upstream layout / local select presentation ownership 계약
  - Stage 2 CSS·verifier 변경안
  - Stage 3 breakpoint visual matrix
  - Stage 4 PR 및 Stage 5 Issue #441 인계 경계
- `mydocs/working/task_m010_442_stage1.md`
  - Stage 1 조사·검증 결과와 다음 단계 영향 기록
- `mydocs/orders/20260728.md`
  - Issue #442 비고를 `Stage 1 완료 · Stage 2 승인 대기`로 갱신

## 본문 변경 정도 / 본문 무손실 여부

- Stage 1에서는 제품 CSS, 검증 스크립트, upstream generated asset, manifest, Swift와 Xcode project를 변경하지 않았다.
- 기존 수행계획서 `mydocs/plans/task_m010_442.md` 본문은 변경하지 않았다.
- 오늘할일은 Issue #442 행의 진행 단계 비고만 갱신했다.
- 구현계획서는 신규 문서이며 조사 결과와 승인된 수행 범위 안에서 5단계 구현·검증 절차를 구체화했다.

## 조사 결과

1. bundled manifest의 upstream target과 로컬 upstream tag는 모두 `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c`로 일치한다.
2. generated stylesheet 다음에 `alhangeul-wkwebview-overrides.css`가 로드되므로 같은 specificity의 local 선언이 upstream 선언을 덮는다.
3. upstream v0.8.2는 desktop에서 `#style-bar`를 최소 68px auto-height ribbon으로, 768~1023px에서 field 1행 + command 1행 grid로 배치한다.
4. local override는 동일한 `#style-bar` ID selector에 32px 고정 높이를 적용하고 field width와 control height도 이전 기준으로 덮는다.
5. HostApp의 900px 최소 폭은 upstream tablet breakpoint에 포함되므로, 필요한 다중 행 높이가 32px로 잘리면서 editor 영역과 겹친다.
6. local override는 Task #134와 Task #140의 WKWebView native select metric 보정을 소유하므로 파일 전체 삭제가 아니라 select appearance/text/indicator만 남기는 방향을 선택했다.
7. 현재 asset verifier는 provenance와 override 파일 load는 확인하지만 structural selector 충돌은 탐지하지 못하므로 Stage 2에서 ownership guard를 추가한다.
8. upstream `v0.8.2..upstream/main` 범위에서 style bar, responsive, toolbar와 index 관련 후속 변경이 없어 local release blocker로 처리한다.

## 검증 결과

upstream tag resolved commit:

```text
PASS: v0.8.2^{commit} =
9b16aa9e23f476e2b335d7c029fc9f24a199d63c
```

bundled asset baseline:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac-task442/Sources/HostApp/Resources/rhwp-studio
```

현재 회귀 원인 selector/property:

```text
8:    height: 32px;
9:    min-height: 32px;
41:  #style-name {
45:  .sb-font-lang {
50:  .sb-font {
54:  .sb-size-group {
77:  .sb-ls-group {
```

HostApp 최소 폭:

```text
40:            .frame(minWidth: 900, minHeight: 620)
276:            .frame(minWidth: 900, minHeight: 620)
```

구현계획서 구조:

```text
PASS: upstream 소유 / Alhangeul local overlay 소유 / local overlay 금지 구분 존재
PASS: Stage 2, Stage 3, Stage 4, Stage 5 변경·검증·인계 절차 존재
PASS: 구현계획서 trailing whitespace 없음
PASS: git diff --check
```

모든 Stage 1 검증 명령은 exit code 0으로 통과했다.

## 잔여 위험

- select-only overlay로 축소한 뒤 WKWebView native select의 수직 text metric이나 indicator 위치가 달라질 수 있다.
- 1023/1024px에서 의도된 두 행 grid와 68px desktop ribbon 전환을 단순 높이 차이만으로 오판할 수 있다.
- verifier 정규식이 `line-height`나 `background-size`를 dimension 위반으로 잘못 탐지하면 정상 overlay를 차단할 수 있다.
- source CSS가 정상이어도 stale DerivedData resource를 실행하면 회귀가 남은 것처럼 보일 수 있다.
- Task #442 merge 뒤에도 Issue #441 candidate SHA를 새로 만들지 않으면 기존 rehearsal artifact가 잘못 재사용될 수 있다.

## 다음 단계 영향

Stage 2는 다음 두 제품 파일로 변경 범위를 제한한다.

- `Sources/HostApp/Resources/rhwp-studio/alhangeul-wkwebview-overrides.css`
- `scripts/verify-rhwp-studio-assets.sh`

CSS에서는 upstream layout selector와 독립 dimension을 제거하고 WKWebView select presentation만 유지한다. verifier는 정상 source 통과와 stale `#style-bar`/dimension을 넣은 task 전용 임시 resource 실패를 함께 확인한다. upstream hashed asset, manifest, Swift와 Xcode project는 변경하지 않는다.

## 승인 요청

승인된 구현계획서와 이 보고서 기준으로 Stage 2의 WKWebView override 축소와 ownership guard 구현을 진행할지 승인 요청한다.

Stage 2 승인 전에는 CSS와 검증 스크립트를 변경하지 않는다.
