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

- iOS에서 가져온 초기 이름은 가능하면 플랫폼 중립 이름으로 정리한다.
  - 예: `mapHWPFontToApple`, `resolveAppleFont`
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
- 변경 후 `validate-stage3-render.sh`를 최소 검증으로 실행한다.

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
