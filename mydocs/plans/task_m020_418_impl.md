# Task M020 #418 구현계획서

수행계획서: `mydocs/plans/task_m020_418.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #418 `rhwp v0.7.18 full sync 재생성과 current devel 통합 검증`
- upstream release: `edwardkim/rhwp v0.7.18`
- target commit: `93862a4e16df59834ebce46d91e948cd739208e9`
- stale 자동 PR: #415 `Sync rhwp upstream v0.7.18`
- 관련 작업: #408 external image context C ABI, #406 HOP UTI compatibility, #396 visual regression baseline
- 마일스톤: M020 `v0.2.x Skia Quick Look/Thumbnail Backend`
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task418`
- 분리 worktree: `build.noindex/worktrees/task418`

## 구현 전 확인 결론

| 항목 | 확인 결과 | 계획 반영 |
|------|-----------|-----------|
| current core | `v0.7.17` / `03351190ec35436e58cbfee0aa9278a8fdc04a59` | `v0.7.18`로 갱신 필요 |
| target release | `v0.7.18` / `93862a4e16df59834ebce46d91e948cd739208e9` | stable tag + resolved commit으로 고정 |
| upstream main | target commit과 동일 | release 이후 floating 변경 없음 |
| PR #415 base | `devel` at `477447f` | current `devel`보다 17커밋 뒤처짐 |
| PR #415 상태 | `mergeable=false`, `mergeable_state=dirty` | 그대로 merge하지 않음 |
| 충돌 파일 | `rhwp-core.lock` | 한쪽 lock 선택 금지, 최신 source에서 재생성 |
| #415 CI | 4개 PR CI check 성공 | #408 merge 전 source이므로 current compatibility 근거로 재사용 금지 |
| #408 upstream API | `set_file_name`, `get_external_image_references`, `inject_external_image_by_key`가 target source에 존재 | 실제 RustBridge compile/test는 새 후보에서 재검증 |
| automation behavior | 열린 automation PR은 새 후보 생성을 막음 | #415 superseded 처리와 branch cleanup 뒤 재실행 필요 |
| task 기록 | 자동 PR branch와 `local/task418` 목적이 다름 | 자동 생성 diff를 task branch에 무커밋으로 가져와 Stage source/report로 커밋 |

## 구현 원칙

1. `rhwp Upstream Sync PR` workflow를 full sync 산출물의 생성 경로로 사용한다. core와 studio를 별도 수작업 결과로 조합하지 않는다.
2. #415의 commit, PR body, CI URL을 Stage 1 증적으로 보존한 뒤에만 superseded close와 branch 삭제를 수행한다.
3. remote close, branch delete, workflow dispatch는 Stage 1 완료보고 승인 후 Stage 2에서만 수행한다.
4. 새 자동 후보는 최신 `devel`에서 core와 bundled studio를 함께 생성해야 한다. target tag와 commit은 명시 input으로 고정한다.
5. 자동 후보 PR 자체를 #418 최종 PR로 사용하지 않는다. 생성된 sync commit을 `local/task418`에 `cherry-pick -n` 또는 동등한 무커밋 적용으로 가져와 단계 보고서와 한 커밋으로 묶는다.
6. task branch에 적용한 뒤 `build-rust-macos.sh --update-lock`을 다시 실행해 #408의 15개 symbol과 current source에서 생성한 artifact metadata가 일치하는지 확인한다.
7. bundled studio manifest의 `source_cargo_lock_sha256`은 target upstream root `Cargo.lock`과 직접 비교한다. 형식 검증만으로 통과 처리하지 않는다.
8. generated `Frameworks/**`, `Alhangeul.xcodeproj`, `build.noindex/**`는 검증 산출물로 사용하고 저장소 정책상 commit하지 않는다.
9. visual/performance 수치가 바뀌면 upstream 개선, 허용 가능한 drift, regression 후보로 분류한다. compile/build 성공만으로 Stage 4를 완료하지 않는다.
10. #409 이후 external image 제품 기능과 public release 실행은 이번 task에서 변경하지 않는다.

## 최종 변경 표면

자동 sync에서 예상하는 tracked product/provenance 변경:

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`
- 필요 시 `rhwp-ffi-symbols.txt`
- `Sources/HostApp/Resources/rhwp-studio/index.html`
- `Sources/HostApp/Resources/rhwp-studio/sw.js`
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`
- `Sources/HostApp/Resources/rhwp-studio/assets/**`

task 문서 변경:

- `mydocs/orders/20260716.md` 또는 실제 단계 진행일의 orders 문서
- `mydocs/plans/task_m020_418_impl.md`
- `mydocs/working/task_m020_418_stage1.md`
- `mydocs/working/task_m020_418_stage2.md`
- `mydocs/working/task_m020_418_stage3.md`
- `mydocs/working/task_m020_418_stage4.md`
- `mydocs/report/task_m020_418_report.md`

