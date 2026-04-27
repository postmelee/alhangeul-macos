# Issue #61 Stage 4 완료 보고서

## 단계명

PR 링크 작성 규격 보강

## 작업 요약

PR 본문 `문서` 섹션에서 같은 문제가 재발하지 않도록 PR 템플릿, `task-final-report` SKILL, Git 워크플로우 매뉴얼, PR 처리 가이드를 같은 규격으로 맞췄다.

규격은 다음 세 가지로 통일했다.

- 문서 링크는 PR 생성 직전 `git rev-parse HEAD`로 확인한 PR head commit SHA 기준 GitHub blob URL 사용
- 문서 섹션 표시 텍스트는 raw URL이 아니라 `[파일명](URL)` 형식 사용
- 상대 링크(`mydocs/...`)와 `blob/publish/task{N}/...` 링크 금지

## 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `.github/pull_request_template.md` | `문서` 섹션 주석에 head SHA 기준과 `[파일명](URL)` 표시 규칙 추가, 바로 바꿔 쓸 수 있는 Markdown 링크 예시 추가 |
| `mydocs/skills/task-final-report/SKILL.md` | PR 생성 단계에 `HEAD_SHA=$(git rev-parse HEAD)` 확인 절차, 문서 링크 작성 규격, PR 본문 검증 기준 추가 |
| `mydocs/manual/git_workflow_guide.md` | 기존 commit SHA 고정 URL 정책에 raw URL 금지와 `[파일명](URL)` 예시 추가 |
| `mydocs/manual/pr_process_guide.md` | 내부 task PR `문서` 섹션 작성 기준과 예시를 새 링크 규격으로 갱신 |

## 규격화 결과

### PR 템플릿

새 PR 작성자는 `문서` 섹션에서 다음 형태를 바로 볼 수 있다.

```md
- 수행 계획서: [task_m000_0.md](https://github.com/postmelee/alhangeul-macos/blob/{head_sha}/mydocs/plans/task_m000_0.md)
- 구현 계획서: [task_m000_0_impl.md](https://github.com/postmelee/alhangeul-macos/blob/{head_sha}/mydocs/plans/task_m000_0_impl.md)
- 단계 보고서: [task_m000_0_stage1.md](https://github.com/postmelee/alhangeul-macos/blob/{head_sha}/mydocs/working/task_m000_0_stage1.md)
- 최종 보고서: [task_m000_0_report.md](https://github.com/postmelee/alhangeul-macos/blob/{head_sha}/mydocs/report/task_m000_0_report.md)
```

### task-final-report SKILL

최종 보고 후 PR 생성 절차에 다음 기준을 추가했다.

- PR body 작성 전에 `HEAD_SHA=$(git rev-parse HEAD)`로 기준 SHA 확인
- `문서` 섹션의 모든 문서 링크는 `HEAD_SHA` 기준 고정 blob URL로 작성
- PR 생성 후 `gh pr view` 결과에서 commit SHA 고정 URL과 `[파일명](URL)` 표시 형식 확인

### 매뉴얼

`git_workflow_guide.md`는 정책 원문과 예시를 함께 갖도록 보강했다. `pr_process_guide.md`는 내부 task PR 예시가 더 이상 단순 코드 경로를 보여주지 않도록 Markdown 링크 형식으로 갱신했다.

## 검증 결과

규격 키워드와 예시가 대상 문서에 반영됐는지 확인했다.

```bash
rg -n "문서 링크|파일명|git rev-parse HEAD|blob/\\{sha\\}|raw URL|task-final-report" \
  .github/pull_request_template.md \
  mydocs/skills/task-final-report/SKILL.md \
  mydocs/manual/git_workflow_guide.md \
  mydocs/manual/pr_process_guide.md
```

결과:

- PR 템플릿에 `git rev-parse HEAD`, `{head_sha}`, `[파일명](...)` 예시가 존재한다.
- `task-final-report` SKILL에 `HEAD_SHA=$(git rev-parse HEAD)`와 PR 본문 검증 기준이 존재한다.
- `git_workflow_guide.md`와 `pr_process_guide.md`가 raw URL 금지와 `[파일명](URL)` 표시 규칙을 포함한다.

Markdown diff 공백 검사를 실행했다.

```bash
git diff --check -- \
  .github/pull_request_template.md \
  mydocs/skills/task-final-report/SKILL.md \
  mydocs/manual/git_workflow_guide.md \
  mydocs/manual/pr_process_guide.md \
  mydocs/working/task_m010_61_stage4.md
```

결과: 통과.

## 완료 조건 확인

| 완료 조건 | 결과 |
|-----------|------|
| 새 PR 작성자가 문서 섹션에서 `[파일명](고정 URL)` 형식을 바로 따라 쓸 수 있음 | 충족 |
| `task-final-report` 절차가 head SHA, 문서 링크 형식, PR 본문 검증을 포함함 | 충족 |
| 기존 매뉴얼의 commit SHA 고정 URL 정책과 새 표시 형식 규칙이 충돌하지 않음 | 충족 |

## 승인 요청 사항

본 Stage 4 결과 기준으로 Stage 5: 통합 검증과 최종 보고 진행을 승인 요청한다.
