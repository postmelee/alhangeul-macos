# Task M020 #391 Stage 3 보고서

단계: Stage 3 `external image C ABI 후보 설계`

## 요약

- 기존 `rhwp_open`, `rhwp_image_data`, `rhwp_render_page_tree` 계약은 유지하고 external image context는 additive C symbol로 확장하는 방향이 맞다.
- 우선 후보는 `RhwpHandle` 내부 타입을 `DocumentCore`에서 `rhwp::wasm_api::HwpDocument`로 전환하고, upstream `setFileName`, `getExternalImageReferences`, `injectExternalImageByKey`를 RustBridge C ABI로 감싸는 방식이다.
- `rhwp_open_with_context`는 보조 후보로 둘 수 있지만, filename만 open 시점에 넣어도 external image bytes 해결은 되지 않는다. open-time context 단독 설계는 불충분하다.
- `populate_external_images_from_dir`를 C ABI로 노출하는 방식은 구현은 작지만 core가 filesystem을 직접 읽게 되어 Quick Look/Thumbnail sandbox 책임 경계와 맞지 않는다. 제품 기본 경로 후보에서 제외한다.
- Swift/CoreGraphics의 `decodeFailed`는 RustBridge가 알 수 없는 상태다. RustBridge는 embedded/external/missing/injected를 보고하고, Swift renderer가 decode 실패를 별도 diagnostic으로 보강해야 한다.

## Current ABI constraints

현재 RustBridge의 C ABI는 다음 패턴을 갖는다.

| 패턴 | current symbol | 설계 영향 |
|------|----------------|-----------|
| opaque handle | `struct RhwpHandle *rhwp_open(...)` | handle 내부 Rust 타입 변경은 C ABI에 드러나지 않는다. |
| borrowed document bytes | `const uint8_t *rhwp_image_data(..., out_len)` | 반환 pointer는 handle lifetime에 묶이고 Swift는 즉시 `Data`로 복사한다. |
| owned bytes 반환 | `rhwp_extract_thumbnail`, `rhwp_render_page_png` + `rhwp_free_bytes` | Rust가 새 buffer를 할당해 caller가 free한다. |
| owned string 반환 | `rhwp_render_page_tree`, `rhwp_page_overlay_images` + `rhwp_free_string` | JSON 반환은 기존 string lifecycle을 재사용할 수 있다. |
| status enum | `RhwpRenderStatus` | injection처럼 실패 원인 구분이 필요한 API는 enum이 적합하다. |
| symbol snapshot | `rhwp-ffi-symbols.txt` | symbol 추가 시 generated header, symbol snapshot, lock metadata 검증이 필요하다. |

현재 ABI에는 input string symbol이 없다. filename, key, display path 같은 새 문자열 입력은 null-terminated C string보다 UTF-8 pointer+length 형태가 낫다. path나 document string 자체에 NUL이 들어갈 수는 없지만, pointer+length가 Swift `Data`/`String.UTF8View`와 Rust `std::str::from_utf8` 검증을 명확히 분리한다.

## 후보 A: `HwpDocument` handle 전환 + additive symbols

### 개요

`RhwpHandle` 내부를 다음처럼 바꾸는 후보이다.

```rust
pub struct RhwpHandle {
    doc: rhwp::wasm_api::HwpDocument,
}
```

pinned `v0.7.17`에서 `rhwp::wasm_api`는 public module이고 `HwpDocument::from_bytes`가 native CLI에서도 사용된다. `HwpDocument`는 `DocumentCore`로 `Deref/DerefMut`되므로 기존 page count, render tree, SVG, PNG export 호출은 대부분 같은 형태로 유지할 가능성이 높다.

### C ABI 후보