Stage 1에서 stale 내용이 확인될 때만 최소 범위로 갱신할 문서 후보:

- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/tech/core_release_compatibility.md`
- `mydocs/tech/project_architecture.md`

## Stage 1. v0.7.18 영향과 자동 후보 재생성 계약 확정

### 목표

#415와 current `devel`의 차이, upstream target API/dependency/studio 영향, workflow 재생성 조건을 read-only로 확정한다.

### 대상

- GitHub PR #415, upstream release/tag/source
- `.github/workflows/rhwp-upstream-sync-pr.yml`
- `scripts/update-rhwp-core.sh`
- `scripts/ci/detect-rhwp-studio-impact.sh`
- current lock/manifest/FFI files
- `mydocs/working/task_m020_418_stage1.md`
- orders 문서

### 작업

1. #415의 head/base SHA, changed files, checks, mergeability와 PR body를 다시 수집한다.
2. current `origin/devel`과 #415 branch의 merge-base, commit distance, conflict file을 고정한다.
3. upstream release/tag commit과 `main` 일치 여부를 다시 확인한다.
4. `v0.7.17..v0.7.18`의 core, WASM, studio, dependency, license/font 영향 경로를 분류한다.
5. target source에서 #408이 호출하는 세 API signature를 확인한다.
6. `update-rhwp-core.sh --check`로 current RustBridge가 target tag를 dependency 후보로 해석할 수 있는지 확인한다.
7. workflow existing PR blocker와 재실행 input을 확인한다.
8. #415를 superseded close하고 동일 automation branch를 삭제한 뒤 workflow를 재실행하는 방식을 Stage 2 계약으로 확정한다.
9. Stage 2 remote mutation 전에 보존할 URL/SHA/check inventory를 보고서에 기록한다.

### 검증

```bash
gh pr view 415 --repo postmelee/alhangeul-macos \
  --json number,state,headRefName,headRefOid,baseRefName,baseRefOid,mergeable,mergeStateStatus,files,statusCheckRollup,url
gh release view v0.7.18 --repo edwardkim/rhwp \
  --json tagName,targetCommitish,publishedAt,url,body
gh api repos/edwardkim/rhwp/commits/main --jq '.sha'
gh api repos/edwardkim/rhwp/commits/v0.7.18 --jq '.sha'
git fetch origin
git rev-list --left-right --count devel...origin/automation/rhwp-v0.7.18-full-sync
git merge-tree "$(git merge-base devel origin/automation/rhwp-v0.7.18-full-sync)" \
  devel origin/automation/rhwp-v0.7.18-full-sync
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.18
git diff --check
```

### 완료 조건

- #415를 그대로 merge할 수 없는 근거와 superseded 재생성 경로가 문서화되어 있다.
- target commit과 #408 API compatibility의 source-level 근거가 있다.
- Stage 2에서 수행할 원격 mutation, workflow input, 중단 조건이 확정되어 있다.
- 제품/core/studio tracked file은 변경되지 않았다.

### 커밋

```text
Task #418 Stage 1: v0.7.18 영향과 sync 재생성 계약 확정
```

## Stage 2. #415 superseded 처리와 최신 자동 full sync 후보 생성

### 목표

stale PR과 automation branch를 정리하고 최신 `devel` 기준의 새 full sync 후보를 생성해 원격 CI까지 완료한다.

### 대상

- GitHub PR #415
- `automation/rhwp-v0.7.18-full-sync` 원격 branch
- `rhwp Upstream Sync PR` workflow run과 새 automation PR
- `mydocs/working/task_m020_418_stage2.md`
- orders 문서

### 작업

1. #415에 #418 링크, stale base, 재생성 사유, 보존된 head SHA를 포함한 superseded 코멘트를 남긴다.
2. #415를 close한다.
3. 원격 automation branch를 삭제하고 삭제 결과를 확인한다.
4. `devel` ref에서 target tag를 명시해 full sync workflow를 실행한다.
5. workflow의 resolve, studio build, candidate creation 세 job을 완료까지 추적한다.
6. 새 automation PR 번호, head/base SHA, repository changed paths, provenance 값을 수집한다.
7. PR CI의 classify, script, release helper, macOS validation 결과를 확인한다.
8. workflow 또는 CI가 실패하면 같은 Stage 안에서 실패 원인을 조사하며, 기존 #415 diff를 대신 채택하지 않는다.

### 실행

```bash
gh pr comment 415 --repo postmelee/alhangeul-macos --body-file <validated-superseded-comment>
gh pr close 415 --repo postmelee/alhangeul-macos
git push origin --delete automation/rhwp-v0.7.18-full-sync
gh workflow run "rhwp Upstream Sync PR" \
  --repo postmelee/alhangeul-macos \
  --ref devel \
  -f target_tag=v0.7.18 \
  -f force_pr=false \
  -f dry_run=false
