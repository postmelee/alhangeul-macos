# Task M019 #348 Stage 5 완료 보고서

## 단계 목적

`publish/task348` 원격 ref에서 `rhwp Upstream Sync PR` workflow를 `dry_run=false`로 실행해 실제 full sync build, automation branch push, 자동 PR 생성, PR CI trigger와 완료까지 검증한다.

## 확인 시각

- 2026-06-07 04:10 KST

## 실행 조건

```bash
gh workflow run "rhwp Upstream Sync PR" \
  --repo postmelee/alhangeul-macos \
  --ref publish/task348 \
  -f target_tag=v0.7.15 \
  -f force_pr=false \
  -f dry_run=false
```

사전 상태:

- `publish/task348` head: `9dc29a165beb5b46d5fd0952f6e4664b61606b96`
- `automation/rhwp-v0.7.15-full-sync` remote branch 없음
- `devel` 대상 `automation/rhwp-v0.7.15-full-sync` PR 없음
- GitHub App repository variable/secret 등록 확인 완료

## full sync workflow 결과

- URL: `https://github.com/postmelee/alhangeul-macos/actions/runs/27070705640`
- event: `workflow_dispatch`
- head branch: `publish/task348`
- head SHA: `9dc29a165beb5b46d5fd0952f6e4664b61606b96`
- status: `completed`
- conclusion: `success`
- createdAt: `2026-06-06T18:43:23Z` (`2026-06-07 03:43:23 KST`)
- updatedAt: `2026-06-06T18:57:29Z` (`2026-06-07 03:57:29 KST`)

| job | conclusion | duration |
|-----|------------|----------|
| `Resolve rhwp full sync target` | success | 28s |
| `Build upstream rhwp-studio assets` | success | 5m50s |
| `Create rhwp full sync PR candidate` | success | 7m39s |

확인된 핵심 단계:

- GitHub App token 설정 검증 통과
- GitHub App token 발급 통과
- upstream `rhwp-studio`/WASM build artifact 생성과 다운로드 통과
- `scripts/update-rhwp-core.sh --channel stable --tag v0.7.15` 통과
- `scripts/build-rust-macos.sh --update-lock` 통과
- `scripts/check-no-appkit.sh` 통과
- `scripts/sync-rhwp-studio.sh --tag v0.7.15 --commit aa925a5954f0fd26dfcef2166cbce7877c481f44` 통과
- `scripts/verify-rhwp-studio-assets.sh --tag v0.7.15 --commit aa925a5954f0fd26dfcef2166cbce7877c481f44` 통과
- `git diff --check` 통과
- automation branch push와 PR 생성 통과

## 생성된 자동 PR

- PR: `https://github.com/postmelee/alhangeul-macos/pull/349`
- number: `#349`
- title: `Sync rhwp upstream v0.7.15`
- author: `app/alhangeul-rhwp-sync-bot`
- base: `devel`
- head: `automation/rhwp-v0.7.15-full-sync`
- head SHA: `991d2762dcfb007a8e21e5922fe5ad34a63d5021`
- PR commit: `Sync rhwp upstream to v0.7.15`

## PR CI 결과

- PR CI run: `https://github.com/postmelee/alhangeul-macos/actions/runs/27071021677`
- event: `pull_request`
- head branch: `automation/rhwp-v0.7.15-full-sync`
- head SHA: `991d2762dcfb007a8e21e5922fe5ad34a63d5021`
- status: `completed`
- conclusion: `success`
- createdAt: `2026-06-06T18:57:23Z` (`2026-06-07 03:57:23 KST`)
- updatedAt: `2026-06-06T19:06:08Z` (`2026-06-07 04:06:08 KST`)

| check | conclusion | duration |
|-------|------------|----------|
| `Classify changed files` | pass | 10s |
| `Script syntax checks` | pass | 9s |
| `Release helper checks` | pass | 19s |
| `macOS validation` | pass | 8m28s |

`macOS validation` 내부 확인:

- `Prepare Rust bridge artifacts`: success
- `Check shared Swift boundary`: success
- `Verify bundled rhwp-studio assets`: success
- `Generate Xcode project`: success
- `Build HostApp Debug`: success
- `Run native renderer smoke`: skipped

`Run native renderer smoke`는 `.github/workflows/pr-ci.yml`에서 `needs.classify-changes.outputs.run_render_smoke == 'true'`일 때만 실행된다. 이번 full sync PR에서는 해당 조건이 false로 판정되어 skip되었고, check 자체는 success로 완료됐다.

## full sync 고정 값 확인

`origin/automation/rhwp-v0.7.15-full-sync:rhwp-core.lock`:

```text
rhwp_ref_kind = "release-tag"
rhwp_release_tag = "v0.7.15"
rhwp_commit = "aa925a5954f0fd26dfcef2166cbce7877c481f44"
rhwp_enabled_features = "native-skia"
```

`origin/automation/rhwp-v0.7.15-full-sync:RustBridge/Cargo.toml`:

```text
rhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "v0.7.15", features = ["native-skia"] }
```

`origin/automation/rhwp-v0.7.15-full-sync:RustBridge/Cargo.lock`:

```text
source = "git+https://github.com/edwardkim/rhwp.git?tag=v0.7.15#aa925a5954f0fd26dfcef2166cbce7877c481f44"
```

