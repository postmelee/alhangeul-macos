# alhangeul-macos 프로젝트 아키텍처

## 목적

이 문서는 현재 `alhangeul-macos` 저장소가 소유하는 macOS 제품 타깃, 공통 Swift 계층, Rust bridge, 생성 산출물, 런타임 데이터 흐름, FFI 경계를 정리한다. 과거의 bridge 계획 문서를 대체하며, 현재 구현과 운영 기준을 기준으로 유지한다.

## 상위 구조

`alhangeul-macos`는 Mac 사용자를 위한 HWP/HWPX 파일 시스템 통합 유틸리티를 지향한다. 현재 v0.1 구현은 Quick Look preview, Finder thumbnail, 읽기 전용 HostApp viewer, Rust bridge를 소유하며, 제품 코드는 `Sources/` 아래에서 타깃별로 시작하고 공통 Swift 계층과 Rust bridge는 제품 타깃이 함께 쓰는 하위 기반으로 둔다.

```text
Sources/
├── HostApp/                  # 사용자가 직접 여는 macOS WKWebView viewer app
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
- 보안 범위 접근으로 원본 파일 bytes를 읽고 `rhwp-studio` WKWebView에 전달할 문서 payload와 revision을 관리한다.
- 앱 bundle의 `Resources/rhwp-studio` 정적 asset을 `alhangeul-studio://app` 내부 resource scheme으로 제공하고, `alhangeul-document://current` 내부 document scheme으로 현재 문서 bytes를 제공한다.
- `rhwp-studio` 파일 메뉴와 `Command/Ctrl+O/S/P` 단축키의 열기/저장/인쇄 명령은 WKUserScript, `WKScriptMessageHandler`, AppKit key equivalent fallback, SwiftUI File menu command를 통해 HostApp의 `DocumentOpenPanel`, 형식 인식형 `DocumentSavePanel`, PDF export panel과 AppKit print operation으로 연결한다.
- HWP/HWPX 저장 메뉴와 native 저장 UX, 형식·destination 검증과 atomic write는 HostApp이 소유한다. 현재 편집 상태의 HWP/HWPX bytes 생성과 저장 성공 뒤 dirty state 정리는 bundled `rhwp-studio`의 embed RPC가 담당한다.
- HostApp titlebar toolbar는 macOS 공유, Finder에서 보기, PDF로 내보내기, 최근 문서 접근을 제공한다. 공유 picker는 toolbar 버튼에 심은 `NSViewRepresentable` anchor view를 기준으로 표시한다.
- HostApp MVP viewer의 zoom/page/search 조작은 `rhwp-studio` 내부 UI가 소유한다.
- `project.yml` 기준으로 `Sources/Shared`, `Sources/RhwpCoreBridge`, `Frameworks/Rhwp.xcframework`를 포함하지만, MVP viewer 화면과 사용자용 PDF export는 native render tree 경로를 호출하지 않는다. PDF export와 일반 인쇄는 현재 editor의 upstream page SVG를 HostApp 전용 `RhwpStudioPagePDFRenderer`가 `WKWebView.createPDF`로 변환하는 경로를 공유한다.
- `QLExtension`과 `ThumbnailExtension`을 app bundle 안에 embed한다.

### QLExtension

`Sources/QLExtension`은 Finder Quick Look preview extension이다.

- Finder가 전달한 파일 URL을 받아 전체 페이지 preview를 만든다.
- `Shared/HwpPreviewPDFRenderer`와 `Shared/HwpPageImageRenderer`를 사용해 render tree 기반 page bitmap을 생성한다.
- 단일 페이지 문서는 PNG reply로 반환하고, 다중 페이지 문서는 Quick Look 표시용 PDF preview로 반환한다.
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

- 현재 핵심 소유 코드는 `HwpPageImageRenderer`와 `HwpPreviewPDFRenderer`다.
- 파일 크기 제한, page index 기반 render tree 요청, bitmap context 생성, PNG 인코딩, Quick Look 표시용 PNG/PDF preview 생성을 공통 처리한다.
- HostApp MVP viewer 화면, 사용자용 PDF export와 일반 인쇄는 이 native bitmap helper를 직접 호출하지 않는다. `HwpPreviewPDFRenderer`는 Finder Quick Look 다중-page preview용 PDF container를 만드는 경로에 한정한다.
- Finder/Quick Look 호출 방식에 가까운 helper는 이 계층에 둘 수 있다.
- 문서 핸들 수명, render tree 모델, FFI 호출 규칙 자체는 `RhwpCoreBridge`가 소유한다.

### RhwpCoreBridge

