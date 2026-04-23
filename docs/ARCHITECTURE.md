# alhangeul-macos 아키텍처

## 소유 경계

- `Vendor/rhwp`: 개인 fork `postmelee/rhwp`의 코어 엔진 submodule. 앱 코드는 수정하지 않는다.
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

코어 최신화 기준은 `postmelee/rhwp`의 `devel`이다. upstream `edwardkim/rhwp`의 `devel`은 최신 core 참고 기준이고, `ios/devel`은 검증된 native viewer 변경을 선별 포팅하는 참고 브랜치로만 사용한다.

submodule 업데이트 후에는 다음을 확인한다.

1. `scripts/build-rust-macos.sh`
2. `scripts/check-no-appkit.sh`
3. HostApp/QLExtension/ThumbnailExtension Xcode build
4. Finder Quick Look 및 thumbnail smoke test

## FFI ABI 정책

`rhwp-ffi-symbols.txt`의 심볼 목록을 기대 ABI로 사용한다. `cbindgen`으로 생성한 헤더의 `rhwp_` 심볼 목록이 달라지면 코어 ABI 변경으로 간주하고 Swift bridge를 함께 검토한다.

## 현재 코어 API 상태

`postmelee/rhwp`의 `devel`은 upstream `devel`에 `ios/devel`의 native viewer core 변경을 선별 포팅한 브랜치다. 이 레포는 `RustBridge` crate에서 C ABI를 소유한다.

현재 구현된 항목:

1. `RustBridge` staticlib
2. `cbindgen` 기반 C header/modulemap 생성
3. 기존 8개 FFI 심볼 export

Issue #3에서 추가한 core API:

1. 상세 render tree serde JSON 직렬화
2. `build_page_render_tree`
3. `get_bin_data`

`ios/devel`의 Swift/FFI 코드는 참고 자료로만 사용하고, 코어 최신화 기준으로 사용하지 않는다. 관련 Issue와 PR은 upstream이 아니라 이 저장소에서 관리한다.
