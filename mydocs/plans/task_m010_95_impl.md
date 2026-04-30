# Issue #95 구현 계획서

## 작업명

rhwp v0.7.8 stable tag 승격

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_95.md`를 기준으로 진행한다.
- 이번 작업은 Demo/Preview commit pin을 Stable release tag pin으로 승격하는 작업이다.
- Stable 기준은 `v0.7.8` release tag와 해당 tag의 resolved commit이 함께 일치해야 한다.
- `RustBridge/Cargo.toml`은 branch나 floating ref를 사용하지 않고 `tag = "v0.7.8"`로 고정한다.
- `Cargo.lock`과 `rhwp-core.lock`의 repo, release tag, resolved commit 불일치를 허용하지 않는다.
- 기존 PageRenderTree 기반 C ABI와 Swift decoder contract를 유지한다.
- PageLayerTree API가 upstream release에 포함되어도 이번 단계에서 신규 ABI나 Swift renderer 전환은 하지 않는다.
- `project.yml`이 Xcode project 원본이며, `AlhangeulMac.xcodeproj`는 `xcodegen generate`로만 재생성한다.
- 각 단계 완료 후 단계별 완료보고서를 작성하고 작업지시자 승인 전 다음 단계로 진행하지 않는다.

## Stage 1: v0.7.8 release tag와 현재 기준 재확인

대상:

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`
- `rhwp-ffi-symbols.txt`
- `scripts/update-rhwp-core.sh`
- `scripts/build-rust-macos.sh`
- `Sources/RhwpCoreBridge/`
- `Sources/Shared/`
- `Sources/HostApp/`
- `Sources/QLExtension/`
- `Sources/ThumbnailExtension/`
- `mydocs/tech/core_release_compatibility.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
- GitHub Issue #95, Issue #76, upstream `edwardkim/rhwp` release `v0.7.8`

작업:

- 현재 Demo/Preview pin `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`와 `rhwp-core.lock` 상태를 기록한다.
- upstream `v0.7.8` release tag의 존재, target, publishedAt, resolved commit을 확인한다.
- `v0.7.8`에 `build_page_render_tree`, `get_bin_data`, `render_page_svg_native`, `get_page_info_native`, `extract_thumbnail_only`가 포함되는지 확인한다.
- PageLayerTree 관련 upstream API는 존재 확인만 하고, 이번 앱 ABI 범위 밖임을 기록한다.
- Stable 전환 후 바꿔야 할 stale 문서 표현 위치를 검색해 목록화한다.
- Stage 2 이후 변경 대상과 검증 순서를 확정한다.

산출물:

- `mydocs/working/task_m010_95_stage1.md`

검증:

```bash
git status --short
gh issue view 95 --repo postmelee/alhangeul-macos --json number,title,state,body,labels,milestone,url
gh release view v0.7.8 --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url
git ls-remote --tags https://github.com/edwardkim/rhwp.git refs/tags/v0.7.8 refs/tags/v0.7.8^{}
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.8
rg -n "rhwp_render_page_tree|rhwp_image_data|bin_data_id|RenderNode|build_page_render_tree|get_bin_data|PageLayerTree" \
  RustBridge Sources/RhwpCoreBridge Sources/Shared Sources/HostApp Sources/QLExtension Sources/ThumbnailExtension mydocs/tech mydocs/manual
rg -n "v0\\.7\\.7|v0\\.7\\.8|e91ecea3174a0da0ad7a1ea495cacc4f8772c31d|demo-commit-pin|Stable 전환|Stable.*blocked|latest release" \
  README.md rhwp-core.lock RustBridge mydocs/tech mydocs/manual mydocs/plans/task_m010_76.md
git diff --check -- mydocs/working/task_m010_95_stage1.md
```

완료 조건:

- `v0.7.8` release tag와 resolved commit이 Stage 1 보고서에 기록되어 있다.
- required API가 Stable tag 기준으로 확인되어 있다.
- PageLayerTree API는 이번 변경 범위 밖으로 분리되어 있다.
- stale 문서 표현 보정 대상이 확정되어 있다.

예상 커밋:

```text
Task #95 Stage 1: v0.7.8 stable tag 기준 재확인
```

## Stage 2: Stable tag dependency와 lock provenance skeleton 갱신

대상:

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`

