# CI workflow 가이드

## 목적

이 문서는 GitHub Actions workflow의 역할, 실행 조건, 권한 경계, 로컬 재현 명령을 정리한다. 릴리스/배포 정책 자체는 [`release_distribution_guide.md`](release_distribution_guide.md), 빌드 세부 절차는 [`build_run_guide.md`](build_run_guide.md)를 따른다.

## Workflow map

| workflow | trigger | 권한 | runner | 역할 |
|----------|---------|------|--------|------|
| `PR CI` | `pull_request` to `main`, `devel`, `native-viewer-editor` | `contents: read` | Ubuntu, macOS | PR 변경 범위 분류, script syntax, 조건부 macOS build, 조건부 release helper dry-run |
| `Release Rehearsal DMG` | `workflow_dispatch` | `contents: read` | macOS | signed/notarized 전 universal rehearsal DMG/checksum과 release delta checklist artifact 생성 |
| `Release Publish DMG` | `workflow_dispatch` | `contents: write` for release job, `pages: write`/`id-token: write` for Pages job, `environment: release`/`github-pages` | macOS, Ubuntu | tag 검증, signed/notarized universal DMG, GitHub Release asset, stable Sparkle appcast, Pages deployment, release delta checklist artifact 생성 |
| `Docs-only Pages Deploy` | `push` to `main` with `docs/**`, `workflow_dispatch` | `contents: read`, `pages: write`/`id-token: write` for Pages job, `environment: github-pages` | Ubuntu | 일반 Pages 문서 변경을 public Pages에 배포하고 기존 public appcast를 보존 |
| `rhwp Upstream Release Check` | `workflow_dispatch`, schedule | `contents: read` | Ubuntu | upstream `rhwp` release와 `rhwp-core.lock` 비교 |

## JavaScript action runtime 기준

GitHub Actions에서 JavaScript action runtime deprecation annotation이 발생하면, 먼저 repository workflow의 `uses:` action과 해당 action의 `action.yml` runtime을 확인한다. 기본 대응은 official action의 지원 runtime major로 갱신하는 것이며, runner 환경변수로 runtime을 강제하거나 deprecated runtime을 허용하는 방식은 임시 진단 외 기본 대응책으로 쓰지 않는다.

workflow action reference 점검 예시:

```bash
rg -n "uses:" .github/workflows
```

official action runtime 확인 예시:

```bash
gh api repos/<owner>/<action>/contents/action.yml --method GET -f ref=<major-or-tag> --jq '.content' | base64 --decode | rg -n "runs:|using:|node"
```

확인 기준:

- official action의 release note와 README에서 major 변경의 breaking change를 확인한다.
- `action.yml`의 `runs.using`이 GitHub-hosted runner의 지원 runtime인지 확인한다.
- workflow에서 쓰는 input, output, credential 동작이 새 major에서 유지되는지 확인한다.
- runner/runtime 강제 또는 deprecated runtime 허용 환경변수를 workflow의 상시 대응으로 두지 않는다.
- official action major 갱신 대신 third-party fork나 임시 wrapper로 대체하지 않는다.

PR에서 확인할 항목:

- `.github/workflows/**` 변경은 `scripts/ci/classify-pr-changes.sh <base-ref> <head-ref>` 결과 `run_release_checks=true`가 되어야 한다.
- PR CI annotation에 JavaScript action runtime deprecation warning이 남는지 확인한다.
- warning이 남으면 `rg -n "uses:" .github/workflows`로 남은 JavaScript action을 다시 찾고, 해당 action의 official `action.yml` `runs.using` 값을 확인한다.
- 특정 deprecation 사건의 증상, 원인, 대응 버전, 검증 기록은 `mydocs/troubleshootings/`에 남기고 이 문서에는 반복 적용 가능한 점검 기준만 둔다.

## PR CI

PR CI는 외부 PR에서도 안전하게 실행할 수 있는 검증만 수행한다.

