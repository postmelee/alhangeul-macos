# alhangeul-macos 프로젝트 아키텍처

## 목적

이 문서는 현재 `alhangeul-macos` 저장소가 소유하는 macOS 제품 타깃, 공통 Swift 계층, Rust bridge, 생성 산출물, 런타임 데이터 흐름, FFI 경계를 정리한다. 과거의 bridge 계획 문서를 대체하며, 현재 구현과 운영 기준을 기준으로 유지한다.

## 상위 구조

`alhangeul-macos`는 Mac 사용자를 위한 HWP/HWPX 파일 시스템 통합 유틸리티를 지향한다. 현재 v0.1 구현은 Quick Look preview, Finder thumbnail, 읽기 전용 HostApp viewer, Rust bridge를 소유하며, 제품 코드는 `Sources/` 아래에서 타깃별로 시작하고 공통 Swift 계층과 Rust bridge는 제품 타깃이 함께 쓰는 하위 기반으로 둔다.

```text
Sources/
├── HostApp/                  # 사용자가 직접 여는 macOS viewer app
├── QLExtension/              # Finder Quick Look preview extension
├── ThumbnailExtension/       # Finder thumbnail extension
├── Shared/                   # HostApp/extension 공통 macOS helper
└── RhwpCoreBridge/           # AppKit/UIKit 없는 Swift FFI wrapper + render tree renderer

RustBridge/                   # edwardkim/rhwp를 C ABI로 노출하는 Rust staticlib crate
Frameworks/                   # generated Rhwp.xcframework/header/modulemap 산출물
project.yml                   # Xcode project 원본
rhwp-core.lock                # core provenance + Rust bridge artifact hash/size
scripts/                      # build, lock verify, render smoke, package helper
mydocs/                       # hyper-waterfall 작업 문서와 운영 매뉴얼
```

## 제품 타깃

### HostApp

`Sources/HostApp`은 사용자가 직접 여는 macOS viewer app이다.

- `DocumentOpenPanel`과 외부 열기 요청을 통해 HWP/HWPX 파일 URL을 받는다.
- 보안 범위 접근, 문서 로딩 상태, 현재 페이지, 페이지 cache, zoom 상태를 관리한다.
- `DocumentPageView`를 통해 AppKit drawing을 수행하고 SwiftUI viewer UI를 구성한다.
- `project.yml` 기준으로 `Sources/Shared`, `Sources/RhwpCoreBridge`, `Frameworks/Rhwp.xcframework`에 의존한다.
- `QLExtension`과 `ThumbnailExtension`을 app bundle 안에 embed한다.

### QLExtension

`Sources/QLExtension`은 Finder Quick Look preview extension이다.

- Finder가 전달한 파일 URL을 받아 첫 페이지 preview를 만든다.
- `Shared/HwpPageImageRenderer`를 사용해 render tree 기반 bitmap을 생성하고 PNG preview로 반환한다.
- 50 MB를 초과하는 파일은 텍스트 fallback을 반환한다.
- full viewer의 page cache, zoom, navigation 상태는 소유하지 않는다.

### ThumbnailExtension

`Sources/ThumbnailExtension`은 Finder thumbnail extension이다.

- Finder thumbnail 요청 크기와 scale을 pixel bucket으로 정규화한다.
- `HwpThumbnailRenderCache`로 같은 파일과 크기 요청의 중복 렌더링을 줄인다.
- `Shared/HwpPageImageRenderer`를 사용해 첫 페이지 bitmap을 만들고, 요청 크기에 맞춰 aspect-fit으로 그린다.
- 50 MB를 초과하는 파일은 단순 fallback 타일을 반환한다.

## 공통 Swift 계층

### Shared

`Sources/Shared`는 HostApp과 extension이 함께 쓰는 macOS helper 계층이다.

- 현재 핵심 소유 코드는 `HwpPageImageRenderer`다.
- 파일 크기 제한, 첫 페이지 render tree 요청, bitmap context 생성, PNG 인코딩을 공통 처리한다.
- Finder/Quick Look 호출 방식에 가까운 helper는 이 계층에 둘 수 있다.
- 문서 핸들 수명, render tree 모델, FFI 호출 규칙 자체는 `RhwpCoreBridge`가 소유한다.

### RhwpCoreBridge

`Sources/RhwpCoreBridge`는 Swift에서 Rust core를 사용하는 최소 공통 bridge 계층이다.

