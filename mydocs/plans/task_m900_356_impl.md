# Task M900 #356 구현계획서

## 개요

이 구현계획서는 릴리즈 노트를 PR/Issue/최종 보고서 분석 기반으로 작성하도록 release 매뉴얼과 자동화를 보강하는 작업을 5단계로 나눈다.

핵심 방향은 `previous_release_ref..candidate_ref` 범위에서 포함 PR을 먼저 분석하고, 그 결과를 `mydocs/release/v<version>.md`의 장기 기록과 GitHub Release/Pages 사용자 문구의 원천으로 삼는 것이다. 기존 path 기반 delta checklist는 계속 유지하되, 누락 확인과 smoke 영역 점검용 보조 자료로만 둔다.

각 단계는 하이퍼-워터폴 승인 gate를 가진다. GitHub Release 게시, Pages/Sparkle 배포, Homebrew Cask 반영, 기존 public release body 직접 수정은 이 구현계획의 실행 범위가 아니다.

## Stage 1: 현행 Release Note 경로와 요구사항 분석

### 목표

현재 release note generator, template checker, release workflow, release 매뉴얼이 어떤 입력을 사용하고 무엇을 검증하지 않는지 정리한다. `v0.1.5` 사례를 기준으로 포함 PR 분석 표에 필요한 column과 자동화 한계를 확정한다.

### 변경 파일

- `mydocs/plans/task_m900_356_impl.md`
- `mydocs/working/task_m900_356_stage1.md`

### 작업

1. `scripts/ci/write-release-notes.sh`, `scripts/ci/check-release-notes-template.sh`, `scripts/ci/write-release-delta-checklist.sh`의 현재 역할을 정리한다.
2. `Release Rehearsal DMG`, `Release Publish DMG`, PR CI release helper check가 release note 관련 산출물을 어떻게 검증하는지 확인한다.
3. release 매뉴얼에서 `포함 PR 분석`, 해결된 Issue, 관련 Issue, 사용자-facing 분류가 아직 표준화되어 있지 않은 지점을 정리한다.
4. `v0.1.4..v0.1.5` 범위의 merge PR 목록과 대표 PR body를 확인해 실제 분류와 resolved/reference 구분에 필요한 column을 설계한다.

### 검증

```bash
git status --short --branch
git log --oneline --merges v0.1.4..v0.1.5
git log --first-parent --oneline --merges v0.1.4..v0.1.5
gh pr view 324 --repo postmelee/alhangeul-macos --json number,title,state,mergedAt,mergeCommit,body,files,url
gh pr view 326 --repo postmelee/alhangeul-macos --json number,title,state,mergedAt,mergeCommit,body,files,url
gh pr view 329 --repo postmelee/alhangeul-macos --json number,title,state,mergedAt,mergeCommit,body,files,url
gh pr view 334 --repo postmelee/alhangeul-macos --json number,title,state,mergedAt,mergeCommit,body,files,url
gh pr view 349 --repo postmelee/alhangeul-macos --json number,title,state,mergedAt,mergeCommit,body,files,url
gh pr view 352 --repo postmelee/alhangeul-macos --json number,title,state,mergedAt,mergeCommit,body,files,url
gh pr view 353 --repo postmelee/alhangeul-macos --json number,title,state,mergedAt,mergeCommit,body,files,url
scripts/validate-github-body.sh mydocs/plans/task_m900_356_impl.md mydocs/working/task_m900_356_stage1.md
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_356_stage1.md`
- 단계 커밋: `Task #356 Stage 1: release note 경로 분석`

### 승인 요청

Stage 1 완료보고서 기준으로 Stage 2 진행 승인을 요청한다.

## Stage 2: Release Record와 매뉴얼 표준 구조 보강

### 목표

릴리즈 기록과 release 매뉴얼에 `포함 PR 분석` 표와 분류/해결 기준을 고정한다.

### 변경 파일

