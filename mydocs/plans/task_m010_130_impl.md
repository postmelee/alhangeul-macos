# Issue #130 구현 계획서

수행계획서: `mydocs/plans/task_m010_130.md`

## 단계 구성 (3단계)

각 단계는 작업지시자 승인 후 진행한다. 각 단계 종료 시 `mydocs/working/task_m010_130_stage{N}.md` 단계별 완료 보고서를 작성하고 해당 단계 산출물과 함께 커밋한다. 커밋 메시지는 `Task #130 Stage {N}: {요약}` 형식.

본 작업은 Agent Skill 문서 추가에 한정된다. Rust/Swift/Xcode 소스 또는 빌드 산출물을 변경하지 않으므로 Xcode/Rust 빌드 검증은 수행하지 않는다. 대신 Skill frontmatter, 양 도구 심볼릭 링크 접근성, 삭제 보호 규칙, 문서 변경 무결성을 검증한다.

---

## Stage 1 — 정리 대상과 보호 규칙 확정

### 목적

현재 저장소의 빌드/검증/임시 산출물 생성 경로와 기존 운영 Skill의 책임 경계를 확인하고, `project-artifact-cleanup` Skill에 들어갈 삭제 가능/승인 필요/삭제 금지 기준을 확정한다.

### 작업 항목

1. 관련 문서를 확인한다.
   - `mydocs/manual/build_run_guide.md`
   - `mydocs/troubleshootings/finder_integration_validation_pitfalls.md`
   - `mydocs/skills/pr-merge-cleanup/SKILL.md`
2. 현재 후보 경로를 read-only 명령으로 조사한다.
   - `build.noindex/`
   - `output/`
   - `RustBridge/target/`
   - `Frameworks/`
   - `/private/tmp/rhwp*`
   - `/private/tmp/alhangeul*`
3. `git worktree list --porcelain`과 `.git` 존재 여부로 삭제 금지 경로 판정 기준을 정리한다.
4. Debug build cleanup 전 Release 설치본 갱신과 `lsregister`, `pluginkit`, `qlmanage -r`, `qlmanage -r cache`, `/tmp/alhangeul-ql` 생성, `qlmanage -t` 확인 기준을 정리한다.
5. Stage 1 단계 보고서 `mydocs/working/task_m010_130_stage1.md`를 작성한다.

### 수정·생성 파일

- `mydocs/plans/task_m010_130_impl.md`
- `mydocs/working/task_m010_130_stage1.md`

### 검증

```bash
rg -n "build.noindex|/private/tmp|pluginkit|qlmanage|Release package|Debug" \
  mydocs/manual/build_run_guide.md \
  mydocs/troubleshootings/finder_integration_validation_pitfalls.md
rg -n "PR merge|worktree|git branch|rm -rf|절대 하지 말 것" \
  mydocs/skills/pr-merge-cleanup/SKILL.md
git worktree list --porcelain
git diff --check
```

### 종료 기준

- cleanup Skill의 대상 경로와 보호 경로가 단계 보고서에 정리됨
- 기존 `pr-merge-cleanup`과 새 Skill의 책임 경계가 정리됨
- Debug build 삭제 전 Release 설치본 갱신 기준이 정리됨
- Stage 1 단계 보고서 작성 완료

### 커밋

```
Task #130 Stage 1: 부산물 정리 기준과 보호 규칙 확정
```

---

## Stage 2 — `project-artifact-cleanup` Skill 작성

### 목적

Stage 1에서 확정한 기준을 바탕으로 `project-artifact-cleanup` Skill을 신규 작성한다. 기본 동작은 dry-run 후보 보고로 제한하고, 실제 삭제는 작업지시자 명시 승인 후에만 허용한다.

### 작업 항목

1. `mydocs/skills/project-artifact-cleanup/SKILL.md`를 생성한다.
2. frontmatter를 기존 Skill과 같은 형식으로 작성한다.
   - `name: project-artifact-cleanup`
   - `allow_implicit_invocation: false`
   - 명시 호출 전용 description
3. 본문에 다음 절차를 포함한다.
   - 트리거와 사전 조건
   - dry-run 후보 수집 명령
   - `safe`, `approval-required`, `never-delete` 분류 기준
   - git worktree/repository 보호 규칙
   - Debug build cleanup 전 Release 설치본 갱신 판단
   - 실제 삭제 전 승인 요청 형식
   - 절대 하지 말 것
   - Codex/Claude Code 호출 방법
