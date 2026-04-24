# alhangeul-macos 프로젝트 아키텍처

## 목적

이 문서는 현재 `alhangeul-macos` 저장소가 소유하는 계층, 빌드 산출물, 런타임 데이터 흐름, FFI 경계를 정리한다. 과거의 bridge 계획 문서를 대체하며, 현재 구현과 운영 기준을 기준으로 유지한다.

## 상위 구조

`alhangeul-macos`는 macOS용 HWP/HWPX 읽기 전용 viewer 제품군을 소유한다.

- `HostApp`: 사용자가 직접 여는 macOS viewer app
- `QLExtension`: Finder Quick Look preview extension
- `ThumbnailExtension`: Finder thumbnail extension
- `Shared`: HostApp과 extension이 공유하는 macOS helper
- `RhwpCoreBridge`: Swift FFI wrapper, render tree 디코딩, CoreGraphics/CoreText renderer
- `RustBridge`: `Vendor/rhwp`를 C ABI로 노출하는 Rust staticlib crate
- `Vendor/rhwp`: `postmelee/rhwp`의 `devel`을 고정한 core submodule

## 소유 경계

### 1. core와 앱 저장소의 경계

- `Vendor/rhwp`는 Rust HWP/HWPX parser/renderer core다.
- core API 변경은 먼저 `postmelee/rhwp` 저장소에 반영한다.
- 앱 저장소는 `Vendor/rhwp`의 submodule pointer, `rhwp-core.lock`, Swift/Rust bridge 적응만 소유한다.
- 앱 저장소에 `Vendor/rhwp` 임시 수정을 남기지 않는다.

### 2. RustBridge 경계

- `RustBridge`는 이 저장소가 소유하는 macOS C ABI 계층이다.
- Swift는 `Vendor/rhwp`를 직접 호출하지 않고 `Rhwp.xcframework`의 `Rhwp` C module만 import한다.
- `Frameworks/Rhwp.xcframework`는 생성 산출물이며 원본은 `RustBridge/`와 `scripts/build-rust-macos.sh`다.
- 기대 ABI 표면은 `rhwp-ffi-symbols.txt`로 고정한다.

### 3. Swift bridge 경계

- `Sources/RhwpCoreBridge`는 HostApp, Quick Look, Thumbnail이 공통으로 사용하는 계층이다.
- 이 계층은 문서 핸들 수명 관리, render tree JSON 디코딩, 이미지 데이터 조회, CoreGraphics/CoreText 렌더링을 담당한다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 넣지 않는다.
- 플랫폼 UI 상태, 뷰 생명주기, Finder/Quick Look 연동은 상위 계층이 소유한다.

### 4. macOS UI 경계

- `Sources/HostApp`: 문서 열기, 보안 범위 접근, 페이지 상태, 줌 상태, SwiftUI/AppKit viewer UI
- `Sources/QLExtension`: Quick Look preview provider
- `Sources/ThumbnailExtension`: Finder thumbnail provider
- `Sources/Shared`: 여러 타깃이 함께 쓰는 첫 페이지 렌더 helper와 공통 유틸리티

### 5. 프로젝트 설정 경계

- `project.yml`이 Xcode project의 원본이다.
- `AlhangeulMac.xcodeproj`는 생성물로 취급한다.
- target 구성, source 포함 범위, bundle identifier, extension embedding은 `project.yml`에서 관리한다.
- 사용자 표시명은 localized `InfoPlist.strings`에서 제공한다. 한국어 환경은 `알한글` 계열, 영어 환경은 `AlhangeulMac` 계열을 사용한다.
- filesystem app bundle name과 내부 Xcode product/executable/module 이름은 `AlhangeulMac` 계열을 유지한다.
- Finder/Quick Look 통합 검증과 배포 zip 내부 `.app` 경로는 ExtensionKit lookup 안정성을 위해 ASCII 이름인 `AlhangeulMac.app`을 사용한다.
- LaunchServices/PlugInKit 등록 검증은 signed/sealed된 Release package 산출물 기준으로 수행한다. `CODE_SIGNING_ALLOWED=NO` Debug 산출물은 compile/link 및 bundle resource 확인용으로만 사용한다.

## 런타임 데이터 흐름

### HostApp viewer 경로

