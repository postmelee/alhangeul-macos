# Issue #49 Stage 3 완료 보고서

## 단계 목적

`mydocs/manual/task_workflow_guide.md`가 단독 문서로 읽혀도 하이퍼-워터폴 단계 진행, 실패 회복, 단계 분할 기준, 보고서 위치, SKILL 호출 표시 방식을 이해할 수 있도록 보강한다.

## 산출물

- `mydocs/manual/task_workflow_guide.md`: 도입부 확장, 핵심 용어, FAQ/흔한 실수, SKILL 호출 표시 안내, 관련 매뉴얼 상호 참조 추가
- `mydocs/working/task_m010_49_stage3.md`: 본 단계 완료 보고서

## 본문 변경 정도

- 기존 타스크 번호 관리, 15단계 절차, 작업 규칙, 승인 간주 조건은 유지했다.
- 새로 추가한 내용은 용어 정의, 실패 회복, 단계 분할, 보고서 위치 보정, SKILL 호출 표시 안내에 한정했다.
- SKILL 호출 표시 안내는 자동 호출 허용이 아니라 승인된 절차 적용 사실을 사용자에게 명시하는 안내로 작성했다.

## SKILL 호출 표시 반영

다음 예시 문구를 매뉴얼에 추가했다.

- `task-stage-report 스킬을 호출합니다.`
- `task-final-report 스킬로 진행합니다.`
- `pr-merge-cleanup 스킬을 호출합니다.`

또한 `task-start`, `external-pr-review` 예시도 함께 포함했다.

## 검증 결과

검증 명령:

```bash
rg -n "핵심 용어|FAQ|SKILL 호출 표시|관련 매뉴얼|task-stage-report 스킬을 호출합니다|task-final-report 스킬로 진행합니다|pr-merge-cleanup 스킬을 호출합니다" mydocs/manual/task_workflow_guide.md
wc -l mydocs/manual/task_workflow_guide.md
git diff --check
```

결과:

- `핵심 용어`, `FAQ / 흔한 실수`, `SKILL 호출 표시 안내`, `관련 매뉴얼` 섹션 확인 완료
- 요청된 SKILL 호출 표시 예시 3종 확인 완료
- `task_workflow_guide.md`는 100줄로 200줄 권장 기준 이하
- `git diff --check` 통과

## 잔여 위험

- "SKILL 호출 표시"를 묵시 호출 허용으로 오해하지 않도록 문서에 구분을 명시했지만, 실제 운영 중 혼동 사례가 나오면 FAQ 예시를 더 추가할 수 있다.
- Stage 4에서 3개 매뉴얼 전체의 섹션 존재와 줄 수를 다시 확인해야 한다.

## 다음 단계 영향

Stage 4에서는 3개 매뉴얼의 도입부·핵심 용어·FAQ·상호 참조 존재 여부, 200줄 이하 유지, 새 강제 규칙 미도입 여부를 통합 검증하고 최종 보고서를 작성한다.

## 승인 요청

Stage 3 결과를 검토한 뒤 Stage 4 통합 검증과 최종 보고 진행 승인을 요청한다.
