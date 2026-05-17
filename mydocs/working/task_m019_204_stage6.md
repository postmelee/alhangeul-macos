# Task M019 #204 Stage 6 보고서

## 단계 목표

전체 upstream sync PR 자동화 변경을 로컬에서 가능한 범위까지 다시 검증하고, GitHub-hosted runner에서만 확인 가능한 항목과 검증 시점을 최종 보고서에 넘긴다.

## 확인 시각

- 2026-05-17 09:56 KST

## 변경 요약

### 실행 권한 보정

`scripts/ci/check-rhwp-upstream-release.sh`의 mode를 `100644`에서 `100755`로 보정했다.

Stage 6 계획서의 직접 실행 검증(`scripts/ci/check-rhwp-upstream-release.sh --help`)을 수행하던 중 permission denied가 발생했다. 기존 workflow와 PR CI는 `bash scripts/ci/check-rhwp-upstream-release.sh` 형태로 호출하므로 runtime 경로는 이미 동작했지만, 다른 sync helper와 동일하게 직접 실행 가능한 helper로 맞췄다.

## 검증 결과

### 기본 상태

```bash
git status --short --branch
```

결과: `local/task204`에서 Stage 6 mode 변경만 남은 상태로 검증을 시작했다.

### workflow YAML과 actionlint

```bash
ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path); puts "Parsed #{path}" }'
actionlint
```

결과: 통과.

Ruby 실행 중 local gem 경고 `Ignoring ffi-1.13.1 because its extensions are not built`가 출력됐지만, workflow YAML parse는 모두 성공했다.

### shell syntax

```bash
bash -n scripts/*.sh scripts/ci/*.sh
```

결과: 통과.

### helper interface

```bash
scripts/ci/check-rhwp-upstream-release.sh --help
scripts/ci/detect-rhwp-studio-impact.sh --help
scripts/ci/write-rhwp-studio-sync-pr-body.sh --help
scripts/sync-rhwp-studio.sh --help
scripts/verify-rhwp-studio-assets.sh --help
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

### impact helper no-change dry-run

```bash
scripts/ci/detect-rhwp-studio-impact.sh \
  --upstream-dir . \
  --current-tag v0.7.11 \
  --current-commit HEAD \
  --target-tag v0.7.11 \
  --target-commit HEAD \
  --output-dir build.noindex/task204-stage6-impact
```

결과:

| 항목 | 값 |
|------|----|
| changed paths | `0` |
| impact paths | `0` |
| has viewer impact | `false` |

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

### upstream release 조회

네트워크 제한 없는 실행으로 다음을 확인했다.

```bash
gh release view -R edwardkim/rhwp --json tagName,url,targetCommitish
scripts/ci/check-rhwp-upstream-release.sh --run-compatibility-check false
```

결과:

- upstream latest release: `v0.7.11`
- target URL: `https://github.com/edwardkim/rhwp/releases/tag/v0.7.11`
- current lock tag: `v0.7.11`
- current lock commit: `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`
- outdated: `false`
- compatibility status: `skipped_by_input`

### whitespace

```bash
git diff --check
```

결과: 통과.

## #214와 #204 잔여 로컬 한계 검증 시점

### #214

#214의 남은 항목은 docs-only Pages deployment의 실제 GitHub Actions 동작이다.

검증 시점:

1. #214 PR이 `devel`에 merge된 뒤 PR CI가 통과하는지 확인한다.
2. 해당 workflow 변경이 최종 public 배포 기준 branch인 `main`에 반영된 뒤 확인한다.
3. `main`의 `docs/**` 변경 push 또는 `Docs-only Pages Deploy` 수동 실행으로 `actions/upload-pages-artifact@v5`, `actions/deploy-pages@v5`, `pages-deploy` concurrency queueing을 확인한다.

정리하면 #214는 `devel` merge만으로 최종 검증이 끝나지 않는다. Pages deployment는 GitHub Pages가 실제 배포되는 `main` 반영 후 GitHub-hosted runner에서 확인하는 것이 정확하다.

### #204

#204의 남은 항목은 write-capable upstream sync PR workflow의 실제 repository 권한과 upstream build 동작이다.

검증 시점:

1. #204 PR이 `devel`에 merge된 뒤 PR CI에서 helper interface, macOS validation, release checks가 통과하는지 확인한다.
2. workflow 파일이 repository default branch에 반영된 뒤 `workflow_dispatch` dry-run으로 target 조회, impact detection, existing PR check, concurrency summary를 확인한다.
3. 이후 새 upstream `edwardkim/rhwp` release가 나오거나 `target_tag`를 명시한 수동 실행에서 `dry_run=false`로 branch push와 `gh pr create`를 확인한다.

정리하면 #204는 `devel` merge 후 PR CI 검증, default branch 반영 후 dry-run, 실제 target release가 있을 때 write-path 검증 순서로 나눠 확인한다.

## 로컬에서 확인하지 못한 항목

다음은 merge 후 GitHub-hosted runner와 repository 권한으로 확인해야 한다.

- `rhwp Upstream Sync PR` schedule 활성화
- `contents: write` 권한으로 `automation/rhwp-<tag>-studio-sync` branch push
- `pull-requests: write` 권한으로 `gh pr create`
- `issues: write` 권한으로 assignee/reviewer 지정
- `rhwp-upstream-sync-pr` concurrency queueing
- 실제 upstream release가 생겼을 때 Docker/npm/Vite build 전체 성공 여부

## 최종 보고서

Stage 6 결과를 `mydocs/report/task_m019_204_report.md`에 정리했다. 최종 보고서 승인 후 PR 게시 준비 단계로 넘어갈 수 있다.