`Sources/RhwpCoreBridge`는 Swift에서 Rust core를 사용하는 최소 공통 bridge 계층이다.

- `RhwpDocument`가 Rust 문서 핸들의 생성과 해제를 관리한다.
- `RenderTree.swift`가 render tree JSON을 Swift 모델로 디코딩한다.
- `CGTreeRenderer`가 배경, 텍스트, 도형, 이미지, 그룹 노드를 CoreGraphics/CoreText로 렌더링한다.
- Quick Look preview와 Finder thumbnail은 이 render tree 기반 bitmap 경로를 공유한다. HostApp MVP viewer 화면, 사용자용 PDF export와 일반 인쇄는 WKWebView `rhwp-studio`와 upstream page SVG 경로를 사용한다.
- 장기 native macOS viewer/editor shell은 Swift가 renderer 전체를 재구현하는 것이 아니라 Rust/rhwp Skia renderer와 Swift 편집 UI/오버레이를 결합하는 방향으로 둔다. 책임 경계는 [`native_macos_skia_editor_strategy.md`](native_macos_skia_editor_strategy.md)를 따른다.
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
- 현재 lock은 `v0.8.2` Stable release tag pin 상태다. `rhwp-core.lock`은 release tag `v0.8.2`와 resolved commit `9b16aa9e23f476e2b335d7c029fc9f24a199d63c`를 함께 기록한다.
- `v0.8.2`에는 현재 `RustBridge`가 사용하는 page/render/image API와 `set_file_name`, `get_external_image_references`, `inject_external_image_by_key` external image context API가 포함되어 있다.
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
- `Alhangeul.xcodeproj`는 생성물로 취급한다.
- target 구성, source 포함 범위, bundle identifier, extension embedding은 `project.yml`에서 관리한다.
- 사용자 표시명은 localized `InfoPlist.strings`에서 제공한다. 한국어 환경은 `알한글` 계열, 영어 환경은 `Alhangeul` 계열을 사용한다.
- 기본 `Info.plist`의 `CFBundleDisplayName`/`CFBundleName`은 실제 app/extension bundle filesystem name과 맞는 ASCII 값으로 둔다. 예: `Alhangeul.app`은 `Alhangeul`, `AlhangeulPreview.appex`는 `AlhangeulPreview`다. 한글 표시는 `ko.lproj/InfoPlist.strings`와 `LSHasLocalizedDisplayName`으로 제공한다.
- filesystem app bundle name과 내부 Xcode product/executable/module 이름은 `Alhangeul` 계열을 유지한다.
- Finder/Quick Look 통합 검증과 배포 zip 내부 `.app` 경로는 ExtensionKit lookup 안정성을 위해 ASCII 이름인 `Alhangeul.app`을 사용한다.
- LaunchServices/PlugInKit 등록 검증은 signed/sealed된 Release package 산출물 기준으로 수행한다. `CODE_SIGNING_ALLOWED=NO` Debug 산출물은 compile/link 및 bundle resource 확인용으로만 사용한다.

## 런타임 데이터 흐름

### HostApp 익명 실행 이벤트 경로

HostApp은 앱 실행과 version 전환을 영구 사용자·기기·설치 식별자 없이 익명 이벤트로 기록할 수 있다. 이벤트는 문서 데이터 흐름과 분리된 `Sources/HostApp/Services/AppExecution*` 계층이 소유하며, 네트워크가 없어도 앱 실행·문서 열기·종료와 Sparkle 업데이트를 막지 않는다. payload, 오프라인 outbox, opt-out, 지표 해석과 운영 검증 기준은 [`task_m040_453_app_execution_analytics_contract.md`](task_m040_453_app_execution_analytics_contract.md)를 따른다.

### HostApp viewer 경로

