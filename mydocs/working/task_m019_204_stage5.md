# Task M019 #204 Stage 5 보고서

## 단계 목표

자동 생성되는 bundled `rhwp-studio` 업데이트 PR이 필요한 PR CI gate를 실행하도록 변경 범위 분류와 PR CI helper 검사를 보강하고, upstream sync PR 운영 기준을 매뉴얼에 기록한다.

## 확인 시각

- 2026-05-17 09:49 KST

## 변경 요약

### PR CI 보강

`.github/workflows/pr-ci.yml`을 갱신했다.

- `script-checks`의 helper interface 검사에 신규 helper와 sync/verify script의 `--help`를 추가했다.
- `macos-validation`에 `scripts/verify-rhwp-studio-assets.sh` 실행 단계를 추가했다.
- 자동 sync PR이 `Sources/HostApp/Resources/rhwp-studio/**`를 바꾸면 HostApp build 전에 bundled manifest와 entrypoint asset 경계를 확인한다.

`scripts/ci/classify-pr-changes.sh`를 갱신했다.

- `Sources/HostApp/Resources/rhwp-studio/**` 변경을 명시 분류한다.
- 해당 경로는 `run_macos_build=true`, `run_rust_verify=true`, `run_release_checks=true`를 켠다.
- 이유는 HostApp bundled asset, `rhwp` release provenance, release note/release handoff에 동시에 영향을 주기 때문이다.

### 운영 문서 갱신

`mydocs/manual/ci_workflow_guide.md`에 다음 내용을 추가했다.

- `rhwp Upstream Sync PR` workflow map 항목
- bundled `rhwp-studio` 변경의 PR CI flag 기준
- PR CI 로컬 재현 명령의 신규 helper `--help`
- macOS validation 재현 명령의 bundled asset 검증
- `rhwp Upstream Sync PR` trigger, 권한, branch, input, 산출물, 실패 해석 기준

`mydocs/manual/core_dependency_operation_guide.md`를 갱신했다.

- 현재 core pin 기준을 `v0.7.11` / `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`로 정정했다.
- `rhwp-core.lock`과 bundled `rhwp-studio` manifest provenance의 역할을 구분했다.
- sync workflow가 `update-rhwp-core.sh --check`를 실행하지만 `rhwp-core.lock`을 자동 수정하지 않는다는 경계를 명시했다.

`mydocs/manual/release_distribution_guide.md`를 갱신했다.

- 신규 impact/body helper, sync/verify script, upstream check/sync workflows를 release 자산 목록에 추가했다.
- 자동 sync PR은 public release가 아니며 DMG, GitHub Release, Sparkle appcast, Homebrew Cask 변경을 만들지 않는다고 명시했다.

`mydocs/orders/20260517.md`의 #204 비고를 Stage 5 상태에 맞게 갱신했다.

## 검증 결과

### shell syntax

```bash
bash -n scripts/ci/classify-pr-changes.sh scripts/ci/check-rhwp-upstream-release.sh scripts/ci/detect-rhwp-studio-impact.sh scripts/ci/prepare-pages-artifact.sh scripts/ci/write-rhwp-studio-sync-pr-body.sh scripts/ci/write-sparkle-appcast.sh scripts/sync-rhwp-studio.sh scripts/verify-rhwp-studio-assets.sh
```

결과: 통과.

### workflow YAML과 actionlint

```bash
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
actionlint
```

결과: 통과.

Ruby 실행 중 local gem 경고 `Ignoring ffi-1.13.1 because its extensions are not built`가 출력됐지만, workflow YAML parse는 모두 성공했다.

### helper interface

```bash
bash scripts/ci/classify-pr-changes.sh --help
bash scripts/ci/check-rhwp-upstream-release.sh --help
bash scripts/ci/detect-rhwp-studio-impact.sh --help
bash scripts/ci/prepare-pages-artifact.sh --help
bash scripts/ci/write-rhwp-studio-sync-pr-body.sh --help
bash scripts/ci/write-sparkle-appcast.sh --help
bash scripts/sync-rhwp-studio.sh --help
bash scripts/verify-rhwp-studio-assets.sh --help
```

결과: 모두 통과.

### bundled asset 검증

```bash
scripts/verify-rhwp-studio-assets.sh
```

결과:

```text
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

### PR CI classification

```bash
scripts/ci/classify-pr-changes.sh devel HEAD
```

결과:

| flag | value |
|------|-------|
| `docs_only` | `false` |
| `run_macos_build` | `true` |
| `run_rust_verify` | `true` |
| `run_render_smoke` | `false` |
| `run_release_checks` | `true` |

추가로 `Sources/HostApp/Resources/rhwp-studio/assets/index-test.js` 같은 nested resource path가 `Sources/HostApp/Resources/rhwp-studio/*` case pattern에 매칭되는 것을 확인했다.

### whitespace

```bash
git diff --check
```

결과: 통과.

## 로컬에서 확인하지 못한 항목

다음은 workflow가 default branch에 merge된 뒤 GitHub-hosted runner와 repository 권한으로 확인해야 한다.

- scheduled `rhwp Upstream Sync PR` 활성화
- `contents: write` 권한으로 `automation/rhwp-<tag>-studio-sync` branch push
- `pull-requests: write` 권한으로 `gh pr create`
- `issues: write` 권한으로 assignee/reviewer 지정
- `rhwp-upstream-sync-pr` concurrency queueing 동작
- 실제 upstream release가 생겼을 때 Docker/npm/Vite build 전체 성공 여부

## Stage 6 진입 조건

Stage 6에서는 전체 #204 변경의 로컬 최종 검증과 최종 보고서를 정리한다. 최종 단계에서도 GitHub-hosted runner 전용 확인 항목은 잔여 확인으로 남긴다.
