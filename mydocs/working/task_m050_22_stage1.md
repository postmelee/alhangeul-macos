# Issue #22 단계 1 완료 보고서

## 작업 내용

- `RustBridge/src/lib.rs`에서 `rhwp::wasm_api::HwpDocument` 의존을 제거했다.
- FFI 핸들 내부 타입을 `DocumentCore`로 교체해 macOS 네이티브 브리지가 WASM 어댑터가 아니라 코어 레이어에 직접 붙도록 정리했다.
- 기존 FFI 심볼 집합과 Swift 호출 표면은 유지한 채 내부 결합만 교체했다.

## 변경 상세

### 1. 브리지 의존 대상 교체

- `use rhwp::wasm_api::HwpDocument;`를 `use rhwp::DocumentCore;`로 변경했다.
- `RhwpHandle`의 `doc` 필드를 `DocumentCore`로 교체했다.
- `rhwp_open`은 `HwpDocument::from_bytes` 대신 `DocumentCore::from_bytes`를 사용하도록 바꿨다.

### 2. 유지한 사항

- `rhwp_open`, `rhwp_page_count`, `rhwp_page_size`, `rhwp_render_page_svg`, `rhwp_render_page_tree`, `rhwp_image_data`, `rhwp_free_string`, `rhwp_close` 심볼 집합은 유지했다.
- Swift 쪽 `RhwpDocument`와 extension/viewer 호출 경로는 이번 단계에서 수정하지 않았다.
- render tree 기반 Viewer/Quick Look 구조도 그대로 유지했다.

## 판단

- `DocumentCore`는 현재 FFI가 필요로 하는 `from_bytes`, `page_count`, `get_page_info_native`, `build_page_render_tree`, `render_page_svg_native`, `get_bin_data`를 직접 제공하므로, 1단계 목표는 추가 설계 변경 없이 달성 가능했다.
- 이 변경으로 네이티브 브리지가 `wasm_api` 레이어의 구조 변화에 덜 종속되게 되었다.

## 검증

- `rg -n "wasm_api::HwpDocument|HwpDocument::from_bytes" RustBridge/src/lib.rs`
  - 결과 없음
- `git diff --check -- RustBridge/src/lib.rs`
- `./scripts/build-rust-macos.sh`
  - arm64/x86_64 `RustBridge` 빌드 성공
  - universal staticlib 생성 성공
  - `cbindgen` header 및 `rhwp-ffi-symbols.txt` 비교 통과
  - `Rhwp.xcframework` 재생성 성공

참고:

- `xcodebuild -create-xcframework` 실행 중 CoreSimulator 관련 경고 로그는 있었지만, xcframework 생성 자체는 정상 완료되었다.

## 다음 단계

- 2단계에서 Thumbnail 전용 fast path 후보인 `extract_thumbnail_only`를 감싸는 FFI를 설계하고, 현재 첫 페이지 직접 렌더 fallback과의 책임 경계를 정리한다.

## 승인 요청 사항

- 이 단계 완료 기준으로 2단계 진행 승인 요청
