# Task M020 #391 Stage 2 보고서

단계: Stage 2 `upstream rhwp/studio external resource contract 조사`

## 요약

- 현재 pinned core는 `rhwp v0.7.17` / commit `03351190ec35436e58cbfee0aa9278a8fdc04a59` / feature `native-skia` 기준이다.
- upstream `#1141` 체인은 filename context, external image reference discovery, external image bytes injection을 이미 merged 상태로 제공한다.
- bundled `rhwp-studio` WASM wrapper도 `setFileName`, `getExternalImageReferences`, `getExternalImageBasenames`, `injectExternalImage`, `injectExternalImageByKey`를 노출한다.
- pinned source의 native `wasm_api::HwpDocument`에는 위 API가 있지만, 알한글 RustBridge handle은 현재 `DocumentCore`를 직접 보관하므로 C ABI에서는 해당 contract를 사용할 수 없다.
- upstream render tree `ImageNode`에는 `external_path`가 있고 SVG/WebCanvas/CanvasKit/Skia 계열은 missing external image placeholder 또는 diagnostic을 표현한다. Swift `ImageNode` 모델과 CoreGraphics renderer는 Stage 1 기준으로 이 정보를 받지 못한다.
- 최근 PR `#1913`, `#1924`, `#1927`, `#1930`, `#2040`은 BinData 보존, 대형 embedded image, placeholder 구조, storage id 정합을 개선한다. embedded bytes가 기존 `bin_data_id`로 채워지는 경우는 core pin update만으로 좋아질 수 있지만, external link bytes 해결과 native placeholder/diagnostic은 downstream C ABI와 Swift renderer 보강이 필요하다.

## 조사 기준

| 항목 | 확인 결과 |
|------|-----------|
| downstream pin | `rhwp-core.lock` 기준 `release-tag v0.7.17`, commit `03351190ec35436e58cbfee0aa9278a8fdc04a59`, `native-skia` |
| Cargo dependency | `RustBridge/Cargo.toml`은 `rhwp` tag `v0.7.17`와 `native-skia` feature를 사용 |
| bundled studio | `Sources/HostApp/Resources/rhwp-studio/`의 WASM JS binding에 external image/filename API 존재 |
| upstream 확인일 | 2026-07-10, GitHub CLI로 개별 issue/PR 상태 재확인 |
| 범위 | 조사/설계 문서화만 수행. RustBridge ABI 구현, framework 재생성, core pin 변경은 제외 |

## Upstream contract 체인

| 항목 | 상태 | #391 의미 |
|------|------|-----------|
| `edwardkim/rhwp#1141` | CLOSED | filename context, external image reference discovery, bytes injection/resource resolver 책임 경계를 묶은 parent issue다. 파일 접근 정책은 consumer 책임, core는 명시 전달된 상태만 반영한다는 방향이다. |
| PR `#1174` | MERGED, 2026-05-30 | `DocumentCore.file_name -> LayoutEngine.set_file_name -> PageRenderTree/PageLayerTree` 경로를 정리하고 filename 변경 시 render tree cache를 무효화한다. |
| PR `#1175` | MERGED, 2026-05-30 | `getExternalImageReferences()` contract를 추가한다. key, binDataId, originalPath, basename, extension, loaded 상태를 JSON으로 노출한다. |
| PR `#1185` | MERGED, 2026-05-31 | `injectExternalImageByKey(key,data,displayPath)`와 legacy basename injection을 추가한다. injection 후 cache를 무효화하고 CanvasKit diagnostic에서 external missing/injected 상태를 구분한다. |

### 책임 경계

upstream contract의 핵심은 renderer backend가 임의로 filesystem을 탐색하지 않는다는 점이다.

- consumer: 파일 선택, 권한, path policy, bytes 준비
- core: discovery key와 BinData id 기준으로 document state 갱신
- renderer backend: document state를 replay하고 missing/injected 상태를 표현

알한글 macOS에 그대로 적용하면 Quick Look/Thumbnail/HostApp shell이 external resource 후보를 읽고, RustBridge C ABI는 발견 목록과 bytes injection만 받아야 한다. renderer가 sibling path를 직접 열거나 sandbox 밖 파일을 추정해서 읽는 구조는 Stage 3 설계 기본안에서 제외한다.

## Pinned `v0.7.17` source 관찰

### `wasm_api::HwpDocument`

