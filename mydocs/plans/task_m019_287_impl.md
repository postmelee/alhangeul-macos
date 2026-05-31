# Task M019 #287 구현계획서

수행계획서: `mydocs/plans/task_m019_287.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #287 rhwp upstream release check가 upstream LFS smudge 실패에 영향받지 않게 수정
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task287`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac`
- 기준 브랜치: `devel`
- 목표: upstream `edwardkim/rhwp` checkout 중 Git LFS 대용량 객체 다운로드가 실패해도 release check와 sync PR workflow가 필요한 source 확인을 계속할 수 있게 한다.

## 확인된 현재 상태

2026-05-27 기준 확인 결과:

- `rhwp Upstream Release Check` run `26491516266`은 `scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13` 실행 중 upstream checkout에서 실패했다.
- `rhwp Upstream Sync PR` run `26491862455`는 `.github/workflows/rhwp-upstream-sync-pr.yml`의 `Check out upstream rhwp` 단계에서 `git clone` checkout 중 실패했다.
- 두 실패 로그 모두 `pdf-large/hwp3-sample10-hwp5-2022.pdf` LFS 객체 다운로드 시도 후 `This repository exceeded its LFS budget` 메시지를 기록했다.
- `GIT_LFS_SKIP_SMUDGE=1 scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13`은 로컬에서 통과했고, target commit은 `b3e16ef212af81ef37d973ddb86d6816d3804642`로 확인됐다.
- `scripts/update-rhwp-core.sh`의 `fetch_target()`은 임시 git repository를 만든 뒤 `git checkout`으로 target commit/tag를 checkout한다.
- `.github/workflows/rhwp-upstream-sync-pr.yml`의 upstream checkout은 `git clone` 후 target commit으로 `git checkout --detach`한다.
- `scripts/ci/detect-rhwp-studio-impact.sh`는 upstream checkout의 git diff path와 source/build input path를 사용하며, 실패한 `pdf-large/` LFS 실제 content를 필요로 하지 않는다.

## 구현 원칙

- LFS smudge 비활성화는 upstream 임시 checkout 경로에만 적용한다.
- 앱 저장소 checkout이나 repository 전역 Git 설정은 바꾸지 않는다.
- `GIT_LFS_SKIP_SMUDGE=1`을 실제 smudge가 발생하는 `clone`/`checkout` 명령에 직접 적용한다.
- 가능하면 해당 임시 upstream repository에 `git config lfs.skipSmudge true`도 설정해 후속 checkout이 같은 정책을 유지하도록 한다.
- `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, bundled `rhwp-studio` asset은 갱신하지 않는다.
- 실제 자동 PR 생성, release publish, signing/notarization, Homebrew 배포는 수행하지 않는다.
- 검증은 로컬에서 가능한 release check와 upstream checkout/impact detection 경로까지 수행하고, GitHub-hosted schedule 재실행은 잔여 확인 항목으로 기록한다.

## Stage 1. 실패 경로와 LFS skip 적용 지점 확정

### 목표

두 workflow 실패 경로와 LFS smudge 발생 지점을 단계 보고서에 고정하고, 실제 구현 지점을 확정한다.

### 작업

- `scripts/update-rhwp-core.sh`의 `init_work_repo()`와 `fetch_target()` 호출 흐름을 확인한다.
- `.github/workflows/rhwp-upstream-sync-pr.yml`의 `Check out upstream rhwp` 단계와 후속 `Detect rhwp-studio impact` 입력을 확인한다.
- `detect-rhwp-studio-impact.sh`가 LFS 실제 content를 요구하지 않는지 path 기준으로 확인한다.
- Stage 2에서 적용할 방식은 다음으로 고정한다.
  - `scripts/update-rhwp-core.sh`: 임시 repository에 `lfs.skipSmudge true` 설정, checkout 명령에 `GIT_LFS_SKIP_SMUDGE=1` 적용
  - `rhwp-upstream-sync-pr.yml`: `git clone`과 후속 `git checkout --detach`에 `GIT_LFS_SKIP_SMUDGE=1` 적용, clone 후 upstream repository local config에 `lfs.skipSmudge true` 설정

