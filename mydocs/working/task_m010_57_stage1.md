# Issue #57 Stage 1 완료 보고서

## 단계 목적

기존 `task-start` Skill과 운영 매뉴얼을 확인해 신규 `task-register` Skill의 책임 경계를 확정하고, GitHub milestone/label 선택 기준과 이슈 생성 전 승인 지점을 설계한다.

## 조사 대상

- `mydocs/skills/task-start/SKILL.md`
- `mydocs/manual/task_workflow_guide.md`
- `mydocs/manual/document_structure_guide.md`
- `mydocs/manual/git_workflow_guide.md`
- GitHub milestone 목록
- GitHub label 목록

## 확인 결과

### `task-start` 책임

`task-start`는 이미 생성된 이슈를 시작하는 절차다.

- 사전 조건: 작업지시자 승인된 이슈 번호와 마일스톤이 존재
- 첫 절차: `gh issue view {N}`로 이슈 정보 확인
- 주요 산출물: `local/task{N}` 브랜치, 오늘할일 행, 수행계획서
- 종료 지점: 수행계획서 승인 요청

따라서 `task-start`에 `gh issue create`를 추가하면 기존 사전 조건과 책임이 넓어진다. 신규 Skill은 `task-start` 앞에서 이슈 번호를 만드는 선행 절차로 분리하는 것이 맞다.

### `task-register` 책임

`task-register`는 이슈가 없는 작업을 GitHub Issue로 등록하고 멈추는 절차로 설계한다.

- 입력: 번호 없는 작업 요청, 작업 목적/배경/범위 초안
- 조회: 중복 이슈, 열린 milestone, 기존 label
- 판단: milestone 후보와 label 후보
- 승인 지점: `gh issue create` 실행 전 제목/본문/milestone/label 초안 확인
- 산출물: 생성된 issue number, URL, milestone, label
- 종료 지점: `task-start` 진입 승인 대기

브랜치 생성, 오늘할일 갱신, 수행계획서 작성은 `task-register`에 포함하지 않는다.

## milestone 목록과 선택 기준

현재 열린 milestone 목록:

| GitHub milestone | 문서 prefix | 선택 기준 |
|------------------|-------------|-----------|
| `alhangeul-macos 기준 완전 이관` | 기존 이관 작업 문맥 | 독립 저장소 이관 자체와 직접 관련된 잔여 작업 |
| `v0.1.0` | `m010` | 기초 구조, 운영 문서, Skill, build/run 기반, core dependency 운영 |
| `v0.2.0` | `m020` | 렌더링 지원 범위 확대, 회귀 테스트 기반 |
| `v0.3.0` | `m030` | Quick Look preview, Finder thumbnail 안정화 |
| `v0.4.0` | `m040` | HostApp viewer 문서 열기, 페이지 탐색, zoom, 대용량 UX/성능 |
| `v0.5.0` | `m050` | 읽기 전용 beta 안정화, fallback, smoke test, 배포 전 검증 |
| `v0.6.0` | `m060` | 편집 기능 도입을 위한 command/bridge 책임 경계와 FFI 설계 |
| `v0.7.0` | `m070` | 텍스트 선택, 커서, 삽입, 삭제 최소 편집 루프 |
| `v0.8.0` | `m080` | 편집 후 재조판, 렌더링 갱신, undo/redo, dirty state |
| `v0.9.0` | `m090` | 저장 경로, autosave, 손상 방지, 복구 정책 |
| `v1.0.0` | `m100` | 읽기와 최소 편집, 저장 안정성을 갖춘 첫 정식 편집 기반 릴리스 |

선택 규칙:

- 작업 성격이 명확하면 위 표의 가장 가까운 milestone을 선택한다.
- 운영 문서나 Agent Skill 보강은 `v0.1.0`을 기본 후보로 둔다.
- 제품 기능 milestone이 둘 이상 걸치면 먼저 작업지시자에게 확인한다.
- GitHub milestone이 비어 있거나 닫힌 milestone만 적합해 보이면 생성하지 않고 확인한다.

## label 목록과 선택 기준

현재 label 목록:

