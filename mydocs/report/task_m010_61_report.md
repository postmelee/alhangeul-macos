# Issue #61 최종 결과 보고서

## 작업 요약

- GitHub Issue: #61
- 마일스톤: M010 (v0.1.0)
- 작업명: PR 문서 링크 전수 보정과 작성 규격 강화
- 작업 브랜치: `local/task61`
- 단계 수: Stage 1 ~ Stage 5

PR #60 문서 섹션의 raw URL 노출과 PR #59 문서 링크 클릭 실패 원인을 조사하고, merged PR 본문 전체를 전수 스캔했다. PR #59는 존재하지 않는 잘못된 40자 SHA를 사용하고 있었고, PR #60은 링크 대상은 유효했지만 문서 섹션에 raw URL이 그대로 노출되어 있었다.

Stage 3에서 GitHub 원격 PR 본문을 보정했고, Stage 4에서 PR 템플릿, `task-final-report` SKILL, Git/PR 매뉴얼을 같은 링크 규격으로 강화했다.

## 단계별 결과

| Stage | 결과 | 산출물 |
|-------|------|--------|
| Stage 1 | merged PR 문서 링크 전수 조사, PR #59/#60 문제 재현 | `mydocs/working/task_m010_61_stage1.md` |
| Stage 2 | 기준 SHA와 PR 본문 보정안 확정 | `mydocs/working/task_m010_61_stage2.md` |
| Stage 3 | PR #59/#60 원격 본문 보정과 접근 검증 | `mydocs/working/task_m010_61_stage3.md` |
| Stage 4 | PR 링크 작성 규격 보강 | `mydocs/working/task_m010_61_stage4.md` |
| Stage 5 | 통합 검증, 최종 보고, 오늘할일 완료 처리 | `mydocs/working/task_m010_61_stage5.md`, 본 보고서 |

## 변경 파일과 영향 범위

로컬 저장소 문서와 템플릿:

- `.github/pull_request_template.md`
- `mydocs/skills/task-final-report/SKILL.md`
- `mydocs/manual/git_workflow_guide.md`
- `mydocs/manual/pr_process_guide.md`
- `mydocs/orders/20260426.md`
- `mydocs/plans/task_m010_61.md`
- `mydocs/plans/task_m010_61_impl.md`
- `mydocs/working/task_m010_61_stage1.md`
- `mydocs/working/task_m010_61_stage2.md`
- `mydocs/working/task_m010_61_stage3.md`
- `mydocs/working/task_m010_61_stage4.md`
- `mydocs/working/task_m010_61_stage5.md`
- `mydocs/report/task_m010_61_report.md`

GitHub 원격 PR 본문:

- PR #59
- PR #60

앱 코드, RustBridge, Xcode project, build script, submodule은 변경하지 않았다.

## 원인 분석

| PR | 증상 | 원인 |
|----|------|------|
| #59 | 문서 링크 클릭 시 파일이 조회되지 않음 | 문서 링크 7개가 존재하지 않는 SHA `6f57cccda6110abe999a54eec159aa91efa3b646`를 사용 |
| #60 | 문서 목차 링크가 너무 길게 노출 | 문서 링크 9개가 Markdown `[파일명](URL)` 형식이 아니라 raw URL로 작성됨 |

PR #59의 실제 head SHA는 `6f57ccc178438bb45ba7df85f6e278af4b428af0`이며, 대상 문서 7개가 모두 이 commit에서 조회됐다. PR #60의 기존 URL은 `c39e479b131804f7c2c123cc71a30f70216402a3` 기준으로 유효했으므로 URL은 유지하고 표시 텍스트만 파일명으로 바꿨다.

## 보정 대상과 결과

| PR | 기준 SHA | 수정 결과 |
|----|----------|-----------|
| #59 | `6f57ccc178438bb45ba7df85f6e278af4b428af0` | 문서 링크 7개를 실제 head SHA 기준 `[파일명](URL)` 링크로 교체 |
| #60 | `c39e479b131804f7c2c123cc71a30f70216402a3` | 문서 링크 9개를 raw URL에서 `[파일명](URL)` 형식으로 교체 |

