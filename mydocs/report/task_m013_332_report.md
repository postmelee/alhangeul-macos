# Task #332 최종 보고서 - 외부 PR 리뷰와 완료 처리 Skill 보강

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#332](https://github.com/postmelee/alhangeul-macos/issues/332) 외부 PR 리뷰와 완료 처리 Skill 보강 |
| 마일스톤 | M013 — 하이퍼-워터폴 작업환경 조성 |
| 단계 수 | 3개 구현 단계 + 최종 검증 |
| 기준 브랜치 | `origin/devel` |

PR #331에 포함되지 않은 외부 PR 처리 Skill 보강을 새 작업으로 정리했다. `external-pr-review`는 merge 전 검토와 피드백 판단에 집중하고, `external-pr-complete`는 merge/cherry-pick 이후 완료 코멘트와 Issue close handoff를 담당하도록 분리했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/skills/external-pr-review/SKILL.md` | triage gate, review 문서 표준 섹션, 기여자 피드백 판단, 내부 후속 분리, 응답 전용 코멘트 초안, body-file 기반 GitHub review/comment 등록 절차 보강 |
| `mydocs/skills/external-pr-complete/SKILL.md` | 외부 PR merge 후 완료 처리 Skill 신규 추가. `pr_{N}_report.md`, PR/Issue 완료 코멘트 초안, 승인 후 GitHub comment/issue close, archives 이동 절차 정의 |
| `mydocs/plans/task_m013_332.md` | 수행계획서 |
| `mydocs/plans/task_m013_332_impl.md` | 구현계획서 |
| `mydocs/working/task_m013_332_stage1.md` | PR #331 기준과 stash 초안 차이 정리 |
| `mydocs/working/task_m013_332_stage2.md` | `external-pr-review` 보강 단계 보고 |
| `mydocs/working/task_m013_332_stage3.md` | `external-pr-complete` 추가 단계 보고 |
| `mydocs/orders/20260603.md` | #332 진행/완료 상태 반영 |

## 변경 전·후 정량 비교

| 항목 | 변경 후 |
|------|---------|
| `external-pr-review` | 191줄 |
| `external-pr-complete` | 179줄 신규 |
| 작업 문서 | 수행계획서 72줄, 구현계획서 105줄, 단계 보고서 합계 145줄 |
| 검증 명령 | `git diff --check`, `rg` 문구 확인, `git status --short` |

## 검증 결과

| 수용 기준 | 결과 |
|-----------|------|
| `external-pr-review`가 review 시작 triage gate를 먼저 제안 | OK |
| 작업지시자 승인 전 본격 review와 GitHub 상태 변경 금지 | OK |
| 첫 기여자 환영, 구체적 칭찬, 실행 가능한 개선 안내 반영 | OK |
| 내부 후속 수정 분리 원칙 반영 | OK |
| PR #331의 body-file 검증과 GitHub 참조 표기 규칙 보존 | OK |
| `external-pr-complete` 신규 Skill 추가 | OK |
| 완료 코멘트 초안 전문을 report에 저장하지 않는 원칙 반영 | OK |
| `git diff --check` | OK |
| 관련 문구 `rg` 확인 | OK |
| `git status --short` | OK |

검증 명령:

```text
git diff --check

rg -n "external-pr-complete|기여자 피드백|내부 후속|GitHub 참조 표기 규칙|PR 완료 코멘트|body-file" mydocs/skills/external-pr-review/SKILL.md mydocs/skills/external-pr-complete/SKILL.md

git status --short
```

## 잔여 위험과 후속 작업

- 실제 GitHub review/comment 등록은 Skill 사용 시 작업지시자 승인 후에만 수행해야 한다.
- `external-pr-complete`는 merge/cherry-pick 완료 후 전용 Skill이므로, merge 전 검토 단계에서 호출하지 않아야 한다.
- 향후 실제 외부 PR 처리에서 초안 문구가 지나치게 길어지면 템플릿을 더 줄일 수 있다.

## 작업지시자 승인 요청

Issue #332 변경은 완료되었다. `publish/task332` PR 생성 후 review와 merge 승인을 요청한다.
