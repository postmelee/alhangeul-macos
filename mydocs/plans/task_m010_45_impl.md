# Issue #45 구현 계획서

수행계획서: `mydocs/plans/task_m010_45.md`

## 단계 구성 (5단계)

각 단계는 작업지시자 승인 후 진행한다. 각 단계 종료 시 `mydocs/working/task_m010_45_stage{N}.md` 단계별 완료 보고서를 작성하고 해당 단계 소스 변경과 함께 커밋한다. 커밋 메시지는 `Task #45 Stage {N}: {요약}` 형식.

본 작업은 문서·운영 인프라 변경에 한정된다. 빌드 산출물 변경이 없으므로 `build_run_guide.md`의 "변경 유형별 최소 검증" 정책상 Xcode/Rust 빌드 검증은 수행하지 않는다. 대신 각 단계에서 매뉴얼 링크 무결성·라인 수·심볼릭 링크 가용성·skill 본문 일관성을 검증한다.

---

## Stage 1 — 신규 매뉴얼 3종 작성

### 목적

AGENTS.md에서 분리할 분량이 큰 3개 블록을 신규 매뉴얼로 그대로 옮긴다. 본 단계에서는 **이전과 정렬만 수행**하고 본문 내용은 변경하지 않는다.

### 작업 항목

1. `mydocs/manual/document_structure_guide.md` 생성
   - 출처: AGENTS.md L42~98
   - 구성:
     - 문서 폴더 구조 목록
     - 폴더 역할 표 (현행 11행 그대로)
     - 문서 파일명 규칙 (`task_{milestone}_{이슈번호}` 패턴 + 강제 규칙 4개)
     - 외부 기여자 PR 처리 폴더 정책 (현행 L100~119 일부, "절차"는 기존 `pr_process_guide.md` 링크로 대체)
2. `mydocs/manual/git_workflow_guide.md` 생성
   - 출처: AGENTS.md L162~226
   - 구성:
     - 브랜치 표 (4행)
     - Git 워크플로우 다이어그램
     - 운영 원칙 7항목 (타스크 브랜치, 원격 게시, 원격 push, devel 대상 PR, merge 전략, main merge)
     - 메인테이너 워크플로우 bash 예시
     - 컨트리뷰터 워크플로우 bash 예시
3. `mydocs/manual/task_workflow_guide.md` 생성
   - 출처: AGENTS.md L228~263
   - 구성:
     - 타스크 번호 관리 (이슈, 마일스톤 표기, 브랜치/커밋 명명, 커밋 메시지 규칙)
     - 타스크 진행 절차 15단계
     - 작업 규칙 (시간 결정자)
     - 승인 간주 조건 (AGENTS.md L34~36)

### 수정·생성 파일

- `mydocs/manual/document_structure_guide.md` (신규)
- `mydocs/manual/git_workflow_guide.md` (신규)
- `mydocs/manual/task_workflow_guide.md` (신규)
- `mydocs/working/task_m010_45_stage1.md` (단계 보고서)

### 검증

```bash
# 작성 누락 점검
test -f mydocs/manual/document_structure_guide.md
test -f mydocs/manual/git_workflow_guide.md
test -f mydocs/manual/task_workflow_guide.md

# 출처 대비 본문 누락 점검 (수동 grep으로 핵심 키워드 확인)
rg -n "강제 규칙" mydocs/manual/document_structure_guide.md
rg -n "메인테이너 워크플로우" mydocs/manual/git_workflow_guide.md
rg -n "타스크 진행 절차" mydocs/manual/task_workflow_guide.md
rg -n "승인 간주 조건" mydocs/manual/task_workflow_guide.md

# 라인 수 (참고용)
wc -l mydocs/manual/document_structure_guide.md mydocs/manual/git_workflow_guide.md mydocs/manual/task_workflow_guide.md

git diff --check
```

### 종료 기준

- 신규 매뉴얼 3개 파일 존재
- AGENTS.md의 해당 블록 내용이 매뉴얼에 누락 없이 존재 (수동 비교)
- 단계 보고서 작성 완료

---

## Stage 2 — AGENTS.md 압축 + CLAUDE.md 임포트 전환

