# Issue #48 구현 계획서

수행계획서: `mydocs/plans/task_m010_48.md`

## 단계 구성 (4단계)

각 단계는 작업지시자 승인 후 진행한다. 각 단계 종료 시 `mydocs/working/task_m010_48_stage{N}.md` 단계별 완료 보고서를 작성하고 해당 단계 산출물과 함께 커밋한다. 커밋 메시지는 `Task #48 Stage {N}: {요약}` 형식.

본 작업은 운영 문서와 Agent Skill 문구 검증에 한정된다. Rust/Swift/Xcode 소스 또는 빌드 산출물을 변경하지 않으므로 Xcode/Rust 빌드 검증은 수행하지 않는다. 대신 SKILL 파일 접근성, 측정 기록 완결성, 문서 변경 무결성을 검증한다.

---

## Stage 1 — Codex 측 노출·묵시 호출 회피 측정

### 목적

현재 Codex 세션에서 Task #45가 추가한 5종 SKILL이 사용 가능 목록에 노출되는지 확인하고, 의도하지 않은 묵시 호출이 관찰되지 않았는지 기록한다.

### 작업 항목

1. 현재 세션의 Available skills 목록에서 다음 5종을 확인한다.
   - `task-start`
   - `task-stage-report`
   - `task-final-report`
   - `pr-merge-cleanup`
   - `external-pr-review`
2. 각 SKILL 원본 `mydocs/skills/{name}/SKILL.md`에 `allow_implicit_invocation: false`와 "명시 호출" 조건이 존재하는지 확인한다.
3. `.agents/skills`와 `.claude/skills`가 동일한 `mydocs/skills` 원천을 가리키는지 확인한다.
4. `mydocs/troubleshootings/task_m010_48_skill_exposure.md`에 Codex 측 측정 결과를 작성한다.
5. Stage 1 단계 보고서 `mydocs/working/task_m010_48_stage1.md`를 작성한다.

### 수정·생성 파일

- `mydocs/plans/task_m010_48_impl.md`
- `mydocs/troubleshootings/task_m010_48_skill_exposure.md`
- `mydocs/working/task_m010_48_stage1.md`

### 검증

```bash
for name in task-start task-stage-report task-final-report pr-merge-cleanup external-pr-review; do
  test -f "mydocs/skills/$name/SKILL.md"
  rg -n "allow_implicit_invocation: false|명시 호출" "mydocs/skills/$name/SKILL.md"
done
test "$(readlink .agents/skills)" = "../mydocs/skills"
test "$(readlink .claude/skills)" = "../mydocs/skills"
rg -n "Codex|task-start|task-stage-report|task-final-report|pr-merge-cleanup|external-pr-review|묵시" mydocs/troubleshootings/task_m010_48_skill_exposure.md
git diff --check
```

### 종료 기준

- Codex 측 5종 노출 여부가 측정 기록에 명시됨
- `allow_implicit_invocation: false`와 명시 호출 조건 확인 결과가 기록됨
- 묵시 호출 회피 관찰 결과가 기록됨
- Stage 1 단계 보고서 작성 완료

### 커밋

```
Task #48 Stage 1: Codex SKILL 노출과 묵시 호출 회피 측정
```

---

## Stage 2 — Claude Code 측 측정 인계와 결과 수집

### 목적

Claude Code 새 세션에서 5종 SKILL이 user-invocable skills 목록에 노출되는지 확인하고, 일반 대화에서 description이 의도하지 않은 묵시 호출을 일으키지 않는지 관찰한다.

### 작업 항목

1. Claude Code 측 측정자가 같은 브랜치 `local/task48`에서 세션을 시작한다.
2. `mydocs/troubleshootings/task_m010_48_skill_exposure.md`의 Claude Code 섹션에 다음을 추가한다.
   - 측정 시각
   - 노출된 5종 이름
   - 명시 호출 경로(`/task-start` 등)
   - 일반 대화 중 묵시 호출 관찰 여부
   - 오동작이 있을 경우 재현 문장과 실제 호출된 SKILL
3. 측정 결과를 바탕으로 Stage 3 분기 입력을 정리한다.
4. Stage 2 단계 보고서를 작성한다.

### 수정·생성 파일

- `mydocs/troubleshootings/task_m010_48_skill_exposure.md`
- `mydocs/working/task_m010_48_stage2.md`

### 검증

```bash
rg -n "Claude Code|측정 시각|판정|task-start|external-pr-review" mydocs/troubleshootings/task_m010_48_skill_exposure.md
git diff --check
```

### 종료 기준

- Claude Code 측 측정 결과가 동일 문서에 누적됨
- 오동작 유무가 명확히 판정됨
- Stage 3에서 description 튜닝이 필요한지 결정 가능

### 커밋