```c
typedef enum RhwpExternalImageStatus {
  RHWP_EXTERNAL_OK = 0,
  RHWP_EXTERNAL_INVALID_HANDLE = 1,
  RHWP_EXTERNAL_INVALID_INPUT = 2,
  RHWP_EXTERNAL_INVALID_UTF8 = 3,
  RHWP_EXTERNAL_NOT_FOUND = 4,
  RHWP_EXTERNAL_ALREADY_LOADED = 5,
  RHWP_EXTERNAL_FAILURE = 6,
} RhwpExternalImageStatus;

RhwpExternalImageStatus rhwp_set_file_name_utf8(
  struct RhwpHandle *handle,
  const uint8_t *name,
  uintptr_t name_len
);

char *rhwp_external_image_refs_json(
  const struct RhwpHandle *handle
);

RhwpExternalImageStatus rhwp_inject_external_image_by_key(
  struct RhwpHandle *handle,
  const uint8_t *key,
  uintptr_t key_len,
  const uint8_t *data,
  uintptr_t data_len,
  const uint8_t *display_path,
  uintptr_t display_path_len
);

char *rhwp_image_state_json(
  const struct RhwpHandle *handle,
  uint16_t bin_data_id
);
```

### JSON shape

`rhwp_external_image_refs_json`은 upstream WASM shape를 그대로 따른다.

```json
[
  {
    "key": "binData:3",
    "binDataId": 3,
    "originalPath": "C:\\sample\\linked.png",
    "basename": "linked.png",
    "extension": "png",
    "loaded": false
  }
]
```

`rhwp_image_state_json`은 Swift renderer diagnostic과 cache key 생성을 위한 보조 API다. 최소 shape는 다음을 후보로 둔다.

```json
{
  "binDataId": 3,
  "key": "binData:3",
  "source": "external",
  "state": "externalMissing",
  "loaded": false,
  "byteLength": 0,
  "externalPath": "C:\\sample\\linked.png"
}
```

상태 후보:

| state | 의미 | 산출 layer |
|-------|------|------------|
| `embeddedAvailable` | external ref가 아니고 bytes가 있다 | RustBridge |
| `embeddedMissing` | external ref가 아니지만 bytes가 없다 | RustBridge |
| `externalMissing` | external ref는 있으나 bytes가 없다 | RustBridge |
| `externalInjected` | external ref가 있고 bytes가 주입되어 있다 | RustBridge |
| `invalidBinDataId` | `bin_data_id == 0` 또는 lookup 불가 | RustBridge |
| `decodeFailed` | bytes는 있으나 CoreGraphics decode 실패 | Swift renderer |
| `placeholderPreserved` | core가 구조 보존용 placeholder를 유지 | RustBridge가 알 수 있으면 JSON, 아니면 render tree/Swift 정책 |

`decodeFailed`는 Rust가 판단하지 않는다. Swift `CGTreeRenderer.decodeImage`가 실패했을 때 overlay diagnostic 또는 debug counter에 붙이는 상태로 둔다.

### 장점

- upstream `#1141/#1175/#1185` contract와 가장 직접적으로 정렬된다.
- 기존 `rhwp_open` symbol과 Swift call site를 유지하면서 handle 내부 구현만 바꿀 수 있다.
- `rhwp_external_image_refs_json`은 기존 JSON string 반환/free 패턴을 재사용한다.
- injection 성공 시 upstream `HwpDocument`가 page tree cache invalidation을 수행한다.
- `setFileName`은 filename field rendering과 cache invalidation을 upstream 방식으로 맞춘다.

### 리스크

- `HwpDocument`가 RustBridge staticlib build에서 필요한 feature 조합으로 컴파일되는지 실제 구현 단계에서 확인해야 한다.
- `HwpDocument` public API 일부가 `wasm_bindgen` 중심이라 native C ABI wrapper에서 borrow/mutability 문제가 생길 수 있다.
- handle 내부 타입 변경 후 기존 `DocumentCore` method 호출이 모두 `Deref`로 통과하는지 build 검증이 필요하다.
- `rhwp_image_data`는 현재 `DocumentCore::get_bin_data(index)`의 0-based index 조회를 쓴다. `HwpDocument` 전환 후에도 동일 lookup 의미를 유지해야 한다.

### 판정

1순위 후보로 둔다. 구현 follow-up에서는 가장 먼저 이 전환안으로 compile spike를 수행하고, 실패하면 후보 D로 upstream `DocumentCore` public API 확장을 요청한다.

## 후보 B: open-time context API 추가

### 개요

`rhwp_open_with_context`를 추가해 parse 직후 filename을 설정하는 방식이다.

```c
struct RhwpHandle *rhwp_open_with_context(
  const uint8_t *data,
  uintptr_t len,
  const uint8_t *file_name,
  uintptr_t file_name_len
);
```

