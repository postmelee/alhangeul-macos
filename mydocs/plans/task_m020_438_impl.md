# Task M020 #438 구현계획서

수행계획서: `mydocs/plans/task_m020_438.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서와 해당 단계 문서 변경을 함께 커밋하고, 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다. `local/task438`에는 PR #436의 제품 변경을 복제하지 않으며, latest `devel + PR #436` 제품 상태는 task 전용 임시 worktree에서만 검증한다.

## 작업 개요

- 이슈: #438 `rhwp v0.8.2 full sync와 최신 devel 통합 검증`
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task438`
- sync 후보: PR #436 `Sync rhwp upstream v0.8.2`
- sync head: `c9e55c83aaeb9e8104b446e8c15c14f0da40c770`
- upstream stable 기준: `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c`
- 현재 `devel` 시작 기준: `c968c1a4a059f31f5e9973900b276bbb00e452cb`
- 현재 앱 core/studio 기준: `v0.7.18` / `93862a4e16df59834ebce46d91e948cd739208e9`
- 후속 경계:
  - PR #436 merge는 최종 검증 보고 승인 뒤 별도 승인
  - public app version/build 확정과 배포는 별도 `Release Operations` 이슈

## 구현 전 확인 결론

| 항목 | 현재 상태 | 구현 판단 |
|------|-----------|-----------|
| PR #436 변경 | core lock, Rust dependency와 bundled studio/WASM 중심 17개 path | 유일한 sync 후보로 유지하고 타스크 브랜치에 중복 적용하지 않는다. |
| PR 생성 base | `09953414276c0f31e20193cd9c2f6aa4662df209` | 이 base에서 실행된 기존 CI만으로 current 결합 검증을 대체하지 않는다. |
| current `devel` | PR #437을 포함한 `c968c1a4a059f31f5e9973900b276bbb00e452cb` | Stage 1 시작 시 `origin/devel`을 다시 조회해 실제 base SHA를 재고정한다. |
| direct changed path overlap | PR #436과 PR #437 사이 없음 | merge conflict 가능성은 낮지만 runtime/ABI 호환성은 별도 검증한다. |
| upstream ancestry | `v0.7.18 → v0.7.19 → v0.8.0 → v0.8.2`, 각 비교 `behind 0` | PR #429와 PR #435를 재개하거나 순차 merge하지 않는다. |
| existing PR CI | classify, script syntax, macOS validation, release helper checks 통과 | current `devel` 결합을 검증한 녹색 결과로 과장하지 않는다. |
| external image 경로 | PR #437에서 Swift wrapper/resolver, QLExtension 연결과 24개 test 반영 | `v0.8.2` core와 다시 compile/link/test한다. |
| core 안정 기준 | stable release tag + resolved commit | `v0.8.2`와 `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` 쌍을 필수 gate로 둔다. |
| bundled studio | PR #436에서 같은 target commit으로 rebuild | manifest, entrypoint, WASM, service worker와 upstream root `Cargo.lock` fingerprint를 함께 확인한다. |
| task branch 변경 | 계획·단계·최종 보고 문서 | 제품 변경이 필요하면 자동 수정하지 않고 범위 보정 승인을 요청한다. |
| public release | 현재 공개 앱은 `v0.1.8`, 다음 version 미확정 | 이 타스크는 release handoff만 만들고 version bump·publish를 하지 않는다. |

## 공통 작업 원칙

1. 모든 단계 보고서에 `origin/devel` base SHA, PR #436 head SHA, 후보 구성 방식, 후보 identity를 기록한다.
2. Stage 1 이후 `origin/devel` 또는 PR #436 head가 바뀌면 기존 후보를 최신 결합 상태로 간주하지 않는다. changed path와 검증 재실행 범위를 먼저 보고한다.
3. PR #436의 GitHub merge ref는 첫 번째 parent가 Stage 1의 `origin/devel`, 두 번째 parent가 PR head와 정확히 일치할 때만 후보로 사용한다.
4. GitHub merge ref가 없거나 stale이면 임시 detached worktree에서 `origin/devel`에 PR head를 `--no-commit --no-ff`로 적용한다. 충돌이 생기면 수동 해결하지 않고 Stage 1을 중단한다.
5. 임시 worktree, upstream checkout과 검증 산출물은 task 전용 `/private/tmp/alhangeul-task438.*` 또는 해당 worktree의 `build.noindex/` 아래에만 둔다.
6. `local/task438`의 Stage 커밋에는 단계 보고서와 오늘할일 상태만 포함한다. PR #436의 lock·asset diff, generated framework, Xcode project와 build output은 포함하지 않는다.
7. `project.yml`을 Xcode project 원본으로 취급한다. `xcodegen generate` 결과는 후보 검증에만 사용하고 `Alhangeul.xcodeproj`의 tracked drift가 없는지 확인한다.
8. core source provenance, Cargo resolved commit, generated header와 FFI symbol은 blocking gate다. `librhwp.a` byte hash/size만 달라질 경우 toolchain 민감도를 분리해 portable verification을 추가로 실행한다.
9. external image 검증은 Rust C ABI, Swift wrapper, resolver policy, QLExtension load 연결을 구분한다. 경로·basename 등 개인정보성 값은 보고서에 기록하지 않는다.
10. actual Finder 등록 smoke는 signed/sealed Release package 기준으로만 실행한다. Debug build는 compile/link 검증에만 사용한다.
11. development extension 등록 cleanup, PR branch refresh, workflow rerun, PR merge 같은 mutation은 해당 단계 승인 범위를 확인한 뒤 수행한다.
12. 검증 실패가 source defect를 가리키면 제품 파일을 고치지 않는다. 실패 명령, 영향, 최소 변경 후보를 보고하고 수행·구현계획 보정 승인을 요청한다.

## 통합 후보 수명주기

### Ref 고정

Stage 1에서 다음 ref를 task 전용 remote-tracking ref로 가져온다.

```bash
git fetch origin \
  devel \
  refs/pull/436/head:refs/remotes/origin/pr-436-head \
  refs/pull/436/merge:refs/remotes/origin/pr-436-merge

