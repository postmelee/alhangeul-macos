# Task #376 구현 계획서

본 문서는 [`task_m040_376.md`](task_m040_376.md) 수행계획서를 단계별 실행 단위로 분해한 것이다. 각 단계 완료 후 [`task-stage-report`](../skills/task-stage-report/SKILL.md) skill로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 환경

- Worktree: `/Users/melee/Documents/projects/rhwp-mac`
- Branch: `local/task376`
- 기준 브랜치: `devel`
- 기준 이슈: [#376](https://github.com/postmelee/alhangeul-macos/issues/376)
- 마일스톤: M040 (`v0.4`)
- 범위: `rhwp Upstream Sync PR` workflow의 base branch 기준 판정과 automation branch blocker 정리

## 구현 원칙

- workflow schedule은 GitHub default branch의 workflow file로 실행되지만, upstream sync 후보의 source of truth는 `BASE_BRANCH=devel`의 repository content로 둔다.
- `rhwp-core.lock`과 bundled `rhwp-studio` manifest의 current 판정은 PR base branch의 파일을 읽어 계산한다.
- 열린 sync PR은 계속 중복 생성 blocker로 취급한다.
- merge 완료 PR의 head branch가 원격에 남아 있는 경우는 opened PR blocker와 구분한다.
- 원격 branch 삭제는 destructive 작업이므로 이번 구현에서는 자동 삭제보다 blocker 오판 방지와 문서화에 집중한다. 실제 삭제는 작업지시자 승인 또는 merge 후 cleanup 절차에서 수행한다.
- public release publish, signing/notarization, Pages/Sparkle, Homebrew 작업은 이번 task에서 실행하지 않는다.

## Stage 1 — 현행 workflow 판정 재현과 설계 확정

### 목표

- `main` checkout 기준 current 판정과 `devel` base branch 기준 current 판정 차이를 작업 문서에 고정한다.
- Stage 2~3에서 바꿀 checkout 기준과 existing branch 판단 규칙을 확정한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/plans/task_m040_376_impl.md` | 구현계획서 작성 | 현재 단계 산출물 |
| `mydocs/working/task_m040_376_stage1.md` | Stage 1 완료보고서 작성 | 현행 run 로그와 설계 결정 기록 |

### 확인할 자료

- Issue #376 본문
- `mydocs/plans/task_m040_376.md`
- `.github/workflows/rhwp-upstream-sync-pr.yml`
- 최신 schedule run `28075879933`의 `resolve-target` job 로그
- PR #359, #369 상태와 head branch 존재 여부
- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/manual/core_dependency_operation_guide.md`

### 설계 결정 기준

- `resolve-target` job의 `current_core_tag`, `current_core_commit`, `current_studio_tag`, `current_studio_commit`은 `BASE_BRANCH` content 기준이어야 한다.
- workflow helper syntax 검증도 base branch checkout 후 실행해 실제 sync PR 생성에 사용할 scripts와 맞춘다.
- `build-studio-assets`와 `create-full-sync-pr` job의 repository checkout도 base branch 기준으로 맞춘다. `create-full-sync-pr`는 어차피 `git switch -c "$branch_name" "origin/$BASE_BRANCH"`로 PR branch를 만들므로 checkout ref와 실제 변경 base가 어긋나지 않게 한다.
- existing automation check는 open PR, merged PR, branch-only 상태를 분리한다.
- branch-only 상태는 이전 run이 branch push 후 PR 생성 전에 실패했을 가능성이 있으므로 계속 blocker로 취급한다.
- merged PR head branch는 blocker로 취급하지 않는 방향을 우선한다. 단, base branch가 current가 아니면 같은 target을 다시 생성할 위험이 있으므로 Stage 3에서 조건을 명확히 한다.

### 단계 검증

```bash
git status --short --branch
git diff --check
rg -n "github.ref|BASE_BRANCH|current_core_tag|current_studio_tag|existing_automation_pr|branch_exists|gh pr list" .github/workflows/rhwp-upstream-sync-pr.yml
```

### 커밋 메시지

```text
Task #376 Stage 1: upstream sync workflow 판정 기준 조사
```

## Stage 2 — base branch 기준 checkout과 current 판정 보강

### 목표

- schedule/manual dispatch 모두에서 sync 필요 여부를 `BASE_BRANCH=devel` content 기준으로 계산하게 한다.
- target release 조회, compatibility check, impact detection 입력이 같은 base branch scripts와 lock/manifest를 사용하게 한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | checkout ref와 summary 문구 보강 | `resolve-target`, `build-studio-assets`, `create-full-sync-pr` 중심 |
| `mydocs/working/task_m040_376_stage2.md` | Stage 2 완료보고서 작성 | checkout 기준과 로컬 검증 결과 기록 |

### 반영 기준

- `resolve-target`의 checkout step은 `ref: ${{ env.BASE_BRANCH }}` 또는 동등하게 base branch content를 읽는 방식으로 수정한다.
- helper syntax 검증은 base branch checkout 후 실행한다.
- `build-studio-assets` checkout도 `BASE_BRANCH` 기준으로 맞춰 `scripts/update-rhwp-core.sh`, `scripts/sync-rhwp-studio.sh`, 검증 helper가 PR base와 같은 버전을 쓰게 한다.
- `create-full-sync-pr` checkout도 `BASE_BRANCH` 기준으로 맞추되, `persist-credentials: false`와 GitHub App token 사용 구조는 유지한다.
- workflow summary에는 workflow ref와 base branch를 구분해, schedule은 default branch workflow로 실행되지만 판정 content는 base branch라는 점이 드러나게 한다.
- `workflow_dispatch`의 `target_tag`, `dry_run`, `force_pr` 입력 의미는 유지한다.

### 단계 검증

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml")'
git diff --check
rg -n "ref:.*BASE_BRANCH|workflow ref|base branch|current core tag|full sync current" .github/workflows/rhwp-upstream-sync-pr.yml
```

### 커밋 메시지

```text
Task #376 Stage 2: sync workflow base branch 판정 적용
```

## Stage 3 — existing automation branch와 PR blocker 판단 보강

### 목표

- 같은 target automation branch가 남아 있어도 열린 PR과 merge 완료 PR을 구분한다.
- merge 완료 head branch가 남아 있는 상태를 workflow가 stale blocker로 오판하지 않게 한다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | existing check output과 decision logic 보강 | open/merged/branch-only 상태 구분 |
| `mydocs/working/task_m040_376_stage3.md` | Stage 3 완료보고서 작성 | blocker matrix와 검증 결과 기록 |

### 반영 기준

- `Check existing automation PR` step은 다음 상태를 output과 summary에 구분해 남긴다.
  - `open_pr_url`: 같은 base/head의 열린 PR
  - `merged_pr_url` 또는 merged 상태: 같은 base/head의 merge 완료 PR
  - `branch_exists`: 원격 automation branch 존재 여부
  - `exists` 또는 blocker 값: 새 PR 생성을 막아야 하는지 여부
- 열린 PR이 있으면 기존처럼 `decision=existing_automation_pr`로 둔다.
- 원격 branch만 있고 PR이 없으면 branch push 후 PR 생성 실패 가능성이 있으므로 blocker로 유지한다.
- merge 완료 PR이 있고 branch만 남은 경우는 blocker로 보지 않는다. 이 경우 base branch current 판정이 true이면 `decision=current`로 끝나고, current가 false이면 새 sync 필요 상태로 이어질 수 있으므로 Stage 2의 base branch current 판정이 먼저 정확해야 한다.
- summary에는 merge 완료 branch가 남아 있어도 blocker가 아니라 cleanup 후보라는 점을 명확히 표시한다.

### 단계 검증

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml")'
git diff --check
rg -n "open_pr|merged_pr|branch_exists|existing_automation_pr|branch_only|cleanup" .github/workflows/rhwp-upstream-sync-pr.yml
```

가능하면 `gh pr list` 명령의 `--jq` 표현은 로컬에서 read-only로 dry 확인한다.

```bash
gh pr list --repo postmelee/alhangeul-macos --base devel --head automation/rhwp-v0.7.17-full-sync --state all --json url,state,mergedAt --jq '.[0] // {}'
```

### 커밋 메시지

```text
Task #376 Stage 3: merged automation branch blocker 구분
```

## Stage 4 — 문서 정리와 최종 검증

### 목표

- CI/core 운영 문서가 base branch 기준 판정과 automation branch lifecycle을 정확히 설명하게 한다.
- 현재 남아 있는 remote automation branch 정리 권고를 최종 보고서에 남긴다.

### 변경 파일과 작업

| 파일 | 작업 | 비고 |
|------|------|------|
| `mydocs/manual/ci_workflow_guide.md` | upstream sync workflow 기준 보강 | base branch 판정, blocker 기준 |
| `mydocs/manual/core_dependency_operation_guide.md` | full sync provenance 설명 보강 | base branch 기준과 cleanup 경계 |
| `mydocs/report/task_m040_376_report.md` | 최종 결과보고서 작성 | 검증 결과와 남은 운영 확인 기록 |
| `mydocs/orders/20260624.md` | 작업 상태 완료 처리 | 최종 보고 단계 |

### 반영 기준

- `ci_workflow_guide.md`의 유지 조건에 "current 판정은 base branch content 기준"을 명시한다.
- 같은 automation branch 또는 open PR 문구는 열린 PR, branch-only blocker, merged branch cleanup 후보를 구분하는 문구로 바꾼다.
- `core_dependency_operation_guide.md`에는 full sync 후보 PR이 `devel` 기준 provenance로 판단된다는 점을 짧게 보강한다.
- 원격 branch 삭제는 자동 수행하지 않는다. 최종 보고서에서 `automation/rhwp-v0.7.16-full-sync`, `automation/rhwp-v0.7.17-full-sync` 삭제 권고와 승인 필요성을 분리해 기록한다.

### 최종 검증

```bash
git status --short --branch
git diff --check
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml")'
bash -n scripts/ci/check-rhwp-upstream-release.sh scripts/ci/detect-rhwp-studio-impact.sh scripts/ci/read-rhwp-core-lock.sh scripts/ci/write-rhwp-full-sync-pr-body.sh
scripts/ci/detect-rhwp-studio-impact.sh --help
scripts/ci/read-rhwp-core-lock.sh --help
scripts/ci/write-rhwp-full-sync-pr-body.sh --help
rg -n "BASE_BRANCH|current_core_tag|current_studio_tag|existing_automation_pr|automation/rhwp|rhwp Upstream Sync PR|base branch" .github/workflows/rhwp-upstream-sync-pr.yml mydocs/manual
```

GitHub-hosted schedule run은 로컬에서 완전 재현할 수 없으므로, PR merge 이후 첫 `rhwp Upstream Sync PR` schedule run에서 `current=true` 또는 기대 decision을 확인하는 항목을 최종 보고서에 남긴다.

### 커밋 메시지

```text
Task #376 Stage 4 + 최종 보고서: upstream sync workflow 기준 정리
```

## 승인 요청 사항

이 구현계획서 승인 후 Stage 1 현행 workflow 판정 재현과 설계 확정 작업을 시작한다.