### 장점

- Swift `RhwpDocument(data:filename:)`가 이미 filename 인자를 받으므로 call site 의미가 직관적이다.
- filename field가 첫 render tree build 전에 설정된다.
- 기존 `rhwp_open`은 유지하고 새 initializer만 추가하면 ABI breaking이 없다.

### 한계

- external image reference discovery와 bytes injection은 별도 symbol이 여전히 필요하다.
- filename만으로는 base directory, sibling resource, sandbox permission, package-relative lookup을 해결할 수 없다.
- open 시점 context를 늘리기 시작하면 이후 base path, security token, resolver option을 계속 붙이고 싶어지는 압력이 생긴다.

### 판정

단독안으로는 부족하다. 후보 A의 `rhwp_set_file_name_utf8`를 먼저 구현하고, filename이 반드시 첫 layout 전에 필요하다는 fixture가 나오면 `rhwp_open_with_context`를 보조 API로 추가한다.

## 후보 C: directory population API 노출

### 개요

upstream `DocumentCore::populate_external_images_from_dir(base_dir)`를 C ABI로 노출하는 방식이다.

```c
uint32_t rhwp_populate_external_images_from_dir(
  struct RhwpHandle *handle,
  const uint8_t *base_dir,
  uintptr_t base_dir_len
);
```

### 장점

- Rust 구현량이 작다.
- upstream native CLI와 비슷한 동작을 만들 수 있다.
- external path basename만 필요한 단순 HWP3 sample에는 빠르게 효과가 날 수 있다.

### 문제

- core/RustBridge가 filesystem을 직접 읽는다.
- Quick Look/Thumbnail sandbox, security-scoped URL, network path 금지, symlink traversal 정책을 RustBridge 내부로 끌어들인다.
- 어떤 external file을 읽었는지 Swift thumbnail cache signature에 반영하기 어렵다.
- 실패 원인이 permission인지 missing file인지 policy reject인지 Swift가 정밀하게 알기 어렵다.

### 판정

제품 기본 경로로 채택하지 않는다. 내부 CLI/debug smoke 전용으로는 검토할 수 있지만 Quick Look/Thumbnail의 downstream contract에는 맞지 않는다.

## 후보 D: upstream `DocumentCore` public API 확장

### 개요

RustBridge handle을 `DocumentCore`로 유지하고 upstream에 다음 public API를 추가하거나 반영한 뒤 C ABI를 감싸는 방식이다.

- `DocumentCore::set_file_name`
- `DocumentCore::external_image_references_json`
- `DocumentCore::inject_external_image_by_key`
- `DocumentCore::image_state`

### 장점

- RustBridge 내부 타입을 바꾸지 않는다.
- domain API가 `wasm_api` wrapper가 아니라 core layer에 자리 잡는다.
- WASM/native/CLI 모두 같은 implementation을 공유하기 쉽다.

### 한계

- upstream PR 또는 core pin update가 선행되어야 한다.
- #391 이후 바로 downstream 구현을 착수하기 어렵다.
- 이미 `HwpDocument` wrapper에 구현된 contract와 중복될 수 있다.

### 판정

후보 A가 compile 또는 API 안정성 문제로 막히면 선택한다. 장기적으로는 upstream에 core-level public API를 두는 편이 더 깨끗하지만, downstream Quick Look/Thumbnail 보정의 첫 구현 경로는 후보 A가 더 빠르다.

## 선택 기준

| 기준 | 후보 A | 후보 B | 후보 C | 후보 D |
|------|--------|--------|--------|--------|
| 기존 ABI compatibility | 좋음 | 좋음 | 좋음 | 좋음 |
| external refs/injection 완성도 | 좋음 | 낮음 | 중간 | 좋음 |
| sandbox 책임 경계 | 좋음 | 중간 | 낮음 | 좋음 |
| 구현 착수 가능성 | 높음 | 높음 | 높음 | 낮음 |
| upstream contract 정합 | 높음 | 일부 | 일부 | 높음 |
| cache invalidation 명확성 | 높음 | 낮음 | 중간 | 높음 |

