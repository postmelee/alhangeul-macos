# Task #332 Stage 1 보고서 - 기준 차이 정리

## 단계 목적

PR #331 반영 기준의 `external-pr-review`와 현재 보강 초안을 비교해, 보존해야 할 규칙과 추가 반영할 절차를 분리했다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m013_332_stage1.md` | PR #331 기준과 stash 초안 비교 결과 |

## 본문 변경 정도 / 본문 무손실 여부

Stage 1은 조사와 보고서 작성 단계다. Skill 본문은 아직 변경하지 않았다.

## 검토 결과

PR #331 기준 `external-pr-review`에는 다음 항목이 들어 있다.

- GitHub 공개 review/comment 본문을 inline `--body`가 아니라 `--body-file`로 등록
- `scripts/validate-github-body.sh`로 body file 검증
- review request가 남아 있는 PR은 단순 comment보다 `gh pr review --body-file` 사용

stash 초안에는 다음 항목이 들어 있다.

- review 시작 전에 reviewer/assignee/label/milestone 권장값을 제안하는 triage gate
- 작업지시자 승인 전 본격 diff 검토, 문서 작성, GitHub 상태 변경 금지
- `기여자 피드백 판단` 섹션
- 첫 기여자 환영, 구체적 칭찬, 실행 가능한 개선 안내 원칙
- 내부 후속 수정은 외부 PR 안에서 몰래 처리하지 않고 별도 Issue/내부 타스크로 분리
- `external-pr-complete` 신규 Skill 초안

Stage 2에서는 PR #331의 body-file 검증과 GitHub 참조 표기 규칙을 보존하면서 stash 초안의 review 보강 항목을 병합한다. Stage 3에서는 stash의 untracked parent에 저장된 `external-pr-complete` 초안을 신규 파일로 추가한다.

## 검증 결과

```text
git cat-file -e origin/devel:mydocs/skills/external-pr-review/SKILL.md
# OK

git cat-file -e 'stash@{0}:mydocs/skills/external-pr-review/SKILL.md'
# OK

git cat-file -e 'stash@{0}^3:mydocs/skills/external-pr-complete/SKILL.md'
# OK

git status --short
# 빈 출력
```

## 잔여 위험

- `external-pr-review`를 stash 초안으로 단순 덮어쓰면 PR #331의 GitHub body-file 검증 절차가 사라질 수 있다.
- `external-pr-complete` 신규 Skill에 GitHub 참조 표기 규칙이 없으면 완료 코멘트에서 PR/Issue 참조 토큰이 조사와 붙을 수 있다.

## 다음 단계 영향

Stage 2는 `external-pr-review`를 직접 편집한다. PR #331 기준의 review 등록 절차와 이번 triage/기여자 피드백 보강을 한 문서 안에서 병합해야 한다.

## 승인 요청

Stage 2로 진행한다.
