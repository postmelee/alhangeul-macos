# Task M019 #204 Stage 2 보고서

## 단계 목표

upstream target release와 현재 bundled `rhwp-studio` manifest 기준 commit 사이의 변경 파일을 비교하고, 그 변경이 viewer/WASM/core에 영향을 주는지 판정하는 helper를 추가한다.

## 확인 시각

- 2026-05-17 09:28 KST

## 변경 요약

신규 helper `scripts/ci/detect-rhwp-studio-impact.sh`를 추가했다.

helper는 upstream `edwardkim/rhwp` checkout을 입력으로 받아 current commit과 target commit 사이의 changed paths를 만들고, viewer 영향 path만 별도 파일로 분리한다. GitHub Actions step 간 전달을 위해 `GITHUB_OUTPUT` 또는 `--github-output` 파일에 결과 값을 기록할 수 있다.

## helper 인터페이스

```bash
scripts/ci/detect-rhwp-studio-impact.sh \
  --upstream-dir <path> \
  --current-tag <tag> \
  --current-commit <commit> \
  --target-tag <tag> \
  --target-commit <commit> \
  [--output-dir <path>] \
  [--github-output <path>]
```

주요 output:

| output | 의미 |
|--------|------|
| `current_tag` | 현재 bundled release tag |
| `current_commit` | upstream checkout에서 resolve한 current commit |
| `target_tag` | target upstream release tag |
| `target_commit` | upstream checkout에서 resolve한 target commit |
| `has_viewer_impact` | viewer/WASM/core 영향 path 존재 여부 |
| `changed_paths_file` | current..target 전체 changed path 목록 |
| `impact_paths_file` | 영향 path 목록 |
| `impact_details_file` | 영향 path와 reason TSV |
| `impact_reason_count` | 영향 path count |

기본 output directory는 `build.noindex/rhwp-upstream-impact`이다.

## impact path 기준

Stage 2 기준은 보수적으로 잡았다.

| path 기준 | reason |
|-----------|--------|
| `rhwp-studio/*` | `rhwp-studio` source 또는 build input |
| `pkg/*` | WASM package output |
| `Cargo.toml`, `Cargo.lock`, `rust-toolchain*`, `.cargo/*`, `crates/*`, `src/*` | Rust/core source 또는 build input |
| `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lockb`, `vite.config.*`, `tsconfig*.json` | repository-level web build input |
| `fonts/*`, `font/*`, `LICENSE*`, `COPYING*`, `NOTICE*`, `THIRD_PARTY*`, `licenses/*` | font/license/provenance input |

이 기준은 `rhwp-studio/**`만 보는 방식보다 넓다. UI 파일 변경이 없어도 WASM/core 변경이 bundled viewer 동작에 영향을 줄 수 있기 때문이다.

## 검증 결과

### syntax와 help

```bash
bash -n scripts/ci/detect-rhwp-studio-impact.sh
scripts/ci/detect-rhwp-studio-impact.sh --help
bash -n scripts/ci/check-rhwp-upstream-release.sh
bash scripts/ci/check-rhwp-upstream-release.sh --help
git diff --check
```

결과: 모두 통과.

### no-change 경로

현재 repository를 임시 upstream checkout처럼 사용해 `HEAD..HEAD`를 비교했다.

```bash
scripts/ci/detect-rhwp-studio-impact.sh \
  --upstream-dir . \
  --current-tag v0.7.11 \
  --current-commit HEAD \
  --target-tag v0.7.11 \
  --target-commit HEAD \
  --output-dir build.noindex/rhwp-impact-self-test
```

결과:

```text
changed paths: 0
impact paths: 0
has_viewer_impact=false
impact_reason_count=0
```

### positive impact 경로

`build.noindex/` 아래 임시 git repository를 만들고 `rhwp-studio/src/App.tsx` 변경 commit을 추가해 비교했다.

결과:

```text
changed paths: 1
impact paths: 1
has_viewer_impact=true
impact_reason_count=1
impact path: rhwp-studio/src/App.tsx (rhwp-studio source or build input)
```

### GitHub output 파일 기록

`--github-output build.noindex/rhwp-impact-self-test/github-output.txt`를 지정해 output file 기록을 확인했다.

결과:

```text
current_tag=v0.7.11
has_viewer_impact=false
impact_reason_count=0
changed_paths_file=build.noindex/rhwp-impact-self-test/changed-v0.7.11-to-v0.7.11.txt
impact_paths_file=build.noindex/rhwp-impact-self-test/impact-v0.7.11-to-v0.7.11.txt
impact_details_file=build.noindex/rhwp-impact-self-test/impact-details-v0.7.11-to-v0.7.11.tsv
```

## Stage 3 진입 조건

Stage 3에서는 `scripts/sync-rhwp-studio.sh`와 `scripts/verify-rhwp-studio-assets.sh`가 target tag/commit을 인자로 받을 수 있게 개선한다. Stage 2 helper의 `has_viewer_impact=true`가 Stage 4 workflow에서 sync script 실행 여부를 판단하는 gate가 된다.

## 잔여 위험

- 실제 upstream `edwardkim/rhwp` checkout의 전체 path 구조는 새 release가 나온 뒤 다시 확인해야 한다. Stage 2의 path 기준은 보수적 초안이며, false positive는 허용하지만 false negative를 줄이는 방향이다.
- release tag의 `targetCommitish`가 `main`으로 표시될 수 있으므로 workflow에서는 tag object 또는 tag ref를 실제 commit으로 resolve해야 한다.
- `impact_details_file`은 TSV 형식이므로 path에 tab 문자가 들어가는 극단적 경우는 지원하지 않는다. upstream repository의 일반 source path에서는 현실적 문제가 아니다.
