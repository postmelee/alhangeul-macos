# Issue #64 Stage 3 완료 보고서

## 단계 목적

Stage 2에서 변경한 `task-register` Skill의 label 최소화 규칙이 전체 이슈 등록 절차와 충돌하지 않는지 통합 검증한다.

## 검증 대상

- `mydocs/skills/task-register/SKILL.md`
- Stage 1 보고서: `mydocs/working/task_m010_64_stage1.md`
- Stage 2 보고서: `mydocs/working/task_m010_64_stage2.md`

## 확인 결과

### Skill 절차 흐름

`task-register`의 기존 흐름은 유지됐다.

1. 중복 이슈 확인
2. 열린 milestone 목록 확인
3. 기존 label 목록 확인
4. milestone 후보 선택
5. label 후보 선택
6. 이슈 초안 작성
7. 이슈 생성 전 승인 요청
8. 승인 후 이슈 생성
9. 생성 결과 확인
10. `task-start` 진입 승인 요청

이번 변경은 5단계, 6단계, 검증 섹션만 보강한다. 이슈 생성 시점이나 `task-start` 책임 경계에는 영향을 주지 않는다.

### 유지된 기존 원칙

| 원칙 | 확인 결과 |
|------|-----------|
| label 목록은 live 조회 결과를 기준으로 판단 | 유지 |
| 기억하고 있는 과거 label 목록으로 단정하지 않음 | 유지 |
| 조회된 기존 label만 후보로 사용 | 유지 |
| 새 label 생성 금지 | 유지 |
| label이 모호하면 label 없이 생성하거나 작업지시자 확인 | 유지 |
| 이슈 생성 전 제목/본문/milestone/label 초안 승인 필요 | 유지 |
| 이슈 생성 후 `task-start` 진입 승인 요청 | 유지 |

### 새로 검증한 규칙

| 규칙 | 확인 결과 |
|------|-----------|
| `type label 1개 + area label 1~2개 + kind/status label 0~1개` 제한 | 반영됨 |
| type label은 작업 성격을 나타내는 label 중 1개 우선 선택 | 반영됨 |
| `area:*`는 주 작업 소유 영역 기준 선택 | 반영됨 |
| `kind:*`는 처리 방식이나 맥락 구분이 필요할 때만 선택 | 반영됨 |
| 일반 이슈는 2~4개 label 권장 | 반영됨 |
| 5개 이상 label은 예외 사유와 작업지시자 확인 필요 | 반영됨 |
| 이슈 초안에 type/area/kind 기준 선택 이유 기재 | 반영됨 |
| 검증 섹션에 label 개수와 예외 사유 기준 추가 | 반영됨 |

## 실행한 명령

```bash
git diff --check
rg -n "label 후보 선택|type label|area label|kind/status|2~4개|5개 이상|작업지시자 확인|새 label은 만들지 않는다" \
  mydocs/skills/task-register/SKILL.md
git status --short --branch
sed -n '1,140p' mydocs/skills/task-register/SKILL.md
```

## 검증 결과

```text
git diff --check
```

결과: 통과.

```text
rg -n "label 후보 선택|type label|area label|kind/status|2~4개|5개 이상|작업지시자 확인|새 label은 만들지 않는다" mydocs/skills/task-register/SKILL.md
```

결과:

- `label 후보 선택` 위치 확인
- `type label`, `area label`, `kind/status` 기준 확인
- `2~4개`, `5개 이상`, `작업지시자 확인` 예외 기준 확인
- `새 label은 만들지 않는다` 기존 제한 유지 확인

```text
git status --short --branch
```

결과: Stage 3 보고서 작성 전 작업 트리는 `local/task64...origin/devel [ahead 4]` 상태였고 미커밋 변경은 없었다.

## 완료 조건 확인

| 완료 조건 | 결과 |
|-----------|------|
| Skill 본문 변경이 검증됨 | 충족 |
| 단계 보고서에 검증 명령과 결과가 기록됨 | 충족 |
| 최종 보고서 작성 단계로 넘어갈 수 있음 | 충족 |

## 잔여 위험

- 실제 신규 이슈 등록 시 label 개수 판단은 작업 성격과 live label description에 따라 달라질 수 있다. Skill은 기준을 제공하지만, 모호한 경우 작업지시자 확인을 계속 요구한다.
- 5개 이상 label 예외 기준은 문서화되었지만 자동 강제는 아니다. 이 절차는 에이전트와 작업지시자의 승인 흐름으로 통제한다.

## 승인 요청 사항

본 Stage 3 결과 기준으로 Stage 4: 최종 보고와 오늘할일 완료 처리를 진행할지 승인 요청한다.
