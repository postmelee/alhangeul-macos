# Task M013 #330 구현계획서

수행계획서: `mydocs/plans/task_m013_330.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #330 GitHub 공개 본문 body-file 검증 스크립트와 PR 처리 규칙 도입
- 마일스톤: M013 (`하이퍼-워터폴 작업환경 조성`)
- 브랜치: `local/task330`
- 작업 위치: `/private/tmp/rhwp-mac-task330`
- 기준 브랜치: `devel`
- 선행 상태: Issue #132 / PR #328 완료 코멘트 처리 중 `#328으로`처럼 GitHub 참조 토큰과 한글 조사가 붙는 표기 문제가 확인됐다.
- 목표: GitHub 공개 body 파일을 등록하기 전에 공통 validator를 실행하고, 관련 Skill과 매뉴얼이 `--body-file` 기반 공개 본문 등록을 우선하도록 정렬한다.

## 구현 원칙

- GitHub 공개 본문과 코멘트는 긴 inline `--body` 대신 `--body-file`을 우선한다.
- PR/Issue 참조 토큰과 한글 조사가 붙는 위험 패턴은 Skill 문장 규칙이 아니라 validator script에서 중앙 관리한다.
- 관련 Skill은 regex를 복제하지 않고 validator 호출 절차만 포함한다.
- GitHub 웹 UI 직접 작성은 사전 차단 대상에서 제외하고 한계로 기록한다.
- public GitHub에 실제 comment/create/edit을 수행하는 명령은 validator 통과 후에만 예시로 둔다.
- 기준 브랜치에 없는 local/untracked Skill은 이 task에서 임의로 새로 추가하지 않는다.

## 기준 브랜치 파일 상태

- tracked Skill: `external-pr-review`, `pr-merge-cleanup`, `task-final-report`, `task-register`, `task-stage-report`, `task-start`
- 기준 브랜치에 없는 Skill: `external-pr-complete`
  - 현재 task branch에는 존재하지 않으므로 이 task의 직접 변경 대상으로 삼지 않는다.
  - 해당 Skill이 별도 작업으로 tracked 상태가 되면 같은 validator 원칙을 적용해야 한다는 handoff를 최종 보고서에 남긴다.

## Stage 1. 공개 GitHub 본문 등록 경로 inventory

### 목표

현재 tracked 파일에서 GitHub 공개 본문을 생성/수정/등록하는 경로를 찾고, validator 적용 대상과 제외 대상을 확정한다.

### 작업

- `gh issue create`, `gh issue comment`, `gh pr create`, `gh pr comment`, `gh pr edit --body-file` 사용 지점을 검색한다.
- `--body-file`을 이미 쓰는 경로와 inline `--body`를 쓰는 경로를 구분한다.
- 사람이 작성하는 공개 body file과 workflow가 생성하는 body file을 분리한다.
- 기준 브랜치에 없는 `external-pr-complete`는 직접 수정 대상에서 제외하고 후속 handoff로 기록한다.
- Stage 1 보고서에 적용 대상 표를 남긴다.

### 산출물

- `mydocs/working/task_m013_330_stage1.md`

### 검증

```bash
rg -n "gh (issue|pr) (create|comment|edit)|--body-file|--body " mydocs/skills mydocs/manual scripts .github
rg --files mydocs/skills | sort
git diff --check
git status --short --branch
```

### 완료 기준

- validator 적용 대상과 제외 대상이 표로 정리된다.
- Stage 2/3에서 수정할 파일 목록이 확정된다.

### 커밋 메시지

```text
Task #330 Stage 1: GitHub 본문 등록 경로 조사
```

## Stage 2. validator 스크립트 구현과 단위 검증

### 목표

GitHub body file에서 PR/Issue 참조 토큰 직후 한글이 붙는 위험 패턴을 차단하는 공통 validator를 추가한다.

### 작업

- `scripts/validate-github-body.sh`를 추가한다.
- 인자 없는 실행, 존재하지 않는 파일, `rg --pcre2` 미지원/부재 상황의 오류 메시지를 정리한다.
- 실패 샘플:
  - `#328으로`
  - `PR #328은`
  - `Issue #132를`
- 통과 샘플:
  - `#328 반영으로`
  - `PR #328 반영은`
  - `Issue #132 이슈를`
  - 코드블록 안 검증 명령의 `gh pr checks 328`
- Stage 2 보고서에 패턴 의도와 false positive 한계를 기록한다.

### 산출물

- `scripts/validate-github-body.sh`
- `mydocs/working/task_m013_330_stage2.md`

### 검증

```bash
bash -n scripts/validate-github-body.sh
printf 'PR #328은 처리됨\n' > /tmp/task330-bad.md
! scripts/validate-github-body.sh /tmp/task330-bad.md
printf 'PR #328 반영은 완료됨\n' > /tmp/task330-good.md
scripts/validate-github-body.sh /tmp/task330-good.md
git diff --check
git status --short --branch
```

### 완료 기준

- 금지 샘플은 non-zero로 실패한다.
- 허용 샘플은 성공한다.
- script syntax와 diff whitespace 검증이 통과한다.

### 커밋 메시지