- `pull_request_target`은 사용하지 않는다.
- 제품/배포/문서 PR은 `devel`, Swift native viewer/editor PR은 `native-viewer-editor` 대상으로 실행한다.
- 퇴역한 `devel-webview`는 PR CI trigger와 신규 PR base로 사용하지 않는다.
- repository secrets가 필요한 signing, notarization, Sparkle private key, GitHub Release publish, Pages deployment는 실행하지 않는다.
- concurrency group은 PR 번호 기준이며 새 push가 오면 이전 PR CI를 취소한다.
- 변경 범위는 `scripts/ci/classify-pr-changes.sh`가 분류하고, 결과는 job output과 `GITHUB_STEP_SUMMARY`에 기록한다.

### 변경 범위 flag

| flag | 의미 | 켜지는 대표 변경 |
|------|------|------------------|
| `docs_only` | macOS build가 필요 없는 문서 중심 변경 | `README.md`, `mydocs/**`, 일반 `docs/**` |
| `run_macos_build` | HostApp Debug build와 shared Swift boundary 확인 필요 | `Sources/**`, `project.yml`, `Alhangeul.xcodeproj/**`, 미분류 non-docs |
| `run_rust_verify` | Rust bridge/core source/header/ABI lock 검증 필요 | `RustBridge/**`, `rhwp-core.lock`, `Frameworks/**`, core 관련 scripts |
| `run_render_smoke` | native renderer smoke 필요 | `Sources/RhwpCoreBridge/**`, `Sources/Shared/**`, extension, samples, render smoke scripts |
| `run_release_checks` | release helper dry-run 필요 | `.github/workflows/**`, `scripts/release.sh`, `scripts/ci/**`, `Casks/**`, release manual/record |

한 파일이 여러 영역에 걸치면 flag는 누적된다. 예를 들어 `Sources/RhwpCoreBridge/CGTreeRenderer.swift`는 `run_macos_build`와 `run_render_smoke`를 모두 켠다.

### docs-only skip 기준

docs-only PR에서도 `classify-changes`와 `script-checks`는 실행한다. `run_macos_build=false`이면 `macos-validation` job은 skipped 상태가 된다. 단, release 관련 문서나 Pages/appcast 파일은 문서여도 `run_release_checks=true`가 될 수 있다.

### PR CI 로컬 재현

```bash
scripts/ci/classify-pr-changes.sh <base-ref> <head-ref>
bash -n scripts/ci/classify-pr-changes.sh
bash -n scripts/ci/*.sh
bash scripts/ci/classify-pr-changes.sh --help
bash scripts/ci/check-rhwp-upstream-release.sh --help
bash scripts/ci/prepare-pages-artifact.sh --help
bash scripts/ci/write-sparkle-appcast.sh --help
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
```

macOS validation 재현:

```bash
rustup target add aarch64-apple-darwin x86_64-apple-darwin
./scripts/build-rust-macos.sh
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

`Frameworks/Rhwp.xcframework`는 git에 commit하지 않는 generated artifact이므로, GitHub Actions fresh runner의 macOS validation은 HostApp build 전에 항상 Rust bridge artifact를 재생성한다.

Rust/core 변경이 있으면 `./scripts/build-rust-macos.sh` 대신 다음 lock 검증을 실행한다.

```bash
./scripts/build-rust-macos.sh --verify-lock
```

PR CI의 macOS validation은 GitHub-hosted runner/toolchain 차이를 고려해 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`을 설정한다. 이 값은 `Frameworks/universal/librhwp.a` byte hash/size 비교만 제외한다. `rhwp` source provenance, `RustBridge/Cargo.lock`, generated header hash/size, `rhwp-ffi-symbols.txt` 검증은 계속 실패 가능한 gate로 남는다.

`RustBridge/examples/*` 같은 benchmark/helper 변경은 macOS build는 요구할 수 있지만 lock-level `run_rust_verify`는 켜지 않는다.

renderer/fixture 변경이 있으면 추가로 실행한다.

```bash
./scripts/validate-stage3-render.sh
```

release checks 재현:

```bash
./scripts/release.sh --help
scripts/ci/write-release-notes.sh 0.1.1 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef build.noindex/release/release-notes-0.1.1.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.1.md
scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app
scripts/ci/write-release-delta-checklist.sh v0.1.0 HEAD build.noindex/release/delta-checklist-0.1.1.md
scripts/ci/write-sparkle-appcast.sh \
  --version 0.1.1 \
  --build 2 \
  --dmg-url https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.1/alhangeul-macos-0.1.1.dmg \
  --length 1 \
  --ed-signature dummy-ed-signature \
  --release-notes-url https://postmelee.github.io/alhangeul-macos/updates/v0.1.1.html \
  --pub-date "Fri, 08 May 2026 09:00:00 +0000" \
  --minimum-system-version 12.0 \
  --output build.noindex/release/appcast.xml
xmllint --noout build.noindex/release/appcast.xml
scripts/ci/prepare-pages-artifact.sh \
  --docs-dir docs \
  --appcast build.noindex/release/appcast.xml \
  --output-dir build.noindex/release/pages-artifact
xmllint --noout build.noindex/release/pages-artifact/appcast.xml
test -f build.noindex/release/pages-artifact/index.html
test -f build.noindex/release/pages-artifact/updates/index.html
```

## Release Rehearsal DMG

`Release Rehearsal DMG`는 public release 전 layout, DMG 생성, checksum, release delta checklist를 확인하는 수동 workflow다.

입력:

- `version`: rehearsal version
- `previous_release_ref`: 직전 public release ref. 기본값은 `v0.1.0`
- `expected_rhwp_tag`: 선택 입력. `rhwp-core.lock`의 release tag와 일치해야 할 때 사용

workflow가 생성하는 주요 산출물:

- `alhangeul-macos-<version>-rehearsal.dmg`
- `alhangeul-macos-<version>-rehearsal.dmg.sha256`
- `delta-checklist-<version>.md`
- workflow summary의 core lock, release delta checklist, rehearsal artifact 섹션

rehearsal 산출물은 public GitHub Release asset이나 Homebrew Cask URL에 사용하지 않는다.
rehearsal workflow가 만든 app bundle도 `arm64 + x86_64` universal slice 검증을 통과해야 하지만, signed/notarized public DMG와 실제 Intel Mac 실기기 smoke를 대체하지 않는다.

## Release Publish DMG

`Release Publish DMG`는 공식 public DMG를 만드는 보호 workflow다.

유지해야 하는 보호 조건:

- `workflow_dispatch` 수동 실행
- `publish-dmg` job의 `environment: release`
- `publish-dmg` job의 `contents: write`
- `deploy-pages` job의 `environment: github-pages`
- `deploy-pages` job의 `pages: write`, `id-token: write`
- `deploy-pages` job의 `concurrency.group: pages-deploy`, `cancel-in-progress: false`
- tag `v<version>`에서 실행되고 checkout HEAD가 해당 tag commit과 일치해야 함
- Developer ID certificate, notarization credential, Sparkle EdDSA private key는 GitHub Actions secret/environment variable로만 사용

입력:

- `version`: publish version
- `previous_release_ref`: 직전 public release ref. 기본값은 `v0.1.0`
- `expected_rhwp_tag`: `rhwp-core.lock`의 release tag와 일치해야 하는 upstream tag
- `require_latest_rhwp`: upstream latest release와 lock tag 일치 여부 확인
- `draft`, `prerelease`: GitHub Release 상태. 둘 다 `false`일 때만 stable Sparkle appcast와 Pages deployment를 실행

workflow가 생성하거나 게시하는 주요 산출물:

- signed/notarized universal `alhangeul-macos-<version>.dmg`
- DMG `.sha256`
- GitHub Release body 후보
- `delta-checklist-<version>.md`
- stable release일 때 generated `appcast.xml`
- stable release일 때 `docs/` + generated `appcast.xml` Pages artifact
- stable release일 때 `deploy-pages` deployment URL
- workflow summary의 release ref, delta checklist, core lock, public artifact, GitHub Release state, Sparkle appcast, Pages artifact, GitHub Pages deployment 섹션

## Docs-only Pages Deploy

`Docs-only Pages Deploy`는 release workflow와 무관한 일반 `docs/**` 변경을 public GitHub Pages에 반영하는 workflow다.

유지해야 하는 조건:

