# Task M013 #244 구현계획서

## 구현 목표

`devel-webview`에 누적된 제품/배포 라인을 외부 기여 기본 브랜치인 `devel`로 승격하고, 기존 `devel`의 Swift native viewer/editor 라인은 별도 보존 브랜치로 분리한다. 최종 산출물은 branch topology 조사 보고, 전환 runbook, 문서/워크플로우 정렬, 승인된 범위의 원격 브랜치 전환 또는 전환 직전 checklist, 최종 보고서다.

## Stage 1: branch topology와 참조 inventory 정리

### 작업 범위

- `origin/main`, `origin/devel-webview`, `origin/devel`의 공통 조상, ahead/behind, cherry-pick 제외 commit 수를 확인한다.
- `git merge-tree`로 `devel <- devel-webview`, `main <- devel-webview`, 필요 시 `devel <- main` 가상 병합 충돌을 기록한다.
- `.github/workflows`, `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `mydocs/manual`, `mydocs/tech`에서 `devel-webview`, `devel`, PR base, 통합 브랜치, branch filter 참조를 inventory로 정리한다.
- 현재 열린 이슈/PR 중 branch 전환에 영향을 받을 수 있는 항목을 `gh` 조회로 확인한다.

### 산출물

- `mydocs/working/task_m013_244_stage1.md`

### 검증

```bash
git status --short --branch
git fetch origin
git rev-list --left-right --count origin/devel...origin/devel-webview
git rev-list --left-right --cherry-pick --count origin/devel...origin/devel-webview
git rev-list --left-right --count origin/main...origin/devel-webview
git merge-tree --write-tree --name-only --messages origin/devel origin/devel-webview
git merge-tree --write-tree --name-only --messages origin/main origin/devel-webview
rg -n "devel-webview|native viewer|native renderer|PR base|통합 브랜치|branch filter|publish/task|local/task" README.md CONTRIBUTING.md AGENTS.md .github mydocs/manual mydocs/tech
git diff --check
```

`git merge-tree`와 `gh` 조회는 네트워크 또는 Git metadata 쓰기 권한이 필요할 수 있으므로 실패 시 승인된 권한으로 재실행한다.

### 커밋

```text
Task #244 Stage 1: 브랜치 전환 inventory 정리
```

## Stage 2: 전환 정책과 runbook 확정

### 작업 범위

- Stage 1 조사 결과를 바탕으로 새 제품 개발 기준 commit 범위를 확정한다.
- 기존 `devel` 보존 브랜치 이름 후보를 비교하고 하나를 선택한다.
- `devel-webview`를 legacy alias로 일정 기간 유지할지, 언제 삭제할지 정책을 정리한다.
- 원격 브랜치 전환 runbook을 작성한다.
- GitHub repository setting에서 별도 수동 확인이 필요한 항목을 분리한다.

### 산출물

- `mydocs/tech/branch_strategy_webview_native.md` 또는 신규 branch migration runbook 문서
- `mydocs/working/task_m013_244_stage2.md`

### 검증

```bash
git diff --check
rg -n "native-viewer|legacy|devel-webview|branch migration|브랜치 전환|default branch|branch protection" mydocs/tech mydocs/manual
```

### 커밋

```text
Task #244 Stage 2: 브랜치 전환 runbook 확정
```

## Stage 3: 기여자/에이전트 문서 정렬

### 작업 범위

- `README.md`, `CONTRIBUTING.md`, `AGENTS.md`의 branch 역할과 PR base 안내를 새 정책에 맞게 갱신한다.
- `mydocs/manual/git_workflow_guide.md`, `task_workflow_guide.md`, `pr_process_guide.md`의 통합 브랜치 기준을 정렬한다.
- `mydocs/tech/project_architecture.md`와 branch strategy 문서에서 HostApp/WebView/native 경계 설명을 새 브랜치명에 맞게 갱신한다.
- 외부 기여자가 일반 제품 변경은 `devel`, Swift native viewer/editor 변경은 native 보존 브랜치로 보내도록 짧은 안내를 고정한다.

### 산출물

- `README.md`
- `CONTRIBUTING.md`
- `AGENTS.md`
- `mydocs/manual/git_workflow_guide.md`
- `mydocs/manual/task_workflow_guide.md`
- `mydocs/manual/pr_process_guide.md`
- `mydocs/tech/branch_strategy_webview_native.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/working/task_m013_244_stage3.md`

### 검증

```bash
git diff --check
rg -n "devel-webview|native-viewer|통합 브랜치|PR base|Swift native|WKWebView" README.md CONTRIBUTING.md AGENTS.md mydocs/manual mydocs/tech
```

### 커밋

```text
Task #244 Stage 3: 브랜치 정책 문서 정렬
```

## Stage 4: workflow와 PR template 정렬

### 작업 범위

- `.github/pull_request_template.md`의 PR base 안내를 새 정책에 맞게 갱신한다.
- `.github/workflows/pr-ci.yml`, `release-publish.yml`, `release-rehearsal.yml`, `rhwp-upstream-check.yml`에서 branch filter와 자동화 문구를 점검하고 필요한 부분을 수정한다.
- release publish는 `main` tag 기준 원칙을 유지하고, rehearsal/PR CI가 새 `devel` 기준을 따르도록 정렬한다.
- workflow 변경이 크면 YAML parse와 shell helper syntax를 실행한다.

### 산출물

- `.github/pull_request_template.md`
- `.github/workflows/pr-ci.yml`
- `.github/workflows/release-publish.yml`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/rhwp-upstream-check.yml`
- `mydocs/working/task_m013_244_stage4.md`