- `mydocs/manual/release_github_pages_sparkle_guide.md`
- `mydocs/manual/public_release_runbook.md`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/manual/ci_workflow_guide.md`
- 필요 시 `mydocs/manual/document_structure_guide.md`
- `mydocs/working/task_m900_356_stage2.md`

### 작업

1. `mydocs/release/v<version>.md` 표준 구조에 `포함 PR 분석` 표를 추가한다.
2. 표준 column을 `PR`, `제목`, `분류`, `사용자-facing`, `공개 요약 반영`, `해결된 Issue`, `관련 Issue`, `근거 문서`, `비고` 기준으로 정리한다.
3. 분류 기준을 `사용자-facing`, `개발자-facing`, `운영/배포`, `문서-only`, `upstream sync`로 정의한다.
4. `변경 요약`과 `알한글 앱 변화`는 사용자-facing으로 판정된 항목만 기준으로 작성하도록 명시한다.
5. 해결된 Issue는 PR body closing keyword 또는 release record에서 완료 확정된 항목만 사용하고, 단순 참고 항목은 관련 Issue로 분리한다.
6. path 기반 delta checklist는 누락 확인용 보조 자료라는 위치를 매뉴얼에 반영한다.

### 검증

```bash
rg -n "포함 PR 분석|사용자-facing|개발자-facing|운영/배포|문서-only|upstream sync|해결된 Issue|관련 Issue|delta checklist" mydocs/manual
scripts/validate-github-body.sh mydocs/manual/release_github_pages_sparkle_guide.md mydocs/manual/public_release_runbook.md mydocs/manual/release_distribution_guide.md mydocs/manual/ci_workflow_guide.md
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_356_stage2.md`
- 단계 커밋: `Task #356 Stage 2: release PR 분석 규칙 문서화`

### 승인 요청

Stage 2 완료보고서 기준으로 Stage 3 진행 승인을 요청한다.

## Stage 3: 포함 PR 분석 Helper 추가

### 목표

`previous_release_ref..candidate_ref` 범위의 merge PR 목록과 기본 분석 표 초안을 생성하는 helper를 추가한다. helper는 release owner의 수동 판단을 대체하지 않고, PR title/body, closing keyword, candidate report path, changed file summary를 한곳에 모으는 초안 생성기로 둔다.

### 변경 파일

- 신규 helper: `scripts/ci/write-release-pr-analysis.sh`
- 필요 시 보조 parser 또는 shell 함수
- `mydocs/working/task_m900_356_stage3.md`

### 작업

1. 입력 형식은 `scripts/ci/write-release-pr-analysis.sh <previous-release-ref> <candidate-ref> <output-file>`로 둔다.
2. `git log --merges`에서 merge PR 번호를 수집하고, first-parent release transport PR과 포함 작업 PR을 구분할 수 있게 기록한다.
3. `gh pr view`를 사용할 수 있으면 PR title/body/files/merge commit을 보강하고, 사용할 수 없으면 git subject와 변경 파일 기반 초안을 남긴다.
4. closing keyword로 해결된 Issue 후보를 추출하되, `Refs`, `Related`, `대상 타스크`, `관련 이슈`는 관련 Issue 후보로 분리한다.
5. 내부 작업 보고서는 `mydocs/report/task_*_<issue>_report.md` 패턴으로 후보를 찾고, 없으면 수동 확인 필요로 표시한다.
6. 분류와 사용자-facing 여부는 자동 단정하지 않고, path/title 기반 hint와 `확인 필요` 기본값을 남긴다.

### 검증

```bash
bash -n scripts/ci/write-release-pr-analysis.sh
scripts/ci/write-release-pr-analysis.sh v0.1.4 v0.1.5 build.noindex/release/pr-analysis-0.1.5.md
rg -n "포함 PR 분석|확인 필요|해결된 Issue|관련 Issue|#324|#326|#329|#334|#349|#352|#353" build.noindex/release/pr-analysis-0.1.5.md
scripts/validate-github-body.sh build.noindex/release/pr-analysis-0.1.5.md
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_356_stage3.md`
- 단계 커밋: `Task #356 Stage 3: release PR 분석 helper 추가`

### 승인 요청

Stage 3 완료보고서 기준으로 Stage 4 진행 승인을 요청한다.

## Stage 4: Release Note Generator와 CI/Workflow 연결

### 목표

release detail doc의 포함 PR 분석 결과가 GitHub Release body와 검증기에 반영되도록 generator/checker를 보강하고, release helper dry-run과 workflow summary/artifact 경로에 새 분석 helper를 연결한다.

### 변경 파일

- `scripts/ci/write-release-notes.sh`
- `scripts/ci/check-release-notes-template.sh`
- `.github/workflows/pr-ci.yml`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- 필요 시 `mydocs/release/v0.1.5.md`
- `mydocs/working/task_m900_356_stage4.md`

