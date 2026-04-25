---
name: task-stage-report
description: |
  하이퍼-워터폴 타스크의 단계 종료 절차를 적용한다. 명시 호출 시에만 사용한다.
  단계별 완료 보고서(`_stage{N}.md`) 작성, 단계 소스와 보고서 묶음 커밋,
  단계 검증 명령 실행을 수행한다. 한 단계가 끝나고 다음 단계 진입 직전에 호출.
allow_implicit_invocation: false
---

# 하이퍼-워터폴 단계 종료 보고

## 트리거

- 명시 호출만: 작업지시자가 "Stage {N} 마무리", "단계 보고서 작성"을 명시 지시한 경우
- 본 SKILL을 직접 호출한 경우

## 사전 조건

- 구현 계획서(`task_m{milestone}_{N}_impl.md`)가 존재하고 작업지시자 승인됨
- 현재 단계의 작업 항목이 모두 코드/문서에 반영됨
- 작업 브랜치는 `local/task{N}`

## 절차

1. 단계별 검증 명령 실행 (구현 계획서의 해당 단계 "검증" 섹션 그대로)
   - 결과를 보고서에 인용할 수 있도록 출력 보존
2. 단계 보고서 작성: `mydocs/working/task_m{milestone}_{N}_stage{S}.md`
   - 표준 섹션:
     - 단계 목적
     - 산출물 (파일 목록 + 라인 수 또는 요약)
     - 본문 변경 정도 / 본문 무손실 여부 (해당 시)
     - 검증 결과 (위 1번 출력 인용)
     - 잔여 위험
     - 다음 단계 영향
     - 승인 요청 (다음 단계 진입 또는 PR 단계)
3. 변경 점검
   ```bash
   git status --short
   git diff --check
   ```
4. 단계 소스 + 보고서 묶음 커밋
   ```bash
   git add {단계 산출 파일들} mydocs/working/task_m{milestone}_{N}_stage{S}.md
   git commit -m "Task #{N} Stage {S}: {핵심 내용 요약}"
   ```
   - 하위 단계: `Task #{N} [Stage {S.M}]: 내용`
   - 최종 단계 + 최종 보고서 묶음: `Task #{N} Stage {S} + 최종 보고서: 내용` (이 경우 별도 SKILL `task-final-report`로 처리 권장)
5. 작업지시자에게 단계 보고서 검토와 다음 단계 진입 승인 요청

## 검증

- `git log --oneline -1`이 단계 커밋 메시지 표준 형식 충족
- `mydocs/working/task_m{milestone}_{N}_stage{S}.md` 존재
- 단계별 검증 명령이 실패 없이 통과 (실패 시 단계 미완료로 처리하고 보고서 작성 보류)

## 절대 하지 말 것

- 검증 실패 상태로 보고서 작성·커밋
- 단계 산출물과 보고서를 분리해 별도 커밋 (한 단계는 한 커밋 원칙)
- 작업지시자 승인 없이 다음 단계 진입

## 호출 방법

- Codex: `$task-stage-report` 또는 `/skills` 메뉴
- Claude Code: `/task-stage-report`
