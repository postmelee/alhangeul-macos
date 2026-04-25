# Issue #52 구현 계획서

## 작업명

기존 PR 문서 링크를 merge 후 조회 가능한 고정 URL로 보정

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_52.md`를 기준으로 진행한다.
- 이미 merge된 PR 본문을 수정하는 작업이므로, 각 PR 본문은 수정 전 내용을 먼저 조회하고 변경 대상 링크만 좁게 보정한다.
- 문서 링크는 `https://github.com/postmelee/alhangeul-macos/blob/{sha}/mydocs/...` 형식의 commit SHA 고정 URL로 작성한다.
- 기준 SHA는 문서가 실제로 존재하는 PR head SHA 또는 merge commit SHA 중 하나로 결정하고, 결정 근거를 단계 보고서에 기록한다.
- PR 제목, 일반 설명, 이슈 링크, PR 링크, 라벨, 마일스톤은 수정하지 않는다.
- Task #49에서 처리한 향후 PR 작성 정책은 이번 범위에서 다시 수정하지 않는다.

## Stage 1: 대상 PR 링크 조사

대상:

- PR #46 본문
- PR #50 본문
- 최근 merge PR 중 `publish/task` 또는 `mydocs/` 상대 링크가 포함된 PR 본문

작업:

- PR #46, PR #50의 본문, head SHA, merge commit SHA를 조회한다.
- 본문에 포함된 문서 링크를 추출하고, 다음 유형으로 분류한다.
  - `blob/publish/taskN/...` 링크
  - `mydocs/...` 상대 링크
  - 이미 commit SHA 고정 URL인 링크
  - 보정 대상이 아닌 이슈/PR/외부 링크
- 동일 유형이 반복되는 기존 PR이 있는지 제한적으로 검색한다.
- 각 후보 링크의 현재 접근 가능성과 보정 필요 여부를 정리한다.

산출물:

- `mydocs/working/task_m010_52_stage1.md`

검증:

```bash
gh pr view 46 --json number,title,state,body,headRefOid,mergeCommit,url
gh pr view 50 --json number,title,state,body,headRefOid,mergeCommit,url
gh pr list --state merged --limit 30 --json number,title,url,body,headRefOid,mergeCommit
git diff --check -- mydocs/working/task_m010_52_stage1.md
```

완료 조건:

- PR #46, PR #50의 문서 링크 보정 필요 여부가 표로 정리되어 있다.
- 추가 조사 대상 PR이 있으면 번호와 사유가 기록되어 있다.
- Stage 2에서 확정할 링크별 기준 SHA 후보가 준비되어 있다.

## Stage 2: 링크 기준 SHA 결정과 보정안 작성

대상:

- Stage 1에서 보정 대상으로 분류한 PR 본문 링크
- 해당 링크가 가리키는 `mydocs/` 문서 경로

작업:

- 각 문서 경로가 PR head SHA와 merge commit SHA에 존재하는지 확인한다.
- PR 작업 산출물을 가장 정확히 보여주는 SHA를 링크별 기준으로 선택한다.
- 수정 전 URL, 수정 후 URL, 기준 SHA, 선택 근거를 표로 작성한다.
- PR 본문 수정 시 사용할 문구와 Markdown 링크 형식을 준비한다.

산출물:

- `mydocs/working/task_m010_52_stage2.md`

검증:

```bash
git cat-file -e {sha}:mydocs/report/task_m010_45_report.md
git cat-file -e {sha}:mydocs/plans/task_m010_47.md
git diff --check -- mydocs/working/task_m010_52_stage2.md
```

완료 조건:

- 모든 보정 대상 링크의 수정 후 URL이 commit SHA 고정 blob URL로 확정되어 있다.
- 링크별 기준 SHA와 선택 근거가 기록되어 있다.
- PR 본문 수정 전 작업지시자가 검토할 수 있는 보정안이 완성되어 있다.

## Stage 3: PR 본문 보정과 접근 검증

대상:

- PR #46 본문
- PR #50 본문
- Stage 1~2에서 추가 보정 대상으로 승인된 PR 본문

작업:

- 수정 직전 PR 본문을 다시 조회해 Stage 2 보정안과 충돌이 없는지 확인한다.
- 승인된 보정안에 따라 문서 링크만 commit SHA 고정 blob URL로 교체한다.
- PR 본문 수정 후 다시 조회해 `blob/publish/taskN/` 문서 링크와 불편한 `mydocs/` 상대 링크가 남아 있지 않은지 확인한다.
- 주요 고정 URL이 404가 아닌지 확인한다.

산출물:

- `mydocs/working/task_m010_52_stage3.md`

검증:

```bash
gh pr view 46 --json body
gh pr view 50 --json body
rg -n "blob/publish/task|\\]\\(mydocs/" mydocs/working/task_m010_52_stage3.md
git diff --check -- mydocs/working/task_m010_52_stage3.md
```

완료 조건:

- 승인된 PR 본문 링크 보정이 GitHub 원격에 반영되어 있다.
- 보정 후 본문 조회 결과와 접근 검증 결과가 단계 보고서에 기록되어 있다.
- 변경하지 않은 링크와 변경한 링크가 구분되어 있다.

## Stage 4: 기록 정리와 최종 보고

대상:

- `mydocs/orders/20260426.md`
- `mydocs/report/task_m010_52_report.md`
- 전체 단계 보고서

작업:

- 수정 대상 PR 목록, 수정 전후 링크, 기준 SHA, 검증 결과를 최종 보고서로 정리한다.
- 오늘할일 상태를 완료로 갱신한다.
- 작업 브랜치의 문서 변경 상태와 GitHub PR 본문 보정 결과를 함께 점검한다.

산출물:

- `mydocs/report/task_m010_52_report.md`

검증:

```bash
git diff --check
git status --short
gh pr view 46 --json body
gh pr view 50 --json body
```

완료 조건:

- 최종 보고서에 보정된 PR, 기준 SHA, 검증 결과가 기록되어 있다.
- 오늘할일이 완료 상태로 갱신되어 있다.
- 작업 브랜치에 커밋되지 않은 변경이 없다.

## 승인 요청 사항

본 구현계획서 기준으로 Stage 1 대상 PR 링크 조사 진행을 승인 요청한다.
