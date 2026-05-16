# Task M018 #198 구현계획서

수행계획서: `mydocs/plans/task_m018_198.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #198 PR 생성 CI와 릴리즈 검증 CI 보강
- 마일스톤: M018 (`v0.1.1`)
- 브랜치: `local/task198`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel-webview`
- 선행 상태: #185 merge 완료. `scripts/ci/write-release-delta-checklist.sh`, release note template, release manual 분리 기준을 활용한다.
- 목표: PR 생성/갱신 시 실행되는 기본 CI gate를 만들고, release rehearsal/publish workflow에 release delta checklist 생성/summary를 연결한다.

## 구현 원칙

- PR CI는 `pull_request` 이벤트만 사용한다. `pull_request_target`은 사용하지 않는다.
- PR CI는 대상 브랜치 `main`, `devel-webview`, `devel`에 대해 실행한다.
- 외부 PR에서 repository secrets가 필요한 job을 실행하지 않는다.
- release publish는 계속 `workflow_dispatch` + `environment: release` 보호 규칙과 tag `v<version>` 검증을 유지한다.
- GitHub Release 게시, signing/notarization, Sparkle appcast 게시, Homebrew tap push를 자동 trigger로 바꾸지 않는다.
- docs-only PR은 workflow 자체는 실행하되 macOS build job을 생략하고, 생략 사유를 `GITHUB_STEP_SUMMARY`에 남긴다.
- 변경 범위 분류 기준은 workflow inline expression보다 `scripts/ci/` helper에 두어 로컬 dry-run과 문서화가 가능하게 한다.
- release delta checklist는 자동 승인 장치가 아니라 release owner가 보정할 초안이다.

## Stage 1. 기존 workflow와 PR CI 경계 확정

### 목표

현재 release rehearsal/publish/upstream workflow와 로컬 검증 스크립트를 대조하고, PR CI에서 항상 실행할 검증과 조건부 실행할 검증의 경계를 확정한다.

### 작업

- `.github/workflows/release-rehearsal.yml`, `release-publish.yml`, `rhwp-upstream-check.yml`의 trigger, permission, concurrency, environment, artifact, summary를 정리한다.
- PR CI 변경 범위 분류 기준을 확정한다.
  - docs-only: `README.md`, `mydocs/**`, 일반 `docs/**` 등 macOS build가 필요 없는 문서 변경
  - app/Swift: `Sources/**`, `project.yml`, Xcode build 입력 변경
  - RustBridge/core lock: `RustBridge/**`, `rhwp-core.lock`, `Frameworks/**`, core 관련 scripts
  - renderer/fixture: `Sources/RhwpCoreBridge/**`, `Sources/Shared/**`, `samples/**`, render smoke scripts
  - release/script/workflow: `.github/workflows/**`, `scripts/release.sh`, `scripts/package-release.sh`, `scripts/ci/**`, `Casks/**`, appcast/updates 관련 파일
- `check-no-appkit.sh`, `build-rust-macos.sh --verify-lock`, `validate-stage3-render.sh`, release helper syntax/preflight의 runner 요구사항을 정리한다.
- Stage 1 보고서에 각 변경 범위가 어떤 job/step을 켜는지 표로 남긴다.

### 예상 변경 파일

- `mydocs/working/task_m018_198_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "workflow_dispatch|pull_request|environment: release|concurrency|GITHUB_STEP_SUMMARY|upload-artifact" .github/workflows
rg -n "build-rust-macos|validate-stage3-render|check-no-appkit|write-release-delta-checklist|write-release-notes|write-sparkle-appcast" scripts mydocs/manual
git diff --check
```

### 완료 기준

- PR CI 변경 범위 분류 기준이 Stage 1 보고서에 확정된다.
- docs-only, app/Swift, RustBridge/core, renderer/fixture, release/script/workflow 변경의 job 영향이 명확하다.
- release publish의 보호 정책을 바꾸지 않는다는 제약이 기록된다.

### 커밋 메시지

```text
Task #198 Stage 1: CI 경계와 변경 범위 기준 확정
```

## Stage 2. PR CI workflow와 변경 범위 helper 구현

### 목표

`pull_request` 기반 PR CI workflow를 추가하고, 변경 파일 범위에 따라 macOS build와 조건부 검증이 실행되도록 한다.

### 작업

- `scripts/ci/classify-pr-changes.sh`를 추가한다.
  - 입력: `<base-ref> <head-ref>`
  - `git diff --name-only "$base..$head"`로 변경 파일 수집
  - `GITHUB_OUTPUT`이 있으면 다음 output을 기록
    - `docs_only`
    - `run_macos_build`
    - `run_rust_verify`
    - `run_render_smoke`
    - `run_release_checks`
  - `GITHUB_STEP_SUMMARY`가 있으면 변경 파일 목록과 각 flag의 이유를 기록
  - 로컬 실행을 위해 `--help`를 제공
