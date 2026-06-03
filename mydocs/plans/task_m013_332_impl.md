# Task #332 구현계획서 - 외부 PR 리뷰와 완료 처리 Skill 보강

## 구현 목표

PR #331에 반영된 GitHub 공개 본문 안전장치를 보존하면서 외부 PR 처리 Skill을 두 단계로 정리한다.

- `external-pr-review`: merge 전 triage, 검토 문서, 검증, 기여자 피드백 초안, 내부 후속 분리
- `external-pr-complete`: merge/cherry-pick/수동 반영 후 완료 보고서, PR/Issue 완료 코멘트 초안, 승인 후 GitHub 처리

## 수용 기준

- `external-pr-review`가 review 시작 triage gate를 먼저 제안하고 작업지시자 승인 전 본격 review를 진행하지 않는다.
- `external-pr-review`가 첫 기여자 환영, 구체적 칭찬, 실행 가능한 개선 안내, 내부 후속 분리를 응답 전용 코멘트 초안 규칙으로 포함한다.
- `external-pr-review`가 PR #331의 GitHub body-file 검증과 GitHub 참조 표기 규칙을 보존한다.
- `external-pr-complete`가 merge 후 완료 처리 책임을 별도 Skill로 제공한다.
- `external-pr-complete`가 보고서에는 코멘트 전문을 저장하지 않고, 사용자 응답에만 PR/Issue 완료 코멘트 초안을 제시한다.
- `git diff --check`와 관련 문구 검색 검증이 통과한다.

## Stage 1: 기준 차이 정리

### 작업

- PR #331 merge commit 기준 `external-pr-review` 본문을 확인한다.
- stash에 보관된 이전 초안을 확인한다.
- PR #331의 GitHub body 검증/참조 표기 규칙과 이후 보강할 항목을 분리한다.

### 산출물

- `mydocs/working/task_m013_332_stage1.md`

### 검증

```bash
git show origin/devel:mydocs/skills/external-pr-review/SKILL.md >/dev/null
git show stash@{0}:mydocs/skills/external-pr-review/SKILL.md >/dev/null
git status --short
```

## Stage 2: `external-pr-review` 보강

### 작업

- triage gate와 승인 전 제한을 명확히 한다.
- 검토 문서 표준 섹션에 기여자 피드백 판단을 추가한다.
- 수정 요청/보류/닫기/분리 재제출 권고 시 응답 전용 코멘트 초안 원칙과 템플릿을 추가한다.
- 내부 후속 수정 분리 원칙을 판단 기준과 절대 금지 항목에 반영한다.
- PR #331의 GitHub body-file 검증 및 참조 표기 규칙을 유지한다.

### 산출물

- `mydocs/skills/external-pr-review/SKILL.md`
- `mydocs/working/task_m013_332_stage2.md`

### 검증

```bash
git diff --check
rg -n "GitHub 참조 표기 규칙|body-file|기여자 피드백|내부 후속|첫 기여" mydocs/skills/external-pr-review/SKILL.md
```

## Stage 3: `external-pr-complete` 신규 추가

### 작업

- merge/cherry-pick/수동 반영 완료 후 절차를 별도 Skill로 추가한다.
- 완료 보고서 표준 섹션, PR/Issue 완료 코멘트 초안 원칙, 승인 후 GitHub 처리 절차를 작성한다.
- 첫 기여자 환영, 구체적 기여 칭찬, maintainer 후속 보완 안내를 completion message 원칙에 반영한다.
- 보고서에 코멘트 초안 전문을 저장하지 않는 제한을 명시한다.

### 산출물

- `mydocs/skills/external-pr-complete/SKILL.md`
- `mydocs/working/task_m013_332_stage3.md`

### 검증

```bash
git diff --check
rg -n "PR 완료 코멘트|Issue 완료 코멘트|첫 기여자|메인테이너 후속|pr_\\{N\\}_report" mydocs/skills/external-pr-complete/SKILL.md
```

## Stage 4: 통합 검증과 PR 게시

### 작업

- 두 Skill의 책임 경계를 다시 확인한다.
- 최종 보고서를 작성하고 오늘할일을 완료 처리한다.
- `publish/task332` 브랜치를 push하고 `devel` 대상 PR을 생성한다.

### 산출물

- `mydocs/report/task_m013_332_report.md`
- GitHub PR

### 검증

```bash
git diff --check
rg -n "external-pr-complete|기여자 피드백|내부 후속|GitHub 참조 표기 규칙|PR 완료 코멘트" mydocs/skills/external-pr-review/SKILL.md mydocs/skills/external-pr-complete/SKILL.md
git status --short
```

## 승인 요청

이 구현계획서 기준으로 Stage 1부터 Stage 4까지 진행한다.