4. Stage 2 단계 보고서 `mydocs/working/task_m010_130_stage2.md`를 작성한다.

### 수정·생성 파일

- `mydocs/skills/project-artifact-cleanup/SKILL.md`
- `mydocs/working/task_m010_130_stage2.md`

### 검증

```bash
test -f mydocs/skills/project-artifact-cleanup/SKILL.md
rg -n "allow_implicit_invocation: false|명시 호출|dry-run|safe|approval-required|never-delete|git worktree|pluginkit|qlmanage" \
  mydocs/skills/project-artifact-cleanup/SKILL.md
git diff --check -- mydocs/skills/project-artifact-cleanup/SKILL.md mydocs/working/task_m010_130_stage2.md
```

### 종료 기준

- 신규 Skill 본문 작성 완료
- 기본 동작이 삭제가 아니라 dry-run 후보 보고임이 명시됨
- git worktree, `.git`, 설치본, 이전 이름 앱 보호 규칙이 명시됨
- Stage 2 단계 보고서 작성 완료

### 커밋

```
Task #130 Stage 2: 프로젝트 부산물 정리 Skill 작성
```

---

## Stage 3 — 접근성 검증과 최종 보고 준비

### 목적

신규 Skill이 `mydocs/skills` 진실 원천과 `.agents/skills`, `.claude/skills` 심볼릭 링크 경로에서 모두 접근 가능한지 확인하고, 문서 전용 변경으로서 최종 보고와 PR 게시 준비 상태를 만든다.

### 작업 항목

1. 양 도구 경로에서 신규 Skill 파일 접근성을 확인한다.
2. Skill 본문이 하이퍼-워터폴 승인 규칙과 충돌하지 않는지 점검한다.
3. 실제 cleanup은 실행하지 않고 dry-run 기준 명령만 문서 수준으로 검증한다.
4. `mydocs/report/task_m010_130_report.md` 최종 보고서를 작성한다.
5. `mydocs/orders/20260502.md`의 #130 상태를 `완료`로 변경하고 완료 시각을 기록한다.
6. Stage 3 단계 보고서 `mydocs/working/task_m010_130_stage3.md`를 작성한다.
7. PR 생성은 작업지시자 승인 후 `task-final-report` 절차로 진행한다.

### 수정·생성 파일

- `mydocs/report/task_m010_130_report.md`
- `mydocs/orders/20260502.md`
- `mydocs/working/task_m010_130_stage3.md`

### 검증

```bash
test -f mydocs/skills/project-artifact-cleanup/SKILL.md
test -f .agents/skills/project-artifact-cleanup/SKILL.md
test -f .claude/skills/project-artifact-cleanup/SKILL.md
rg -n "project-artifact-cleanup|dry-run|never-delete|approval-required" \
  mydocs/skills/project-artifact-cleanup/SKILL.md
git diff --check
git status --short
```

### 종료 기준

- 신규 Skill 파일이 세 경로에서 모두 접근 가능함
- 최종 보고서와 오늘할일 완료 처리 완료
- Stage 3 단계 보고서 작성 완료
- PR 게시 승인 요청 가능

### 커밋

```
Task #130 Stage 3 + 최종 보고서: 부산물 정리 Skill 검증과 보고
```

---

## 단계별 커밋 메시지 (예상)

| Stage | 커밋 메시지 |
|-------|-------------|
| 1 | `Task #130 Stage 1: 부산물 정리 기준과 보호 규칙 확정` |
| 2 | `Task #130 Stage 2: 프로젝트 부산물 정리 Skill 작성` |
| 3 | `Task #130 Stage 3 + 최종 보고서: 부산물 정리 Skill 검증과 보고` |

## 후속 작업

- PR `publish/task130` push와 draft PR 생성은 Stage 3 완료 후 작업지시자 승인 시 `task-final-report` 절차로 진행한다.
- PR merge 후 branch/worktree 정리는 기존 `pr-merge-cleanup` 절차로 수행한다.
- 실제 부산물 삭제는 본 타스크 범위가 아니라, 신규 Skill을 명시 호출한 별도 작업에서 dry-run 보고와 승인 후 수행한다.

## 승인 요청 사항

이 구현 계획서 3단계 구성으로 Stage 1 진입을 승인 요청한다.