TASK438_BASE_SHA="$(git rev-parse origin/devel)"
TASK438_PR_HEAD_SHA="$(git rev-parse refs/remotes/origin/pr-436-head)"
TASK438_MERGE_BASE_SHA="$(
  git merge-base "$TASK438_BASE_SHA" "$TASK438_PR_HEAD_SHA"
)"
```

명령 실행 시 실제 값은 Stage 1 보고서에 기록한다. `TASK438_PR_HEAD_SHA`가 승인된 `c9e55c83aaeb9e8104b446e8c15c14f0da40c770`에서 바뀌었으면 변경 이유와 diff를 다시 확인한다.

### 후보 모드 A: current GitHub merge ref

다음 두 parent 검사가 모두 통과할 때만 GitHub merge ref를 사용한다.

```bash
test "$(
  git rev-parse refs/remotes/origin/pr-436-merge^1
)" = "$TASK438_BASE_SHA"
test "$(
  git rev-parse refs/remotes/origin/pr-436-merge^2
)" = "$TASK438_PR_HEAD_SHA"
```

task 전용 parent directory를 `mktemp -d`로 만든 뒤 그 아래 non-existing child path에 detached worktree를 추가한다.

```bash
TASK438_WORKTREE_PARENT="$(
  mktemp -d /private/tmp/alhangeul-task438.XXXXXX
)"
TASK438_INTEGRATION_DIR="$TASK438_WORKTREE_PARENT/integration"
git worktree add --detach \
  "$TASK438_INTEGRATION_DIR" \
  refs/remotes/origin/pr-436-merge
