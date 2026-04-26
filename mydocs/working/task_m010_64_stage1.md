# Issue #64 Stage 1 완료 보고서

## 단계 목적

현재 `task-register` Skill의 label 선택 절차를 확인하고, label 최소화 규칙을 어느 위치에 어떤 기준으로 반영할지 확정한다. 이번 단계에서는 Skill 본문을 수정하지 않고 조사와 설계만 수행한다.

## 조사 대상

- `mydocs/skills/task-register/SKILL.md`
- `mydocs/plans/task_m010_64.md`
- GitHub label 목록

## 현재 Skill 구조 확인

`task-register`의 label 관련 흐름은 다음 세 지점으로 나뉘어 있다.

| 위치 | 현재 역할 | 보강 필요 |
|------|-----------|-----------|
| 3. 기존 label 목록 확인 | `gh api repos/.../labels`로 live label을 조회하고 `name`/`description` 기준으로 판단 | 기존 원칙 유지 |
| 5. label 후보 선택 | 기존 label 중 명확히 대응하는 label을 선택하고, 모호하면 label 없이 생성하거나 확인 | label 최소화 규칙의 주 위치 |
| 6. 이슈 초안 작성 | 선택한 label과 선택 이유를 초안에 포함 | 5개 이상 예외 사유 기재 기준 추가 |
| 검증 | 승인된 기존 label만 붙었는지 확인 | label 개수와 선택 이유 검증 기준 추가 |
| 절대 하지 말 것 | 새 milestone 또는 새 label 생성 금지 | 기존 원칙 유지 |

현재 5단계는 "명확히 대응할 때만 선택"이라고만 되어 있어 관련 영역 label을 과하게 붙이는 상황을 막지 못한다. 따라서 Stage 2의 본문 변경은 5단계를 중심으로 하되, 6단계와 검증 섹션에 짧은 보강을 함께 넣는 것이 적절하다.

## 현재 GitHub label 체계

Stage 1에서 조회한 label은 총 25개다.

### type 후보

| label | 설명 | 사용 기준 |
|-------|------|-----------|
| `bug` | Something isn't working | 동작 오류, 회귀, 실패 원인 수정 |
| `documentation` | Improvements or additions to documentation | 문서, manual, Skill, task 문서 변경 |
| `duplicate` | This issue or pull request already exists | 실질적으로 같은 이슈가 이미 있는 경우 |
| `enhancement` | New feature or request | 새 기능, 기능 개선, 운영 절차 개선 |
| `question` | Further information is requested | 정보 요청 또는 범위 확인이 주목적인 항목 |

기본 label 중 `good first issue`, `help wanted`, `invalid`, `wontfix`는 일반 신규 내부 타스크 등록의 기본 type으로 쓰기보다 예외 상태 또는 contributor-facing label로 유지하는 편이 맞다.

### area 후보

| label | 설명 |
|-------|------|
| `area:bridge-ffi` | RustBridge, C ABI, Swift bridge boundary work |
| `area:ci-cd` | Build, package, sign, notarize, DMG, Homebrew, release automation |
| `area:core` | rhwp core provenance, dependency, release tag related work |
| `area:docs` | README, manuals, architecture docs, generated task documents |
| `area:localization` | Localized display names and Korean/English presentation |
| `area:quick-look` | Quick Look preview extension integration |
| `area:rendering` | Render tree, image data, visual quality, renderer behavior |
| `area:test-assets` | Sample documents, fixtures, smoke/render verification assets |
| `area:thumbnail` | Finder thumbnail extension integration |
| `area:viewer-app` | HostApp viewer, app UX, document opening behavior |
| `area:workflow` | AGENTS, SKILL, task workflow, PR process, issue operations |

`area:*`는 관련 가능성이 있는 모든 영역이 아니라 주 작업 소유 영역을 고르는 기준으로 제한해야 한다. 교차 영역 작업도 보통 2개까지만 붙이고, 세 번째 area가 필요하면 초안에서 이유를 설명하는 방식이 낫다.

### kind/status 후보

| label | 설명 |
|-------|------|
| `kind:architecture` | Architecture, ownership boundary, dependency design |
| `kind:automation` | Scripts, release automation, verification automation |
| `kind:follow-up` | Follow-up from a prior task, PR, or residual risk |
| `kind:regression` | Regression or quality degradation found after prior work |
| `kind:verification` | Manual verification, smoke test, or measurement-focused work |

`kind:*`는 작업 처리 방식이나 맥락이 실제 triage에 도움이 될 때만 붙인다. 단순히 관련 단어가 본문에 있다는 이유로 추가하지 않는다.

## Stage 2 수정 위치 확정

### 1. `5. label 후보 선택`

여기에 핵심 규칙을 추가한다.

