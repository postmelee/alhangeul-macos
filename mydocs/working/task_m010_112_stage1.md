# Task #112 Stage 1 완료 보고서

## 단계 목적

현재 PR 템플릿, PR 처리 가이드, `task-final-report` 절차의 중복과 충돌 지점을 정리하고, Stage 2~3에서 어떤 문구를 삭제·이동·유지할지 확정했다.

이번 단계는 조사와 기준 확정만 수행했다. `.github/pull_request_template.md`, `mydocs/manual/pr_process_guide.md`, `mydocs/skills/task-final-report/SKILL.md` 본문은 아직 수정하지 않았다.

## 조사 대상

| 파일 | 역할 | 라인 수 |
|------|------|--------|
| `.github/pull_request_template.md` | 실제 PR 본문 시작 템플릿 | 73 |
| `mydocs/manual/pr_process_guide.md` | 내부 task PR 작성 규칙과 외부 PR 검토 절차 | 195 |
| `mydocs/skills/task-final-report/SKILL.md` | 최종 보고와 draft PR 생성 절차 | 86 |
| `mydocs/manual/git_workflow_guide.md` | branch/publish/PR 링크 정책 | 114 |
| `.github/copilot-instructions.md` | PR review 관점의 자동 리뷰 지시 | 26 |

## 중복과 충돌 지점

### 1. `관련 이슈`의 의미 충돌

현재 템플릿과 PR 처리 가이드는 `관련 이슈`를 주로 `Closes #번호` 용도로 설명한다.

- `.github/pull_request_template.md`: `관련 이슈` 아래에 `Closes #` placeholder가 남아 있다.
- `mydocs/manual/pr_process_guide.md`: 기본 원칙과 섹션별 작성 기준에서 "merge 시 닫아도 되는 경우 Closes"를 안내한다.
- `mydocs/manual/pr_process_guide.md`: 작성 예시도 `Closes #22`를 사용한다.

확정 기준:

- 현재 PR이 직접 수행하는 이슈는 `요약` 안의 `대상 타스크`로 분리한다.
- `관련 이슈`는 PR 이해에 필요한 선행, 후속, Epic, upstream, 참고 PR/issue를 정리하는 하단 섹션으로 바꾼다.
- `Closes #` 기본 placeholder는 템플릿에서 제거한다.
- issue close 정책은 `관련 이슈`가 아니라 하이퍼-워터폴 merge/cleanup 절차에서 다룬다.

### 2. `문서` 섹션과 Stage 요약 분리

현재 구조는 `변경 내역`과 `문서`가 별도 최상위 섹션이다. 이 때문에 리뷰어가 Stage별 변경을 읽은 뒤 해당 단계 보고서로 바로 이동하기 어렵다.

확정 기준:

- 최상위 `## 문서` 섹션은 제거한다.
- `변경 내역` 안에 `Stage별 요약`, `주요 파일/영역`, `작업 문서`를 둔다.
- Task #61의 commit SHA 고정 URL, `[파일명](URL)` 표시 규칙은 `작업 문서` 주석과 `task-final-report` 검증에 유지한다.
- 수행 계획서, 구현 계획서, 최종 보고서는 `작업 문서` 하위 항목으로 짧게 묶는다.

### 3. Stage 보고서 링크와 커밋 링크 기준 부족

`mydocs/manual/pr_process_guide.md`는 Stage 커밋이 있으면 짧은 SHA를 함께 적으라고 안내하지만, 템플릿과 `task-final-report`는 단계 보고서 링크와 커밋 링크를 함께 쓰는 형식을 강제하지 않는다.

확정 기준:

```md
- **[Stage 1](stage-url)** ([0cdbae0](commit-url)): 한 줄 요약
```

- `Stage 1` 텍스트는 해당 단계 보고서로 링크한다.
- `(0cdbae0)` 텍스트는 해당 Stage 커밋 URL로 링크한다.
- Stage별 요약은 Stage당 1줄을 유지한다.
- PR head SHA 기준 문서 링크와 실제 commit URL을 모두 `task-final-report` 검증 대상으로 둔다.

### 4. 검증 체크리스트 장황화

현재 템플릿은 기본 검증 명령을 여러 개 미체크 상태로 제공한다. 실제 실행한 항목만 남기라는 주석은 있지만, 작성자가 미실행 체크리스트를 그대로 둘 위험이 있다.

확정 기준:

- `검증` 섹션은 질문형 힌트 `어떻게 검증했나요?`만 유지한다.
- 실행하지 않은 항목은 삭제한다는 기준을 유지한다.
- Xcode/Rust/renderer 검증 명령은 템플릿 기본값이 아니라 PR 처리 가이드와 Copilot review 지시에 조건부 기대치로 남긴다.

