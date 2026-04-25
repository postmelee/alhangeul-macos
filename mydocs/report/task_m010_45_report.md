# Issue #45 최종 결과 보고서

## 작업 요약

- **이슈**: [#45 AGENTS.md/CLAUDE.md 최적화와 하이퍼-워터폴 절차 skill 분리](https://github.com/postmelee/alhangeul-macos/issues/45)
- **마일스톤**: v0.1.0 (M010)
- **브랜치**: `local/task45` (분리 worktree `/Users/melee/Documents/projects/rhwp-mac-task45`)
- **단계 수**: 5
- **참조 문서**:
  - 수행계획서: [`task_m010_45.md`](../plans/task_m010_45.md)
  - 구현계획서: [`task_m010_45_impl.md`](../plans/task_m010_45_impl.md)
  - 단계별 보고서: [`task_m010_45_stage1.md`](../working/task_m010_45_stage1.md), [`stage2`](../working/task_m010_45_stage2.md), [`stage3`](../working/task_m010_45_stage3.md), [`stage4`](../working/task_m010_45_stage4.md)

## 배경

매 턴 시스템 프롬프트로 적재되는 `AGENTS.md`(263줄)와 `CLAUDE.md`(257줄)는 95% 중복이었고, 다수의 강제 규칙이 이미 `mydocs/manual/` 매뉴얼에 존재함에도 두 파일에 다시 기재되어 있었다. 모범 사례(2026)는 AGENTS.md를 항상 필요한 정책·제약·인덱스 위주로 두고, 절차형 워크플로우는 Agent Skills로 분리할 것을 권고한다 (출처: SmartScope 2026 가이드, Vercel 평가, HumanLayer/Builder.io). 본 작업은 이 권고를 본 저장소의 하이퍼-워터폴 방법론에 맞게 적용한 것이다.

## 정량 비교

### AGENTS.md / CLAUDE.md 라인 수

| 파일 | 변경 전 | 변경 후 | 감소 | 수용 기준 |
|------|---------|---------|------|-----------|
| `AGENTS.md` | 263 | 74 | -189 (71.9%) | ≤ 100 ✓ |
| `CLAUDE.md` | 257 | 5 | -252 (98.1%) | ≤ 30 ✓ |
| **합계** | **520** | **79** | **-441 (84.8%)** | — |

매 턴 시스템 프롬프트 적재량 약 **441줄 절약**.

### 분리·작성된 매뉴얼·SKILL

| 분류 | 파일 | 라인 수 |
|------|------|---------|
| 신규 매뉴얼 | `mydocs/manual/document_structure_guide.md` | 76 |
| 신규 매뉴얼 | `mydocs/manual/git_workflow_guide.md` | 67 |
| 신규 매뉴얼 | `mydocs/manual/task_workflow_guide.md` | 44 |
| 신규 SKILL | `mydocs/skills/task-start/SKILL.md` | 76 |
| 신규 SKILL | `mydocs/skills/task-stage-report/SKILL.md` | 65 |
| 신규 SKILL | `mydocs/skills/task-final-report/SKILL.md` | 80 |
| 신규 SKILL | `mydocs/skills/pr-merge-cleanup/SKILL.md` | 76 |
| 신규 SKILL | `mydocs/skills/external-pr-review/SKILL.md` | 77 |
| 심볼릭 링크 | `.agents/skills` → `../mydocs/skills` (mode 120000) | — |
| 심볼릭 링크 | `.claude/skills` → `../mydocs/skills` (mode 120000) | — |

## 주요 변경

1. **CLAUDE.md를 `@AGENTS.md` 임포트 기반으로 단순화**: Claude Code 공식 import 표기로 본문 상속, Codex는 무관.
2. **AGENTS.md를 인덱스 + 핵심 강제 규칙 중심으로 재구성**:
   - 프로젝트 개요, 하이퍼-워터폴 핵심 규칙, 명명 규칙, 핵심 강제 규칙(7항목 1줄 요약), 매뉴얼 인덱스(11개), Agent Skills 정책, 작업 규칙
   - 폴더 역할 표·외부 PR 절차·빌드 강제 규칙·Git 워크플로우·타스크 진행 15단계는 매뉴얼로 이전
3. **신규 매뉴얼 3종**: `document_structure_guide.md`, `git_workflow_guide.md`, `task_workflow_guide.md` — 본문 변경 없이 이전·정렬.
4. **하이퍼-워터폴 절차 5종 SKILL 분리**: `task-start`, `task-stage-report`, `task-final-report`, `pr-merge-cleanup`, `external-pr-review`
   - 모두 `allow_implicit_invocation: false` (Codex 표준 키)
   - description을 좁게 작성해 Claude Code에서도 묵시적 호출 회피
   - 본문 도구 비종속 (`gh`/`git`/파일 생성), 도구별 차이는 "호출 방법" 섹션에만
5. **양 도구 호환 심볼릭 링크**: `.agents/skills`(Codex)와 `.claude/skills`(Claude Code)가 진실 원천 `mydocs/skills`를 가리키므로 한 곳에 작성하면 양 도구가 동일 본문 인식.

## 검증 결과 (수용 기준 별)

| # | 수용 기준 | 결과 |
|---|-----------|------|
| 1 | `AGENTS.md` ≤ 100줄 | ✓ 74줄 |
| 2 | `CLAUDE.md` ≤ 30줄 | ✓ 5줄 |
| 3 | 매뉴얼·skill 링크 무결성 (11개 매뉴얼 인덱스 모두 유효) | ✓ 11/11 ok |
| 4 | skill 5종이 양 도구에서 인식 (`.agents/skills`/`.claude/skills` 동일 노출) | ✓ 파일 시스템·git 단위 통과, CLI 단위는 사람 검증 항목 (아래 후속 작업) |
| 5 | 기존 매뉴얼·문서명·브랜치/커밋 규칙 손실 없음 (분리/이동만) | ✓ 핵심 키워드 8건 잔존, 신규 강제 규칙 0건, 폐지 0건 |

검증 명령 출력 발췌:

```
=== AGENTS.md 매뉴얼 인덱스 (11개) ===
ok README.md
ok mydocs/manual/agent_code_hyperfall_rule_conflict.md
ok mydocs/manual/build_run_guide.md
ok mydocs/manual/core_submodule_operation_guide.md
ok mydocs/manual/document_structure_guide.md
ok mydocs/manual/git_workflow_guide.md
ok mydocs/manual/pr_process_guide.md
ok mydocs/manual/release_distribution_guide.md
ok mydocs/manual/swift_macos_code_rules_guide.md
ok mydocs/manual/task_workflow_guide.md
ok mydocs/tech/project_architecture.md

=== Skill 양 경로 접근 ===
agents ok task-start ... external-pr-review (5종 × 2경로 모두 ok)

=== 라인 수 변동 ===
 AGENTS.md | 299 ++++++++++++--------------------------------------------------
 CLAUDE.md | 256 +----------------------------------------------------
 2 files changed, 57 insertions(+), 498 deletions(-)
```

## 단계별 커밋 히스토리

```
4e5619f Task #45 Stage 4: skills 심볼릭 링크와 양 도구 인식 정책
76486cd Task #45 Stage 3: 하이퍼-워터폴 절차 SKILL.md 5종 작성
d5ec04c Task #45 Stage 2: AGENTS.md/CLAUDE.md 압축과 매뉴얼 인덱스 갱신
3867933 Task #45 Stage 1: 신규 매뉴얼 3종 분리 작성
a89d59e Task #45: 구현 계획서 작성 (5단계)
756a3b4 Task #45: 수행 계획서 작성과 오늘할일 갱신
```

본 보고 커밋이 추가된다: `Task #45 Stage 5 + 최종 보고서: 통합 검증과 보고`.

## 잔여 위험과 후속 작업

1. **Claude Code `@AGENTS.md` 임포트 실측**: CLAUDE.md의 본문 상속이 다음 세션에서 실제로 적용되는지 사람 검증 필요. 미지원으로 판명되면 CLAUDE.md를 짧은 안내 + 핵심 규칙 요약 형태로 재작성 (별도 후속 이슈로 처리 권장).
2. **CLI 단위 SKILL 인식 실측**:
   - Codex: `codex` 또는 `/skills` 메뉴에서 5종 노출 여부
   - Claude Code: 새 세션 시스템 프롬프트의 user-invocable skills 목록에 5종 노출 여부
   - 두 도구 모두 description 매칭이 의도 외 묵시적 호출을 일으키지 않는지 관찰
3. **심볼릭 링크 환경 호환**: 현재 GitHub Actions·로컬 macOS 환경에서 정상 동작. Windows/zip 배포 도입 시 재검토.
4. **신규 매뉴얼 본문 보강**: 현재는 AGENTS.md에서 그대로 이전한 분량만 들어 있음. 향후 각 매뉴얼이 자체 완결성을 갖도록 도입부·예시·FAQ 보강이 필요할 수 있음 (별도 운영 작업).
5. **Stage 1 폴더 역할 표 `skills/` 행과 실제 디렉터리 일치**: Stage 4에서 `mydocs/skills/` 디렉터리와 두 심볼릭 링크가 실제로 존재하므로 일치 확인됨.

## PR 게시 준비 상태

- 커밋 히스토리 6개 (수행계획·구현계획·Stage 1~4) + 본 Stage 5 보고 커밋 = 총 7개
- working tree clean (본 보고 커밋 직후)
- `git log --oneline devel..local/task45`이 의도된 Stage 커밋 메시지를 모두 보여줌
- PR 생성(`publish/task45` push + draft PR)은 작업지시자 승인 후 별도 진행

## 작업지시자 승인 요청

- 본 최종 보고서 검토 후 PR 게시 단계 진행 승인 요청
- 잔여 위험 1번(Claude Code import 실측)과 2번(CLI SKILL 인식 실측)을 후속 별도 이슈로 등록할지 여부 확인 요청
