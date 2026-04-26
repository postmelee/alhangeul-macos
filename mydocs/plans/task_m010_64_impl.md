# Issue #64 구현 계획서

수행계획서: `mydocs/plans/task_m010_64.md`

## 작업명

task-register Skill label 선택 규칙 보강

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_64.md`를 기준으로 진행한다.
- 변경 대상은 `task-register` Skill의 label 선택 절차와 검증 기준으로 한정한다.
- 신규 GitHub label 생성, 기존 이슈 label 재정리, milestone 변경은 수행하지 않는다.
- 기존 원칙인 live label 목록 조회, 기존 label만 사용, 새 label 생성 금지는 유지한다.
- label 선택 규칙은 신규 이슈 등록 시 읽기 부담이 커지지 않도록 짧고 실행 가능한 문장으로 작성한다.
- 문서와 Skill 절차 보강만 수행하므로 Rust/Swift/Xcode 빌드 검증은 수행하지 않는다.

## Stage 1: 현재 label 선택 절차와 보강 위치 확정

대상:

- `mydocs/skills/task-register/SKILL.md`
- `mydocs/plans/task_m010_64.md`
- 현재 GitHub label 체계

작업:

1. `task-register` Skill의 현재 label 조회, 후보 선택, 이슈 초안 작성, 검증 섹션을 다시 확인한다.
2. label 최소화 규칙을 넣을 정확한 위치를 확정한다.
3. 검증 섹션에 추가할 label 개수와 선택 이유 기준을 확정한다.
4. 기존 원칙과 충돌하지 않는 문구를 정리한다.
5. Stage 1 단계 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_64_stage1.md`

검증:

```bash
rg -n "기존 label 목록 확인|label 후보 선택|이슈 초안 작성|검증|새 label" \
  mydocs/skills/task-register/SKILL.md
git diff --check -- mydocs/working/task_m010_64_stage1.md
```

완료 조건:

- Skill 본문에서 수정할 섹션이 Stage 1 보고서에 명시되어 있다.
- `type`, `area`, `kind/status` 기준을 어느 항목에 추가할지 확정되어 있다.
- 5개 이상 label 예외 처리 규칙의 위치가 확정되어 있다.

커밋:

```text
Task #64 Stage 1: task-register label 선택 규칙 보강 위치 확정
```

## Stage 2: task-register Skill label 최소화 규칙 반영

대상:

- `mydocs/skills/task-register/SKILL.md`

작업:

1. `label 후보 선택` 단계에 다음 기준을 추가한다.
   - type label 1개 우선 선택
   - area label은 주 작업 소유 영역 기준으로 1~2개 선택
   - kind/status label은 처리 방식이나 맥락 구분이 필요할 때 0~1개 선택
   - 일반 이슈는 2~4개 label 권장
   - 5개 이상 label은 예외 사유와 작업지시자 확인 필요
2. `이슈 초안 작성` 단계의 label 설명에 선택 이유와 예외 사유 기재 기준을 보강한다.
3. `검증` 섹션에 label 개수와 선택 이유 검증 기준을 추가한다.
4. "새 label은 만들지 않는다"와 "조회된 기존 label만 후보" 원칙이 유지되는지 확인한다.
5. Stage 2 단계 보고서를 작성한다.

산출물:

- `mydocs/skills/task-register/SKILL.md`
- `mydocs/working/task_m010_64_stage2.md`

검증:

```bash
rg -n "type label|area label|kind/status|2~4개|5개 이상|선택 이유|새 label은 만들지 않는다" \
  mydocs/skills/task-register/SKILL.md
git diff --check -- \
  mydocs/skills/task-register/SKILL.md \
  mydocs/working/task_m010_64_stage2.md
```

완료 조건:

- 신규 이슈 등록 시 label을 보통 2~4개로 제한하는 규칙이 Skill에 반영되어 있다.
- `area:*`는 관련 영역 전체가 아니라 주 작업 소유 영역 기준으로 고른다는 문구가 있다.
- 5개 이상 label을 붙일 때 작업지시자 확인이 필요하다는 문구가 있다.
- 기존 label만 사용하고 새 label을 만들지 않는 기존 제한이 유지된다.

커밋:

```text
Task #64 Stage 2: task-register label 최소화 규칙 반영
```

## Stage 3: 통합 검증과 단계 결과 정리

대상:

- `mydocs/skills/task-register/SKILL.md`
- Stage 1~2 단계 보고서

작업:

1. Skill 전체를 읽어 label 최소화 규칙이 이슈 생성 절차 흐름과 자연스럽게 이어지는지 확인한다.
2. live label 목록 조회 원칙, 새 label 생성 금지, 생성 전 승인 원칙이 손상되지 않았는지 확인한다.
3. 검색 기반 검증으로 핵심 문구가 모두 존재하는지 확인한다.
4. `git diff --check`로 전체 문서 변경을 검증한다.
5. Stage 3 단계 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_64_stage3.md`

검증:

```bash
git diff --check
rg -n "label 후보 선택|type label|area label|kind/status|2~4개|5개 이상|작업지시자 확인|새 label은 만들지 않는다" \
  mydocs/skills/task-register/SKILL.md
git status --short
```

완료 조건:

- Skill 본문 변경이 검증된다.
- 단계 보고서에 검증 명령과 결과가 기록되어 있다.
- 최종 보고서 작성 단계로 넘어갈 수 있다.

커밋:

```text
Task #64 Stage 3: task-register label 규칙 검증
```

## Stage 4: 최종 보고와 오늘할일 완료 처리

대상:

- `mydocs/report/task_m010_64_report.md`
- `mydocs/orders/20260426.md`
- 전체 변경 파일

작업:

1. 최종 결과 보고서를 작성한다.
2. 오늘할일에서 #64 상태를 완료로 바꾸고 완료 시각을 기록한다.
3. 전체 변경 범위와 검증 결과를 최종 확인한다.
4. PR 게시 전 working tree 상태를 확인한다.

산출물:

- `mydocs/report/task_m010_64_report.md`
- `mydocs/orders/20260426.md`

검증:

```bash
git diff --check
rg -n "#64|task-register Skill label 선택 규칙 보강|완료:" mydocs/orders/20260426.md
test -f mydocs/report/task_m010_64_report.md
git status --short
```

완료 조건:

- 최종 보고서와 오늘할일 완료 처리가 끝난다.
- 전체 변경이 커밋되어 PR 게시 승인 요청이 가능하다.
- Skill 변경 범위가 `task-register` label 선택 규칙 보강에 한정되어 있다.

커밋:

```text
Task #64 Stage 4 + 최종 보고서: task-register label 규칙 보강 결과 정리
```

## 단계별 커밋 메시지

| Stage | 커밋 메시지 |
|-------|-------------|
| 1 | `Task #64 Stage 1: task-register label 선택 규칙 보강 위치 확정` |
| 2 | `Task #64 Stage 2: task-register label 최소화 규칙 반영` |
| 3 | `Task #64 Stage 3: task-register label 규칙 검증` |
| 4 | `Task #64 Stage 4 + 최종 보고서: task-register label 규칙 보강 결과 정리` |

## 후속 작업

- Stage 4 완료 후 작업지시자 승인 시 `task-final-report` 절차로 `publish/task64` push와 draft PR 생성을 진행한다.
- PR merge 후 정리는 `pr-merge-cleanup` 절차로 수행한다.

## 승인 요청 사항

이 구현 계획서 기준으로 Stage 1을 진행할지 승인 요청한다. 승인 전에는 `task-register` Skill 본문을 수정하지 않는다.
