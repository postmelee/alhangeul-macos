# Task M019 #348 최종 보고서

## 작업 개요

- 이슈: #348 `rhwp Upstream Sync PR를 full upstream sync와 PR CI 트리거 구조로 확장`
- 마일스톤: M019 / v0.1.2
- 작업 브랜치: `local/task348`
- 게시 브랜치: `publish/task348`
- 기준 브랜치: `devel`
- 수정 PR: #350 `https://github.com/postmelee/alhangeul-macos/pull/350`
- 구현/검증 최종 커밋: `47eeb51 Task #348 Stage 5: full sync 자동 PR 생성 검증`

이번 작업은 `rhwp Upstream Sync PR` workflow를 `rhwp-studio` bundled asset만 갱신하는 자동화에서, upstream `rhwp` release tag 하나를 기준으로 native core provenance와 bundled `rhwp-studio`를 함께 갱신하는 full upstream sync 후보 PR 생성 자동화로 확장했다.

public release, signed/notarized DMG, GitHub Release, Sparkle appcast, Homebrew Cask 배포는 이번 작업에서 실행하지 않았다.

## 최종 구현 결과

### workflow 구조

`.github/workflows/rhwp-upstream-sync-pr.yml`을 다음 job 구조로 확장했다.

| job | 역할 |
|-----|------|
| `Resolve rhwp full sync target` | 현재 core/studio provenance와 target release tag/commit 비교, upstream impact 분석, 기존 automation PR 확인, 실행 decision 산출 |
| `Build upstream rhwp-studio assets` | Ubuntu runner에서 upstream checkout, Docker 기반 WASM build, `rhwp-studio` Vite build, artifact upload |
| `Create rhwp full sync PR candidate` | macOS runner에서 base branch 기준 full sync 적용, core lock update, RustBridge lock update, studio asset sync, 검증, GitHub App token 기반 branch push/PR 생성 |

current 판정은 `rhwp-core.lock`과 bundled `rhwp-studio/manifest.json`이 모두 target tag/commit과 일치할 때만 true로 처리한다. 한쪽만 뒤처진 경우에도 full sync PR을 만든다.

### full sync 대상

자동 PR은 다음 파일군을 같은 upstream release tag/commit 기준으로 갱신한다.