1. `DocumentOpenPanel` 또는 외부 열기 요청이 파일 URL을 전달한다.
2. `DocumentViewerStore`가 보안 범위 접근 안에서 파일 bytes를 읽고 파일명, bytes, document revision을 `RhwpStudioDocumentPayload`로 보관한다.
3. `DocumentViewerView`가 `RhwpStudioWebView`를 표시한다.
4. `RhwpStudioResourceLocator`가 `alhangeul-studio://app/index.html`에 `url=alhangeul-document://current?revision=...`와 `filename=...` query를 붙여 entrypoint URL을 만든다.
5. `RhwpStudioResourceSchemeHandler`가 app bundle의 `Resources/rhwp-studio` 정적 asset을 MIME type과 함께 응답한다.
6. `rhwp-studio` JS가 WASM/CSS/font asset을 같은 `alhangeul-studio://app` origin에서 fetch한다.
7. `rhwp-studio`의 `loadFromUrlParam()`이 내부 document URL을 `fetch`하면 `RhwpStudioDocumentSchemeHandler`가 현재 revision의 bytes를 `application/octet-stream`으로 응답한다.
8. HWP/HWPX parsing, page layout, zoom/page UI는 `rhwp-studio`와 그 WASM bundle이 담당한다.
9. `파일 > 열기`는 injected host bridge script가 Swift callback으로 전달해 기존 문서 열기 flow를 다시 호출한다.
10. `파일 > 저장`, `다른 이름으로 저장`, `HWP 형식으로 저장`, `HWPX 형식으로 저장`은 injected bridge가 upstream menu handler보다 먼저 소비해 HostApp command로 전달한다.
11. HostApp은 명시적 형식 command를 우선하고, 일반 저장 command는 current source URL, 현재 filename, 기본 HWP 순서로 저장 형식을 정한다.
12. HWP 저장은 `exportHwpBase64`와 `exportHwp` fallback을, HWPX 저장은 `exportHwpx`를 사용해 현재 편집 상태의 bytes를 받는다.
13. HostApp은 요청·응답 형식, byte count, CFB/ZIP signature와 destination 확장자를 확인한 뒤 security-scoped source 또는 native panel에서 선택한 URL에 atomic write한다.
14. 저장 성공 뒤 current source와 최근 문서를 실제 destination으로 갱신하고 `notifySaved(fileName)`을 호출해 upstream filename, dirty state와 recovery 상태를 동기화한다.
15. `파일 > 인쇄`는 active editor state를 settle한 뒤 `pageCount`와 page별 `getPageSvg`를 순서대로 수집하고, HostApp 공용 page SVG renderer로 만든 `PDFDocument`를 PDFKit/AppKit print operation에 전달한다.
16. 내부 `PDF로 저장…`의 `file:print-to-pdf`와 toolbar의 `file:export-pdf`는 canonical `file:export-pdf`로 합쳐진다. HostApp이 native destination panel을 먼저 표시한 뒤 현재 editor의 page SVG를 수집하고, `WKWebView.createPDF`로 page geometry와 text layer를 보존한 PDF를 만들어 atomic write한 성공 URL만 Finder에 표시한다.
17. `공유`는 active editor element를 settle한 뒤 `rhwp-studio`의 `exportHwp` response bytes를 임시 파일로 만든 뒤 `NSSharingServicePicker`로 전달한다.
18. 최근 문서는 security-scoped bookmark와 함께 저장하고, toolbar menu에서 다시 열 수 있게 한다.

### HostApp HWP/HWPX 저장 경로

#### 소유 경계

- HostApp은 upstream 파일 메뉴의 저장 command를 native command로 intercept하고 저장 형식 결정, `NSSavePanel`, destination, security-scoped 접근, payload 검증, atomic write, current source와 최근 문서 갱신을 소유한다.
- bundled `rhwp-studio`는 현재 editor state를 settle하고 해당 형식 exporter를 호출하며, HWP/HWPX bytes를 HostApp에 전달한다. 로컬 파일 경로 선택과 write는 수행하지 않는다.
- durable write 뒤 HostApp은 `notifySaved(fileName)` embed RPC를 호출한다. upstream은 filename, dirty state와 recovery draft를 정리하고 HostApp은 저장 완료 상태를 표시한다.
- `notifySaved` 실패는 이미 완료된 파일 write와 current source 갱신을 되돌리지 않는다. HostApp은 파일 저장과 editor state 동기화 실패를 구분해 사용자에게 알린다.

#### command와 형식 결정

| command | 형식 결정 | destination |
|---------|-----------|-------------|
| `file:save` | current source URL → 현재 filename → 기본 HWP | 같은 형식의 source가 있으면 제자리 저장, source가 없거나 write에 실패하면 같은 형식 save panel |
| `file:save-as` | current source URL → 현재 filename → 기본 HWP | 현재 형식을 유지하는 native save panel |
| `file:save-as-hwp` | 명시적 HWP | HWP native save panel |
| `file:save-as-hwpx` | 명시적 HWPX | HWPX native save panel |

지원 확장자는 대소문자를 구분하지 않고 판정한다. 저장 패널의 title, UTI, 기본 filename과 확장자 정규화는 하나의 `DocumentSaveFormat`에서 파생하며 `.hwp.hwpx` 같은 중복 suffix를 만들지 않는다. source와 filename 모두 형식을 제공하지 않는 새 문서·임시 문서는 HWP를 기본값으로 사용한다.

