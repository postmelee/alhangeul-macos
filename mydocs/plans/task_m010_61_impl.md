# Issue #61 구현 계획서

수행계획서: `mydocs/plans/task_m010_61.md`

## 작업명

PR 문서 링크 전수 보정과 작성 규격 강화

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_61.md`를 기준으로 진행한다.
- 이미 merge된 PR 본문을 수정하는 작업은 원격 상태 변경이므로, 수정 전 본문을 조회하고 변경 대상 문서 링크만 좁게 보정한다.
- 문서 링크는 `https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/...` 형식의 commit SHA 고정 URL을 사용한다.
- PR 본문 문서 섹션의 표시 텍스트는 raw URL이 아니라 `[파일명](URL)` 형식을 사용한다.
- 기준 SHA는 원칙적으로 해당 PR의 head commit SHA를 사용한다. 문서가 head SHA에 없고 merge commit에만 있는 예외가 확인되면 merge commit SHA를 사용하고 근거를 기록한다.
- PR 제목, label, milestone, review 상태, 일반 이슈 링크는 수정하지 않는다.
- PR 본문 수정 결과는 로컬 diff에 남지 않으므로 단계 보고서에 수정 전후, 기준 SHA, 검증 결과를 기록한다.
- 앱 코드, RustBridge, Xcode project, build script는 변경하지 않는다.
- 문서/운영 규격 변경이므로 Xcode/Rust 빌드는 수행하지 않는다.

## Stage 1: merged PR 문서 링크 전수 조사

대상:

- 최근 merged PR 전체 (`gh pr list --state merged --limit 100`)
- PR 본문 중 `github.com/postmelee/alhangeul-macos/blob/{40자 SHA}/mydocs/...` 링크
- PR 본문 문서 섹션의 raw URL 노출
- `mydocs/...` 상대 링크 또는 비클릭 경로가 남아 있는 문서 섹션

작업:

1. PR #59, #60 본문, head SHA, merge commit SHA를 재조회한다.
2. 최근 merged PR 100건의 본문에서 저장소 내부 `mydocs/` 문서 링크를 추출한다.
3. 링크를 다음 유형으로 분류한다.
   - 존재하지 않는 40자 SHA를 사용하는 링크
   - commit은 존재하지만 문서 파일 접근이 실패하는 링크
   - commit SHA 고정 URL이지만 raw URL이 그대로 표시되는 문서 섹션 링크
   - `mydocs/...` 상대 링크 또는 비클릭 경로
   - 검증 명령, 변경 내역 설명 등 의도적으로 보정하지 않을 파일 경로
4. commit 존재 여부를 확인한다.
5. 문서 파일 접근 가능성은 로컬 git object 확인과 GitHub API/URL 조회 결과를 분리해 기록한다.
6. Stage 1 단계 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_61_stage1.md`

검증:

```bash
gh pr view 59 --repo postmelee/alhangeul-macos --json number,title,body,commits,mergeCommit,url
gh pr view 60 --repo postmelee/alhangeul-macos --json number,title,body,commits,mergeCommit,url
gh pr list --repo postmelee/alhangeul-macos --state merged --limit 100 --json number,title,url,body,mergeCommit
gh pr list --repo postmelee/alhangeul-macos --state merged --limit 100 --json body --jq '.[] | .body | scan("https://github\\.com/postmelee/alhangeul-macos/blob/([0-9a-f]{40})/[^\\s)]+") | .[0]' | sort -u
git diff --check -- mydocs/working/task_m010_61_stage1.md
```

완료 조건:

- 보정 대상 PR과 제외 대상 PR이 표로 정리되어 있다.
- PR #59의 깨진 SHA와 PR #60의 raw URL 표시 문제가 재확인되어 있다.
- Stage 2에서 사용할 기준 SHA 후보가 PR별로 정리되어 있다.

커밋:

```text
Task #61 Stage 1: PR 문서 링크 전수 조사
```

## Stage 2: 기준 SHA와 PR 본문 보정안 확정

대상:

- Stage 1에서 보정 대상으로 분류한 PR 본문 링크
- 각 링크가 가리키는 `mydocs/` 문서 경로

작업:

