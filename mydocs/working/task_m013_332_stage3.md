# Task #332 Stage 3 보고서 - external-pr-complete 신규 추가

## 단계 목적

외부 기여자 PR이 merge, cherry-pick, 또는 수동 반영된 뒤의 완료 처리 절차를 `external-pr-complete` Skill로 분리했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/skills/external-pr-complete/SKILL.md` | merge 후 완료 보고서, PR/Issue 완료 코멘트 초안, 승인 후 GitHub 처리, archive 이동 절차 |
| `mydocs/working/task_m013_332_stage3.md` | Stage 3 완료 보고 |

## 본문 변경 정도 / 본문 무손실 여부

- 신규 Skill 179줄을 추가했다.
- `external-pr-review`에서 넘긴 merge 후 완료 처리 책임을 별도 Skill로 수용했다.
- PR/Issue 코멘트 초안 전문을 report 문서에 저장하지 않고 응답에만 제시하는 원칙을 명시했다.

## 검증 결과

```text
git diff --check
# OK

rg -n "PR 완료 코멘트|Issue 완료 코멘트|첫 기여자|메인테이너 후속|pr_\\{N\\}_report|GitHub 참조 표기 규칙" mydocs/skills/external-pr-complete/SKILL.md
# PR 완료 코멘트, Issue 완료 코멘트, 첫 기여자, 메인테이너 후속, pr_{N}_report, GitHub 참조 표기 규칙 문구 확인
```

## 잔여 위험

- 실제 GitHub 코멘트 등록과 issue close는 작업지시자 승인 후에만 수행되므로, Skill 실행 시 승인 gate를 지켜야 한다.
- merge/cherry-pick 전 완료 코멘트 작성은 금지되어 있으므로 `external-pr-review` 단계와 혼동하지 않아야 한다.

## 다음 단계 영향

Stage 4에서 두 Skill의 책임 경계와 최종 검증 결과를 확인한 뒤 최종 보고서와 PR을 작성한다.

## 승인 요청

Stage 4로 진행한다.
