---
name: external-pr-complete
description: |
  외부 기여자 PR이 merge 또는 cherry-pick 반영된 뒤 완료 처리를 수행한다.
  명시 호출 시에만 사용한다. PR/Issue 완료 코멘트 초안 작성, pr_{N}_report.md 작성,
  승인 후 GitHub 코멘트 등록, 관련 Issue close, mydocs/pr/archives 이동을 처리한다.
  첫 기여자 환영, 구체적 기여 칭찬, maintainer 후속 보완 안내를 완료 메시지에 반영한다.
  외부 PR 운영 기록만 바뀐 경우 별도 PR 없이 대상 통합 브랜치에 직접 커밋/푸시한다.
  external-pr-review 이후 merge/반영이 끝난 외부 PR 전용.
allow_implicit_invocation: false
---

# 외부 기여자 PR 완료 처리

## 트리거

- 명시 호출만: 작업지시자가 "외부 PR #N 완료 처리", "PR #N merge 후 정리", "`external-pr-complete` 실행"을 지시한 경우
- `external-pr-review`에서 merge/cherry-pick 가능으로 검토되고, 작업지시자가 실제 반영 완료 또는 완료 처리 진행을 명시한 경우

## 사전 조건

- 대상은 외부 기여자 PR이다. 내부 task PR(`publish/task{N}`)에는 사용 금지
- `mydocs/pr/pr_{N}_review.md`가 존재하거나, 처리 근거가 PR/Issue 코멘트로 재구성 가능해야 한다
- PR이 GitHub merge 완료 상태이거나, maintainer cherry-pick/수동 반영 commit이 확인되어야 한다
- 관련 Issue close는 작업지시자 승인 후에만 수행한다
- `gh` CLI 인증

## 직접 반영 기준

- `mydocs/pr/pr_{N}_review.md`, `mydocs/pr/pr_{N}_report.md`, `mydocs/pr/archives/**` 같은 외부 PR 운영 기록만 변경하면 별도 PR을 만들지 않고 대상 통합 브랜치에 직접 커밋/푸시한다.
- 직접 반영은 push까지 완료해야 한다. 운영 기록 커밋을 로컬 base branch에만 남기지 않는다.
- Skill, 매뉴얼, 코드, 빌드 설정, 앱 동작, workflow 정책 변경이 함께 있으면 직접 반영하지 말고 일반 Issue/브랜치/PR 절차로 분리한다.
- 직접 반영 전 `git pull --ff-only`가 실패하거나 대상 브랜치가 diverged 상태면 중단하고, 운영 기록 커밋만 재정렬할지 작업지시자에게 확인한다.

## 절차

1. 완료 상태 수집
   ```bash
   gh pr view {N} --json number,title,state,author,baseRefName,headRefName,isCrossRepository,mergedAt,mergeCommit,comments,commits,files,body,url
   gh pr checks {N}
   ```
   - PR state, merge commit, head SHA, base branch, 작성자, 연결 이슈, 기존 코멘트를 확인
   - cherry-pick/수동 반영이면 작업지시자 또는 git log로 반영 commit SHA를 확인
2. 관련 Issue 식별
   - PR 본문 `closes #N`, `Related: #N`, review 문서, 작업지시자 지시에서 후보를 찾음
   - 후보가 여러 개거나 `Related`만 있고 완료 여부가 애매하면 close 전에 작업지시자에게 확인
   - 이슈 확인:
     ```bash
     gh issue view {ISSUE} --json number,title,state,comments,url
     ```
3. 완료 보고서 작성 또는 갱신: `mydocs/pr/pr_{N}_report.md`
   - 표준 섹션:
     - PR 정보 (번호, 작성자, base/head, 연결 이슈)
     - 처리 결정 (merge / cherry-pick 통합 / close)
     - 반영 commit (PR head, merge commit 또는 cherry-pick commit)
     - 메인테이너 후속 보완/충돌 해소 내역
     - 검증 결과
     - 첫 기여 여부와 기여자 커뮤니케이션 요지
     - PR 완료 코멘트 등록 여부/링크/요지
     - Issue 코멘트/close 여부/링크/요지
     - 남은 리스크와 후속 이슈
   - PR/Issue 코멘트 초안 전문은 보고서에 쓰지 않는다. 링크와 요지만 기록한다
