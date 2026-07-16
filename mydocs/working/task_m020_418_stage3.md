# Task M020 #418 Stage 3 보고서

## 단계 목적

fresh automation candidate PR #419의 `rhwp v0.7.18` full sync diff를 `local/task418`에 통합하고, current #408 RustBridge source에서 native artifact를 다시 생성해 core/studio provenance와 15개 FFI symbol을 task branch 기준으로 고정한다.

이 단계에서는 HostApp/extension build, render smoke, visual/performance baseline을 수행하지 않는다. 해당 검증은 Stage 4 범위로 유지한다.

## 산출물

| 파일/경로 | 변경 요약 |
|-----------|-----------|
| `RustBridge/Cargo.toml` | `rhwp` dependency를 stable tag `v0.7.18`로 갱신 |
| `RustBridge/Cargo.lock` | target dependency graph와 resolved commit `93862a4e...` 반영 |
| `rhwp-core.lock` | local current source에서 재생성한 universal archive/header reference metadata 반영 |
| `Sources/HostApp/Resources/rhwp-studio/assets/**` | `v0.7.18`에서 생성한 hashed JS/CSS/WASM asset 교체 |
| `Sources/HostApp/Resources/rhwp-studio/index.html` | 새 hashed entrypoint 참조 반영 |
| `Sources/HostApp/Resources/rhwp-studio/manifest.json` | target tag/commit, upstream Cargo.lock fingerprint, entrypoint hash 반영 |
| `Sources/HostApp/Resources/rhwp-studio/sw.js` | 새 asset precache 목록 반영 |
| `mydocs/manual/core_dependency_operation_guide.md` | current stable pin과 external image API 기준을 `v0.7.18`로 갱신 |
| `mydocs/tech/core_release_compatibility.md` | current provenance/artifact/API contract를 실제 lock과 #408 ABI 기준으로 갱신 |
| `mydocs/tech/project_architecture.md` | current stable core 경계를 `v0.7.18`로 갱신 |
| `mydocs/working/task_m020_418_stage3.md` | Stage 3 통합·검증 결과 기록 |
| `mydocs/orders/20260717.md` | #418을 Stage 3 완료 및 Stage 4 승인 대기로 갱신 |

`Frameworks/universal/librhwp.a`, `Frameworks/generated_rhwp.h`, `Frameworks/generated_rhwp_symbols.txt`, `Frameworks/Rhwp.xcframework`는 재생성했지만 정책상 git 추적 대상이 아니다.

## 통합 결과

### Fresh candidate 재확인

적용 직전에 PR #419를 다시 조회했다.

| 항목 | 값 |
|------|----|
| state | `OPEN` |
| base | `dda97c7000fe12e7ed925e4e8a8d2b71f44fc46f` |
| head | `bdea7f557d8de3ca5e11913cd691f06052076d0d` |
| mergeability | `MERGEABLE`, `CLEAN` |
| PR CI | 네 check `SUCCESS` |

fresh commit의 parent가 exact base `dda97c7...`임을 확인했다. `git cherry-pick -n bdea7f5...`로 commit을 만들지 않고 task branch index/worktree에 적용했으며 conflict는 없었다.

적용 직후 changed path는 Stage 2에서 확인한 PR #419의 11개 repository path와 일치했다.

### Local core artifact 재생성

```bash
./scripts/build-rust-macos.sh --update-lock
```

결과: 성공.

- arm64 release static library build 성공
- x86_64 release static library build 성공
- universal archive architecture: `x86_64 arm64`
- cbindgen header 생성 성공
- XCFramework 생성 성공
- `rhwp-core.lock` 갱신 성공

local task branch의 최종 core provenance:

| 필드 | 값 |
|------|----|
| release tag | `v0.7.18` |
| resolved commit | `93862a4e16df59834ebce46d91e948cd739208e9` |
| feature | `native-skia` |
| built_at | `2026-07-16T15:57:48Z` |
| `librhwp.a` SHA-256 | `b7029e88c44774d44e4e30c624113eced4b305918a114834acb5725584c8b0a7` |
| `librhwp.a` size | `208707280` bytes |
| generated header SHA-256 | `c4cba0728b7e443ba78541dc1184d6aa286b91b72006e423e9283d998c31d8e5` |
| generated header size | `3310` bytes |

automation candidate와 task branch의 product/provenance 파일을 비교하면 `rhwp-core.lock`만 다르다. 차이는 local 재생성에 따른 `built_at`, static archive SHA-256, size 세 필드다. release tag/commit/feature와 generated header metadata는 동일하다.

static archive 값이 candidate의 `f9adfd52...` / `208697904`에서 local 값으로 바뀐 것은 source/ABI 변경이 아니라 runner/toolchain/build path 영향을 받을 수 있는 reference artifact 재생성 결과다. strict local verify로 현재 lock과 현재 산출물의 일치를 확인했다.

### FFI symbol과 ABI 보존

생성된 symbol 목록은 expected `rhwp-ffi-symbols.txt`와 정확히 일치한다.

```text
rhwp_close
rhwp_external_image_refs_json
rhwp_extract_thumbnail
rhwp_free_bytes
rhwp_free_string
rhwp_image_data
rhwp_inject_external_image_by_key
rhwp_open
rhwp_page_count
rhwp_page_overlay_images
rhwp_page_size
rhwp_render_page_png
rhwp_render_page_svg
rhwp_render_page_tree
rhwp_set_file_name_utf8
```

`rhwp-ffi-symbols.txt`, `RustBridge/src/lib.rs`, `RustBridge/cbindgen.toml`은 candidate 적용 전 task HEAD에서 변경하지 않았다. generated header hash도 #408 이후 기준과 동일하므로 dependency sync가 ABI 표면을 추가·삭제하지 않았다.

