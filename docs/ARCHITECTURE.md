# rhwp-mac 아키텍처

## 소유 경계

- `Vendor/rhwp`: upstream `edwardkim/rhwp`의 코어 엔진 submodule. 앱 코드는 수정하지 않는다.
- `Sources/RhwpCoreBridge`: macOS 앱이 소유하는 Swift FFI/렌더 브리지.
- `Sources/HostApp`: macOS viewer 앱.
- `Sources/QLExtension`: Quick Look preview extension.
- `Sources/ThumbnailExtension`: Finder thumbnail extension.
- `Sources/Shared`: preview/thumbnail/host app에서 공유하는 macOS 전용 helper.

## Swift bridge 정책

기존 `rhwp-ios/Sources`의 공유 Swift 파일은 초기 이식 자산으로만 사용한다. 분리 후에는 iOS 코드와 직접 공유하지 않고, 이 레포의 `Sources/RhwpCoreBridge`가 독립적으로 소유한다.

플랫폼 중립 이름을 사용한다.

- `mapHWPFontToApple`
- `resolveAppleFont`

## rhwp submodule 정책

코어 최신화 기준은 upstream `devel`이다. `ios/devel`은 iOS 앱 참고용 브랜치이며, 이 프로젝트의 코어 최신화 기준으로 사용하지 않는다.

submodule 업데이트 후에는 다음을 확인한다.

1. `scripts/build-rust-macos.sh`
2. `scripts/check-no-appkit.sh`
3. HostApp/QLExtension/ThumbnailExtension Xcode build
4. Finder Quick Look 및 thumbnail smoke test

## FFI ABI 정책

`rhwp-ffi-symbols.txt`의 심볼 목록을 기대 ABI로 사용한다. `cbindgen`으로 생성한 헤더의 `rhwp_` 심볼 목록이 달라지면 코어 ABI 변경으로 간주하고 Swift bridge를 함께 검토한다.

## 현재 코어 API gap

upstream `devel`은 최신 코어 브랜치지만, 기존 macOS prototype이 사용하던 iOS/macOS C ABI를 아직 제공하지 않는다.

현재 필요한 항목:

1. native staticlib 또는 파생 프로젝트에서 빌드 가능한 public bridge API
2. `cbindgen` 대상 C ABI 정의
3. `rhwp_render_page_tree`가 Swift `CGTreeRenderer`에서 필요한 상세 render tree JSON을 반환하는 경로
4. 이미지 바이너리 조회 API (`rhwp_image_data` 상당)

따라서 이 레포는 `Vendor/rhwp`를 upstream `devel` submodule로 고정하되, 기존 기능을 완전히 복구하려면 다음 중 하나가 필요하다.

- upstream `devel`에 macOS/iOS viewer용 public native bridge API를 추가한다.
- 이 레포에 별도 Rust bridge crate를 두되, upstream `devel`이 상세 render tree와 이미지 데이터를 public API로 노출하도록 먼저 정리한다.

`ios/devel`의 Swift/FFI 코드는 참고 자료로만 사용하고, 코어 최신화 기준으로 사용하지 않는다.
