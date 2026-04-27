# Issue #47 구현 계획서

수행계획서: `mydocs/plans/task_m010_47.md`

## 단계 구성 (3단계)

각 단계는 작업지시자 승인 후 진행한다. 각 단계 종료 시 `mydocs/report/task_m010_47_stage{N}.md` 단계별 완료 보고서를 작성하고 해당 단계 소스 변경과 함께 커밋한다. 커밋 메시지는 `Task #47 Stage {N}: {요약}` 형식.

본 작업은 운영 문서·인프라 문서 변경에 한정된다. 코드/빌드 산출물 변경이 없으므로 `build_run_guide.md`의 "변경 유형별 최소 검증" 정책상 Xcode/Rust 빌드 검증은 수행하지 않는다. 대신 각 단계에서 매뉴얼 링크 무결성·라인 수·실측 본문 일관성을 검증한다.

---

## Stage 1 — Claude Code 임포트 실측 기록

### 목적

본 저장소 루트에서 시작된 현 Claude Code 세션의 시스템 프롬프트에 `AGENTS.md` 본문이 적재되었는지 직접 확인하고, 결과를 1회 기록 문서로 남긴다.

### 작업 항목

1. 현 세션 시스템 프롬프트에서 다음 단서를 직접 인용 가능한지 확인한다.
   - 헤더: `Contents of /Users/melee/Documents/projects/rhwp-mac/AGENTS.md (project instructions, checked into the codebase):`
   - 본문 핵심 섹션 식별자: `# AGENTS.md`, `## 하이퍼-워터폴 핵심 규칙`, `## 핵심 강제 규칙 (변경 전 매뉴얼 확인 필수)`, `## 필수 참조 문서`
2. 결과별 판정:
   - 위 헤더와 4개 섹션 식별자가 모두 적재되어 있으면 **임포트 정상 적용**으로 판정.
   - 일부만 적재되었거나 헤더 자체가 없으면 **미적용 또는 부분 적용**으로 판정.
3. `mydocs/troubleshootings/task_m010_47_claude_agents_import.md` 작성. 포함 항목:
   - 측정 시각 (한국 시간 기준)
   - 측정 환경: Claude Code (모델명·버전이 식별 가능한 범위에서 기록)
   - 측정 절차 (시스템 프롬프트 컨텍스트의 어떤 부분을 어떻게 인용 확인했는지)
   - 인용 단서: 헤더 한 줄과 핵심 섹션 식별자 4종
   - 판정 결과 (적용/미적용/부분 적용 중 하나)
   - 후속 조치 결정 (Stage 2에서 무엇을 할지)
4. 본 단계는 `CLAUDE.md`나 `AGENTS.md` 본문을 변경하지 않는다.

### 수정·생성 파일

- `mydocs/troubleshootings/task_m010_47_claude_agents_import.md` (신규)
- `mydocs/report/task_m010_47_stage1.md` (단계 보고서)

### 검증

```bash
test -f mydocs/troubleshootings/task_m010_47_claude_agents_import.md
rg -n "측정 시각|판정 결과|후속 조치" mydocs/troubleshootings/task_m010_47_claude_agents_import.md
git diff --check
```

### 종료 기준

- 실측 기록 문서 작성 완료
- 판정 결과(적용/미적용/부분 적용)가 명시됨
- Stage 2 분기 결정이 문서에 명시됨
- 단계 보고서 작성 완료

### 커밋

```
Task #47 Stage 1: Claude Code @AGENTS.md 임포트 실측 기록
```

---

## Stage 2 — 결과 분기 처리

### 목적

Stage 1 판정 결과에 따라 `CLAUDE.md`를 유지하거나 폴백 본문으로 재작성한다.

### 작업 항목 (분기)

#### 분기 A — 임포트 정상 적용으로 판정된 경우

1. `CLAUDE.md`를 변경하지 않는다.
2. 단계 보고서에 "변경 없음 — 임포트 정상" 명시.
3. 후속 모니터링 항목으로 "Claude Code 버전 업 시 재측정"을 보고서에 남긴다.

#### 분기 B — 미적용 또는 부분 적용으로 판정된 경우

1. `CLAUDE.md`를 폴백 본문으로 재작성. 구성 (예상 80~120줄):
   - 머리말: `AGENTS.md`가 단일 진실 원천이며 본 문서는 Claude Code 적재용 요약본임을 명시. 두 문서 동기화 책임 안내.
   - 프로젝트 개요 (3~5줄)
   - 하이퍼-워터폴 핵심 규칙 요약 + 승인 간주 조건
   - 명명 규칙 (브랜치, 커밋, 문서 파일명, 마일스톤 표기)
   - 핵심 강제 규칙 (각 1줄 + 매뉴얼 링크)
   - 필수 참조 문서 인덱스 (`AGENTS.md`와 동일 12개 항목 유지)
   - Agent Skills 위치·인식 정책 1~3줄
   - 작업 시간 규칙 1줄
