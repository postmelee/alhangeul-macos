# Issue #64 최종 결과 보고서

## 작업 요약

- GitHub Issue: #64
- Milestone: v0.1.0
- 문서 prefix: `task_m010_64`
- 작업명: task-register Skill label 선택 규칙 보강
- 작업 브랜치: `local/task64`
- 단계 수: 4단계

`task-register` Skill에 신규 이슈 등록 시 label을 과하게 붙이지 않도록 최소화 규칙을 추가했다. 기존 live label 조회, 기존 label만 사용, 새 label 생성 금지, 이슈 생성 전 승인 원칙은 유지하면서, label 후보 선택 단계에 `type`, `area`, `kind/status` 기준을 명시했다.

## 단계별 결과

| Stage | 결과 | 산출물 |
|-------|------|--------|
| Stage 1 | 현재 label 선택 절차와 보강 위치 확정 | `mydocs/working/task_m010_64_stage1.md` |
| Stage 2 | `task-register` Skill label 최소화 규칙 반영 | `mydocs/skills/task-register/SKILL.md`, `mydocs/working/task_m010_64_stage2.md` |
| Stage 3 | 통합 검증과 단계 결과 정리 | `mydocs/working/task_m010_64_stage3.md` |
| Stage 4 | 최종 보고, 오늘할일 완료 처리 | `mydocs/working/task_m010_64_stage4.md`, 본 보고서 |

## 변경 파일과 영향 범위

| 파일 | 영향 |
|------|------|
| `mydocs/skills/task-register/SKILL.md` | 신규 이슈 등록 시 label 선택 최소화 규칙 추가 |
| `mydocs/orders/20260426.md` | #64 오늘할일 완료 처리 |
| `mydocs/plans/task_m010_64.md` | 수행계획서 |
| `mydocs/plans/task_m010_64_impl.md` | 구현계획서 |
| `mydocs/working/task_m010_64_stage1.md` | Stage 1 완료 보고 |
| `mydocs/working/task_m010_64_stage2.md` | Stage 2 완료 보고 |
| `mydocs/working/task_m010_64_stage3.md` | Stage 3 완료 보고 |
| `mydocs/working/task_m010_64_stage4.md` | Stage 4 완료 보고 |
| `mydocs/report/task_m010_64_report.md` | 최종 결과 보고 |

Rust, Swift, Xcode project, build script, GitHub label, milestone, 기존 Issue label은 변경하지 않았다.

## 반영된 label 선택 규칙

`task-register` Skill의 `label 후보 선택` 단계에 다음 기준을 추가했다.

- label은 기본적으로 `type label 1개 + area label 1~2개 + kind/status label 0~1개`로 제한한다.
- type label은 `bug`, `documentation`, `enhancement`, `duplicate`, `question` 등 작업 성격을 나타내는 label 중 1개를 우선 고른다.
- `area:*` label은 영향을 받는 모든 영역이 아니라 주 작업 소유 영역 기준으로 고른다.
- `kind:*` label은 처리 방식이나 맥락을 실제로 구분할 때만 붙인다.
- 일반 이슈는 2~4개 label을 권장한다.
- 5개 이상 label이 필요하면 이슈 초안에 예외 사유를 적고 작업지시자 확인을 받는다.

`이슈 초안 작성` 단계에는 type/area/kind 기준의 선택 이유와 5개 이상 예외 사유 기재 기준을 추가했다. `검증` 섹션에는 label 개수, 예외 사유, `area:*` 주 작업 소유 영역 기준 확인을 추가했다.

## 유지된 원칙

| 원칙 | 결과 |
|------|------|
| GitHub label 목록을 live 조회한다 | 유지 |
| 기억하고 있는 과거 label 목록으로 단정하지 않는다 | 유지 |
| 조회된 기존 label만 후보로 사용한다 | 유지 |
| 새 label은 만들지 않는다 | 유지 |
| label이 애매하면 label 없이 생성하거나 작업지시자에게 확인한다 | 유지 |
| 이슈 생성 전 제목/본문/milestone/label 초안을 승인받는다 | 유지 |
| 이슈 생성 후 `task-start` 진입 승인 요청으로 멈춘다 | 유지 |

## 검증 결과

실행한 검증:

```bash
git diff --check
rg -n "label 후보 선택|type label|area label|kind/status|2~4개|5개 이상|작업지시자 확인|새 label은 만들지 않는다" \
  mydocs/skills/task-register/SKILL.md
rg -n "#64|task-register Skill label 선택 규칙 보강|완료:" mydocs/orders/20260426.md
test -f mydocs/report/task_m010_64_report.md
git status --short
```

결과:

- `git diff --check` 통과
- `task-register` Skill에서 label 최소화 핵심 문구 검색 확인
- 오늘할일 #64 완료 처리 확인
- 최종 보고서 파일 존재 확인
- Stage 4 커밋 전 변경 파일은 최종 보고서, Stage 4 보고서, 오늘할일로 한정됨

문서와 Skill 절차 보강만 수행했으므로 Rust/Swift/Xcode 빌드 검증은 수행하지 않았다.

## 수용 기준

| 기준 | 결과 |
|------|------|
| 신규 이슈 등록 시 label을 보통 2~4개로 제한하는 규칙 반영 | OK |
| `area:*`는 관련 영역 전체가 아니라 주 작업 소유 영역 기준으로 고르는 문구 반영 | OK |
| 5개 이상 label에 작업지시자 확인 필요 문구 반영 | OK |
| 기존 label만 사용하고 새 label을 만들지 않는 제한 유지 | OK |
| 오늘할일 완료 처리 | OK |

## 잔여 위험과 후속 작업

- label 최소화 규칙은 Skill 절차 문서 기반이다. GitHub UI나 CLI가 자동으로 label 개수를 제한하지는 않으므로, 에이전트가 `task-register` 실행 시 해당 규칙을 따라야 한다.
- 실제 신규 이슈 등록 시 작업 성격이 넓으면 label 5개 이상이 필요할 수 있다. 이 경우 예외 사유와 작업지시자 확인으로 처리한다.
- 향후 label 체계가 바뀌면 `task-register`는 live 조회 기준으로 판단하지만, type/area/kind 분류 문구가 현재 label 체계와 어긋나는지는 별도 점검이 필요하다.

## 커밋 목록

```text
7204912 Task #64: 수행 계획서 작성과 오늘할일 갱신
c5d7798 Task #64: 구현 계획서 작성
fa92ad5 Task #64 Stage 1: task-register label 선택 규칙 보강 위치 확정
e05ffc5 Task #64 Stage 2: task-register label 최소화 규칙 반영
c995ce1 Task #64 Stage 3: task-register label 규칙 검증
```

## 승인 요청 사항

본 최종 결과 보고서 기준으로 `publish/task64` 원격 게시와 `devel` 대상 draft PR 생성을 승인 요청한다.
