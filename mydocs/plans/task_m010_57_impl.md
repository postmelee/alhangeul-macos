# Issue #57 구현 계획서

수행계획서: `mydocs/plans/task_m010_57.md`

## 작업명

이슈 미등록 작업을 위한 task-register Skill 추가

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_57.md`를 기준으로 진행한다.
- `task-register`는 이슈가 없는 작업을 GitHub Issue로 등록하는 선행 Skill이며, `task-start`의 책임을 침범하지 않는다.
- 원격 GitHub 상태를 바꾸는 `gh issue create` 실행 전에는 제목, 본문, milestone, label 초안을 작업지시자에게 확인한다.
- milestone과 label은 저장소의 현재 목록을 조회해 기존 값만 사용한다. 새 milestone 또는 label 생성은 이번 작업 범위에서 제외한다.
- 모든 문서와 Skill 본문은 한국어로 작성한다.
- 문서 전용 변경이므로 Rust/Swift/Xcode 빌드 검증은 수행하지 않는다.

## Stage 1: 기존 절차 경계 조사와 task-register 세부 설계

대상:

- `mydocs/skills/task-start/SKILL.md`
- `mydocs/manual/task_workflow_guide.md`
- `mydocs/manual/document_structure_guide.md`
- `mydocs/manual/git_workflow_guide.md`
- GitHub milestone/label 목록

작업:

1. `task-start`의 사전 조건과 절차를 확인해 `task-register`와의 책임 경계를 확정한다.
2. `task_workflow_guide.md`의 타스크 번호 관리와 SKILL 호출 표시 위치를 확인한다.
3. 열린 milestone과 label 목록을 조회해 Skill 본문에 넣을 선택 기준을 정리한다.
4. 이슈 생성 전 승인 지점과 생성 후 멈춤 지점을 설계한다.
5. Stage 1 단계 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_57_stage1.md`

검증:

```bash
rg -n "task-start|GitHub Issue|새 타스크 등록|마일스톤|label|SKILL 호출" \
  mydocs/skills/task-start/SKILL.md \
  mydocs/manual/task_workflow_guide.md \
  mydocs/manual/document_structure_guide.md \
  mydocs/manual/git_workflow_guide.md
git diff --check -- mydocs/working/task_m010_57_stage1.md
```

완료 조건:

- `task-register`와 `task-start`의 책임 경계가 Stage 1 보고서에 정리되어 있다.
- milestone/label 선택 기준과 모호할 때의 확인 규칙이 정리되어 있다.
- Stage 2에서 작성할 Skill 구조가 확정되어 있다.

커밋:

```text
Task #57 Stage 1: task-register 절차 경계와 설계 정리
```

## Stage 2: task-register Skill 작성

대상:

- `mydocs/skills/task-register/SKILL.md`

작업:

1. 신규 Skill 디렉터리와 `SKILL.md`를 작성한다.
2. frontmatter는 기존 Skill과 같은 형식을 따른다.
   - `name: task-register`
   - 번호 없는 작업의 이슈 등록에만 좁게 맞춘 `description`
   - `allow_implicit_invocation: false`
3. 트리거를 명시 호출로 제한한다.
4. 사전 조건을 정리한다.
   - 이슈 번호가 아직 없음
   - 작업지시자가 이슈 등록을 명시 승인함
   - `gh` CLI 인증 완료
   - GitHub milestone/label 조회 가능
5. 절차를 작성한다.
   - 기존 중복 이슈 검색
   - 열린 milestone 목록 조회
   - label 목록 조회
   - 제목/본문/milestone/label 초안 제시
   - 승인 후 `gh issue create`
   - 생성된 이슈 번호, URL, milestone, label 기록
   - 다음 단계는 `task-start` 승인 대기
6. milestone 선택 기준을 작성한다.
   - 운영/문서/기초 구조: `v0.1.0`
   - Finder Quick Look/Thumbnail 안정화: `v0.3.0`
   - viewer UX/성능: `v0.4.0`
   - 읽기 전용 베타 안정화: `v0.5.0`
   - 편집 관련 선행 설계/구현/저장: `v0.6.0`~`v1.0.0`
7. label 선택 기준을 작성한다.
   - 문서/운영 문서: `documentation`
   - 기능/개선: `enhancement`
   - 결함 수정: `bug`
   - 모호하면 label 없이 생성하거나 작업지시자 확인
8. Stage 2 단계 보고서를 작성한다.

산출물:

- `mydocs/skills/task-register/SKILL.md`
- `mydocs/working/task_m010_57_stage2.md`

검증:

```bash
test -f mydocs/skills/task-register/SKILL.md
test -f .agents/skills/task-register/SKILL.md
test -f .claude/skills/task-register/SKILL.md
rg -n "name: task-register|allow_implicit_invocation: false|gh issue create|milestone|label|task-start|승인" \
  mydocs/skills/task-register/SKILL.md
git diff --check -- mydocs/skills/task-register/SKILL.md mydocs/working/task_m010_57_stage2.md
```