- `RhwpDocument`가 Rust 문서 핸들의 생성과 해제를 관리한다.
- `RenderTree.swift`가 render tree JSON을 Swift 모델로 디코딩한다.
- `CGTreeRenderer`가 배경, 텍스트, 도형, 이미지, 그룹 노드를 CoreGraphics/CoreText로 렌더링한다.
- HostApp, Quick Look, Thumbnail이 모두 이 계층을 공유한다.
- 이 계층에는 AppKit/UIKit 직접 의존을 넣지 않는다. 플랫폼 UI 상태, 뷰 생명주기, Finder/Quick Look 연동은 상위 타깃 또는 `Shared`가 소유한다.

## Rust bridge와 core 경계

### core와 앱 저장소의 경계

- `edwardkim/rhwp`는 Rust HWP/HWPX parser/renderer core다.
- core API 변경은 먼저 `edwardkim/rhwp` 저장소에 반영한다.
- 앱 저장소는 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`, Swift/Rust bridge 적응만 소유한다.
- 앱 저장소 안에서 core를 직접 수정하지 않는다. core 실험은 별도 clone 또는 Cargo patch/local override로 수행하고 커밋하지 않는다.

### Demo/Preview와 Stable 기준

- 현재 v0.1.0 목표는 Demo/Preview release다.
- Demo/Preview 배포는 필요한 bridge API가 포함된 resolved commit을 `rev`로 고정하는 commit-pinned git dependency를 허용한다.
- Stable 안정 기준은 `edwardkim/rhwp` release tag와 resolved commit을 함께 고정하는 것이다.
- 현재 lock은 Demo/Preview commit pin 상태다. 2026-04-29 확인 release `v0.7.7`에는 `RustBridge`가 사용하는 `build_page_render_tree` API가 없어 Stable 전환은 blocked 상태다.
- branch/floating ref는 배포 기준으로 사용하지 않는다.

### RustBridge

`RustBridge`는 이 저장소가 소유하는 macOS C ABI 계층이다.

- Swift는 Rust core를 직접 호출하지 않고 `Rhwp.xcframework`의 `Rhwp` C module만 import한다.
- `RustBridge/src/lib.rs`는 Swift가 호출하는 `rhwp_*` FFI entrypoint를 제공한다.
- `RustBridge/Cargo.toml`은 `edwardkim/rhwp` git dependency를 선언한다.
- `RustBridge/Cargo.lock`은 Cargo가 해석한 resolved commit을 고정한다.
- 기대 ABI 표면은 `rhwp-ffi-symbols.txt`로 고정한다.

## 생성 산출물과 프로젝트 설정

### Frameworks

- `Frameworks/Rhwp.xcframework`는 생성 산출물이며 원본은 `RustBridge/`와 `scripts/build-rust-macos.sh`다.
- `Frameworks/generated_rhwp.h`, `Frameworks/module.modulemap`, `Frameworks/universal/librhwp.a`도 Rust bridge build 결과로 취급한다.
- Rust bridge 산출물의 hash/size와 core provenance는 `rhwp-core.lock`에 기록한다.
- 생성 산출물은 원본 코드가 아니므로 변경 시 build script와 lock 정합성을 함께 확인한다.

### Xcode project

- `project.yml`이 Xcode project의 원본이다.
- `AlhangeulMac.xcodeproj`는 생성물로 취급한다.
- target 구성, source 포함 범위, bundle identifier, extension embedding은 `project.yml`에서 관리한다.
- 사용자 표시명은 localized `InfoPlist.strings`에서 제공한다. 한국어 환경은 `알한글` 계열, 영어 환경은 `AlhangeulMac` 계열을 사용한다.
- 기본 `Info.plist`의 `CFBundleDisplayName`/`CFBundleName`은 실제 app/extension bundle filesystem name과 맞는 ASCII 값으로 둔다. 예: `AlhangeulMac.app`은 `AlhangeulMac`, `AlhangeulMacPreview.appex`는 `AlhangeulMacPreview`다. 한글 표시는 `ko.lproj/InfoPlist.strings`와 `LSHasLocalizedDisplayName`으로 제공한다.
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
6. HostApp은 페이지 cache와 zoom 상태를 관리하고, 실제 AppKit drawing은 `DocumentPageView`가 수행한다.

### Quick Look preview 경로

1. Finder가 `QLExtension`의 `HwpPreviewProvider`를 호출한다.
2. `HwpPreviewProvider`가 `Shared/HwpPageImageRenderer`에 첫 페이지 렌더링을 요청한다.
3. `HwpPageImageRenderer`가 `RhwpDocument`를 열고 첫 페이지 render tree를 bitmap으로 그린다.
4. preview는 렌더된 이미지를 PNG로 인코딩해 `QLPreviewReply`로 반환한다.
5. 파일이 50 MB를 초과하면 텍스트 fallback을 반환한다.

### Thumbnail 경로

1. Finder가 `ThumbnailExtension`의 `HwpThumbnailProvider`를 호출한다.
2. `HwpThumbnailRenderRequest`가 요청 크기, scale, 파일 수정 시각, 파일 크기를 cache key로 정리한다.
3. `HwpThumbnailRenderCache`가 동일 요청 또는 더 큰 cached bitmap을 재사용한다.
4. cache miss에서는 `Shared/HwpPageImageRenderer`가 첫 페이지 render tree를 bitmap으로 그린다.
5. thumbnail provider가 결과 이미지를 요청 크기에 맞춰 aspect-fit으로 그리고 extension badge를 붙인다.
6. 파일이 50 MB를 초과하면 단순 fallback 타일을 반환한다.

## 현재 Rust FFI 표면

현재 `Rhwp.xcframework`가 외부에 노출하는 기대 심볼은 다음과 같다.

- `rhwp_open`
- `rhwp_close`
- `rhwp_page_count`
- `rhwp_page_size`
- `rhwp_render_page_svg`
- `rhwp_render_page_tree`
- `rhwp_image_data`
- `rhwp_extract_thumbnail`
- `rhwp_free_string`
- `rhwp_free_bytes`

현재 제품 경로에서 핵심적으로 사용하는 API는 다음과 같다.

- `rhwp_open`: 문서 바이트를 파싱해 문서 핸들을 생성
- `rhwp_page_count`: 총 페이지 수 조회
- `rhwp_page_size`: 페이지 크기 조회
- `rhwp_render_page_tree`: 상세 render tree JSON 반환
- `rhwp_image_data`: `bin_data_id`에 대응하는 이미지 바이트 조회
- `rhwp_extract_thumbnail`: embedded thumbnail 바이트와 메타데이터 조회
- `rhwp_close`: 문서 핸들 해제
- `rhwp_free_string`: Rust가 할당한 문자열 해제
- `rhwp_free_bytes`: Rust가 소유권을 넘긴 byte buffer 해제

`rhwp_render_page_svg`는 현재 HostApp/extension의 주 렌더링 경로는 아니지만, 진단/호환성 관점에서 ABI에 포함되어 있다. core SVG와 native renderer 비교 절차는 [`render_core_native_compare_guide.md`](../manual/render_core_native_compare_guide.md)를 따른다.

## FFI 안전성 규칙

- null pointer 입력은 Rust와 Swift 양쪽에서 방어한다.
- `RhwpDocument`의 수명은 내부 `OpaquePointer` handle 수명과 일치해야 한다.
- `rhwp_render_page_tree`와 `rhwp_render_page_svg`가 반환한 문자열은 반드시 `rhwp_free_string`으로 해제한다.
- `rhwp_image_data`는 내부 문서 버퍼를 가리키므로, Swift에서는 즉시 `Data`로 복사해 사용한다.
- `rhwp_extract_thumbnail`이 반환한 byte buffer는 Swift에서 복사 후 `rhwp_free_bytes`로 해제한다.
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
- 현재 preview와 thumbnail의 기본 경로는 render tree 기반 bitmap 렌더링이다.

## 변경 시 주의할 점

- `Sources/RhwpCoreBridge`는 공통 계층이므로 AppKit/UIKit 직접 의존을 추가하지 않는다.
- HostApp 전용 AppKit drawing 코드는 `Sources/HostApp`에 둔다.
- Finder/Quick Look 호출 방식에 묶인 helper는 `Sources/QLExtension`, `Sources/ThumbnailExtension`, 또는 `Sources/Shared`에 둔다.
- render tree JSON 구조가 바뀌면 `RenderTree.swift`와 `CGTreeRenderer.swift`를 함께 검토한다.
- core 업데이트, ABI 변경, Swift 디코더 변경은 서로 영향을 주므로 분리된 단위로 검토한다.
- Demo/Preview commit pin을 Stable release처럼 표현하지 않는다.

## 운영 기준 문서

이 문서는 구조와 소유 경계를 설명한다. 실제 운영 절차는 다음 문서를 기준으로 한다.

- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/manual/swift_macos_code_rules_guide.md`
- `rhwp-core.lock`