### 검증

```bash
git diff --check
ruby -e 'ARGV.each { |path| require "psych"; Psych.parse_file(path); puts path }' .github/workflows/*.yml
rg -n "devel-webview|devel|native-viewer|branches:|base_ref|github.base_ref" .github
```

### 커밋

```text
Task #244 Stage 4: 브랜치 기준 workflow 정렬
```

## Stage 5: 승인된 원격 브랜치 전환 실행 또는 handoff 고정

### 작업 범위

- Stage 2 runbook과 Stage 3-4 문서 정렬이 승인된 뒤에만 원격 브랜치 전환을 실행한다.
- 작업지시자가 원격 전환 실행을 승인하면 다음 계열 작업을 수행한다.
  - 기존 `origin/devel` head를 native 보존 브랜치로 push
  - 새 제품 개발 기준을 `origin/devel`로 반영
  - `origin/devel-webview`를 legacy alias로 유지하거나 승인된 정책에 따라 처리
  - 원격 ref와 로컬 branch tracking 상태 확인
- 원격 전환 실행을 이번 PR 범위에서 보류하기로 하면 최종 실행 checklist와 GitHub repository setting handoff를 문서에 고정한다.

### 산출물

- branch migration 실행 기록 또는 실행 보류 handoff
- `mydocs/working/task_m013_244_stage5.md`

### 검증

```bash
git ls-remote --heads origin main devel devel-webview native-viewer
git status --short --branch
git diff --check
```

원격 push, branch delete, branch protection/default branch 변경은 모두 작업지시자의 해당 단계 명시 승인 후에만 수행한다.

### 커밋

```text
Task #244 Stage 5: 브랜치 전환 실행 기준 정리
```

## Stage 6: 최종 검증과 보고

### 작업 범위

- 전체 문서와 workflow에서 새 branch policy 참조가 일관되는지 점검한다.
- 수행계획서와 구현계획서의 포함/제외 범위가 지켜졌는지 확인한다.
- 최종 결과보고서를 작성하고 오늘할일 상태를 갱신한다.
- PR 게시 또는 후속 수동 설정 항목을 정리한다.

### 산출물

- `mydocs/report/task_m013_244_report.md`
- `mydocs/orders/20260514.md`

### 검증

```bash
git diff --check
rg -n "devel-webview|devel|native-viewer|통합 브랜치|PR base|branch protection|default branch" README.md CONTRIBUTING.md AGENTS.md .github mydocs/manual mydocs/tech mydocs/report/task_m013_244_report.md
git status --short --branch
```

### 커밋

```text
Task #244 Stage 6 + 최종 보고서: 브랜치 승격 정리
```

## PR 계획

- 작업 브랜치: `local/task244`
- 게시 브랜치: `publish/task244`
- 대상 브랜치: 전환 전에는 `devel-webview`, 전환 실행 후에는 Stage 5 결과 기준으로 결정
- PR 제목 후보: `Promote devel as the product contribution branch`
- PR 본문에는 branch topology 조사 결과, native 보존 브랜치 이름, workflow 변경, 원격 전환 실행 여부, 남은 repository setting handoff를 명시한다.

## 변경 금지 사항

- Stage 5 승인 전에는 원격 `devel`, `devel-webview`, native 보존 브랜치를 push/delete/force-update하지 않는다.
- branch protection, default branch, repository setting은 로컬 명령으로 우회하지 않는다.
- `local/task243` worktree의 미추적/미커밋 변경을 수정하거나 staging하지 않는다.
- Swift/Rust 제품 기능 코드를 branch 정책 전환 명목으로 수정하지 않는다.
- public release, tag 생성, GitHub Release 게시를 수행하지 않는다.
