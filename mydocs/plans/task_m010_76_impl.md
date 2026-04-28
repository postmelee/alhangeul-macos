# Issue #76 구현 계획서

## 작업명

rhwp PR #385 반영 core pin 갱신과 native bridge 검증

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_76.md`를 기준으로 진행한다.
- 이번 작업은 Stable release tag 전환이 아니라 Demo/Preview commit pin 갱신이다.
- upstream merge commit `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`는 full SHA `rev`로 고정하고, branch나 floating ref는 사용하지 않는다.
- `v0.7.7` 또는 구현 시점의 최신 release가 required API를 만족하지 못하면 Stable 전환 blocked 상태를 유지한다.
- 기존 native render tree C ABI와 Swift decoder contract를 유지한다.
- Rust bridge generated artifact는 `Frameworks/` 아래 재생성하되, git에는 tracked provenance(`rhwp-core.lock`)와 source/문서 변경만 반영한다.
- 각 단계 완료 후 단계별 완료보고서를 작성하고 작업지시자 승인 전 다음 단계로 진행하지 않는다.

## Stage 1: 현재 pin, upstream merge commit, release 상태 재확인

대상:

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`
- `rhwp-ffi-symbols.txt`
- `scripts/update-rhwp-core.sh`
- `scripts/build-rust-macos.sh`
- `Sources/RhwpCoreBridge/`
- `mydocs/tech/core_release_compatibility.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- GitHub PR #385, Issue #363, Issue #76

작업:

- 현재 `RustBridge` dependency rev와 `Cargo.lock` resolved commit을 기록한다.
- upstream PR #385 merge commit `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`의 required API 확인 결과를 기록한다.
- 구현 시점의 `edwardkim/rhwp` latest release tag, target branch, publishedAt, resolved commit을 다시 확인한다.
- latest release가 `DocumentCore::build_page_render_tree`, `DocumentCore::get_bin_data`, `DocumentCore::render_page_svg_native`, `DocumentCore::get_page_info_native`, `rhwp::parser::extract_thumbnail_only`를 만족하는지 확인한다.
- Swift bridge가 기대하는 render tree JSON shape와 `bin_data_id` 이미지 조회 contract를 정리한다.
- Stage 2 이후 변경 대상과 Stable blocked 사유를 확정한다.

산출물:

- `mydocs/working/task_m010_76_stage1.md`

검증:

```bash
git status --short
gh pr view 385 --repo edwardkim/rhwp --json state,baseRefName,headRefName,comments,commits,url
gh issue view 363 --repo edwardkim/rhwp --json state,closedAt,comments,url
gh release view --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url
./scripts/update-rhwp-core.sh --check --channel demo --rev e91ecea3174a0da0ad7a1ea495cacc4f8772c31d
./scripts/update-rhwp-core.sh --check --channel stable --tag <latest-release-tag>
rg -n "rhwp_render_page_tree|rhwp_image_data|bin_data_id|RenderNode|build_page_render_tree|get_bin_data" \
  RustBridge Sources/RhwpCoreBridge mydocs/tech mydocs/manual
git diff --check -- mydocs/working/task_m010_76_stage1.md
```

완료 조건:

- 현재 pin, upstream merge commit, latest release 상태가 단계 보고서에 기록되어 있다.
- Demo/Preview pin 갱신 대상 commit과 Stable blocked 여부가 확정되어 있다.
- Swift/native bridge use case 검증 포인트가 Stage 2~4 작업 기준으로 정리되어 있다.

## Stage 2: Demo/Preview core pin과 lock provenance 갱신

대상:

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`
- `Frameworks/` generated artifacts

작업:

- `./scripts/update-rhwp-core.sh --channel demo --rev e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`로 core dependency skeleton을 갱신한다.
- `RustBridge/Cargo.toml`이 upstream merge commit full SHA `rev`를 사용하는지 확인한다.
- `RustBridge/Cargo.lock`의 `rhwp` source가 같은 commit으로 resolved 되었는지 확인한다.
- `./scripts/build-rust-macos.sh --update-lock`로 Rust bridge artifact를 재생성하고 `rhwp-core.lock`의 hash/size를 갱신한다.
- `rhwp-core.lock`에 latest checked release tag와 release resolved commit이 구현 시점 기준으로 남는지 확인한다.
- generated `Frameworks/` 산출물은 ignore 대상임을 유지하고, tracked file 변경만 분리한다.

산출물:

- `mydocs/working/task_m010_76_stage2.md`

검증:

```bash
./scripts/update-rhwp-core.sh --channel demo --rev e91ecea3174a0da0ad7a1ea495cacc4f8772c31d
./scripts/build-rust-macos.sh --update-lock
rg -n "e91ecea3174a0da0ad7a1ea495cacc4f8772c31d|rhwp_ref_kind|rhwp_release_transition_status|rhwp_latest_checked_release" \
  RustBridge/Cargo.toml RustBridge/Cargo.lock rhwp-core.lock
git status --short
git diff --check
```

완료 조건:

- `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`이 같은 upstream merge commit 기준을 가리킨다.
- `rhwp-core.lock` artifact hash/size가 현재 generated artifact와 일치한다.
- Stable release tag 전환을 완료로 표시하지 않는다.

## Stage 3: RustBridge, lock, C ABI, no-AppKit 검증

대상:

- `RustBridge/`
- `Frameworks/` generated artifacts
- `rhwp-ffi-symbols.txt`
- `rhwp-core.lock`
- `Sources/RhwpCoreBridge/`

작업:

- Rust bridge build와 lock verify를 수행한다.
- expected FFI symbol snapshot과 generated symbol list를 비교한다.
- generated header의 `RhwpPageSize.width_pt`, `RhwpPageSize.height_pt` 유지 여부를 확인한다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존이 없는지 확인한다.
- ABI symbol 변경이 있으면 Swift 영향 분석 후 같은 단계에서 처리 여부를 작업지시자에게 보고한다.

산출물:

- `mydocs/working/task_m010_76_stage3.md`

검증:

```bash
./scripts/build-rust-macos.sh --verify-lock
diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
grep -n "width_pt\\|height_pt" Frameworks/generated_rhwp.h
./scripts/check-no-appkit.sh
bash -n scripts/update-rhwp-core.sh
bash -n scripts/build-rust-macos.sh
git diff --check
```

완료 조건:

- Rust bridge artifact가 `rhwp-core.lock`과 일치한다.
- FFI symbol set에 의도하지 않은 추가, 삭제, 이름 변경이 없다.
- Swift bridge boundary의 no-AppKit 규칙이 유지된다.

## Stage 4: HostApp, render smoke, image data use case 검증

대상:

- `project.yml`
- `AlhangeulMac.xcodeproj`
- `Sources/HostApp/`
- `Sources/QLExtension/`
- `Sources/ThumbnailExtension/`
- `Sources/RhwpCoreBridge/`
- `samples/`
- `scripts/validate-stage3-render.sh`

작업:

- `xcodegen generate`로 project를 재생성한다.
- HostApp Debug build를 수행한다.
- `validate-stage3-render.sh` 기본 샘플로 render tree decode, text run, non-white pixel smoke를 확인한다.
- 이미지가 포함된 샘플을 추가로 사용해 `bin_data_id` 기반 `rhwp_image_data` 조회 실패가 없는지 확인한다.
- 필요하면 Quick Look preview와 Finder thumbnail smoke를 수행한다.
- render 결과 차이나 실패가 있으면 core pin 갱신에 따른 회귀인지 환경 문제인지 분리해 보고한다.

산출물:

- `mydocs/working/task_m010_76_stage4.md`

검증:

```bash
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
find samples -name "*.hwp" -o -name "*.hwpx"
git diff --check
```

필요 시 추가 검증:

```bash
qlmanage -t -x -s 512 -o /tmp/rhwp-task76-ql <sample.hwp>
```

완료 조건:

- HostApp Debug build가 성공한다.
- 기본 render smoke가 통과한다.
- 이미지 use case에서 `bin_data_id` 조회 실패가 보고되지 않는다.
- Quick Look/Thumbnail 검증을 수행하지 않았다면 미실행 사유가 단계 보고서에 기록되어 있다.

## Stage 5: 문서 보정과 upstream 회신용 검증 결과 정리

대상:

- `mydocs/tech/core_release_compatibility.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- 필요 시 `mydocs/tech/project_architecture.md`
- 필요 시 `README.md`
- `mydocs/orders/20260429.md`
- `mydocs/report/task_m010_76_report.md`

작업:

- 현재 Demo/Preview pin이 upstream PR #385 merge commit 기준임을 문서화한다.
- latest checked release와 Stable blocked 사유를 구현 시점 기준으로 갱신한다.
- core compatibility 문서에서 `1e9d78a...` 중심 표현을 최신 pin 기준으로 보정한다.
- upstream 메인테이너에게 회신할 검증 요약을 최종 보고서에 별도 섹션으로 정리한다.
- 오늘할일을 완료 상태로 갱신한다.
- 전체 변경 파일의 diff check와 검색 gate를 수행한다.

산출물:

- `mydocs/working/task_m010_76_stage5.md`
- `mydocs/report/task_m010_76_report.md`

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
rg -n "1e9d78a1d40c71779d81c6ec6870cd301d912626|e91ecea3174a0da0ad7a1ea495cacc4f8772c31d|v0\\.7\\.|build_page_render_tree|get_bin_data|demo-commit-pin|Stable" \
  rhwp-core.lock RustBridge mydocs README.md
git status --short
```

완료 조건:

- core pin 갱신과 native bridge 검증 결과가 최종 보고서에 기록되어 있다.
- upstream 회신에 사용할 수 있는 짧은 검증 요약이 준비되어 있다.
- 오늘할일이 완료 상태로 갱신되어 있다.
- PR 게시 전 브랜치에 미커밋 변경이 없다.

## 승인 요청 사항

이 구현 계획서 기준으로 Stage 1 조사를 진행할지 승인 요청한다. 승인 전에는 `RustBridge`, lock, generated framework, core compatibility 문서 변경을 진행하지 않는다.
