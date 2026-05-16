# Task M013 #244 Stage 2 보고서

## 단계 목적

Stage 1 inventory 결과를 바탕으로 `devel` 승격 전환 정책과 원격 브랜치 migration runbook을 확정했다.

이번 단계는 문서화만 수행했고, 원격 브랜치 생성, 원격 브랜치 삭제, `devel` force update, branch protection/default branch 설정 변경은 수행하지 않았다.

## 확정한 전환 정책

| 항목 | 결정 |
|------|------|
| 제품 개발 기본 브랜치 | `devel` |
| 기존 `devel` 보존 브랜치 | `native-viewer-editor` |
| 새 `devel` 기준 | `origin/devel-webview`를 first parent로 두고 `origin/main` 전용 release 후속 변경을 merge한 commit |
| 기존 `devel` native commit 처리 | 새 제품 `devel`에 직접 merge하지 않고 `native-viewer-editor`로 보존 |
| `devel-webview` 처리 | 전환 직후 삭제하지 않고 legacy alias로 유지 |
| 원격 전환 실행 | Stage 5에서 작업지시자가 별도 명시 승인한 뒤에만 수행 |

## native 보존 브랜치 이름

기존 `devel`은 Swift native viewer renderer뿐 아니라 native editor foundation까지 장기적으로 포함하는 라인이다. 따라서 보존 브랜치 이름은 `native-viewer-editor`로 선택했다.

원격 후보 확인 결과 `native-viewer`, `native-viewer-editor`, `native-devel`, `experiment/native`는 현재 존재하지 않았다.

## PR #131 / Issue #130 gate

Stage 1에서 기존 `devel` base open PR로 확인한 [PR #131](https://github.com/postmelee/alhangeul-macos/pull/131)은 작업지시자 결정에 따라 구현하지 않기로 했다.

현재 상태:

| 항목 | 상태 |
|------|------|
| PR #131 | `CLOSED` |
| Issue #130 | `CLOSED`, `NOT_PLANNED` |

따라서 Stage 2 runbook의 `origin/devel` open PR gate에서 #131은 해소된 항목으로 기록했다. 전환 실행 직전에는 새 open PR이 생겼는지 다시 확인해야 한다.

## 제품 `devel` commit 생성 원칙

새 제품 `devel`은 단순히 `origin/devel-webview`를 복사하지 않는다. `origin/main`에는 v0.1.2 public release 이후 README, release record, Pages 관련 변경이 있기 때문이다.

선택한 방식:

```bash
git checkout -B task244/product-devel-candidate origin/devel-webview
git merge --no-ff origin/main -m "Merge main release records into devel product line"
```

이 방식은 다음 장점이 있다.

- 제품 개발 first-parent 흐름을 기존 `devel-webview` 기준으로 유지한다.
- `main`의 release 후속 문서/배포 기록을 잃지 않는다.
- 후보 commit이 `origin/devel-webview` descendant가 되므로 legacy `devel-webview`를 fast-forward로 맞출 수 있다.
- 기존 `origin/devel` native 라인과 충돌하는 renderer/project 설정을 제품 라인에 섞지 않는다.

## 원격 전환 runbook

`mydocs/tech/branch_strategy_webview_native.md`에 다음 내용을 추가했다.

- 전환 후 브랜치 역할
- `native-viewer-editor` 이름 선택 사유
- 제품 `devel` 기준 commit 원칙
- 원격 전환 runbook
- 전환 전 gate
- 전환 후 PR base 기준

핵심 실행 순서는 다음이다.

1. 최신 원격 상태와 열린 PR을 확인한다.
2. 기존 `origin/devel` head를 `origin/native-viewer-editor`로 push해 보존한다.
3. `origin/devel-webview`에서 시작해 `origin/main`을 merge한 제품 후보 commit을 만든다.
4. `origin/devel-webview`를 제품 후보로 fast-forward해 legacy alias로 유지한다.
5. `origin/devel`은 `--force-with-lease`로 제품 후보 commit을 가리키게 교체한다.
6. branch protection/default branch 설정은 GitHub repository setting에서 수동 확인한다.

## 보류한 결정

| 항목 | 보류 사유 |
|------|-----------|
| GitHub default branch를 `devel`로 바꿀지 여부 | 외부 기여 base 오입력 감소에는 도움이 되지만, release/tag 기준 `main`, GitHub Pages, repository home 운영 영향을 함께 봐야 하므로 Stage 5 수동 설정 항목으로 남겼다. |
| `devel-webview` 삭제 시점 | 기존 링크와 자동화 호환성을 위해 최소 한 전환 주기 동안 legacy alias로 유지한다. 삭제는 별도 승인으로 판단한다. |
| `publish/task178` 삭제 | 열린 PR에는 연결되지 않았지만 이번 Stage 2의 원격 branch migration 범위는 아니다. cleanup은 별도 승인으로 처리한다. |

## 변경 파일

| 파일 | 변경 |
|------|------|
| `mydocs/tech/branch_strategy_webview_native.md` | Task #244 전환 정책, runbook, gate, 전환 후 PR base 기준 추가 |
| `mydocs/working/task_m013_244_stage2.md` | Stage 2 보고서 추가 |

## 검증 결과

| 검증 | 결과 |
|------|------|
| `git status --short --branch` | #244 worktree에서만 변경 진행 |
| `gh pr view 131` | `CLOSED` 확인 |
| `gh issue view 130` | `CLOSED`, `NOT_PLANNED` 확인 |
| `git ls-remote --heads origin native-viewer native-viewer-editor native-devel experiment/native` | 후보 원격 브랜치 없음 확인 |
| `git diff --check` | 통과 |
| `rg -n "native-viewer|legacy|devel-webview|branch migration|브랜치 전환|default branch|branch protection" mydocs/tech mydocs/manual` | 변경 내용 확인 |

## 다음 단계 제안

Stage 3에서는 README, CONTRIBUTING, AGENTS, workflow/manual/architecture 문서의 branch 역할과 PR base 안내를 새 정책에 맞게 정렬한다. Stage 3에서도 원격 브랜치 변경은 수행하지 않는다.

## 승인 요청

Stage 2 전환 정책과 runbook 정리를 완료했다. 이 보고서 기준으로 Stage 3 기여자/에이전트 문서 정렬을 진행해도 되는지 승인 요청한다.