완료 조건:

- Codex/Claude Code 심볼릭 링크 경로에서 신규 Skill이 보인다.
- Skill이 이슈 생성 전 승인 지점과 생성 후 `task-start` 대기 지점을 명시한다.
- 기존 milestone/label만 사용하는 원칙이 명시된다.

커밋:

```text
Task #57 Stage 2: task-register Skill 작성
```

## Stage 3: 타스크 진행 매뉴얼 보강

대상:

- `mydocs/manual/task_workflow_guide.md`
- 필요 시 `mydocs/manual/document_structure_guide.md`

작업:

1. 타스크 번호 관리 섹션에서 이슈가 없는 작업은 `task-register`로 선행 등록한다는 안내를 추가한다.
2. 기존 `gh issue create` 한 줄 예시를 현재 Skill 절차와 충돌하지 않도록 정리한다.
3. SKILL 호출 표시 안내에 `task-register` 예시를 추가한다.
4. `task-start`가 이미 존재하는 이슈를 시작하는 Skill이라는 경계를 매뉴얼에 짧게 남긴다.
5. 문서 구조 매뉴얼의 마일스톤 FAQ에 보강이 필요한지 확인하고, 필요할 때만 최소 수정한다.
6. Stage 3 단계 보고서를 작성한다.

산출물:

- `mydocs/manual/task_workflow_guide.md`
- 필요 시 `mydocs/manual/document_structure_guide.md`
- `mydocs/working/task_m010_57_stage3.md`

검증:

```bash
rg -n "task-register|이슈가 없는|새 타스크 등록|task-start|SKILL 호출 표시" \
  mydocs/manual/task_workflow_guide.md \
  mydocs/manual/document_structure_guide.md
git diff --check -- \
  mydocs/manual/task_workflow_guide.md \
  mydocs/manual/document_structure_guide.md \
  mydocs/working/task_m010_57_stage3.md
```

완료 조건:

- 매뉴얼에서 이슈 등록 선행 절차와 `task-start` 시작 절차가 구분된다.
- SKILL 호출 표시 안내에 `task-register`가 포함된다.
- 불필요한 새 강제 규칙이나 중복 설명이 추가되지 않는다.

커밋:

```text
Task #57 Stage 3: 이슈 등록 선행 절차 매뉴얼 보강
```

## Stage 4: 통합 검증과 최종 보고

대상:

- 전체 변경 파일
- `mydocs/orders/20260426.md`
- `mydocs/report/task_m010_57_report.md`

작업:

1. 신규 Skill 경로와 심볼릭 링크 노출을 확인한다.
2. Skill과 매뉴얼의 책임 경계 문구를 검색으로 확인한다.
3. `allow_implicit_invocation: false`와 명시 호출 정책을 확인한다.
4. 오늘할일 상태를 완료로 갱신하고 완료 시각을 기록한다.
5. 최종 결과 보고서를 작성한다.
6. Stage 4 단계 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_57_stage4.md`
- `mydocs/report/task_m010_57_report.md`
- `mydocs/orders/20260426.md`

검증:

```bash
git diff --check
test -f mydocs/skills/task-register/SKILL.md
test -f .agents/skills/task-register/SKILL.md
test -f .claude/skills/task-register/SKILL.md
rg -n "task-register|task-start|gh issue create|milestone|label|allow_implicit_invocation: false" \
  mydocs/skills/task-register/SKILL.md \
  mydocs/manual/task_workflow_guide.md \
  mydocs/manual/document_structure_guide.md
git status --short
```

완료 조건:

- 신규 Skill과 매뉴얼 보강이 모두 검증된다.
- 최종 보고서와 오늘할일 완료 처리가 끝난다.
- working tree가 clean이고 PR 게시 승인 요청이 가능하다.

커밋:

```text
Task #57 Stage 4 + 최종 보고서: task-register Skill 통합 보고
```

## 단계별 커밋 메시지

| Stage | 커밋 메시지 |
|-------|-------------|
| 1 | `Task #57 Stage 1: task-register 절차 경계와 설계 정리` |
| 2 | `Task #57 Stage 2: task-register Skill 작성` |
| 3 | `Task #57 Stage 3: 이슈 등록 선행 절차 매뉴얼 보강` |
| 4 | `Task #57 Stage 4 + 최종 보고서: task-register Skill 통합 보고` |

## 후속 작업

- Stage 4 완료 후 작업지시자 승인 시 `task-final-report` 절차로 `publish/task57` push와 draft PR 생성을 진행한다.
- PR merge 후 정리는 `pr-merge-cleanup` 절차로 수행한다.

## 승인 요청 사항

이 구현 계획서 4단계 구성으로 Stage 1 진입을 승인 요청한다.
