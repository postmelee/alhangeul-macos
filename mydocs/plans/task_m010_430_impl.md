# Issue #430 구현 계획서

## 작업명

GitHub Pages 하단 철학 문구와 Open Graph 설명 보강

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_430.md`를 기준으로 진행한다.
- 작업 브랜치는 `local/task430`, 통합 대상은 `devel`로 둔다.
- Task 시작 전에 시각 검토를 마친 시안은 `stash@{0}`의 `Task #430 approved Pages philosophy prototype`으로 보존되어 있다.
- 승인 시안은 그대로 복원하지 않고 변경 대상과 footer 무손실 여부를 확인한 뒤 `docs/index.html`, `docs/styles.css`에만 선택 적용한다.
- Open Graph 설명은 `Mac에서 HWP/HWPX를 미리보고 편집하고 공유하는 오픈소스 앱입니다.`로 고정한다.
- 철학 섹션은 FAQ 다음이자 footer 직전인 본문 최하단에 둔다.
- 철학 제목은 `문서 접근은 특정 프로그램 구매 여부에 묶이면 안 됩니다.`로 고정하고, `문서 접근`과 `특정 프로그램 구매 여부`에만 기존 섹션 헤더와 같은 600 굵기를 적용한다.
- `문서 접근`에만 기존 accent 색상을 적용하고 나머지 제목은 본문색을 유지한다.
- 제목 크기는 기존 섹션 헤더와 같은 데스크톱 40px, 태블릿 38px, 모바일 32px로 맞춘다.
- 철학 섹션의 위아래 여백은 데스크톱 `clamp(88px, 10vh, 120px)`, 모바일 68px로 대칭 적용한다.
- footer 문구, 앱 소스, Pages workflow, appcast, 릴리스 자산은 변경하지 않는다.
- 각 단계 완료 후 결과를 기록하고 작업지시자 승인 없이 다음 단계로 진행하지 않는다.
- `main` 승격과 public Pages 배포는 구현 PR merge 뒤 별도 승인 지점으로 둔다.

## 사전 조사 요약

- 현행 `docs/index.html`의 본문 최하단은 FAQ 섹션 뒤에 바로 footer가 이어지며 독립 철학 섹션이 없다.
- 현행 Open Graph 설명은 프로젝트 철학과 제품 기능을 한 문장에 함께 담고 있어 링크 공유 설명으로는 길다.
- 현행 footer에는 `Mac을 위한 HWP/HWPX 문서 미리보기 및 편집 앱입니다. 한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다.`가 있으며 이번 변경에서는 그대로 유지한다.
- 승인 시안 diff의 변경 대상은 `docs/index.html`, `docs/styles.css` 두 파일뿐이다. 업데이트·문의/제보 페이지와 footer 변경은 포함되지 않았다.
- 승인 시안은 철학 섹션을 FAQ 뒤, `</main>` 앞에 배치하고 기존 reveal 속성을 재사용한다.
- 승인 시안은 제목 전체를 400 굵기로 두고 두 핵심 구절만 600 굵기로 올린다. `문서 접근`에는 `var(--accent)`, 설명에는 `var(--muted)`를 재사용한다.
- `.github/workflows/pages-docs-deploy.yml`은 `main`의 `docs/**` push 또는 수동 실행에서 동작한다. 공개 appcast를 다운로드·XML 검증한 뒤 `prepare-pages-artifact.sh`로 Pages artifact에 포함한다.
- `origin/main...origin/devel`에는 Task #430 외 차이가 있으므로 `devel` 대상 PR merge가 곧바로 public Pages 배포를 의미하지 않는다. `main` 승격 범위는 배포 직전에 다시 확인하고 승인받아야 한다.

## Stage 1: 구현 경계 확정과 구현계획서 작성

대상:

- `mydocs/plans/task_m010_430_impl.md`
- `mydocs/working/task_m010_430_stage1.md`

작업:

- 현행 Pages 홈 구조와 footer 원문을 확인한다.
- 보존된 승인 시안 diff에서 변경 파일, 문구, 위치, type scale, 반응형 여백을 확인한다.
- docs-only Pages workflow의 실행 브랜치와 public appcast 보존 절차를 확인한다.
- Task #430의 구현·검증·PR·배포 단계를 분리하고 각 단계 완료 조건을 문서화한다.
- `main` 승격에 Task #430 외 변경이 포함될 수 있는 위험을 배포 전 별도 승인 사항으로 기록한다.