Stage 3 권고는 후보 A를 우선 구현 후보로 삼고, 후보 B는 filename-first fixture가 필요할 때 보조로 추가, 후보 C는 제품 기본 경로에서 제외, 후보 D는 upstream 정리 또는 후보 A 실패 시 대체 경로로 둔다.

## Swift wrapper mapping

후속 구현에서 Swift wrapper는 다음 API를 후보로 둔다.

```swift
struct RhwpExternalImageReference: Decodable, Hashable {
    let key: String
    let binDataId: UInt16
    let originalPath: String
    let basename: String
    let extension: String
    let loaded: Bool
}

enum RhwpExternalImageStatus: Equatable {
    case ok
    case invalidHandle
    case invalidInput
    case invalidUTF8
    case notFound
    case alreadyLoaded
    case failure
}

extension RhwpDocument {
    func setFileNameContext(_ name: String) -> RhwpExternalImageStatus
    func externalImageReferences() -> [RhwpExternalImageReference]
    func injectExternalImage(key: String, data: Data, displayPath: String) -> RhwpExternalImageStatus
    func imageState(binDataId: UInt16) -> RhwpImageState?
}
```

`RhwpDocument(data:filename:)`는 open 성공 직후 `setFileNameContext`를 호출하도록 바꿀 수 있다. 이 변경은 parse failure error message와 별개로 document rendering context를 core에 전달한다.

`RenderTree.ImageNode`에는 다음 field를 additive decode한다.

```swift
let externalPath: String?
```

`externalPath` decode는 기존 JSON에 field가 없어도 nil이므로 backward compatible하다. Swift `CGTreeRenderer.renderImage`는 image bytes가 없고 `externalPath != nil`이면 생략 대신 placeholder 정책을 적용할 수 있다. placeholder 실제 디자인과 surface별 노출 여부는 Stage 4에서 결정한다.

## Memory ownership

- `rhwp_external_image_refs_json`과 `rhwp_image_state_json`은 Rust-owned C string을 반환하고 caller가 `rhwp_free_string`으로 해제한다.
- `rhwp_inject_external_image_by_key`의 `data` pointer는 호출 중에만 유효하다. RustBridge는 성공 여부와 무관하게 caller buffer를 보관하지 않고, 성공 시 Rust-owned `Vec<u8>`로 복사한다.
- `display_path`는 diagnostic용 문자열이다. core가 이 값을 외부 파일 접근에 사용하지 않는다는 전제를 문서화해야 한다.
- `rhwp_image_data`의 borrowed pointer는 handle 내부 storage에 묶인다. injection 같은 mutation 후에는 과거 pointer를 재사용하면 안 된다. Swift current wrapper는 즉시 `Data`로 복사하므로 이 원칙과 맞는다.
- `RhwpDocument` handle은 thread-safe로 선언하지 않는다. 같은 handle에서 render와 injection을 동시에 호출하지 않는 것을 Swift wrapper contract로 둔다.

## Error reporting

`rhwp_inject_external_image_by_key`는 upstream WASM이 `u32` count를 반환하지만, C ABI에서는 다음 원인 구분이 필요하다.

| status | 사용 조건 |
|--------|-----------|
| `RHWP_EXTERNAL_OK` | injection 또는 setter 성공 |
| `RHWP_EXTERNAL_INVALID_HANDLE` | handle null |
| `RHWP_EXTERNAL_INVALID_INPUT` | key/data/name pointer와 length 조합이 부적절 |
| `RHWP_EXTERNAL_INVALID_UTF8` | key/name/display path가 UTF-8이 아님 |
| `RHWP_EXTERNAL_NOT_FOUND` | key에 해당하는 external reference 없음 |
| `RHWP_EXTERNAL_ALREADY_LOADED` | reference는 있으나 이미 bytes가 있음 |
| `RHWP_EXTERNAL_FAILURE` | panic, serialization 실패, upstream helper false 등 기타 실패 |

다만 upstream `inject_external_image_by_key` public method가 현재 `0/1`만 반환하므로 `NOT_FOUND`와 `ALREADY_LOADED`를 정확히 구분하려면 RustBridge가 injection 전에 refs JSON 또는 helper logic으로 reference 상태를 조회해야 한다. 이 구분이 구현을 과하게 만들면 v1은 `OK/INVALID/FAILURE` 중심으로 시작하고 `rhwp_image_state_json`으로 상세 원인을 보완하는 단계화를 허용한다.

