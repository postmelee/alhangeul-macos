# Task M018 #212 구현계획서

수행계획서: `mydocs/plans/task_m018_212.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #212 GitHub Pages 홍보 페이지 footer와 업데이트 안내 UX 보강
- 마일스톤: M018 (`v0.1.1`)
- 브랜치: `local/task212`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac/build.noindex/worktrees/task212`
- 기준 브랜치: `devel-webview`
- 선행 상태: #208 완료 후 Pages 최신 다운로드와 단일 universal DMG 안내가 반영되어 있다.
- 충돌 고려: #206은 `/Users/melee/Documents/projects/rhwp-mac`의 `local/task206`에서 진행 중이며 Pages/appcast 배포 방식 전환을 다룬다.
- 목표: 정적 Pages의 footer 문구, `/updates/` 업데이트 안내, footer responsive layout을 사용자-facing 범위에서 보강한다.

## 확인된 현재 상태

2026-05-10 기준 확인 결과:

- #206 현재 변경 파일은 `mydocs/orders/20260510.md`, `mydocs/plans/task_m018_206.md`, `mydocs/plans/task_m018_206_impl.md`, `mydocs/working/task_m018_206_stage1.md`로 제한되어 있다.
- #206 구현계획상 향후 변경 대상은 `.github/workflows/release-publish.yml`, `scripts/ci/prepare-pages-artifact.sh`, release/CI 매뉴얼과 release record다.
- #206 수행계획은 Pages site redesign 또는 사용자-facing copy 전면 수정을 제외한다.
- #212는 `docs/` HTML/CSS와 task 문서만 수정해 #206 workflow/helper 변경과 책임 경계를 분리한다.
- 현재 footer 문구는 홈과 업데이트/릴리즈 노트 페이지가 서로 다르다.
- 현재 `/updates/`는 “수동 확인”, “자동 확인”, “Sparkle appcast URL”을 구현 관점으로 크게 노출한다.
- 현재 footer CSS는 `1180px` 이하에서 2열로 바뀌며 nav가 설명 아래로 내려갈 수 있다.

## 구현 원칙

- Footer 제품 문구는 작업지시자가 지정한 문구로 통일한다.
  - `Mac을 위한 HWP/HWPX 문서 미리보기 및 편집 앱입니다. 한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다.`
- `/updates/`는 일반 사용자 안내 페이지로 취급한다. Sparkle, feed, appcast 같은 구현 용어는 필요할 때만 보조 설명으로 사용한다.
- appcast URL은 앱의 고정 업데이트 feed이므로 유지하되, 사용자가 직접 조작해야 하는 필수 절차처럼 보이지 않게 한다.
- desktop과 중간 화면 폭에서는 footer 브랜드, 설명, nav를 한 행에 유지한다. 설명 문구만 중앙 영역에서 줄바꿈되게 한다.
- mobile에서는 1열 stack을 허용하되 브랜드, 문구, 링크 간격과 wrapping이 자연스럽게 보이도록 한다.
- #206과 충돌하지 않도록 `.github/`, `scripts/ci/`, `docs/appcast.xml`, release workflow, Pages settings 문서는 수정하지 않는다.

## Stage 1. 현황 고정과 충돌 범위 확정

### 목표

#206과 #212의 변경 경계를 단계 보고서로 고정하고, 실제 구현에서 수정할 `docs/` HTML/CSS 위치와 검증 viewport를 확정한다.

### 작업

