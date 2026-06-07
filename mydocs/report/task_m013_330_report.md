# Task M013 #330 최종 보고서

## 작업 개요

| 항목 | 내용 |
|------|------|
| Issue | #330 |
| 마일스톤 | M013 — 하이퍼-워터폴 작업환경 조성 |
| 브랜치 | `local/task330` |
| 기준 브랜치 | `devel` |
| 작업 위치 | `/private/tmp/rhwp-mac-task330` |
| 목적 | GitHub 공개 본문 등록 전 body file 검증을 강제해 PR/Issue 참조 토큰과 한글 조사가 붙는 실수를 차단 |

## 완료 요약

- GitHub 공개 body file 검증용 `scripts/validate-github-body.sh`를 추가했다.
- 사람이 작성하는 Issue/PR/comment/review 본문은 `--body-file`로 작성하고 validator 통과 후 등록한다는 공통 규칙을 매뉴얼에 반영했다.
- tracked Skill 중 공개 GitHub 본문 등록 경로가 있는 `task-register`, `task-final-report`, `external-pr-review`에 validator 호출을 연결했다.
- PR review request 알림이 남는 문제를 줄이기 위해 `external-pr-review`에 실제 GitHub review 등록 절차를 추가했다.

## 변경 파일

| 파일 | 변경 내용 |
|------|-----------|
| `scripts/validate-github-body.sh` | PR/Issue 참조 토큰 직후 한글이 붙는 패턴을 `rg --pcre2`로 검사하는 validator 추가 |
| `mydocs/skills/task-register/SKILL.md` | Issue 본문을 inline `--body` 대신 body file 작성, validator 통과, `--body-file` 등록 흐름으로 보정 |
| `mydocs/skills/task-final-report/SKILL.md` | PR 생성 전 `PR_BODY` validator 호출 추가 |
| `mydocs/skills/external-pr-review/SKILL.md` | PR 메타 조회에 `reviewRequests,reviews` 포함, `gh pr review --body-file` 등록 절차 추가 |
| `mydocs/manual/pr_process_guide.md` | 공개 GitHub body file 검증 원칙과 PR body 생성 예시 보정 |
| `mydocs/manual/git_workflow_guide.md` | maintainer/contributor PR body와 review body 예시에 validator + `--body-file` 흐름 반영 |
| `mydocs/plans/task_m013_330.md` | 수행계획서 작성 |
| `mydocs/plans/task_m013_330_impl.md` | 4단계 구현계획서 작성 |
| `mydocs/working/task_m013_330_stage1.md` | 공개 GitHub 본문 등록 경로 inventory 기록 |
| `mydocs/working/task_m013_330_stage2.md` | validator 구현과 단위 검증 기록 |
| `mydocs/working/task_m013_330_stage3.md` | 매뉴얼/Skill 보정 결과 기록 |
| `mydocs/orders/20260603.md` | #330 작업 상태를 완료로 갱신 |

## 단계별 결과

| 단계 | 결과 |
|------|------|
| Stage 1 | tracked Skill과 매뉴얼의 GitHub 공개 본문 등록 경로를 조사하고 적용 대상과 제외 대상을 확정 |
| Stage 2 | `scripts/validate-github-body.sh` 추가 및 실패/통과 샘플 검증 완료 |
| Stage 3 | 관련 매뉴얼과 tracked Skill을 `--body-file` + validator 흐름으로 보정 |
| Stage 4 | 통합 검증, 최종 보고서 작성, 오늘할일 완료 처리 수행 |

## 수용 기준 확인

| 기준 | 결과 |
|------|------|
| 참조 토큰 직후 한글이 붙는 위험 패턴 차단 | 충족 |
| `#328 반영으로`, `PR #328 반영은`, `Issue #132 이슈를` 같은 분리 표기 허용 | 충족 |
| Issue/PR/comment/review 공개 본문은 `--body-file` 우선으로 문서화 | 충족 |
| tracked Skill의 공개 본문 등록 경로에 validator 호출 연결 | 충족 |
| PR review request 해소를 위해 실제 `gh pr review --body-file` 절차 반영 | 충족 |
| 기준 브랜치에 없는 `external-pr-complete` 직접 수정 금지 | 충족 |

## 검증 결과

| 명령 | 결과 |
|------|------|
| `bash -n scripts/validate-github-body.sh` | 통과 |
| `scripts/validate-github-body.sh /tmp/task330-bad.md` | 위험 패턴을 exit 1로 차단 |
| `scripts/validate-github-body.sh /tmp/task330-good.md` | 통과 |
| `rg -n "validate-github-body\|--body-file\|gh issue create\|gh pr create\|gh issue comment\|gh pr comment\|gh pr review\|reviewRequests" scripts mydocs/manual mydocs/skills mydocs/report/task_m013_330_report.md` | validator 적용 경로와 review request 조회 경로 확인 |
| `git diff --check` | 통과 |
| `git status --short --branch` | Stage 4 산출물 작성 전 기준 `local/task330...origin/devel [ahead 5]` 확인 |

## 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 공통 GitHub body validator | 없음 | `scripts/validate-github-body.sh` 1개 추가 |
| `task-register` Issue body 등록 | inline `--body` 예시 | body file 작성 후 validator, `--body-file` 등록 |
| `task-final-report` PR body 등록 | `--body-file` 사용, validator 없음 | validator 통과 후 `--body-file` 등록 |
| `external-pr-review` review 처리 | GitHub review 등록 절차 없음 | 작업지시자 승인 후 `gh pr review --body-file` 등록 가능 |
| 작업 커밋 | 없음 | Stage 1~3 및 계획서 5커밋, Stage 4 최종 보고서 1커밋 |

## 남은 한계와 handoff

- GitHub 웹 UI에서 직접 작성하는 comment/body는 이 validator로 사전 차단할 수 없다.
- workflow가 자동 생성하는 body file 전체에는 이번 작업에서 validator를 강제하지 않았다.
- 기준 브랜치에는 `external-pr-complete` Skill이 없어서 직접 수정하지 않았다. 해당 Skill이 tracked 상태로 들어오면 완료 처리 단계에서 `reviewRequests,reviews` 조회, 필요 시 `gh pr edit --remove-reviewer` 정리, 공개 완료 comment/review body validator 호출을 추가해야 한다.
- 기존 release 매뉴얼의 일반 설명 문장 일부에는 참조 번호 뒤에 한글이 붙는 표현이 남아 있다. 이번 작업은 공개 GitHub body file 등록 경로 보호가 목적이므로 일반 문서 문장은 범위 밖으로 두었다.

## PR 게시 전 확인

PR 게시 시에는 `task-final-report` Skill 흐름에 따라 PR body file을 만든 뒤 `scripts/validate-github-body.sh "$PR_BODY"`를 통과시키고 `gh pr create --body-file "$PR_BODY"`로 등록해야 한다.