1. 각 보정 대상 PR의 head commit SHA와 merge commit SHA를 확정한다.
2. 각 문서 경로가 기준 SHA에서 조회 가능한지 확인한다.
3. 접근 실패 링크는 올바른 기준 SHA와 경로를 확정한다.
4. raw URL 표시 링크는 동일 URL을 유지하되 표시 텍스트를 파일명 또는 짧은 stage label로 바꾸는 Markdown 본문을 작성한다.
5. 수정 전 URL, 수정 후 Markdown, 기준 SHA, 선택 근거를 표로 작성한다.
6. 기계적 치환 대상과 수동 확인 대상 문단을 구분한다.
7. Stage 2 단계 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_61_stage2.md`

검증:

```bash
git cat-file -e {sha}^{commit}
git cat-file -e {sha}:mydocs/...
gh api repos/postmelee/alhangeul-macos/commits/{sha} --jq '.sha'
gh api repos/postmelee/alhangeul-macos/contents/{path}?ref={sha} --jq '.path'
git diff --check -- mydocs/working/task_m010_61_stage2.md
```

완료 조건:

- 모든 보정 대상 링크의 수정 후 Markdown이 확정되어 있다.
- PR #59 링크는 실제 commit SHA 기준으로 교체안이 확정되어 있다.
- PR #60 문서 섹션은 `[파일명](URL)` 형식 교체안이 확정되어 있다.
- 작업지시자가 Stage 3에서 원격 PR 본문 수정 범위를 검토할 수 있다.

커밋:

```text
Task #61 Stage 2: PR 문서 링크 보정안 확정
```

## Stage 3: PR 본문 원격 보정과 접근 검증

대상:

- Stage 2에서 승인된 PR 본문
- 우선 대상: PR #59, PR #60
- 추가 대상: Stage 1~2에서 같은 유형으로 확인되고 승인된 merged PR

작업:

1. 수정 직전 각 PR 본문을 다시 조회해 Stage 2 보정안 작성 이후 변경이 없는지 확인한다.
2. 각 PR 본문을 임시 파일로 저장한다.
3. 승인된 범위의 문서 링크만 보정한다.
4. `gh pr edit {N} --body-file {file}`로 PR 본문을 갱신한다.
5. 수정 후 PR 본문을 재조회한다.
6. 존재하지 않는 40자 SHA, raw URL 문서 표시, 상대 문서 링크가 남아 있는지 검증한다.
7. 주요 링크의 GitHub API 접근 또는 URL 접근을 확인한다.
8. Stage 3 단계 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_61_stage3.md`
- GitHub 원격 PR 본문 수정

검증:

```bash
gh pr view 59 --repo postmelee/alhangeul-macos --json body
gh pr view 60 --repo postmelee/alhangeul-macos --json body
gh pr list --repo postmelee/alhangeul-macos --state merged --limit 100 --json number,title,body
gh api repos/postmelee/alhangeul-macos/commits/{sha} --jq '.sha'
gh api repos/postmelee/alhangeul-macos/contents/{path}?ref={sha} --jq '.path'
git diff --check -- mydocs/working/task_m010_61_stage3.md
```

완료 조건:

- 승인된 PR 본문 보정이 GitHub 원격에 반영되어 있다.
- PR #59 문서 링크가 클릭 가능한 실제 commit SHA로 교체되어 있다.
- PR #60 문서 섹션이 raw URL 표시 대신 `[파일명](URL)` 형식이다.
- 보정하지 않은 항목과 그 이유가 Stage 3 보고서에 기록되어 있다.

커밋:

```text
Task #61 Stage 3: PR 본문 문서 링크 보정
```

## Stage 4: PR 링크 작성 규격 보강

대상:

- `.github/pull_request_template.md`
- `mydocs/skills/task-final-report/SKILL.md`
- `mydocs/manual/git_workflow_guide.md`
- 필요 시 `mydocs/manual/pr_process_guide.md`

작업:

1. PR 템플릿의 `문서` 섹션에 짧은 Markdown 링크 예시를 추가한다.
2. PR 템플릿 주석에 문서 링크 기준을 추가한다.
   - PR head SHA 기준 고정 blob URL
   - `[파일명](URL)` 표시
   - 해당 없는 항목 삭제
3. `task-final-report` SKILL에 PR 본문 작성 전 `git rev-parse HEAD`로 head SHA를 확인하는 절차를 추가한다.
4. `task-final-report` SKILL에 문서 링크 작성 형식과 PR 본문 조회 검증을 추가한다.
5. `git_workflow_guide.md`의 기존 PR 문서 링크 정책에 표시 텍스트 규칙을 보강한다.
6. `pr_process_guide.md`에 중복되는 규칙이 필요하면 짧게 연결하고, 불필요하면 수정하지 않는다.
7. Stage 4 단계 보고서를 작성한다.