```text
Task #330 Stage 2: GitHub body validator 추가
```

## Stage 3. 매뉴얼과 tracked Skill 절차 보정

### 목표

공개 GitHub 본문 등록 절차를 `--body-file` + validator 통과 흐름으로 정렬한다.

### 작업

- `mydocs/manual/pr_process_guide.md`에 공개 GitHub body file 검증 원칙을 추가한다.
- 필요 시 `mydocs/manual/git_workflow_guide.md`의 PR 생성 예시를 validator 호출 포함 흐름으로 보정한다.
- `mydocs/skills/task-register/SKILL.md`의 `gh issue create` 예시를 inline `--body`에서 `--body-file` 기반으로 바꾸고 validator 호출을 추가한다.
- `mydocs/skills/task-final-report/SKILL.md`의 PR body 등록 전 validator 호출을 추가한다.
- `mydocs/skills/external-pr-review/SKILL.md`의 공개 코멘트 초안/등록 안내에 validator 원칙을 연결한다.
- 기준 브랜치에 없는 `external-pr-complete`는 직접 수정하지 않고 후속 handoff로 기록한다.

### 산출물

- `mydocs/manual/pr_process_guide.md`
- `mydocs/manual/git_workflow_guide.md` 또는 Stage 1에서 확정한 관련 매뉴얼
- `mydocs/skills/task-register/SKILL.md`
- `mydocs/skills/task-final-report/SKILL.md`
- `mydocs/skills/external-pr-review/SKILL.md`
- `mydocs/working/task_m013_330_stage3.md`

### 검증

```bash
rg -n "validate-github-body|--body-file|gh issue create|gh pr create|gh issue comment|gh pr comment" mydocs/manual mydocs/skills
rg -n --pcre2 "(?:PR|Issue)?\\s*#\\d+\\p{Hangul}" mydocs/skills mydocs/manual
bash -n scripts/validate-github-body.sh
git diff --check
git status --short --branch
```

### 완료 기준

- GitHub 공개 본문 등록 경로가 `--body-file` 우선 원칙을 설명한다.
- 관련 tracked Skill에 validator 호출이 연결된다.
- regex 세부 규칙은 script에만 존재하고 Skill/매뉴얼에는 중복 구현하지 않는다.

### 커밋 메시지

```text
Task #330 Stage 3: GitHub body 검증 절차 문서화
```

## Stage 4. 통합 검증과 최종 보고

### 목표

전체 변경의 적용 범위와 한계를 확인하고, 최종 결과보고서와 오늘할일 완료 처리를 수행한다.

### 작업

- 수행계획서와 구현계획서의 포함/제외 범위가 지켜졌는지 확인한다.
- validator 샘플 검증을 다시 수행한다.
- 관련 Skill/매뉴얼에서 `--body-file`과 validator 호출이 빠진 공개 body 경로가 남았는지 검색한다.
- 기준 브랜치에 없는 `external-pr-complete`에 대한 후속 handoff를 최종 보고서에 기록한다.
- 최종 결과보고서를 작성한다.
- `mydocs/orders/20260603.md`의 #330 상태를 완료로 갱신한다.

### 산출물

- `mydocs/report/task_m013_330_report.md`
- `mydocs/orders/20260603.md`

### 검증

```bash
bash -n scripts/validate-github-body.sh
printf 'Issue #132를 닫음\n' > /tmp/task330-bad.md
! scripts/validate-github-body.sh /tmp/task330-bad.md
printf 'Issue #132 이슈를 닫음\n' > /tmp/task330-good.md
scripts/validate-github-body.sh /tmp/task330-good.md
rg -n "validate-github-body|--body-file|gh issue create|gh pr create|gh issue comment|gh pr comment" scripts mydocs/manual mydocs/skills mydocs/report/task_m013_330_report.md
git diff --check
git status --short --branch
```

### 완료 기준

- validator 실패/통과 샘플 검증이 모두 기대대로 동작한다.
- 관련 매뉴얼/Skill에서 validator 호출 경로가 확인된다.
- 최종 보고서에 변경 파일, 검증 결과, 남은 한계와 후속 handoff가 기록된다.
- 오늘할일이 완료 처리된다.

### 커밋 메시지

```text
Task #330 Stage 4 + 최종 보고서: GitHub body 검증 절차 정리
```

## PR 계획

- 작업 브랜치: `local/task330`
- 게시 브랜치: `publish/task330`
- 대상 브랜치: `devel`
- PR 제목 후보: `Task #330: GitHub 공개 본문 body-file 검증 도입`
- PR 본문에는 validator 도입 이유, 적용 대상, 검증 결과, GitHub UI 직접 작성 한계를 포함한다.

## 변경 금지 사항

- GitHub 웹 UI 직접 작성 코멘트를 사전 차단한다고 문서화하지 않는다.
- `gh` 전역 alias나 GitHub CLI extension 설치를 요구하지 않는다.
- 기준 브랜치에 없는 local/untracked Skill을 임의로 추가하지 않는다.
- public GitHub에 코멘트나 PR/Issue 본문을 등록하는 실제 명령을 승인 없이 실행하지 않는다.
