# Issue #112 구현 계획서

수행계획서: `mydocs/plans/task_m010_112.md`

## 작업명

PR 본문 구조와 관련 이슈 작성 규칙 강화

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_112.md`를 기준으로 진행한다.
- 기존 파일에 설명을 계속 추가하기보다, 중복되거나 현재 의미와 어긋난 내용을 줄이고 재배치한다.
- Task #24의 PR 템플릿 표준화 맥락과 Task #61의 commit SHA 고정 문서 링크 규칙은 보존한다.
- `관련 이슈`는 현재 PR의 직접 task issue가 아니라 선행, 후속, Epic, upstream, 참고 PR/issue를 정리하는 섹션으로 정의한다.
- 현재 PR이 직접 수행하는 issue는 `대상 타스크`로 분리한다.
- Stage별 요약에는 단계 보고서 링크와 짧은 커밋 링크를 함께 표시한다. 예: `**[Stage 1](stage-url)** ([0cdbae0](commit-url)): 요약`.
- JECT-Study/VS-4th-Client PR #3에서 확인한 질문형 프롬프트는 채택하되, 미실행 체크리스트와 이슈/문서/리스크 생략 방식은 채택하지 않는다.
- Before/After 표는 UI, Finder, Quick Look, Thumbnail, renderer 결과처럼 시각적 변경사항이 있을 때만 사용한다.
- 문서/운영 규격 변경이므로 Swift, Rust, Xcode 빌드 검증은 수행하지 않는다.

## Stage 1: 기존 규칙 중복과 충돌 지점 정리

대상:

- `.github/pull_request_template.md`
- `mydocs/manual/pr_process_guide.md`
- `mydocs/skills/task-final-report/SKILL.md`
- `mydocs/manual/git_workflow_guide.md`
- `.github/copilot-instructions.md`

작업:

1. 현재 PR 템플릿의 섹션과 주석을 새 구조와 대조한다.
2. `관련 이슈`, `문서`, `Closes #`, `검증`, `스크린샷` 문구가 어떤 파일에 중복되어 있는지 정리한다.
3. Task #61에서 도입한 문서 링크 규칙을 어느 섹션으로 옮겨도 보존되는지 확인한다.
4. Stage별 단계 보고서 링크와 커밋 링크를 어떤 형식으로 표시할지 확정한다.
5. 질문형 프롬프트와 조건부 Before/After 표를 넣을 위치를 확정한다.
6. Stage 1 단계 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_112_stage1.md`

검증:

```bash
rg -n "관련 이슈|Closes #|문서|검증|스크린샷|pull_request_template|body-file" \
  .github/pull_request_template.md \
  mydocs/manual/pr_process_guide.md \
  mydocs/skills/task-final-report/SKILL.md \
  mydocs/manual/git_workflow_guide.md \
  .github/copilot-instructions.md
git diff --check -- mydocs/working/task_m010_112_stage1.md
```

완료 조건:

- 어떤 문구를 삭제, 이동, 유지할지 Stage 1 보고서에 정리되어 있다.
- `대상 타스크`와 `관련 이슈`의 책임 분리가 확정되어 있다.
- Stage별 요약에 단계 보고서 링크와 커밋 링크를 함께 표시하는 형식이 확정되어 있다.
- Before/After 표는 시각 변경이 있을 때만 유지한다는 기준이 확정되어 있다.

커밋:

```text
Task #112 Stage 1: PR 본문 규칙 중복과 충돌 지점 정리
```

## Stage 2: PR 템플릿 구조 축약 개편

대상:

- `.github/pull_request_template.md`

작업:

1. 템플릿을 새 대단원 구조로 재배치한다.
   - `요약`
   - `변경 내역`
   - `핵심 리뷰 포인트`
   - `검증`
   - `스크린샷`
   - `관련 이슈`
   - `후속 이슈 제안`
   - `남은 리스크`
2. `요약` 주석에 질문형 프롬프트를 넣는다.
   - 대상 타스크는 무엇인가요?
   - 왜 변경했나요?
   - 무엇을 변경했나요?
   - 리뷰어가 먼저 볼 지점은 무엇인가요?
3. `변경 내역` 안에 Stage별 요약, 주요 파일/영역 표, 작업 문서 링크를 배치한다.
   - Stage 제목은 단계 보고서로 링크한다.
   - Stage 제목 옆에는 짧은 커밋 SHA를 commit URL로 링크한다.
   - 예: `- **[Stage 1](stage-url)** ([0cdbae0](commit-url)): 요약`
4. `문서` 최상위 섹션은 제거하되, commit SHA 고정 URL과 `[파일명](URL)` 규칙은 `작업 문서` 주석에 유지한다.
5. `스크린샷`은 시각적 변경사항이 있을 때만 유지하고, Before/After 표 예시를 짧게 둔다.
6. 미실행 체크리스트가 남지 않도록 검증 주석을 "실제 실행한 항목만 남김" 기준으로 축약한다.
7. Stage 2 단계 보고서를 작성한다.

산출물:

- `.github/pull_request_template.md`
- `mydocs/working/task_m010_112_stage2.md`

검증:

```bash
rg -n "대상 타스크|왜 변경했나요|무엇을 변경했나요|핵심 리뷰 포인트|후속 이슈 제안|Before|After|head_sha|commit-url|stage-url" \
  .github/pull_request_template.md
