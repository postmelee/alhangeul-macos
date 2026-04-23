# Issue #22 단계 2 완료 보고서

## 작업 내용

- Thumbnail 전용 fast path 후보인 `extract_thumbnail_only`를 감싸는 Rust FFI를 `RustBridge`에 추가했다.
- 새 FFI가 반환하는 이미지 바이트의 소유권을 해제할 수 있도록 `rhwp_free_bytes`를 함께 추가했다.
- `rhwp-ffi-symbols.txt`를 갱신하고 `build-rust-macos.sh`로 심볼/헤더/xcframework 재생성을 검증했다.

## 추가한 FFI 표면

### 1. `rhwp_extract_thumbnail`

입력:

- 원본 파일 바이트 포인터와 길이

출력:

- `out_data`: heap-allocated 썸네일 바이트
- `out_len`: 바이트 길이
- `out_width`: 썸네일 너비
- `out_height`: 썸네일 높이
- `out_format`: `png` / `bmp` / `gif` / `unknown`

반환:

- 성공 시 `true`
- 썸네일 없음 또는 입력 오류 시 `false`

설계 의도:

- Viewer/Quick Look용 문서 핸들 기반 FFI와 분리된, Thumbnail 전용 raw-bytes fast path를 제공한다.
- `extract_thumbnail_only`는 전체 문서 open/paginate 없이 HWP/HWPX 컨테이너에서 preview 이미지만 읽으므로 Thumbnail 최적화에 적합하다.

### 2. `rhwp_free_bytes`

- `rhwp_extract_thumbnail`이 heap에 소유권을 넘긴 이미지 바이트를 해제하는 함수다.
- 기존 `rhwp_free_string`과 역할을 맞춰, 문자열/바이트 해제 책임을 명확히 분리했다.

## 유지한 사항

- 기존 문서 핸들 기반 FFI (`rhwp_open`, `rhwp_page_count`, `rhwp_page_size`, `rhwp_render_page_svg`, `rhwp_render_page_tree`, `rhwp_image_data`, `rhwp_close`)는 그대로 유지했다.
- Swift `ThumbnailExtension`은 이번 단계에서 아직 새 FFI를 사용하지 않는다.
- 첫 페이지 직접 렌더 fallback 정책도 이번 단계에서는 변경하지 않았다.

## 메모리/소유권 규칙

1. `rhwp_extract_thumbnail` 성공 시:
   - `out_data`는 호출자가 `rhwp_free_bytes(out_data, out_len)`로 해제해야 한다.
   - `out_format`은 호출자가 `rhwp_free_string(out_format)`로 해제해야 한다.
2. 실패 시:
   - 출력 포인터와 길이/크기는 0 또는 null로 초기화된다.
3. `rhwp_image_data`와 달리:
   - 이번 fast path의 바이트는 문서 핸들 내부 버퍼가 아니라 별도 heap 소유 메모리다.

## 판단

- Stage 1에서 네이티브 브리지가 `DocumentCore`에 직접 붙도록 정리한 덕분에, Stage 2는 `parser::extract_thumbnail_only`를 별도 raw-bytes API로 추가하는 선에서 분리된 역할을 만들 수 있었다.
- 이 설계로 다음 단계에서 `ThumbnailExtension`은 `embedded preview 우선 -> 실패 시 현재 첫 페이지 렌더 fallback` 정책을 구현할 수 있다.
- Quick Look과 Viewer는 계속 render tree 기반 경로를 유지하고, Thumbnail만 별도 fast path를 가지게 된다.

## 검증

- `git diff --check -- RustBridge/src/lib.rs rhwp-ffi-symbols.txt`
- `rg -n "rhwp_extract_thumbnail|rhwp_free_bytes" RustBridge/src/lib.rs rhwp-ffi-symbols.txt`
- `./scripts/build-rust-macos.sh`
  - arm64/x86_64 빌드 성공
  - `rhwp-ffi-symbols.txt` 비교 통과
  - 생성 헤더에 다음 시그니처 반영 확인
    - `bool rhwp_extract_thumbnail(...)`
    - `void rhwp_free_bytes(uint8_t *ptr, uintptr_t len);`
  - `Rhwp.xcframework` 재생성 성공

참고:

- `xcodebuild -create-xcframework` 과정에서 CoreSimulator 관련 경고가 있었지만, 산출물 생성과 심볼 검증은 정상 완료되었다.

## 다음 단계

- 3단계에서 Swift 호출 경로를 반영한다.
- 목표 정책:
  - `ThumbnailExtension`: embedded preview 우선
  - 실패 시 현재 `HwpPageImageRenderer.renderFirstPage` fallback
  - Viewer/Quick Look: 현행 render tree 경로 유지

## 승인 요청 사항

- 이 단계 완료 기준으로 3단계 진행 승인 요청
