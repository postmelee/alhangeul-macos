# Swift 및 macOS 코드 규칙 가이드

## 목적

이 문서는 macOS 앱/extension과 Swift bridge 계층의 상세 코드 규칙을 정리한다.

## 핵심 가드레일

- `Sources/RhwpCoreBridge`는 HostApp/Quick Look/Thumbnail 공통 계층이다.
- 공통 계층에는 AppKit/UIKit 직접 의존을 넣지 않는다.
- 플랫폼 UI 코드는 HostApp/extension/Shared 경계에서 처리한다.
- Rust FFI 경계의 포인터/길이/수명 해제 규칙을 명확히 유지한다.

## 계층별 역할

- `Sources/HostApp`: macOS 전용 UI/상태/입력 처리
- `Sources/QLExtension`: Quick Look preview provider
- `Sources/ThumbnailExtension`: Finder thumbnail provider
- `Sources/Shared`: preview/thumbnail/host 공통 helper
- `Sources/RhwpCoreBridge`: FFI wrapper, render tree 디코딩, CoreGraphics renderer

## 네이밍과 코드 스타일

- iOS에서 가져온 초기 이름은 macOS 또는 platform-neutral 이름으로 정리한다.
- bridge 계층은 데이터 변환과 렌더링에 집중하고, UI 상태를 갖지 않는다.
- HostApp은 문서 열기/줌/페이지 상태를 `Store` 계층에서 관리한다.

## FFI 안전성

- null pointer 입력을 방어한다.
- 길이(`len`)와 포인터의 일관성을 보장한다.
- 문자열 메모리 해제(`rhwp_free_string`) 호출 누락을 방지한다.
- handle 수명(`rhwp_open`/`rhwp_close`)과 Swift wrapper lifetime을 일치시킨다.

## 렌더링 관련 규칙

- render tree JSON 구조 변경 시 `RenderTree.swift` 디코더를 먼저 점검한다.
- 이미지 렌더링은 `bin_data_id` 인덱스 규칙(1-indexed)을 유지한다.
- 텍스트 렌더링은 CoreText 좌표계 변환을 문서화하고 임의 변경하지 않는다.
- 변경 후 `validate-stage3-render.sh`를 최소 smoke 검증으로 실행한다.
- node type, transform, clipping, image, text style 해석을 바꿨다면 문제 샘플에서 `render-debug-compare.sh`를 실행해 core SVG와 native PNG 차이를 확인한다.
- core SVG와 native PNG가 다르면 [`render_core_native_compare_guide.md`](render_core_native_compare_guide.md)의 판단 흐름에 따라 Swift renderer 문제와 core 문제를 분리한다.

### Render tree decode 오류 계약

`renderPageTree(at:) -> RenderNode?`는 기존 제품 caller를 위해 실패 시 nil을 유지한다. `renderPageTreeThrowing(at:)`와 `RenderTreeDecoder.decode`는 native smoke/CI 등 진단이 필요한 caller에서 사용한다. UInt32 변환 범위와 `pageCount` 밖의 요청은 invalidPageIndex, 유효한 page의 producer null JSON은 producerUnavailable로 구분한다. raw JSON API는 FFI null 경로 검증을 위해 UInt32 변환만 확인한다. envelope/known payload 오류는 `RenderTreeDecodingFailure`다.

Known variant의 필수 필드/형식 오류를 `.unknown` 성공으로 바꾸지 않는다. 올바른 단일 enum tag의 future variant는 `.unknown`으로 수용한다. 다중/빈 tag object와 payload variant의 unit 표현은 오류다. 추가 envelope 필드는 무시하므로 legacy `dirty` 호환은 유지한다. 하위 payload enum 전체의 정책이나 pixel parity를 보증하는 계약은 아니다.

Core의 usize index metadata는 UInt로 보존하여 머리말/꼬리말의 큰 unsigned marker를 손실시키지 않는다.

Known tag 목록은 CaseIterable enum에서 얻고 payload switch는 모든 case를 처리한다. 빈/다중 tag는 단일 variant를 단정하지 않으며 variant가 확정되지 않은 진단은 `unresolved`와 schema path/reason으로 표시한다. macOS 12 최소 지원은 유지하며 최신 OS/CI 성공을 최소 OS runtime 실행 증거로 대신하지 않는다.

진단은 known variant, schema coding path, 원인 분류만 포함한다. Foundation이 coding path 없는 비-DecodingError를 반환하는 경우 알려진 payload 경로와 `unexpectedDecoderError`를 유지한다. 문서 값, raw JSON, Foundation debugDescription/underlyingError는 오류 객체나 제품 로그에 넣지 않는다. wrapper는 stdout/stderr를 출력하지 않고 진단을 소비하는 CLI만 명시적으로 출력한다. C JSON 문자열은 복사 후 `rhwp_free_string`으로 해제한다.

## extension 특화 규칙

- Quick Look/Thumbnail은 메모리 사용량을 보수적으로 관리한다.
- 파일 크기 fallback 정책을 유지한다.
- sandbox 환경에서 실패 시 명확한 fallback 응답을 제공한다.

## 권장 검증

- `./scripts/check-no-appkit.sh`
- `./scripts/build-rust-macos.sh`
- `xcodegen generate`
- `xcodebuild ... HostApp ...`
- `./scripts/validate-stage3-render.sh`
- renderer 시각 결과 변경 시 `./scripts/render-debug-compare.sh output/render-debug path/to/sample.hwp`