1. `DocumentOpenPanel` 또는 외부 열기 요청이 파일 URL을 전달한다.
2. `DocumentViewerStore`가 파일을 읽고 `RhwpDocument`를 생성한다.
3. `RhwpDocument`가 `rhwp_open`으로 Rust 문서 핸들을 연다.
4. 페이지별로 `rhwp_page_size`, `rhwp_render_page_tree`, `rhwp_image_data`를 사용해 렌더 데이터를 가져온다.
5. `RenderNode`와 `CGTreeRenderer`가 CoreGraphics/CoreText로 페이지를 그린다.
6. HostApp은 페이지 캐시와 줌 상태를 관리하고, 실제 AppKit drawing은 `DocumentPageView`가 수행한다.

### Quick Look / Thumbnail 경로

1. Finder가 `QLExtension` 또는 `ThumbnailExtension`을 호출한다.
2. 두 extension 모두 `Shared/HwpPageImageRenderer`를 사용해 첫 페이지를 공통 경로로 렌더링한다.
3. `HwpPageImageRenderer`는 문서 첫 페이지의 render tree를 bitmap으로 그린다.
4. 파일이 50 MB를 초과하면 preview는 텍스트 fallback, thumbnail은 단순 fallback 타일을 반환한다.

## 현재 Rust FFI 표면

현재 `Rhwp.xcframework`가 외부에 노출하는 기대 심볼은 다음과 같다.

- `rhwp_open`
- `rhwp_close`
- `rhwp_page_count`
- `rhwp_page_size`
- `rhwp_render_page_svg`
- `rhwp_render_page_tree`
- `rhwp_image_data`
- `rhwp_free_string`

현재 제품 경로에서 핵심적으로 사용하는 API는 다음과 같다.

- `rhwp_open`: 문서 바이트를 파싱해 문서 핸들을 생성
- `rhwp_page_count`: 총 페이지 수 조회
- `rhwp_page_size`: 페이지 크기 조회
- `rhwp_render_page_tree`: 상세 render tree JSON 반환
- `rhwp_image_data`: `bin_data_id`에 대응하는 이미지 바이트 조회
- `rhwp_close`: 문서 핸들 해제
- `rhwp_free_string`: Rust가 할당한 문자열 해제

`rhwp_render_page_svg`는 현재 HostApp/extension의 주 렌더링 경로는 아니지만, 진단/호환성 관점에서 ABI에 포함되어 있다.

## FFI 안전성 규칙

- null pointer 입력은 Rust와 Swift 양쪽에서 방어한다.
- `RhwpDocument`의 수명은 내부 `OpaquePointer` handle 수명과 일치해야 한다.
- `rhwp_render_page_tree`와 `rhwp_render_page_svg`가 반환한 문자열은 반드시 `rhwp_free_string`으로 해제한다.
- `rhwp_image_data`는 내부 문서 버퍼를 가리키므로, Swift에서는 즉시 `Data`로 복사해 사용한다.
- 이미지 조회의 `bin_data_id`는 1-indexed 규칙을 유지한다.

## 렌더링 구조

### render tree 기반 렌더링

- Rust core는 페이지를 상세 render tree JSON으로 직렬화한다.
- `Sources/RhwpCoreBridge/RenderTree.swift`가 JSON을 `RenderNode`로 디코딩한다.
- `CGTreeRenderer`가 배경, 텍스트, 도형, 이미지, 그룹 노드를 CoreGraphics/CoreText로 렌더링한다.

### 미리보기용 bitmap 렌더링

- `Shared/HwpPageImageRenderer`는 첫 페이지를 `CGContext`에 직접 그린다.
- Quick Look preview는 렌더된 이미지를 PNG로 인코딩해 반환한다.
- Thumbnail extension은 같은 이미지를 요청 크기에 맞춰 aspect-fit으로 그린다.

## 현재 구현 기준에서 주의할 점

- `Sources/RhwpCoreBridge`는 공통 계층이므로 AppKit/UIKit 직접 의존을 추가하지 않는다.
- HostApp 전용 AppKit drawing 코드는 `Sources/HostApp`에 둔다.
- render tree JSON 구조가 바뀌면 `RenderTree.swift`와 `CGTreeRenderer.swift`를 함께 검토한다.
- core 업데이트, ABI 변경, Swift 디코더 변경은 서로 영향을 주므로 분리된 단위로 검토한다.

## 운영 기준 문서

이 문서는 구조와 소유 경계를 설명한다. 실제 운영 절차는 다음 문서를 기준으로 한다.

- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/core_submodule_operation_guide.md`
- `mydocs/manual/swift_macos_code_rules_guide.md`
- `rhwp-core.lock`