### 5. 스크린샷과 Before/After 조건

현재 템플릿은 `스크린샷` 섹션을 마지막에 두고, 해당 없으면 삭제하라고 안내한다. Before/After 표는 없다.

확정 기준:

- `스크린샷`은 UI, Finder, Quick Look, Thumbnail, renderer 결과처럼 시각적 변경사항이 있을 때만 유지한다.
- 시각 변경이 있을 때만 Before/After 표를 사용한다.
- 실제 이미지나 산출물 없이 `Before: - / After: 신규 구현`처럼 형식만 채우는 방식은 채택하지 않는다.

### 6. `--template`와 `--body-file` 기본값

현재 `task-final-report`는 `gh pr create --template .github/pull_request_template.md`를 예시로 둔다. PR 처리 가이드는 `--body-file`을 이미 허용하지만 기본 운영 기준은 `--template` 중심이다.

확정 기준:

- PR 본문 품질 강화를 위해 `task-final-report`에서는 최종 보고서와 단계 보고서를 바탕으로 본문을 완성한 뒤 `--body-file`을 우선 사용하도록 바꾼다.
- `--template`은 초안 작성 출발점으로 남기되, 최종 PR 생성 경로의 기본값으로 두지 않는다.

## 파일별 다음 단계 처리

| 파일 | Stage 2~3 처리 |
|------|---------------|
| `.github/pull_request_template.md` | Stage 2에서 구조를 직접 개편한다. `## 문서`와 `Closes #` placeholder를 제거하고 질문형 프롬프트, Stage 링크+커밋 링크 예시, 조건부 Before/After 표를 반영한다. |
| `mydocs/manual/pr_process_guide.md` | Stage 3에서 내부 task PR 섹션을 새 구조로 다시 맞춘다. 외부 기여 PR 검토 절차는 유지한다. |
| `mydocs/skills/task-final-report/SKILL.md` | Stage 3에서 `--body-file` 우선, `변경 내역 > 작업 문서`, Stage 보고서 링크+커밋 링크 검증 기준으로 보정한다. |
| `mydocs/manual/git_workflow_guide.md` | 필요 시 용어만 최소 보정한다. 기존 commit SHA 고정 문서 링크 정책은 유지한다. |
| `.github/copilot-instructions.md` | 필요 시 "템플릿 사용과 실제 실행 검증" 문구만 최소 보강한다. |

## 검증 결과

### 검색 검증

```bash
rg -n "관련 이슈|Closes #|문서|검증|스크린샷|pull_request_template|body-file" \
  .github/pull_request_template.md \
  mydocs/manual/pr_process_guide.md \
  mydocs/skills/task-final-report/SKILL.md \
  mydocs/manual/git_workflow_guide.md \
  .github/copilot-instructions.md
```

결과:

- `관련 이슈`와 `Closes #`가 템플릿과 PR 처리 가이드에 남아 있어 의미 충돌 확인.
- `문서` 섹션 기준이 템플릿, PR 처리 가이드, `task-final-report`에 반복되어 있음 확인.
- `body-file`은 PR 처리 가이드에만 운영 선택지로 있고, `task-final-report` 기본 생성 예시는 아직 `--template` 중심임 확인.
- Copilot 지시는 "실제 실행한 검증만 적는다"는 원칙만 짧게 갖고 있어 큰 충돌은 없음.

### 문서 형식 검증

```bash
git diff --check -- mydocs/working/task_m010_112_stage1.md
```

결과: 통과.

## 잔여 위험

- Stage 2에서 템플릿을 줄이는 과정에서 초보 작성자가 따라 쓸 예시가 부족해질 수 있다. 질문형 프롬프트와 짧은 예시만 남겨 균형을 맞춘다.
- Stage 커밋 URL은 PR head commit SHA 기반 문서 링크와 성격이 다르다. Stage 커밋 자체를 직접 링크해야 하므로 `task-final-report`에서 두 링크 유형을 구분해 검증해야 한다.
- `관련 이슈` 의미 변경 후 issue close 안내가 사라진 것처럼 보일 수 있다. 직접 수행 issue는 `대상 타스크`로 보이고, close는 merge/cleanup 절차에 남긴다.

## 다음 단계 영향

Stage 2에서는 `.github/pull_request_template.md`만 수정한다. 이번 보고서의 결정에 따라 최상위 `문서` 섹션과 `Closes #` placeholder를 제거하고, `변경 내역` 안에 Stage 보고서 링크+커밋 링크 예시와 `작업 문서` 하위 항목을 넣는다.

## 승인 요청

이 Stage 1 결과 기준으로 Stage 2: PR 템플릿 구조 축약 개편을 진행할지 승인 요청한다.