명시적 HWPX 저장이 성공하면 current source URL과 filename이 실제 `.hwpx` destination으로 바뀐다. 이후 일반 `Command+S`는 current source에서 HWPX를 다시 결정하므로 panel 없이 같은 URL에 `exportHwpx` 결과를 저장한다. HWPX에서 HWP로 저장한 반대 방향도 동일한 규칙으로 후속 `Command+S`가 HWP exporter를 유지한다.

#### exporter와 write 전 검증

```text
HWP  -> exportHwpBase64 -> 미지원 시 exportHwp fallback
HWPX -> exportHwpx -> chunked base64 encode
```

bridge의 `save-document` response는 `format`, 정규화한 `fileName`, `base64`, `byteCount`를 포함한다. HostApp은 다음 조건을 모두 만족한 경우에만 파일을 쓴다.

1. destination과 format을 가진 pending save request가 존재한다.
2. response format이 HWP/HWPX 중 하나이며 pending format과 일치한다.
3. base64 decode 결과와 `byteCount`가 일치한다.
4. HWP는 CFB magic, HWPX는 ZIP magic을 가진다.
5. destination 확장자와 요청 format이 일치한다.

검증 실패 시 파일, current source, 최근 문서와 clean state를 변경하지 않는다. 제자리 atomic write가 실패하면 원래 요청 format을 유지한 native save panel로 fallback한다. 저장 패널 선택이나 export가 진행 중일 때 들어온 중복 요청은 새 pending state를 만들지 않는다.

runtime signature guard는 완전히 다른 형식의 bytes를 잘못된 확장자로 쓰는 오류를 빠르게 막는 역할만 한다. HWPX의 `mimetype`, `Contents/`, `META-INF/` entry와 실제 재열기는 별도 container/render smoke에서 확인한다.

#### 지원 범위와 호환 제한

- HostApp은 upstream exporter가 반환한 bytes를 별도 본문 변환 없이 atomic write한다. HWP/HWPX parser, document model과 exporter의 형식 호환성은 bundled `rhwp-studio`/`rhwp` 구현 범위에 따른다.
- 대표 fixture에서 HWP → HWP, HWP → HWPX, HWPX → HWPX, HWPX → HWP 저장과 재열기, page 1의 텍스트·표·이미지 또는 non-blank render를 검증했다. 이는 모든 HWP/HWPX 기능의 의미론적 완전 무손실을 보장하지 않는다.
- HWPX runtime 검증은 ZIP magic까지만 수행한다. 손상된 ZIP이나 필수 entry가 빠진 container는 별도 검증 없이는 runtime guard를 통과할 수 있다.
- HWPX exporter는 call-stack overflow를 피하도록 chunked base64 encoding하지만, JS와 Swift 양쪽에 전체 payload를 보유하는 메모리 비용은 남는다.
- 공유는 이 저장 경로와 별개로 HWP exporter payload를 사용하는 기존 동작을 유지한다. PDF export와 일반 인쇄는 HWP/HWPX bytes exporter를 사용하지 않고 현재 editor의 page SVG를 사용한다.

### HostApp PDF 저장과 일반 인쇄 경로

#### command와 native save ownership

bundled `rhwp-studio`의 내부 PDF menu command는 `file:print-to-pdf`지만 HostBridge가 upstream browser print handler보다 먼저 소비해 `file:export-pdf`로 정규화한다. HostApp toolbar도 처음부터 `file:export-pdf`를 전달하므로 두 진입점은 같은 coordinator method와 native save panel을 사용한다.

| 진입점 | 입력 command | canonical command | HostApp 동작 |
|--------|---------------|-------------------|--------------|
| 내부 `PDF로 저장…` | `file:print-to-pdf` | `file:export-pdf` | `requestPDFExport` |
| titlebar toolbar PDF | `file:export-pdf` | `file:export-pdf` | `requestPDFExport` |

HostApp은 다음 pending state를 소유한다.

```text
idle
  -> choosingDestination(requestID, loadID)
  -> collectingPages(requestID, destinationURL)
  -> exporting(requestID)
  -> idle
```

- `DocumentPDFExportPanel`은 `choosingDestination`에서 한 번만 native sheet로 표시된다.
- panel 취소는 page SVG를 요청하지 않고 `idle`로 복귀한다.
- destination이 결정된 뒤에만 HostBridge의 PDF page 수집 함수를 평가한다.
- request ID는 HostBridge의 성공·실패 message까지 왕복하며 현재 request와 일치하는 응답만 state를 전이시킨다.
- 문서 load identity가 바뀌거나 main WebContent process가 종료되면 destination 선택·page 수집 request를 무효화하고 늦게 도착한 응답을 무시한다. 이미 독립 renderer에서 시작한 export는 해당 request completion까지 유지한다.
- page 수집, render/write 중 중복 export command는 새 panel이나 pending destination을 만들지 않는다.
- bridge evaluation, payload 검증, render와 write의 성공·실패 completion은 request ID와 controller identity가 일치할 때만 pending controller와 state를 정리한다.
- offscreen renderer의 WebContent process 종료는 명시적 실패 completion으로 변환해 export state가 `exporting`에 남지 않게 한다.
- write에 성공한 destination만 Finder에 표시한다.

