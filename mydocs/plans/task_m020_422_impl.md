# Task M020 #422 구현계획서

수행계획서: `mydocs/plans/task_m020_422.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #422 `rhwp v0.7.19 full sync 통합과 릴리스 후보 회귀 검증`
- upstream release: `edwardkim/rhwp v0.7.19`
- target commit: `f137b4c9468eaff5bb43e25108e9c9d39a2ed15b`
- automation candidate: PR #421 `Sync rhwp upstream v0.7.19`
- automation commit: `ddcc0329ae1b6bef7c6dacb51ee8375de3b6d42c`
- 직전 기준: Task #418 작업, PR #420 반영, `rhwp v0.7.18`
- 관련 작업: Issue #408 external image C ABI, Issue #409 Swift resolver, Issue #406 HOP UTI compatibility, Issue #396 visual baseline
- 마일스톤: M020 `v0.2.x Skia Quick Look/Thumbnail Backend`
- 기준 브랜치: `devel` at `9ca9c488937bdda00fb045eb82b1ab2ecb31aa83`
- 작업 브랜치: `local/task422`
- 분리 worktree: `/Users/melee/Documents/projects/rhwp-mac-task422`

## 구현 전 확인 결론

| 항목 | 확인 결과 | 계획 반영 |
|------|-----------|-----------|
| current core/studio | `v0.7.18` / `93862a4e16df59834ebce46d91e948cd739208e9` | `v0.7.19`로 갱신 필요 |
| target release | `v0.7.19` / `f137b4c9468eaff5bb43e25108e9c9d39a2ed15b` | stable tag + resolved commit으로 고정 |
| upstream release 범위 | 55개 PR, 578개 commit | compile 외 renderer/studio 회귀 검증 필요 |
| PR #421 base | `devel` at `9ca9c488937bdda00fb045eb82b1ab2ecb31aa83` | Task branch 시작점과 동일 |
| PR #421 head | `ddcc0329ae1b6bef7c6dacb51ee8375de3b6d42c` | exact automation input으로 사용 |
| PR #421 상태 | `MERGEABLE`, `CLEAN` | stale 재생성 없이 통합 후보로 검토 |
| PR #421 CI | classify, script, release helper, macOS validation 성공 | 생성 근거로 보존하되 local gate 대체 금지 |
| repository changed paths | core lock/dependency와 studio asset 15개 | task branch에서 current artifact/provenance 재검증 |
| current FFI 기준 | external image context 포함 15개 symbol | 추가·삭제 없이 보존해야 함 |
| renderer 정책 | CoreGraphics production default, Skia internal opt-in | default 전환 없이 양 경로 비교 |
| public release | `v0.1.8 (14)` 후보, 아직 미등록 | 이 Task 완료 후 `v0.7.19` 기준 별도 이슈 등록 |

## 구현 원칙

1. PR #421 후보는 upstream full sync 생성 경로와 tracked diff의 근거로 사용한다. PR 자체를 Task #422 최종 PR로 사용하거나 직접 merge하지 않는다.
2. Stage 1에서 base/head/freshness를 다시 확인한 뒤 automation commit을 `cherry-pick -n`으로 적용해 Stage 2 source와 보고서를 하나의 Task commit으로 만든다.
3. Stage 1 시점에 PR #421 base가 current Task 시작점과 달라졌거나 automation branch가 재작성됐으면 통합을 중단하고 freshness 계약을 다시 승인받는다.
4. automation의 `rhwp-core.lock` reference metadata는 current RustBridge source에서 `build-rust-macos.sh --update-lock`을 다시 실행해 확정한다.
5. `rhwp-ffi-symbols.txt`의 15개 symbol, generated header, generated symbol list를 ABI 기준으로 유지한다. 차이가 생기면 임의 수용하지 않고 source API와 bridge export를 조사한다.
6. native core와 bundled `rhwp-studio`는 같은 `v0.7.19` tag/commit에 고정한다. manifest의 source `Cargo.lock` fingerprint와 hashed entrypoint도 직접 검증한다.
7. `RhwpCoreBuildInfo.swift`와 기술·운영 문서는 final lock과 동일 provenance로 맞춘다.
8. `project.yml`을 Xcode project 원본으로 사용하고 generated `Alhangeul.xcodeproj`를 commit하지 않는다. `Frameworks/**`와 `build.noindex/**`도 검증 산출물로만 사용한다.
9. production renderer 기본값은 CoreGraphics로 유지한다. Skia 측정은 DEBUG/internal opt-in 경로로 제한하고 known `KTX.hwp` delta와 신규 회귀를 분리한다.
10. HML, MessageChannel, external linked image resolver는 실제 macOS integration이 없으므로 사용자-facing 완료 기능으로 표현하지 않는다.
11. PR #421 close와 automation branch 삭제는 Task PR merge 확인 후 `pr-merge-cleanup` 단계에서 수행한다.
12. app version/build 변경과 public release 실행은 이 Task에 포함하지 않는다.

## 최종 변경 표면

automation candidate에서 가져올 tracked product/provenance 변경:

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`
- `Sources/HostApp/Resources/rhwp-studio/index.html`
- `Sources/HostApp/Resources/rhwp-studio/sw.js`
- `Sources/HostApp/Resources/rhwp-studio/manifest.json`
- `Sources/HostApp/Resources/rhwp-studio/manifest.webmanifest`
- `Sources/HostApp/Resources/rhwp-studio/assets/**`
- `Sources/HostApp/Resources/rhwp-studio/fonts/**`

Task에서 추가로 갱신할 수 있는 tracked file:

- 필요 시 `rhwp-ffi-symbols.txt`
- `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/tech/core_release_compatibility.md`
- `mydocs/tech/project_architecture.md`

Task 문서 변경:

- `mydocs/orders/20260718.md` 또는 실제 단계 진행일의 orders 문서
- `mydocs/plans/task_m020_422_impl.md`
- `mydocs/working/task_m020_422_stage1.md`
- `mydocs/working/task_m020_422_stage2.md`
- `mydocs/working/task_m020_422_stage3.md`
- `mydocs/working/task_m020_422_stage4.md`
- `mydocs/report/task_m020_422_report.md`

생성·검증하지만 commit하지 않는 산출물:

- `Frameworks/generated_rhwp.h`
- `Frameworks/generated_rhwp_symbols.txt`
- `Frameworks/universal/librhwp.a`
- `Frameworks/Rhwp.xcframework/**`
- `Alhangeul.xcodeproj/**`
- `build.noindex/**`

## Stage 1. v0.7.19 영향과 automation 통합 계약 확정

### 목표

upstream release 영향, PR #421 provenance/freshness, current ABI와 core/studio 검증 기준을 read-only로 확정한다.

### 대상

- upstream release/tag/compare와 PR #421
- `.github/workflows/rhwp-upstream-sync-pr.yml`
- `scripts/update-rhwp-core.sh`
- `scripts/build-rust-macos.sh`
- `scripts/ci/detect-rhwp-studio-impact.sh`
- current lock/manifest/build info/FFI files
- Task #418 최종 보고서와 visual baseline
- `mydocs/working/task_m020_422_stage1.md`
- orders 문서

### 작업

1. upstream release tag, peeled commit, published state와 release note를 다시 수집한다.
2. `v0.7.18..v0.7.19`의 core, renderer, studio, WASM, font/license 영향 경로와 규모를 분류한다.
3. PR #421 base/head SHA, changed paths, checks, mergeability와 PR body provenance를 고정한다.
4. Task branch 시작점과 automation base가 동일하고 automation commit이 단일 sync commit인지 확인한다.
5. current RustBridge에서 export하는 15개 symbol과 target source의 사용 API를 확인한다.
6. `update-rhwp-core.sh --check`로 stable target dependency 해석과 resolved commit을 검증한다.
7. studio manifest, source `Cargo.lock` fingerprint, font root와 entrypoint 변화의 검증 방법을 확정한다.
8. Task #418 baseline의 representative sample, threshold, `KTX.hwp` sentinel을 Stage 4 비교 기준으로 고정한다.
9. Stage 2에서 적용할 exact commit, expected changed paths, 재생성 명령과 중단 조건을 보고서에 기록한다.

### 검증

```bash
gh release view v0.7.19 --repo edwardkim/rhwp \
  --json tagName,targetCommitish,publishedAt,isDraft,isPrerelease,url,body
gh api repos/edwardkim/rhwp/commits/v0.7.19 --jq '.sha'
gh api repos/edwardkim/rhwp/compare/v0.7.18...v0.7.19 \
  --jq '{status,ahead_by,total_commits,files:[.files[].filename]}'
gh pr view 421 --repo postmelee/alhangeul-macos \
  --json number,state,headRefName,headRefOid,baseRefName,baseRefOid,mergeable,mergeStateStatus,files,statusCheckRollup,url
git fetch origin automation/rhwp-v0.7.19-full-sync
git rev-list --left-right --count 9ca9c488937bdda00fb045eb82b1ab2ecb31aa83...origin/automation/rhwp-v0.7.19-full-sync
git diff --name-status 9ca9c488937bdda00fb045eb82b1ab2ecb31aa83...origin/automation/rhwp-v0.7.19-full-sync
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.19
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh
git diff --check
```

### 완료 조건

- target release tag와 resolved commit이 stable provenance로 확인돼 있다.
- PR #421 exact base/head, CI와 changed path inventory가 문서화돼 있다.
- automation candidate를 그대로 적용해도 current Task source를 잃지 않는다는 근거가 있다.
- 15개 C ABI, studio manifest/font, visual baseline의 검증 계약과 중단 조건이 확정돼 있다.
- 제품/core/studio tracked file은 변경되지 않았다.

### 중단 조건

- upstream tag가 이동했거나 peeled commit이 예상값과 다르다.
- PR #421 base/head가 재작성됐거나 Task 시작점과 다른 source를 기준으로 한다.
- target source에서 current RustBridge 필수 API가 제거 또는 비호환 변경됐다.
- stable update check가 target commit을 재현하지 못한다.

### 커밋

```text
Task #422 Stage 1: v0.7.19 영향과 sync 통합 계약 확정
```

## Stage 2. automation candidate 통합과 core/studio provenance 고정

### 목표

PR #421 exact automation candidate를 Task branch에 적용하고 current RustBridge artifact, 15개 C ABI, native core와 bundled studio provenance를 `v0.7.19`로 고정한다.

### 대상

- automation commit `ddcc0329ae1b6bef7c6dacb51ee8375de3b6d42c`
- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`
- `rhwp-ffi-symbols.txt`
- `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`
- `Sources/HostApp/Resources/rhwp-studio/**`
- core/studio provenance 관련 기존 문서
- `mydocs/working/task_m020_422_stage2.md`
- orders 문서

### 작업

1. origin automation ref를 fetch하고 Stage 1에서 확정한 base/head가 유지되는지 재확인한다.
2. automation commit을 `cherry-pick -n`으로 적용하고 실제 changed path가 Stage 1 inventory와 일치하는지 확인한다.
3. target dependency가 stable tag와 resolved commit에 고정됐는지 Cargo manifest/lock을 확인한다.
4. current RustBridge source에서 macOS artifact와 `rhwp-core.lock` reference metadata를 재생성한다.
5. expected/generated symbol list와 generated header를 대조하고 15개 ABI를 확인한다.
6. bundled studio manifest의 tag, commit, source `Cargo.lock` fingerprint, entrypoint hash와 font asset을 검증한다.
7. `RhwpCoreBuildInfo.swift`를 final lock provenance에 맞추고 build info 검증기를 실행한다.
8. core dependency 운영, compatibility와 architecture 문서의 stale `v0.7.18` current 기준을 최소 범위로 갱신한다.
9. generated/ignored output이 staged source에 포함되지 않았는지 확인한다.

### 실행·검증

```bash
git fetch origin automation/rhwp-v0.7.19-full-sync
git diff --name-status 9ca9c488937bdda00fb045eb82b1ab2ecb31aa83...origin/automation/rhwp-v0.7.19-full-sync
git cherry-pick -n ddcc0329ae1b6bef7c6dacb51ee8375de3b6d42c
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
./scripts/verify-rhwp-studio-assets.sh \
  --tag v0.7.19 \
  --commit f137b4c9468eaff5bb43e25108e9c9d39a2ed15b
comm -3 <(sort rhwp-ffi-symbols.txt) <(sort Frameworks/generated_rhwp_symbols.txt)
rg -n "v0.7.19|f137b4c9468eaff5bb43e25108e9c9d39a2ed15b|native-skia" \
  RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock \
  Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift \
  Sources/HostApp/Resources/rhwp-studio/manifest.json
git status --short
git diff --check
```

### 완료 조건

- Task branch의 product/provenance diff가 PR #421 후보의 의도된 full sync 변경을 포함한다.
- core lock, build info와 studio manifest가 모두 target tag/commit을 가리킨다.
- current RustBridge에서 생성한 artifact metadata와 15개 C ABI가 검증된다.
- upstream root `Cargo.lock` fingerprint, studio entrypoint와 font asset이 검증된다.
- provenance 문서가 final lock과 일치하고 generated output은 commit 대상에서 제외된다.

### 중단 조건

- automation diff가 Stage 1 changed path inventory 밖의 제품 변경을 포함한다.
- artifact 재생성이나 15개 symbol 검증이 실패한다.
- core와 studio의 target commit 또는 Cargo.lock fingerprint가 다르다.
- build info 또는 기존 overlay를 유지하려면 계획 범위를 넘는 source 수정이 필요하다.

### 커밋

```text
Task #422 Stage 2: v0.7.19 core와 bundled studio provenance 통합
```

## Stage 3. ABI, 앱 target과 대표 runtime 회귀 검증

### 목표

target core/studio 조합에서 RustBridge ABI, Swift target compile/link, 대표 HWP/HWPX parser/render와 embedded image 경로가 회귀하지 않는지 확인한다.

### 대상

- RustBridge test와 generated artifacts
- HostApp, QLExtension, ThumbnailExtension
- representative HWP/HWPX와 embedded image fixture
- PR #421 CI와 local validation 결과
- `mydocs/working/task_m020_422_stage3.md`
- orders 문서

### 작업

1. Rust format/check/locked test와 lock verification을 실행한다.
2. external image context ABI unit test와 refs JSON/file-name/injection lifecycle을 확인한다.
3. no-AppKit 경계, core build info와 bundled studio asset을 다시 검증한다.
4. `xcodegen`으로 project를 재생성하고 HostApp, QLExtension, ThumbnailExtension Debug build를 각각 실행한다.
5. 기본 native render와 embedded image fixture regression을 실행한다.
6. HWP/HWPX representative set에서 page count, blank/fallback, crash/timeout과 image lookup을 확인한다.
7. Quick Look/Thumbnail production policy smoke로 CoreGraphics default와 fallback 계약을 확인한다.
8. 검증 실패가 upstream regression, downstream integration, 환경 문제 중 어디에 속하는지 분류한다.
9. downstream 수정이 필요하면 Stage 범위를 보고하고 최소 수정 후 전체 검증을 반복한다.

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
  -derivedDataPath build.noindex/DerivedData-task422-host CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme QLExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task422-ql CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task422-thumbnail CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh
./scripts/validate-stage3-render.sh build.noindex/task422-image samples/hwp-img-001.hwp
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task422-quicklook-runtime \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/hwpx/hwpx-01.hwpx
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task422-thumbnail-runtime \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/hwpx/hwpx-01.hwpx
git diff --check
```

### 완료 조건

- RustBridge locked test와 15개 ABI verification이 통과한다.
- HostApp과 두 extension이 compile/link된다.
- representative HWP/HWPX 및 embedded image output에 blank, crash, timeout, blocking fallback이 없다.
- production CoreGraphics default와 Quick Look/Thumbnail fallback 계약이 유지된다.
- 개발용 앱/extension registration이 남지 않는다.

### 중단 조건

- ABI, app target build 또는 representative runtime이 재현 가능하게 실패한다.
- external/embedded image lifetime에 신규 crash 또는 누락이 발생한다.
- 통합 수정이 이 Task의 provenance/compatibility 범위를 넘는다.
- smoke가 개발 등록을 요구하지만 표준 절차로 정리할 수 없다.

### 커밋

```text
Task #422 Stage 3: v0.7.19 ABI와 앱 runtime 회귀 검증
```

## Stage 4. renderer와 bundled studio visual 회귀 판정

### 목표

CoreGraphics/Skia representative visual suite와 bundled studio 로딩·글꼴 경로를 측정해 `v0.7.19`의 레이아웃, 표, 이미지와 font 변경에 blocking regression이 없는지 판정한다.

### 대상

- Task #396/Task #418 visual baseline과 representative samples
- CoreGraphics production path와 Skia internal opt-in path
- `KTX.hwp` known Skia delta sentinel
- bundled studio WKWebView asset와 NotoSansKR font
- `mydocs/working/task_m020_422_stage4.md`
- orders 문서

### 작업

1. Task #418 baseline의 sample set과 이전 CoreGraphics/Skia 수치를 재확인한다.
2. 같은 sample set을 clean output directory에서 CoreGraphics와 Skia policy로 각각 실행한다.
3. page count/size drift, changed pixel 비율, blank/fallback, latency와 cache 결과를 수집한다.
4. `KTX.hwp` Skia-CG delta를 기존 sentinel과 비교해 같은 수준인지 신규 악화인지 판정한다.
5. 저장 지오메트리와 표 페이지네이션 영향 문서를 대표하는 samples에서 잘림, 과소분할과 내용 소실을 직접 확인한다.
6. bundled studio entrypoint, WASM, CanvasKit chunk와 NotoSansKR font가 로드되고 첫 페이지가 비어 있지 않은지 확인한다.
7. BinData 지연 로딩은 대표 이미지 문서의 성공과 memory 관찰 범위만 기록하며 upstream 수치를 앱 실측값처럼 인용하지 않는다.
8. 변화는 upstream 개선, 허용 가능한 drift, known sentinel, regression 후보로 분류한다.

### 검증

```bash
./scripts/preview-renderer-baseline.sh build.noindex/task422-baseline
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task422-quicklook-visual \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/hwpx/hwpx-01.hwpx
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task422-thumbnail-visual \
  samples/basic/request.hwp samples/basic/KTX.hwp samples/hwpx/hwpx-01.hwpx
./scripts/verify-rhwp-studio-assets.sh \
  --tag v0.7.19 \
  --commit f137b4c9468eaff5bb43e25108e9c9d39a2ed15b
git diff --check
```

Stage 1에서 current harness usage와 sample 위치를 다시 확인해 잘못된 옵션이 있으면 구현계획서의 의도를 유지하는 범위에서 실제 명령을 단계 보고서에 기록한다.

### 완료 조건

- representative visual suite가 모든 sample의 output과 정량 결과를 생성한다.
- blank/fallback, page size/count drift와 내용 소실 같은 blocking regression이 없다.
- `KTX.hwp` 결과가 known sentinel 범위인지 수치로 판정돼 있다.
- bundled studio와 font asset의 load/render 결과가 기록돼 있다.
- upstream 수치와 알한글 local 측정값이 구분돼 있다.

### 중단 조건

- 동일 입력에서 native page 수나 크기가 예상 밖으로 변한다.
- CoreGraphics 또는 Skia 결과에 신규 blank, crash, content loss가 있다.
- bundled studio가 entrypoint/WASM/font를 로드하지 못한다.
- visual 결과가 환경 문제와 renderer regression으로 구분되지 않는다.

### 커밋

```text
Task #422 Stage 4: v0.7.19 renderer와 studio 회귀 판정
```

## Stage 5. 최종 보고와 v0.1.8 release handoff

### 목표

full sync 결과, upstream 사용자 영향, 검증 근거와 잔여 위험을 정리하고 `rhwp v0.7.19` 기준의 별도 public release Task가 바로 시작할 수 있는 입력을 확정한다.

### 대상

- `mydocs/report/task_m020_422_report.md`
- orders 문서
- PR #421 처리 상태와 Task branch commit
- `v0.1.8` Release Operations 이슈 초안 입력

### 작업

1. Stage 1~4의 commit, source/provenance diff, automation CI, local build/runtime/visual 결과를 요약한다.
2. upstream release note를 HostApp, bundled studio, Quick Look/Thumbnail과 내부 구현 영향으로 분류한다.
3. 공개 release note 후보는 실제 검증된 HWP/HWPX 레이아웃·표·글꼴·메모리 영향 안에서 작성한다.
4. HML과 MessageChannel은 macOS integration이 없으므로 공개 지원 완료로 표현하지 않는다.
5. Issue #409 작업 전에는 external linked image 제품 지원 완료를 주장하지 않는다.
6. Issue #406 작업의 signed HOP exact UTI smoke를 release blocking manual gate로 유지한다.
7. 최신 공개 앱 `v0.1.7 (13)` 이후 포함 PR을 final candidate 기준으로 다시 분석한다.
8. 다음 release identity 후보 `v0.1.8 (14)`, previous ref `v0.1.7`, expected rhwp `v0.7.19`와 resolved commit을 handoff 값으로 기록한다.
9. Task PR merge 후 PR #421 superseded comment/close, automation branch 삭제와 local worktree cleanup 순서를 기록한다.
10. 오늘할일을 완료 처리하고 최종 결과보고서 승인을 요청한다.

### 검증

```bash
rg -n "#422|v0.7.19|f137b4c9468eaff5bb43e25108e9c9d39a2ed15b|#421|#406|#409|v0.1.8|release" \
  mydocs/report/task_m020_422_report.md mydocs/orders
./scripts/build-rust-macos.sh --verify-lock
./scripts/verify-rhwp-studio-assets.sh
cargo test --manifest-path RustBridge/Cargo.toml --locked
git diff --check
git status --short --branch
git log --oneline origin/devel..HEAD
```

### 완료 조건

- 최종 보고서가 core/studio provenance, ABI, automation/local 검증, visual 결과와 잔여 위험을 포함한다.
- public release Task가 사용할 version/build 후보, previous ref, expected rhwp tag/commit과 manual smoke 항목이 정리돼 있다.
- PR #421과 Task PR의 역할 및 merge 후 cleanup 순서가 명확하다.
- orders 문서가 완료 상태이고 working tree가 clean하다.
- `task-final-report` 승인 지점에 있다.

### 중단 조건

- Stage 1~4 결과 중 미해결 blocking regression이 남아 있다.
- final lock/manifest/build info provenance가 일치하지 않는다.
- public release handoff가 실제 검증 범위를 넘어선 기능을 주장한다.

### 커밋

```text
Task #422 Stage 5 + 최종 보고서: v0.7.19 release handoff 정리
```

## 단계별 승인 지점

1. 이 구현계획서 승인 후 Stage 1 read-only 조사와 완료보고를 시작한다.
2. Stage 1 완료보고 승인 후에만 PR #421 automation candidate를 Task branch에 적용하고 artifact를 재생성한다.
3. Stage 2 완료보고 승인 후 full local ABI/app/runtime validation을 수행한다.
4. Stage 3 완료보고 승인 후 renderer와 bundled studio visual 회귀 검증을 수행한다.
5. Stage 4 완료보고 승인 후 최종 보고와 public release handoff를 작성한다.
6. 최종 결과보고서 승인 후 `task-final-report` 절차로 `publish/task422` PR을 게시한다.
7. Task #422 PR merge 확인 후 PR #421 및 automation branch, local task branch/worktree를 정리한다.

구현계획서 승인 전에는 core/studio tracked file 변경, automation candidate 적용, PR #421 상태 변경과 public release 작업을 수행하지 않는다.