### 예상 변경 파일

- `mydocs/working/task_m019_287_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "fetch_target|init_work_repo|git clone|git -C .*checkout|detect-rhwp-studio-impact|pdf-large|lfs" \
  scripts/update-rhwp-core.sh .github/workflows/rhwp-upstream-sync-pr.yml scripts/ci/detect-rhwp-studio-impact.sh
git diff --check
```

### 완료 기준

- Stage 1 보고서에 두 실패 run, 실패 명령, LFS skip 적용 지점, LFS content 불필요 근거가 기록된다.
- Stage 2에서 수정할 파일과 방식이 확정된다.

### 커밋 메시지

```text
Task #287 Stage 1: upstream checkout 실패 경로 정리
```

## Stage 2. upstream checkout LFS smudge 비활성화 구현

### 목표

release compatibility check와 sync PR workflow의 upstream checkout이 Git LFS smudge 실패에 영향받지 않도록 source/workflow를 수정한다.

### 작업

- `scripts/update-rhwp-core.sh`를 수정한다.
  - 임시 repository 생성 직후 `git -C "$WORK_DIR" config lfs.skipSmudge true`를 설정한다.
  - demo commit checkout과 stable tag checkout 모두 `GIT_LFS_SKIP_SMUDGE=1 git -C "$WORK_DIR" checkout ...` 형태로 실행한다.
  - fetch 명령은 smudge가 발생하지 않는 경로이므로 기존 동작을 유지하되, 필요하면 checkout 정책을 설명하는 짧은 주석을 추가한다.
- `.github/workflows/rhwp-upstream-sync-pr.yml`을 수정한다.
  - `git clone "$UPSTREAM_GIT_URL" "$upstream_dir"`를 `GIT_LFS_SKIP_SMUDGE=1 git clone ...` 형태로 변경한다.
  - clone 후 `git -C "$upstream_dir" config lfs.skipSmudge true`를 설정한다.
  - target commit checkout도 `GIT_LFS_SKIP_SMUDGE=1 git -C "$upstream_dir" checkout --detach ...` 형태로 변경한다.
- 변경은 checkout 단계에만 한정하고 downstream build/sync 로직은 변경하지 않는다.

### 예상 변경 파일

- `scripts/update-rhwp-core.sh`
- `.github/workflows/rhwp-upstream-sync-pr.yml`
- `mydocs/working/task_m019_287_stage2.md`

### 검증

```bash
git status --short --branch
bash -n scripts/update-rhwp-core.sh
bash -n scripts/ci/check-rhwp-upstream-release.sh
ruby -e 'require "psych"; Psych.parse_file(".github/workflows/rhwp-upstream-sync-pr.yml"); puts "parsed"'
git diff --check
```

### 완료 기준

- 두 upstream checkout 경로가 LFS smudge skip 정책을 명시적으로 적용한다.
- shell syntax와 workflow YAML parse 검증이 통과한다.
- `rhwp-core.lock`, RustBridge dependency, bundled `rhwp-studio` asset 변경이 없다.

### 커밋 메시지

```text
Task #287 Stage 2: upstream checkout LFS smudge 비활성화
```

## Stage 3. release check와 sync impact 경로 검증

### 목표

수정 후 `v0.7.13` release compatibility check와 sync PR upstream checkout/impact 판정 경로가 LFS 객체 다운로드 없이 통과하는지 확인한다.

### 작업

- `scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13`를 실행한다.
- `scripts/ci/check-rhwp-upstream-release.sh --target-tag v0.7.13 --run-compatibility-check true`를 실행한다.
- sync PR workflow의 upstream checkout 단계에 대응하는 로컬 명령을 실행한다.
  - `GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/edwardkim/rhwp.git build.noindex/rhwp-upstream`
  - `git -C build.noindex/rhwp-upstream config lfs.skipSmudge true`
  - `GIT_LFS_SKIP_SMUDGE=1 git -C build.noindex/rhwp-upstream checkout --detach b3e16ef212af81ef37d973ddb86d6816d3804642`