`origin/automation/rhwp-v0.7.15-full-sync:Sources/HostApp/Resources/rhwp-studio/manifest.json`:

```json
{
  "source_ref_kind": "release-tag",
  "source_release_tag": "v0.7.15",
  "source_resolved_commit": "aa925a5954f0fd26dfcef2166cbce7877c481f44"
}
```

## PR diff 확인

`git diff --name-status origin/devel...origin/automation/rhwp-v0.7.15-full-sync` 기준:

```text
M	RustBridge/Cargo.lock
M	RustBridge/Cargo.toml
A	Sources/HostApp/Resources/rhwp-studio/assets/canvaskit-renderer-Cmoh0T0M.js
D	Sources/HostApp/Resources/rhwp-studio/assets/canvaskit-renderer-Dz1dV4AX.js
A	Sources/HostApp/Resources/rhwp-studio/assets/index-C9eG_4qi.css
A	Sources/HostApp/Resources/rhwp-studio/assets/index-DVBNvrb8.js
D	Sources/HostApp/Resources/rhwp-studio/assets/index-DokHBifW.js
D	Sources/HostApp/Resources/rhwp-studio/assets/index-Dp_1IBLX.css
R052	Sources/HostApp/Resources/rhwp-studio/assets/rhwp_bg-BPam6dJo.wasm	Sources/HostApp/Resources/rhwp-studio/assets/rhwp_bg-4pi8y5Ik.wasm
A	Sources/HostApp/Resources/rhwp-studio/fonts/NotoSansKR-ExtraLight.woff2
M	Sources/HostApp/Resources/rhwp-studio/index.html
M	Sources/HostApp/Resources/rhwp-studio/manifest.json
M	Sources/HostApp/Resources/rhwp-studio/rhwp.d.ts
M	Sources/HostApp/Resources/rhwp-studio/rhwp.js
M	Sources/HostApp/Resources/rhwp-studio/rhwp_bg.wasm.d.ts
M	Sources/HostApp/Resources/rhwp-studio/sw.js
M	rhwp-core.lock
```

full sync 취지에 맞게 native core provenance와 bundled `rhwp-studio` asset이 같은 upstream release tag/commit으로 갱신됐다.

## 추가 발견과 수정

자동 생성된 #349 PR 본문의 `Repository changes` 집계는 `13`개로 표시됐다. 원인은 workflow가 PR body 생성 전에 `git diff --name-only`를 실행했기 때문이다. 이 시점에는 새로 생성된 asset/font 파일이 아직 untracked 상태라 `git diff --name-only`에 포함되지 않는다.

실제 PR files와 fetch 후 diff 기준은 17개이며, PR commit과 CI 검증에는 누락이 없다. 다만 자동 PR body의 변경 파일 목록은 신규 파일을 빠뜨릴 수 있으므로 workflow를 추가 보정했다.

보정 내용:

- `git add`로 full sync 대상 경로를 먼저 staging한다.
- staged change가 없으면 PR을 만들지 않는다.
- PR body의 repository changes는 `git diff --cached --name-only`를 사용한다.

보정 후 로컬 검증:

```bash
git diff --check
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'
actionlint .github/workflows/rhwp-upstream-sync-pr.yml
bash -n scripts/ci/write-rhwp-full-sync-pr-body.sh
```

결과: 통과.

이 보정은 #349 생성 이후 발견된 PR body 집계 정확도 수정이다. #349의 실제 branch, commit, full sync 파일, PR CI 결과에는 영향이 없다.

## 완료 기준 확인

| 기준 | 결과 |
|------|------|
| `dry_run=false` workflow 실행 | OK, run `27070705640` success |
| upstream `v0.7.15` resolve | OK |
| upstream viewer/WASM/core impact detection | OK, `has_viewer_impact=true`, `176` |
| upstream `rhwp-studio`/WASM build artifact 생성 | OK |
| `rhwp-core.lock` stable release tag/commit 갱신 | OK, `v0.7.15` / `aa925a5954f0fd26dfcef2166cbce7877c481f44` |
| `RustBridge/Cargo.toml` tag 갱신 | OK |
| `RustBridge/Cargo.lock` resolved commit 갱신 | OK |
| bundled `rhwp-studio` manifest tag/commit 갱신 | OK |
| automation branch push | OK, `automation/rhwp-v0.7.15-full-sync` |
| automation PR 생성 | OK, #349 |
| GitHub App bot author 확인 | OK, `app/alhangeul-rhwp-sync-bot` |
| PR CI 자동 trigger | OK, run `27071021677` |
| PR CI 최종 결과 | OK, success |
| PR body repository changes 신규 파일 누락 보정 | OK, workflow 추가 수정 및 정적 검증 통과 |

## 남은 판단

#349는 upstream `rhwp` `v0.7.15` full sync 후보 PR로 열려 있다. 이번 #348 작업의 목적은 자동 full sync PR workflow를 완성하고 검증하는 것이며, #349 merge 여부는 upstream release note/source review와 앱 영향 검토 후 별도로 결정한다.

Stage 6에서는 #348 최종 보고서를 작성하고, #348 workflow 수정 PR을 게시한다.
