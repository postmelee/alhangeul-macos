# Task M013 #330 Stage 3 보고서

## 단계 목적

GitHub 공개 본문 등록 절차와 PR review 등록 절차를 `--body-file` + `scripts/validate-github-body.sh` 흐름으로 정렬한다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/skills/task-register/SKILL.md` | Issue 생성 본문을 inline `--body`가 아니라 body file 작성, validator 통과, `--body-file` 등록 흐름으로 보정 |
| `mydocs/skills/task-final-report/SKILL.md` | PR 생성 전 `PR_BODY` validator 호출 추가 |
| `mydocs/skills/external-pr-review/SKILL.md` | review request 해소를 위해 `gh pr review --body-file` 등록 절차와 validator 호출 추가 |
| `mydocs/manual/pr_process_guide.md` | 공개 PR/Issue/comment/review body file 검증 원칙과 PR 생성 예시 보정 |
| `mydocs/manual/git_workflow_guide.md` | maintainer/contributor PR 생성과 review body 예시에 validator + `--body-file` 흐름 반영 |
| `mydocs/working/task_m013_330_stage3.md` | Stage 3 결과 기록 |

## 변경 요약

### `task-register`

- 승인된 Issue 본문을 `/tmp/task-register-issue-body.md` 같은 파일로 작성하도록 바꿨다.
- `scripts/validate-github-body.sh "$ISSUE_BODY"` 통과 후 `gh issue create --body-file "$ISSUE_BODY"`를 실행하도록 보정했다.
- inline `--body`로 공개 Issue 본문을 등록하지 말라는 금지 규칙을 추가했다.

### `task-final-report`

- `gh pr create --body-file "$PR_BODY"` 직전에 `scripts/validate-github-body.sh "$PR_BODY"`를 실행하도록 추가했다.
- PR 본문 검증 기준에 validator 통과 조건을 추가했다.

### `external-pr-review`

- PR 메타 수집에 `reviewRequests,reviews`를 포함했다.
- 작업지시자 승인 후 공개 review body file을 만들고 validator 통과 후 다음 중 하나를 등록하는 흐름을 추가했다.
  - `gh pr review {N} --approve --body-file "$REVIEW_BODY"`
  - `gh pr review {N} --comment --body-file "$REVIEW_BODY"`
  - `gh pr review {N} --request-changes --body-file "$REVIEW_BODY"`
- 단순 PR comment 대신 실제 GitHub review를 남겨 review request 알림과 검토 상태를 정리해야 한다는 원칙을 추가했다.

### 매뉴얼

- `pr_process_guide.md`에 GitHub 공개 PR/Issue 본문, 코멘트, review 본문은 `--body-file`로 등록하고 등록 전 validator를 통과해야 한다는 공통 원칙을 추가했다.
- `pr_process_guide.md`의 `--template` 직접 사용 예시를 body file 작성 흐름으로 바꿨다.
- `git_workflow_guide.md`의 maintainer/contributor PR 생성 예시에 validator 호출과 `--body-file`을 추가했다.
- review 본문을 남기는 경우 `gh pr review --body-file`을 사용한다는 기준을 추가했다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `rg -n "validate-github-body\|--body-file\|gh issue create\|gh pr create\|gh issue comment\|gh pr comment\|gh pr review\|reviewRequests" mydocs/manual mydocs/skills` | 변경한 Skill/매뉴얼에서 validator와 body-file 경로 확인 |
| `rg -n -- "--body \"\|--body $\|--body [^ -]" mydocs/skills mydocs/manual` | inline `--body` 등록 예시 없음 |
| `rg -n --pcre2 "(?:PR\|Issue)?\\s*#\\d+\\p{Hangul}" mydocs/skills/external-pr-review/SKILL.md mydocs/skills/task-final-report/SKILL.md mydocs/skills/task-register/SKILL.md mydocs/manual/pr_process_guide.md mydocs/manual/git_workflow_guide.md` | 변경 대상 파일에서는 match 없음 |
| `bash -n scripts/validate-github-body.sh` | 통과 |
| `scripts/validate-github-body.sh /tmp/task330-stage3-bad.md` | `PR #328은 처리됨`을 exit 1로 차단 |
| `scripts/validate-github-body.sh /tmp/task330-stage3-good.md` | `PR #328 반영은 처리됨` 통과 |
| `git diff --check` | 통과 |

## 전체 manual 검색 결과

`rg -n --pcre2 "(?:PR|Issue)?\\s*#\\d+\\p{Hangul}" mydocs/skills mydocs/manual`는 기존 release 매뉴얼의 `#209에서`, `#225에서` 같은 일반 문장을 일부 찾았다.

이번 Stage 3의 목표는 GitHub 공개 body file 등록 경로를 validator로 보호하는 것이므로, release 매뉴얼의 기존 설명 문구는 수정하지 않았다. 공개 GitHub body file로 등록되는 파일은 `scripts/validate-github-body.sh`를 통과해야 하므로 같은 패턴이 공개 코멘트/본문으로 나가는 것은 차단된다.

## 남은 리스크와 handoff

- 기준 브랜치에는 `external-pr-complete` Skill이 없으므로 직접 수정하지 않았다. 해당 Skill이 tracked 상태로 들어오면 완료 처리 단계에서 `reviewRequests,reviews` 확인, 필요 시 `gh pr edit --remove-reviewer` cleanup, 공개 완료 comment/review body validator 호출을 추가해야 한다.
- GitHub 웹 UI에서 직접 작성한 코멘트는 validator로 사전 차단할 수 없다.
- workflow-generated body file은 이번 stage에서 강제 보정하지 않았다. 필요하면 별도 automation hardening task에서 다룬다.

## 다음 단계

Stage 4에서 전체 변경을 다시 검증하고 최종 보고서와 오늘할일 완료 처리를 수행한다.

## 승인 요청

Stage 3 결과 기준으로 Stage 4 통합 검증과 최종 보고 단계에 들어가도 되는지 승인 요청한다.