- `rhwp-core.lock`
- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-ffi-symbols.txt` 필요 시
- `Sources/HostApp/Resources/rhwp-studio/**`

`Frameworks/` 산출물은 git에 commit하지 않고, reference metadata만 `rhwp-core.lock`에 기록하는 기존 정책을 유지했다.

### PR CI 트리거

자동 PR 생성은 기본 `GITHUB_TOKEN`이 아니라 GitHub App installation token을 사용한다.

필요한 저장소 설정:

- repository variable: `ALHANGEUL_AUTOMATION_CLIENT_ID`
- repository secret: `ALHANGEUL_AUTOMATION_APP_PRIVATE_KEY`
- GitHub App 권한: Metadata read, Contents write, Pull requests write, Issues write

검증 결과, 이 token으로 생성된 자동 PR에는 `pull_request` 기반 PR CI가 정상 트리거됐다.

### PR body

새 helper `scripts/ci/write-rhwp-full-sync-pr-body.sh`를 추가해 자동 PR 본문에 다음 정보를 남기도록 했다.

- previous core/studio tag와 commit
- target upstream release URL, tag, commit
- upstream changed paths count
- viewer/WASM/core impact paths
- repository changed paths
- full sync 검증 명령 결과
- maintainer checklist
- release boundary

Stage 5에서 #349 생성 후 신규 asset이 PR body의 repository changes 집계에 빠지는 문제를 발견했다. 원인은 body 생성 시점에 `git diff --name-only`를 사용해 untracked 신규 파일이 빠졌기 때문이다. 이를 `git add` 후 `git diff --cached --name-only` 기준으로 보정했다.

## 검증 결과

### 로컬 정적 검증

다음 검증을 수행했다.

```bash
git diff --check
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'
actionlint .github/workflows/rhwp-upstream-sync-pr.yml
bash -n scripts/ci/write-rhwp-full-sync-pr-body.sh
bash -n scripts/ci/read-rhwp-core-lock.sh
```

결과: 통과.

### dry-run 검증

- run: `https://github.com/postmelee/alhangeul-macos/actions/runs/27070451323`
- ref: `publish/task348`
- input: `target_tag=v0.7.15`, `force_pr=false`, `dry_run=true`
- conclusion: success

확인 결과:

- current core/studio: `v0.7.13`, `b3e16ef212af81ef37d973ddb86d6816d3804642`
- target: `v0.7.15`, `aa925a5954f0fd26dfcef2166cbce7877c481f44`
- `has_viewer_impact=true`
- impact path count: `176`
- build/PR 생성 job은 `dry_run=true` 조건으로 skip

### 실제 full sync PR 생성 검증

- run: `https://github.com/postmelee/alhangeul-macos/actions/runs/27070705640`
- ref: `publish/task348`
- input: `target_tag=v0.7.15`, `force_pr=false`, `dry_run=false`
- conclusion: success

job 결과:

| job | conclusion | duration |
|-----|------------|----------|
| `Resolve rhwp full sync target` | success | 28s |
| `Build upstream rhwp-studio assets` | success | 5m50s |
| `Create rhwp full sync PR candidate` | success | 7m39s |

생성된 자동 PR:

- PR: `https://github.com/postmelee/alhangeul-macos/pull/349`
- title: `Sync rhwp upstream v0.7.15`
- author: `app/alhangeul-rhwp-sync-bot`
- base: `devel`
- head: `automation/rhwp-v0.7.15-full-sync`
- head SHA: `991d2762dcfb007a8e21e5922fe5ad34a63d5021`

full sync provenance:

| 항목 | 결과 |
|------|------|
| `rhwp-core.lock` | `v0.7.15` / `aa925a5954f0fd26dfcef2166cbce7877c481f44` |
| `RustBridge/Cargo.toml` | `rhwp` tag `v0.7.15` |
| `RustBridge/Cargo.lock` | `git+https://github.com/edwardkim/rhwp.git?tag=v0.7.15#aa925a5954f0fd26dfcef2166cbce7877c481f44` |
| `rhwp-studio/manifest.json` | `v0.7.15` / `aa925a5954f0fd26dfcef2166cbce7877c481f44` |

### 자동 PR CI 검증

- PR CI run: `https://github.com/postmelee/alhangeul-macos/actions/runs/27071021677`
- event: `pull_request`
- conclusion: success

check 결과:

| check | conclusion |
|-------|------------|
| `Classify changed files` | pass |
| `Script syntax checks` | pass |
| `Release helper checks` | pass |
| `macOS validation` | pass |

`macOS validation` 안에서 Rust bridge artifact 준비, Swift boundary check, bundled `rhwp-studio` asset verify, Xcode project generation, HostApp Debug build가 통과했다. `Run native renderer smoke`는 PR CI classification에서 `run_render_smoke=false`로 판정되어 workflow 조건에 따라 skipped 처리됐다.

## #349 처리 권고

#349는 이번 #348 workflow가 실제로 생성한 upstream `rhwp` `v0.7.15` full sync 후보 PR이다. 현재 상태는 다음과 같다.

- state: OPEN
- mergeable: MERGEABLE
- PR CI: all pass
- content: core/studio provenance가 같은 release tag/commit으로 정합

권고 처리:

1. #349는 닫지 말고 upstream update review 대상으로 유지한다.
2. #348 workflow 수정 PR을 먼저 merge해 향후 자동화 기준을 devel에 반영한다.
3. #349에서 upstream `rhwp` `v0.7.15` release note/source diff, app-facing 영향, viewer/editor smoke 필요 여부를 maintainer가 검토한다.
4. 검토 결과 문제가 없으면 #349를 `devel`에 merge한다.
5. #349 merge는 public release가 아니다. release version 확정, release note 작성, signed/notarized DMG, GitHub Release, Sparkle appcast, Homebrew Cask는 별도 release approval과 release workflow에서 진행한다.

대안:

- #349 PR body의 `repository changed paths: 13` 집계가 신규 asset을 빠뜨린 상태로 생성됐다. 실제 diff와 CI에는 영향이 없으므로 merge 후보로 쓰는 데 문제는 없다.
- 자동 PR 본문까지 보정된 형태로 다시 받고 싶다면, #348 merge 후 #349를 superseded close하고 `rhwp Upstream Sync PR`을 `devel` ref에서 다시 실행해 새 full sync PR을 생성하면 된다. 다만 현재 #349의 content와 checks가 정상이라 실무상 재생성 필요성은 낮다.

## 남은 운영 경계

- GitHub App private key와 client id는 repository settings에 유지해야 한다.
- `dry_run=false` 자동 PR 생성은 GitHub App token 설정이 없으면 실패하도록 명시 검증한다.
- 자동 PR은 release 후보 입력일 뿐 release 실행이 아니다.
- upstream 변경 분석과 release 판단은 maintainer가 별도로 수행한다.
- public release 관련 작업은 `release_distribution_guide.md`의 보호 절차와 별도 승인 없이는 실행하지 않는다.

## 변경 파일 요약

주요 변경:

- `.github/workflows/rhwp-upstream-sync-pr.yml`
- `scripts/ci/write-rhwp-full-sync-pr-body.sh`
- `scripts/ci/read-rhwp-core-lock.sh`
- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/plans/task_m019_348.md`
- `mydocs/working/task_m019_348_stage1.md`
- `mydocs/working/task_m019_348_stage2.md`
- `mydocs/working/task_m019_348_stage3.md`
- `mydocs/working/task_m019_348_stage4.md`
- `mydocs/working/task_m019_348_stage5.md`
- `mydocs/orders/20260607.md`

## 완료 판단

#348의 완료 기준은 충족됐다.

- full sync automation branch/PR 생성 확인 완료
- core/studio provenance 정합 확인 완료
- 자동 생성 PR의 PR CI trigger 확인 완료
- PR CI 최종 pass 확인 완료
- public release boundary 유지 확인 완료

다음 절차는 #350을 review 후 merge하고, merge 후 #348 이슈를 정리하는 것이다.