- `local/task206`의 현재 변경 파일과 구현계획을 확인한다.
- #212 대상 파일의 footer 문구, `/updates/` 업데이트 안내, appcast URL 섹션, footer CSS breakpoint 위치를 정리한다.
- #206과 겹치지 않는 수정 파일 목록을 확정한다.
- Stage 1 보고서에 구현 범위와 제외 범위를 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m018_212_stage1.md`

### 검증

```bash
git status --short --branch
git diff --name-status origin/devel-webview...local/task206
rg -n "Mac을 위한 HWP/HWPX|수동 확인|자동 확인|Sparkle appcast|site-footer|@media \\(max-width: 1180px\\)" docs
git diff --check
```

### 완료 기준

- #206과 #212의 파일/책임 경계가 보고서에 기록된다.
- 구현 대상과 제외 대상이 명확하다.
- `docs/` source 변경은 아직 수행하지 않는다.

### 커밋 메시지

```text
Task #212 Stage 1: Pages footer 개선 범위 확정
```

## Stage 2. Footer 문구와 업데이트 안내 HTML 보정

### 목표

홈, `/updates/`, 릴리즈 노트 페이지의 footer 문구를 통일하고, `/updates/`의 앱 업데이트 안내를 일반 사용자 관점으로 단순화한다.

### 작업

- `docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.0.html`, `docs/updates/v0.1.1.html` footer 문구를 승인 문구로 통일한다.
- `/updates/`의 “수동 확인/자동 확인” 카드 구조를 제거하거나 단일 안내 구조로 합친다.
- 앱 메뉴 업데이트 확인 흐름과 사용자의 설치 선택권을 간결하게 설명한다.
- appcast URL 섹션은 유지하되 “앱이 사용하는 업데이트 feed 주소”라는 보조 정보로 문구를 조정한다.
- 기존 다운로드 링크와 GitHub Releases 링크는 유지한다.

### 예상 변경 파일

- `docs/index.html`
- `docs/updates/index.html`
- `docs/updates/v0.1.0.html`
- `docs/updates/v0.1.1.html`
- `mydocs/working/task_m018_212_stage2.md`

### 검증

```bash
rg -n "Mac을 위한 HWP/HWPX 문서 미리보기 및 편집 앱|수동 확인|자동 확인|Sparkle appcast URL|업데이트 feed|알한글 > 업데이트 확인" docs
git diff --check
```

### 완료 기준

- 모든 Pages footer 문구가 승인 문구로 통일된다.
- `/updates/`에서 “수동 확인/자동 확인” 구현 중심 카드가 사라지거나 일반 사용자 안내로 합쳐진다.
- appcast URL 자체는 유지된다.

### 커밋 메시지

```text
Task #212 Stage 2: Pages footer 문구와 업데이트 안내 보정
```

## Stage 3. Footer responsive CSS 보정

### 목표

중간 화면 폭에서 footer nav가 설명 아래로 내려가 어색해지는 문제를 해결하고, desktop/mobile footer 정렬을 함께 안정화한다.

### 작업

- `.site-footer` grid/flex 기준을 조정해 넓은 화면과 중간 화면에서 브랜드, 설명, nav가 한 행에 남도록 한다.
- 설명 문구의 중앙 영역 width, wrapping, `word-break`/`text-wrap` 기준을 보정한다.
- `1180px` 이하 breakpoint가 nav를 2행으로 내리는 기존 규칙을 재검토한다.
- mobile breakpoint에서는 1열 stack과 nav wrapping을 유지하되 간격을 정돈한다.
- 필요하면 `/updates/` footer margin이나 content width와 충돌하지 않게 조정한다.

### 예상 변경 파일

- `docs/styles.css`
- `mydocs/working/task_m018_212_stage3.md`

### 검증

```bash
rg -n "site-footer|updates-page \\+ \\.site-footer|@media \\(max-width: 1180px\\)|@media \\(max-width: 820px\\)|@media \\(max-width: 520px\\)" docs/styles.css
git diff --check
```

### 완료 기준

- 중간 화면 폭에서 footer nav가 우측 영역에 유지되도록 CSS가 보정된다.
- mobile stack 동작은 유지된다.
- HTML 변경 없이 CSS만으로 layout 의도가 설명된다.

### 커밋 메시지

```text
Task #212 Stage 3: footer 반응형 정렬 보정
```

## Stage 4. 렌더링 QA와 최종 정리

### 목표

정적 페이지 렌더링으로 footer 문구, `/updates/` 정보 구조, responsive layout을 확인하고 최종 보고/PR 준비 상태로 정리한다.

### 작업

- 로컬 정적 서버로 `docs/`를 열어 홈과 `/updates/`를 확인한다.
- desktop, 중간 폭, mobile viewport에서 footer 정렬과 wrapping을 확인한다.
- `/updates/`의 앱 업데이트 안내와 appcast URL 섹션 위계를 확인한다.
- console error/warn을 확인한다.
- `mydocs/orders/20260510.md` 상태를 완료로 갱신한다.
- 최종 보고서에 변경 파일, 검증 결과, #206 비충돌 범위를 기록한다.
- `task-final-report` 절차로 PR 준비를 진행한다.

### 예상 변경 파일

- `mydocs/orders/20260510.md`
- `mydocs/report/task_m018_212_report.md`

### 검증

```bash
git status --short --branch
git diff --check
python3 -m http.server 8765 --directory docs
```

렌더링 검증:

- `/` desktop viewport
- `/updates/` desktop viewport
- `/updates/` 중간 폭 viewport
- `/updates/` mobile viewport
- page identity, blank-page check, framework overlay 없음, console health, screenshot evidence

### 완료 기준

- 정적 검증과 렌더링 QA가 통과한다.
- #206과 겹치는 workflow/helper/appcast XML 변경이 없다.
- 최종 보고서와 오늘할일 갱신이 커밋된다.
- PR 생성 전 working tree가 clean이다.

### 커밋 메시지

```text
Task #212 Stage 4 + 최종 보고서: Pages footer UX 보강 완료
```

## 승인 요청 사항

1. 위 4단계 구현 구조 승인
2. Stage 1에서 #206과 #212의 변경 경계를 보고서로 고정하는 방향 승인
3. Stage 2에서 `/updates/`의 “수동 확인/자동 확인” 카드를 일반 사용자 안내 문단으로 합치는 방향 승인
4. Stage 3에서 footer 중간 breakpoint를 nav 우측 유지 기준으로 조정하는 방향 승인
5. Stage 4에서 정적 서버와 렌더링 QA 후 최종 보고/PR 준비로 진행하는 방향 승인