```
Task #48 Stage 2: Claude Code SKILL 노출 측정 결과 기록
```

---

## Stage 3 — Description 튜닝 여부 결정

### 목적

Codex와 Claude Code 측 측정 결과를 합쳐 SKILL description 또는 트리거 문구 수정 필요성을 판단한다.

### 작업 항목

#### 분기 A — 오동작 없음

1. 5종 SKILL 본문을 변경하지 않는다.
2. 단계 보고서에 변경 없음과 유지 근거를 기록한다.
3. 장기 관찰 항목으로 "1주일 사용 동안 묵시 호출 0건" 확인 방법을 남긴다.

#### 분기 B — 오동작 있음

1. 오동작이 관찰된 SKILL의 `description`과 `## 트리거` 문구만 최소 수정한다.
2. 수정 원칙:
   - 일반 명사형 설명을 줄이고 "작업지시자가 명시 호출한 경우" 문구를 앞쪽에 둔다.
   - 자동 수행처럼 읽히는 표현을 피한다.
   - 기존 절차 본문과 커밋/검증 규칙은 변경하지 않는다.
3. 수정 전후 차이를 단계 보고서에 기록한다.

### 수정·생성 파일

- 분기 A: `mydocs/working/task_m010_48_stage3.md`
- 분기 B:
  - 필요한 `mydocs/skills/*/SKILL.md`
  - `mydocs/working/task_m010_48_stage3.md`

### 검증

분기 A:
```bash
git diff -- mydocs/skills
git diff --check
```

분기 B:
```bash
rg -n "allow_implicit_invocation: false|명시 호출" mydocs/skills/*/SKILL.md
git diff -- mydocs/skills
git diff --check
```

### 종료 기준

- description 튜닝 필요 여부가 문서로 확정됨
- 필요한 경우 변경 범위가 SKILL 문구에 한정됨
- Stage 3 단계 보고서 작성 완료

### 커밋

분기 A:
```
Task #48 Stage 3: SKILL description 변경 없음 결정
```

분기 B:
```
Task #48 Stage 3: SKILL description 명시 호출 조건 보강
```

---

## Stage 4 — 통합 검증과 최종 보고

### 목적

전체 측정 결과와 변경 여부를 최종 보고서로 정리하고 PR 게시 준비 상태를 만든다.

### 작업 항목

1. `mydocs/report/task_m010_48_report.md` 작성:
   - Codex 측 측정 결과
   - Claude Code 측 측정 결과
   - description 튜닝 여부와 근거
   - 수용 기준 충족 상태
   - 1주일 장기 관찰 잔여 항목
2. `mydocs/orders/20260425.md`에서 #48 상태를 `완료`로 변경하고 완료 시각을 기록한다.
3. 최종 검증 명령 실행:
   - 측정 기록 존재 확인
   - 5종 SKILL 접근성 확인
   - `git diff --check`
   - `git status --short`
4. Stage 4 단계 보고서를 작성한다.
5. PR 생성은 작업지시자 승인 후 `task-final-report` 절차로 진행한다.

### 수정·생성 파일

- `mydocs/report/task_m010_48_report.md`
- `mydocs/orders/20260425.md`
- `mydocs/working/task_m010_48_stage4.md`

### 검증

```bash
test -f mydocs/troubleshootings/task_m010_48_skill_exposure.md
test -f mydocs/report/task_m010_48_report.md
for name in task-start task-stage-report task-final-report pr-merge-cleanup external-pr-review; do
  test -f "mydocs/skills/$name/SKILL.md"
done
git diff --check
git status --short
```

### 종료 기준

- 최종 보고서 작성 완료
- 오늘할일 완료 처리
- working tree clean
- PR 게시 승인 요청 가능

### 커밋

```
Task #48 Stage 4 + 최종 보고서: SKILL 실측 통합 보고
```

---

## 단계별 커밋 메시지 (예상)

| Stage | 커밋 메시지 |
|-------|-------------|
| 1 | `Task #48 Stage 1: Codex SKILL 노출과 묵시 호출 회피 측정` |
| 2 | `Task #48 Stage 2: Claude Code SKILL 노출 측정 결과 기록` |
| 3A | `Task #48 Stage 3: SKILL description 변경 없음 결정` |
| 3B | `Task #48 Stage 3: SKILL description 명시 호출 조건 보강` |
| 4 | `Task #48 Stage 4 + 최종 보고서: SKILL 실측 통합 보고` |

## 후속 작업

- PR `publish/task48` push와 draft PR 생성은 Stage 4 완료 후 작업지시자 승인 시 `task-final-report` 절차로 진행한다.
- PR merge 후 정리는 `pr-merge-cleanup` 절차로 수행한다.

## 승인 요청 사항

이 구현 계획서 4단계 구성으로 Stage 1 진입을 승인 요청한다.
