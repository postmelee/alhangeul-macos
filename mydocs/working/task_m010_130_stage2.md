# Issue #130 Stage 2 완료 보고서

## 단계 목적

Stage 1에서 확정한 분류 기준을 바탕으로 `project-artifact-cleanup` Skill을 신규 작성했다. 이 Skill은 빌드/렌더/임시 산출물 정리를 dry-run 후보 보고 중심으로 수행하고, 실제 삭제는 작업지시자 명시 승인 후에만 허용한다.

## 산출물

- `mydocs/skills/project-artifact-cleanup/SKILL.md` — 신규 프로젝트 부산물 정리 Skill
- `mydocs/working/task_m010_130_stage2.md` — Stage 2 완료 보고서

## Skill 작성 내용

신규 Skill frontmatter:

- `name: project-artifact-cleanup`
- `allow_implicit_invocation: false`
- description에 명시 호출 전용, dry-run 분류, git/worktree/install 보호, 승인 후 삭제 조건을 포함

본문 구성:

1. 트리거와 사전 조건
2. 현재 상태 확인 명령
3. read-only 후보 수집 명령
4. `safe`, `approval-required`, `never-delete` 분류 기준
5. Debug build 정리 전 Release 설치본 갱신 판단
6. 삭제 전 승인 요청 형식
7. 절대 하지 말 것
8. Codex/Claude Code 호출 방법

## 반영한 보호 규칙

- 기본 동작은 삭제가 아니라 dry-run 후보 보고다.
- `git worktree list --porcelain`에 등록된 경로는 삭제 금지다.
- `.git` 디렉터리 또는 gitfile이 있는 경로는 삭제 금지다.
- 저장소 루트, `/private/tmp` 자체, `$HOME`, `$HOME/Applications` 자체는 삭제 금지다.
- `$HOME/Applications/AlhangeulMac.app`는 cleanup 후보로 삭제하지 않는다.
- Release 설치본 갱신 절차에서 표준 설치본을 교체하는 경우는 일반 cleanup 삭제와 분리하고, 작업지시자 승인 후에만 수행한다고 명시했다.
- 이전 이름 설치본(`RhwpMac.app`, `알한글.app`)은 충돌 확인과 승인 없이 삭제하지 않는다.
- PR merge 후 branch/worktree 정리는 이 Skill이 아니라 기존 `pr-merge-cleanup` Skill 책임으로 분리했다.

## 검증 결과

```text
test -f mydocs/skills/project-artifact-cleanup/SKILL.md
```

결과: 통과.

```text
rg -n "allow_implicit_invocation: false|명시 호출|dry-run|safe|approval-required|never-delete|git worktree|pluginkit|qlmanage" \
  mydocs/skills/project-artifact-cleanup/SKILL.md
```

결과: 통과. frontmatter, 명시 호출, dry-run, 세 분류명, worktree 보호, PlugInKit/Quick Look 기준이 모두 확인됐다.

```text
git diff --check -- mydocs/skills/project-artifact-cleanup/SKILL.md mydocs/working/task_m010_130_stage2.md
```

결과: 통과. Skill 본문과 Stage 2 보고서가 모두 검사 범위에 포함됐다.

```text
wc -l mydocs/skills/project-artifact-cleanup/SKILL.md
```

결과: 185 lines. Skill 본문은 500줄 이하로 유지했다.

## 잔여 위험

- 실제 삭제 명령은 아직 검증하지 않았다. 본 타스크 범위는 Skill 작성이며, 실제 cleanup은 신규 Skill을 명시 호출하는 별도 작업에서 dry-run과 승인 후 수행해야 한다.
- Release 설치본 갱신 절차는 `rm -rf "$APP"`를 포함하므로, Skill 본문에서 일반 cleanup 삭제와 구분했지만 실제 실행 시에도 작업지시자 승인을 다시 확인해야 한다.
- `/private/tmp` 후보는 이름 패턴만으로 완전히 판정할 수 없으므로, dry-run 보고에서 보호 사유와 삭제 사유를 사람이 확인해야 한다.

## 다음 단계 영향

Stage 3에서는 신규 Skill이 `mydocs/skills`, `.agents/skills`, `.claude/skills` 세 경로에서 모두 접근 가능한지 검증한다. 이후 최종 보고서와 오늘할일 완료 처리를 작성하고 PR 게시 준비 상태로 정리한다.

## 승인 요청

Stage 2 완료를 보고한다. 다음 단계인 Stage 3 — 접근성 검증과 최종 보고 준비를 승인 요청한다.