- `push` to `main` with `docs/**` 변경에서 실행
- `workflow_dispatch` 수동 실행 가능
- workflow 내부에서 `GITHUB_REF=refs/heads/main`인지 확인하고, 다른 ref에서는 실패
- `github-pages` environment
- `pages: write`, `id-token: write`
- `concurrency.group: pages-deploy`, `cancel-in-progress: false`
- repository Pages source는 `workflow`
- `github-pages` environment는 `main` branch와 release tag `v*` deployment를 허용

workflow가 생성하거나 게시하는 주요 산출물:

- public `https://postmelee.github.io/alhangeul-macos/appcast.xml`에서 내려받은 preserved appcast
- `docs/` + preserved public `appcast.xml` Pages artifact
- `deploy-pages` deployment URL
- workflow summary의 deployment ref, public appcast, Pages artifact, GitHub Pages deployment 섹션

동작 기준:

- docs-only workflow는 Sparkle appcast를 새로 생성하지 않는다.
- repository의 `docs/appcast.xml`은 stale copy일 수 있으므로 docs-only artifact source로 사용하지 않는다.
- public appcast 다운로드, 빈 파일 검증, `xmllint --noout` 검증 중 하나라도 실패하면 Pages deployment를 중단한다.
- stale repository appcast fallback은 사용하지 않는다.
- release workflow의 `deploy-pages` job과 같은 `pages-deploy` concurrency group을 공유해 Pages deployment를 취소 없이 직렬화한다.

로컬 재현:

```bash
mkdir -p build.noindex/release
curl -fsSL https://postmelee.github.io/alhangeul-macos/appcast.xml \
  -o build.noindex/release/public-appcast.xml
xmllint --noout build.noindex/release/public-appcast.xml
scripts/ci/prepare-pages-artifact.sh \
  --docs-dir docs \
  --appcast build.noindex/release/public-appcast.xml \
  --output-dir build.noindex/release/pages-artifact
test -f build.noindex/release/pages-artifact/index.html
test -f build.noindex/release/pages-artifact/updates/index.html
xmllint --noout build.noindex/release/pages-artifact/appcast.xml
```

## rhwp Upstream Release Check

`rhwp Upstream Release Check`는 upstream `edwardkim/rhwp` release와 현재 `rhwp-core.lock`을 비교한다.

입력:

- `target_tag`: 비워두면 upstream latest release를 조회한다.
- `run_compatibility_check`: target이 lock과 다를 때 `scripts/update-rhwp-core.sh --check --channel stable --tag <tag>`를 실행할지 결정한다.

로컬 재현:

```bash
bash scripts/ci/check-rhwp-upstream-release.sh --help
bash scripts/ci/check-rhwp-upstream-release.sh --run-compatibility-check true
bash scripts/ci/check-rhwp-upstream-release.sh --target-tag <rhwp-tag> --run-compatibility-check true
```

## 실패 해석 기준

- `classify-changes` 실패: base/head ref나 변경 범위 helper 문제를 먼저 확인한다.
- `script-checks` 실패: shell syntax 또는 helper interface 회귀다. macOS build 전 수정한다.
- `macos-validation` 실패: 앱 build, XcodeGen 입력, shared Swift boundary, Rust lock, renderer smoke 중 하나가 깨진 것이다.
- `release-checks` 실패: release helper, release note template, delta checklist, Sparkle appcast XML 생성 경계가 깨진 것이다.
- `Release Rehearsal DMG` 실패: public release 전 packaging/release script 또는 ref delta 입력을 수정한다.
- `Release Publish DMG` 실패: public release 산출물 상태를 먼저 확인하고, 필요한 경우 GitHub Release asset/appcast/Pages/Homebrew 반영을 중단한다.
- `Docs-only Pages Deploy` 실패: public appcast 다운로드/XML 검증 실패, Pages artifact 조립 실패, `github-pages` environment policy, 또는 `deploy-pages` 실패를 먼저 확인한다. stale `docs/appcast.xml` fallback으로 우회하지 않는다.

실패 증상, 재현 조건, 원인, 재발 방지 절차가 명확해진 경우에만 `mydocs/troubleshootings/`에 별도 문서로 남긴다.
