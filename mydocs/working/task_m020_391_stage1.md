# Task M020 #391 Stage 1 보고서

단계: Stage 1 `현재 app ABI와 image data 계약 inventory`

## 요약

- 현재 Swift shell은 문서 `fileURL`을 알고 있지만 RustBridge에는 문서 bytes와 `filename` 중 bytes만 전달한다.
- `RhwpDocument(data:filename:)`의 `filename`은 parse 실패 에러 메시지, Quick Look title/log, HostApp display name에만 쓰이고 `rhwp_open` 호출에는 들어가지 않는다.
- RustBridge current open ABI는 `rhwp_open(data,len)`뿐이며 내부에서 `DocumentCore::from_bytes(bytes)`를 호출한다. base path, absolute path, package URL, resource resolver, diagnostic channel은 없다.
- Swift render tree image model은 `ImageNode.bin_data_id`를 중심으로 `rhwp_image_data(handle, bin_data_id, out_len)`를 조회한다. external path/ref/status를 담는 필드는 없다.
- CoreGraphics renderer는 image byte가 없거나 decode에 실패하면 해당 이미지를 조용히 생략한다. overlay image도 base64 payload 또는 `bin_data_id` bytes가 없으면 fallback을 타지만, fallback 역시 동일한 `rhwp_image_data` 계약에 묶인다.
- Quick Look/Thumbnail extension은 sandbox + user-selected read-only entitlement를 갖고 main file URL을 읽는다. sibling/external resource 탐색, injection, cache signature 반영은 현재 없다.

## Current call graph

### Quick Look Preview

1. `HwpPreviewProvider.providePreview`가 `QLFilePreviewRequest.fileURL`을 받는다.
2. `HwpPreviewPDFRenderer.load(fileURL:)`이 main file을 읽고 `RhwpDocument`를 만든다.
3. 단일 페이지는 PNG reply, 복수 페이지는 PDF reply로 갈라지지만 같은 `HwpPreviewDocumentContext.document`를 사용한다.
4. native render path는 `HwpPageImageRenderer.renderPage(document:pageIndex:)`로 들어간다.

근거:

- `Sources/QLExtension/HwpPreviewProvider.swift:12-19` request의 `fileURL`에서 preview context를 생성한다.
- `Sources/QLExtension/HwpPreviewProvider.swift:41-60` PNG reply title에는 `filename`을 쓰지만 render 입력은 이미 열린 context다.
- `Sources/QLExtension/HwpPreviewProvider.swift:74-92` PDF reply도 title/log 용도로 `filename`을 사용한다.
- `Sources/Shared/HwpPreviewPDFRenderer.swift:173-181` main file을 `Data(contentsOf:)`로 읽고 `fileURL.lastPathComponent`를 `RhwpDocument(data:filename:)`에 넘긴다.
- `Sources/Shared/HwpPreviewPDFRenderer.swift:120-124` PDF 각 페이지 render는 `HwpPageImageRenderer.renderPage(document:pageIndex:)`를 호출한다.

### Finder Thumbnail

1. `HwpThumbnailProvider.provideThumbnail`이 `QLFileThumbnailRequest.fileURL`을 받는다.
2. `HwpThumbnailRenderRequest`는 cache key에 path, mtime, file size, requested pixel bucket, renderer signature를 넣는다.
3. cache miss 시 `HwpPageImageRenderer.renderFirstPage(fileURL:)`가 main file을 읽고 `RhwpDocument(data:filename:)`를 만든다.

근거:

- `Sources/ThumbnailExtension/HwpThumbnailProvider.swift:12-25` request file URL과 maximum size를 render request로 만든다.
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift:19-36` cache key는 main file path, modification time, file size, pixel bucket, render signature로 구성된다.
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift:190-197` cache miss render는 `HwpPageImageRenderer.renderFirstPage(fileURL:...)`로 위임한다.
- `Sources/Shared/HwpPageImageRenderer.swift:120-141` main file을 `Data(contentsOf:)`로 읽고 `fileURL.lastPathComponent`를 wrapper에 전달한다.

