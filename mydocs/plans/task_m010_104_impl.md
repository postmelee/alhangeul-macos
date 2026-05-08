# Issue #104 구현 계획서

## 작업명

rhwp v0.7.9 stable tag 반영 및 앱 검증 버전 등록

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_104.md`를 기준으로 진행한다.
- 이번 작업은 기존 `v0.7.8` Stable release tag pin을 `v0.7.9` Stable release tag pin으로 갱신하는 작업이다.
- Stable 기준은 `v0.7.9` release tag와 해당 tag의 resolved commit `0fb3e6758b8ad11d2f3c3849c83b914684e83863`이 함께 일치해야 한다.
- `RustBridge/Cargo.toml`은 branch나 floating ref를 사용하지 않고 `tag = "v0.7.9"`로 고정한다.
- `Cargo.lock`과 `rhwp-core.lock`의 repo, release tag, resolved commit 불일치를 허용하지 않는다.
- 기존 PageRenderTree 기반 C ABI와 Swift decoder/renderer contract를 유지한다.
- upstream core source는 수정하지 않는다. 앱 저장소에서는 dependency, lock, Rust bridge 산출물, 앱 검증용 version/등록 절차, 현재 기준 문서만 다룬다.
- `project.yml`이 Xcode project 원본이며, `AlhangeulMac.xcodeproj`는 `xcodegen generate`로만 재생성한다.
- Quick Look/Thumbnail 등록 판정은 Debug 산출물이 아니라 Release package 산출물과 `$HOME/Applications/AlhangeulMac.app` 설치본 기준으로 수행한다.
- 각 단계 완료 후 단계별 완료보고서를 작성하고 작업지시자 승인 전 다음 단계로 진행하지 않는다.

## Stage 1: v0.7.9 release tag와 현재 기준 재확인

대상:

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`
- `rhwp-ffi-symbols.txt`
- `scripts/update-rhwp-core.sh`
- `scripts/build-rust-macos.sh`
- `scripts/package-release.sh`
- `scripts/release.sh`
- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `Sources/HostApp/Support/BuildInfo.swift`
- `Sources/RhwpCoreBridge/`
- `Sources/Shared/`
- `Sources/HostApp/`
- `Sources/QLExtension/`
- `Sources/ThumbnailExtension/`
- `mydocs/tech/core_release_compatibility.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
- GitHub Issue #104, upstream `edwardkim/rhwp` release `v0.7.9`

작업:

- 현재 `v0.7.8` Stable pin 상태와 `rhwp-core.lock` artifact 기준을 기록한다.
- upstream `v0.7.9` release tag의 존재, release URL, publishedAt, resolved commit을 확인한다.
- `v0.7.9`에 `build_page_render_tree`, `get_bin_data`, `render_page_svg_native`, `get_page_info_native`, `extract_thumbnail_only`가 포함되는지 확인한다.
- `v0.7.9` release note의 앱 영향 범위를 요약한다.
- 현재 app/extension plist version, package-release 입력 version, release script version 검증 기준을 확인한다.
- `$HOME/Applications/AlhangeulMac.app` 표준 설치본 교체와 LaunchServices/PlugInKit 등록 절차의 위험을 확인한다.
- Stage 2 이후 변경 대상과 검증 순서를 확정한다.

산출물:

- `mydocs/working/task_m010_104_stage1.md`

검증:

```bash
git status --short
gh issue view 104 --repo postmelee/alhangeul-macos --json number,title,state,body,labels,milestone,url
gh release view v0.7.9 --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url
git ls-remote --tags https://github.com/edwardkim/rhwp.git refs/tags/v0.7.9 refs/tags/v0.7.9^{}
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.9
rg -n "rhwp_render_page_tree|rhwp_image_data|bin_data_id|RenderNode|build_page_render_tree|get_bin_data|render_page_svg_native|get_page_info_native|extract_thumbnail_only" \
  RustBridge Sources/RhwpCoreBridge Sources/Shared Sources/HostApp Sources/QLExtension Sources/ThumbnailExtension mydocs/tech mydocs/manual
rg -n "CFBundleShortVersionString|CFBundleVersion|package-release|validate_source_versions|0\\.1\\.0" \
  Sources scripts mydocs/manual/build_run_guide.md mydocs/manual/release_distribution_guide.md mydocs/tech/project_architecture.md
git diff --check -- mydocs/working/task_m010_104_stage1.md
```

완료 조건:

- `v0.7.9` release tag와 resolved commit이 Stage 1 보고서에 기록되어 있다.
- required API가 Stable tag 기준으로 확인되어 있다.
- app/extension version과 Release package version 적용 방침이 확정되어 있다.
- `$HOME/Applications/AlhangeulMac.app` 설치/등록 검증 범위가 확인되어 있다.

예상 커밋:

```text
Task #104 Stage 1: v0.7.9 stable tag와 검증 기준 재확인
```

## Stage 2: Stable tag dependency와 lock provenance skeleton 갱신

대상:

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`