rg -n "## 문서|Closes #" .github/pull_request_template.md
git diff --check -- \
  .github/pull_request_template.md \
  mydocs/working/task_m010_112_stage2.md
```

완료 조건:

- PR 템플릿에 `대상 타스크`와 하단 `관련 이슈`가 분리되어 있다.
- 최상위 `## 문서` 섹션이 제거되고, 작업 문서 링크는 `변경 내역` 안에 있다.
- Stage별 요약에 단계 보고서 링크와 짧은 커밋 링크 예시가 있다.
- 질문형 프롬프트와 조건부 Before/After 표가 반영되어 있다.
- `Closes #` 기본 placeholder가 템플릿에서 사라져 있다.

커밋:

```text
Task #112 Stage 2: PR 템플릿 구조 축약 개편
```

## Stage 3: PR 처리 가이드와 task-final-report 절차 보정

대상:

- `mydocs/manual/pr_process_guide.md`
- `mydocs/skills/task-final-report/SKILL.md`
- 필요 시 `mydocs/manual/git_workflow_guide.md`
- 필요 시 `.github/copilot-instructions.md`

작업:

1. `pr_process_guide.md`의 내부 task PR 필수 섹션과 섹션별 작성 기준을 새 템플릿 구조에 맞춘다.
2. `관련 이슈`는 PR 이해를 위한 맥락 이슈이고, 직접 수행 issue는 `대상 타스크`에 적는다고 명시한다.
3. 짧게 강제하는 기준을 가이드에 반영한다.
   - `요약`: 최대 4 bullet
   - Stage별 요약: Stage당 1줄, 단계 보고서 링크와 짧은 커밋 링크 포함
   - 주요 파일/영역 표: 최대 5행
   - 핵심 리뷰 포인트: 최대 3개, 코드 블록은 각 20줄 이하
   - 검증: 실제 실행한 명령만 남김
4. `task-final-report`의 PR 생성/검증 절차에서 `문서` 섹션 검증을 `변경 내역 > 작업 문서` 기준으로 바꾼다.
5. `task-final-report`에 Stage별 요약의 단계 보고서 링크와 커밋 링크 작성/검증 기준을 추가한다.
6. `task-final-report`에 `--body-file` 우선 사용과 PR 본문 짧은 작성 기준을 반영한다.
7. Git 워크플로우나 Copilot 지시 문서에 새 용어와 충돌하는 문구가 있으면 최소 문장만 보정한다.
8. Stage 3 단계 보고서를 작성한다.

산출물:

- `mydocs/manual/pr_process_guide.md`
- `mydocs/skills/task-final-report/SKILL.md`
- 필요 시 `mydocs/manual/git_workflow_guide.md`
- 필요 시 `.github/copilot-instructions.md`
- `mydocs/working/task_m010_112_stage3.md`

검증:

```bash
rg -n "대상 타스크|관련 이슈|후속 이슈 제안|최대 4|최대 5행|20줄 이하|body-file|작업 문서|커밋 링크|단계 보고서" \
  mydocs/manual/pr_process_guide.md \
  mydocs/skills/task-final-report/SKILL.md \
  mydocs/manual/git_workflow_guide.md \
  .github/copilot-instructions.md
rg -n "문서 섹션|## 문서|Closes #" \
  mydocs/manual/pr_process_guide.md \
  mydocs/skills/task-final-report/SKILL.md
git diff --check -- \
  mydocs/manual/pr_process_guide.md \
  mydocs/skills/task-final-report/SKILL.md \
  mydocs/manual/git_workflow_guide.md \
  .github/copilot-instructions.md \
  mydocs/working/task_m010_112_stage3.md
```

