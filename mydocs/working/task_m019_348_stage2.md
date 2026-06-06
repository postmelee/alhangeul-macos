# Task M019 #348 Stage 2 완료 보고서

## 단계 목적

full sync workflow 구조와 자동 PR의 PR CI 트리거 방식을 확정한다. Stage 3 구현에서 선택지를 다시 흔들지 않도록 runner 분리, target/current 판정, token 정책, helper 변경 범위를 고정한다.

## 확인 시각

- 2026-06-07 02:43 KST

## 참조 기준

GitHub Actions 공식 문서의 현재 설명은 다음 기준을 둔다.

- `GITHUB_TOKEN`으로 수행한 작업이 만든 이벤트는 일반적으로 새 workflow run을 만들지 않는다. 예외는 `workflow_dispatch`, `repository_dispatch`이고, `pull_request` opened/synchronize/reopened는 approval-required 상태가 될 수 있다.
- workflow 안에서 다른 workflow를 정상 트리거해야 하면 `GITHUB_TOKEN` 대신 GitHub App installation access token 또는 PAT를 사용할 수 있다.
- GitHub App installation access token은 `actions/create-github-app-token` action으로 발급할 수 있다.

참조:

- `https://docs.github.com/actions/using-workflows/triggering-a-workflow`
- `https://docs.github.com/actions/concepts/security/github_token`
- `https://docs.github.com/en/apps/creating-github-apps/guides/making-authenticated-api-requests-with-a-github-app-in-a-github-actions-workflow`
- `https://github.com/actions/create-github-app-token`

## workflow 구조 결정

full sync workflow는 Ubuntu와 macOS job split 구조로 구현한다.

| job | runner | 역할 |
|-----|--------|------|
| `resolve-target` | `ubuntu-latest` | helper syntax 확인, current core/studio provenance 읽기, target release/tag commit 해석, 기존 automation branch/PR 확인, upstream impact 분석, dry-run summary |
| `build-studio-assets` | `ubuntu-latest` | upstream checkout, `scripts/update-rhwp-core.sh --check`, Docker 기반 WASM build, `npm ci`, `npx tsc`, `npx vite build --base ./`, `pkg/`와 `rhwp-studio/dist/` artifact upload |
| `create-full-sync-pr` | `macos-15` | base branch checkout, upstream checkout 복원, build artifact download, core lock/artifact update, studio asset sync, 검증, automation branch commit/push, PR 생성 |

단일 macOS job은 선택하지 않는다. 현재 upstream WASM build의 안정 경로가 Ubuntu Docker compose이고, core artifact update는 `xcodebuild`, `xcrun lipo`, Apple target Rust build가 필요하므로 두 runner의 책임을 분리하는 편이 실행 환경을 가장 명확하게 만든다.

macOS job은 upstream repository를 target commit으로 다시 checkout한 뒤 Ubuntu artifact의 `pkg/`와 `rhwp-studio/dist/`를 덮어써 `scripts/sync-rhwp-studio.sh`가 요구하는 `.git`, `pkg`, `rhwp-studio/dist` 조건을 모두 만족시킨다.

## current/target 판정 결정

current 기준은 `rhwp-studio` manifest만 보지 않고 다음 네 값을 모두 본다.

| 기준 | source |
|------|--------|
| current core tag | `rhwp-core.lock`의 `rhwp_release_tag` |
| current core commit | `rhwp-core.lock`의 `rhwp_commit` |
| current studio tag | `Sources/HostApp/Resources/rhwp-studio/manifest.json`의 `source_release_tag` |
| current studio commit | `Sources/HostApp/Resources/rhwp-studio/manifest.json`의 `source_resolved_commit` |

target 기준은 input `target_tag`가 있으면 그 값을 쓰고, 없으면 upstream latest release를 사용한다. resolved commit은 `git ls-remote --tags`로 tag commit을 해석한다.

`current=true`는 core와 studio가 모두 target tag/resolved commit과 일치할 때만 설정한다. 한쪽만 target과 맞고 다른 한쪽이 뒤처진 경우도 full sync 대상이다.

viewer impact 분석은 유지하지만 PR 생성의 유일한 gate로 쓰지 않는다. upstream release가 viewer path를 직접 바꾸지 않았더라도 core lock provenance가 뒤처졌다면 full sync PR을 생성해야 한다.

## core/studio 적용 순서 결정

macOS job의 적용 순서는 다음으로 고정한다.

1. `git switch -c automation/rhwp-<tag>-full-sync origin/devel`
2. `scripts/update-rhwp-core.sh --channel stable --tag <target>`
3. `scripts/build-rust-macos.sh --update-lock`
4. `scripts/check-no-appkit.sh`
5. `scripts/sync-rhwp-studio.sh --upstream-dir <restored-upstream> --tag <target> --commit <target-commit>`
6. `scripts/verify-rhwp-studio-assets.sh --tag <target> --commit <target-commit>`
7. `git diff --check`
8. repository changed paths와 verification 결과 기록
9. full sync PR body 생성
10. full sync 산출물 전체를 stage/commit/push

tracked stage 대상은 최소 다음을 포함한다.

