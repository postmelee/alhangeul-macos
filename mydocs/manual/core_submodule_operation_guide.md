# rhwp Core Dependency 운영 가이드

## 목적

이 문서는 `edwardkim/rhwp` core를 앱 저장소에서 고정하고 갱신하는 절차를 정리한다. 파일명은 과거 submodule 운영 문서명을 유지하지만, 현재 기준은 `RustBridge`의 git dependency와 lock provenance다.

## 소유 경계

- `edwardkim/rhwp`: Rust HWP/HWPX parser/renderer core
- `RustBridge`: 이 저장소가 소유하는 macOS C ABI bridge
- `RustBridge/Cargo.toml`: core dependency 선언
- `RustBridge/Cargo.lock`: Cargo가 해석한 core source와 resolved commit
- `rhwp-core.lock`: 앱 저장소 관점의 core provenance와 Rust bridge 산출물 hash/size
- `Sources/RhwpCoreBridge`: Swift FFI wrapper/renderer
- `Sources/HostApp`: viewer app
- `Sources/QLExtension`: Quick Look preview extension
- `Sources/ThumbnailExtension`: Finder thumbnail extension
- `Sources/Shared`: 공통 helper

## core 기준

- Stable 안정 기준은 `edwardkim/rhwp` release tag와 resolved commit을 함께 고정하는 것이다.
- Demo/Preview 배포는 필요한 bridge API가 포함된 resolved commit을 `rev`로 고정하는 commit-pinned git dependency를 허용한다.
- 현재 `rhwp-core.lock`은 Demo/Preview commit pin 상태를 기록한다.
- 최신 확인 release `v0.7.3`에는 `RustBridge`가 사용하는 `build_page_render_tree`, `get_bin_data` API가 없어 Stable 전환은 blocked 상태다.
- `main`, `devel` 같은 branch는 필요한 API가 포함된 과도기 commit을 식별하는 출처일 뿐, 앱의 안정 기준으로 취급하지 않는다.
- release tag compatibility와 Demo/Preview commit 기준은 [`core_release_compatibility.md`](../tech/core_release_compatibility.md)를 따른다.

## 운영 원칙

- core API 변경은 먼저 `edwardkim/rhwp`에 반영한다.
- 앱 저장소에서는 `RustBridge` dependency, `Cargo.lock`, `rhwp-core.lock`, Swift/Rust bridge 적응만 커밋한다.
- core를 로컬에서 실험해야 하면 별도 clone 또는 임시 Cargo patch/local override를 사용하고, local path 변경은 커밋하지 않는다.
- ABI 변경은 `rhwp-ffi-symbols.txt`와 Swift bridge 영향 검토를 동반한다.
- Demo/Preview 배포를 Stable release처럼 표시하지 않는다.
- branch나 floating ref를 배포 기준으로 사용하지 않는다.

## 업데이트 절차

Demo/Preview commit pin:

```bash
./scripts/update-rhwp-core.sh --channel demo --rev <commit-sha>
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
```

Stable release tag:

```bash
./scripts/update-rhwp-core.sh --channel stable --tag <release-tag>
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
```

조회/검증만 수행하고 파일을 바꾸지 않을 때:

```bash
./scripts/update-rhwp-core.sh --check --channel stable --tag <release-tag>
```

`validate-stage3-render.sh`의 기본 샘플은 앱 저장소 루트의 `samples/`를 사용한다. core 저장소 내부 샘플 경로는 기본 검증 경로로 사용하지 않는다.

## 업데이트 후 확인 항목

- `RustBridge/Cargo.toml`의 dependency repo/ref와 의도한 채널 일치
- `RustBridge/Cargo.lock`의 `rhwp` source repo/ref/resolved commit
- `rhwp-core.lock`의 `rhwp_repo`, `rhwp_ref_kind`, `rhwp_commit` 일치
- Stable이면 `rhwp_release_tag`와 resolved commit 일치
- Demo/Preview이면 `rhwp_release_transition_status = "demo-commit-pin"` 유지
- `rhwp-core.lock`의 `Frameworks/universal/librhwp.a`, `Frameworks/generated_rhwp.h` sha256/size 기록 갱신 여부
- `rhwp-ffi-symbols.txt` 변경 여부와 의도성
- Swift `RenderTree` 모델과 core JSON 구조 호환성
- Quick Look/Thumbnail smoke test 필요 여부
- Demo/Preview 배포인지 Stable 배포인지와 해당 core 기준

## 금지 사항

- branch dependency 또는 floating ref를 배포 기준으로 사용
- Cargo local path override를 커밋
- `Cargo.lock`과 `rhwp-core.lock`의 resolved commit 불일치 방치
- ABI 영향 검토 없이 FFI 변경 반영
- core 저장소 PR과 앱 저장소 PR을 혼합 진행
- Demo/Preview 배포를 Stable release처럼 표시