| label | 사용 기준 |
|-------|-----------|
| `bug` | 동작 오류, 회귀, 실패 원인 수정 |
| `documentation` | README, manual, plan/report, Skill 등 문서성 변경 |
| `duplicate` | 기존 이슈와 중복으로 판단되는 경우 |
| `enhancement` | 새 기능, 기능 개선, 운영 절차 개선 |
| `good first issue` | 신규 기여자에게 적합한 독립 소형 작업 |
| `help wanted` | 외부 도움이나 별도 검토가 필요한 작업 |
| `invalid` | 작업으로 진행하지 않을 잘못된 요청 |
| `question` | 정보 요청 또는 범위 확인이 주목적인 항목 |
| `wontfix` | 진행하지 않기로 한 항목 |

선택 규칙:

- 문서/Skill 작업은 `documentation`을 우선 후보로 둔다.
- 운영 절차 개선이나 기능적 개선 성격이 있으면 `enhancement`를 함께 후보로 둔다.
- 결함 재현과 수정이 중심이면 `bug`를 후보로 둔다.
- label 판단이 모호하면 label 없이 생성하거나 작업지시자에게 확인한다.
- 새 label 생성은 `task-register` 범위에서 제외한다.

## Stage 2 Skill 구조

Stage 2에서 작성할 `mydocs/skills/task-register/SKILL.md` 구조:

1. frontmatter
   - `name: task-register`
   - 번호 없는 작업의 GitHub Issue 등록에 한정한 description
   - `allow_implicit_invocation: false`
2. 트리거
   - 작업지시자가 이슈 생성 또는 신규 타스크 등록을 명시한 경우
   - 작업지시자가 본 Skill을 직접 호출한 경우
3. 사전 조건
   - 이슈 번호가 아직 없음
   - `gh` 인증 완료
   - 이슈 생성 전 작업지시자 승인 필요
4. 절차
   - 기존 중복 이슈 검색
   - 열린 milestone 조회
   - label 조회
   - 이슈 제목/본문/milestone/label 초안 제시
   - 승인 후 `gh issue create`
   - 생성 결과 기록
   - `task-start` 승인 대기
5. 검증
   - 생성된 이슈 URL 확인
   - milestone/label 반영 확인
6. 절대 하지 말 것
   - 승인 없이 이슈 생성
   - 새 milestone/label 생성
   - 브랜치/오늘할일/수행계획서 작성
7. 호출 방법
   - Codex와 Claude Code 호출법

## 검증 결과

구현계획서의 Stage 1 검증 명령을 실행했다.

```bash
rg -n "task-start|GitHub Issue|새 타스크 등록|마일스톤|label|SKILL 호출" \
  mydocs/skills/task-start/SKILL.md \
  mydocs/manual/task_workflow_guide.md \
  mydocs/manual/document_structure_guide.md \
  mydocs/manual/git_workflow_guide.md
git diff --check -- mydocs/working/task_m010_57_stage1.md
```

결과:

- `task-start` 사전 조건과 절차 확인 완료
- 타스크 번호 관리의 `gh issue create` 한 줄 예시 확인 완료
- 마일스톤 미정 시 확인 규칙 확인 완료
- Stage 1 보고서 공백 검증 통과

추가 확인:

```bash
gh api repos/postmelee/alhangeul-macos/milestones --jq '.[] | {number,title,state,description,open_issues,closed_issues}'
gh api repos/postmelee/alhangeul-macos/labels --paginate --jq '.[] | {name,description,color}'
```

결과:

- 열린 milestone 11개 확인
- 기존 label 9개 확인

## 잔여 위험

- milestone 선택 기준은 현재 GitHub milestone 설명에 기반한다. milestone 설명이 바뀌면 `task-register` 본문도 갱신해야 한다.
- label 체계가 기본 GitHub label 중심이라 세밀한 분류는 어렵다. 새 label이 필요하면 별도 이슈로 분리하는 편이 안전하다.
- `task-register`가 이슈 생성 후 자동으로 `task-start`까지 진행하면 승인 게이트가 흐려질 수 있으므로 Stage 2 본문에서 멈춤 지점을 강하게 명시해야 한다.

## 다음 단계 영향

Stage 2에서는 이 설계를 기준으로 `mydocs/skills/task-register/SKILL.md`를 신규 작성한다. Stage 2에서는 매뉴얼을 아직 변경하지 않고 Skill 본문과 단계 보고서만 커밋한다.

## 승인 요청

Stage 2 `task-register` Skill 작성으로 진행할지 승인 요청한다.