- `Sources/HostApp/Resources/rhwp-studio`
- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`
- `rhwp-ffi-symbols.txt`

`Frameworks/` 아래 생성 산출물은 `.gitignore` 대상이므로 commit하지 않는다. `Frameworks/generated_rhwp.h`와 `Frameworks/universal/librhwp.a`는 `rhwp-core.lock`의 hash/size metadata 대상으로만 반영한다. `Frameworks/Rhwp.xcframework`도 기존 정책대로 commit 대상이 아니다.

## 자동 PR token 결정

자동 PR 생성에는 GitHub App installation token을 사용한다.

필요 repository 설정:

| 이름 | 위치 | 목적 |
|------|------|------|
| `ALHANGEUL_AUTOMATION_CLIENT_ID` | repository variable | GitHub App Client ID |
| `ALHANGEUL_AUTOMATION_APP_PRIVATE_KEY` | repository secret | GitHub App private key |

GitHub App 권한:

| 권한 | 수준 | 이유 |
|------|------|------|
| Metadata | read | repository 접근 기본 권한 |
| Contents | read/write | automation branch push |
| Pull requests | read/write | PR 생성, reviewer 지정 |
| Issues | read/write | assignee 지정과 PR issue metadata 처리 |

`GITHUB_TOKEN` fallback으로 실제 PR을 만들지 않는다. secret/variable이 없으면 `dry_run=false` 실행은 명확히 실패시키고, 필요한 설정 이름을 summary에 남긴다. 이렇게 해야 자동 PR이 만들어졌지만 PR CI가 자동으로 붙지 않는 상태를 다시 만들지 않는다.

fine-grained PAT는 보조 선택지로만 남긴다. 개인 계정 token 수명과 권한 회수가 운영 부담이므로 기본 설계에서 제외한다.

`repository_dispatch`/`workflow_dispatch` 기반 별도 검증은 fallback으로만 남긴다. 이 방식은 PR의 일반 `pull_request` checks와 동일한 UX가 아니고, PR status check 연결을 별도 구현해야 하므로 이번 full sync의 기본 경로로 사용하지 않는다.

## PR body/helper 결정

기존 `scripts/ci/write-rhwp-studio-sync-pr-body.sh`는 studio-only 용어와 입력 구조가 강하다. Stage 3에서는 full sync 기준 helper로 확장하거나 신규 helper를 도입한다.

PR body에는 다음 정보를 포함한다.

- previous core tag/commit
- previous studio tag/commit
- target release tag/commit/URL
- upstream changed paths와 viewer impact details
- repository changed paths
- 실행한 core/studio 검증 명령
- PR CI가 확인해야 할 항목
- public release가 자동 실행되지 않는다는 release boundary

자동 PR commit message는 `Sync rhwp upstream to <tag>` 계열로 바꾸고, `Automation source`는 issue close keyword 없이 workflow 출처만 남긴다.

## Stage 3 구현 범위

Stage 3에서 수정할 파일은 다음으로 예상한다.

| 파일 | 변경 |
|------|------|
| `.github/workflows/rhwp-upstream-sync-pr.yml` | split job, full sync current 판정, GitHub App token, artifact handoff, macOS core update |
| `scripts/ci/write-rhwp-studio-sync-pr-body.sh` 또는 신규 helper | full sync PR body 작성 |
| `scripts/ci/classify-pr-changes.sh` | 신규 helper 이름을 release checks 대상으로 반영 |
| `mydocs/manual/ci_workflow_guide.md` | full sync workflow 역할과 token 조건 문서화 |
| `mydocs/manual/core_dependency_operation_guide.md` | `v0.7.13` drift와 full sync 자동화 경계 문서화 |

가능하면 기존 `scripts/update-rhwp-core.sh`, `scripts/build-rust-macos.sh`, `scripts/sync-rhwp-studio.sh`는 인터페이스 변경 없이 조합한다.

## 검증 계획

Stage 3 구현 후 최소 검증은 다음 순서로 수행한다.

1. 로컬 syntax:
   - `git diff --check`
   - workflow YAML parse
   - `bash -n scripts/*.sh scripts/ci/*.sh`
   - 관련 helper `--help`
2. check-only:
   - `scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.15`
3. workflow dry-run:
   - `gh workflow run "rhwp Upstream Sync PR" --ref publish/task348 -f target_tag=v0.7.15 -f dry_run=true`
4. token 설정 확인 후 full run:
   - `gh workflow run "rhwp Upstream Sync PR" --ref publish/task348 -f target_tag=v0.7.15 -f dry_run=false`
5. 생성 PR 검증:
   - core/studio provenance가 모두 `v0.7.15`와 `aa925a5954f0fd26dfcef2166cbce7877c481f44`인지 확인
   - PR CI checks가 자동으로 생성되는지 확인

## 잔여 조건

repository variable 목록 조회 결과 현재 출력되는 variable은 없었다. secret 목록 조회는 승인 검토 타임아웃으로 확인하지 못했다. 따라서 Stage 3 구현은 token 미설정 시 명확히 실패하는 구조로 만들고, Stage 5 실제 full run 전에 `ALHANGEUL_AUTOMATION_CLIENT_ID`, `ALHANGEUL_AUTOMATION_APP_PRIVATE_KEY` 준비 여부를 다시 확인해야 한다.

## 승인 요청 사항

Stage 2 보고서를 승인하면 Stage 3 `workflow/helper 구현`으로 진행한다.
