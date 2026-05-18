# Task M019 #204 구현계획서

수행계획서: `mydocs/plans/task_m019_204.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #204 rhwp upstream release 감지와 rhwp-studio 자동 업데이트 PR 생성 파이프라인 추가
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task204`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel`
- 자동 PR base: `devel`
- 선행 상태: `devel-webview`는 퇴역한 legacy alias이며 신규 PR base나 자동화 기준으로 쓰지 않는다.
- 목표: upstream `edwardkim/rhwp` release를 감지하고 viewer/WASM/core 영향 변경이 있을 때 bundled `rhwp-studio` 업데이트 후보 PR을 자동 생성한다.

## 확인된 현재 상태

2026-05-17 기준 로컬 확인 결과:

- `.github/workflows/rhwp-upstream-check.yml`은 `workflow_dispatch`와 schedule로 `scripts/ci/check-rhwp-upstream-release.sh`를 실행한다.
- `scripts/ci/check-rhwp-upstream-release.sh`는 upstream latest release와 `rhwp-core.lock`의 tag/commit을 비교하고, 필요 시 `scripts/update-rhwp-core.sh --check --channel stable --tag <tag>`를 실행한다.
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`은 bundled studio 기준으로 `source_release_tag=v0.7.11`, `source_resolved_commit=a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`를 기록한다.
- `scripts/sync-rhwp-studio.sh`는 upstream checkout path만 위치 인자로 받고, expected tag/commit은 script 내부에 하드코딩되어 있다.
- `scripts/verify-rhwp-studio-assets.sh`도 expected tag/commit을 내부 상수로 검사한다.
- `scripts/ci/classify-pr-changes.sh`는 `Sources/*`, `rhwp-core.lock`, `scripts/sync-rhwp-studio.sh`, `scripts/verify-rhwp-studio-assets.sh` 변경을 macOS/Rust verify 대상으로 분류하지만, bundled `rhwp-studio` asset 변경의 의도와 release helper 검증 연결은 #204 자동 PR 관점에서 더 명시할 여지가 있다.
- `.github/workflows/pr-ci.yml`은 `devel` PR을 대상으로 실행한다. `devel-webview`는 trigger에 없다.

## 구현 원칙

- read-only upstream 감시와 write-capable PR 생성 workflow는 분리한다.
- 자동 PR base는 현재 통합 브랜치 정책에 맞춰 `devel`로 한다.
- 자동화는 public release를 실행하지 않는다. Release publish, signed/notarized DMG, Sparkle stable appcast, Homebrew 작업은 기존 protected manual workflow와 maintainer 승인에 맡긴다.
- repository write 권한은 자동 PR 생성 workflow에만 부여하고, 기존 read-only check workflow는 `contents: read`로 유지한다.
- third-party create-PR action은 추가하지 않고, `gh` CLI와 repository-local script를 우선 사용한다.
- viewer 영향 변경 감지는 `rhwp-studio/**`만 보지 않는다. WASM/core viewer output에 영향을 줄 수 있는 upstream source, `pkg/`, package/Vite/TypeScript build input, fonts/license/provenance 파일을 보수적으로 포함한다.
- 자동 PR 생성 전에는 기존 열린 sync PR 또는 같은 automation branch를 탐색해 중복 PR 생성을 피한다.
- local helper는 GitHub Actions뿐 아니라 maintainer 로컬 dry-run에서도 쓸 수 있도록 `--help`, 명시 인자, summary output을 갖춘다.
- GitHub-hosted runner에서 실제 upstream build와 PR 생성 권한은 로컬에서 완전히 검증할 수 없으므로 단계 보고서와 최종 보고서에 잔여 확인 항목을 남긴다.

## Stage 1. 현황 확인과 자동화 정책 확정

### 목표

현재 upstream check, studio sync, manifest, PR CI 기준을 확인하고 #204에서 적용할 base branch, 권한, workflow 분리 정책을 단계 보고서에 고정한다.

### 작업