#### page SVG payload와 공용 renderer

upstream과 HostApp 사이의 PDF/print payload는 형식에 관계없이 다음 구조를 사용한다.

```json
{
  "fileName": "example.hwpx",
  "pageCount": 3,
  "pages": ["<svg ...>", "<svg ...>", "<svg ...>"]
}
```

HostBridge의 `documentPages()`는 active editor state를 settle한 뒤 `pageCount`를 읽고 page index 0부터 `getPageSvg`를 순차 호출한다. 각 page 요청 timeout은 30초다. `RhwpStudioPagePayload`는 양의 page count, 실제 SVG 배열 수와 비어 있지 않은 page SVG를 검증한다.

```text
current editor
  -> pageCount + getPageSvg(page) 순차 수집
  -> RhwpStudioPagePayload
  -> RhwpStudioPagePDFRenderer
       -> page SVG를 전용 WKWebView에 load
       -> SVG width/height/viewBox 기반 page metrics 계산
       -> page 크기로 WKPDFConfiguration.rect 설정
       -> WKWebView.createPDF
       -> PDFKit으로 단일 page를 최종 PDFDocument에 순서대로 삽입
```

`RhwpStudioPagePDFRenderer`는 PDF command, save panel과 파일 write를 소유하지 않는다. page별 geometry 확인과 `WKWebView.createPDF` 호출, page count 일치 검증만 담당한다.

- `RhwpStudioPDFExportController`는 renderer 결과의 `%PDF` signature를 확인하고 선택한 URL에 `Data.write(.atomic)`으로 기록한다.
- `RhwpStudioPrintController`는 같은 renderer 결과를 `PDFDocument.printOperation`에 전달한다. 모든 non-square page 방향이 하나로 일치할 때만 job orientation을 초기화하며, 가로·세로 혼합 문서는 job orientation을 강제하지 않고 PDFKit auto-rotate에 맡긴다.
- Quick Look과 Thumbnail은 이 renderer를 사용하지 않는다. 두 extension은 `RhwpDocument`와 render tree 기반 `HwpPageImageRenderer`의 bitmap 경로를 유지한다.

#### page SVG trust boundary

upstream `getPageSvg` 결과는 현재 editor에서 생성되지만 원본 문서 내용에서 유래한 markup이므로 trusted executable HTML이 아니라 비신뢰 정적 렌더 입력으로 취급한다. renderer는 SVG 문자열 자체를 범용 sanitizer로 재작성하지 않고, 전용 offscreen WebView의 실행·resource·navigation capability를 최소화한다.

| 방어선 | 계약 |
|--------|------|
| WebView 격리 | renderer 전용 `WKWebViewConfiguration`과 `WKWebView`를 사용하고 website data store는 `.nonPersistent()`로 둔다. main editor WebView, user script, message handler와 URL scheme handler를 공유하지 않는다. |
| 문서 script 차단 | `defaultWebpagePreferences.allowsContentJavaScript = false`와 `javaScriptCanOpenWindowsAutomatically = false`를 적용한다. SVG `<script>`, event handler와 `javascript:` URL을 실행하지 않는다. |
| app-owned metrics | page 크기 측정 script만 `WKContentWorld.defaultClient`에서 실행한다. 이 world는 page script 전역과 격리되며 DOM의 width/height, viewBox와 bounding rect만 읽는다. 실패 시 content JavaScript를 다시 켜는 fallback은 없다. |
| subresource policy | raw SVG보다 앞에 CSP meta를 배치한다. `default-src`, script, connect, frame, object, media, worker, manifest와 font는 `'none'`이며 `base-uri`와 `form-action`도 거부한다. wrapper/SVG 표현을 위한 inline style과 실제 page bitmap을 위한 `data:` image만 허용한다. |
| navigation policy | page마다 `loadHTMLString(baseURL: nil)`이 만드는 최초 main-frame `about:blank` navigation만 한 번 허용한다. 이후 main-frame 이동, subframe, `targetFrame == nil` new-window와 HTTP/HTTPS/file/blob/custom scheme navigation은 취소한다. |
| 실패 처리 | page load·metrics·`createPDF`를 포함한 page별 render가 30초 안에 끝나지 않으면 watchdog timeout으로 완료한다. invalid metrics, 단일-page PDF가 아닌 결과, 잘못된 media box, 최종 page count 불일치와 WebContent process 종료도 명시적 render 실패로 반환한다. 권한을 확대하거나 차단된 resource를 다시 로드하지 않는다. |

