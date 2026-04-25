# Issue #49 구현 계획서

수행계획서: `mydocs/plans/task_m010_49.md`

## 단계 구성 (4단계)

각 단계는 작업지시자 승인 후 진행한다. 각 단계 종료 시 `mydocs/working/task_m010_49_stage{N}.md` 단계별 완료 보고서를 작성하고 해당 단계 산출물과 함께 커밋한다. 커밋 메시지는 `Task #49 Stage {N}: {요약}` 형식.

본 작업은 운영 매뉴얼 문서 보강에 한정된다. Rust/Swift/Xcode 소스 또는 빌드 산출물을 변경하지 않으므로 Xcode/Rust 빌드 검증은 수행하지 않는다. 대신 문서 섹션 존재, 줄 수, 상호 참조, 새 강제 규칙 미도입 여부를 검증한다.

---

## Stage 1 — 문서 구조 매뉴얼 보강

### 목적

`mydocs/manual/document_structure_guide.md`가 단독 문서로 읽혀도 폴더 선택 기준과 내부 타스크/외부 PR 경계를 이해할 수 있도록 보강한다.

### 작업 항목

1. 기존 도입부를 범위/제외 범위/읽는 시점이 드러나도록 확장한다.
2. 핵심 용어 섹션을 추가한다.
   - 문서 진실 원천
   - 내부 타스크
   - 외부 기여 PR
   - 마일스톤 포함 문서명
   - Agent Skills 진실 원천
3. FAQ 또는 흔한 실수 섹션을 추가한다.
   - 폴더를 잘못 선택했을 때 처리
   - 마일스톤이 아직 확정되지 않았을 때 처리
   - 외부 PR과 내부 타스크 경계가 모호할 때 처리
4. 관련 매뉴얼 상호 참조 섹션을 추가한다.
5. Stage 1 단계 보고서를 작성한다.

### 수정·생성 파일

- `mydocs/plans/task_m010_49_impl.md`
- `mydocs/manual/document_structure_guide.md`
- `mydocs/working/task_m010_49_stage1.md`

### 검증

```bash
rg -n "핵심 용어|FAQ|관련 매뉴얼" mydocs/manual/document_structure_guide.md
wc -l mydocs/manual/document_structure_guide.md
git diff --check
```

### 종료 기준

- `document_structure_guide.md`에 도입부, 핵심 용어, FAQ, 관련 매뉴얼 섹션이 존재
- 문서 줄 수 200줄 이하
- Stage 1 단계 보고서 작성 완료

### 커밋

```
Task #49 Stage 1: 문서 구조 매뉴얼 자체 완결성 보강
```

---

## Stage 2 — Git 워크플로우 매뉴얼 보강

### 목적

`mydocs/manual/git_workflow_guide.md`가 단독 문서로 읽혀도 브랜치 정책, PR 게시 경로, PR 본문 문서 링크 작성 기준, 충돌·사고 회복 기준을 이해할 수 있도록 보강한다.

### 작업 항목

1. 기존 도입부를 범위/제외 범위/읽는 시점 중심으로 확장한다.
2. 핵심 용어 섹션을 추가한다.
   - `devel`
   - `local/taskN`
   - `publish/taskN`
   - draft PR
   - 분리 worktree
3. FAQ 또는 흔한 실수 섹션을 추가한다.
   - 다른 에이전트와 메인 worktree 충돌 시 처리
   - `devel` rebase가 필요해 보일 때 처리
   - 잘못된 브랜치를 push했을 때 회복
   - PR 본문 문서 링크를 merge 후에도 조회 가능한 형태로 작성하는 기준
4. 관련 매뉴얼 상호 참조 섹션을 추가한다.
5. Stage 2 단계 보고서를 작성한다.

### 수정·생성 파일

- `mydocs/manual/git_workflow_guide.md`
- `mydocs/working/task_m010_49_stage2.md`

### 검증

```bash
rg -n "핵심 용어|FAQ|관련 매뉴얼" mydocs/manual/git_workflow_guide.md
wc -l mydocs/manual/git_workflow_guide.md
git diff --check
```

### 종료 기준

- `git_workflow_guide.md`에 도입부, 핵심 용어, FAQ, 관련 매뉴얼 섹션이 존재
- 문서 줄 수 200줄 이하
- Stage 2 단계 보고서 작성 완료

### 커밋

```
Task #49 Stage 2: Git 워크플로우 매뉴얼 자체 완결성 보강
```

---

## Stage 3 — 타스크 진행 매뉴얼 보강과 SKILL 호출 표시 안내

### 목적

`mydocs/manual/task_workflow_guide.md`가 단독 문서로 읽혀도 단계 진행, 실패 회복, 보고서 위치, SKILL 호출 표시 방식을 이해할 수 있도록 보강한다.

