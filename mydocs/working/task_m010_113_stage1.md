# Task M010 #113 Stage 1 완료 보고서

## 단계 목표

`task-final-report` Skill의 최종 보고서 작성 규칙에 `변경 파일 목록과 영향 범위` 섹션 작성 표준을 추가한다.

## 변경 내용

`mydocs/skills/task-final-report/SKILL.md`의 `최종 보고서 작성` 절차에서 표준 섹션 목록 중 `변경 파일 목록과 영향 범위` 아래에 다음 규칙을 추가했다.

- 반드시 Markdown table로 작성한다.
- 기본 컬럼은 `파일 | 내용`으로 한다.
- 단순 파일 목록만 나열하지 않는다.

## 변경하지 않은 항목

- 기존 완료 보고서는 소급 수정하지 않았다.
- `.github/pull_request_template.md`는 변경하지 않았다.
- `pr_process_guide.md`, `git_workflow_guide.md` 같은 PR 본문 구조 문서는 변경하지 않았다.
- PR 생성 절차와 commit SHA 고정 문서 링크 규칙은 유지했다.

## 검증

```bash
rg -n "변경 파일 목록과 영향 범위|Markdown table|파일 \\| 내용|단순 파일 목록" mydocs/skills/task-final-report/SKILL.md
git diff --check -- mydocs/skills/task-final-report/SKILL.md mydocs/working/task_m010_113_stage1.md
```

결과:

- `task-final-report` Skill에서 3개 규칙이 검색됨
- `git diff --check` 통과

## 산출물

- `mydocs/skills/task-final-report/SKILL.md`
- `mydocs/working/task_m010_113_stage1.md`

## 다음 단계

Stage 2에서 추가 규칙의 검색 가능성과 변경 범위 제한을 다시 확인한다.
