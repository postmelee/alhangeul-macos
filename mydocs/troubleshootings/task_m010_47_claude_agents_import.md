# Claude Code `@AGENTS.md` 임포트 실측 기록

본 문서는 Issue #47 Stage 1의 1회 실측 기록이다. Task #45에서 `CLAUDE.md`를 `@AGENTS.md` 임포트 표기 + 안내 1줄로 단순화한 변경이 Claude Code 새 세션에서 실제로 적용되는지 확인한다.

## 측정 환경

- 측정 시각: 2026-04-25 22:42 KST
- 측정 위치: `/Users/melee/Documents/projects/rhwp-mac` (저장소 루트)
- 도구: Claude Code
- 모델: Claude Opus 4.7 (`claude-opus-4-7`)
- 대상 커밋: `e1e61ed` (devel 시점, Task #45 PR #46 merge 후)
- 측정 작업 브랜치: `local/task47`
- 측정 시점의 파일 라인 수: `CLAUDE.md` 5줄, `AGENTS.md` 74줄

## 측정 절차

본 세션은 위 저장소 루트에서 시작되었으며, Claude Code는 세션 시작 시 `CLAUDE.md`와 (해석된 임포트 대상인) `AGENTS.md`를 시스템 프롬프트의 `claudeMd` 컨텍스트에 적재한다.

세션 컨텍스트에 다음 두 헤더가 모두 출력되었는지, 그리고 `AGENTS.md` 본문의 핵심 섹션 식별자가 적재되었는지를 직접 확인했다.

확인한 헤더:

1. `Contents of /Users/melee/Documents/projects/rhwp-mac/CLAUDE.md (project instructions, checked into the codebase):`
2. `Contents of /Users/melee/Documents/projects/rhwp-mac/AGENTS.md (project instructions, checked into the codebase):`

확인한 `AGENTS.md` 핵심 섹션 식별자:

- `# AGENTS.md`
- `## 하이퍼-워터폴 핵심 규칙`
- `## 핵심 강제 규칙 (변경 전 매뉴얼 확인 필수)`
- `## 필수 참조 문서`

## 관측 결과

- `CLAUDE.md` 적재: 정상. `@AGENTS.md` 표기와 안내 1줄이 모두 컨텍스트에 출력됨.
- `AGENTS.md` 적재: 정상. 위 4개 섹션 식별자가 본문 내에 모두 출력됨. `## 프로젝트 개요`, `## 명명 규칙`, `## Agent Skills`, `## 작업 규칙` 등 부속 섹션도 동일 블록 내에서 관찰됨.
- 두 파일이 별도의 `Contents of ...` 헤더 블록으로 각각 출력되는 형태로 적재되었다. Claude Code가 `@AGENTS.md` 임포트 표기를 해석해 별도 청크로 첨부하는 방식으로 추정된다.

## 판정 결과

**임포트 정상 적용.** Claude Code는 본 저장소 루트에서 시작된 세션에서 `CLAUDE.md`의 `@AGENTS.md` 표기를 해석해 `AGENTS.md` 본문을 시스템 프롬프트에 적재한다. 본 세션에서는 제목·하이퍼-워터폴 핵심 규칙·핵심 강제 규칙·필수 참조 문서 등 운영 규칙 핵심 섹션이 누락 없이 노출됨이 확인되었다.

## 후속 조치 결정

- Stage 2 분기: **분기 A — `CLAUDE.md` 변경 없음**으로 진행한다.
- 본 결과는 본 시점·본 모델의 1회 관측이다. 향후 Claude Code 또는 모델 버전 업데이트 시 임포트 처리 방식이 달라질 수 있으므로 다음을 후속 항목으로 남긴다.
  - 후속 모니터링: 신규 메이저 버전 적용 시 동일 절차로 재측정.
  - 동기화 책임: 현재 단일 진실 원천은 `AGENTS.md`이며 `CLAUDE.md`는 임포트 표기만 둔다. 향후 폴백이 필요해질 경우 본 문서를 근거로 계획서를 다시 갱신한다.

## 참조

- 관련 PR: #46 (Task #45)
- 관련 보고서: `mydocs/report/task_m010_45_report.md` "잔여 위험 1번"
- 본 타스크 수행계획서: `mydocs/plans/task_m010_47.md`
- 본 타스크 구현계획서: `mydocs/plans/task_m010_47_impl.md`
