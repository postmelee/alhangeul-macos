# Task M018 #198 Stage 1 완료 보고서

## 단계 목적

기존 GitHub Actions workflow와 로컬 검증 스크립트를 대조해 PR CI에서 항상 실행할 검증, 변경 범위에 따라 조건부 실행할 검증, release rehearsal/publish에 남겨야 할 검증을 분리했다. 이 단계는 구현 전 경계 확정이며, workflow나 script는 아직 수정하지 않았다.

## 현재 workflow 상태

| workflow | trigger | runner | 권한/보호 | 현재 역할 | Stage 2~3 영향 |
|----------|---------|--------|-----------|-----------|----------------|
| `release-rehearsal.yml` | `workflow_dispatch` | `macos-15` | `contents: read`, secrets 없음 | `scripts/release.sh --skip-notarize`로 rehearsal DMG/checksum artifact 생성 | 기존 역할 유지. Stage 3에서 delta checklist summary/artifact만 추가 |
| `release-publish.yml` | `workflow_dispatch` | `macos-15` | `contents: write`, `environment: release`, Apple/Sparkle secrets 사용 | tag `v<version>` 검증, signed/notarized DMG, GitHub Release asset, stable appcast/Pages branch 갱신 | 자동 실행으로 바꾸지 않음. Stage 3에서 delta checklist summary/artifact만 추가 |
| `rhwp-upstream-check.yml` | `workflow_dispatch`, schedule | `ubuntu-latest` | `contents: read`, `GH_TOKEN`만 사용 | upstream `rhwp` 최신 release와 `rhwp-core.lock` 비교 | PR CI와 별도 유지. core update 감시 역할 |

현재 release workflow는 모두 manual/scheduled 성격이다. `pull_request`에서 실행되는 공통 gate가 없으므로 Stage 2에서 새 `pr-ci.yml`을 추가한다.

## PR CI job 경계

| job | runner | 실행 조건 | 역할 |
|-----|--------|-----------|------|
| `classify-changes` | `ubuntu-latest` | 모든 PR | 변경 파일을 분류하고 `docs_only`, `run_macos_build`, `run_rust_verify`, `run_render_smoke`, `run_release_checks` flag를 산출 |
| `script-checks` | `ubuntu-latest` | 모든 PR | shell script syntax와 helper `--help` 수준의 가벼운 검증. secrets 불필요 |
| `macos-validation` | `macos-15` | `run_macos_build == true` | `check-no-appkit.sh`, `xcodegen generate`, HostApp Debug build |
| `rust-verify` 또는 macOS step | `macos-15` | `run_rust_verify == true` | `rustup target add ...`, `./scripts/build-rust-macos.sh --verify-lock` |
| `render-smoke` 또는 macOS step | `macos-15` | `run_render_smoke == true` | `./scripts/validate-stage3-render.sh` |
| `release-checks` | `macos-15` 권장 | `run_release_checks == true` | `scripts/release.sh --help`, release note dry-run/template check, delta checklist, appcast helper syntax |

`release-checks`는 macOS runner를 쓰는 방향이 안전하다. `write-release-notes.sh`는 `plutil`로 `rhwp-studio` manifest를 읽고, `release.sh`는 macOS release pipeline script이므로 Ubuntu syntax-only 검증만으로 충분하지 않다.

## 변경 범위 분류 기준

| 범위 | 대표 path | flag | 실행 의도 |
|------|-----------|------|-----------|
| 일반 문서 | `README.md`, `mydocs/**`, `docs/assets/**`, 일반 문서성 `docs/**` | `docs_only=true` | macOS build 생략. 단, release 관련 문서면 `run_release_checks`를 별도로 켤 수 있음 |
| public Pages/appcast | `docs/updates/**`, `docs/appcast.xml`, `docs/index.html` | `docs_only=true`, `run_release_checks=true` | macOS build는 생략하되 release URL/template/appcast 경계 확인 |
| 앱/Swift/Xcode | `Sources/**`, `project.yml`, `Sources/*/Info.plist`, entitlements | `run_macos_build=true` | HostApp Debug build와 shared boundary 확인 |
| RustBridge/core/provenance | `RustBridge/**`, `rhwp-core.lock`, `Frameworks/**`, `scripts/build-rust-macos.sh`, `scripts/update-rhwp-core.sh`, `scripts/sync-rhwp-studio.sh`, `scripts/verify-rhwp-studio-assets.sh` | `run_macos_build=true`, `run_rust_verify=true` | Rust artifact/lock 정합성 확인 |
| renderer/fixture | `Sources/RhwpCoreBridge/**`, `Sources/Shared/**`, `Sources/QLExtension/**`, `Sources/ThumbnailExtension/**`, `samples/**`, `scripts/stage3_render_check.swift`, `scripts/validate-stage3-render.sh`, `scripts/render-debug-compare.sh` | `run_macos_build=true`, `run_render_smoke=true` | render tree/native renderer smoke 확인 |
| release script/workflow | `.github/workflows/**`, `scripts/release.sh`, `scripts/package-release.sh`, `scripts/create-dmg-background.swift`, `scripts/ci/**`, `scripts/update-cask-sha256.sh`, `Casks/**` | `run_release_checks=true` | release preflight, helper syntax, release note/delta/appcast 후보 확인 |
| release manual/record | `mydocs/manual/release*.md`, `mydocs/release/**`, `mydocs/tech/release_environment.md` | `docs_only=true`, `run_release_checks=true` | 매뉴얼과 release helper 기준이 어긋나지 않는지 확인 |