```

이 모드의 후보 identity는 merge ref commit SHA와 두 parent SHA다.

### 후보 모드 B: local no-commit merge

merge ref가 없거나 parent가 current base/head와 다르면 current base에서 detached worktree를 만들고 PR head를 commit 없이 적용한다.

```bash
TASK438_WORKTREE_PARENT="$(
  mktemp -d /private/tmp/alhangeul-task438.XXXXXX
)"
TASK438_INTEGRATION_DIR="$TASK438_WORKTREE_PARENT/integration"
git worktree add --detach \
  "$TASK438_INTEGRATION_DIR" \
  "$TASK438_BASE_SHA"
git -C "$TASK438_INTEGRATION_DIR" merge \
  --no-commit \
  --no-ff \
  "$TASK438_PR_HEAD_SHA"
```

이 모드의 후보 identity는 base/head SHA 쌍, merge-base SHA와 staged tree다. `git -C "$TASK438_INTEGRATION_DIR" status --short`에는 PR #436 변경만 staged 상태로 존재해야 한다.

### 재사용과 정리

- Stage 1 보고서에 candidate mode, 절대 worktree path, base/head/merge identity를 기록한다.
- 후속 Stage는 환경 변수가 유지된다고 가정하지 않고 Stage 1 보고서와 `git worktree list`에서 exact path를 복원한다.
- 후보 source는 Stage 2~4 동안 유지하고 각 Stage 시작 시 identity와 tracked drift를 재검사한다.
- Stage 4가 끝나거나 후보를 폐기할 때 merge 진행 상태를 먼저 확인하고 task 전용 worktree만 `git worktree remove --force`로 제거한다.
- upstream checkout과 parent temp directory는 Stage 보고서에 기록된 exact absolute path를 확인한 뒤 task 종료 cleanup에서 제거한다.
- `refs/remotes/origin/pr-436-head`, `refs/remotes/origin/pr-436-merge`는 PR #436 검증이 끝난 뒤 local ref cleanup 대상으로만 처리한다. 원격 automation branch는 이 타스크에서 삭제하지 않는다.

## 판정 규칙

| 결과 | 판정 |
|------|------|
| merge conflict, tag/commit 불일치, Cargo resolved commit drift | blocking |
| generated header 또는 FFI symbol mismatch | blocking |
| bundled manifest/hash/entrypoint/WASM/service worker 불일치 | blocking |
| RustBridge test, ExternalImageTests, app/extension compile·link 실패 | blocking |
| document open/render 실패, empty bitmap, Hangul/text sanity 실패 | blocking |
| Quick Look/Thumbnail policy smoke row 실패 | blocking |
| actual Finder smoke에서 current provider 미등록 또는 HWP/HWPX output 실패 | blocking |
| strict staticlib hash만 mismatch, portable source/header/symbol 검증 통과 | non-blocking 후보이나 release handoff에 명시 |
| sandbox DNS/CoreSimulator/PlugInKit 환경 문제 | 같은 명령을 승인된 환경에서 재현해 source 실패와 분리 |
| upstream 사용자-facing 회귀 의심 | PR #436 merge 보류 후 별도 defect/upstream 대응 범위 제안 |

## Stage 1. PR·upstream 영향과 current 통합 후보 고정

### 목표

PR #436, current `devel`, upstream `v0.8.2`의 identity와 변경 범위를 고정하고 충돌 없는 격리 통합 후보를 만든다. 기존 CI가 검증한 범위와 이번에 추가로 검증할 범위를 분리하며, PR branch refresh 또는 CI 재실행 판단 기준을 확정한다.

### 대상

- GitHub PR #436 metadata, checks, merge ref
- `origin/devel`
- upstream release `v0.8.2`
- task 전용 임시 integration worktree
- `mydocs/working/task_m020_438_stage1.md`
- `mydocs/orders/20260728.md`

### 작업

1. `origin/devel`, PR head, GitHub merge ref를 fetch하고 base/head/merge-base SHA를 기록한다.
2. PR state, mergeability, visible check name·conclusion·execution time과 changed files 17개를 고정한다.
3. PR 생성 base `0995341` 이후 current `devel` 변경 path와 PR #436 path 교집합을 계산한다.
4. upstream `v0.7.18 → v0.7.19 → v0.8.0 → v0.8.2` ancestry와 target release metadata를 다시 확인한다.
5. GitHub merge ref parent가 current base/head와 일치하는지 확인한다.
6. parent가 일치하면 후보 모드 A, 그렇지 않으면 후보 모드 B로 task 전용 detached worktree를 만든다.
7. 후보 모드 B에서 merge conflict가 발생하면 파일을 수동 해결하지 않고 중단한다.
8. 후보의 PR diff가 #436 changed files와 일치하고 Task #409 source가 current base에서 보존됐는지 확인한다.
9. `scripts/update-rhwp-core.sh --check`로 `v0.8.2` stable compatibility를 read-only 확인한다.
10. 기존 PR CI가 current merge tree를 검증했는지 여부와 local validation만으로 충분한지 분리한다.
11. PR branch refresh, PR reopen, workflow rerun 중 어떤 mutation도 실행하지 않고 필요 여부와 권고만 Stage 1 보고서에 기록한다.

### 검증

```bash
gh pr view 436 --repo postmelee/alhangeul-macos \
  --json state,mergeable,mergeStateStatus,baseRefName,baseRefOid,headRefName,headRefOid,statusCheckRollup,files
