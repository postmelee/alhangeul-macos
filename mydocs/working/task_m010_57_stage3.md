# Issue #57 Stage 3 완료 보고서

## 단계 목적

`task-register` 신규 Skill이 실제 하이퍼-워터폴 흐름에서 누락되지 않도록 타스크 진행 매뉴얼에 이슈 등록 선행 절차와 `task-start` 책임 경계를 반영한다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `mydocs/manual/task_workflow_guide.md` | 타스크 번호 관리, 타스크 진행 절차, SKILL 호출 표시 안내에 `task-register` 반영 |
| `mydocs/manual/document_structure_guide.md` | 마일스톤 미정 FAQ에 이슈가 없는 경우 `task-register`로 milestone 확인 후 승인받는 안내 추가 |

## 변경 내용

### 타스크 번호 관리

기존에는 새 타스크 등록을 `gh issue create` 한 줄 예시로만 안내했다. 이를 `task-register` 선행 절차로 바꾸고, 이미 이슈 번호가 있는 작업은 `task-start`로 시작한다는 경계를 추가했다.

정리된 책임 경계:

- `task-register`: 이슈가 없는 작업의 중복 이슈, milestone, label 확인과 GitHub Issue 생성
- `task-start`: 생성된 이슈 번호를 기준으로 브랜치, 오늘할일, 수행계획서 생성

### 타스크 진행 절차

1단계와 2단계를 다음 흐름으로 조정했다.

- 이슈가 없는 작업은 `task-register`로 GitHub Issue 등록
- 기존 이슈가 있으면 해당 번호 사용
- 작업지시자가 지정한 이슈를 `task-start`로 시작

### SKILL 호출 표시 안내

권장 호출 표시 예시에 `task-register 스킬을 호출합니다.`를 추가했다. 이 표시는 묵시 호출 허용이 아니라, 작업지시자의 명시 지시나 단계 승인에 따라 해당 절차를 적용한다는 사실을 알리는 용도다.

### 문서 구조 매뉴얼

마일스톤 미정 FAQ에 이슈가 아직 없는 경우를 보강했다. 신규 문서명에 필요한 마일스톤은 이슈 생성 전에 `task-register`에서 열린 milestone을 확인하고 작업지시자 승인을 받아 확정하도록 안내했다.

## 검증 결과

구현계획서의 Stage 3 검증 명령을 실행했다.

```bash
rg -n "task-register|이슈가 없는|새 타스크 등록|task-start|SKILL 호출 표시" \
  mydocs/manual/task_workflow_guide.md \
  mydocs/manual/document_structure_guide.md
git diff --check -- \
  mydocs/manual/task_workflow_guide.md \
  mydocs/manual/document_structure_guide.md \
  mydocs/working/task_m010_57_stage3.md
```

결과:

- `task_workflow_guide.md`에서 `task-register`와 `task-start` 책임 경계 확인
- `task_workflow_guide.md`에서 이슈가 없는 작업의 선행 등록 절차 확인
- `task_workflow_guide.md`의 SKILL 호출 표시 안내에 `task-register` 포함 확인
- `document_structure_guide.md`의 마일스톤 FAQ 보강 확인
- Stage 3 변경 파일 공백 검증 통과

추가 확인:

```bash
git diff --check
```

결과:

- 전체 변경 파일 공백 검증 통과

## 새 강제 규칙 여부

이번 단계는 기존 하이퍼-워터폴 규칙의 누락된 선행 절차를 매뉴얼에 연결한 것이다. 새 workflow 강제 규칙을 만들지 않고, `task-register`와 `task-start`의 책임 경계를 설명하는 수준으로 제한했다.

## 잔여 위험

- `task-register`가 추가됐지만 실제 호출 가능 여부는 Stage 4에서 `.agents`와 `.claude` 심볼릭 링크 경로를 포함해 다시 통합 확인한다.
- 문서 구조 매뉴얼의 마일스톤 FAQ는 간단히 보강했다. milestone 선택 기준 상세는 `task-register` Skill 본문에 둔다.

## 다음 단계 영향

Stage 4에서는 신규 Skill 경로, 심볼릭 링크 노출, Skill/매뉴얼 책임 경계 문구를 통합 검증하고 최종 보고서와 오늘할일 완료 처리를 진행한다.

## 승인 요청

Stage 4 통합 검증과 최종 보고로 진행할지 승인 요청한다.