4. 응답용 완료 코멘트 초안 작성
   - 사용자 응답에만 `PR 완료 코멘트 초안`, `Issue 완료 코멘트 초안` 섹션으로 제시
   - 첫 기여자라면 환영과 감사를 포함하되, 칭찬은 구체적 기여 사실에 붙인다
   - 칭찬 후보는 문제 정의, 작은 변경 범위, 기존 구조 존중, 테스트/샘플 보강, maintainer 피드백 반영, 문서화처럼 실제 확인한 항목만 사용한다
   - maintainer가 충돌 해소, follow-up commit, cherry-pick 보정, 검증 보완을 했다면 숨기지 말고 비난 없이 사실로 적는다
   - PR 범위를 넘는 후속 항목이 남았으면 별도 Issue/내부 타스크 링크 또는 예정 문구를 completion comment에 짧게 포함한다
   - GitHub PR/Issue 참조 표기는 아래 "GitHub 참조 표기 규칙"을 따른다
   - 실제 수행한 검증만 적고, 실행하지 않은 검증은 쓰지 않는다
5. 작업지시자 승인 후 GitHub 처리
   - 승인 전에는 GitHub 코멘트 등록, issue close, branch cleanup을 하지 않는다
   - 승인 후 필요 시:
     ```bash
     gh pr comment {N} --body-file /tmp/pr_{N}_complete_comment.md
     gh issue comment {ISSUE} --body-file /tmp/issue_{ISSUE}_complete_comment.md
     gh issue close {ISSUE}
     ```
6. 처리 완료 문서 보관 이동
   ```bash
   git mv mydocs/pr/pr_{N}_review.md mydocs/pr/archives/
   git mv mydocs/pr/pr_{N}_review_impl.md mydocs/pr/archives/  # 존재 시
   git mv mydocs/pr/pr_{N}_report.md mydocs/pr/archives/
   ```
7. 직접 반영 준비
   ```bash
   BASE_BRANCH={PR base branch}
   git fetch origin --prune
   git checkout "$BASE_BRANCH"
   git pull --ff-only
   git status --short
   git diff --name-only --cached
   git diff --name-only
   ```
   - 변경 파일이 `mydocs/pr/**` 운영 기록으로만 제한되는지 확인한다.
   - 다른 파일이 섞이면 commit/push를 중단하고 일반 작업 PR로 분리한다.
8. 단일 커밋 후 직접 push
   ```bash
   git add mydocs/pr/
   git commit -m "PR #{N} 완료 처리: {요약}"
   git push origin "$BASE_BRANCH"
   ```
   - push 실패 또는 non-fast-forward가 발생하면 강제 push하지 말고 작업지시자에게 보고한다.

## GitHub 참조 표기 규칙

- PR 완료 코멘트와 Issue 완료 코멘트 모두 GitHub PR/Issue 참조 토큰을 한글 조사와 붙여 쓰지 않는다.
- `#328으로`, `#132를`, `PR #328은`처럼 쓰지 말고 `#328 반영으로`, `#132 이슈를`, `PR #328 반영은`처럼 참조 토큰 뒤를 공백, 문장 부호, 또는 별도 명사로 분리한다.
- 여러 대상을 함께 적을 때는 `PR #328 및 Issue #132`처럼 각 참조 토큰을 독립적으로 둔다.

## PR 완료 코멘트 초안 원칙

- 목적은 merge 후 공개 완료 안내다. merge 전 검토 의견이나 사전 승인 요청으로 쓰지 않는다
- `edwardkim/rhwp` 방식처럼 다음 정보를 짧게 남긴다:
  - 반영 완료 선언
  - 반영 방식과 대상 branch
  - merge/cherry-pick commit SHA
  - 충돌 해소 또는 메인테이너 후속 보완 내역
  - 실행한 검증 명령
  - 시각/수동 판정 결과가 있으면 포함
  - 첫 기여자 환영 여부
  - 기여 감사와 구체적 기여 포인트
  - 남은 내부 후속 Issue/타스크 또는 다음 PR 안내가 있으면 한 줄로 포함