- 현재 bundled manifest의 tag/commit과 target tag/commit을 사용해 `scripts/ci/detect-rhwp-studio-impact.sh`를 실행한다.
- 검증 전후 로컬 `build.noindex/rhwp-upstream` 부산물은 재생성 가능 산출물로 취급하고, 정리 여부와 대상 경로를 Stage 3 보고서에 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m019_287_stage3.md`

### 검증

```bash
scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13
scripts/ci/check-rhwp-upstream-release.sh --target-tag v0.7.13 --run-compatibility-check true
rm -rf build.noindex/rhwp-upstream build.noindex/rhwp-upstream-impact
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/edwardkim/rhwp.git build.noindex/rhwp-upstream
git -C build.noindex/rhwp-upstream config lfs.skipSmudge true
GIT_LFS_SKIP_SMUDGE=1 git -C build.noindex/rhwp-upstream checkout --detach b3e16ef212af81ef37d973ddb86d6816d3804642
scripts/ci/detect-rhwp-studio-impact.sh \
  --upstream-dir build.noindex/rhwp-upstream \
  --current-tag "$(awk -F'\"' '/source_release_tag/ { print $4; exit }' Sources/HostApp/Resources/rhwp-studio/manifest.json)" \
  --current-commit "$(awk -F'\"' '/source_resolved_commit/ { print $4; exit }' Sources/HostApp/Resources/rhwp-studio/manifest.json)" \
  --target-tag v0.7.13 \
  --target-commit b3e16ef212af81ef37d973ddb86d6816d3804642 \
  --output-dir build.noindex/rhwp-upstream-impact
git status --short --branch
git diff --check
```

### 완료 기준

- release compatibility check가 명시적 외부 `GIT_LFS_SKIP_SMUDGE=1` 없이 통과한다.
- sync PR checkout 대응 명령이 LFS budget 초과 없이 target commit checkout까지 통과한다.
- impact detection이 upstream checkout을 입력으로 정상 종료한다.
- 검증 결과와 GitHub-hosted workflow 재실행 잔여 확인 항목이 Stage 3 보고서에 기록된다.

### 커밋 메시지

```text
Task #287 Stage 3: LFS skip checkout 경로 검증
```

## Stage 4. 최종 보고와 PR 준비

### 목표

작업 결과와 검증 한계를 최종 보고서에 정리하고 PR 게시 전 상태를 정리한다.

### 작업

- `mydocs/report/task_m019_287_report.md`를 작성한다.
- `mydocs/orders/20260527.md`의 #287 상태를 `완료`로 갱신한다.
- 실패 run 두 개와 수정 지점, 검증 명령 결과, 잔여 확인 항목을 보고서에 기록한다.
- `rhwp-core.lock`과 bundled `rhwp-studio` asset이 변경되지 않았음을 확인한다.
- PR 게시 전 `git status --short --branch`와 `git diff --check`를 실행한다.

### 예상 변경 파일

- `mydocs/report/task_m019_287_report.md`
- `mydocs/orders/20260527.md`

### 검증

```bash
git status --short --branch
git diff --check
git diff --name-only devel...HEAD
```

### 완료 기준

- 최종 보고서가 작성되고 오늘할일이 완료 처리된다.
- 작업 브랜치에 미커밋 변경이 없다.
- PR 게시 절차로 넘길 준비가 끝난다.

### 커밋 메시지

```text
Task #287 Stage 4 + 최종 보고서: LFS smudge 실패 회피 검증 정리
```

## 승인 요청 사항

1. 위 4단계 구현 계획 승인
2. Stage 1에서 실패 경로와 LFS skip 적용 지점을 보고서로 고정하는 작업 승인
3. Stage 2에서 `scripts/update-rhwp-core.sh`와 `.github/workflows/rhwp-upstream-sync-pr.yml`만 수정하는 방향 승인
4. Stage 3에서 `v0.7.13` release check와 sync PR checkout/impact 판정 경로를 네트워크 검증하는 방향 승인
5. 각 단계 완료 후 단계 보고서를 작성하고 승인받은 뒤 다음 단계로 진행하는 절차 승인

승인 전에는 source와 workflow 구현 변경을 진행하지 않는다.
