# Task #332 Stage 2 보고서 - external-pr-review 보강

## 단계 목적

`external-pr-review`에 외부 PR 검토 시작 triage, 기여자 피드백 판단, 내부 후속 분리, 응답 전용 코멘트 초안 규칙을 반영했다. PR #331에서 도입된 GitHub 공개 본문 body-file 검증과 참조 표기 규칙도 보존했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/skills/external-pr-review/SKILL.md` | triage gate, 피드백 판단, body-file 등록 절차, 내부 후속 분리 원칙 보강 |
| `mydocs/working/task_m013_332_stage2.md` | Stage 2 완료 보고 |

## 본문 변경 정도 / 본문 무손실 여부

- `external-pr-review` 절차를 기존 9단계에서 11단계로 재구성했다.
- 기존 GitHub 공개 review/comment 등록 절차는 `--body-file`과 `scripts/validate-github-body.sh` 사용 조건을 유지했다.
- 기존 archive 이동과 완료 보고서 책임은 merge 후 절차인 `external-pr-complete`로 넘기도록 정리했다.

## 검증 결과

```text
git diff --check
# OK

rg -n "GitHub 참조 표기 규칙|body-file|기여자 피드백|내부 후속|첫 기여" mydocs/skills/external-pr-review/SKILL.md
# GitHub 참조 표기 규칙, body-file, 기여자 피드백, 내부 후속, 첫 기여 문구 확인
```

## 잔여 위험

- 실제 GitHub review/comment 등록은 작업지시자 승인 후에만 수행되므로, Skill 사용자가 응답 초안과 공개 등록 단계를 혼동하지 않아야 한다.
- `external-pr-complete`가 아직 Stage 3에서 추가되지 않았기 때문에 현재 시점에서는 review Skill의 handoff 대상 파일이 존재하지 않는다.

## 다음 단계 영향

Stage 3에서 `external-pr-complete`를 추가해 merge/cherry-pick 이후 PR/Issue 완료 코멘트 초안, `pr_{N}_report.md`, archive 이동 책임을 완성한다.

## 승인 요청

Stage 3으로 진행한다.
