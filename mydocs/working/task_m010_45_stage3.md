# Issue #45 Stage 3 완료 보고서

## 단계 목적

하이퍼-워터폴 절차의 정형 시점 5개를 Codex/Claude Code 양쪽 호환 SKILL.md로 분리한다. 진실 원천은 `mydocs/skills/`에 둔다. 모든 SKILL은 `allow_implicit_invocation: false` + 도구 비종속 본문으로 작성한다.

## 산출물

| Skill | 파일 | 라인 수 | 트리거 시점 |
|-------|------|---------|-------------|
| `task-start` | `mydocs/skills/task-start/SKILL.md` | 76 | 새 타스크 시작 (이슈 → 브랜치 → orders → 수행계획서) |
| `task-stage-report` | `mydocs/skills/task-stage-report/SKILL.md` | 65 | 한 단계 종료 (검증 → `_stage{N}.md` → 묶음 커밋) |
| `task-final-report` | `mydocs/skills/task-final-report/SKILL.md` | 80 | 모든 단계 완료 후 (보고서 → push → draft PR) |
| `pr-merge-cleanup` | `mydocs/skills/pr-merge-cleanup/SKILL.md` | 76 | PR merge 확인 후 (이슈 close → 브랜치/worktree 정리) |
| `external-pr-review` | `mydocs/skills/external-pr-review/SKILL.md` | 77 | 외부 기여자 PR 검토 (review/impl/report → archives) |

총 374줄.

## 표준 frontmatter 일관성

5종 모두 다음 형식을 따른다.

```
---
name: <skill-name>
description: |
  <2~5줄 설명. 명시 호출 전용임 명시. 어떤 시점에 무엇을 수행하는지 구체적으로>
allow_implicit_invocation: false
---
```

`description`은 양 도구 모두 묵시적 트리거 후보로 사용하지 않도록, 매우 구체적인 시점·동작만 기술하고 일반화된 표현은 피했다.

## 표준 본문 섹션

5종 모두 동일 섹션 순서로 작성됨:

1. 트리거 (명시 호출 조건)
2. 사전 조건
3. 절차 (`gh`/`git`/파일 생성 한정 명령)
4. 검증
5. 절대 하지 말 것
6. 호출 방법 (Codex `$skill-name` / Claude Code `/skill-name`)

## 도구 비종속성 점검

본문에서 "호출 방법" 섹션을 제외한 영역에 도구 이름(claude code, codex)이 노출되지 않음 — 검증 명령으로 확인:

```
--- tool name leakage in body (excluding 호출 방법 section) ---
(빈 출력)
```

## 검증 결과

```
--- skill files ---
ok task-start
ok task-stage-report
ok task-final-report
ok pr-merge-cleanup
ok external-pr-review

--- allow_implicit_invocation flags ---
mydocs/skills/task-final-report/SKILL.md:8:allow_implicit_invocation: false
mydocs/skills/pr-merge-cleanup/SKILL.md:8:allow_implicit_invocation: false
mydocs/skills/external-pr-review/SKILL.md:7:allow_implicit_invocation: false
mydocs/skills/task-stage-report/SKILL.md:7:allow_implicit_invocation: false
mydocs/skills/task-start/SKILL.md:8:allow_implicit_invocation: false

--- line counts ---
   77 mydocs/skills/external-pr-review/SKILL.md
   76 mydocs/skills/pr-merge-cleanup/SKILL.md
   80 mydocs/skills/task-final-report/SKILL.md
   65 mydocs/skills/task-stage-report/SKILL.md
   76 mydocs/skills/task-start/SKILL.md
  374 total

--- diff check ---
diff-check ok
```

## 잔여 위험

- `allow_implicit_invocation: false`는 Codex 표준 키이며 Claude Code는 미인식 키를 무시한다. Claude Code에서 묵시적 호출이 발생하지 않도록 `description`을 좁게 작성했지만, 모델 판단에 따라 변동 가능성은 남는다. Stage 4에서 양 도구 인식 점검 시 description 매칭이 의도와 일치하는지 추가 점검한다.
- 본 단계에서는 진실 원천만 작성했고 Codex/Claude Code가 인식하는 `.agents/skills`·`.claude/skills` 심볼릭 링크는 Stage 4에서 생성한다.

## 다음 단계 영향

Stage 4에서 `.agents/skills`와 `.claude/skills`를 `mydocs/skills`로 가리키는 심볼릭 링크로 만들면 두 도구가 동일한 SKILL.md를 인식하게 된다.

## 승인 요청

Stage 4(skills 심볼릭 링크와 양 도구 인식 정책) 진입 승인 요청.
