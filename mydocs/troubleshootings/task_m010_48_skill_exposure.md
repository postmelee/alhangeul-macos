# Codex/Claude Code SKILL 인식 실측 기록

본 문서는 Issue #48의 SKILL 노출 및 묵시 호출 회피 실측 기록이다. Task #45에서 추가한 하이퍼-워터폴 절차 SKILL 5종이 Codex와 Claude Code에서 의도대로 인식되는지 확인한다.

## 측정 대상

| SKILL | 원본 경로 | 의도한 호출 방식 |
|-------|-----------|------------------|
| `task-start` | `mydocs/skills/task-start/SKILL.md` | Codex `$task-start` 또는 `/skills`, Claude Code `/task-start` |
| `task-stage-report` | `mydocs/skills/task-stage-report/SKILL.md` | Codex `$task-stage-report` 또는 `/skills`, Claude Code `/task-stage-report` |
| `task-final-report` | `mydocs/skills/task-final-report/SKILL.md` | Codex `$task-final-report` 또는 `/skills`, Claude Code `/task-final-report` |
| `pr-merge-cleanup` | `mydocs/skills/pr-merge-cleanup/SKILL.md` | Codex `$pr-merge-cleanup` 또는 `/skills`, Claude Code `/pr-merge-cleanup` |
| `external-pr-review` | `mydocs/skills/external-pr-review/SKILL.md` | Codex `$external-pr-review` 또는 `/skills`, Claude Code `/external-pr-review` |

## 공통 파일 시스템 확인

- `.agents/skills`는 `../mydocs/skills`를 가리킨다.
- `.claude/skills`는 `../mydocs/skills`를 가리킨다.
- 5종 `SKILL.md` 모두 frontmatter에 `allow_implicit_invocation: false`를 포함한다.
- 5종 `SKILL.md` 모두 description 또는 트리거 섹션에 "명시 호출" 조건을 포함한다.

## Codex 측 측정

### 측정 환경

- 측정 시각: 2026-04-25 23:02 KST
- 측정 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 도구: Codex desktop
- 작업 브랜치: `local/task48`
- 기준 커밋: `0a3443d` (`origin/devel`)

### 노출 확인

현 Codex 세션의 Available skills 목록에 다음 5종이 모두 노출되었다.

- `task-start`
- `task-stage-report`
- `task-final-report`
- `pr-merge-cleanup`
- `external-pr-review`

각 항목은 저장소 내부 경로 `/Users/melee/Documents/projects/rhwp-mac/mydocs/skills/{name}/SKILL.md`를 원천으로 표시하며, 설명에는 "명시 호출 시에만 사용" 또는 그와 동등한 제한 조건이 포함되어 있다.

### 명시 호출 조건 확인

현재 브랜치에서 각 SKILL 원본 파일을 확인한 결과:

- `allow_implicit_invocation: false`가 5종 모두에 존재한다.
- `## 트리거` 섹션이 5종 모두에 존재한다.
- `## 트리거` 섹션은 작업지시자가 해당 절차를 명시 지시하거나 SKILL을 직접 호출한 경우를 호출 조건으로 둔다.

### 묵시 호출 회피 관찰

Issue #48 시작 과정에서 다음 동작을 관찰했다.

- 최초 작업 지시는 "https://github.com/postmelee/alhangeul-macos/issues/48 작업을 진행해줘"였고, 이는 `task-start`의 "타스크 #N 진행" 명시 트리거에 해당해 타스크 시작 절차를 적용했다.
- 이후 "진행해줘" 지시는 직전 응답에서 요청한 수행계획서 승인에 대한 명시 승인으로 해석했다. 이 지시만으로 5종 SKILL이 임의로 자동 실행되지는 않았다.
- 일반 파일 확인, 이슈 조회, git 상태 확인, 문서 작성 과정에서 `task-final-report`, `pr-merge-cleanup`, `external-pr-review`는 호출되지 않았다.
- Stage 1 완료 보고는 하이퍼-워터폴 절차상 필요한 단계 종료 작업이며, `task-stage-report`의 절차를 확인한 뒤 Stage 1 보고서 작성에만 적용했다.

현 시점 Codex 측에서는 의도와 다른 묵시 호출을 관찰하지 못했다.

### Codex 판정

**정상.** Codex 현재 세션에서 5종 SKILL은 모두 노출되며, frontmatter와 트리거 문구도 명시 호출 제한을 유지한다. 현재까지 일반 작업 흐름 중 의도하지 않은 묵시 호출은 관찰되지 않았다.

## Claude Code 측 측정

Claude Code 측 측정은 같은 브랜치에서 이어서 수행한다.

### 기록할 항목

- 측정 시각:
- 측정 위치:
- 도구/모델:
- 작업 브랜치:
- user-invocable skills 목록에 노출된 5종:
- 명시 호출 경로 확인:
- 일반 대화 중 묵시 호출 관찰 여부:
- 오동작이 있을 경우 재현 문장:
- 판정:

## 장기 관찰 항목

Issue #48 수용 기준의 "일반 작업 흐름 중 묵시적 호출 1주일 0건"은 단일 세션에서 즉시 완료할 수 없는 운영 관찰 기준이다. 본 문서는 관찰 시작 시점과 도구별 1차 판정을 기록하고, 향후 1주일 동안 묵시 호출이 관찰되면 이 문서 또는 후속 feedback 문서에 재현 문장과 호출된 SKILL을 추가한다.