완료 조건:

- PR 처리 가이드가 새 템플릿 구조와 같은 용어를 사용한다.
- `task-final-report` 검증 기준이 `변경 내역 > 작업 문서` 구조를 확인한다.
- 기존 commit SHA 고정 문서 링크 규칙이 유지된다.
- Stage별 요약의 단계 보고서 링크와 커밋 링크 기준이 절차에 반영되어 있다.
- `관련 이슈`와 issue close 안내가 섞이지 않는다.

커밋:

```text
Task #112 Stage 3: PR 작성 가이드와 final-report 절차 보정
```

## Stage 4: 통합 검증과 최종 보고

대상:

- 전체 변경 파일
- `mydocs/orders/20260501.md`
- `mydocs/report/task_m010_112_report.md`

작업:

1. 전체 diff whitespace 검증을 실행한다.
2. 템플릿, 가이드, Skill의 핵심 문구가 같은 의미로 맞춰져 있는지 검색한다.
3. `관련 이슈`, `대상 타스크`, `작업 문서`, Stage별 커밋 링크, `스크린샷` 기준이 서로 충돌하지 않는지 최종 확인한다.
4. 오늘할일에서 #112 상태를 완료로 바꾸고 완료 시각을 기록한다.
5. 최종 결과 보고서를 작성한다.
6. Stage 4 단계 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_112_stage4.md`
- `mydocs/report/task_m010_112_report.md`
- `mydocs/orders/20260501.md`

검증:

```bash
git diff --check
for pattern in "대상 타스크" "관련 이슈" "후속 이슈 제안" "핵심 리뷰 포인트" "작업 문서" "단계 보고서" "Before" "After"; do
  rg -n "$pattern" .github/pull_request_template.md
done
for pattern in "대상 타스크" "관련 이슈" "후속 이슈 제안" "최대 4" "최대 5행" "20줄 이하" "작업 문서" "단계 보고서" "Before/After"; do
  rg -n "$pattern" mydocs/manual/pr_process_guide.md
done
for pattern in "Open PR" "body-file" "핵심 리뷰 포인트" "후속 이슈 제안" "작업 문서" "단계 보고서" "Before/After"; do
  rg -n "$pattern" mydocs/skills/task-final-report/SKILL.md
done
rg -n "## 문서|Closes #" \
  .github/pull_request_template.md \
  mydocs/manual/pr_process_guide.md \
  mydocs/skills/task-final-report/SKILL.md
rg -n "^\| #112 \|.*\| 완료 \|.*완료: [0-9]{2}:[0-9]{2}" mydocs/orders/20260501.md
test -f mydocs/report/task_m010_112_report.md
git status --short
```

완료 조건:

- 최종 보고서와 오늘할일 완료 처리가 끝난다.
- 전체 변경이 커밋되어 PR 게시 승인 요청이 가능하다.
- PR 템플릿, PR 처리 가이드, `task-final-report`의 용어가 정합하다.
- Stage별 요약에 단계 보고서 링크와 짧은 커밋 링크를 함께 쓰는 기준이 문서화되어 있다.
- 시각 변경이 있을 때만 Before/After 표를 쓰는 기준이 문서화되어 있다.

커밋:

```text
Task #112 Stage 4 + 최종 보고서: PR 본문 규칙 강화 결과 정리
```

## 단계별 커밋 메시지

| Stage | 커밋 메시지 |
|-------|-------------|
| 1 | `Task #112 Stage 1: PR 본문 규칙 중복과 충돌 지점 정리` |
| 2 | `Task #112 Stage 2: PR 템플릿 구조 축약 개편` |
| 3 | `Task #112 Stage 3: PR 작성 가이드와 final-report 절차 보정` |
| 4 | `Task #112 Stage 4 + 최종 보고서: PR 본문 규칙 강화 결과 정리` |

## 후속 작업

- Stage 4 완료 후 작업지시자 승인 시 `task-final-report` 절차로 `publish/task112` push와 Open PR 생성을 진행한다.
- PR merge 후 정리는 `pr-merge-cleanup` 절차로 수행한다.
- PR body lint 스크립트는 이번 범위에서 제외하며, 같은 실수가 반복될 때 별도 이슈로 검토한다.

## 승인 요청 사항

이 구현 계획서 기준으로 Stage 1을 진행할지 승인 요청한다. 승인 전에는 PR 템플릿, PR 처리 가이드, `task-final-report` 본문을 수정하지 않는다.