- `.github/workflows/pr-ci.yml`을 추가한다.
  - `on.pull_request.branches`: `main`, `devel-webview`, `devel`
  - `permissions.contents: read`
  - `concurrency.group`: PR 번호 또는 ref 기반, `cancel-in-progress: true`
  - `classify-changes` job: Ubuntu runner에서 변경 범위 분류
  - `script-checks` job: shell script syntax, release helper syntax, release note dry-run/template check를 수행
  - `macos-validation` job: `docs_only != true`일 때 macOS runner에서 실행
    - `./scripts/check-no-appkit.sh`
    - `xcodegen generate`
    - `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build`
    - `run_rust_verify == true`일 때 `rustup target add ...` 후 `./scripts/build-rust-macos.sh --verify-lock`
    - `run_render_smoke == true`일 때 `./scripts/validate-stage3-render.sh`
  - `release-checks` job: `run_release_checks == true`일 때 release script/helper preflight 수행
    - `./scripts/release.sh --help`
    - release notes dry-run + `check-release-notes-template.sh`
    - `write-release-delta-checklist.sh v0.1.0 HEAD ...`
    - `write-sparkle-appcast.sh` syntax 확인
- docs-only PR에서는 macOS job이 skipped 상태가 되며, classify summary에 생략 사유를 남긴다.

### 예상 변경 파일

- `.github/workflows/pr-ci.yml`
- `scripts/ci/classify-pr-changes.sh`
- `mydocs/working/task_m018_198_stage2.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
bash -n scripts/ci/classify-pr-changes.sh
scripts/ci/classify-pr-changes.sh --help
scripts/ci/classify-pr-changes.sh devel-webview HEAD
bash -n scripts/ci/*.sh
scripts/ci/write-release-notes.sh 0.1.1 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef build.noindex/release/release-notes-0.1.1.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.1.md
scripts/ci/write-release-delta-checklist.sh v0.1.0 HEAD build.noindex/release/delta-checklist-0.1.1.md
git diff --check
```

가능하면 macOS local 환경에서 다음을 실행한다. 비용이 크거나 환경이 맞지 않으면 Stage 2 보고서에 미실행 사유를 기록하고 PR CI에서 확인한다.

```bash
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### 완료 기준

- PR CI workflow YAML parse가 통과한다.
- 변경 범위 helper가 로컬에서 실행되고 output/summary용 flag를 산출한다.
- docs-only와 macOS build 필요 PR의 분류 기준이 Stage 2 보고서에 예시와 함께 기록된다.
- release script/workflow 변경에 대한 release helper preflight가 PR CI에 연결된다.

### 커밋 메시지

```text
Task #198 Stage 2: PR CI workflow와 변경 범위 분류 추가
```

## Stage 3. Release rehearsal/publish workflow delta checklist 연결

### 목표

기존 release rehearsal/publish workflow를 대체하지 않고, #185의 release delta checklist를 workflow 입력과 summary/artifact에 연결한다.

### 작업

- `.github/workflows/release-rehearsal.yml`에 `previous_release_ref` input을 추가한다.
  - 기본값은 `v0.1.0`
  - candidate ref는 checkout된 `GITHUB_SHA`를 사용한다.
  - `scripts/ci/write-release-delta-checklist.sh "$PREVIOUS_RELEASE_REF" "$GITHUB_SHA" "$ALHANGEUL_BUILD_ROOT/release/delta-checklist-$VERSION.md"` 실행
  - checklist path와 previous/candidate ref를 `GITHUB_STEP_SUMMARY`에 기록
  - release rehearsal artifact와 별도로 delta checklist artifact를 업로드
- `.github/workflows/release-publish.yml`에 `previous_release_ref` input을 추가한다.
  - 기본값은 `v0.1.0`
  - tag validation 후 candidate ref는 `v$VERSION` 또는 `GITHUB_SHA`로 명확히 기록한다.
  - publish 전 delta checklist를 생성하고 artifact upload에 포함한다.
- release publish의 기존 보호 조건을 유지한다.
  - `workflow_dispatch`
  - `environment: release`
  - tag `v<version>` 검증
  - signing/notarization, checksum, GitHub Release asset, appcast publish 경로
- delta checklist 실패는 잘못된 previous ref 또는 candidate ref를 조기에 드러내도록 실패 처리한다.

### 예상 변경 파일

- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- `mydocs/working/task_m018_198_stage3.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-rehearsal.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'
scripts/ci/write-release-delta-checklist.sh v0.1.0 HEAD build.noindex/release/delta-checklist-0.1.1.md
rg -n "previous_release_ref|write-release-delta-checklist|delta-checklist|GITHUB_STEP_SUMMARY|upload-artifact" .github/workflows/release-rehearsal.yml .github/workflows/release-publish.yml
rg -n "HostApp|Quick Look|Thumbnail|Sparkle|DMG|Homebrew|문서" build.noindex/release/delta-checklist-0.1.1.md
git diff --check
```

### 완료 기준

- release rehearsal과 publish workflow가 delta checklist를 생성하고 summary/artifact로 남기는 경로를 가진다.
- release publish의 보호된 수동 실행과 tag 검증이 유지된다.
- Stage 3 보고서에 변경 전/후 release workflow 역할이 기록된다.

### 커밋 메시지

```text
Task #198 Stage 3: release workflow delta checklist 연결
```

## Stage 4. CI 역할과 수동 재현 문서화

### 목표

PR CI, release rehearsal, release publish, rhwp upstream check의 역할과 경계를 문서화하고, 실패 시 수동 재현 명령을 찾을 수 있게 한다.

### 작업

- `mydocs/manual/ci_workflow_guide.md`를 추가한다.
  - PR CI trigger, base branch, concurrency, permission
  - 변경 범위 분류 flag와 job mapping
  - docs-only skip 기준
  - macOS validation에서 실행하는 명령
  - release checks에서 실행하는 명령
  - release rehearsal/publish/upstream check 역할
  - 외부 PR과 secrets 정책
- `release_distribution_guide.md`의 하위 문서 맵 또는 전체 release flow에 CI guide를 연결한다.
- `release_github_pages_sparkle_guide.md`에 release delta checklist가 workflow summary/artifact로 생성된다는 기준을 반영한다.
- `release_packaging_dmg_guide.md`에 release rehearsal workflow가 DMG/checksum과 delta checklist를 생성한다는 기준을 반영한다.
- 필요 시 `README.md`의 build/release 참고 링크에 CI guide를 추가한다.
- Stage 4 보고서에 문서 entrypoint와 하위 링크를 정리한다.

### 예상 변경 파일

- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/manual/release_github_pages_sparkle_guide.md`
- `mydocs/manual/release_packaging_dmg_guide.md`
- `README.md` (필요 시)
- `mydocs/working/task_m018_198_stage4.md`