작업:

- `./scripts/update-rhwp-core.sh --channel stable --tag v0.7.8`로 core dependency skeleton을 갱신한다.
- `RustBridge/Cargo.toml`이 `tag = "v0.7.8"` dependency를 사용하는지 확인한다.
- `RustBridge/Cargo.lock`의 `rhwp` source가 `tag=v0.7.8`와 resolved commit을 포함하는지 확인한다.
- `rhwp-core.lock`이 `rhwp_ref_kind = "release-tag"`, `rhwp_release_tag = "v0.7.8"`, resolved commit을 기록하는지 확인한다.
- Demo/Preview 전용 `rhwp_release_transition_status = "demo-commit-pin"`이 Stable lock에 남지 않는지 확인한다.
- artifact hash/size는 Stage 3에서 재생성하므로, Stage 2에서는 provenance skeleton 정합성만 확인한다.

산출물:

- `mydocs/working/task_m010_95_stage2.md`

검증:

```bash
./scripts/update-rhwp-core.sh --channel stable --tag v0.7.8
rg -n "v0\\.7\\.8|rhwp_ref_kind|rhwp_release_tag|rhwp_commit|demo-commit-pin" \
  RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
git diff -- RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
git diff --check -- RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock mydocs/working/task_m010_95_stage2.md
```

완료 조건:

- `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`이 같은 `v0.7.8` Stable 기준을 가리킨다.
- Demo/Preview commit pin 상태값이 Stable lock provenance에 남지 않는다.
- generated artifact 갱신 전 상태와 Stage 3 작업 필요성이 보고서에 기록되어 있다.

예상 커밋:

```text
Task #95 Stage 2: rhwp v0.7.8 stable tag dependency 전환
```

## Stage 3: Rust bridge 산출물 재생성과 lock verify

대상:

- `RustBridge/`
- `Frameworks/generated_rhwp.h`
- `Frameworks/universal/librhwp.a`
- `Frameworks/Rhwp.xcframework`
- `Frameworks/generated_rhwp_symbols.txt`
- `rhwp-core.lock`
- `rhwp-ffi-symbols.txt`

작업:

- `./scripts/build-rust-macos.sh --update-lock`로 Rust static library, generated header, `Rhwp.xcframework`를 재생성한다.
- `rhwp-core.lock`의 artifact sha256/size를 현재 산출물 기준으로 갱신한다.
- `./scripts/build-rust-macos.sh --verify-lock`로 lock과 산출물 정합성을 확인한다.
- expected FFI symbol snapshot과 generated symbol list를 비교한다.
- generated header의 기존 C ABI surface가 유지되는지 확인한다.
- FFI symbol set이 바뀌면 의도 여부를 분석하고, 필요한 경우 작업지시자에게 ABI 범위 재확인을 요청한다.

산출물:

- `mydocs/working/task_m010_95_stage3.md`

검증:

```bash
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
grep -n "rhwp_render_page_tree\\|rhwp_image_data\\|width_pt\\|height_pt" Frameworks/generated_rhwp.h
git status --short
git diff --check -- rhwp-core.lock rhwp-ffi-symbols.txt mydocs/working/task_m010_95_stage3.md
```

완료 조건:

- Rust bridge artifact가 `v0.7.8` lock provenance와 일치한다.
- generated C header와 symbol set에 의도하지 않은 ABI 변경이 없다.
- `Rhwp.xcframework`가 재생성되어 이후 Xcode build에 사용할 수 있다.

예상 커밋:

```text
Task #95 Stage 3: Rust bridge artifact와 lock 검증 갱신
```

## Stage 4: Swift/macOS build와 PageRenderTree render smoke 검증

대상:

- `project.yml`
- `AlhangeulMac.xcodeproj`
- `Sources/RhwpCoreBridge/`
- `Sources/Shared/`
- `Sources/HostApp/`
- `Sources/QLExtension/`
- `Sources/ThumbnailExtension/`
- `samples/`
- `scripts/validate-stage3-render.sh`
- 필요 시 render debug output

작업:

- `xcodegen generate`로 Xcode project를 재생성한다.
- `Sources/RhwpCoreBridge`의 AppKit/UIKit 직접 의존 금지 규칙을 검증한다.
- HostApp Debug build를 수행한다.
- 기본 render smoke로 open, page count, render tree 생성, page size, text run, non-white bitmap을 확인한다.
- 이미지가 포함된 샘플에서 `bin_data_id` 기반 `rhwp_image_data` 조회 경로가 유지되는지 확인한다.
- Quick Look preview와 Thumbnail smoke를 수행하거나, 실행하지 못한 경우 이유와 대체 검증을 기록한다.
- `v0.7.8` 전환으로 render 결과가 달라졌다면 회귀인지 정상 차이인지 분리해 기록한다.

산출물:

- `mydocs/working/task_m010_95_stage4.md`

검증:

```bash
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
./scripts/render-debug-compare.sh /tmp/rhwp-task95-v078-smoke --page 1 samples/hwp-multi-001.hwp samples/20250130-hongbo.hwp samples/aift.hwp
find samples -name "*.hwp" -o -name "*.hwpx"
git diff --check
```

필요 시 추가 검증:

```bash
qlmanage -p samples/hwp-multi-001.hwp
qlmanage -t -x -s 512 -o /tmp/rhwp-task95-ql samples/hwp-multi-001.hwp
```

완료 조건:

- `check-no-appkit.sh`가 통과한다.
- HostApp Debug build가 성공한다.
- 기본 render smoke가 통과한다.
- 이미지 use case에서 `bin_data_id` 조회 실패가 보고되지 않는다.
- Quick Look/Thumbnail 검증 수행 여부와 결과가 단계 보고서에 기록되어 있다.

예상 커밋:

```text
Task #95 Stage 4: v0.7.8 PageRenderTree render smoke 검증
```

## Stage 5: 문서 보정과 최종 결과 정리

대상:

- `mydocs/tech/core_release_compatibility.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- 필요 시 `mydocs/manual/build_run_guide.md`
- 필요 시 `README.md`
- `mydocs/orders/20260430.md`
- `mydocs/report/task_m010_95_report.md`

작업:

- core 기준 문서에서 현재 상태를 `v0.7.8` Stable release tag pin으로 갱신한다.
- #76 이후 남아 있는 stale latest release `v0.7.7` 또는 Stable blocked 표현을 현재 상태에 맞게 보정한다.
- 과거 단계 보고서처럼 당시 시점 기록인 문서는 수정하지 않고, 현재 기준 문서만 갱신한다.
- PageLayerTree API는 `v0.7.8` 포함 사실과 후속 전환 범위를 분리해 기록한다.
- 전체 검증 결과, 미실행 검증, 잔여 리스크를 최종 보고서에 정리한다.
- 오늘할일을 완료 상태와 완료 시각으로 갱신한다.
- PR 게시 전 미커밋 변경이 없는지 확인한다.

산출물:

- `mydocs/working/task_m010_95_stage5.md`
- `mydocs/report/task_m010_95_report.md`

검증:

```bash
git diff --check
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
rg -n "v0\\.7\\.7|v0\\.7\\.8|e91ecea3174a0da0ad7a1ea495cacc4f8772c31d|demo-commit-pin|Stable 전환|Stable.*blocked|latest release" \
  README.md rhwp-core.lock RustBridge mydocs/tech mydocs/manual mydocs/plans/task_m010_76.md mydocs/plans/task_m010_95.md mydocs/plans/task_m010_95_impl.md
git status --short
```

완료 조건:

- 현재 기준 문서가 `v0.7.8` Stable tag pin 상태를 설명한다.
- stale latest release/Stable blocked 표현 보정 범위가 최종 보고서에 기록되어 있다.
- 최종 검증 결과와 잔여 리스크가 정리되어 있다.
- 오늘할일이 완료 상태로 갱신되어 있다.
- PR 게시 전 브랜치에 미커밋 변경이 없다.

예상 커밋:

```text
Task #95 Stage 5 + 최종 보고서: v0.7.8 stable 승격 결과 정리
```

## 승인 요청 사항

이 구현 계획서 기준으로 Stage 1 조사를 진행할지 승인 요청한다. 승인 전에는 `RustBridge`, lock, generated framework, core compatibility 문서 변경을 진행하지 않는다.