### 작업 항목

1. 기존 도입부를 범위/제외 범위/읽는 시점 중심으로 확장한다.
2. 핵심 용어 섹션을 추가한다.
   - 수행계획서
   - 구현계획서
   - 단계별 완료보고서
   - 최종 결과보고서
   - 승인 간주 조건
3. FAQ 또는 흔한 실수 섹션을 추가한다.
   - 단계 실패 후 회복
   - 단계 분할 결정 기준
   - `working/`과 `report/` 위치 혼동 회복
4. SKILL 호출 표시 안내를 추가한다.
   - 승인된 하이퍼-워터폴 SKILL 절차를 적용하기 전에 `{skill-name} 스킬을 호출합니다.` 또는 `{skill-name} 스킬로 진행합니다.` 형식으로 알린다.
   - 이 안내가 묵시 호출 허용이 아니라 절차 적용 사실 표시임을 명시한다.
5. 관련 매뉴얼 상호 참조 섹션을 추가한다.
6. Stage 3 단계 보고서를 작성한다.

### 수정·생성 파일

- `mydocs/manual/task_workflow_guide.md`
- `mydocs/working/task_m010_49_stage3.md`

### 검증

```bash
rg -n "핵심 용어|FAQ|SKILL 호출 표시|관련 매뉴얼|task-stage-report 스킬을 호출합니다|task-final-report 스킬로 진행합니다|pr-merge-cleanup 스킬을 호출합니다" mydocs/manual/task_workflow_guide.md
wc -l mydocs/manual/task_workflow_guide.md
git diff --check
```

### 종료 기준

- `task_workflow_guide.md`에 도입부, 핵심 용어, FAQ, SKILL 호출 표시 안내, 관련 매뉴얼 섹션이 존재
- 문서 줄 수 200줄 이하
- Stage 3 단계 보고서 작성 완료

### 커밋

```
Task #49 Stage 3: 타스크 진행 매뉴얼과 SKILL 호출 표시 안내 보강
```

---

## Stage 4 — 통합 검증과 최종 보고

### 목적

3개 매뉴얼 보강 결과가 Issue #49 수용 기준을 만족하는지 확인하고 최종 보고서를 작성한다.

### 작업 항목

1. 3개 매뉴얼 섹션 존재 확인:
   - 도입부
   - 핵심 용어
   - FAQ 또는 흔한 실수
   - 관련 매뉴얼
2. 3개 매뉴얼 줄 수가 각각 200줄 이하인지 확인한다.
3. 지엽적 FAQ와 중복 설명을 걷어냈는지 확인한다.
4. 새 강제 규칙 도입 여부를 diff로 점검한다.
5. 최종 보고서 `mydocs/report/task_m010_49_report.md`를 작성한다.
6. `mydocs/orders/20260425.md`에서 #49 상태를 `완료`로 변경하고 완료 시각을 기록한다.
7. Stage 4 단계 보고서를 작성한다.

### 수정·생성 파일

- `mydocs/report/task_m010_49_report.md`
- `mydocs/orders/20260425.md`
- `mydocs/working/task_m010_49_stage4.md`

### 검증

```bash
rg -n "핵심 용어|FAQ|관련 매뉴얼" mydocs/manual/document_structure_guide.md mydocs/manual/git_workflow_guide.md mydocs/manual/task_workflow_guide.md
wc -l mydocs/manual/document_structure_guide.md mydocs/manual/git_workflow_guide.md mydocs/manual/task_workflow_guide.md
git diff --check
git status --short
```

### 종료 기준

- 3개 매뉴얼 모두 수용 기준 충족
- 최종 보고서 작성 완료
- 오늘할일 완료 처리
- working tree clean
- PR 게시 승인 요청 가능

### 커밋

```
Task #49 Stage 4 + 최종 보고서: 매뉴얼 보강 통합 보고
```

---

## 단계별 커밋 메시지 (예상)

| Stage | 커밋 메시지 |
|-------|-------------|
| 1 | `Task #49 Stage 1: 문서 구조 매뉴얼 자체 완결성 보강` |
| 2 | `Task #49 Stage 2: Git 워크플로우 매뉴얼 자체 완결성 보강` |
| 3 | `Task #49 Stage 3: 타스크 진행 매뉴얼과 SKILL 호출 표시 안내 보강` |
| 4 | `Task #49 Stage 4 + 최종 보고서: 매뉴얼 보강 통합 보고` |

## 후속 작업

- PR `publish/task49` push와 draft PR 생성은 Stage 4 완료 후 작업지시자 승인 시 `task-final-report` 절차로 진행한다.
- PR merge 후 정리는 `pr-merge-cleanup` 절차로 수행한다.

## 승인 요청 사항

이 구현 계획서 4단계 구성으로 Stage 1 진입을 승인 요청한다.