- 기존 upstream check workflow와 helper output을 확인한다.
- `rhwp-studio` manifest와 `rhwp-core.lock`의 provenance 항목을 대조한다.
- `devel-webview` 퇴역 정책을 README와 git workflow 문서에서 확인하고 자동 PR base를 `devel`로 확정한다.
- GitHub Actions workflow 권한 모델을 정리한다.
  - read-only check: `contents: read`
  - sync PR workflow: `contents: write`, `pull-requests: write`, 필요 시 `issues: write`
- scheduled workflow와 `workflow_dispatch`는 repository 기본 브랜치와 merge 상태에 따라 실제 활성화 조건이 달라질 수 있음을 잔여 확인 항목으로 기록한다.
- 자동 PR 중복 방지 기준을 확정한다.
  - branch: `automation/rhwp-<tag>-studio-sync`
  - title: `Update bundled rhwp-studio to rhwp <tag>`
  - 같은 head/base 열린 PR이 있으면 새 PR 생성 대신 summary에 existing PR을 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m019_204_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "devel-webview|rhwp-upstream|rhwp-studio|pull-requests|contents: write|workflow_dispatch|schedule" README.md mydocs/manual .github/workflows scripts
jq '.source_release_tag,.source_resolved_commit' Sources/HostApp/Resources/rhwp-studio/manifest.json
bash scripts/ci/check-rhwp-upstream-release.sh --help
git diff --check
```

네트워크 접근이 가능한 경우:

```bash
gh release view -R edwardkim/rhwp --json tagName,url,targetCommitish
```

### 완료 기준

- Stage 1 보고서에 base `devel`, workflow 분리, 권한 경계, 중복 PR 방지 기준이 기록된다.
- Stage 2에서 구현할 helper 경계가 명확하다.

### 커밋 메시지

```text
Task #204 Stage 1: upstream sync PR 자동화 정책 확정
```

## Stage 2. upstream release와 studio impact 감지 helper 추가

### 목표

upstream target release와 현재 bundled studio manifest를 비교하고, target commit까지의 diff가 viewer/WASM/core에 영향을 주는지 판정하는 helper를 추가한다.

### 작업

- 신규 helper 후보 `scripts/ci/detect-rhwp-studio-impact.sh`를 추가한다.
- 입력 인자 후보를 구현한다.
  - `--upstream-dir <path>`
  - `--current-commit <commit>`
  - `--target-commit <commit>`
  - `--current-tag <tag>`
  - `--target-tag <tag>`
  - `--github-output <path>` 또는 `GITHUB_OUTPUT` 자동 사용
- helper는 다음 output 후보를 남긴다.
  - `current_tag`
  - `current_commit`
  - `target_tag`
  - `target_commit`
  - `has_viewer_impact`
  - `changed_paths_file`
  - `impact_paths_file`
  - `impact_reason_count`
- impact path 기준을 script 내부 함수로 분리한다.
  - `rhwp-studio/**`
  - `pkg/rhwp.js`
  - `pkg/rhwp_bg.wasm`
  - `package.json`, `package-lock.json`
  - `Cargo.toml`, `Cargo.lock`, `crates/**`, `src/**`
  - `vite.config.*`, `tsconfig*.json`
  - font/license/provenance 관련 파일
- 영향 없음 상태는 exit 0으로 두고 output만 `has_viewer_impact=false`로 남긴다.
- invalid commit, missing upstream checkout, empty diff 같은 입력 오류는 실패시킨다.
- `scripts/ci/check-rhwp-upstream-release.sh`는 기존 역할을 유지하되, 필요하면 studio manifest 기준 output을 추가하는 방식으로 보강한다.

### 예상 변경 파일

- 신규: `scripts/ci/detect-rhwp-studio-impact.sh`
- 필요 시 `scripts/ci/check-rhwp-upstream-release.sh`
- `mydocs/working/task_m019_204_stage2.md`

### 검증

```bash
git status --short --branch
bash -n scripts/ci/detect-rhwp-studio-impact.sh
scripts/ci/detect-rhwp-studio-impact.sh --help
bash -n scripts/ci/check-rhwp-upstream-release.sh
bash scripts/ci/check-rhwp-upstream-release.sh --help
git diff --check
```

upstream checkout이 있는 경우:

```bash
scripts/ci/detect-rhwp-studio-impact.sh \
  --upstream-dir build.noindex/rhwp-upstream \
  --current-tag v0.7.11 \
  --current-commit a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae \
  --target-tag <target-tag> \
  --target-commit <target-commit>
```

### 완료 기준

- helper가 current/target commit 사이 변경 파일과 viewer 영향 여부를 안정적으로 출력한다.
- 새 release 없음과 viewer 영향 없음은 실패가 아니라 skipped/current 상태로 표현할 수 있다.
- Stage 2 보고서에 impact path 기준과 한계가 기록된다.

### 커밋 메시지

```text
Task #204 Stage 2: rhwp-studio 영향 변경 감지 helper 추가
```

## Stage 3. rhwp-studio sync script 인자화와 검증 보강

### 목표

자동화가 target release tag와 resolved commit을 입력으로 받아 bundled `rhwp-studio` asset 후보를 갱신할 수 있도록 sync/verify script를 개선한다.

### 작업

- `scripts/sync-rhwp-studio.sh`를 option parser 방식으로 변경한다.
- 지원 인자 후보:
  - `--tag <rhwp-release-tag>`
  - `--commit <resolved-commit>`
  - `--upstream-dir <path>`
  - `--target-dir <path>`
  - `--check`
  - `-h|--help`
- 기존 위치 인자 사용은 가능하면 호환 유지하거나, 명확한 오류와 help를 제공한다.
- 입력 commit과 upstream checkout `HEAD`가 일치하는지 확인한다.
- upstream `pkg/rhwp.js`, `pkg/rhwp_bg.wasm`, `rhwp-studio/dist/index.html` 존재를 확인한다.
- `samples/` 제외, local overlay 보존, `crossorigin` 제거, relative base asset path 유지, `manifest.json` 갱신을 기존과 동일하게 유지한다.
- `--check`는 실제 target resource를 수정하지 않고 임시 directory에서 sync와 `verify-rhwp-studio-assets.sh`를 수행하는 dry-run 후보로 구현한다.
- `scripts/verify-rhwp-studio-assets.sh`도 expected tag/commit을 인자로 받을 수 있게 보강한다.
  - `--tag <tag>`
  - `--commit <commit>`
  - `--resource-dir <path>`
  - `-h|--help`
- 기본값은 manifest의 현재 tag/commit을 읽거나 기존 bundled 기준을 사용하도록 설계해 기존 호출 `scripts/verify-rhwp-studio-assets.sh`가 계속 동작하게 한다.

### 예상 변경 파일

- `scripts/sync-rhwp-studio.sh`
- `scripts/verify-rhwp-studio-assets.sh`
- 필요 시 신규 helper: `scripts/ci/read-rhwp-studio-manifest.sh`
- `mydocs/working/task_m019_204_stage3.md`

### 검증

```bash
git status --short --branch
bash -n scripts/sync-rhwp-studio.sh scripts/verify-rhwp-studio-assets.sh
scripts/sync-rhwp-studio.sh --help
scripts/verify-rhwp-studio-assets.sh --help
scripts/verify-rhwp-studio-assets.sh
scripts/ci/classify-pr-changes.sh devel HEAD
git diff --check
```

upstream build artifact가 준비된 경우:

```bash
scripts/sync-rhwp-studio.sh \
  --tag <target-tag> \
  --commit <target-commit> \
  --upstream-dir build.noindex/rhwp-upstream \
  --check
```

### 완료 기준

- sync script가 하드코딩 tag/commit 없이 target release 입력으로 동작할 수 있다.
- verify script가 기존 기본 호출과 자동화용 명시 tag/commit 호출을 모두 지원한다.
- Stage 3 보고서에 호환성 유지 여부와 dry-run 한계가 기록된다.

### 커밋 메시지

```text
Task #204 Stage 3: rhwp-studio sync script 인자화
```

## Stage 4. 자동 PR body helper와 workflow 추가

### 목표

viewer 영향 변경이 있을 때 `devel` 대상 자동 업데이트 PR을 생성하는 write-capable workflow를 추가한다.

### 작업

- 신규 PR body helper 후보 `scripts/ci/write-rhwp-studio-sync-pr-body.sh`를 추가한다.
- PR body에는 다음 항목을 포함한다.
  - upstream release URL
  - previous bundled tag/commit
  - new tag/commit
  - viewer impact result와 주요 변경 path
  - 변경 파일 요약
  - 실행한 검증
  - maintainer 확인 항목
  - public release는 별도 승인과 protected workflow가 필요하다는 문구
  - `@postmelee` mention
- 신규 workflow `.github/workflows/rhwp-upstream-sync-pr.yml`을 추가한다.
- trigger 후보:
  - `workflow_dispatch` with `target_tag`, `force_pr`, `dry_run`
  - `schedule` with 보수적 시간대
- 권한 후보:
  - top-level 또는 job-level `contents: write`
  - `pull-requests: write`
  - assignee 설정이 필요하면 `issues: write`
- job 흐름 후보:
  1. checkout `devel` 기준으로 repository fetch-depth 0
  2. upstream release 조회
  3. current studio manifest 읽기
  4. target commit resolve
  5. upstream checkout/clone
  6. impact helper 실행
  7. current 또는 no-impact이면 PR 생성 없이 summary 종료
  8. existing branch/PR 탐색
  9. upstream WASM/studio build 실행
  10. sync script 실행
  11. verification 실행
  12. branch commit/push
  13. `gh pr create --base devel --head <branch>`
  14. assignee/reviewer/mention 설정
- branch naming:
  - `automation/rhwp-<tag>-studio-sync`
- commit message:
  - `Task #204: Update bundled rhwp-studio to <tag>`
- PR title:
  - `Update bundled rhwp-studio to rhwp <tag>`

### 예상 변경 파일

- 신규: `.github/workflows/rhwp-upstream-sync-pr.yml`
- 신규: `scripts/ci/write-rhwp-studio-sync-pr-body.sh`
- 필요 시 `scripts/ci/detect-rhwp-studio-impact.sh`
- `mydocs/working/task_m019_204_stage4.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml")'
bash -n scripts/ci/write-rhwp-studio-sync-pr-body.sh
scripts/ci/write-rhwp-studio-sync-pr-body.sh --help
rg -n "contents: write|pull-requests: write|issues: write|devel|automation/rhwp|gh pr create|@postmelee|release-publish" .github/workflows/rhwp-upstream-sync-pr.yml scripts/ci/write-rhwp-studio-sync-pr-body.sh
git diff --check
```

GitHub-hosted runner 전용 확인 항목:

- `GITHUB_TOKEN`으로 branch push와 PR 생성이 가능한지
- reviewer request 또는 assignee 설정 권한이 충분한지
- schedule이 workflow merge 후 기대한 branch에서 실제로 활성화되는지

### 완료 기준

- workflow가 current/no-impact/create-pr 상태를 구분한다.
- 자동 PR body만 읽어도 previous/new provenance, 영향 감지, 검증, 승인 분리가 이해된다.
- Stage 4 보고서에 실제 PR 생성 미검증 범위와 GitHub-hosted runner 확인 항목이 기록된다.

### 커밋 메시지

```text
Task #204 Stage 4: rhwp-studio 자동 업데이트 PR workflow 추가
```

## Stage 5. PR CI 분류와 운영 문서 갱신

### 목표

자동 생성 PR이 필요한 검증을 실행하도록 PR CI 분류 기준을 보강하고, 운영 문서에 upstream sync PR 흐름을 기록한다.

### 작업

- `scripts/ci/classify-pr-changes.sh`에서 bundled `rhwp-studio` resource 변경이 macOS build를 요구하는지 확인하고 필요한 경우 이유를 더 명확히 한다.
- `Sources/HostApp/Resources/rhwp-studio/**` 변경이 release/provenance와 HostApp bundle에 미치는 영향을 PR CI summary에 반영한다.
- `.github/workflows/pr-ci.yml` script helper interface check에 신규 helper `--help`를 추가한다.
- `mydocs/manual/ci_workflow_guide.md`에 `rhwp Upstream Sync PR` workflow 항목을 추가한다.
  - trigger, 권한, runner, state 분기, PR 생성 조건, 로컬 재현 명령
- `mydocs/manual/core_dependency_operation_guide.md`에 studio manifest와 core lock 비교 기준, 자동 PR handoff를 기록한다.
- `mydocs/manual/release_distribution_guide.md`에 자동 sync PR과 public release 승인 분리 기준을 반영한다.

### 예상 변경 파일

- `scripts/ci/classify-pr-changes.sh`
- `.github/workflows/pr-ci.yml`
- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/working/task_m019_204_stage5.md`

### 검증

```bash
git status --short --branch
bash -n scripts/ci/*.sh
scripts/ci/classify-pr-changes.sh devel HEAD
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
rg -n "Upstream Sync|rhwp-studio|automation/rhwp|devel|public release|protected" mydocs/manual .github/workflows scripts/ci
git diff --check
```

### 완료 기준

- 자동 sync PR 변경 범위가 필요한 PR CI gate를 켠다.
- 신규 helper `--help`가 PR CI에서 검증된다.
- 운영 매뉴얼이 감시, 자동 PR, 검증, public release 승인 분리를 설명한다.

### 커밋 메시지

```text
Task #204 Stage 5: upstream sync PR 운영 기준 문서화
```

## Stage 6. 통합 검증과 보고

### 목표

전체 자동화 변경을 로컬에서 가능한 범위까지 검증하고, GitHub-hosted runner에서만 확인 가능한 항목을 명확히 남긴다.

### 작업

- 전체 workflow YAML parse를 실행한다.
- 전체 shell syntax check를 실행한다.
- 신규 helper `--help`와 dry-run 가능한 경로를 실행한다.
- `scripts/verify-rhwp-studio-assets.sh` 기본 호출을 실행해 기존 bundled asset이 깨지지 않았는지 확인한다.
- PR CI 분류 helper를 실행한다.
- 네트워크 접근이 허용되면 upstream release 조회와 target/current 비교 dry-run을 실행한다.
- 실제 branch push/PR 생성, reviewer/assignee 설정, schedule queueing은 GitHub-hosted runner 확인 항목으로 분리한다.
- 최종 결과보고서와 PR 준비 문서를 작성한다.

### 예상 변경 파일

- `mydocs/working/task_m019_204_stage6.md`
- `mydocs/report/task_m019_204_report.md`
- 필요 시 `mydocs/orders/20260517.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
bash -n scripts/*.sh scripts/ci/*.sh
scripts/ci/check-rhwp-upstream-release.sh --help
scripts/ci/detect-rhwp-studio-impact.sh --help
scripts/ci/write-rhwp-studio-sync-pr-body.sh --help
scripts/sync-rhwp-studio.sh --help
scripts/verify-rhwp-studio-assets.sh --help
scripts/verify-rhwp-studio-assets.sh
scripts/ci/classify-pr-changes.sh devel HEAD
git diff --check
```

선택 네트워크 검증:

```bash
gh release view -R edwardkim/rhwp --json tagName,url,targetCommitish
```

### 완료 기준

- 로컬에서 가능한 syntax, helper interface, bundled asset verification, PR CI classification 검증이 통과한다.
- Stage 6 보고서와 최종 보고서에 GitHub-hosted runner 잔여 검증 항목이 구체적으로 남는다.
- 최종 PR은 #204를 닫을 수 있는 설명과 검증 결과를 포함한다.

### 커밋 메시지

```text
Task #204 Stage 6 + 최종 보고서: upstream sync PR 자동화 검증 정리
```

## 최종 산출물 기준

- 자동 PR base는 `devel`이다.
- 새 upstream release가 없으면 workflow summary에 current 상태가 남고 PR은 생성되지 않는다.
- 새 upstream release가 있어도 viewer 영향 변경이 없으면 skipped/no-impact summary가 남고 PR은 생성되지 않는다.
- viewer/WASM/core 영향 변경이 있으면 bundled `rhwp-studio` 업데이트 후보 branch와 PR이 생성된다.
- 자동 PR은 maintainer 알림을 위해 `@postmelee` mention과 가능한 assignee/reviewer 설정을 포함한다.
- 자동 PR body는 provenance, impact, 검증, maintainer 확인 항목, public release 분리를 설명한다.
- public release는 기존 protected `release-publish.yml` workflow와 maintainer 승인 없이는 실행되지 않는다.