gh run watch <run-id> --repo postmelee/alhangeul-macos --exit-status
gh pr list --repo postmelee/alhangeul-macos \
  --base devel --head automation/rhwp-v0.7.18-full-sync --state open \
  --json number,headRefOid,baseRefOid,mergeable,mergeStateStatus,statusCheckRollup,url
```

### 완료 조건

- #415가 superseded 사유와 #418 링크를 남긴 채 closed 상태다.
- stale automation branch가 제거되고 최신 workflow가 새 branch/PR을 생성했다.
- 새 후보가 current `devel`을 base로 하고 core/studio 모두 target provenance를 기록한다.
- workflow와 PR CI가 모두 성공했거나 실패 원인이 단계 보고서에 명확히 기록되어 있다.

### 커밋

```text
Task #418 Stage 2: 최신 devel 기준 v0.7.18 sync 후보 생성
```

## Stage 3. 자동 후보를 task branch에 통합하고 provenance 고정

### 목표

새 automation candidate의 tracked sync diff를 `local/task418`에 가져와 #408 ABI와 core/studio provenance를 current task 기준으로 고정한다.

### 대상

- 새 `automation/rhwp-v0.7.18-full-sync` commit
- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`
- `rhwp-ffi-symbols.txt`
- `Sources/HostApp/Resources/rhwp-studio/**`
- `mydocs/working/task_m020_418_stage3.md`
- orders 문서

### 작업

1. 새 automation PR head를 fetch하고 base가 Stage 2 current `devel`인지 확인한다.
2. automation sync commit을 `cherry-pick -n`으로 task branch에 적용해 별도 upstream commit을 만들지 않는다.
3. changed path가 PR body와 실제 diff에서 일치하는지 확인한다.
4. `build-rust-macos.sh --update-lock`을 current task source에서 실행한다.
5. target tag/commit, 15개 expected/generated symbol, generated header와 lock artifact metadata를 확인한다.
6. bundled manifest tag/commit/entrypoint hash와 local overlay 보존을 확인한다.
7. upstream root `Cargo.lock` sha256을 manifest `source_cargo_lock_sha256`과 직접 비교한다.
8. source/provenance 변경과 Stage 3 보고서를 한 커밋으로 묶는다.

### 검증

```bash
git fetch origin automation/rhwp-v0.7.18-full-sync
git diff --name-status origin/devel...origin/automation/rhwp-v0.7.18-full-sync
git cherry-pick -n <fresh-sync-commit>
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-studio-assets.sh \
  --tag v0.7.18 \
  --commit 93862a4e16df59834ebce46d91e948cd739208e9
comm -3 <(sort rhwp-ffi-symbols.txt) <(sort Frameworks/generated_rhwp_symbols.txt)
rg -n "v0.7.18|93862a4e16df59834ebce46d91e948cd739208e9|native-skia" \
  RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock \
  Sources/HostApp/Resources/rhwp-studio/manifest.json
git diff --check
```

### 완료 조건

- task branch tracked diff가 fresh automation candidate의 의도된 full sync 변경을 포함한다.
- core lock과 studio manifest가 동일한 target tag/commit을 가리킨다.
- #408의 15개 FFI symbol과 header가 target core에서 유지된다.
- upstream Cargo.lock fingerprint와 manifest 값이 일치한다.
- generated/ignored 산출물이 commit 대상에 포함되지 않는다.

### 커밋

```text
Task #418 Stage 3: v0.7.18 core와 bundled studio provenance 통합
```

## Stage 4. ABI, 앱 target, 렌더 회귀 검증

### 목표

target core/studio 조합에서 RustBridge C ABI, Swift target compile/link, embedded image, Quick Look/Thumbnail renderer와 visual baseline이 회귀하지 않는지 확인한다.

### 대상

- RustBridge test와 generated artifacts
- HostApp, QLExtension, ThumbnailExtension
- #396 baseline manifest와 대표 HWP/HWPX samples
- 새 automation PR CI와 local validation 결과
- `mydocs/working/task_m020_418_stage4.md`
- orders 문서

### 작업

1. Rust format/check/test와 lock verification을 실행한다.
2. external image context ABI unit test와 refs JSON lifecycle을 확인한다.
3. no-AppKit 경계와 core build info를 검증한다.
4. Xcode project를 재생성하고 HostApp, QLExtension, ThumbnailExtension Debug build를 각각 실행한다.
5. stage3 render와 embedded image fixture regression을 실행한다.
6. #396 representative set으로 bundled studio/native renderer baseline을 재측정한다.
7. Quick Look/Thumbnail Skia opt-in smoke와 fallback/size/latency를 이전 기준과 비교한다.
8. blank/fallback, page count/size, image lookup, crash/timeout을 blocking regression으로 분류한다.
9. 검증 중 필요한 downstream 수정이 생기면 범위를 보고하고 같은 Stage 안에서 수정·재검증한다.