산출물:

- `.github/pull_request_template.md`
- `mydocs/skills/task-final-report/SKILL.md`
- `mydocs/manual/git_workflow_guide.md`
- 필요 시 `mydocs/manual/pr_process_guide.md`
- `mydocs/working/task_m010_61_stage4.md`

검증:

```bash
rg -n "문서 링크|파일명|git rev-parse HEAD|blob/\\{sha\\}|raw URL|task-final-report" \
  .github/pull_request_template.md \
  mydocs/skills/task-final-report/SKILL.md \
  mydocs/manual/git_workflow_guide.md \
  mydocs/manual/pr_process_guide.md
git diff --check -- \
  .github/pull_request_template.md \
  mydocs/skills/task-final-report/SKILL.md \
  mydocs/manual/git_workflow_guide.md \
  mydocs/manual/pr_process_guide.md \
  mydocs/working/task_m010_61_stage4.md
```

완료 조건:

- 새 PR 작성자가 문서 섹션에서 `[파일명](고정 URL)` 형식을 바로 따라 쓸 수 있다.
- `task-final-report` 절차가 head SHA, 문서 링크 형식, PR 본문 검증을 포함한다.
- 기존 매뉴얼의 commit SHA 고정 URL 정책과 새 표시 형식 규칙이 충돌하지 않는다.

커밋:

```text
Task #61 Stage 4: PR 문서 링크 작성 규격 보강
```

## Stage 5: 통합 검증과 최종 보고

대상:

- 전체 변경 파일
- 원격 PR 본문 보정 결과
- `mydocs/orders/20260426.md`
- `mydocs/report/task_m010_61_report.md`

작업:

1. 전체 diff whitespace 검증을 실행한다.
2. PR #59, #60 및 추가 보정 PR 본문을 재조회한다.
3. merged PR 본문 전수 스캔으로 깨진 SHA와 raw URL 문서 표시 잔존 여부를 확인한다.
4. 규격 보강 문서에서 핵심 문구를 검색한다.
5. 오늘할일 상태를 완료로 갱신하고 완료 시각을 기록한다.
6. 최종 결과 보고서를 작성한다.
7. Stage 5 단계 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_61_stage5.md`
- `mydocs/report/task_m010_61_report.md`
- `mydocs/orders/20260426.md`

검증:

```bash
git diff --check
gh pr view 59 --repo postmelee/alhangeul-macos --json body
gh pr view 60 --repo postmelee/alhangeul-macos --json body
gh pr list --repo postmelee/alhangeul-macos --state merged --limit 100 --json number,title,body
rg -n "문서 링크|파일명|git rev-parse HEAD|blob/\\{sha\\}|raw URL" \
  .github/pull_request_template.md \
  mydocs/skills/task-final-report/SKILL.md \
  mydocs/manual/git_workflow_guide.md
git status --short
```

완료 조건:

- 최종 보고서에 보정 대상 PR, 기준 SHA, 수정 결과, 검증 결과가 기록되어 있다.
- 오늘할일이 완료 상태로 갱신되어 있다.
- 작업 브랜치에 커밋되지 않은 변경이 없다.
- PR 게시 승인 요청이 가능하다.

커밋:

```text
Task #61 Stage 5 + 최종 보고서: PR 문서 링크 보정과 규격화 결과 정리
```

## 단계별 커밋 메시지

| Stage | 커밋 메시지 |
|-------|-------------|
| 1 | `Task #61 Stage 1: PR 문서 링크 전수 조사` |
| 2 | `Task #61 Stage 2: PR 문서 링크 보정안 확정` |
| 3 | `Task #61 Stage 3: PR 본문 문서 링크 보정` |
| 4 | `Task #61 Stage 4: PR 문서 링크 작성 규격 보강` |
| 5 | `Task #61 Stage 5 + 최종 보고서: PR 문서 링크 보정과 규격화 결과 정리` |

## 후속 작업

- Stage 5 완료 후 작업지시자 승인 시 `task-final-report` 절차로 `publish/task61` push와 draft PR 생성을 진행한다.
- PR merge 후 정리는 `pr-merge-cleanup` 절차로 수행한다.

## 승인 요청 사항

이 구현 계획서 5단계 구성으로 Stage 1 진입을 승인 요청한다.