### 목적

AGENTS.md를 항상 필요한 정책·제약·인덱스만 남긴 ≤ 100줄 형식으로 재작성하고, CLAUDE.md를 `@AGENTS.md` 임포트 기반 ≤ 30줄로 축소한다.

### 작업 항목

1. AGENTS.md 재작성 (덮어쓰기)
   - 구성 (예상 구조):
     1. 프로젝트 개요 (5~7줄)
     2. 하이퍼-워터폴 핵심 규칙 요약 + 승인 간주 조건 (~15줄)
     3. 명명 규칙 통합 블록: 브랜치, 커밋, 문서 파일명, 마일스톤 표기 (~15줄)
     4. 필수 참조 문서 인덱스 (~15줄, 신규 매뉴얼 3종 포함)
     5. 핵심 강제 규칙 한 줄 요약 (Sources/RhwpCoreBridge AppKit 금지, 빌드 산출물 build.noindex/, project.yml 원본 등 — 각 1줄 + 매뉴얼 링크)
     6. 작업 시간 규칙 (1줄)
   - 제거 대상: 폴더 역할 표 전체, 외부 PR 처리 절차, 빌드 강제 규칙 7개 상세, Git 워크플로우 다이어그램과 bash 예시, 타스크 진행 15단계
2. CLAUDE.md 재작성
   - 1차 시도: `@AGENTS.md` import 문법으로 본문 상속
   - 검증 방법: Claude Code 공식 문서 import 표기 확인 + 실제 파일에 `@AGENTS.md` 1줄 포함 후 라인 수 체크
   - 미지원으로 판명되면: 짧은 안내문 + AGENTS.md 링크 + Claude Code 전용 차이점만 적은 형태로 폴백 (≤ 30줄)
3. 매뉴얼 인덱스 갱신
   - AGENTS.md "필수 참조 문서" 섹션에 신규 3종 매뉴얼 추가
   - 기존 9개 + 신규 3개 = 12개 인덱스

### 수정·생성 파일

- `AGENTS.md` (대폭 축소·재작성)
- `CLAUDE.md` (대폭 축소·재작성)
- `mydocs/working/task_m010_45_stage2.md`

### 검증

```bash
# 라인 수 종료 기준
wc -l AGENTS.md CLAUDE.md
# AGENTS.md ≤ 100, CLAUDE.md ≤ 30 확인

# 매뉴얼 링크 무결성 (모든 (path) 참조가 실제 파일을 가리키는지)
rg -n "mydocs/" AGENTS.md CLAUDE.md | while IFS=: read -r f l rest; do
  echo "$f:$l: $rest"
done

# 핵심 키워드 손실 점검
rg -n "하이퍼-워터폴|승인 간주|local/task|publish/task|task_\\{milestone\\}" AGENTS.md

# Claude Code import 동작 확인 (사람 검증)
# - CLAUDE.md에 @AGENTS.md 표기 시 본문 상속이 되는지 다음 세션 시작 시 점검 (다음 단계 진입 전)

git diff --check
```

### 종료 기준

- AGENTS.md ≤ 100줄, CLAUDE.md ≤ 30줄
- 모든 매뉴얼 인덱스 링크 유효
- 핵심 강제 규칙·명명 규칙·승인 절차 키워드가 AGENTS.md에 남아 있음
- 단계 보고서 작성

---

## Stage 3 — Skill 5종 SKILL.md 작성

### 목적

하이퍼-워터폴 절차의 5개 시점을 Codex/Claude Code 양쪽 호환 SKILL.md로 분리한다. 진실 원천은 `mydocs/skills/{name}/SKILL.md`.

### 작업 항목

1. 디렉터리 구성: `mydocs/skills/`
2. 5개 skill 작성:
   - `task-start/SKILL.md` — 이슈 확인 → `local/task{N}` 브랜치 생성 → orders 갱신 → `task_m{X}_{N}.md` 템플릿
   - `task-stage-report/SKILL.md` — `_stage{N}.md` 작성 + Stage N 커밋
   - `task-final-report/SKILL.md` — `_report.md` + orders 갱신 + git status 확인 + publish/task push + draft PR 생성
   - `pr-merge-cleanup/SKILL.md` — 이슈 close + publish 원격 삭제 + local 브랜치/worktree 정리 + devel 복귀
   - `external-pr-review/SKILL.md` — `pr_{N}_review.md` → 검증 → `pr_{N}_report.md` → archives 이동