한 파일이 여러 범위에 걸치면 flag는 OR로 누적한다. 예를 들어 `Sources/RhwpCoreBridge/CGTreeRenderer.swift`는 앱 build와 render smoke를 모두 켠다.

## 항상 실행할 검증

| 검증 | 이유 | runner |
|------|------|--------|
| `bash -n` for shell scripts | syntax regression을 빠르게 탐지 | Ubuntu |
| `scripts/ci/* --help` 또는 dry-run 가능한 helper help | helper interface regression 탐지 | Ubuntu 또는 macOS |
| 변경 범위 summary | 리뷰어가 build 생략/실행 이유를 확인 | Ubuntu |

`write-release-notes.sh` dry-run은 `plutil`을 사용하므로 release 변경이 있을 때 macOS runner에서 실행한다.

## 조건부 검증

| 조건 | 검증 |
|------|------|
| `run_macos_build=true` | `./scripts/check-no-appkit.sh`, `xcodegen generate`, HostApp Debug build (`CODE_SIGNING_ALLOWED=NO`) |
| `run_rust_verify=true` | `rustup target add aarch64-apple-darwin x86_64-apple-darwin`, `./scripts/build-rust-macos.sh --verify-lock` |
| `run_render_smoke=true` | `./scripts/validate-stage3-render.sh` |
| `run_release_checks=true` | `./scripts/release.sh --help`, release note dry-run/template check, `write-release-delta-checklist.sh`, appcast helper syntax |

## release workflow 유지 조건

- `release-publish.yml`은 `workflow_dispatch`를 유지한다.
- `release-publish.yml`은 `environment: release`를 유지한다.
- `release-publish.yml`은 tag `v<version>` 검증을 유지한다.
- signed/notarized DMG, GitHub Release asset, Sparkle appcast, Pages branch push는 PR CI에서 실행하지 않는다.
- Stage 3 보강은 delta checklist 생성과 summary/artifact 연결에 한정한다.

## Stage 2 구현 입력

Stage 2의 `scripts/ci/classify-pr-changes.sh`는 최소 다음 output을 제공한다.

```text
docs_only
run_macos_build
run_rust_verify
run_render_smoke
run_release_checks
```

추가로 사람이 읽을 수 있는 summary에는 다음을 남긴다.

- 변경 파일 전체 목록
- 각 flag 값과 true가 된 이유
- docs-only로 macOS build를 생략한 경우 그 사유
- release checks가 켜진 경우 release helper/preflight 수동 재현 명령

## 검증 결과

구현계획서 Stage 1 검증 명령을 수행했다.

```bash
git status --short --branch
```

결과: `local/task198`에서 Stage 1 보고서 작성 전 clean 상태를 확인했다.

```bash
rg -n "workflow_dispatch|pull_request|environment: release|concurrency|GITHUB_STEP_SUMMARY|upload-artifact" .github/workflows
```

결과 요약:

- 기존 workflow에는 `pull_request` trigger가 없다.
- `release-rehearsal.yml`, `release-publish.yml`, `rhwp-upstream-check.yml` 모두 `workflow_dispatch` 기반이다.
- `release-publish.yml`은 `environment: release`와 step summary/appcast artifact/public DMG artifact 경로를 가진다.
- `release-rehearsal.yml`은 rehearsal DMG/checksum artifact 경로를 가진다.

```bash
rg -n "build-rust-macos|validate-stage3-render|check-no-appkit|write-release-delta-checklist|write-release-notes|write-sparkle-appcast" scripts mydocs/manual
```

결과 요약:

- build/run/release manual에 `build-rust-macos`, `check-no-appkit`, `validate-stage3-render` 기준이 이미 존재한다.
- #185 산출물인 `write-release-delta-checklist.sh`, `write-release-notes.sh`, `write-sparkle-appcast.sh`가 release communication/release workflow 입력으로 정리돼 있다.

```bash
git diff --check
```

결과: 출력 없음, exit code 0.

## 다음 단계 영향

Stage 2에서는 이 보고서의 flag와 path 분류표를 기준으로 `scripts/ci/classify-pr-changes.sh`와 `.github/workflows/pr-ci.yml`을 구현한다. Stage 3에서는 기존 release workflow의 보호 조건을 유지한 채 delta checklist 생성과 summary/artifact 연결만 추가한다.

## 승인 요청

Stage 1 산출물 승인을 요청한다.

승인 후 Stage 2 `PR CI workflow와 변경 범위 helper 구현`으로 진행한다.
