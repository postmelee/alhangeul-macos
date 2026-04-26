# Issue #64 Stage 2 완료 보고서

## 단계 목적

Stage 1에서 확정한 위치에 따라 `task-register` Skill 본문에 label 최소화 규칙과 예외 승인 기준을 반영한다.

## 변경 대상

- `mydocs/skills/task-register/SKILL.md`

## 변경 요약

`task-register` Skill의 기존 원칙은 유지했다.

- GitHub label 목록을 live 조회한다.
- 조회된 기존 label만 후보로 사용한다.
- 작업 성격이 label의 `name`/`description`과 명확히 대응할 때만 선택한다.
- 적합한 label이 없거나 애매하면 label 없이 생성하거나 작업지시자에게 확인한다.
- 새 label은 만들지 않는다.

위 원칙 위에 label 개수와 선택 기준을 추가했다.

## 상세 변경

### `5. label 후보 선택`

다음 규칙을 추가했다.

- label은 기본적으로 `type label 1개 + area label 1~2개 + kind/status label 0~1개`로 제한한다.
- type label은 `bug`, `documentation`, `enhancement`, `duplicate`, `question` 등 작업 성격을 나타내는 label 중 1개를 우선 고른다.
- `area:*` label은 영향을 받는 모든 영역이 아니라 주 작업 소유 영역 기준으로 고른다.
- `kind:*` label은 `kind:architecture`, `kind:automation`, `kind:regression`, `kind:verification`, `kind:follow-up`처럼 처리 방식이나 맥락을 실제로 구분할 때만 붙인다.
- 일반 이슈는 2~4개 label을 권장한다.
- 5개 이상 label이 필요하면 이슈 초안에 예외 사유를 적고 작업지시자 확인을 받는다.

### `6. 이슈 초안 작성`

label 선택 이유 작성 기준을 보강했다.

- label 선택 이유는 type/area/kind 기준으로 나누어 적는다.
- 5개 이상이면 예외 사유를 별도로 적는다.

### `검증`

생성된 이슈의 label 검증 기준을 보강했다.

- 일반 이슈 label은 2~4개 권장 범위인지 확인한다.
- 5개 이상 label이면 승인된 예외 사유가 생성 결과 보고에 포함되어야 한다.
- `area:*` label은 주 작업 소유 영역 기준으로 선택되어야 한다.

## 설계 판단

label 목록 전체를 Skill 본문에 복제하지 않았다. 실제 label 목록은 계속 live 조회 결과를 기준으로 판단해야 하기 때문이다.

`type`, `area`, `kind/status` 기준은 특정 저장소 label 체계를 설명하기 위한 운영 원칙으로만 추가했다. label이 새로 추가되거나 설명이 바뀌어도 `name`/`description` 기준 판단 원칙은 유지된다.

5개 이상 label은 금지하지 않았다. 대형 변경이나 교차 영역 작업에서는 필요할 수 있으므로, 예외 사유와 작업지시자 확인을 요구하는 방식으로 제한했다.

## 변경하지 않은 항목

- GitHub label 생성/삭제 없음
- 기존 GitHub Issue label 재정리 없음
- milestone 변경 없음
- `task-start`, `task-final-report` 등 다른 Skill 변경 없음
- 매뉴얼 변경 없음

## 실행한 명령

```bash
sed -n '52,108p' mydocs/skills/task-register/SKILL.md
git diff -- mydocs/skills/task-register/SKILL.md
```

## 검증 결과

구현계획서의 Stage 2 검증 명령을 실행했다.

```bash
rg -n "type label|area label|kind/status|2~4개|5개 이상|선택 이유|새 label은 만들지 않는다" \
  mydocs/skills/task-register/SKILL.md
git diff --check -- \
  mydocs/skills/task-register/SKILL.md \
  mydocs/working/task_m010_64_stage2.md
```

결과:

- label 최소화 핵심 문구 검색 통과
- `새 label은 만들지 않는다` 기존 제한 유지 확인
- Skill 본문과 Stage 2 보고서 공백 검증 통과

## 완료 조건 확인

| 완료 조건 | 결과 |
|-----------|------|
| 신규 이슈 등록 시 label을 보통 2~4개로 제한하는 규칙이 Skill에 반영되어 있음 | 충족 |
| `area:*`는 관련 영역 전체가 아니라 주 작업 소유 영역 기준으로 고른다는 문구가 있음 | 충족 |
| 5개 이상 label을 붙일 때 작업지시자 확인이 필요하다는 문구가 있음 | 충족 |
| 기존 label만 사용하고 새 label을 만들지 않는 기존 제한이 유지됨 | 충족 |

## 승인 요청 사항

본 Stage 2 결과 기준으로 Stage 3: 통합 검증과 단계 결과 정리를 진행할지 승인 요청한다.