### 검증

```bash
cargo fmt --manifest-path RustBridge/Cargo.toml --check
cargo check --manifest-path RustBridge/Cargo.toml --locked
cargo test --manifest-path RustBridge/Cargo.toml --locked
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task418-host CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task418-ql CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task418-thumbnail CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh
./scripts/validate-stage3-render.sh build.noindex/task418-image samples/hwp-img-001.hwp
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task418-quicklook \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/hwpx/hwpx-01.hwpx
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task418-thumbnail \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-renderer-baseline.sh build.noindex/task418-baseline
git diff --check
```

### 완료 조건

- RustBridge locked test와 15개 ABI verification이 통과한다.
- HostApp과 두 extension이 compile/link된다.
- embedded image와 representative renderer output에 blocking regression이 없다.
- visual/performance 변화와 환경 한계가 Stage 4 보고서에 수치로 기록되어 있다.
- development extension registration이 남지 않는다.

### 커밋

```text
Task #418 Stage 4: v0.7.18 앱과 렌더 회귀 검증
```

## Stage 5. 최종 보고와 public release handoff

### 목표

full sync 결과, upstream 사용자-facing 영향, 검증 근거와 잔여 위험을 정리하고 별도 public release task가 바로 시작할 수 있는 입력을 확정한다.

### 대상

- `mydocs/report/task_m020_418_report.md`
- orders 문서
- upstream automation PR과 #415 처리 상태
- 다음 Release Operations 이슈 초안 입력

### 작업

1. Stage 1~4의 commit, source/provenance diff, workflow/PR CI, local 검증을 요약한다.
2. upstream release note를 알한글 HostApp, bundled editor, Quick Look/Thumbnail, parser/performance 영향으로 분류한다.
3. #408은 ABI 기반이며 #409가 미완료이므로 external image 제품 지원으로 과장하지 않는 release note 경계를 기록한다.
4. #406 HOP exact UTI signed-install smoke를 다음 release blocking manual gate로 넘긴다.
5. 최신 공개 앱 `v0.1.7 (13)` 이후 포함 PR 분석과 release identity 후보 `v0.1.8 (14)`를 handoff 값으로 제시하되 이 task에서 확정하지 않는다.
6. fresh automation PR은 task PR에 sync diff가 포함됐음을 확인한 뒤 superseded 처리 시점과 cleanup 대상을 정리한다.
7. 오늘할일을 완료 처리하고 최종 보고 승인을 요청한다.

### 검증

```bash
rg -n "#418|v0.7.18|93862a4e16df59834ebce46d91e948cd739208e9|#415|#408|#409|#406|release" \
  mydocs/report/task_m020_418_report.md mydocs/orders
./scripts/build-rust-macos.sh --verify-lock
./scripts/verify-rhwp-studio-assets.sh
cargo test --manifest-path RustBridge/Cargo.toml --locked
git diff --check
git status --short --branch
git log --oneline origin/devel..HEAD
```

### 완료 조건

- 최종 보고서가 core/studio provenance, ABI, CI/local validation, visual 결과와 잔여 위험을 포함한다.
- public release task가 사용할 version/build 후보, previous ref, expected rhwp tag와 manual smoke 항목이 정리되어 있다.
- automation PR과 task PR의 역할 및 cleanup 순서가 명확하다.
- working tree가 clean이고 `task-final-report` 승인 지점에 있다.

### 커밋

```text
Task #418 Stage 5 + 최종 보고서: v0.7.18 release handoff 정리
```

## 단계별 승인 지점

1. 이 구현계획서 승인 후 Stage 1 read-only 조사와 완료보고를 시작한다.
2. Stage 1 완료보고 승인 후에만 #415 close, 원격 branch 삭제, workflow dispatch를 수행한다.
3. Stage 2 완료보고 승인 후 새 automation candidate diff를 task branch에 적용한다.
4. Stage 3 완료보고 승인 후 full local app/render validation을 수행한다.
5. Stage 4 완료보고 승인 후 최종 보고와 public release handoff를 작성한다.
6. 최종 결과보고서 승인 후 `task-final-report` 절차로 `publish/task418` PR을 게시한다.
7. Task #418 PR merge 확인 후 automation PR/branch와 local task branch/worktree cleanup을 수행한다.

구현계획서 승인 전에는 core/studio tracked file 변경, PR #415 상태 변경, 원격 branch 삭제, workflow 실행을 수행하지 않는다.