pinned source checkout에서 `src/wasm_api.rs`는 native build에서도 `HwpDocument::from_bytes(data)`를 제공하고 `DocumentCore`로 `Deref/DerefMut`된다. 즉 RustBridge가 handle 내부 타입을 `wasm_api::HwpDocument`로 바꾸면 기존 page/render API를 유지하면서 upstream external API를 감쌀 가능성이 있다.

확인된 public surface:

- `ExternalImageReference` JSON field: `key`, `binDataId`, `originalPath`, `basename`, `extension`, `loaded`
- `get_external_image_references() -> String`
- `get_external_image_basenames() -> String`
- `inject_external_image(basename,data,display_path) -> u32`
- `inject_external_image_by_key(key,data,display_path) -> u32`
- `set_file_name(name)`

`injectExternalImageByKey`의 key는 `binData:N` 형태를 지원하고, invalid key, 존재하지 않는 reference, 이미 loaded 상태인 reference는 실패로 취급된다. injection 성공 시 document의 BinData content가 채워지고 display path가 diagnostic/debug용으로 갱신된다.

### `DocumentCore`

현재 알한글 RustBridge가 직접 보관하는 `DocumentCore`에는 Stage 2 기준 다음 차이가 있다.

- public `populate_external_images_from_dir(base_dir)`는 존재한다.
- filename setter와 structured external reference JSON API는 public `DocumentCore` surface로 보이지 않는다.
- `Document::inject_external_image_data`는 model 내부 helper이고 RustBridge crate가 직접 호출할 수 있는 public API가 아니다.

따라서 Stage 3 설계안은 세 갈래를 비교해야 한다.

1. RustBridge handle을 `DocumentCore`에서 `wasm_api::HwpDocument`로 바꾸고 public wrapper API를 감싼다.
2. `DocumentCore::populate_external_images_from_dir`만 C ABI로 노출한다.
3. upstream에 public `DocumentCore` filename/external refs/injection API를 요청하거나 반영한 뒤 RustBridge handle 구조를 유지한다.

2번은 core가 directory를 직접 읽는 형태라 macOS sandbox 책임 경계와 충돌하기 쉽다. Stage 3의 기본 후보는 1번 또는 3번을 중심으로 잡는 것이 맞다.

## Bundled `rhwp-studio` 관찰

`Sources/HostApp/Resources/rhwp-studio/rhwp_bg.wasm.d.ts`와 `rhwp.js`는 다음 binding을 이미 노출한다.

- `hwpdocument_setFileName`
- `hwpdocument_getExternalImageBasenames`
- `hwpdocument_getExternalImageReferences`
- `hwpdocument_injectExternalImage`
- `hwpdocument_injectExternalImageByKey`

`rhwp.js`의 high-level method도 같은 이름으로 제공된다. 즉 HostApp WKWebView 기반 MVP는 upstream studio 쪽 API를 쓸 준비가 되어 있지만, native Quick Look/Thumbnail의 Swift CoreGraphics path는 RustBridge C ABI에 같은 symbol이 없어서 동일 contract에 접근하지 못한다.

## Render tree와 missing image 표현

pinned `v0.7.17` source의 render tree `ImageNode`에는 `external_path: Option<String>`이 있다. upstream 주석은 `data`가 없고 `external_path`가 있으면 placeholder 표시가 가능하다는 방향을 명시한다.

backend별 관찰:

- SVG renderer는 image data가 없고 external path가 있으면 placeholder rect와 external path label을 그리는 경로가 있다.
- WebCanvas renderer도 external path가 있는 missing image를 dashed placeholder로 표현한다.
- CanvasKit policy는 `externalImage;missingImageData`와 `externalImage;injectedImageData` diagnostic을 구분한다.
- Skia renderer 계열은 invalid/missing image placeholder를 그리는 테스트와 경로가 있다.

downstream Swift는 Stage 1 기준으로 다음 정보가 빠져 있다.

- `RenderTree.ImageNode`에 `externalPath` field 없음
- `rhwp_render_page_tree` JSON decode 후 external missing 상태를 Swift model에 보존하지 않음
- `CGTreeRenderer.renderImage`는 image byte nil/decode failure를 조용히 return 처리
- `PlaceholderNode`는 차트/OLE 같은 별도 placeholder label용이며 image missing diagnostic과 연결되어 있지 않음

따라서 upstream core가 render tree에 `external_path`를 이미 내보내더라도 Swift JSON model이 해당 field를 보존하지 않으면 native Quick Look/Thumbnail에는 자동 반영되지 않는다.

