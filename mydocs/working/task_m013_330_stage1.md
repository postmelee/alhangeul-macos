# Task M013 #330 Stage 1 보고서

## 단계 목적

GitHub 공개 본문/코멘트 등록 경로와 PR review request 해소 경로를 조사해, `scripts/validate-github-body.sh` 적용 대상과 제외 대상을 확정한다.

## 조사 명령

```bash
rg -n "gh (issue|pr) (create|comment|review|edit)|reviewRequests|reviewDecision|--body-file|--body " mydocs/skills mydocs/manual scripts .github
rg --files mydocs/skills | sort
gh pr view 328 --repo postmelee/alhangeul-macos --json number,state,reviewRequests,reviews,reviewDecision,mergedAt,url
gh pr review --help
gh pr edit --help
git diff --check
git status --short --branch
```

## 현재 tracked Skill 상태

| Skill | tracked 여부 | 판단 |
|------|--------------|------|
| `external-pr-review` | 있음 | 외부 PR 검토 단계에서 review 등록 절차를 추가할 대상 |
| `external-pr-complete` | 없음 | 기준 브랜치에 없으므로 이 task에서 직접 수정하지 않고 후속 handoff로 기록 |
| `task-final-report` | 있음 | PR body file 생성 후 validator 호출을 추가할 대상 |
| `task-register` | 있음 | Issue body를 inline `--body`에서 `--body-file` 기반으로 바꿀 대상 |
| `pr-merge-cleanup` | 있음 | issue close 중심이며 공개 body 등록 경로는 없음 |
| `task-stage-report`, `task-start` | 있음 | 공개 GitHub body 등록 경로는 없음 |

## GitHub 공개 body 등록 경로 inventory

| 경로 | 현재 명령/패턴 | 문제 | Stage 3 처리 |
|------|----------------|------|--------------|
| `mydocs/skills/task-register/SKILL.md` | `gh issue create ... --body "{본문}"` | 긴 Issue body가 inline 문자열이라 validator를 끼우기 어렵고 quoting 위험이 있음 | `/tmp/issue_{N}_body.md` 같은 body file 작성, validator 통과 후 `--body-file` 사용으로 보정 |
| `mydocs/skills/task-final-report/SKILL.md` | `gh pr create ... --body-file "$PR_BODY"` | body-file은 이미 사용하지만 validator 호출이 없음 | `gh pr create` 직전 `scripts/validate-github-body.sh "$PR_BODY"` 추가 |
| `mydocs/skills/external-pr-review/SKILL.md` | `reviewDecision` 조회만 있고 공개 review/comment 등록 절차 없음 | merge 권고 후 실제 GitHub review를 남기지 않으면 reviewer request가 해소되지 않을 수 있음 | 작업지시자 승인 후 `gh pr review {N} --approve/--comment --body-file {file}` + validator 절차 추가 |
| `mydocs/manual/pr_process_guide.md` | `gh pr create --body-file` 예시 | body-file 우선 원칙은 있으나 validator 원칙 없음 | PR body file 생성 후 validator 통과 원칙 추가 |
| `mydocs/manual/git_workflow_guide.md` | `gh pr create --body-file`, `gh pr review --approve` 예시 | review body가 없는 approve 예시만 있고, 공개 review body 검증 원칙 없음 | 필요 시 review body가 있을 때 `--body-file` + validator 사용 원칙 추가 |
| `.github/workflows/rhwp-upstream-sync-pr.yml` | generated `body_file`로 `gh pr create --body-file "$body_file"` | workflow-generated body file이며 사람이 직접 작성하는 공개 comment가 아님 | 이번 task에서는 직접 보정 대상에서 제외. 필요 시 Stage 3에서 공통 validator 호출 가능성만 재검토 |

## PR review request 관측

PR #328은 merge 완료 상태지만 review request가 남아 있다.

```json
{
  "state": "MERGED",
  "reviewRequests": [{"login": "postmelee"}],
  "reviews": [],
  "reviewDecision": ""
}
```

판단:

- PR 완료 comment는 GitHub review가 아니므로 reviewer request를 해소하지 못한다.
- merge 가능 권고가 난 외부 PR에서는 merge 전에 `external-pr-review` 단계에서 실제 GitHub review를 등록하는 흐름이 가장 자연스럽다.
- 이미 merge된 PR에서 잔여 request가 남은 경우에는 사후 approve보다 `gh pr edit {N} --remove-reviewer {login}`로 request를 정리하는 편이 기록상 자연스럽다.
- 기준 브랜치에 `external-pr-complete`가 없으므로, merge 후 잔여 `reviewRequests` 확인과 cleanup은 이번 task 최종 보고서의 handoff로 남긴다.

## `gh` 기능 확인

- `gh pr review`는 `--approve`, `--comment`, `--request-changes`, `--body-file`을 지원한다.
- `gh pr edit`는 `--remove-reviewer`를 지원한다.
- 따라서 Stage 3에서는 다음 원칙으로 문서화한다.
  - merge 전 검토 등록: `gh pr review {N} --approve/--comment --body-file {file}`
  - body file 검증: `scripts/validate-github-body.sh {file}` 통과 후 등록
  - merge 후 잔여 request 정리: 완료 처리 계열에서 `reviewRequests`를 확인하고 필요 시 reviewer 제거를 작업지시자 승인 후 수행

## 적용 대상과 제외 대상

### 적용 대상

- 사람이 작성하는 Issue body file
- 사람이 작성하는 PR body file
- 사람이 작성하는 PR comment / Issue comment body file
- 사람이 작성하는 PR review body file
- Skill/매뉴얼의 공개 GitHub 본문 등록 예시

### 제외 대상

- GitHub 웹 UI에서 직접 작성한 body/comment의 사전 차단
- workflow가 자동 생성하는 body file의 모든 경로 강제 보정
- 기준 브랜치에 없는 `external-pr-complete` Skill 직접 수정
- 실제 GitHub comment/review/cleanup 수행

## 다음 단계 확정

Stage 2에서는 `scripts/validate-github-body.sh`를 구현하고 실패/통과 샘플을 검증한다.

Stage 3에서는 다음 tracked 파일을 보정한다.

- `mydocs/skills/task-register/SKILL.md`
- `mydocs/skills/task-final-report/SKILL.md`
- `mydocs/skills/external-pr-review/SKILL.md`
- `mydocs/manual/pr_process_guide.md`
- `mydocs/manual/git_workflow_guide.md`

`external-pr-complete`는 기준 브랜치에 없는 파일이므로 직접 수정하지 않고, 추후 tracked 상태가 되면 `reviewRequests` 확인, `gh pr review --body-file`, `gh pr edit --remove-reviewer` 원칙을 적용해야 한다는 handoff를 남긴다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `rg -n "gh (issue|pr) ..."` | 공개 GitHub body 관련 경로 확인 |
| `rg --files mydocs/skills \| sort` | tracked Skill 목록 확인 |
| `gh pr view 328 ... reviewRequests ...` | merge 후 reviewer request 잔존 확인 |
| `gh pr review --help` | `--body-file` 지원 확인 |
| `gh pr edit --help` | `--remove-reviewer` 지원 확인 |
| `git diff --check` | 통과 |
| `git status --short --branch` | Stage 1 보고서 및 구현계획서 보정 변경 확인 |

## 승인 요청

Stage 1 결과 기준으로 Stage 2 validator 스크립트 구현에 들어가도 되는지 승인 요청한다.
