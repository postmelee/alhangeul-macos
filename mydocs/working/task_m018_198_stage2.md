# Task M018 #198 Stage 2 완료 보고서

## 단계 목적

PR 생성/갱신 시 실행되는 `pull_request` 기반 CI workflow를 추가하고, 변경 파일 범위에 따라 macOS build, Rust lock 검증, render smoke, release helper 검증을 조건부로 켜는 helper를 구현했다.

## 변경 요약

### `.github/workflows/pr-ci.yml`

- `pull_request` 대상 브랜치: `main`, `devel-webview`, `devel`
- 권한: `contents: read`
- 동시성: PR 번호 기준 `cancel-in-progress: true`
- `pull_request_target`은 사용하지 않는다.
- repository secrets, signing/notarization, GitHub Release publish, Pages/Appcast push는 실행하지 않는다.

| job | runner | 조건 | 역할 |
|-----|--------|------|------|
| `classify-changes` | `ubuntu-latest` | 모든 PR | 변경 파일을 분류하고 CI flag를 산출 |
| `script-checks` | `ubuntu-latest` | 모든 PR | shell syntax와 helper `--help` interface 확인 |
| `macos-validation` | `macos-15` | `run_macos_build == true` | AppKit boundary, Xcode project generate, HostApp Debug build |
| `release-checks` | `macos-15` | `run_release_checks == true` | release script/help, release note template, delta checklist, Sparkle appcast helper dry-run |

### `scripts/ci/classify-pr-changes.sh`

- 입력: `<base-ref> <head-ref>`
- `git diff --name-only "$base..$head"`로 변경 파일을 수집한다.
- GitHub Actions output:
  - `docs_only`
  - `run_macos_build`
  - `run_rust_verify`
  - `run_render_smoke`
  - `run_release_checks`
- `GITHUB_STEP_SUMMARY`가 있으면 변경 파일, flag, flag가 켜진 이유를 기록한다.
- 로컬 실행 시에는 summary를 stdout으로 출력한다.

## 분류 기준 결과

Stage 2 신규 파일을 포함한 임시 Git tree로 `devel-webview` 대비 분류를 dry-run했다.

```bash
scripts/ci/classify-pr-changes.sh devel-webview <stage2-temporary-commit>
```

결과 요약:

| Flag | Value |
|------|-------|
| `docs_only` | `false` |
| `run_macos_build` | `false` |
| `run_rust_verify` | `false` |
| `run_render_smoke` | `false` |
| `run_release_checks` | `true` |

사유:

- `.github/workflows/pr-ci.yml`은 CI/release automation 변경이므로 docs-only가 아니며 release checks를 켠다.
- `scripts/ci/classify-pr-changes.sh`는 CI/release automation 변경이므로 docs-only가 아니며 release checks를 켠다.
- 앱/Swift/Rust/renderer 입력은 변경하지 않았으므로 macOS build, Rust verify, render smoke는 켜지지 않는다.

## 검증 결과

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/pr-ci.yml")'
```

결과: exit code 0. 로컬 Ruby 환경에서 `ffi` gem native extension 경고가 출력됐지만 YAML parse는 통과했다.

```bash
bash -n scripts/ci/classify-pr-changes.sh
bash -n scripts/ci/*.sh
```

결과: exit code 0.

```bash
bash scripts/ci/classify-pr-changes.sh --help
bash scripts/ci/check-rhwp-upstream-release.sh --help
bash scripts/ci/write-sparkle-appcast.sh --help
./scripts/release.sh --help
```

결과: 모두 exit code 0.

```bash
scripts/ci/write-release-notes.sh 0.1.1 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef build.noindex/release/release-notes-0.1.1.md
scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.1.md
```

결과: `Release note template check passed`.

```bash
scripts/ci/write-release-delta-checklist.sh v0.1.0 HEAD build.noindex/release/delta-checklist-0.1.1.md
```

결과: exit code 0.

```bash
scripts/ci/write-sparkle-appcast.sh --version 0.1.1 --build 2 --dmg-url https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.1/alhangeul-macos-0.1.1.dmg --length 1 --ed-signature dummy-ed-signature --release-notes-url https://postmelee.github.io/alhangeul-macos/updates/v0.1.1.html --pub-date "Fri, 08 May 2026 09:00:00 +0000" --minimum-system-version 12.0 --output build.noindex/release/appcast.xml
xmllint --noout build.noindex/release/appcast.xml
```

결과: exit code 0.

```bash
./scripts/check-no-appkit.sh
```

결과: `OK: shared Swift code has no AppKit/UIKit dependencies`.

```bash
git diff --check HEAD -- .github/workflows/pr-ci.yml scripts/ci/classify-pr-changes.sh
```

결과: 출력 없음, exit code 0.

## 미실행 검증

`xcodegen generate`와 `xcodebuild ... HostApp ... build`는 Stage 2에서 앱/Xcode 입력을 변경하지 않았고, 새 PR CI의 분류상 이번 변경은 `run_macos_build=false`로 평가되므로 로컬에서는 실행하지 않았다. 앱/Swift/Xcode/Rust/renderer 경로가 변경되는 PR에서는 `macos-validation` job이 해당 명령을 실행한다.

## 다음 단계 영향

Stage 3에서는 기존 `release-rehearsal.yml`, `release-publish.yml`의 보호 조건과 수동 실행 정책은 유지하면서, #185에서 만든 release delta checklist를 workflow input, summary, artifact에 연결한다.

## 승인 요청

Stage 2 산출물 승인을 요청한다.

승인 후 Stage 3 `Release rehearsal/publish workflow delta checklist 연결`로 진행한다.