3. 표준 frontmatter:
   ```
   ---
   name: <skill-name>
   description: |
     <좁고 구체적인 트리거 설명. 명시 호출 전용임을 명시.>
   allow_implicit_invocation: false
   ---
   ```
4. 표준 본문 구성: 트리거 → 사전 조건 → 절차 (`gh`/`git`/파일 생성 한정) → 검증 → 도구별 호출 방법 안내 (Codex `$skill-name` / Claude Code `/skill-name`)
5. 본문은 도구 비종속으로 작성. 도구별 차이는 마지막 "호출 방법" 섹션에만 표기.

### 수정·생성 파일

- `mydocs/skills/task-start/SKILL.md`
- `mydocs/skills/task-stage-report/SKILL.md`
- `mydocs/skills/task-final-report/SKILL.md`
- `mydocs/skills/pr-merge-cleanup/SKILL.md`
- `mydocs/skills/external-pr-review/SKILL.md`
- `mydocs/working/task_m010_45_stage3.md`

### 검증

```bash
# 5개 skill 존재
for s in task-start task-stage-report task-final-report pr-merge-cleanup external-pr-review; do
  test -f mydocs/skills/$s/SKILL.md && echo "ok $s" || echo "missing $s"
done

# frontmatter 형식
for f in mydocs/skills/*/SKILL.md; do
  echo "=== $f ==="
  head -10 "$f"
done

# allow_implicit_invocation: false 일괄 적용 확인
rg -n "allow_implicit_invocation:" mydocs/skills/*/SKILL.md

# 도구명 하드코딩 점검 (호출 방법 섹션 외에 도구명이 본문에 노출되지 않아야 함)
rg -n "claude code|claude-code|codex" mydocs/skills/*/SKILL.md

git diff --check
```

### 종료 기준

- 5개 SKILL.md 작성 완료
- 모두 `allow_implicit_invocation: false`
- 본문 도구 비종속, 호출 방법만 도구별 분기
- 단계 보고서 작성

---

## Stage 4 — 심볼릭 링크 + 양 도구 인식 점검

### 목적

`.agents/skills`와 `.claude/skills`를 `mydocs/skills`로 향하는 심볼릭 링크로 만들고, 양 도구가 진실 원천을 동일하게 인식하는지 점검한다.

### 작업 항목

1. 심볼릭 링크 생성:
   ```bash
   mkdir -p .agents .claude
   ln -s ../mydocs/skills .agents/skills
   ln -s ../mydocs/skills .claude/skills
   ```
2. 두 링크를 git에 커밋 (git은 심볼릭 링크를 정상 추적)
3. 인식 점검:
   - 파일 시스템 단위: `test -f .agents/skills/task-start/SKILL.md`, `test -f .claude/skills/task-start/SKILL.md`
   - Codex 인식: `codex` CLI 가용 시 `codex --skills list` 또는 동등 명령 (가용성 미확인 시 수동 확인 항목으로 보고서에 기록)
   - Claude Code 인식: 새 세션 시작 시 시스템 프롬프트의 skill 목록에 5종 노출 여부 (사람 확인)
4. README 또는 매뉴얼 인덱스에 skill 진실 원천·심볼릭 링크 정책을 1~3줄로 명시 (어느 매뉴얼에 둘지: `document_structure_guide.md` 후보)

### 수정·생성 파일

- `.agents/skills` (심볼릭 링크, 신규)
- `.claude/skills` (심볼릭 링크, 신규)
- `mydocs/manual/document_structure_guide.md` (skill 위치 정책 1~3줄 추가)
- `mydocs/working/task_m010_45_stage4.md`

### 검증