## 최근 external/large image 관련 PR

| 항목 | 상태 | 영향 범주 | #391 판정 |
|------|------|-----------|-----------|
| PR `#1913` | MERGED, 2026-07-05 | HWPX external BinData Link 왕복 보존 | external link 구조가 core에 더 잘 남는다. 하지만 bytes가 비어 있으면 native renderer는 C ABI discovery/injection 없이는 해결할 수 없다. |
| issue `#1917` | CLOSED | HWPX 64MB BinData load 거부와 pic control 소실 | large embedded image가 core에서 더 잘 열리면 기존 `bin_data_id` path로 자동 개선될 수 있다. |
| PR `#1924` | MERGED, 2026-07-05 | HWPX BinData limit 64MB -> 512MB | embedded large image load 개선이다. downstream에는 memory/thumbnail cache policy 검토가 남지만 external ABI 자체는 아니다. |
| PR `#1927` | MERGED, 2026-07-05 | BinData load 실패 placeholder pic 보존 | 구조 보존은 core update 효과다. 시각적 placeholder를 Swift에서 표시하려면 render tree field/diagnostic을 받아야 한다. |
| PR `#1930` | MERGED, 2026-07-05 | HWP5 그림 `imgDim` 원본 크기 roundtrip 보존 | original image dimension metadata 보존 성격이다. external resource C ABI와 직접 연결되지는 않는다. |
| PR `#2040` | MERGED, 2026-07-08 | BinData storage id를 위치와 분리해 max+1 채번 | `ImageAttr.bin_data_id`는 여전히 위치 기반 1-based 의미를 유지한다. C ABI는 storage id와 render lookup id를 혼동하지 않도록 `binDataId`를 upstream JSON 의미 그대로 다뤄야 한다. |

`#2040` 본문은 `inject_external_image_data`의 위치 기반 id 재작성은 범위 외라고 명시한다. 따라서 external injection ABI 설계에서는 `binDataId`를 "렌더 lookup용 1-based 위치 id"로 보고, 저장소 stream id 또는 `BinData.storage_id`와 섞지 않는 원칙이 필요하다.

## Stage 1 질문에 대한 답

### `DocumentCore::from_path` 또는 document context API가 있는가?

Stage 2 기준으로 알한글이 쓰는 `DocumentCore` public surface에는 filename setter, structured external refs, explicit bytes injection API가 충분히 노출되어 있지 않다. native directory population API는 있으나, 이는 core가 filesystem을 직접 읽는 형태라 macOS shell 책임 경계와 맞지 않는다.

### upstream은 external image를 어디에 표현하는가?

external reference discovery는 WASM/native wrapper API에서 JSON으로 노출된다. render tree `ImageNode`에도 `external_path`가 남을 수 있고, backend별 placeholder/diagnostic 경로가 존재한다. 다만 알한글 Swift model이 `external_path`를 디코딩하지 않으므로 현재 native CoreGraphics path에서는 이 정보가 소실된다.

### missing external image는 `PlaceholderNode`인가, `ImageNode`인가?

upstream render tree 관찰상 image 자체는 `ImageNode`에 남고 `data == None`, `external_path == Some` 조합으로 placeholder 표시가 가능하다. Swift의 `PlaceholderNode`와는 별개로 취급해야 한다.

### overlay compact JSON도 external/missing 상태를 갖는가?

Stage 2에서 확인한 downstream current path는 overlay compact JSON이 base64 image data 중심이고 `binDataId`도 Swift supplement로 보강한다. upstream external reference contract는 render tree와 document-level API 쪽에 더 명확하게 존재한다. 따라서 Stage 3 설계는 overlay JSON 확장보다 document-level refs/injection과 render tree `externalPath` 보존을 우선한다.

### Skia PNG export는 core 내부에서 external bytes를 해결해야 하는가?

upstream contract의 바람직한 경계는 consumer가 bytes를 준비하고 core에 주입한 뒤 renderer가 그 상태를 replay하는 것이다. Skia PNG export가 좋아지려면 Swift/macOS shell이 injection을 먼저 수행하거나, 제한된 directory population을 명시 정책으로 호출해야 한다.

### downstream ABI는 filename/base URL만 넘기면 되는가?

filename context만으로는 부족하다. filename은 field rendering과 일부 context에는 필요하지만, external image 해결에는 reference discovery와 explicit bytes injection이 필요하다. base URL/direct directory population은 sandbox와 cache signature를 흐리게 하므로 기본 ABI로 삼기 어렵다.