### 작업

1. `write-release-notes.sh`가 `mydocs/release/v<version>.md`에서 GitHub Release용 `직접 반영된 PR과 Issue` section 후보를 읽거나 생성하도록 보강한다.
2. GitHub Release body의 필수 heading에 직접 반영된 PR, 해결된 Issue, 관련 Issue 구분을 추가한다.
3. `check-release-notes-template.sh`가 `포함 PR 분석` 또는 GitHub Release용 PR/Issue section 누락을 검출하게 한다.
4. release helper dry-run에서 `scripts/validate-github-body.sh`를 release notes output에 적용한다.
5. rehearsal/publish workflow에 PR 분석 helper summary/artifact를 추가하되, publish blocking 여부는 잘못된 ref나 helper 실패처럼 기계적으로 명확한 경우로 제한한다.
6. PR CI release helper sample version/ref가 현재 release doc 요구사항과 충돌하지 않게 갱신한다.

### 검증

```bash
bash -n scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh scripts/ci/write-release-pr-analysis.sh
scripts/ci/write-release-pr-analysis.sh v0.1.4 v0.1.5 build.noindex/release/pr-analysis-0.1.5.md
scripts/ci/write-release-notes.sh 0.1.5 d347c13b80aeaa006776db7ae2b00f8a2d11836c94757165f4bb87a331dd585b build.noindex/release/release-notes-0.1.5.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.5.md
scripts/validate-github-body.sh build.noindex/release/release-notes-0.1.5.md build.noindex/release/pr-analysis-0.1.5.md
scripts/ci/write-release-delta-checklist.sh v0.1.4 HEAD build.noindex/release/delta-checklist-0.1.5.md
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_356_stage4.md`
- 단계 커밋: `Task #356 Stage 4: release note PR 분석 자동화 연결`

### 승인 요청

Stage 4 완료보고서 기준으로 Stage 5 진행 승인을 요청한다.

## Stage 5: 통합 검증과 최종 보고 준비

### 목표

문서, helper, release note generator/checker, workflow 연결이 한 흐름으로 동작하는지 확인하고 최종 결과 보고와 PR 게시 준비를 마친다.

### 변경 파일

- `mydocs/release/v0.1.5.md` 또는 release 표준 예시 보강이 필요한 문서
- `mydocs/orders/20260607.md`
- `mydocs/report/task_m900_356_report.md`
- `mydocs/working/task_m900_356_stage5.md`

### 작업

1. Stage 2~4 산출물의 문서/자동화 흐름을 `v0.1.4..v0.1.5` 사례로 end-to-end 검증한다.
2. GitHub 공개 body로 쓰일 수 있는 generated notes와 PR body 초안은 모두 `scripts/validate-github-body.sh`를 통과시킨다.
3. 최종 보고서에 변경 요약, 검증 결과, release owner가 수동 판단해야 하는 영역을 기록한다.
4. 오늘할일을 완료 처리하고 PR body 초안을 body file로 작성할 준비를 한다.

### 검증

```bash
git status --short --branch
bash -n scripts/ci/write-release-pr-analysis.sh scripts/ci/write-release-notes.sh scripts/ci/check-release-notes-template.sh scripts/ci/write-release-delta-checklist.sh
scripts/ci/write-release-pr-analysis.sh v0.1.4 v0.1.5 build.noindex/release/pr-analysis-0.1.5.md
scripts/ci/write-release-notes.sh 0.1.5 d347c13b80aeaa006776db7ae2b00f8a2d11836c94757165f4bb87a331dd585b build.noindex/release/release-notes-0.1.5.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.5.md
scripts/validate-github-body.sh build.noindex/release/release-notes-0.1.5.md build.noindex/release/pr-analysis-0.1.5.md
rg -n "포함 PR 분석|직접 반영된 PR|해결된 Issue|관련 Issue|사용자-facing|delta checklist" mydocs scripts .github/workflows
git diff --check
```

### 단계 산출물

- `mydocs/working/task_m900_356_stage5.md`
- `mydocs/report/task_m900_356_report.md`
- 단계 커밋: `Task #356 Stage 5 + 최종 보고서: release PR 분석 자동화 검증 완료`

### 승인 요청

Stage 5 완료보고서와 최종 결과보고서 기준으로 PR 게시 승인을 요청한다.