```bash
# 심볼릭 링크 존재와 대상
ls -la .agents/skills .claude/skills
readlink .agents/skills
readlink .claude/skills
# 두 링크 모두 ../mydocs/skills 또는 동등 경로를 가리켜야 함

# 링크 통한 파일 접근
for s in task-start task-stage-report task-final-report pr-merge-cleanup external-pr-review; do
  test -f .agents/skills/$s/SKILL.md && echo "agents ok $s" || echo "agents miss $s"
  test -f .claude/skills/$s/SKILL.md && echo "claude ok $s" || echo "claude miss $s"
done

# git이 심볼릭 링크로 추적하는지 확인
git ls-files -s .agents/skills .claude/skills

git diff --check
```

### 종료 기준

- 심볼릭 링크 2개 생성 + git 추적 (mode `120000`)
- 양 경로 모두에서 5개 skill 접근 가능
- 위치 정책 매뉴얼 갱신
- 단계 보고서 작성

---

## Stage 5 — 최종 검증과 보고서

### 목적

전체 변경의 무결성을 점검하고 최종 결과 보고서를 작성한다. PR 생성 직전 상태로 정리.

### 작업 항목

1. 통합 검증 (수용 기준 5개)
   - AGENTS.md ≤ 100줄
   - CLAUDE.md ≤ 30줄
   - 매뉴얼 3종 신규 + 기존 9종 인덱스 유효
   - skill 5종 양 경로에서 접근 가능
   - 핵심 강제 규칙·명명 규칙·승인 절차 키워드 무손실
2. 최종 보고서 작성: `mydocs/report/task_m010_45_report.md`
   - 변경 요약, 파일 목록, 라인 수 비교 표
   - 검증 결과
   - 잔여 위험과 후속 작업 (추후 도구 인식 실측, AGENTS.md import 문법 호환성 등)
3. 오늘할일 갱신: #45 행 상태 `완료`로 변경, 비고에 `완료: HH:mm` 기록
4. PR 생성 사전 점검: `git status`, `git log --oneline devel..local/task45`
5. PR 생성은 작업지시자 승인 후 별도 진행 (`publish/task45` push + draft PR)

### 수정·생성 파일

- `mydocs/report/task_m010_45_report.md`
- `mydocs/orders/20260425.md` (#45 완료 처리)
- `mydocs/working/task_m010_45_stage5.md`

### 검증

```bash
# 라인 수 수용 기준
wc -l AGENTS.md CLAUDE.md

# 매뉴얼 인덱스 무결성
rg -n "mydocs/manual/" AGENTS.md | awk -F'[()]' '{print $2}' | while read -r p; do
  test -f "$p" && echo "ok $p" || echo "miss $p"
done

# Skill 양 경로 접근
ls .agents/skills .claude/skills

# 최종 보고서 존재
test -f mydocs/report/task_m010_45_report.md && echo "report ok"

# 미커밋 파일 없음
git status --short

# 커밋 히스토리
git log --oneline devel..local/task45
```

### 종료 기준

- 모든 수용 기준 충족
- 최종 보고서 작성
- 오늘할일 #45 완료 처리
- working tree clean
- 단계 보고서 작성

---

## 단계별 커밋 메시지 (예상)

| Stage | 커밋 메시지 |
|-------|-------------|
| 1 | `Task #45 Stage 1: 신규 매뉴얼 3종 분리 작성` |
| 2 | `Task #45 Stage 2: AGENTS.md/CLAUDE.md 압축과 매뉴얼 인덱스 갱신` |
| 3 | `Task #45 Stage 3: 하이퍼-워터폴 절차 SKILL.md 5종 작성` |
| 4 | `Task #45 Stage 4: skills 심볼릭 링크와 양 도구 인식 정책` |
| 5 | `Task #45 Stage 5 + 최종 보고서: 통합 검증과 보고` |

## 후속 작업

- PR `publish/task45` push와 draft PR 생성은 본 5단계 완료 후 작업지시자 승인 시 진행
- merge 후 정리: 이슈 close, publish/task45 원격 삭제, worktree `/Users/melee/Documents/projects/rhwp-mac-task45` 제거, devel 복귀

## 승인 요청 사항

이 구현 계획서 5단계 구성으로 Stage 1 진입을 승인 요청한다.