### HostApp

1. `DocumentViewerStore.loadDocument(from:)`는 file URL에 대해 security-scoped access를 시작하고 main file bytes를 읽는다.
2. store state는 `RhwpStudioDocumentPayload(data, filename, revision)`만 보관한다.
3. 현재 MVP viewer는 bundled `rhwp-studio` WKWebView 중심이다. native PDF export만 `RhwpDocument(data:filename:)`를 직접 사용한다.

근거:

- `Sources/HostApp/Stores/DocumentViewerStore.swift:43-64` HostApp은 URL에 대해 `startAccessingSecurityScopedResource()` 후 `Data(contentsOf:)`를 읽고 basename만 보존한다.
- `Sources/HostApp/Stores/DocumentViewerStore.swift:188-203` store payload는 `data`, `filename`, `revision`만 갖는다.
- `Sources/HostApp/Services/RhwpStudioDocumentPayload.swift:3-7` payload model에 source URL/base directory는 없다.
- `Sources/HostApp/Services/RhwpStudioPDFExportController.swift:49-65` native PDF export는 payload data와 filename으로 `RhwpDocument`를 다시 연다.

## Current RustBridge ABI

| Symbol | 역할 | filename/external context 관점 |
|--------|------|--------------------------------|
| `rhwp_open(data,len)` | bytes에서 `DocumentCore` 생성 | filename/base path 인자가 없다. |
| `rhwp_render_page_tree(handle,page)` | page render tree JSON 반환 | image node가 external ref/status를 표현하는지는 upstream JSON shape에 전적으로 의존한다. |
| `rhwp_page_overlay_images(handle,page)` | overlay compact JSON 반환 | compact JSON 자체에는 `binDataId`가 없고 Swift가 render tree supplement로 보강한다. |
| `rhwp_image_data(handle,bin_data_id,out_len)` | embedded BinData bytes 조회 | 1-indexed id 조회만 가능하다. missing 이유는 구분하지 않는다. |
| `rhwp_render_page_png(handle,page,...)` | Skia PNG export | export options에 font paths만 있고 document filename/resource context는 없다. |

근거:

- `rhwp-ffi-symbols.txt:1-12` exported symbol 목록에는 open context, external refs, bytes injection, diagnostic API가 없다.
- `RustBridge/src/lib.rs:101-116` `rhwp_open`은 data pointer/length만 검사하고 `DocumentCore::from_bytes(bytes)`를 호출한다.
- `RustBridge/src/lib.rs:151-163` render tree JSON은 `build_page_render_tree(page)` 결과의 root만 문자열화한다.
- `RustBridge/src/lib.rs:165-174` overlay compact JSON은 `get_page_overlay_images_native(page)` 결과를 그대로 반환한다.
- `RustBridge/src/lib.rs:215-225` Skia PNG export options에는 scale, max_dimension, `font_paths`만 있으며 document file context는 없다.
- `RustBridge/src/lib.rs:247-271` image data는 `bin_data_id == 0`을 invalid로 보고 `(bin_data_id - 1)` index로 `get_bin_data`를 조회한다.
- `rhwp-core.lock:3-8` 현재 core는 release tag `v0.7.17`, commit `03351190ec35436e58cbfee0aa9278a8fdc04a59`, feature `native-skia` 기준이다.

## Swift image data contract

### Render tree image node

`RenderTree.swift`의 `ImageNode`는 embedded BinData id와 render 속성을 담는다. Stage 1 기준으로 path, URI, external link target, missing reason, resource id 같은 필드는 없다.

근거:

- `Sources/RhwpCoreBridge/RenderTree.swift:303-328` `ImageNode`는 `bin_data_id`, section/para/control index, fill/effect/brightness/contrast/textWrap/transform/crop 등을 디코딩한다.
- `Sources/RhwpCoreBridge/RenderTree.swift:386-395` `PlaceholderNode`는 label과 색상만 있고 image missing diagnostic과 연결되는 필드는 없다.