### 검증

```bash
git status --short --branch
rg -n "PR CI|docs-only|classify-pr-changes|HostApp Debug|release rehearsal|release publish|rhwp upstream|pull_request|workflow_dispatch|environment: release|delta checklist" mydocs/manual README.md .github/workflows
git diff --check
```

### 완료 기준

- CI별 역할과 실행 조건이 문서화된다.
- release 관련 문서에서 delta checklist와 release workflow summary/artifact 위치를 찾을 수 있다.
- docs-only skip과 외부 PR secrets 제한이 문서에 명확히 남는다.

### 커밋 메시지

```text
Task #198 Stage 4: CI 역할과 release 검증 경계 문서화
```

## Stage 5. 최종 dry-run, 보고, PR 준비

### 목표

전체 workflow/helper/document 산출물을 대조하고, GitHub-hosted runner에서만 확인 가능한 항목과 로컬에서 검증한 항목을 분리해 최종 보고서에 기록한다.

### 작업

- 모든 workflow YAML parse를 반복한다.
- shell helper syntax와 dry-run을 반복한다.
- `pr-ci.yml`의 job 조건과 `classify-pr-changes.sh` output 이름이 일치하는지 대조한다.
- release rehearsal/publish workflow가 기존 release path를 보존했는지 대조한다.
- 오늘할일 상태를 완료로 갱신한다.
- 최종 보고서에 다음을 포함한다.
  - 변경 파일 목록과 영향 범위
  - PR CI job mapping
  - release workflow delta checklist 연결 방식
  - 실행한 로컬 검증
  - PR 게시 후 GitHub Actions에서 확인할 항목
  - #188 handoff

### 예상 변경 파일

- `mydocs/orders/20260510.md`
- `mydocs/report/task_m018_198_report.md`

### 검증

```bash
git status --short --branch
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-rehearsal.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/release-publish.yml")'
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-check.yml")'
bash -n scripts/ci/*.sh
scripts/ci/classify-pr-changes.sh --help
scripts/ci/classify-pr-changes.sh devel-webview HEAD
scripts/ci/write-release-notes.sh 0.1.1 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef build.noindex/release/release-notes-0.1.1.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.1.md
scripts/ci/write-release-delta-checklist.sh v0.1.0 HEAD build.noindex/release/delta-checklist-0.1.1.md
rg -n "pull_request|concurrency|classify-pr-changes|docs_only|run_macos_build|run_rust_verify|run_render_smoke|run_release_checks|previous_release_ref|environment: release" .github/workflows scripts/ci mydocs/manual
git diff --check
```

### 완료 기준

- 모든 새/수정 workflow YAML parse가 통과한다.
- helper script syntax와 dry-run이 통과한다.
- PR CI와 release workflow의 역할 경계가 문서와 일치한다.
- 최종 보고서와 오늘할일 갱신이 완료된다.
- PR 게시 준비 전 작업트리가 정리된다.

### 커밋 메시지

```text
Task #198 Stage 5 + 최종 보고서: PR CI와 release 검증 보강 완료
```