검증:

```bash
rg -n "Stage 1|Stage 2|Stage 3|Stage 4|Stage 5|footer|appcast|main" mydocs/plans/task_m010_430_impl.md
git diff --check -- mydocs/plans/task_m010_430_impl.md mydocs/working/task_m010_430_stage1.md
git status --short
```

완료 조건:

- 승인 시안과 현행 파일의 차이가 두 구현 파일로 한정됨을 확인했다.
- footer 무손실, appcast 보존, `main` 승격 승인 지점이 구현계획에 명시되어 있다.
- 구현계획서와 Stage 1 보고서가 한 커밋에 포함되어 있다.

예상 커밋:

```text
Task #430 Stage 1: 구현 경계와 배포 계획 확정
```

## Stage 2: 승인된 철학 섹션과 Open Graph 설명 구현

대상:

- `docs/index.html`
- `docs/styles.css`
- `mydocs/working/task_m010_430_stage2.md`

작업:

- `docs/index.html`의 Open Graph 설명을 승인 문구로 교체한다.
- FAQ 다음, footer 직전 본문 최하단에 독립 철학 섹션을 추가한다.
- 제목과 보조 설명에 승인된 문구와 강조 범위를 적용한다.
- 기존 reveal 구조와 CSS cache-busting query를 승인 시안 기준으로 반영한다.
- `docs/styles.css`에 철학 섹션의 폭, 경계선, 대칭 여백, 제목/설명 type scale과 반응형 규칙을 추가한다.
- footer 원문과 다른 페이지의 footer가 변경되지 않았는지 확인한다.

검증:

```bash
rg -n "og:description|philosophy-section|philosophy-title|philosophy-highlight|philosophy-emphasis" docs/index.html docs/styles.css
rg -n "한글 파일이 더 이상 낯선 파일로 남지 않도록 만듭니다" docs/index.html docs/updates/index.html docs/feedback/index.html
node --check docs/script.js
git diff --check -- docs/index.html docs/styles.css mydocs/working/task_m010_430_stage2.md
```

완료 조건:

- Open Graph 설명, 철학 문구, 위치와 강조 범위가 승인안과 일치한다.
- 데스크톱·태블릿·모바일 제목 크기와 위아래 대칭 여백이 CSS에 반영되어 있다.
- footer 원문과 다른 Pages 문서는 변경되지 않았다.
- 구현 변경과 Stage 2 보고서가 한 커밋에 포함되어 있다.

예상 커밋:

```text
Task #430 Stage 2: 철학 섹션과 Open Graph 설명 반영
```

## Stage 3: 브라우저 시각 검증과 Pages artifact 사전 검증

대상:

- 필요 시 `docs/index.html`
- 필요 시 `docs/styles.css`
- `mydocs/working/task_m010_430_stage3.md`
- 필요 시 `mydocs/working/assets/task_m010_430_stage3_*.png`

작업:

- 로컬 정적 서버에서 데스크톱과 모바일 폭의 홈을 확인한다.
- FAQ 다음 철학 섹션 위치, 제목 위계, 한국어 줄바꿈, 대칭 여백과 footer 연결을 확인한다.
- 가로 overflow, reveal 동작, 기존 FAQ/footer 회귀를 확인하고 필요한 범위에서만 CSS를 보정한다.
- 업데이트 릴리스 문구 정합성 검사를 실행한다.
- 현재 공개 appcast를 임시 파일로 받아 XML을 검증한다.
- `prepare-pages-artifact.sh`로 로컬 Pages artifact를 만들고 홈·업데이트 페이지·appcast 포함 여부를 확인한다.

검증:

```bash
node --check docs/script.js
scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml -o /tmp/task430-public-appcast.xml
xmllint --noout /tmp/task430-public-appcast.xml
scripts/ci/prepare-pages-artifact.sh --docs-dir docs --appcast /tmp/task430-public-appcast.xml --output-dir build.noindex/task430-pages-artifact
test -f build.noindex/task430-pages-artifact/index.html
test -f build.noindex/task430-pages-artifact/updates/index.html
xmllint --noout build.noindex/task430-pages-artifact/appcast.xml
git diff --check -- docs mydocs/working/task_m010_430_stage3.md
```

완료 조건:

- 데스크톱과 모바일에서 승인한 철학 섹션의 위계와 여백이 유지된다.
- 기존 FAQ, footer와 다른 Pages 문서에 눈에 띄는 회귀가 없다.
- Pages artifact가 생성되고 공개 appcast가 유효한 XML로 보존된다.
- 검증 결과와 잔여 위험이 Stage 3 보고서에 기록되어 있다.

예상 커밋:

```text
Task #430 Stage 3: Pages 시각 및 artifact 검증 완료
```

## Stage 4: 최종 보고와 devel 대상 PR 게시

대상:

- `mydocs/report/task_m010_430_report.md`
- `mydocs/orders/20260721.md`
- 필요 시 최종 검증 결과 문서 보강

작업:

- 구현·시각·artifact 검증 결과와 잔여 위험을 최종 결과보고서에 정리한다.
- 오늘할일 #430을 완료 처리하고 완료 시각을 기록한다.
- 최종 검증을 재실행한다.
- `task-final-report` 절차에 따라 `publish/task430`을 push하고 `devel` 대상 Open PR을 생성한다.
- PR 검증 결과를 확인하고 merge 승인을 요청한다.

검증:

```bash
rg -n "Issue #430|철학|Open Graph|appcast|검증 결과|잔여 위험" mydocs/report/task_m010_430_report.md
rg -n "#430 .*완료" mydocs/orders/20260721.md
node --check docs/script.js
git diff --check -- docs mydocs
git status --short
```

완료 조건:

- 최종 결과보고서와 오늘할일 완료 기록이 작성되어 있다.
- 작업 브랜치 변경이 모두 커밋되어 있다.
- `publish/task430` 원격 브랜치와 `devel` 대상 PR이 준비되어 있다.
- PR merge와 이후 배포는 별도 승인 전 실행하지 않는다.

예상 커밋:

```text
Task #430 Stage 4 + 최종 보고서: Pages 철학 문구 보강 완료
```

## Stage 5: 승인된 main 승격과 public Pages 배포 검증

대상:

- 기존 `Docs-only Pages Deploy` workflow 실행 결과
- 공개 `https://postmelee.github.io/alhangeul-macos/`
- 공개 `https://postmelee.github.io/alhangeul-macos/appcast.xml`
- 필요 시 Task #430 최종 보고 기록 보강

작업:

- Task #430 PR merge 뒤 `origin/main...origin/devel` 차이와 `main` 승격 포함 범위를 다시 제시한다.
- 작업지시자가 승인한 경로로만 Task #430을 `main`에 반영한다.
- `main`의 `docs/**` 변경으로 실행된 `Docs-only Pages Deploy` workflow를 확인한다.
- workflow의 release asset gate, artifact 준비, `deploy-pages` job 성공 여부를 확인한다.
- 공개 홈에서 Open Graph 설명과 철학 섹션 문구·위치·스타일을 확인한다.
- 배포 전후 공개 appcast의 최신 item과 enclosure URL이 유지되는지 확인한다.
- 배포 결과를 Task #430 기록에 보강하고, merge/이슈 close/브랜치 정리는 별도 승인 절차에 따른다.

검증:

```bash
git rev-list --left-right --count origin/main...origin/devel
curl -fsSL https://postmelee.github.io/alhangeul-macos/ -o /tmp/task430-public-index.html
rg -n "Mac에서 HWP/HWPX를 미리보고 편집하고 공유하는 오픈소스 앱입니다|philosophy-section|문서 접근|특정 프로그램 구매 여부" /tmp/task430-public-index.html
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml -o /tmp/task430-deployed-appcast.xml
xmllint --noout /tmp/task430-deployed-appcast.xml
```

완료 조건:

- 승인 범위를 벗어난 변경 없이 Task #430이 `main`에 반영되었다.
- Docs-only Pages workflow가 성공했다.
- 공개 홈에서 승인 문구와 레이아웃을 확인했다.
- public appcast의 최신 배포 정보가 보존되었다.
- 배포 결과와 남은 운영 조치가 기록되었다.

## 승인 요청 사항

이 구현 계획서의 Stage 2 `승인된 철학 섹션과 Open Graph 설명 구현`을 진행할지 승인 요청한다. 승인 전에는 보존한 시안을 `docs/`에 적용하지 않는다.

Stage 3 이후도 각 단계 보고서를 검토받은 뒤 진행한다. Stage 5의 `main` 승격과 public Pages 배포는 Task #430 PR merge 뒤 당시의 브랜치 차이를 제시하고 별도 승인을 받는다.