작업:

- `./scripts/update-rhwp-core.sh --channel stable --tag v0.7.9`로 core dependency skeleton을 갱신한다.
- `RustBridge/Cargo.toml`이 `tag = "v0.7.9"` dependency를 사용하는지 확인한다.
- `RustBridge/Cargo.lock`의 `rhwp` source가 `tag=v0.7.9`와 resolved commit을 포함하는지 확인한다.
- `rhwp-core.lock`이 `rhwp_ref_kind = "release-tag"`, `rhwp_release_tag = "v0.7.9"`, resolved commit을 기록하는지 확인한다.
- artifact hash/size는 Stage 3에서 재생성하므로 Stage 2에서는 provenance skeleton 정합성만 확인한다.

산출물:

- `mydocs/working/task_m010_104_stage2.md`

검증:

```bash
./scripts/update-rhwp-core.sh --channel stable --tag v0.7.9
rg -n "v0\\.7\\.9|0fb3e6758b8ad11d2f3c3849c83b914684e83863|rhwp_ref_kind|rhwp_release_tag|rhwp_commit|demo-commit-pin" \
  RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
git diff -- RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
git diff --check -- RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock mydocs/working/task_m010_104_stage2.md
```

완료 조건:

- `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`이 같은 `v0.7.9` Stable 기준을 가리킨다.
- `rhwp-core.lock`에 release tag와 resolved commit이 함께 기록되어 있다.
- generated artifact 갱신 전 상태와 Stage 3 작업 필요성이 보고서에 기록되어 있다.

예상 커밋:

```text
Task #104 Stage 2: rhwp v0.7.9 stable tag dependency 전환
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

- `mydocs/working/task_m010_104_stage3.md`

검증:

```bash
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
grep -n "rhwp_render_page_tree\\|rhwp_image_data\\|width_pt\\|height_pt" Frameworks/generated_rhwp.h
git status --short
git diff --check -- rhwp-core.lock rhwp-ffi-symbols.txt mydocs/working/task_m010_104_stage3.md
```

완료 조건:

- Rust bridge artifact가 `v0.7.9` lock provenance와 일치한다.
- generated C header와 symbol set에 의도하지 않은 ABI 변경이 없다.
- `Rhwp.xcframework`가 재생성되어 이후 Xcode build와 Release package에 사용할 수 있다.

예상 커밋:

```text
Task #104 Stage 3: Rust bridge artifact와 lock 검증 갱신
```

## Stage 4: 앱 version 정합성과 Swift/macOS build 검증

대상:

- `Sources/HostApp/Info.plist`
- `Sources/QLExtension/Info.plist`
- `Sources/ThumbnailExtension/Info.plist`
- `Sources/HostApp/Support/BuildInfo.swift`
- `project.yml`
- `AlhangeulMac.xcodeproj`
- `Sources/RhwpCoreBridge/`
- `Sources/Shared/`
- `Sources/HostApp/`
- `Sources/QLExtension/`
- `Sources/ThumbnailExtension/`
- `scripts/release.sh`

작업:

- Stage 1에서 확정한 version 방침에 따라 app/extension plist version을 조정하거나 기존 값을 유지한다.
- version을 조정한다면 HostApp, QLExtension, ThumbnailExtension의 `CFBundleShortVersionString`과 `CFBundleVersion`을 같은 기준으로 맞춘다.
- `scripts/release.sh`의 source version 검증과 충돌하지 않는지 확인한다.
- `xcodegen generate`로 Xcode project를 재생성한다.
- `Sources/RhwpCoreBridge`의 AppKit/UIKit 직접 의존 금지 규칙을 검증한다.
- HostApp Debug build를 수행한다.
- 기본 render smoke로 open, page count, render tree 생성, page size, text run, non-white bitmap을 확인한다.

산출물:

- `mydocs/working/task_m010_104_stage4.md`

검증:

```bash
rg -n "CFBundleShortVersionString|CFBundleVersion" Sources/HostApp/Info.plist Sources/QLExtension/Info.plist Sources/ThumbnailExtension/Info.plist
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
git diff --check
```

완료 조건:

- app/extension version 값이 의도한 기준으로 일치하거나, 유지 결정이 보고서에 명확히 기록되어 있다.
- `check-no-appkit.sh`가 통과한다.
- HostApp Debug build가 성공한다.
- 기본 render smoke가 통과한다.

예상 커밋:

```text
Task #104 Stage 4: 앱 version 정합성과 render smoke 검증
```

## Stage 5: Release package 설치 등록과 Quick Look/Thumbnail/Viewer smoke

대상:

- `scripts/package-release.sh`
- `build.noindex/release/AlhangeulMac.app`
- `$HOME/Applications/AlhangeulMac.app`
- `Sources/QLExtension/`
- `Sources/ThumbnailExtension/`
- `Sources/HostApp/`
- `samples/`

작업:

- Stage 4에서 확정한 app version으로 `./scripts/package-release.sh <app-version>`을 실행한다.
- `build.noindex/release/AlhangeulMac.app`가 생성되었는지 확인한다.
- 표준 설치 경로 `$HOME/Applications/AlhangeulMac.app`만 교체한다.
- LaunchServices에 설치본을 등록한다.
- PlugInKit에 app extension을 등록한다.
- `pluginkit -mAvvv`에서 Quick Look preview extension과 Thumbnail extension이 새 설치 경로 아래에 잡히는지 확인한다.
- Quick Look cache를 갱신한다.
- `qlmanage -t -x`로 thumbnail smoke를 수행한다.
- 가능한 경우 `qlmanage -p` 또는 `open`으로 preview/viewer 실행 smoke를 수행한다.
- GUI 확인을 자동화하지 못한 항목은 실제 수행 가능 여부와 대체 검증을 Stage 5 보고서에 남긴다.

산출물:

- `mydocs/working/task_m010_104_stage5.md`
- `build.noindex/release/alhangeul-macos-<app-version>.zip`

검증:

```bash
./scripts/package-release.sh <app-version>

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
APP="$HOME/Applications/AlhangeulMac.app"
mkdir -p "$HOME/Applications"
"$LSREGISTER" -u "$APP" >/dev/null 2>&1 || true
rm -rf "$APP"
ditto build.noindex/release/AlhangeulMac.app "$APP"
"$LSREGISTER" -f -R -trusted "$APP"
pluginkit -a "$APP"
pluginkit -mAvvv | rg -n -C 8 "com\\.postmelee\\.alhangeulmac|AlhangeulMac(Preview|Thumbnail)"
qlmanage -r
qlmanage -r cache
mkdir -p /tmp/rhwp-task104-ql
qlmanage -t -x -s 512 -o /tmp/rhwp-task104-ql samples/basic/KTX.hwp
test -s /tmp/rhwp-task104-ql/KTX.hwp.png
open "$APP"
git diff --check -- mydocs/working/task_m010_104_stage5.md
```

완료 조건:

- Release package 산출물이 생성되어 있다.
- `$HOME/Applications/AlhangeulMac.app` 설치본이 새 package 산출물로 교체되어 있다.
- Quick Look preview extension과 Thumbnail extension이 PlugInKit에서 새 설치 경로로 확인된다.
- thumbnail smoke 산출 PNG가 생성된다.
- viewer 실행 smoke 수행 결과가 보고서에 기록되어 있다.

예상 커밋:

```text
Task #104 Stage 5: Release 앱 등록과 extension smoke 검증
```

## Stage 6: 문서 보정과 최종 결과 정리

대상:

- `mydocs/tech/core_release_compatibility.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- 필요 시 `mydocs/manual/build_run_guide.md`
- 필요 시 `README.md`
- `mydocs/orders/20260501.md`
- `mydocs/report/task_m010_104_report.md`