### Bundled studio provenance

```bash
./scripts/verify-rhwp-studio-assets.sh \
  --tag v0.7.18 \
  --commit 93862a4e16df59834ebce46d91e948cd739208e9
```

결과: 성공.

manifest 기준:

| 필드 | 값 |
|------|----|
| release tag | `v0.7.18` |
| resolved commit | `93862a4e16df59834ebce46d91e948cd739208e9` |
| upstream `Cargo.lock` SHA-256 | `5cf25bdd98a070906ff6c78126f8384bb3122db974143dcd8e39cd3099359045` |
| copied files | 60개 / 39,392,653 bytes |
| main JS | `assets/index-D5QjYkw5.js` |
| main CSS | `assets/index-BKc-ZB2H.css` |
| WASM | `assets/rhwp_bg-CfVwz6LI.wasm` |

GitHub API에서 target commit의 upstream root `Cargo.lock` 원문을 받아 SHA-256을 직접 계산했고 manifest 값과 일치했다. 따라서 native `RustBridge/Cargo.lock`과 별개인 studio/WASM dependency graph fingerprint도 target source에 연결된다.

local overlay인 `alhangeul-wkwebview-overrides.css`, `fonts/FONTS.md`는 candidate 적용 전과 diff가 없고 manifest의 `local_overlay_paths`에도 유지됐다.

### 운영 문서 동기화

계획서가 stale 확인 시 갱신 후보로 지정한 세 문서에서 current core가 `v0.7.11` 또는 `v0.7.16`으로 남아 있었다. 역사 기록을 확장하지 않고 current-state 문장과 compatibility table만 다음 기준으로 갱신했다.

- stable tag `v0.7.18`
- resolved commit `93862a4e...`
- local `rhwp-core.lock` artifact metadata
- `HwpDocument` opaque handle
- filename/external image context C ABI 세 개
- native PNG와 overlay image C ABI

세 문서에서 stale current tag/SHA와 `DocumentCore::from_bytes` 직접 소유 표현이 더 이상 검색되지 않음을 확인했다.

## 본문 변경 정도 / 본문 무손실 여부

- core/studio source 결과는 automation candidate를 그대로 적용했으며 minified JS, CSS, WASM을 수동 편집하지 않았다.
- candidate 대비 task branch의 의도적 product 차이는 local artifact metadata를 담은 `rhwp-core.lock`뿐이다.
- local WKWebView overlay와 font 설명 파일은 무손실이다.
- #408의 Rust source, expected symbol 목록, cbindgen 설정은 무손실이다.
- generated `Frameworks/**`는 commit하지 않는다.
- 세 운영 문서는 기존 구조와 운영 원칙을 유지하고 current version/provenance/API 표현만 교체·보강했다.
- PR #419는 automation candidate 증거로 open 상태를 유지하며 이 단계에서 merge/close하지 않았다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| PR #419 head/base/CI 재조회 | Stage 2 값 유지, MERGEABLE/CLEAN, 네 check SUCCESS |
| `git cherry-pick -n bdea7f5...` | conflict 없이 11개 candidate path 적용 |
| `./scripts/build-rust-macos.sh --update-lock` | universal staticlib/header/XCFramework 재생성 및 lock 갱신 성공 |
| `./scripts/build-rust-macos.sh --verify-lock` | strict artifact hash/size, Cargo lock, FFI symbol 검증 성공 |
| `./scripts/check-no-appkit.sh` | shared Swift code의 AppKit/UIKit 의존 없음 |
| `./scripts/verify-rhwp-studio-assets.sh --tag ... --commit ...` | bundled asset/manifest 검증 성공 |
| `comm -3 expected generated symbols` | 빈 diff, 15개 symbol 일치 |
| upstream `Cargo.lock` direct SHA-256 | `5cf25bdd...`, manifest와 일치 |
| local overlay/source ABI diff | 빈 diff |
| candidate 대비 product diff | local `rhwp-core.lock`만 변경 |
| `git diff --check` | 문서 편집 전 중간 검증 통과 |

Stage 3 보고서와 orders 편집 후 staged/unstaged 전체에 대해 `git diff --check`를 다시 실행한다.

## 잔여 위험

- local static archive hash는 현재 환경의 reference 값이다. 다른 CI runner에서는 source/ABI가 같아도 byte hash가 달라질 수 있으며, repository 정책상 CI는 staticlib byte hash만 선택적으로 제외할 수 있다.
- Stage 3는 native core release build까지 확인했지만 HostApp/QLExtension/ThumbnailExtension의 Swift compile/link는 Stage 4에 남아 있다.
- bundled studio와 native renderer의 사용자-visible 출력, embedded image, Quick Look/Thumbnail latency와 fallback은 아직 재측정하지 않았다.
- upstream 변경 폭이 크므로 compile/provenance 성공만으로 렌더 회귀가 없다고 판단하지 않는다.
- hashed JS/CSS/WASM은 generated asset이므로 source-level 리뷰보다 manifest hash와 Stage 4 runtime smoke를 신뢰 경계로 사용한다.

## 다음 단계 영향

Stage 4에서는 고정된 `v0.7.18` core/studio 조합으로 Rust fmt/check/test, core build info, XcodeGen과 세 app target build, embedded image/render smoke, Quick Look/Thumbnail policy smoke, #396 baseline 비교를 수행한다. blocking regression이 확인되면 같은 Stage 안에서 원인을 분류하고 필요한 downstream 수정 범위를 보고한다.

## 승인 요청

Stage 3 `자동 후보를 task branch에 통합하고 provenance 고정`은 완료됐다. Stage 4 `ABI, 앱 target, 렌더 회귀 검증`으로 진행하려면 작업지시자 승인이 필요하다.