navigation delegate는 모든 image, font와 CSS subresource 요청을 관측하는 경계가 아니므로 외부 resource 차단은 CSP가 담당하고 navigation policy는 frame·document 이동을 담당한다. non-persistent store는 renderer session의 website data를 영구 저장하지 않는 마지막 격리선이다. 이 세 정책 중 하나를 제거할 때는 다른 정책이 같은 범위를 대신한다고 가정하지 않고 WebKit 통합 테스트를 함께 갱신해야 한다.

WebKit은 navigation policy에서 `.cancel`한 load에 `didFinish`나 `didFailProvisionalNavigation`을 보장하지 않는다. page별 watchdog은 정책이 정상 load를 취소하거나 WebKit callback이 멈춰도 renderer completion을 timeout 실패로 정확히 한 번 호출하고 다음 PDF·인쇄 요청이 재진입할 수 있게 한다. `finish`는 정상·실패·timeout 모두에서 watchdog과 WebView load를 정리한다.

HostAppTests는 CSP가 없는 test-only WebView가 `127.0.0.1` 임시 listener에 실제 연결되는 양성 대조를 먼저 확인한 뒤, hardened renderer의 HTTP/HTTPS image, `<use>`, CSS paint/font/stylesheet, iframe, object, meta refresh와 new-window fixture가 연결 0건인지 검증한다. 별도 script/event sentinel은 page content가 실행되지 않으면서 HostApp metrics, searchable text, embedded data PNG와 nested data SVG raster가 유지됨을 확인한다.

허용된 `style-src 'unsafe-inline'`과 `img-src data:`는 현재 upstream page SVG 충실도에 필요한 최소 예외다. HTTP/HTTPS, `blob:`, file URL, 외부 font와 임의 custom scheme은 허용하지 않는다. upstream이 향후 data font나 다른 resource 계약을 추가하면 기존 예외를 넓히기 전에 대표 HWP/HWPX PDF·인쇄 회귀, script/network 차단과 deployment target WebKit 동작을 별도 변경으로 검증해야 한다.

이 trust boundary는 사용자용 PDF export와 일반 인쇄의 공용 offscreen renderer에만 적용된다. main editor의 `alhangeul-studio://app` resource policy, HWP/HWPX 저장 exporter, Quick Look/Thumbnail과 Rust `rhwp` core의 실행 경계는 변경하지 않는다.

#### HWP/HWPX와 원본 불변 경계

PDF 저장은 HWP와 HWPX에 같은 `pageCount`/`getPageSvg` 경로를 적용한다. HWPX를 HWP로 중간 변환하지 않으며 `exportHwp`, `exportHwpBase64`, `exportHwpx`, `RhwpDocument`와 `HwpPreviewPDFRenderer`는 사용자용 PDF export controller의 입력이 아니다.

PDF export는 non-mutating command다.

- current source URL, current filename과 source format을 변경하지 않는다.
- HWP/HWPX 원본 bytes를 다시 쓰지 않는다.
- editor dirty state를 clean으로 바꾸거나 `notifySaved`를 호출하지 않는다.
- 현재 editor state에서 생성한 page SVG만 destination PDF에 반영한다.

Stage 4 실제 UI smoke에서 HWP/HWPX menu와 toolbar 결과의 page count, page geometry, 추출 text와 page raster가 일치했다. KTX 가로 page는 `1123 × 794 pt`, 대표 HWP/HWPX는 upstream과 같은 9쪽 `794 × 1123 pt`를 유지했고 모든 page가 nonblank였다. macOS Preview에서 한글 text selection과 저장 전 current edit 반영도 확인했다. smoke 전후 원본 SHA-256과 수정 시각은 변하지 않았다.

#### 잔여 제한과 실패 기준