## `binDataId` naming rule

Stage 2에서 확인한 `#2040`과 upstream `find_bin_data` 규칙 때문에 다음 원칙을 고정한다.

- C ABI와 Swift model의 `binDataId`는 render lookup id다.
- 기본 해석은 1-based `bin_data_content` 위치다.
- upstream renderer는 위치 lookup 실패 시 storage id fallback을 쓸 수 있지만, downstream ABI는 storage id를 직접 의미하지 않는다.
- external refs key `binData:N`의 `N`도 render lookup id로 취급한다.
- 후속 테스트 fixture는 sparse storage id, storage id collision, external injected image를 분리해서 잡는다.

## Rollout proposal

후속 구현은 한 PR에 모두 넣지 않고 다음 단위로 나누는 것이 좋다.

1. RustBridge additive ABI spike
   - `RhwpHandle` 내부 `HwpDocument` 전환 compile 검증
   - `rhwp_set_file_name_utf8`
   - `rhwp_external_image_refs_json`
   - `rhwp_inject_external_image_by_key`
   - `rhwp-ffi-symbols.txt`, generated header, lock metadata 갱신

2. Swift wrapper와 JSON model
   - `RhwpExternalImageReference`, `RhwpExternalImageStatus`, `RhwpImageState`
   - `RhwpDocument(data:filename:)`의 filename context setter 호출
   - external refs/injection unit tests 또는 smoke harness

3. Render tree external path 보존
   - `ImageNode.externalPath`
   - missing external image placeholder/fallback policy
   - CoreGraphics decode failure diagnostic

4. macOS shell resolver
   - Quick Look/Thumbnail/HostApp별 file access policy
   - allowed sibling/package-relative resource lookup
   - thumbnail cache signature에 external resource 상태 반영

5. Fixture and regression
   - exact external BinData Link sample
   - large BinData sample
   - storage id sparse/collision sample
   - native CG vs Skia/SVG missing/injected image comparison

## Stage 3 판정

downstream 적용은 "filename만 넘기기"로는 부족하다. 최소 구현 단위는 filename setter, external refs JSON, key 기반 bytes injection, image state diagnostic, Swift `externalPath` decode의 조합이다.

제품 경로의 기본 선택은 후보 A다. 이 안은 upstream contract를 재사용하고, macOS shell이 bytes와 권한 정책을 소유하며, RustBridge는 명시적으로 전달된 context만 document state에 반영한다. 후보 C처럼 RustBridge가 directory를 직접 읽는 방식은 sandbox와 cache 설계를 흐리므로 기본안에서 제외한다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `sed -n '1,340p' RustBridge/src/lib.rs` | 통과: current handle, string/bytes free, render status 패턴 확인 |
| `sed -n '1,280p' Sources/RhwpCoreBridge/RhwpDocument.swift` | 통과: Swift wrapper ownership과 filename 미전달 확인 |
| `sed -n '1,120p' rhwp-ffi-symbols.txt` | 통과: external context symbol 없음 확인 |
| `sed -n '1,220p' Frameworks/generated_rhwp.h` | 통과: generated C surface current shape 확인 |
| `rg -n "pub mod wasm_api|HwpDocument::from_bytes" ...` | 통과: pinned core의 public `wasm_api`와 native usage 확인 |
| `sed -n '2588,2714p' .../src/wasm_api.rs` | 통과: upstream refs/injection API shape 확인 |
| `sed -n '250,330p' .../src/model/document.rs` | 통과: external loaded/injection helper와 position-first lookup 확인 |

## 다음 단계 영향

Stage 4에서는 이 ABI 후보를 전제로 Swift/macOS shell 책임을 설계한다. 특히 Quick Look/Thumbnail이 어떤 external file을 읽을 수 있는지, resolver가 어떤 path를 거부해야 하는지, injected resource signature를 thumbnail cache에 어떻게 반영할지 결정해야 한다.

## 승인 요청

Stage 3 결과에 따라 Stage 4 `macOS external resource 책임 경계 설계`로 진행해도 되는지 승인 요청한다.