2. `AGENTS.md`는 변경하지 않는다.
3. `mydocs/manual/document_structure_guide.md`에 "AGENTS.md/CLAUDE.md 동기화 책임" 1~3줄 추가 검토. 추가 시 본 단계에 포함.

### 수정·생성 파일

- 분기 A: 변경 없음 (보고서만)
- 분기 B:
  - `CLAUDE.md` (재작성)
  - `mydocs/manual/document_structure_guide.md` (필요 시 1~3줄 추가)
- 공통: `mydocs/report/task_m010_47_stage2.md`

### 검증

분기 A:
```bash
git diff CLAUDE.md
# 출력 없음을 확인
```

분기 B:
```bash
wc -l CLAUDE.md
# 120줄 이하 확인
rg -n "mydocs/manual/" CLAUDE.md | awk -F'[()]' '{print $2}' | while read -r p; do
  test -f "$p" && echo "ok $p" || echo "miss $p"
done
rg -n "하이퍼-워터폴|승인 간주|local/task|publish/task" CLAUDE.md
git diff --check
```

### 종료 기준

- 분기 A: `CLAUDE.md` 변경 없음 보고서에 명시
- 분기 B: `CLAUDE.md` ≤ 120줄, 모든 매뉴얼 링크 유효, 핵심 키워드 포함
- 단계 보고서 작성

### 커밋

분기 A:
```
Task #47 Stage 2: 임포트 정상 적용 확인, CLAUDE.md 변경 없음
```

분기 B:
```
Task #47 Stage 2: CLAUDE.md 폴백 본문 작성과 동기화 정책 안내
```

---

## Stage 3 — 통합 검증과 최종 보고서

### 목적

전체 변경의 무결성을 점검하고 최종 결과 보고서를 작성한다. PR 생성 직전 상태로 정리.

### 작업 항목

1. 통합 검증 (수용 기준):
   - 분기 A: `git diff devel..local/task47 -- CLAUDE.md` 출력이 비어 있어야 함.
   - 분기 B: `CLAUDE.md` ≤ 120줄, 매뉴얼 링크 무결성, 핵심 강제 규칙 키워드 무손실.
   - 공통: `mydocs/troubleshootings/task_m010_47_claude_agents_import.md` 1건 존재.
2. 최종 보고서 작성: `mydocs/report/task_m010_47_report.md`
   - 측정 절차와 결과 요약
   - 분기 결정 근거
   - 변경 파일 목록 (분기 A는 보고/실측 문서뿐, 분기 B는 CLAUDE.md 포함)
   - 검증 결과
   - 잔여 위험과 후속 작업 (Claude Code 버전 업 후 재측정, 동기화 책임 등)
3. 오늘할일 갱신: #47 행 상태 `완료`로 변경, 비고에 `완료: HH:mm` 기록
4. PR 생성 사전 점검: `git status`, `git log --oneline devel..local/task47`
5. PR 생성은 작업지시자 승인 후 별도 진행 (`task-final-report` 스킬로 진행: `publish/task47` push + draft PR)

### 수정·생성 파일

- `mydocs/report/task_m010_47_report.md`
- `mydocs/orders/20260425.md` (#47 완료 처리)
- `mydocs/report/task_m010_47_stage3.md`

### 검증

```bash
test -f mydocs/report/task_m010_47_report.md
test -f mydocs/troubleshootings/task_m010_47_claude_agents_import.md
git status --short
git log --oneline devel..local/task47
```

### 종료 기준

- 모든 수용 기준 충족
- 최종 보고서 작성
- 오늘할일 #47 완료 처리
- working tree clean
- 단계 보고서 작성

### 커밋

```
Task #47 Stage 3 + 최종 보고서: 통합 검증과 보고
```

---

## 단계별 커밋 메시지 (예상)

| Stage | 커밋 메시지 |
|-------|-------------|
| 1 | `Task #47 Stage 1: Claude Code @AGENTS.md 임포트 실측 기록` |
| 2A | `Task #47 Stage 2: 임포트 정상 적용 확인, CLAUDE.md 변경 없음` |
| 2B | `Task #47 Stage 2: CLAUDE.md 폴백 본문 작성과 동기화 정책 안내` |
| 3 | `Task #47 Stage 3 + 최종 보고서: 통합 검증과 보고` |

## 후속 작업

- PR `publish/task47` push와 draft PR 생성은 Stage 3 완료 후 작업지시자 승인 시 `task-final-report` 스킬로 진행
- merge 후 정리: 이슈 close, publish/task47 원격 삭제, devel 복귀 (`pr-merge-cleanup` 스킬)

## 승인 요청 사항

이 구현 계획서 3단계 구성으로 Stage 1 진입을 승인 요청한다.
