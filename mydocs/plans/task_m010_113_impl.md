# Issue #113 구현 계획서

수행계획서: `mydocs/plans/task_m010_113.md`

## 작업명

task-final-report 최종 보고서 변경 파일 표준 강화

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_113.md`를 기준으로 진행한다.
- 변경 범위는 `task-final-report` Skill의 최종 보고서 작성 규칙에 한정한다.
- 기존 완료 보고서는 소급 수정하지 않는다.
- PR 템플릿 구조, 관련 이슈 의미, 작업 문서 위치 같은 넓은 PR 본문 개편은 #112 또는 별도 작업으로 남긴다.
- 문서/운영 규칙 변경이므로 Swift, Rust, Xcode 빌드는 수행하지 않는다.

## Stage 1: 변경 파일 섹션 작성 규칙 보강

대상:

- `mydocs/skills/task-final-report/SKILL.md`

작업:

1. `최종 보고서 작성` 절차의 표준 섹션 중 `변경 파일 목록과 영향 범위` 항목 아래에 작성 규칙을 추가한다.
2. 추가 규칙은 다음 3개로 제한한다.
   - 반드시 Markdown table로 작성한다.
   - 기본 컬럼은 `파일 | 내용`으로 한다.
   - 단순 파일 목록만 나열하지 않는다.
3. 기존 표준 섹션 목록, PR 생성 절차, commit SHA 고정 문서 링크 규칙은 유지한다.
4. Stage 1 단계 보고서를 작성한다.

산출물:

- `mydocs/skills/task-final-report/SKILL.md`
- `mydocs/working/task_m010_113_stage1.md`

검증:

```bash
rg -n "변경 파일 목록과 영향 범위|Markdown table|파일 \\| 내용|단순 파일 목록" mydocs/skills/task-final-report/SKILL.md
git diff --check -- mydocs/skills/task-final-report/SKILL.md mydocs/working/task_m010_113_stage1.md
```

완료 조건:

- `task-final-report` Skill에 3개 작성 규칙이 명시되어 있다.
- 기존 완료 보고서나 PR 템플릿은 변경하지 않았다.

커밋:

```text
Task #113 Stage 1: 최종 보고서 변경 파일 표준 보강
```

## Stage 2: 규칙 검색과 적용 범위 검증

대상:

- `mydocs/skills/task-final-report/SKILL.md`
- `mydocs/working/task_m010_113_stage2.md`

작업:

1. Stage 1에서 추가한 문구가 검색 가능한지 확인한다.
2. `task-final-report` 외 PR 템플릿, PR 처리 가이드, Git 워크플로우 문서를 바꾸지 않았음을 diff로 확인한다.
3. 이번 작업이 #112의 넓은 PR 본문 구조 개편과 겹치지 않는다는 점을 단계 보고서에 기록한다.
4. Stage 2 단계 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_113_stage2.md`

검증:

```bash
rg -n "Markdown table|파일 \\| 내용|단순 파일 목록" mydocs/skills/task-final-report/SKILL.md
git diff --name-only devel..HEAD
git diff --check -- mydocs/working/task_m010_113_stage2.md
```

완료 조건:

- 추가 규칙이 Skill 본문에서 검색된다.
- 변경 범위가 `task-final-report` Skill과 task 문서로 제한되어 있다.

커밋:

```text
Task #113 Stage 2: 최종 보고서 규칙 검증
```

## Stage 3: 최종 보고서와 오늘할일 정리

대상:

- `mydocs/orders/20260501.md`
- `mydocs/report/task_m010_113_report.md`
- `mydocs/working/task_m010_113_stage3.md`

작업:

1. 전체 변경 파일을 최종 보고서로 정리한다.
2. 최종 보고서의 `변경 파일 목록과 영향 범위` 섹션은 Stage 1에서 정한 `파일 | 내용` Markdown table 형식으로 작성한다.
3. 오늘할일에서 #113 상태를 완료로 바꾸고 완료 시각을 기록한다.
4. Stage 3 단계 보고서를 작성한다.
5. PR 게시 전 커밋 상태를 정리한다.

산출물:

- `mydocs/orders/20260501.md`
- `mydocs/report/task_m010_113_report.md`
- `mydocs/working/task_m010_113_stage3.md`

검증:

```bash
git diff --check
rg -n "변경 파일 목록과 영향 범위|\\| 파일 \\| 내용 \\|" \
  mydocs/report/task_m010_113_report.md \
  mydocs/skills/task-final-report/SKILL.md
rg -n "#113|완료:" mydocs/orders/20260501.md
test -f mydocs/report/task_m010_113_report.md
git status --short
```

완료 조건:

- 최종 보고서가 새 변경 파일 표준을 직접 적용한다.
- 오늘할일 완료 처리가 끝난다.
- 작업 트리가 정리되어 PR 게시 승인 요청이 가능하다.

커밋:

```text
Task #113 Stage 3 + 최종 보고서: 최종 보고서 변경 파일 표준 강화 결과 정리
```

## 단계별 커밋 메시지

| Stage | 커밋 메시지 |
|-------|-------------|
| 1 | `Task #113 Stage 1: 최종 보고서 변경 파일 표준 보강` |
| 2 | `Task #113 Stage 2: 최종 보고서 규칙 검증` |
| 3 | `Task #113 Stage 3 + 최종 보고서: 최종 보고서 변경 파일 표준 강화 결과 정리` |

## 후속 작업

- Stage 3 완료 후 작업지시자 승인 시 `task-final-report` 절차로 `publish/task113` push와 draft PR 생성을 진행한다.
- PR merge 후 정리는 `pr-merge-cleanup` 절차로 수행한다.
- 기존 완료 보고서 일괄 보정이나 PR body lint 자동화가 필요하면 별도 이슈로 분리한다.

## 승인 요청 사항

이 구현 계획서 기준으로 Stage 1을 진행할지 승인 요청한다. 승인 전에는 `task-final-report` Skill 본문 수정에 착수하지 않는다.
