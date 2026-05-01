# Task #112 Stage 3 완료 보고서

## 단계 목적

Stage 2에서 개편한 PR 템플릿 구조에 맞춰 `pr_process_guide.md`, `task-final-report` 절차, Git workflow 예시, Copilot review 지시를 보정했다.

이번 단계에서는 내부 task PR 작성 규칙을 새 템플릿 용어로 맞추되, 외부 기여 PR 검토 절차는 유지했다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `mydocs/manual/pr_process_guide.md` | 내부 task PR 작성 기준을 `대상 타스크`, `변경 내역 > 작업 문서`, 맥락용 `관련 이슈`, `후속 이슈 제안` 구조로 재작성 |
| `mydocs/skills/task-final-report/SKILL.md` | PR 생성 절차를 `--body-file` 우선으로 바꾸고 Stage 보고서 링크+commit 링크, 작업 문서 링크 검증 기준 반영 |
| `mydocs/manual/git_workflow_guide.md` | PR 생성 예시를 `--body-file` 기준으로 보정하고 작업 문서/Stage commit 링크 예시 추가 |
| `.github/copilot-instructions.md` | PR 설명 검토 기준에 대상 타스크/관련 이슈 분리와 Stage report+commit 링크 확인 추가 |

Diff stat:

```text
.github/copilot-instructions.md          |  2 +-
mydocs/manual/git_workflow_guide.md      | 10 +++-
mydocs/manual/pr_process_guide.md        | 99 +++++++++++++++++++-------------
mydocs/skills/task-final-report/SKILL.md | 17 ++++--
```

## 주요 변경

### PR 처리 가이드

내부 task PR 작성 기준을 새 템플릿 구조와 맞췄다.

- 직접 수행 issue는 `대상 타스크`에 적도록 정리
- `관련 이슈`는 선행, 후속, Epic, upstream, 참고 PR/issue를 적는 맥락 섹션으로 재정의
- `문서` 최상위 대단원 대신 `변경 내역` 안의 `작업 문서` 항목 사용
- Stage 제목은 단계 보고서 링크, 짧은 commit SHA는 commit URL로 링크
- `요약` 최대 4 bullet, 주요 파일/영역 표 최대 5행, 핵심 리뷰 포인트 최대 3개와 코드 블록 20줄 이하 기준 반영

외부 기여 PR 검토 절차는 기존 구조를 유지했다.

### task-final-report

PR 생성 절차를 `--body-file` 우선 흐름으로 보정했다.

- `PR_BODY=/tmp/task{N}-pr-body.md`를 두고 최종 보고서와 단계 보고서 기준으로 PR 본문을 완성
- Stage별 요약은 단계 보고서 URL과 짧은 commit SHA 링크를 함께 사용
- 작업 문서는 `HEAD_SHA` 기준 고정 URL과 `[파일명](URL)` 형식 사용
- 시각적 변경사항이 있을 때만 Before/After 표 유지
- 관련 이슈는 대상 타스크가 아니라 맥락 이슈만 작성
- 실행하지 않은 검증 체크리스트가 남아 있지 않은지 검증

### Git workflow와 Copilot 지시

Git workflow의 메인테이너 예시는 `--body-file /tmp/task17-pr-body.md` 기준으로 바꿨다. PR 본문 링크 FAQ에는 작업 문서 항목과 Stage report+commit 링크 예시를 추가했다.

Copilot 지시는 한 문장만 보정했다. PR 설명이 템플릿을 쓰는지뿐 아니라 대상 타스크/관련 이슈 분리, Stage report+commit 링크, 실제 실행 검증만 기록했는지 확인하도록 했다.

## 검증 결과

### 새 구조 키워드 확인

```bash
rg -n "대상 타스크|관련 이슈|후속 이슈 제안|최대 4|최대 5행|20줄 이하|body-file|작업 문서|커밋 링크|단계 보고서" \
  mydocs/manual/pr_process_guide.md \
  mydocs/skills/task-final-report/SKILL.md \
  mydocs/manual/git_workflow_guide.md \
  .github/copilot-instructions.md
```

결과: 통과. `대상 타스크`, 맥락용 `관련 이슈`, `후속 이슈 제안`, 짧게 강제하는 기준, `--body-file`, 작업 문서, Stage report+commit 링크 기준이 확인됐다.

### 제거 대상 확인

```bash
rg -n "문서 섹션|## 문서|Closes #" \
  mydocs/manual/pr_process_guide.md \
  mydocs/skills/task-final-report/SKILL.md
```

결과: 출력 없음. `rg` exit code는 1이며, 이번 검증에서는 제거 대상 문자열이 없다는 의미로 기대 결과다.

### 문서 형식 확인

```bash
git diff --check -- \
  mydocs/manual/pr_process_guide.md \
  mydocs/skills/task-final-report/SKILL.md \
  mydocs/manual/git_workflow_guide.md \
  .github/copilot-instructions.md \
  mydocs/working/task_m010_112_stage3.md
```

결과: 통과.

## 잔여 위험

- `task-final-report`는 PR 본문 파일 작성을 절차로 명시하지만, 아직 PR body lint 스크립트는 없다. 반복 실수가 생기면 별도 이슈에서 자동 검증을 검토한다.
- `--template` 중심 예시가 줄었기 때문에, 초안 PR을 GitHub UI에서 직접 만드는 경우 작성자가 템플릿 주석을 직접 지워야 한다. 이 위험은 PR 처리 가이드의 `--body-file` 우선 기준으로 낮춘다.
- Stage commit URL은 full SHA를 링크 대상으로 쓰는 편이 안정적이다. 가이드 예시는 짧은 표시 텍스트와 `{stage_sha}` 링크 placeholder를 함께 보여준다.

## 다음 단계 영향

Stage 4에서는 전체 정합성을 검증하고 최종 보고서와 오늘할일 완료 처리를 진행한다.

특히 다음을 최종 확인한다.

- PR 템플릿, PR 처리 가이드, `task-final-report`가 같은 용어를 사용하는지
- Stage별 요약의 단계 보고서 링크와 commit 링크 기준이 모두 남아 있는지
- 조건부 Before/After 기준이 유지되는지
- 제거 대상인 `## 문서`, `Closes #`가 다시 생기지 않았는지

## 승인 요청

이 Stage 3 결과 기준으로 Stage 4: 통합 검증과 최종 보고를 진행할지 승인 요청한다.