- 첫 기여자에게는 "첫 외부 기여라 더 반갑다"는 환영을 넣되, 프로젝트가 실제로 얻은 효과를 함께 적는다
- maintainer 후속 보완이 있었던 경우 "PR 내용 반영 후 maintainer 측에서 ..."처럼 사실 중심으로 적고, 기여자의 실패처럼 표현하지 않는다
- 다음 기여 안내는 실행 가능한 내용이 있을 때만 쓴다. 예: base branch, smoke test, 샘플 파일, 문서 위치

### PR 완료 코멘트 템플릿

~~~md
메인테이너 검증 및 반영 완료했습니다.

- PR #{N} 반영: `{base}`에 {merge/cherry-pick/수동 반영}했습니다.
- 반영 commit: `{sha}`
- {충돌 해소 또는 메인테이너 후속 보완 내역. 없으면 생략}
- {수동/시각/설치본 판정 결과. 없으면 생략}

검증:

```text
{실제로 실행한 검증 명령과 결과}
```

기여 감사합니다. {이번 PR의 구체적 기여 의미 또는 첫 기여 환영 문장}
{다음 PR에 도움이 되는 짧은 안내 또는 별도 후속 Issue/타스크 링크. 없으면 생략}
~~~

## Issue 완료 코멘트 초안 원칙

- Issue에는 "무엇으로 해결됐는지"와 "어떤 검증으로 닫는지"를 남긴다
- Issue 코멘트는 해결 근거 중심으로 쓴다. 기여자 칭찬과 환영 문구는 PR 완료 코멘트에 둔다
- PR이 `Related`만 사용했어도 작업지시자가 close를 승인하면 수동으로 comment 후 close한다
- 여러 issue가 관련되면 각 issue별로 해결 범위가 맞는지 분리해서 작성한다

### Issue 완료 코멘트 템플릿

~~~md
PR #{N} 반영 및 {필요 시 메인테이너 후속 보완}으로 해결되었습니다.

반영 내용:

- {핵심 해결 내용 1}
- {핵심 해결 내용 2}
- `{base}` 반영 commit: `{sha}`

검증:

```text
{실제로 실행한 검증 명령과 결과}
```

이 이슈는 완료 처리합니다.
~~~

## 판단 기준

- PR이 아직 merge/반영되지 않았으면 완료 코멘트를 작성하지 말고 `external-pr-review` 단계로 돌려보낸다
- issue close는 PR merge만으로 자동 실행하지 않는다. 작업지시자 승인과 해결 범위 확인이 필요하다
- 연결 이슈가 `Related`인지 `Closes`인지에 따라 자동 close 기대 여부를 구분하되, 실제 close 전 상태를 확인한다
- cherry-pick이면 원 PR head SHA와 반영 commit SHA를 모두 보고서에 기록한다
- 완료 코멘트 전문은 응답에만 제시하고, `pr_{N}_report.md`에는 링크와 요지만 남긴다
- 외부 PR 운영 기록만 바뀌면 별도 PR을 만들지 않는다. 직접 커밋 후 대상 통합 브랜치에 push까지 완료한다

## 검증

- `pr_{N}_report.md`에 처리 결정, commit SHA, 검증 결과, PR/Issue 처리 요지가 기록됨
- 응답에 PR 완료 코멘트 초안과 필요한 Issue 완료 코멘트 초안이 제시됨
- 승인 후 실제 GitHub 코멘트 URL과 issue close 상태가 확인됨
- 처리 완료 문서가 `mydocs/pr/archives/`로 이동됨
- 직접 반영 시 `git status --short --branch`에 대상 branch의 local-only ahead가 남지 않음

## 절대 하지 말 것

- 내부 task PR에 본 Skill 적용
- merge/반영 전 완료 코멘트 작성
- 작업지시자 승인 없이 PR comment, issue comment, issue close 수행
- 해결 범위가 불명확한 issue close
- 실행하지 않은 검증을 완료 코멘트나 보고서에 기록
- PR/Issue 코멘트 초안 전문을 `pr_{N}_report.md`에 복제
- 외부 PR 운영 기록 커밋을 로컬에만 남기고 push하지 않음
- Skill, 매뉴얼, 코드, 빌드 설정 변경을 외부 PR 운영 기록 직접 반영 커밋에 섞음
- non-fast-forward 상태에서 강제 push

## 호출 방법

- Codex: `$external-pr-complete PR #N 완료 처리`
- Claude Code: `/external-pr-complete`