## Stage 3 설계 입력

Stage 3에서 최소로 다뤄야 할 state:

- `embedded`: 기존 `rhwp_image_data`로 bytes 존재
- `externalMissing`: external reference는 있으나 bytes 없음
- `externalInjected`: external reference가 injection으로 loaded
- `placeholderPreserved`: bytes load 실패 또는 roundtrip 보존용 placeholder 구조 존재
- `decodeFailed`: bytes는 있으나 Swift/CoreGraphics decode 실패
- `invalidBinDataId`: render tree id 또는 caller id가 유효하지 않음

Stage 3에서 비교할 ABI 후보:

- `rhwp_set_file_name(handle, utf8_name)`
- `rhwp_external_image_refs(handle) -> JSON`
- `rhwp_inject_external_image_by_key(handle, key, bytes, display_path) -> status`
- `rhwp_image_state(handle, bin_data_id) -> enum 또는 JSON`
- `rhwp_render_page_tree` JSON model에 `externalPath` additive decode
- `rhwp_open_with_context(data, len, filename, optional_display_path)` 또는 open 후 setter 방식

memory/lifetime 원칙:

- C ABI는 caller-provided bytes를 즉시 Rust-owned `Vec<u8>`로 복사한다.
- Rust가 반환하는 JSON string은 기존 `rhwp_free_string` lifecycle을 따른다.
- external refs key는 stable string으로 Swift cache key에 들어갈 수 있어야 한다.
- cache invalidation은 injection 성공, filename setter 변경, image state 변경 시 명시적으로 발생해야 한다.

## Stage 2 판정

upstream `rhwp`는 external resource contract 자체를 이미 상당히 갖고 있다. 문제는 downstream 알한글 native path가 그 contract를 C ABI로 받지 못하고, Swift render tree model도 `external_path`와 missing/injected diagnostic을 보존하지 않는다는 점이다.

따라서 #391의 실제 downstream 적용 작업은 core pin update만으로 끝나지 않는다. embedded large image와 일부 parser/roundtrip 보존은 upstream 발전을 따라 자동 개선될 수 있지만, Quick Look/Thumbnail의 external image 정합성은 다음 downstream 작업이 필요하다.

1. RustBridge C ABI에서 filename setter 또는 open context, external refs enumeration, bytes injection을 additive symbol로 노출한다.
2. Swift `RhwpDocument`가 external refs를 조회하고 shell이 허용한 bytes를 주입할 수 있게 한다.
3. Swift `ImageNode`가 upstream `external_path`를 보존하고 CoreGraphics renderer가 missing external image를 생략 대신 placeholder/diagnostic으로 처리할지 정책화한다.
4. Thumbnail cache signature에 injected resource 상태 또는 resolver signature를 반영한다.
5. storage id와 render `binDataId`를 혼동하지 않도록 ABI 문서와 테스트 fixture를 분리한다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `gh issue view 1141 --repo edwardkim/rhwp --json number,title,state,url` | 통과: CLOSED 확인 |
| `gh pr view 1174/1175/1185 --repo edwardkim/rhwp --json number,title,state,mergedAt,url` | 통과: 모두 MERGED 확인 |
| `gh pr view 1913/1924/1927/1930/2040 --repo edwardkim/rhwp --json number,title,state,mergedAt,url` | 통과: 모두 MERGED 확인 |
| `gh pr list --repo edwardkim/rhwp --search "external image"` | 통과: `#1175`, `#1185`, `#1913`, `#2040` 등 관련 PR 확인 |
| `rg -n "ExternalImageReference|get_external_image_references|get_external_image_basenames|inject_external_image|set_file_name|populate_external_images_from_dir" ...` | 통과: pinned source의 wrapper/API 위치 확인 |
| `rg -n "external_path|placeholder|missingImageData|injectedImageData" ...` | 통과: render tree/backend diagnostic 위치 확인 |

## 다음 단계 영향

Stage 3에서는 제품 코드를 수정하지 않고 external image C ABI 후보를 설계한다. 특히 `wasm_api::HwpDocument` handle 전환안과 `DocumentCore` public API 확장안을 비교하고, Swift wrapper가 사용할 JSON/status shape를 정한다.

## 승인 요청

Stage 2 결과에 따라 Stage 3 `external image C ABI 후보 설계`로 진행해도 되는지 승인 요청한다.
