# rhwp Core Submodule 운영 가이드

## 목적

이 문서는 `Vendor/rhwp` core submodule 운영 절차를 정리한다.

## 소유 경계

- `Vendor/rhwp`: Rust HWP/HWPX parser/renderer core
- `RustBridge`: 이 저장소가 소유하는 macOS C ABI bridge
- `Sources/RhwpCoreBridge`: Swift FFI wrapper/renderer
- `Sources/HostApp`: viewer app
- `Sources/QLExtension`: Quick Look preview extension
- `Sources/ThumbnailExtension`: Finder thumbnail extension
- `Sources/Shared`: 공통 helper

## core 기준

- 안정 기준은 `edwardkim/rhwp` release tag와 resolved commit을 함께 고정하는 것이다.
- 현재 `Vendor/rhwp` submodule은 release tag 전환 전까지의 임시 운용 경로다.
- 현재 lock은 release tag 전환 대기 상태를 기록한다.
- 최신 확인 release `v0.7.3`에는 `RustBridge`가 사용하는 `build_page_render_tree`, `get_bin_data` API가 없어 즉시 전환하지 않는다.
- `devel` branch는 필요한 API가 포함된 과도기 commit을 식별하는 출처일 뿐, 앱의 안정 기준으로 취급하지 않는다.

## 운영 원칙

- 앱 저장소에서 `Vendor/rhwp`에 임시 수정을 남기지 않는다.
- core API 변경은 먼저 `edwardkim/rhwp`에 반영한다.
- 앱 저장소에서는 submodule pointer와 `rhwp-core.lock`을 함께 갱신하되, 새 core 최신화는 release tag 전환 가능 여부를 먼저 확인한다.
- ABI 변경은 `rhwp-ffi-symbols.txt`와 Swift bridge 영향 검토를 동반한다.
- `Vendor/rhwp` 제거와 릴리즈 기반 git dependency 전환은 후속 Issue #30에서 진행한다.

## 업데이트 절차

```bash
./scripts/update-rhwp-core.sh
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

`validate-stage3-render.sh`의 기본 샘플은 앱 저장소 루트의 `samples/`를 사용한다. core submodule 갱신 후에도 기본 검증 경로는 submodule 내부 샘플 디렉터리에 의존하지 않아야 한다.

이 절차는 release tag 전환 전까지의 submodule 검증 절차다. 새 release가 나왔을 때는 먼저 해당 tag의 resolved commit으로 `RustBridge`가 빌드되는지 확인하고, 통과하는 경우 후속 dependency 전환 계획에 반영한다.

## 업데이트 후 확인 항목

- `Vendor/rhwp` commit과 `rhwp-core.lock`의 `rhwp_commit` 일치
- `rhwp-core.lock`의 `Frameworks/universal/librhwp.a`, `Frameworks/generated_rhwp.h` sha256/size 기록 갱신 여부
- `rhwp-ffi-symbols.txt` 변경 여부와 의도성
- Swift `RenderTree` 모델과 core JSON 구조 호환성
- Quick Look/Thumbnail smoke test 필요 여부

## 금지 사항

- `Vendor/rhwp` 변경만 커밋하고 `rhwp-core.lock`을 누락
- ABI 영향 검토 없이 FFI 변경 반영
- core 저장소 PR과 앱 저장소 PR을 혼합 진행