작업:

- core 기준 문서에서 현재 상태를 `v0.7.9` Stable release tag pin으로 갱신한다.
- `v0.7.8`을 현재 상태처럼 말하는 문서를 `v0.7.9` 기준으로 보정한다.
- 과거 단계 보고서처럼 당시 시점 기록인 문서는 수정하지 않는다.
- Release package 설치/등록 smoke 결과, 미실행 검증, 잔여 리스크를 최종 보고서에 정리한다.
- 오늘할일을 완료 상태와 완료 시각으로 갱신한다.
- PR 게시 전 미커밋 변경이 없는지 확인한다.

산출물:

- `mydocs/working/task_m010_104_stage6.md`
- `mydocs/report/task_m010_104_report.md`

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
rg -n "v0\\.7\\.8|v0\\.7\\.9|42cf91b6ba7b50fa1c853c01158a52ef68b45442|0fb3e6758b8ad11d2f3c3849c83b914684e83863|latest release|현재 lock|현재 앱 저장소" \
  README.md rhwp-core.lock RustBridge mydocs/tech mydocs/manual mydocs/plans/task_m010_104.md mydocs/plans/task_m010_104_impl.md
git status --short
```

완료 조건:

- 현재 기준 문서가 `v0.7.9` Stable tag pin 상태를 설명한다.
- Release package 설치/등록과 Quick Look/Thumbnail/Viewer smoke 결과가 최종 보고서에 기록되어 있다.
- 최종 검증 결과와 잔여 리스크가 정리되어 있다.
- 오늘할일이 완료 상태로 갱신되어 있다.
- PR 게시 전 브랜치에 미커밋 변경이 없다.

예상 커밋:

```text
Task #104 Stage 6 + 최종 보고서: v0.7.9 반영과 앱 등록 검증 정리
```

## 승인 요청 사항

이 구현 계획서 기준으로 Stage 1 조사를 진행할지 승인 요청한다. 승인 전에는 `RustBridge`, lock, generated framework, plist version, Release package 설치/등록, core compatibility 문서 변경을 진행하지 않는다.
