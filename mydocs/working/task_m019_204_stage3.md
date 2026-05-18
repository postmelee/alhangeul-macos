# Task M019 #204 Stage 3 보고서

## 단계 목표

자동화가 target release tag와 resolved commit을 입력으로 받아 bundled `rhwp-studio` asset 후보를 갱신할 수 있도록 `scripts/sync-rhwp-studio.sh`와 `scripts/verify-rhwp-studio-assets.sh`를 인자화한다.

## 확인 시각

- 2026-05-17 09:33 KST

## 변경 요약

### `scripts/verify-rhwp-studio-assets.sh`

기존 기본 호출을 유지하면서 다음 option을 추가했다.

```bash
scripts/verify-rhwp-studio-assets.sh [RESOURCE_DIR]
scripts/verify-rhwp-studio-assets.sh \
  --resource-dir <path> \
  --tag <rhwp-release-tag> \
  --commit <resolved-commit>
```

기본값:

- resource dir: `Sources/HostApp/Resources/rhwp-studio`
- expected tag: 대상 `manifest.json`의 `source_release_tag`
- expected commit: 대상 `manifest.json`의 `source_resolved_commit`

기존 positional resource dir 호출도 계속 지원한다.

### `scripts/sync-rhwp-studio.sh`

기존 upstream dir positional 호출을 유지하면서 다음 option을 추가했다.

```bash
scripts/sync-rhwp-studio.sh [UPSTREAM_DIR]
scripts/sync-rhwp-studio.sh \
  --upstream-dir <path> \
  --tag <rhwp-release-tag> \
  --commit <resolved-commit> \
  --target-dir <path> \
  --check
```

주요 변경:

- expected tag/commit 하드코딩을 제거했다.
- `--tag`, `--commit`이 없으면 현재 target manifest에서 기본값을 읽는다.
- 입력 commit을 upstream checkout 안에서 full commit으로 resolve하고, upstream checkout `HEAD`와 일치하는지 확인한다.
- `--check`는 실제 target을 수정하지 않고 `build.noindex/rhwp-studio-check.*` 임시 target에서 sync와 verify를 수행한다.
- `manifest.json`에는 resolve된 full commit을 기록한다.
- copied total bytes 계산은 macOS `stat -f` 의존 대신 Perl `-s` 기반으로 바꿔 GitHub-hosted runner 호환성을 높였다.
- sync 후 `verify-rhwp-studio-assets.sh --resource-dir --tag --commit`을 호출해 provenance를 명시 검증한다.

## 호환성 확인

유지되는 기존 호출:

```bash
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh Sources/HostApp/Resources/rhwp-studio
scripts/sync-rhwp-studio.sh <upstream-dir> --tag <tag> --commit <commit> --check
```

자동화용 신규 호출:

```bash
scripts/verify-rhwp-studio-assets.sh \
  --resource-dir Sources/HostApp/Resources/rhwp-studio \
  --tag v0.7.11 \
  --commit a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae

scripts/sync-rhwp-studio.sh \
  --upstream-dir <upstream-dir> \
  --tag <target-tag> \
  --commit <target-commit> \
  --check
```

## 검증 결과

### syntax와 help

```bash
bash -n scripts/sync-rhwp-studio.sh scripts/verify-rhwp-studio-assets.sh
scripts/sync-rhwp-studio.sh --help
scripts/verify-rhwp-studio-assets.sh --help
bash -n scripts/*.sh scripts/ci/*.sh
git diff --check
```

결과: 모두 통과.

### verify 기본/명시/positional 호출

```bash
scripts/verify-rhwp-studio-assets.sh
scripts/verify-rhwp-studio-assets.sh \
  --resource-dir Sources/HostApp/Resources/rhwp-studio \
  --tag v0.7.11 \
  --commit a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae
scripts/verify-rhwp-studio-assets.sh Sources/HostApp/Resources/rhwp-studio
```

결과: 모두 `OK: rhwp-studio assets verified ...`로 통과.

### sync `--check` dry-run

`build.noindex/` 아래 임시 upstream checkout을 만들고 현재 bundled resource를 `rhwp-studio/dist`로 복사했다. `pkg/rhwp.js`, `pkg/rhwp_bg.wasm`도 임시로 준비한 뒤 fake upstream commit을 만들어 `--check`를 실행했다.

```bash
scripts/sync-rhwp-studio.sh \
  --upstream-dir build.noindex/rhwp-sync-check-test-* \
  --tag v0.7.11 \
  --commit <fake-upstream-commit> \
  --check
```

결과:

```text
OK: rhwp-studio assets verified at .../build.noindex/rhwp-studio-check.*
OK: rhwp-studio sync check passed for v0.7.11 at <fake-upstream-commit>
```

legacy positional upstream dir 호출도 같은 방식으로 `--check`를 실행해 통과했다.

### 커밋 후 PR 분류 확인

Stage 3 커밋 후 다음 명령을 실행했다.

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

`scripts/sync-rhwp-studio.sh`, `scripts/verify-rhwp-studio-assets.sh` 변경이 macOS build와 Rust verify를 켜는 것으로 확인했다. 신규 `scripts/ci/detect-rhwp-studio-impact.sh`는 release checks를 켠다.

## Stage 4 진입 조건

Stage 4에서는 자동 PR body helper와 write-capable workflow를 추가한다. Stage 3 결과로 workflow는 target tag/commit을 명시해 `sync-rhwp-studio.sh --check` 또는 실제 sync를 호출할 수 있다.

## 잔여 위험

- `--check`는 sync와 verify의 파일 조립 경로를 검증하지만, 실제 upstream WASM build와 `rhwp-studio` build 자체를 수행하지는 않는다. Stage 4 workflow에서 upstream build 단계가 추가되어야 한다.
- `--check` 임시 target은 실행 종료 시 삭제되므로 결과 resource tree를 장기 보관하지 않는다. 실패 시에는 workflow log와 summary를 기준으로 원인을 확인해야 한다.