- page SVG는 순차 생성·변환하지만 bridge message와 native payload가 전체 page SVG 문자열을 보유하므로 대용량·다중-page 문서의 memory/time 비용이 남는다.
- page별 `getPageSvg`와 native page render에는 각각 30초 timeout이 있지만 전체 document export를 포괄하는 별도 deadline은 없다.
- SVG page metrics는 명시적 width/height, viewBox, bounding rect 순으로 해석하고 정수 point로 올림한다. 잘못되거나 0 이하인 metrics와 최종 page count 불일치는 오류로 종료한다.
- upstream SVG는 Preview에서 선택 가능한 text layer를 유지하지만 positioned text 특성 때문에 `pdftotext -layout`에서 한글이나 편집 marker 사이에 시각 위치 기준 공백이 추가될 수 있다.
- Quartz PDF metadata에는 생성 시각이 포함되므로 같은 본문을 다시 저장해도 PDF file SHA-256은 달라질 수 있다. 본문 동등성은 page count, geometry, extracted text와 raster 비교로 판정한다.
- destination panel 취소는 output을 만들지 않는다. atomic write 실패는 partial destination을 남기지 않고 사용자 오류를 표시하며 state를 `idle`로 복구한다.

### Quick Look preview 경로

1. Finder가 `QLExtension`의 `HwpPreviewProvider`를 호출한다.
2. `HwpPreviewProvider`가 `Shared/HwpPreviewPDFRenderer.load(fileURL:)`로 파일 크기, page count, 첫 페이지 크기를 확인하고 `RhwpDocument`를 한 번 연다.
3. 단일 페이지 문서는 data creation block에서 첫 페이지 bitmap을 PNG로 encoding해 `.png` `QLPreviewReply`로 반환한다.
4. 다중 페이지 문서는 같은 `RhwpDocument`를 `HwpPreviewPDFRenderer`에 넘겨 `pageCount`만큼 page index를 순회한다.
5. 각 페이지는 `Shared/HwpPageImageRenderer`가 render tree 기반 bitmap으로 그린다.
6. 다중 페이지 preview는 페이지별 bitmap을 Quick Look 표시용 PDF page에 담아 `.pdf` `QLPreviewReply`로 반환한다.
7. 파일이 50 MB를 초과하면 텍스트 fallback을 반환한다.

이 PDF는 Finder Quick Look이 다중 페이지 preview를 표시하도록 하는 임시 컨테이너이며, 사용자용 PDF export나 HWP/HWPX 구조 변환 산출물이 아니다. 현재 data reply 구조에서는 첫 페이지만 먼저 표시한 뒤 나머지를 append하는 true lazy pagination은 구현하지 않는다.

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
- `rhwp_set_file_name_utf8`
- `rhwp_external_image_refs_json`
- `rhwp_inject_external_image_by_key`
- `rhwp_page_count`
- `rhwp_page_size`
- `rhwp_render_page_svg`
- `rhwp_render_page_tree`
- `rhwp_page_overlay_images`
- `rhwp_render_page_png`
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
- `rhwp_set_file_name_utf8`: filename context를 document에 설정
- `rhwp_external_image_refs_json`: external image reference와 loaded 상태를 upstream JSON 배열로 조회
- `rhwp_inject_external_image_by_key`: Swift/macOS shell이 읽은 image bytes를 reference key로 주입
- `rhwp_close`: 문서 핸들 해제
- `rhwp_free_string`: Rust가 할당한 문자열 해제
- `rhwp_free_bytes`: Rust가 소유권을 넘긴 byte buffer 해제

`rhwp_render_page_svg`는 현재 HostApp/extension의 주 렌더링 경로는 아니지만, 진단/호환성 관점에서 ABI에 포함되어 있다. core SVG와 native renderer 비교 절차는 [`render_core_native_compare_guide.md`](../manual/render_core_native_compare_guide.md)를 따른다.

External image context ABI는 #409 Swift wrapper/Quick Look 적용 전까지 제품 경로에서 직접 호출하지 않는다. RustBridge는 external path를 열지 않으며 source URL 권한, resolver policy, bytes read와 cache signature는 Swift/macOS shell 책임이다. `rhwp_image_state_json`은 pinned public API가 전체 image 상태를 제공하지 않아 현재 ABI에 포함하지 않는다.

## FFI 안전성 규칙

- null pointer 입력은 Rust와 Swift 양쪽에서 방어한다.
- `RhwpDocument`의 수명은 내부 `OpaquePointer` handle 수명과 일치해야 한다.
- `rhwp_render_page_tree`와 `rhwp_render_page_svg`가 반환한 문자열은 반드시 `rhwp_free_string`으로 해제한다.
- `rhwp_external_image_refs_json`이 반환한 문자열도 반드시 `rhwp_free_string`으로 해제한다.
- filename, external key, image bytes, display path 입력 pointer는 caller-owned이며 FFI 호출 동안 유효해야 한다.
- `rhwp_image_data`가 반환한 non-null pointer는 caller-owned allocation이다. Swift에서는 즉시 `Data`로 복사하고 반환받은 동일 pointer와 length를 `rhwp_free_bytes`로 정확히 한 번 해제한다.
- `rhwp_image_data` allocation은 document handle과 독립이며 `rhwp_free_bytes` 호출 전까지 유효하다. free 뒤 pointer를 보관하거나 재사용하지 않는다.
- `rhwp_extract_thumbnail`이 반환한 byte buffer도 Swift에서 복사 후 `rhwp_free_bytes`로 해제한다.
- 이미지 조회의 `bin_data_id`는 1-indexed 규칙을 유지한다.