- label은 기본적으로 `type 1개 + area 1~2개 + kind/status 0~1개`로 제한한다.
- type label은 `bug`, `documentation`, `enhancement`, `duplicate`, `question` 등 작업 성격을 나타내는 label 중 1개를 우선 고른다.
- `area:*`는 영향을 받는 모든 영역이 아니라 주 작업 소유 영역 기준으로 고른다.
- `kind:*`는 `architecture`, `automation`, `regression`, `verification`, `follow-up`처럼 처리 방식이나 맥락을 실제로 구분할 때만 붙인다.
- 일반 이슈는 2~4개 label을 권장한다.
- 5개 이상 label이 필요하면 이슈 초안에 예외 사유를 적고 작업지시자 확인을 받는다.

기존 문장인 "조회된 기존 label만 후보로 사용한다", "새 label은 만들지 않는다"는 그대로 유지한다.

### 2. `6. 이슈 초안 작성`

현재는 "label: live 조회 결과에서 고른 기존 label 0개 이상과 선택 이유"라고 되어 있다. 여기에 다음 취지를 추가한다.

- label은 type/area/kind 기준으로 나누어 선택 이유를 적는다.
- 5개 이상이면 예외 사유를 별도로 적는다.

### 3. `검증`

현재 검증은 "승인된 기존 label만 붙어 있어야 한다"에 머문다. 다음 기준을 추가한다.

- 일반 이슈 label이 2~4개 권장 범위인지 확인한다.
- 5개 이상 label이면 승인된 예외 사유가 생성 결과 보고에 포함되어야 한다.
- `area:*`가 주 작업 소유 영역 기준으로 선택되었는지 확인한다.

## 기존 원칙과의 충돌 검토

| 기존 원칙 | 유지 여부 | 비고 |
|-----------|-----------|------|
| GitHub label 목록을 live 조회한다 | 유지 | 기억 기반 label 판단 금지 원칙과 충돌 없음 |
| 조회된 기존 label만 후보로 쓴다 | 유지 | 새 label 생성은 계속 금지 |
| label이 애매하면 label 없이 생성하거나 확인한다 | 유지 | 개수 제한과 상호 보완 관계 |
| 이슈 생성 전 제목/본문/milestone/label 초안을 승인받는다 | 유지 | 5개 이상 예외 사유 확인 지점으로 활용 |
| 이슈 생성 후 `task-start` 승인 대기 | 유지 | 이번 변경은 이슈 등록 이후 흐름에 영향 없음 |

## Stage 2 반영 방침

Stage 2에서는 `mydocs/skills/task-register/SKILL.md`만 수정한다. 매뉴얼 변경은 이번 작업 범위에 포함하지 않는다.

문구는 다음 기준으로 작성한다.

- 짧은 bullet 중심으로 작성해 이슈 등록 절차의 가독성을 유지한다.
- `type`, `area`, `kind/status`의 의미를 설명하되, label 목록 전체를 Skill에 다시 복제하지 않는다.
- "관련 있어 보이면 모두 붙인다"가 아니라 "검색과 triage에 실제로 필요한 label만 붙인다"는 기준을 명확히 둔다.
- 5개 이상 label은 금지가 아니라 예외 승인 대상으로 둔다.

## 실행한 명령

```bash
rg -n "기존 label 목록 확인|label 후보 선택|이슈 초안 작성|## 검증|새 label" mydocs/skills/task-register/SKILL.md
sed -n '1,170p' mydocs/skills/task-register/SKILL.md
gh api repos/postmelee/alhangeul-macos/labels --paginate --jq '.[] | {name,description,color}'
git status --short --branch
```

## 검증 결과

구현계획서의 Stage 1 검증 명령을 실행했다.

```bash
rg -n "기존 label 목록 확인|label 후보 선택|이슈 초안 작성|검증|새 label" \
  mydocs/skills/task-register/SKILL.md
git diff --check -- mydocs/working/task_m010_64_stage1.md
```

결과:

- `task-register`의 label 관련 위치 확인 완료
- 현재 GitHub label 25개 조회 완료
- Stage 2 수정 위치와 문구 방향 확정
- Stage 1 보고서 공백 검증 통과

## 완료 조건 확인

| 완료 조건 | 결과 |
|-----------|------|
| Skill 본문에서 수정할 섹션이 Stage 1 보고서에 명시되어 있음 | 충족 |
| `type`, `area`, `kind/status` 기준을 어느 항목에 추가할지 확정되어 있음 | 충족 |
| 5개 이상 label 예외 처리 규칙의 위치가 확정되어 있음 | 충족 |

## 승인 요청 사항

본 Stage 1 결과 기준으로 Stage 2: `task-register` Skill label 최소화 규칙 반영을 진행할지 승인 요청한다.
