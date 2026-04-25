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

## core 최신화 기준

1. `postmelee/rhwp`의 `devel`: 실제 사용 기준
2. `edwardkim/rhwp`의 `devel`: upstream 참고 기준
3. `edwardkim/rhwp`의 `ios/devel`: native viewer 변경 참고 기준

## 운영 원칙

- 앱 저장소에서 `Vendor/rhwp`에 임시 수정을 남기지 않는다.
- core API 변경은 먼저 `postmelee/rhwp` `devel`에 반영한다.
- 앱 저장소에서는 submodule pointer와 `rhwp-core.lock`을 함께 갱신한다.
- ABI 변경은 `rhwp-ffi-symbols.txt`와 Swift bridge 영향 검토를 동반한다.

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

## 업데이트 후 확인 항목

- `Vendor/rhwp` commit과 `rhwp-core.lock`의 `rhwp_commit` 일치
- `rhwp-core.lock`의 `Frameworks/universal/librhwp.a`, `Frameworks/generated_rhwp.h` sha256/size 기록 갱신 여부
- `rhwp-ffi-symbols.txt` 변경 여부와 의도성
- Swift `RenderTree` 모델과 core JSON 구조 호환성
- Quick Look/Thumbnail smoke test 필요 여부

## 금지 사항

- `Vendor/rhwp` 변경만 커밋하고 `rhwp-core.lock`을 누락
- ABI 영향 검토 없이 FFI 변경 반영
- upstream 대상 PR과 앱 저장소 PR을 혼합 진행
