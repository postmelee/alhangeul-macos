# Task M019 #287 Stage 1 완료 보고서

## 단계 목적

`rhwp Upstream Release Check`와 `rhwp Upstream Sync PR` workflow의 실패 경로를 확인하고, Stage 2에서 적용할 Git LFS smudge 비활성화 지점을 고정한다.

이번 단계는 조사와 보고 단계이며 source, workflow, lock, bundled asset은 변경하지 않았다.

## 확인 시각

- 2026-05-27 14:50 KST

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/working/task_m019_287_stage1.md` | 두 실패 run의 실패 지점, 현재 checkout 명령, LFS skip 적용 지점, 다음 단계 영향 정리 |

참조한 기존 파일:

| 파일 | 확인 내용 |
|------|----------|
| `scripts/update-rhwp-core.sh` | `fetch_target()`가 임시 upstream repository를 만든 뒤 `git checkout`으로 demo commit 또는 stable tag를 checkout |
| `.github/workflows/rhwp-upstream-sync-pr.yml` | `Check out upstream rhwp` 단계가 `git clone` 후 target commit으로 `git checkout --detach` 수행 |
| `scripts/ci/detect-rhwp-studio-impact.sh` | upstream checkout의 git diff path와 source/build input path를 사용하며 실패한 `pdf-large/` LFS 실제 content를 요구하지 않음 |

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경 없음.
- workflow 변경 없음.
- `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock` 변경 없음.
- bundled `rhwp-studio` asset 변경 없음.
- 신규 단계 보고서만 추가했다.

## 확인한 실패 경로

### `rhwp Upstream Release Check`

- 실패 run: `26491516266`
- 실패 job: `Compare rhwp-core.lock with upstream release`
- 실패 step: `Check upstream rhwp release`
- 실행 경로: `scripts/ci/check-rhwp-upstream-release.sh` -> `scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13`
- 현재 `scripts/update-rhwp-core.sh` 흐름:
  - `init_work_repo()`에서 임시 directory에 `git init` 후 upstream remote 추가
  - stable channel에서 `git fetch --depth 1 origin "refs/tags/$TAG:refs/tags/$TAG"`
  - `git -C "$WORK_DIR" checkout -q --detach "$TAG"`
- LFS smudge 발생 가능 지점: `git checkout`

### `rhwp Upstream Sync PR`

- 실패 run: `26491862455`
- 실패 job: `Create rhwp-studio sync PR candidate`
- 실패 step: `Check out upstream rhwp`
- 현재 workflow 흐름:
  - `git clone "$UPSTREAM_GIT_URL" "$upstream_dir"`
  - `git -C "$upstream_dir" checkout --detach "${{ steps.resolve.outputs.target_commit }}"`
- LFS smudge 발생 가능 지점: `git clone`의 기본 checkout, 후속 `git checkout --detach`

두 실패 로그 모두 다음 upstream LFS 객체 다운로드 실패를 기록했다.

```text
pdf-large/hwp3-sample10-hwp5-2022.pdf
This repository exceeded its LFS budget.
fatal: pdf-large/hwp3-sample10-hwp5-2022.pdf: smudge filter lfs failed
```

로컬 확인에서는 `GIT_LFS_SKIP_SMUDGE=1 scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13`이 통과했다. 따라서 실패는 `v0.7.13`의 필수 API 부재가 아니라 checkout 과정에서 LFS 실제 객체를 받으려 한 자동화 문제로 판단한다.

## LFS 실제 content 불필요 근거

`scripts/update-rhwp-core.sh --check`는 target checkout 후 `check_required_apis()`에서 다음 API 문자열을 `src` 아래에서 찾는다.

- `build_page_render_tree`
- `get_bin_data`
- `render_page_svg_native`
- `get_page_info_native`
- `extract_thumbnail_only`

이 경로는 `pdf-large/` fixture content가 필요하지 않다.

`rhwp-upstream-sync-pr.yml`의 다음 단계인 `Detect rhwp-studio impact`는 `scripts/ci/detect-rhwp-studio-impact.sh`에 upstream checkout 경로와 current/target tag/commit을 넘긴다. helper의 impact 판정은 다음 path 계열을 git diff 결과로 분류한다.

- `rhwp-studio/*`
- `pkg/*`
- `Cargo.toml`, `Cargo.lock`, `rust-toolchain*`, `.cargo/*`, `crates/*`, `src/*`
- `package.json`, lockfile, `vite.config.*`, `tsconfig*.json`
- font/license/provenance 관련 파일

실패한 `pdf-large/hwp3-sample10-hwp5-2022.pdf`의 실제 LFS content는 이 판정에 필요하지 않다. diff path 확인에는 LFS pointer checkout만으로 충분하다.

## Stage 2 적용 지점

Stage 2 수정 범위는 두 checkout 경로로 한정한다.

### `scripts/update-rhwp-core.sh`

- `init_work_repo()`에서 임시 upstream repository 생성 직후 `git -C "$WORK_DIR" config lfs.skipSmudge true`를 설정한다.
- demo channel의 `git checkout -q --detach FETCH_HEAD`에 `GIT_LFS_SKIP_SMUDGE=1`을 적용한다.
- stable channel의 `git checkout -q --detach "$TAG"`에 `GIT_LFS_SKIP_SMUDGE=1`을 적용한다.
- `git fetch`는 checkout smudge를 발생시키지 않으므로 기존 명령을 유지한다.

### `.github/workflows/rhwp-upstream-sync-pr.yml`

- `git clone "$UPSTREAM_GIT_URL" "$upstream_dir"`에 `GIT_LFS_SKIP_SMUDGE=1`을 적용한다.
- clone 후 `git -C "$upstream_dir" config lfs.skipSmudge true`를 설정한다.
- 후속 `git -C "$upstream_dir" checkout --detach <target>`에도 `GIT_LFS_SKIP_SMUDGE=1`을 적용한다.

이 방식은 앱 저장소 checkout이나 runner 전역 Git 설정을 바꾸지 않고, upstream 임시 checkout 경로에만 적용된다.

## 검증 결과

```bash
git status --short --branch
```

결과: `## local/task287`, Stage 1 조사 전 미커밋 변경 없음.

```bash
rg -n "fetch_target|init_work_repo|git clone|git -C .*checkout|detect-rhwp-studio-impact|pdf-large|lfs" \
  scripts/update-rhwp-core.sh .github/workflows/rhwp-upstream-sync-pr.yml scripts/ci/detect-rhwp-studio-impact.sh
```

결과:

```text
scripts/update-rhwp-core.sh:309:init_work_repo() {
scripts/update-rhwp-core.sh:315:fetch_target() {
scripts/update-rhwp-core.sh:323:    git -C "$WORK_DIR" checkout -q --detach FETCH_HEAD
scripts/update-rhwp-core.sh:329:    git -C "$WORK_DIR" checkout -q --detach "$TAG"
.github/workflows/rhwp-upstream-sync-pr.yml:184:          git clone "$UPSTREAM_GIT_URL" "$upstream_dir"
.github/workflows/rhwp-upstream-sync-pr.yml:185:          git -C "$upstream_dir" checkout --detach "${{ steps.resolve.outputs.target_commit }}"
.github/workflows/rhwp-upstream-sync-pr.yml:194:          scripts/ci/detect-rhwp-studio-impact.sh \
```

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- Stage 1은 조사와 적용 지점 확정만 수행했으므로 CI 실패는 아직 수정되지 않았다.
- `rhwp-upstream-sync-pr.yml` 후속 build 단계가 예상과 달리 LFS 실제 content를 필요로 하면 Stage 3 검증 이후 별도 보강이 필요할 수 있다.
- GitHub-hosted schedule workflow 재실행은 로컬에서 완전히 대체할 수 없다. PR 이후 수동 재실행 또는 다음 schedule 확인이 필요하다.
- LFS smudge skip은 upstream 대용량 fixture의 실제 content를 검증하지 않는다는 뜻이다. 이번 작업은 release 감시와 sync PR 자동화 안정화가 목적이므로 이 제한은 허용 범위로 둔다.

## 다음 단계 영향

Stage 2에서는 실제 source/workflow 변경을 수행한다.

1. `scripts/update-rhwp-core.sh` 임시 upstream repository에 `lfs.skipSmudge true`를 설정한다.
2. `scripts/update-rhwp-core.sh`의 demo/stable checkout에 `GIT_LFS_SKIP_SMUDGE=1`을 적용한다.
3. `.github/workflows/rhwp-upstream-sync-pr.yml`의 upstream `git clone`과 target `git checkout`에 `GIT_LFS_SKIP_SMUDGE=1`을 적용한다.
4. shell syntax, workflow YAML parse, `git diff --check`를 실행한다.

## 승인 요청

Stage 1 결과를 승인하면 Stage 2 `upstream checkout LFS smudge 비활성화 구현`으로 진행한다.
