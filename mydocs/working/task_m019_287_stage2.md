# Task M019 #287 Stage 2 완료 보고서

## 단계 목적

release compatibility check와 sync PR workflow의 upstream checkout이 Git LFS smudge 실패에 영향받지 않도록 source와 workflow의 checkout 지점을 보강한다.

이번 단계는 구현 단계이며, `rhwp-core.lock`, RustBridge dependency, bundled `rhwp-studio` asset은 변경하지 않았다.

## 산출물

| 파일 | 요약 |
|------|------|
| `scripts/update-rhwp-core.sh` | 임시 upstream repository에 `lfs.skipSmudge true` 설정, demo/stable checkout에 `GIT_LFS_SKIP_SMUDGE=1` 적용 |
| `.github/workflows/rhwp-upstream-sync-pr.yml` | upstream `git clone`과 target commit checkout에 `GIT_LFS_SKIP_SMUDGE=1` 적용, clone 후 local `lfs.skipSmudge true` 설정 |
| `mydocs/working/task_m019_287_stage2.md` | 본 Stage 2 구현/검증 보고서 |

## 본문 변경 정도 / 본문 무손실 여부

- 제품 앱 source 변경 없음.
- `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock` 변경 없음.
- bundled `Sources/HostApp/Resources/rhwp-studio` asset 변경 없음.
- CI/helper checkout 명령만 변경했다.

## 구현 내용

### `scripts/update-rhwp-core.sh`

임시 upstream repository 생성 직후 local config를 추가했다.

```text
git -C "$WORK_DIR" config lfs.skipSmudge true
```

demo/stable target checkout에는 명령 단위 환경 변수를 적용했다.

```text
GIT_LFS_SKIP_SMUDGE=1 git -C "$WORK_DIR" checkout -q --detach FETCH_HEAD
GIT_LFS_SKIP_SMUDGE=1 git -C "$WORK_DIR" checkout -q --detach "$TAG"
```

`git fetch`는 checkout smudge를 발생시키지 않으므로 기존 명령을 유지했다.

### `.github/workflows/rhwp-upstream-sync-pr.yml`

upstream clone과 target commit checkout에 같은 정책을 적용했다.

```text
GIT_LFS_SKIP_SMUDGE=1 git clone "$UPSTREAM_GIT_URL" "$upstream_dir"
git -C "$upstream_dir" config lfs.skipSmudge true
GIT_LFS_SKIP_SMUDGE=1 git -C "$upstream_dir" checkout --detach "${{ steps.resolve.outputs.target_commit }}"
```

이 변경은 workflow의 `Check out upstream rhwp` 단계에만 적용된다. 앱 저장소 checkout, workflow permissions, impact detection, build/sync/PR 생성 로직은 변경하지 않았다.

## 검증 결과

```bash
git status --short --branch
```

결과:

```text
## local/task287
 M .github/workflows/rhwp-upstream-sync-pr.yml
 M scripts/update-rhwp-core.sh
```

```bash
bash -n scripts/update-rhwp-core.sh
```

결과: 통과.

```bash
bash -n scripts/ci/check-rhwp-upstream-release.sh
```

결과: 통과.

```bash
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'
```

결과:

```text
Ignoring ffi-1.13.1 because its extensions are not built. Try: gem pristine ffi --version 1.13.1
parsed
```

YAML parse는 성공했다. `ffi-1.13.1` 메시지는 로컬 Ruby gem extension 경고이며, workflow parse 실패가 아니다.

```bash
git diff --check
```

결과: 통과.

## 잔여 위험

- Stage 2는 syntax와 YAML parse 중심 검증이다. 실제 `v0.7.13` checkout 재현은 Stage 3에서 수행한다.
- GitHub-hosted runner에서 schedule workflow가 같은 방식으로 통과하는지는 PR 이후 수동 재실행 또는 다음 schedule에서 확인해야 한다.
- sync PR workflow 후속 build 단계가 LFS 실제 content를 필요로 하면 별도 실패가 나타날 수 있다. 현재 impact detection 경로는 LFS 실제 content를 요구하지 않는 것으로 Stage 1에서 확인했다.

## 다음 단계 영향

Stage 3에서는 다음을 확인한다.

1. `scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13`가 외부 `GIT_LFS_SKIP_SMUDGE=1` 없이 통과하는지 확인한다.
2. `scripts/ci/check-rhwp-upstream-release.sh --target-tag v0.7.13 --run-compatibility-check true`가 통과하는지 확인한다.
3. sync PR workflow의 upstream checkout 대응 명령과 `detect-rhwp-studio-impact.sh`를 로컬에서 실행한다.

## 승인 요청

Stage 2 결과를 승인하면 Stage 3 `release check와 sync impact 경로 검증`으로 진행한다.
