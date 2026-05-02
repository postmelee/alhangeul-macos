# Issue #130 최종 결과 보고서

## 작업 요약

- **이슈**: [#130 프로젝트 부산물 정리 Skill 추가](https://github.com/postmelee/alhangeul-macos/issues/130)
- **마일스톤**: 하이퍼-워터폴 작업환경 조성
- **브랜치**: `local/task130`
- **단계 수**: 3
- **참조 문서**:
  - 수행계획서: [`task_m010_130.md`](../plans/task_m010_130.md)
  - 구현계획서: [`task_m010_130_impl.md`](../plans/task_m010_130_impl.md)
  - 단계별 보고서: [`stage1`](../working/task_m010_130_stage1.md), [`stage2`](../working/task_m010_130_stage2.md), [`stage3`](../working/task_m010_130_stage3.md)

## 배경

프로젝트 작업 중 `build.noindex/`, `output/`, `RustBridge/target/`, `Frameworks/`, `/private/tmp/rhwp*`, `/private/tmp/alhangeul*`에 재생성 가능한 산출물이 누적된다. 그러나 같은 패턴 안에 실제 git worktree, git repository, 현재 task 검증 증거, Quick Look/Thumbnail 테스트용 설치본과 연결된 산출물이 섞일 수 있어 단순 패턴 삭제는 위험하다.

본 작업은 이러한 부산물을 정리할 때 사용할 명시 호출 전용 Skill을 추가하고, 기본 동작을 삭제가 아닌 dry-run 후보 보고로 고정했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/skills/project-artifact-cleanup/SKILL.md` | 신규 Skill. dry-run 후보 수집, `safe`/`approval-required`/`never-delete` 분류, git/worktree/install 보호, 승인 후 삭제 절차 정의 |
| `mydocs/plans/task_m010_130.md` | 수행계획서 |
| `mydocs/plans/task_m010_130_impl.md` | 3단계 구현계획서 |
| `mydocs/working/task_m010_130_stage1.md` | 정리 대상과 보호 규칙 확정 보고 |
| `mydocs/working/task_m010_130_stage2.md` | Skill 작성 보고 |
| `mydocs/working/task_m010_130_stage3.md` | 접근성 검증과 최종 보고 준비 보고 |
| `mydocs/report/task_m010_130_report.md` | 본 최종 결과 보고서 |
| `mydocs/orders/20260502.md` | #130 완료 처리 |

Rust/Swift/Xcode 소스와 빌드 산출물은 변경하지 않았다. 실제 부산물 삭제도 수행하지 않았다.

## 변경 전·후 정량 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| `project-artifact-cleanup` Skill | 없음 | `mydocs/skills/project-artifact-cleanup/SKILL.md` 175 lines |
| Skill 접근 경로 | 없음 | `mydocs/skills`, `.agents/skills`, `.claude/skills` 3개 경로 접근 가능 |
| cleanup 실행 방식 | 정해진 전용 절차 없음 | dry-run 후보 보고 후 승인 삭제 절차 문서화 |
| 실제 부산물 삭제 | 0건 | 0건 |
| 코드/빌드 산출물 변경 | 없음 | 없음 |

## 주요 결정

### 기본 동작

- `project-artifact-cleanup`은 명시 호출 시에만 사용한다.
- 기본 동작은 dry-run 후보 보고다.
- 실제 삭제는 작업지시자가 개별 경로 목록을 확인하고 명시 승인한 뒤에만 수행한다.

### 분류 기준

| 분류 | 대표 예 |
|------|---------|
| `safe` | `build.noindex/DerivedData*`, `output/stage3-render*`, `output/task*-*`, `/private/tmp/rhwp-task*-render`, `/private/tmp/rhwp-task*-swift-module-cache`, `/private/tmp/task*-pr-body.md`, `/private/tmp/alhangeul-*` |
| `approval-required` | `build.noindex/release`, `RustBridge/target`, `Frameworks`, `/private/tmp/rhwp-core-*`, 상태가 불분명한 현재 task 산출물 |
| `never-delete` | 저장소 루트, `/private/tmp` 자체, `$HOME`, `$HOME/Applications/AlhangeulMac.app`, git worktree, `.git` 보유 경로 |

### Debug build cleanup

Debug build는 compile/link 확인용이므로 `build.noindex/DerivedData*` 정리 후보가 될 수 있다. 다만 Quick Look/Thumbnail/Viewer 테스트가 계속 필요하면 먼저 Release package 산출물을 `$HOME/Applications/AlhangeulMac.app` 표준 설치본으로 갱신하고 `lsregister`, `pluginkit`, `qlmanage -t` 확인을 거친 뒤 Debug 산출물 삭제를 제안하도록 했다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| `test -f mydocs/skills/project-artifact-cleanup/SKILL.md` | OK |
| `test -f .agents/skills/project-artifact-cleanup/SKILL.md` | OK |
| `test -f .claude/skills/project-artifact-cleanup/SKILL.md` | OK |
| `rg -n "project-artifact-cleanup|dry-run|never-delete|approval-required|호출 방법|Codex:|Claude Code:" mydocs/skills/project-artifact-cleanup/SKILL.md` | OK |
| `git diff --check` | OK |
| `git status --short` | 최종 커밋 전 변경 파일만 존재 |

심볼릭 링크 확인:

```text
.agents/skills -> ../mydocs/skills
.claude/skills -> ../mydocs/skills
```

## 단계별 커밋 히스토리

```text
aa48017 Task #130 Stage 3 + 최종 보고서: 부산물 정리 Skill 검증과 보고
66fc825 Task #130 Stage 2: 프로젝트 부산물 정리 Skill 작성
0eeb8b9 Task #130 Stage 1: 부산물 정리 기준과 보호 규칙 확정
ce40588 Task #130: 구현 계획서 작성
56f2705 Task #130: 수행 계획서 작성과 오늘할일 갱신
```

PR 리뷰 지적 반영 커밋이 추가된다: `Task #130: PR 리뷰 지적 반영`.

## 잔여 위험과 후속 작업

- 실제 삭제는 아직 수행하지 않았다. 새 Skill을 명시 호출하는 별도 작업에서 dry-run 보고와 승인 후 수행해야 한다.
- `/private/tmp` 파일명은 작업자가 자유롭게 만들 수 있으므로 패턴 기반 분류는 항상 최종 확인이 필요하다.
- `Frameworks/`와 `RustBridge/target/`은 재생성 가능하지만 삭제 후 즉시 재빌드 가능한 환경인지 확인해야 한다.
- Release 설치본 갱신 절차는 `$HOME/Applications/AlhangeulMac.app` 교체를 포함하므로 일반 cleanup 삭제와 분리해 별도 승인으로 다뤄야 한다.

## PR 게시 준비 상태

- 신규 Skill 작성 완료
- 세 경로 접근성 검증 완료
- 오늘할일 완료 처리 완료
- 최종 보고서 작성 완료
- PR #131 게시 완료 후 Copilot 리뷰 지적을 반영했다.

## 작업지시자 승인 요청

본 최종 보고서와 PR 리뷰 반영 내용을 확인하고 PR #131 리뷰·merge 승인을 요청한다.