gh release view v0.8.2 --repo edwardkim/rhwp \
  --json tagName,targetCommitish,publishedAt,url,body
git merge-base \
  refs/remotes/origin/devel \
  refs/remotes/origin/pr-436-head
git diff --name-status \
  09953414276c0f31e20193cd9c2f6aa4662df209..origin/devel
git worktree list --porcelain
git -C "$TASK438_INTEGRATION_DIR" status --short
cd "$TASK438_INTEGRATION_DIR"
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.8.2
git diff --check
git diff --cached --check
```

### 완료 조건

- current base, PR head, merge-base와 candidate identity가 full SHA로 기록돼 있다.
- 후보가 충돌 없이 구성되고 PR #436의 17개 path만 upstream sync diff로 식별된다.
- PR #437 이후 Task #409 source가 후보에 보존돼 있다.
- 기존 CI와 current-base 추가 검증 범위가 분리돼 있다.
- PR refresh/CI rerun 필요 여부와 다음 단계 승인 시 필요한 GitHub mutation이 명시돼 있다.
- product tracked file은 `local/task438`에 변경되지 않았다.

### 커밋

```text
Task #438 Stage 1: v0.8.2 통합 기준과 후보 구성 확정
```

## Stage 2. Core·bundled studio provenance와 artifact 검증

### 목표

격리 통합 후보의 native core와 bundled `rhwp-studio`가 동일한 `v0.8.2` tag/commit을 가리키는지 독립적으로 확인하고 source, Cargo lock, manifest, generated ABI와 reference artifact gate를 분리해 검증한다.

### 대상

- integration worktree의 `RustBridge/Cargo.toml`
- integration worktree의 `RustBridge/Cargo.lock`
- integration worktree의 `rhwp-core.lock`
- integration worktree의 `rhwp-ffi-symbols.txt`
- integration worktree의 `Sources/HostApp/Resources/rhwp-studio/**`
- task 전용 upstream `v0.8.2` checkout
- non-committed `Frameworks/**`
- `mydocs/working/task_m020_438_stage2.md`
- `mydocs/orders/20260728.md`

### 작업

1. Stage 1 candidate identity와 tracked source drift가 없는지 재검사한다.
2. `RustBridge/Cargo.toml` dependency가 `tag = "v0.8.2"`를 사용하는지 확인한다.
3. `RustBridge/Cargo.lock`의 rhwp package source와 resolved commit이 target commit과 일치하는지 확인한다.
4. `rhwp-core.lock`의 repo, ref kind, release tag, commit, features와 artifact metadata를 확인한다.
5. task 전용 `/private/tmp/alhangeul-task438.*` parent 아래 upstream `v0.8.2` checkout을 만들고 actual HEAD를 target commit과 비교한다.
6. upstream checkout에 Stage 4 external fixture 4개가 존재하는지 확인한다. target release에서 fixture가 제거·변경됐으면 과거 `v0.7.18` fixture로 조용히 대체하지 않고 Stage 2 결과에 기록한다.
7. upstream root `Cargo.lock` sha256을 계산해 bundled manifest의 `source_cargo_lock_sha256`와 일치하는지 확인한다.
8. bundled manifest tag/commit, files hash, entrypoint, WASM, service worker와 font asset 정합성을 검증한다.
9. Rust universal static library, generated header, generated symbols와 XCFramework를 lock 기준으로 검증한다.
10. strict `--verify-lock` 결과를 먼저 기록한다. strict 실패가 `librhwp.a` byte hash/size 하나로 제한될 때만 portable verification을 실행한다.
11. generated header/symbol, Cargo source, bundled asset mismatch는 portable skip 대상으로 취급하지 않는다.
12. build 후 후보의 tracked source에 새 drift가 없는지 확인한다.

### 검증

```bash
TASK438_UPSTREAM_PARENT="$(
  mktemp -d /private/tmp/alhangeul-task438-upstream.XXXXXX
)"
TASK438_UPSTREAM_DIR="$TASK438_UPSTREAM_PARENT/rhwp"
git clone \
  --depth 1 \
  --branch v0.8.2 \
  https://github.com/edwardkim/rhwp.git \
  "$TASK438_UPSTREAM_DIR"
test -f "$TASK438_UPSTREAM_DIR/samples/hwp3-sample10-hwpx.hwpx"
test -f "$TASK438_UPSTREAM_DIR/samples/oracle.gif"
test -f "$TASK438_UPSTREAM_DIR/samples/rdb02.gif"
test -f "$TASK438_UPSTREAM_DIR/samples/s1.jpg"
cd "$TASK438_INTEGRATION_DIR"
git -C "$TASK438_INTEGRATION_DIR" status --short
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.8.2
./scripts/build-rust-macos.sh --verify-lock
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 \
  ./scripts/build-rust-macos.sh --verify-lock
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh \
  --tag v0.8.2 \
  --commit 9b16aa9e23f476e2b335d7c029fc9f24a199d63c
test "$(
  git -C "$TASK438_UPSTREAM_DIR" rev-parse HEAD
)" = "9b16aa9e23f476e2b335d7c029fc9f24a199d63c"
test "$(
  shasum -a 256 "$TASK438_UPSTREAM_DIR/Cargo.lock" | awk '{print $1}'
)" = "$(
  /usr/bin/plutil -extract source_cargo_lock_sha256 raw -o - \
    Sources/HostApp/Resources/rhwp-studio/manifest.json
)"
git diff --check
```

strict `--verify-lock`가 통과하면 portable 명령은 교차 확인으로 기록한다. strict 명령이 오직 static archive byte reference 차이로 실패하면 그 출력은 진단 결과로 보존하고 portable 명령, source/header/symbol gate가 모두 통과해야 Stage 2를 완료할 수 있다.

### 완료 조건

- core와 studio가 모두 target `v0.8.2` / commit 쌍을 가리킨다.
- upstream root `Cargo.lock`과 manifest fingerprint가 일치한다.
- bundled asset manifest와 actual files가 모두 검증된다.
- source, Cargo, generated header, expected/generated FFI symbol gate가 통과한다.
- strict/portable static archive 결과와 toolchain 민감도가 구분돼 있다.
- integration candidate에 검증으로 인한 tracked drift가 없다.

### 커밋

```text
Task #438 Stage 2: v0.8.2 core와 bundled studio provenance 검증
```

## Stage 3. ABI·external image·앱 target 통합 검증

### 목표

`v0.8.2` core가 current RustBridge와 Task #409 external image Swift 경로를 유지하는지 test하고, HostApp과 두 extension의 compile/link 및 bundled studio resource 포함을 확인한다.

### 대상

- integration worktree의 `RustBridge/**`
- integration worktree의 `Sources/RhwpCoreBridge/**`
- integration worktree의 `Sources/Shared/HwpExternalImageResolver.swift`
- integration worktree의 `Sources/QLExtension/**`
- integration worktree의 `Sources/ThumbnailExtension/**`
- integration worktree의 `Tests/ExternalImageTests/**`
- integration worktree의 `project.yml`
- `build.noindex/DerivedDataTask438Stage3*`
- `mydocs/working/task_m020_438_stage3.md`
- `mydocs/orders/20260728.md`

### 작업

1. Stage 1 candidate identity와 Stage 2 generated framework가 유지되는지 확인한다.
2. Rust format과 locked RustBridge test를 실행한다.
3. `RhwpCoreBridge`의 AppKit/UIKit 금지와 build info/lock 정합성을 확인한다.
4. `xcodegen generate`로 project를 생성하고 project 원본인 `project.yml`과 결과 drift 여부를 확인한다.
5. `ExternalImageTests`를 실행해 status mapping, refs JSON, FFI buffer lifetime, basename-only resolver와 Preview open contract를 검증한다.
6. 현재 기준 24개 test의 pass/fail과 result bundle path를 기록한다. test 수가 달라지면 source diff와 test discovery를 확인한다.
7. HostApp, QLExtension, ThumbnailExtension을 각각 Debug compile/link한다.
8. HostApp app bundle에 bundled studio index, 단일 WASM, manifest와 required asset이 포함되는지 확인한다.
9. app bundle 안의 bundled studio copy도 verification script로 확인한다.
10. xcodegen/build 과정이 candidate의 tracked source를 바꾸지 않았는지 확인한다.

### 검증

```bash
cd "$TASK438_INTEGRATION_DIR"
cargo fmt --manifest-path RustBridge/Cargo.toml --check
cargo test --manifest-path RustBridge/Cargo.toml --locked
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ExternalImageTests \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask438Stage3Tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask438Stage3Host \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask438Stage3QL \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ThumbnailExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask438Stage3Thumbnail \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/verify-rhwp-studio-assets.sh \
  build.noindex/DerivedDataTask438Stage3Host/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
git diff --check
```

### 완료 조건

- locked RustBridge test와 no-AppKit/build-info gate가 통과한다.
- external image 24개 current test가 모두 통과하거나 변경된 test 수의 의도성이 증명된다.
- HostApp, QLExtension, ThumbnailExtension이 `v0.8.2` framework와 compile/link된다.
- HostApp bundle의 bundled studio copy가 source manifest와 일치한다.
- Xcode project와 candidate tracked source에 검증으로 인한 drift가 없다.
- source/test 실패와 sandbox·network 환경 실패가 분리돼 기록돼 있다.

### 커밋

```text
Task #438 Stage 3: v0.8.2 ABI와 앱 target 통합 검증
```

## Stage 4. Renderer·Finder surface 회귀와 release handoff

### 목표

대표 HWP/HWPX와 external sibling fixture에서 renderer와 policy smoke를 실행하고, 승인된 경우 Release package 기반 Finder 등록 smoke까지 확인한다. upstream 변화와 모든 검증 결과를 근거로 PR #436 merge 권고와 public release handoff를 확정한다.

### 대상

- repository representative samples
- upstream `v0.8.2` checkout의 external fixture
- integration worktree의 `build.noindex/task438-*`
- 필요 시 local Release package와 `$HOME/Applications/Alhangeul.app`
- upstream `v0.8.2` release note
- `mydocs/working/task_m020_438_stage4.md`
- `mydocs/orders/20260728.md`

### 작업

1. Stage 1 candidate identity와 Stage 2~3 tracked source 무손실 상태를 재검사한다.
2. HWP 세로/가로/다중 페이지, HWPX와 embedded image 대표 sample의 first-page render sanity를 실행한다.
3. Quick Look policy smoke에서 CoreGraphics와 Skia opt-in reply shape, backend/fallback, external resource count를 확인한다.
4. upstream checkout의 `samples/hwp3-sample10-hwpx.hwpx`, `oracle.gif`, `rdb02.gif`, `s1.jpg`를 task worktree의 `build.noindex/`로 복사해 valid sibling fixture를 만든다.
5. external fixture는 initial refs 3건, injected/loaded 3건, missing 0건과 non-empty render를 확인한다. 원본 checkout과 repository sample은 수정하지 않는다.
6. Thumbnail policy smoke에서 대표 5개 sample의 CoreGraphics/Skia render, cache miss/exactHit/largerBucketHit와 fallback을 확인한다.
7. source-level smoke 전후 extension registration hygiene를 check-only로 확인한다.
8. actual Finder smoke는 Stage 3 완료보고 승인 후 별도 확인을 받아 현재 source version `0.1.8` local Release package로 실행한다. 이 version은 smoke identity이며 다음 public version 확정이 아니다.
9. actual smoke를 실행하면 `$HOME/Applications/Alhangeul.app` 교체 범위, HWP/HWPX output, active provider path와 cleanup 결과를 기록한다.
10. development registration이 남으면 task 전용 개발 등록만 cleanup하고 check-only를 다시 통과시킨다. legacy/installed app 파일은 임의 삭제하지 않는다.
11. upstream release note를 bundled editor, parser/import/export, renderer, dependency/provenance와 앱 사용자-facing 영향으로 분류한다.
12. PR #436의 current merge readiness를 최종 재조회하고 local result와 GitHub check 경계를 정리한다.
13. blocking/non-blocking 결과, manual release smoke와 public release note 입력을 handoff로 작성한다.
14. integration worktree와 upstream checkout의 exact path를 검증한 뒤 task 전용 임시 산출물과 local refs의 cleanup 목록을 확정한다.

### 검증

```bash
cd "$TASK438_INTEGRATION_DIR"
mkdir -p build.noindex/task438-external-valid
ditto \
  "$TASK438_UPSTREAM_DIR/samples/hwp3-sample10-hwpx.hwpx" \
  build.noindex/task438-external-valid/hwp3-sample10-hwpx.hwpx
ditto \
  "$TASK438_UPSTREAM_DIR/samples/oracle.gif" \
  build.noindex/task438-external-valid/oracle.gif
ditto \
  "$TASK438_UPSTREAM_DIR/samples/rdb02.gif" \
  build.noindex/task438-external-valid/rdb02.gif
ditto \
  "$TASK438_UPSTREAM_DIR/samples/s1.jpg" \
  build.noindex/task438-external-valid/s1.jpg
./scripts/validate-stage3-render.sh \
  build.noindex/task438-stage4-render \
  samples/basic/KTX.hwp \
  samples/basic/request.hwp \
  samples/복학원서.hwp \
  samples/hwpx/hwpx-01.hwpx \
  samples/hwp-multi-001.hwp
./scripts/smoke-quicklook-skia-policy.sh \
  build.noindex/task438-stage4-quicklook \
  samples/basic/KTX.hwp \
  samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx \
  build.noindex/task438-external-valid/hwp3-sample10-hwpx.hwpx
./scripts/smoke-thumbnail-skia-policy.sh \
  build.noindex/task438-stage4-thumbnail \
  samples/복학원서.hwp \
  samples/basic/KTX.hwp \
  samples/basic/request.hwp \
  samples/hwpx/hwpx-01.hwpx \
  samples/hwp-multi-001.hwp
./scripts/check-extension-registration-hygiene.sh --check-only
gh pr view 436 --repo postmelee/alhangeul-macos \
  --json state,mergeable,mergeStateStatus,baseRefOid,headRefOid,statusCheckRollup
git diff --check
```

actual Finder smoke를 별도 승인받은 경우에만 다음 표준 흐름을 추가한다.

```bash
./scripts/package-release.sh 0.1.8
./scripts/smoke-clean-quicklook-install.sh \
  --skip-package \
  --app build.noindex/release/Alhangeul.app \
  --install-app "$HOME/Applications/Alhangeul.app" \
  --output-dir /private/tmp/alhangeul-task438-finder-smoke \
  --sample samples/basic/KTX.hwp \
  --sample samples/hwpx/hwpx-01.hwpx \
  --sample build.noindex/task438-external-valid/hwp3-sample10-hwpx.hwpx
./scripts/check-extension-registration-hygiene.sh --check-only
```

`$HOME/Applications/Alhangeul.app`의 기존 설치 상태와 replacement 영향은 실행 직전 다시 보고한다. `/Applications/Alhangeul.app`은 이 타스크 smoke 대상으로 선택하지 않는다.

### 완료 조건

- 대표 HWP/HWPX first-page render와 text/Hangul/non-white sanity가 통과한다.
- Quick Look policy smoke의 CoreGraphics/Skia 행과 external injection/render가 통과한다.
- Thumbnail 대표 smoke의 render/cache 행이 모두 통과하거나 fallback 사유가 blocking/non-blocking으로 판정돼 있다.
- actual Finder smoke를 승인받아 실행한 경우 current provider, HWP/HWPX/external fixture output과 cleanup이 확인돼 있다.
- actual Finder smoke를 실행하지 않은 경우 release blocking manual gate와 미실행 사유가 handoff에 남아 있다.
- development extension registration이 남지 않는다.
- PR #436의 merge 권고 또는 보류 근거가 current base/head SHA와 검증 결과로 정리돼 있다.
- public release 타스크가 사용할 upstream 변화, 필수 manual smoke와 잔여 위험이 정리돼 있다.
- `local/task438`에는 제품 source/asset diff가 없다.

### 커밋

```text
Task #438 Stage 4: v0.8.2 렌더 회귀와 release handoff 확정
```

## 최종 보고와 PR 경계

Stage 4 완료보고 승인 후 다음 순서로 진행한다.

1. `mydocs/report/task_m020_438_report.md`에 candidate identity, Stage 1~4 결과, strict/portable provenance, external image, renderer/Finder smoke, upstream 영향과 PR #436 권고를 정리한다.
2. 오늘할일을 완료 처리하고 실제 완료 시각을 기록한다.
3. 최종 보고서 승인 후에만 `task-final-report` 절차로 `local/task438` 문서 변경을 `publish/task438`에 push하고 `devel` 대상 PR을 만든다.
4. Task #438 PR은 검증 기록만 포함하며 PR #436의 17개 product diff를 포함하지 않는다.
5. Task #438 최종 보고·PR과 별개로, PR #436 actual merge는 작업지시자 별도 승인 후 실행한다.
6. PR #436 merge 확인 뒤 다음 app release version/build를 별도 `Release Operations` 이슈에서 확정한다.

## 단계별 승인 지점

1. 이 구현계획서 승인 후 Stage 1 metadata 조사와 task 전용 integration worktree 생성을 시작한다.
2. Stage 1 완료보고 승인 후에만 Stage 2 core/studio provenance와 framework build를 실행한다.
3. Stage 1에서 PR refresh 또는 CI 재실행이 필요하다고 판정해도 별도 승인 전에는 GitHub mutation을 수행하지 않는다.
4. Stage 2 완료보고 승인 후에만 Stage 3 Rust/Swift test와 app target build를 실행한다.
5. Stage 3 완료보고 승인 후 Stage 4 source-level renderer/policy smoke를 실행한다.
6. `$HOME/Applications/Alhangeul.app`을 사용하는 actual Finder 등록 smoke는 Stage 4 안에서 실행 직전 별도 승인을 확인한다.
7. Stage 4 완료보고 승인 후 최종 결과보고서를 작성한다.
8. 최종 결과보고서 승인 후 `task-final-report` 절차로 Task #438 PR을 게시한다.
9. Task #438 PR merge와 PR #436 merge는 별도 상태 확인과 승인 절차를 따른다.
10. PR #436 merge 확인 전에는 public release task, tag, signing/notarization 또는 publish workflow를 시작하지 않는다.

구현계획서 승인 전에는 integration worktree 생성, upstream checkout, core/framework build, app test, Finder 등록, PR branch/status 변경 또는 workflow 실행을 수행하지 않는다.