### `RhwpDocument.imageData`

Swift wrapper는 `rhwp_image_data`가 반환한 pointer를 즉시 Swift `Data`로 복사한다. pointer ownership은 Rust `DocumentCore` 내부 lifetime에 의존하고 Swift가 free하지 않는다.

근거:

- `Sources/RhwpCoreBridge/RhwpDocument.swift:194-200` `imageData(binDataId:)`는 pointer와 길이를 받아 `Data(bytes:count:)`로 복사한다.
- `Sources/RhwpCoreBridge/RhwpDocument.swift:203-213` availability 확인도 같은 `rhwp_image_data` call 결과가 nil/0인지로만 판단한다.

### Overlay image path

Overlay compact JSON은 base64 image bytes를 직접 담을 수 있지만, compact payload에는 `binDataId`가 없다. Swift는 render tree를 순회해 layer+bbox로 supplement를 붙인다.

근거:

- `Sources/RhwpCoreBridge/PageOverlayImages.swift:81-94` overlay source는 `data`, `base64Length`, optional `binDataId`, optional `binDataAvailable`만 갖는다.
- `Sources/RhwpCoreBridge/PageOverlayImages.swift:166-183` compact JSON decode가 실패하거나 없으면 render tree supplement만으로 fallback image set을 만든다.
- `Sources/RhwpCoreBridge/PageOverlayImages.swift:245-257` compact payload model은 base64를 `Data`로 decode하며 `binDataId`는 nil로 둔다.
- `Sources/RhwpCoreBridge/PageOverlayImages.swift:316-340` supplement는 render tree `ImageNode.binDataId`와 `document.hasImageData`로 availability를 계산한다.
- `Sources/RhwpCoreBridge/PageOverlayImages.swift:352-369` compact overlay JSON에는 `binDataId`가 없어 bbox/layer 매칭으로 보강한다는 주석과 구현이 있다.

## Renderer missing data behavior

### 일반 ImageNode

CoreGraphics renderer는 `binDataId == 0`, document 없음, `rhwp_image_data` nil, image decode 실패를 모두 "그리지 않음"으로 처리한다. 사용자에게 보이는 placeholder 또는 diagnostic은 이 레이어에서 생성하지 않는다.

근거:

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:756-767` `renderImage`는 `doc.imageData` 또는 `decodeImage` 실패 시 즉시 return한다.
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:851-857` decode는 ImageIO 또는 PCX decode만 시도한다.

### Overlay image

Overlay compositor는 renderable overlay가 있으면 `renderOverlayImages`를 먼저 시도하고 draw count가 0이면 render tree page overlay layer로 fallback한다. 그러나 fallback layer의 image drawing도 결국 `renderImage`와 같은 `rhwp_image_data` 계약을 사용한다.

근거:

- `Sources/Shared/HwpNativePageCompositor.swift:55-84` renderable overlay가 없거나 draw count가 0이면 page overlay layer를 render tree로 다시 그린다.
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:828-849` overlay image decode는 inline data를 먼저 보고, 없으면 `binDataId`로 `document.imageData`를 조회한다.

### RawSvg

RawSvg는 external image ABI와 별개지만 #404 downstream 보정 후보와 연결된다. Swift renderer는 single image data URL만 decode하고 일반 SVG vector나 SVG image reference는 fallback 박스로 간다.

근거:

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:1519-1531` RawSvg 크기/limit 검사 또는 single image decode 실패 시 fallback을 그린다.
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:1539-1559` data URL이 `image/*`이면서 `image/svg+xml`이 아니고 base64인 경우만 image data로 decode한다.

## Sandbox and file access observations

- Quick Look과 Thumbnail extension entitlements는 app sandbox와 user-selected read-only만 선언한다.
- extension 코드에는 external sibling file lookup, security-scoped resource open/close, relative path resolver가 없다.
- HostApp은 user-selected file URL에 대해 security-scoped access를 시작하지만, 현재 source URL/base directory를 document payload나 RustBridge handle에 유지하지 않는다.
- Thumbnail cache key는 main file path/mtime/file size만 보므로 future external image context가 들어오면 external resource signature 또는 injected bytes signature가 cache key에 추가되어야 한다.

근거:

- `Sources/QLExtension/QLExtension.entitlements:5-8` Quick Look extension sandbox와 read-only file entitlement.
- `Sources/ThumbnailExtension/ThumbnailExtension.entitlements:5-8` Thumbnail extension sandbox와 read-only file entitlement.
- `Sources/HostApp/Stores/DocumentViewerStore.swift:50-64` HostApp open path는 security-scoped access 안에서 main file만 읽는다.
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift:29-36` thumbnail cache key에는 external resource 상태가 없다.

## Current limitations

1. Filename context 부재
   - Swift wrapper initializer는 `filename`을 받지만 FFI call에는 넣지 않는다.
   - RustBridge handle은 `DocumentCore`만 보관한다.
   - 따라서 core가 relative external resource를 열려면 필요한 base directory나 original filename을 알 수 없다.

2. External resource identity 부재
   - render tree `ImageNode`는 `bin_data_id`만 표현한다.
   - Swift model에는 external link target, package-relative path, URI, original BinData name, placeholder reason이 없다.

3. Missing image diagnostic 부재
   - `rhwp_image_data` nil은 invalid id, missing embedded data, unsupported external link, decode failure 이전 단계 등을 구분하지 않는다.
   - CoreGraphics renderer는 nil/decode failure를 생략 처리하므로 native PNG에서 조용한 누락이 생길 수 있다.

4. Bytes injection 부재
   - Swift shell이 sibling file이나 security-scoped file을 읽더라도 RustBridge handle에 주입할 API가 없다.
   - injection이 생기면 `imageCache` key와 document lifetime, cache invalidation도 같이 설계해야 한다.

5. Surface별 권한 경계 부재
   - Quick Look/Thumbnail은 Finder가 준 request URL 중심이고 HostApp은 security-scoped URL을 다룬다.
   - current bridge ABI가 URL을 받지 않으므로 surface별 권한 차이를 표현할 channel도 없다.

## Stage 2 확인 질문

- pinned `rhwp v0.7.17`에 `DocumentCore::from_path`, document context, external resource resolver, BinData link metadata 접근 API가 있는가?
- upstream issue `edwardkim/rhwp#1141`과 PR `#1913`, `#1924`, `#1917`, `#1930`은 external image를 render tree, SVG, Skia PNG, overlay JSON 중 어디에 표현하는가?
- upstream이 missing external image를 `PlaceholderNode`로 내보내는가, 아니면 `ImageNode.bin_data_id`만 유지하고 byte data를 비워 두는가?
- `get_page_overlay_images_native`의 compact JSON에 external/missing 상태를 추가할 계획이 있는가, 아니면 render tree supplement가 계속 필요할까?
- Skia PNG export는 external resource bytes를 core 내부에서 해결해야 하는가, 아니면 downstream이 injected bytes를 준비해야 하는가?
- downstream ABI는 filename/base URL만 넘겨도 되는가, 아니면 external refs enumeration + explicit bytes injection이 필요한가?

## Stage 1 판정

현재 downstream ABI만으로는 filename/external image context를 자동 반영할 수 없다. upstream parser가 embedded BinData bytes와 기존 `bin_data_id`/JSON shape를 더 잘 채우는 변경은 자동 반영될 수 있지만, external link를 보존하거나 missing placeholder/diagnostic을 내보내는 변경은 Swift model, C ABI, renderer fallback 정책 중 적어도 하나의 downstream 보강이 필요하다.

Stage 2에서는 pinned release와 upstream external image 관련 이슈/PR을 조사해 "core update만으로 해결되는 embedded/placeholder 개선"과 "downstream context ABI가 필요한 external resource 해결"을 분리한다.