## 렌더링 구조

### render tree 기반 렌더링

- Rust core는 페이지를 상세 render tree JSON으로 직렬화한다.
- `Sources/RhwpCoreBridge/RenderTree.swift`가 JSON을 `RenderNode`로 디코딩한다.
- `CGTreeRenderer`가 배경, 텍스트, 도형, 이미지, 그룹 노드를 CoreGraphics/CoreText로 렌더링한다.

### 미리보기용 bitmap 렌더링

- `Shared/HwpPageImageRenderer`는 요청된 page index를 `CGContext`에 직접 그린다.
- Quick Look preview는 단일 페이지 문서를 PNG로 반환하고, 다중 페이지 문서는 렌더된 page bitmap들을 PDF page에 삽입해 반환한다.
- Thumbnail extension은 같은 이미지를 요청 크기에 맞춰 aspect-fit으로 그린다.
- render tree 기반 bitmap renderer의 제품 경로는 Quick Look preview와 Thumbnail이다. Quick Look 다중-page PDF는 Finder 표시를 위한 bitmap container이며 사용자용 PDF export와 다른 산출물이다.

### HostApp page SVG PDF 렌더링

- HostApp PDF export와 일반 인쇄는 bundled `rhwp-studio`가 현재 editor state에서 생성한 page SVG를 사용한다.
- 문서 유래 page SVG는 비신뢰 정적 렌더 입력이다. `RhwpStudioPagePDFRenderer`는 non-persistent 전용 WKWebView에서 content JavaScript를 끄고 deny-by-default CSP, 최초 `about:blank` main-frame 1회만 허용하는 navigation policy와 page별 30초 watchdog을 적용한다.
- HostApp의 page metrics script만 `WKContentWorld.defaultClient`에서 실행해 SVG metrics를 보존하고 `WKWebView.createPDF`를 호출한 뒤 PDFKit으로 결과 page를 합친다.
- `RhwpStudioPDFExportController`는 결과를 사용자 destination에 atomic write하며, `RhwpStudioPrintController`는 같은 `PDFDocument`를 AppKit print operation에 전달한다.
- 이 경로는 HWP/HWPX source bytes, `RhwpDocument`, render tree bitmap과 `HwpPreviewPDFRenderer`를 거치지 않는다.
- PDF의 searchable/selectable text semantics는 upstream page SVG와 WebKit PDF 생성 결과에 따른다.

### 장기 HostApp native 경로

- HostApp의 장기 native viewer/editor 경로는 Swift native macOS shell과 Rust/rhwp Skia renderer를 결합하는 방향으로 둔다.
- Swift 계층은 window, toolbar, sidebar, zoom/scroll/cache orchestration, accessibility, caret/selection/IME/ruler/object overlay, command routing을 소유한다.
- HWP/HWPX parsing, document model, layout, Skia rendering, hit-test/selection anchor, dirty region, save/export 안정성은 core와 RustBridge contract가 소유해야 한다.
- CoreGraphics/CoreText render tree renderer는 현행 Quick Look/Thumbnail의 기준 경로이자 fallback/diagnostic 경로로 유지한다. HostApp PDF export와 일반 인쇄의 기준 경로는 upstream page SVG와 WebKit PDF renderer다.
- native editor mutation은 renderer 도입만으로 열지 않고, hit-test, selection, mutation, dirty state, save/round-trip gate를 별도 이슈에서 통과해야 한다.

## 변경 시 주의할 점

- `Sources/RhwpCoreBridge`는 공통 계층이므로 AppKit/UIKit 직접 의존을 추가하지 않는다.
- HostApp 전용 WebKit/AppKit bridge 코드는 `Sources/HostApp`에 둔다.
- native render tree 기반 bitmap 경로는 Quick Look/Thumbnail에 필요한 범위에서 `Sources/Shared`와 `Sources/RhwpCoreBridge`에 유지한다.
- HostApp native macOS shell과 Swift overlay 상태는 `Sources/HostApp` 또는 상위 UI 계층이 소유하고, `Sources/RhwpCoreBridge`에 UI 상태를 넣지 않는다.
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
