# Issue #45 Stage 2 완료 보고서

## 단계 목적

AGENTS.md를 항상 필요한 정책·제약·인덱스 중심의 ≤ 100줄로 압축하고, CLAUDE.md를 `@AGENTS.md` 임포트 기반 ≤ 30줄로 축소한다. Stage 1에서 분리한 매뉴얼 3종을 인덱스에 추가한다.

## 산출물

| 파일 | 변경 전 | 변경 후 | 수용 기준 |
|------|---------|---------|-----------|
| `AGENTS.md` | 263줄 | 74줄 | ≤ 100 ✓ |
| `CLAUDE.md` | 257줄 | 5줄 | ≤ 30 ✓ |

총 263 + 257 = 520줄 → 74 + 5 = 79줄. **84.8% 감소**.

## AGENTS.md 새 구조

| 섹션 | 라인 범위 | 비고 |
|------|----------|------|
| 헤더 + 운영 정책 안내 | 1~3 | 매 턴 적재되는 파일임을 명시 |
| 프로젝트 개요 | 5~12 | 8줄, 기존 9줄에서 1줄 축소 |
| 하이퍼-워터폴 핵심 규칙 | 14~29 | 10개 규칙 + 승인 간주 조건 |
| 명명 규칙 | 31~41 | 마일스톤·브랜치·커밋·문서 파일명 통합 블록 |
| 핵심 강제 규칙 | 43~51 | 7개 항목, 각 1줄 + 매뉴얼 링크 |
| 필수 참조 문서 | 53~66 | 12개 인덱스 (신규 매뉴얼 3종 포함) |
| Agent Skills 정책 | 68~70 | 진실 원천·심볼릭 링크·`allow_implicit_invocation: false` 정책 1단락 |
| 작업 규칙 | 72~74 | 1줄 |

## CLAUDE.md 새 구조

```markdown
# CLAUDE.md

본 저장소의 에이전트 운영 규칙은 [`AGENTS.md`](AGENTS.md)를 단일 진실 원천으로 한다. Claude Code도 이 규칙을 그대로 적용한다.

@AGENTS.md
```

`@AGENTS.md` 임포트 표기는 Claude Code 공식 표기법이며, 다음 세션부터 본문 상속이 적용된다. Codex는 CLAUDE.md를 읽지 않고 AGENTS.md만 참조하므로 영향 없음.

## 본문에서 제거된 블록

다음 블록은 Stage 1에서 분리한 매뉴얼로 이전되었고 AGENTS.md에서 제거되었다.

| 제거 블록 | 이전처 |
|-----------|--------|
| 폴더 구조 목록 (12 entries) | `document_structure_guide.md` |
| 폴더 역할 표 (12행) | `document_structure_guide.md` |
| 문서 파일명 규칙 4개 강제 규칙 | `document_structure_guide.md` |
| 외부 PR 처리 폴더 정책 + 즉시 처리 절차 | `document_structure_guide.md` + `pr_process_guide.md` |
| 빌드 강제 규칙 7개 상세 | `build_run_guide.md` (기존, AGENTS.md엔 1줄 요약) |
| Git 워크플로우 다이어그램 + 운영 원칙 | `git_workflow_guide.md` |
| 메인테이너 워크플로우 bash 예시 | `git_workflow_guide.md` |
| 컨트리뷰터 워크플로우 bash 예시 | `git_workflow_guide.md` |
| 타스크 진행 15단계 절차 | `task_workflow_guide.md` |

## AGENTS.md에 남아 있는 핵심 키워드 (정보 무손실 점검)

```
14:## 하이퍼-워터폴 핵심 규칙
27:- PR merge와 이슈 close 후에는 `devel`로 돌아오고, 더 이상 필요 없는 `local/task{번호}` 브랜치와 임시 worktree를 정리
29:**승인 간주 조건**: ...
34:- 브랜치: `local/task{이슈번호}` (작업), `publish/task{이슈번호}` (devel 대상 PR 게시용)
40:- 문서 파일명: `task_{milestone}_{이슈번호}{_impl|_stage{N}|_report}?.md`
70:Agent Skills ... `allow_implicit_invocation: false` ...
```

## 검증 결과

```
--- line counts ---
   74 AGENTS.md
    5 CLAUDE.md
   79 total

--- manual links validity (전체 11개 모두 ok) ---
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

--- diff check ---
diff-check ok
```

## 잔여 위험

- Claude Code의 `@AGENTS.md` 임포트가 실제 다음 세션부터 정상 적용되는지는 본 단계 종료 시점에 직접 확인 불가. 사용자가 Claude Code 새 세션을 열 때 AGENTS.md 본문이 시스템 프롬프트에 포함되는지 점검이 필요하다. 만약 미지원으로 판명되면 CLAUDE.md를 짧은 안내문 + 핵심 규칙 요약 형태로 폴백한다.
- AGENTS.md에서 빌드/Swift/core 강제 규칙을 1줄 요약 + 매뉴얼 링크로 압축했으므로, 새 에이전트 세션에서 작업 전 해당 매뉴얼을 1회 읽어야 정확한 제약을 알 수 있다. 이는 모범 사례(점진적 공개)의 의도된 동작이다.

## 다음 단계 영향

Stage 3에서 SKILL.md 5종을 작성하면 AGENTS.md "Agent Skills" 섹션의 정책 안내가 실제 디렉터리·심볼릭 링크와 일치하게 된다.

## 승인 요청

Stage 3(하이퍼-워터폴 절차 SKILL.md 5종 작성) 진입 승인 요청.
