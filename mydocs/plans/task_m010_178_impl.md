# Issue #178 구현 계획서

## 작업명

홍보 페이지 두 번째 섹션 레이아웃과 철학 문구 보강

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_178.md`를 기준으로 진행한다.
- 작업 브랜치는 `local/task178`, 통합 대상은 `devel-webview`로 둔다.
- 변경 범위는 GitHub Pages 정적 홍보 페이지의 두 번째 섹션으로 제한한다.
- `HWP/HWPX 문서를 Mac에서 빠르게 확인하고, 편집하고, 공유하세요.` 리드 문구는 유지한다.
- 기존 이미지 `docs/assets/og-main.png`를 유지하고 새 자산은 만들지 않는다.
- 기존 Apple-style white/black/blue accent 톤, 시스템 폰트, header/hero/Feature 섹션 구조를 유지한다.
- 과장된 제품 주장을 추가하지 않는다.
- HostApp, Quick Look, Thumbnail extension, Xcode project, 배포 설정은 변경하지 않는다.
- 각 단계 완료 후 단계별 완료보고서를 작성하고 작업지시자 승인 전 다음 단계로 진행하지 않는다.

## 사전 조사 요약

현행 두 번째 섹션 구조는 `docs/index.html`의 `app-intro-section`이다.

- `docs/index.html` L83-L120: `알한글` 제목, 리드 문구, `.app-intro-philosophy`, `og-main.png`, 기능 요약 4개 항목이 한 섹션에 배치되어 있다.
- `docs/styles.css` L299-L303: `.app-intro-section`이 `min-height: calc(100svh - var(--header-height))`와 `align-items: center`를 사용한다. 이 조합 때문에 콘텐츠 높이가 viewport보다 작을 때 위아래 여백이 중앙 정렬로 분산되어, 제목 위 여백이 실제 padding보다 크게 느껴질 수 있다.
- `docs/styles.css` L338-L345: 철학 설명은 15px muted text 단락으로만 표시되어 리드 문구 아래 중요 메시지로 보이기 어렵다.
- `docs/styles.css` L347-L349: 스크린샷 영역이 `width: min(960px, 100%, 82svh)`로 제한되어 있으며, 원본 `og-main.png` 크기 대비 여유가 있다.
- `docs/styles.css` L1376-L1384, L1623-L1646: tablet/mobile override에서 섹션 높이, padding, 철학 설명 type scale을 별도로 관리하므로 데스크톱 변경 후 반응형 보정이 필요하다.

## Stage 1: 두 번째 섹션 HTML/CSS 보강

대상:

- `docs/index.html`
- `docs/styles.css`
- `mydocs/working/task_m010_178_stage1.md`

작업:

- `.app-intro-section`을 중앙 정렬 위주에서 상단 진입 리듬이 자연스러운 구조로 조정한다.
- 데스크톱에서 두 번째 섹션 상단 padding과 내부 gap을 줄이고, 첫 섹션 뒤에 과한 빈 공간이 생기지 않게 한다.
- `.app-intro-philosophy`를 단순 회색 단락에서 얇은 hairline 선언문 영역으로 바꾼다.
- 철학 설명 문구를 두 문장 위계로 재구성한다.
  - 선언 문장: `문서 접근은 특정 프로그램 구매 여부에 묶이면 안 됩니다.`
  - 보조 문장: `알한글은 한글을 설치하기 어려운 Mac에서도 필요한 HWP/HWPX 문서를 확인하고 제출할 수 있게 만드는 오픈소스 도구입니다.`
- 스크린샷 미디어 폭을 데스크톱 기준 더 크게 조정한다.
- 이미지 확대에 맞춰 기능 요약 4개 항목의 폭과 간격을 조정한다.
- 모바일에서는 철학 설명 영역의 padding, type scale, 줄바꿈이 과해지지 않도록 별도 override를 둔다.

검증:

```bash
rg -n "문서 접근은 특정 프로그램 구매 여부|app-intro-philosophy|app-intro-media|app-intro-capabilities" docs/index.html docs/styles.css
git diff --check -- docs/index.html docs/styles.css mydocs/working/task_m010_178_stage1.md
```

완료 조건:

- 리드 문구가 변경되지 않았다.
- 철학 설명이 두 문장 구조로 분리되어 있다.
- 두 번째 섹션 상단 정렬과 스크린샷 확대 CSS가 반영되어 있다.
- 구현 변경과 단계 보고서가 한 커밋에 포함되어 있다.

예상 커밋:

```text
Task #178 Stage 1: 두 번째 섹션 레이아웃과 철학 문구 보강
```

## Stage 2: 브라우저 시각 검증과 반응형 보정

대상:

- `docs/index.html`
- `docs/styles.css`
- 필요 시 `docs/script.js` 확인
- `mydocs/working/task_m010_178_stage2.md`
- 필요 시 `mydocs/working/assets/task_m010_178_stage2_*.png`

작업:

- 로컬 정적 서버로 `docs/` 페이지를 실행한다.
- Browser/IAB 또는 사용 가능한 브라우저 검증 도구로 데스크톱과 모바일 폭을 확인한다.
- 두 번째 섹션에서 다음 항목을 확인하고 필요한 CSS 보정을 수행한다.
  - `알한글` 제목 위 상단 여백
  - 리드 문구와 철학 설명의 위계
  - 스크린샷 이미지 크기와 shadow/radius 품질
  - 기능 요약 4개 항목의 줄바꿈과 간격
  - 모바일 overflow와 과한 줄바꿈 여부
  - 이전 hero 섹션과 다음 Feature sticky 섹션의 연결감
- `docs/script.js` reveal sequence가 변경된 구조에서도 어색하지 않은지 확인한다. 필요 시 timing은 건드리지 않고 markup/CSS만 보정하는 방향을 우선한다.

검증:

```bash
python3 -m http.server 8080 --directory docs
node --check docs/script.js
rg -n "app-intro|reveal|og-main" docs/index.html docs/styles.css docs/script.js
git diff --check -- docs mydocs/working/task_m010_178_stage2.md
```

완료 조건:

- 데스크톱과 모바일에서 두 번째 섹션의 상단 여백, 철학 설명, 스크린샷 크기가 의도대로 보인다.
- 기존 hero, Feature, FAQ 섹션에 눈에 띄는 회귀가 없다.
- `docs/script.js` 문법 검사를 통과한다.
- 검증 결과와 잔여 위험이 단계 보고서에 기록되어 있다.

예상 커밋:

```text
Task #178 Stage 2: 두 번째 섹션 브라우저 검증과 반응형 보정
```

## Stage 3: 최종 보고와 PR 준비

대상:

- `mydocs/report/task_m010_178_report.md`
- `mydocs/orders/20260508.md`
- 필요 시 최종 검증 결과 문서 보강

작업:

- 최종 결과보고서를 작성한다.
- 오늘할일 #178 상태를 완료로 갱신하고 완료 시각을 기록한다.
- 최종 검증 명령을 재실행한다.
- `publish/task178` 원격 브랜치와 `devel-webview` 대상 PR 준비는 `task-final-report` 절차에서 진행한다.

검증:

```bash
rg -n "Issue #178|두 번째 섹션|검증 결과|잔여 위험" mydocs/report/task_m010_178_report.md
rg -n "#178 .*완료" mydocs/orders/20260508.md
git diff --check -- docs mydocs
git status --short
```

완료 조건:

- 최종 보고서가 작성되어 있다.
- 오늘할일 #178이 완료 처리되어 있다.
- 작업 브랜치의 변경이 모두 커밋되어 PR 게시 가능한 상태다.

예상 커밋:

```text
Task #178 Stage 3 + 최종 보고서: 두 번째 섹션 보강 완료
```

## 승인 요청 사항

이 구현 계획서 기준으로 Stage 1 `두 번째 섹션 HTML/CSS 보강`을 진행할지 승인 요청한다. 승인 전에는 `docs/` 구현 파일 변경을 진행하지 않는다.
