# rhwp Core Dependency 운영 가이드

## 목적

이 문서는 `edwardkim/rhwp` core를 앱 저장소에서 고정하고 갱신하는 절차를 정리한다. 현재 기준은 `RustBridge`의 git dependency와 lock provenance다.

## 소유 경계

- `edwardkim/rhwp`: Rust HWP/HWPX parser/renderer core
- `RustBridge`: 이 저장소가 소유하는 macOS C ABI bridge
- `RustBridge/Cargo.toml`: core dependency 선언
- `RustBridge/Cargo.lock`: Cargo가 해석한 core source와 resolved commit
- `rhwp-core.lock`: 앱 저장소 관점의 core provenance와 Rust bridge reference artifact metadata
- `Sources/RhwpCoreBridge`: Swift FFI wrapper/renderer
- `Sources/HostApp`: viewer app
- `Sources/QLExtension`: Quick Look preview extension
- `Sources/ThumbnailExtension`: Finder thumbnail extension
- `Sources/Shared`: 공통 helper

## core 기준

- Stable 안정 기준은 release tag + resolved commit. Demo/Preview는 필요한 API가 포함된 resolved commit을 `rev`로 고정.
- 현재 `rhwp-core.lock`은 `v0.7.11` Stable release tag pin 상태다. `RustBridge/Cargo.toml`은 `tag = "v0.7.11"`을 사용하고, `RustBridge/Cargo.lock`과 `rhwp-core.lock`은 resolved commit `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`를 기록한다.
- `v0.7.11`에는 현재 bridge가 요구하는 `build_page_render_tree`, `get_bin_data`, `render_page_svg_native`, `get_page_info_native`, `extract_thumbnail_only` API가 포함되어 있다.
- `main`, `devel` 같은 branch는 필요한 API가 포함된 과도기 commit을 찾는 참고 출처일 뿐, 안정 기준으로 사용하지 않는다.
- 채널별 dependency/lock 필드와 compatibility gate 상세는 [`core_release_compatibility.md`](../tech/core_release_compatibility.md)를 따른다.

## 운영 원칙

- core API 변경은 먼저 `edwardkim/rhwp`에 반영한다.
- 앱 저장소에서는 `RustBridge` dependency, `Cargo.lock`, `rhwp-core.lock`, Swift/Rust bridge 적응만 커밋한다.
- core를 로컬에서 실험해야 하면 별도 clone 또는 임시 Cargo patch/local override를 사용하고, local path 변경은 커밋하지 않는다.
- ABI 변경은 `rhwp-ffi-symbols.txt`와 Swift bridge 영향 검토를 동반한다.
- Demo/Preview 배포를 Stable release처럼 표시하지 않는다.
- branch나 floating ref를 배포 기준으로 사용하지 않는다.

## Artifact 검증 정책

`rhwp-core.lock`의 source provenance 필드(`rhwp_repo`, `rhwp_ref_kind`, `rhwp_release_tag`, `rhwp_commit`)는 Stable/Demo 기준을 고정하는 핵심 gate다. `Frameworks/generated_rhwp.h` hash/size와 `rhwp-ffi-symbols.txt`는 Swift/Rust ABI 표면 검증에 직접 연결되므로 CI와 release workflow에서 계속 검증한다.

`Frameworks/universal/librhwp.a` hash/size는 reference artifact metadata로 유지한다. 이 값은 기준 환경에서 생성한 Rust bridge static archive 식별자로 유용하지만, Rust compiler, Xcode, macOS runner image, archive tool, build path 차이에 따라 source와 ABI가 같아도 byte-for-byte 값이 달라질 수 있다.

GitHub-hosted CI/release workflow는 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`로 `librhwp.a` byte hash/size 비교만 제외할 수 있다. 이 경우에도 source provenance, `Cargo.lock`, generated header, FFI symbol 검증은 유지한다. strict staticlib byte hash를 필수 release gate로 복귀하려면 toolchain/runner/build path 또는 CI 기준 lock 생성 환경을 먼저 고정한다.

## 업데이트 절차

Demo/Preview commit pin:

```bash
./scripts/update-rhwp-core.sh --channel demo --rev <commit-sha>
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
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
xcodebuild -project Alhangeul.xcodeproj \
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

## upstream release 감지와 studio sync

`rhwp-core.lock`은 Rust bridge가 링크하는 core 기준이고, `Sources/HostApp/Resources/rhwp-studio/manifest.json`은 WKWebView viewer asset의 source release와 resolved commit 기준이다. 두 provenance는 release note와 검증에서 함께 확인하지만, 자동 sync PR은 public release 결정을 대신하지 않는다.

- `.github/workflows/rhwp-upstream-check.yml`은 read-only 감시 workflow로 upstream latest release와 `rhwp-core.lock`을 비교한다.
- `.github/workflows/rhwp-upstream-sync-pr.yml`은 viewer/WASM/core 영향 변경이 있을 때 `devel` 대상 `automation/rhwp-<tag>-studio-sync` branch와 bundled `rhwp-studio` 업데이트 후보 PR을 만든다.
- sync workflow는 PR 생성 전에 `scripts/update-rhwp-core.sh --check --channel stable --tag <tag>`로 target release compatibility를 조회하지만, `rhwp-core.lock`을 자동 수정하지 않는다.
- bundled studio asset 변경 PR은 PR CI에서 `scripts/verify-rhwp-studio-assets.sh`, HostApp build, Rust/core provenance verify, release helper dry-run을 확인한다.
- signed/notarized DMG, GitHub Release, Sparkle appcast, Homebrew Cask 반영은 별도 release 승인과 보호 workflow가 필요하다.

## 업데이트 후 확인 항목

- `RustBridge/Cargo.toml`의 dependency repo/ref와 의도한 채널 일치
- `RustBridge/Cargo.lock`의 `rhwp` source repo/ref/resolved commit
- `rhwp-core.lock`의 `rhwp_repo`, `rhwp_ref_kind`, `rhwp_commit` 일치
- Stable이면 `rhwp_release_tag`와 resolved commit 일치
- Demo/Preview이면 `rhwp_release_transition_status = "demo-commit-pin"` 유지
- `rhwp-core.lock`의 `Frameworks/universal/librhwp.a` reference metadata와 `Frameworks/generated_rhwp.h` sha256/size 기록 갱신 여부
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