merged PR 최근 100건 기준 전수 조사에서는 고정 blob 문서 링크가 있는 PR 18건, 링크 98개를 확인했다. Stage 5 재검증 시 모든 고정 URL SHA가 실제 `commit`으로 확인됐고, 문서 섹션 raw URL과 상대/비클릭 `mydocs/` 경로는 남아 있지 않았다.

## 규격화 결과

향후 재발을 줄이기 위해 작성 규격을 다음과 같이 명시했다.

- PR 문서 링크는 PR 생성 직전 `git rev-parse HEAD`로 확인한 PR head commit SHA 기준 GitHub blob URL 사용
- 문서 섹션 표시 텍스트는 raw URL이 아니라 `[파일명](URL)` 형식 사용
- 상대 링크(`mydocs/...`)와 `blob/publish/task{N}/...` 링크 금지

반영 위치:

- PR 템플릿: 문서 섹션 주석과 예시
- `task-final-report` SKILL: `HEAD_SHA=$(git rev-parse HEAD)` 절차와 PR 본문 검증 기준
- `git_workflow_guide.md`: commit SHA 고정 URL 정책과 `[파일명](URL)` 예시
- `pr_process_guide.md`: 내부 task PR 문서 섹션 작성 예시

## 검증 결과

| 수용 기준 | 결과 |
|-----------|------|
| PR #59 문서 링크가 클릭 가능한 실제 commit SHA로 교체됨 | OK |
| PR #60 문서 섹션이 raw URL 대신 `[파일명](URL)` 형식임 | OK |
| merged PR 문서 링크 전수 스캔에서 깨진 SHA가 남지 않음 | OK |
| merged PR 문서 섹션에 raw URL 표시가 남지 않음 | OK |
| PR 템플릿과 SKILL에 재발 방지 규격 반영 | OK |
| 오늘할일 완료 처리 | OK |

실행한 주요 검증:

```bash
git diff --check
gh pr view 59 --repo postmelee/alhangeul-macos --json body
gh pr view 60 --repo postmelee/alhangeul-macos --json body
gh pr list --repo postmelee/alhangeul-macos --state merged --limit 100 --json number,title,body
rg -n "문서 링크|파일명|git rev-parse HEAD|blob/\\{sha\\}|raw URL" \
  .github/pull_request_template.md \
  mydocs/skills/task-final-report/SKILL.md \
  mydocs/manual/git_workflow_guide.md
git status --short
```

검증 결과:

- `git diff --check` 통과
- PR #59의 잘못된 SHA `6f57cccda6110abe999a54eec159aa91efa3b646` 잔존 여부 `false`
- merged PR 고정 blob URL의 18개 SHA 모두 `commit`으로 확인
- 문서 섹션 raw URL 표시 검사 출력 없음
- 문서 섹션 상대/비클릭 `mydocs/` 경로 검사 출력 없음
- 규격 보강 문서에서 핵심 문구 검색 확인

## 잔여 위험과 후속 작업

- GitHub PR 본문 수정은 원격 상태 변경이므로 로컬 diff에는 본문 변경 자체가 남지 않는다. Stage 2~3 보고서와 본 보고서에 수정 대상, 기준 SHA, 검증 결과를 기록했다.
- 현재 보강은 템플릿과 절차 문서 기반이다. 향후 같은 문제가 반복되면 PR 본문 lint 스크립트나 `task-final-report` 보조 스크립트로 자동 검사하는 후속 작업을 검토한다.
- PR 게시 후 생성되는 #61 PR 본문도 이번 규격에 맞게 `[파일명](고정 URL)` 형식으로 작성해야 한다.

## 커밋 목록

```text
af8cad8 Task #61: 수행 계획서 작성과 오늘할일 갱신
ea2642d Task #61: 구현 계획서 작성
085b5be Task #61 Stage 1: PR 문서 링크 전수 조사
1120864 Task #61 Stage 2: PR 문서 링크 보정안 확정
ab4770d Task #61 Stage 3: PR 본문 문서 링크 보정
eb2ef31 Task #61 Stage 4: PR 문서 링크 작성 규격 보강
```

## 승인 요청 사항

본 최종 결과 보고서 기준으로 `publish/task61` 원격 게시와 `devel` 대상 draft PR 생성을 승인 요청한다.
