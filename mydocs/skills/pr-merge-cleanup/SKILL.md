---
name: pr-merge-cleanup
description: |
  PR merge 확인 후 부산물을 정리하는 절차를 적용한다. 명시 호출 시에만 사용한다.
  GitHub 이슈 close, publish/task{N} 원격 브랜치 삭제,
  로컬 local/task{N} 브랜치와 분리 worktree 정리, 대상 통합 브랜치 복귀를 수행한다.
  PR이 실제로 merge된 직후에만 호출.
allow_implicit_invocation: false
---

# PR merge 후 부산물 정리

## 트리거

- 명시 호출만: 작업지시자가 "merge 후 정리", "타스크 정리"를 명시 지시한 경우
- 본 SKILL을 직접 호출한 경우

## 사전 조건

- 대상 PR이 GitHub에서 실제 merged 상태 (`gh pr view {번호} --json state,mergeCommit`)
- 작업지시자의 이슈 close 승인 (또는 PR 본문에 `closes #N` 명시되어 자동 close된 상태)

## 절차

1. PR과 이슈 상태 확인
   ```bash
   gh pr view {번호} --json state,mergedAt,mergeCommit,headRefName
   gh issue view {N} --json state
   ```
   - PR `state == MERGED` 아니면 즉시 중단하고 작업지시자 보고
2. 이슈 close (자동 close 안 된 경우만)
   ```bash
   gh issue close {N}
   ```
3. 대상 통합 브랜치 최신화
   ```bash
   git fetch origin --prune
   BASE_BRANCH=$(gh pr view {번호} --json baseRefName --jq .baseRefName)
   git checkout "$BASE_BRANCH"
   git pull --ff-only
   ```
4. 원격 publish 브랜치 삭제 (이미 PR merge 시 `--delete-branch`로 삭제된 경우 skip)
   ```bash
   git push origin --delete publish/task{N} 2>&1 || echo "이미 삭제됨"
   ```
5. 분리 worktree 사용했다면 제거
   ```bash
   git worktree remove ../{repo}-task{N}
   git worktree prune
   ```
6. 로컬 작업 브랜치 삭제 (재사용 가능성 없을 때만)
   ```bash
   git branch -d local/task{N}
   # 강제 삭제는 작업지시자 명시 승인 후에만: git branch -D local/task{N}
   ```
7. 오늘할일 최종 정리: `mydocs/orders/{yyyymmdd}.md`의 #{N} 행이 `완료` + 시각 기록되어 있는지 재확인
8. 결과 보고: 정리된 항목 목록을 작업지시자에게 짧게 회신

## 검증

- `gh pr view {번호}` `state == MERGED` 확인
- `git branch -vv | grep local/task{N}` 출력 없음 (삭제된 경우)
- `git ls-remote origin publish/task{N}` 빈 출력 (원격 삭제 확인)
- `git worktree list` 출력에 정리 대상 worktree 미존재
- `git branch --show-current`가 대상 PR의 `baseRefName`

## 절대 하지 말 것

- PR이 merged 상태가 아닌데 이슈 close
- 작업지시자 다른 task 브랜치(`local/task{다른번호}`)나 메인 worktree 삭제
- `git branch -D` 강제 삭제 무단 사용 (병합 안 된 커밋이 있을 때 손실 위험)
- 다른 작업자의 stash 삭제

## 호출 방법

- Codex: `$pr-merge-cleanup` 또는 `/skills` 메뉴
- Claude Code: `/pr-merge-cleanup`
