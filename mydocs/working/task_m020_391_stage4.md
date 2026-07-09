# Task M020 #391 Stage 4 보고서

단계: Stage 4 `macOS external resource 책임 경계 설계`

## 요약

- Quick Look Preview, Finder Thumbnail, HostApp native export는 모두 Swift/macOS shell이 source URL 권한과 external resource bytes를 판정하고, RustBridge에는 명시적으로 filename context와 bytes만 전달하는 구조로 설계한다.
- RustBridge/core가 directory를 직접 읽는 `populate_external_images_from_dir` 방식은 제품 기본 경로에서 제외한다.
- external path의 `originalPath`는 신뢰할 수 있는 접근 경로가 아니라 reference metadata다. resolver는 basename과 source document 위치를 기준으로 제한된 후보만 만든다.
- Quick Look/Thumbnail extension은 read-only sandbox 환경이므로 sibling file lookup도 conservative opt-in으로 두고, 실패 시 missing placeholder/diagnostic으로 degrade해야 한다.
- Thumbnail은 external resource 상태가 cache key에 들어가야 한다. 현재 key는 main file path/mtime/size/render signature뿐이므로 resolver 적용 전 cache 구조 조정이 필요하다.
- HostApp은 security-scoped bookmark를 이미 갖지만 `RhwpStudioDocumentPayload`에는 URL이 없다. future native viewer/export resolver는 source URL 또는 resolved bookmark를 별도 context로 전달해야 한다.

## Current surface inventory

| Surface | current input | current retention | Stage 4 의미 |
|---------|---------------|-------------------|--------------|
| Quick Look Preview | `QLFilePreviewRequest.fileURL` | `HwpPreviewDocumentContext`에 `RhwpDocument`, filename, page info만 유지 | request URL은 load 시점에만 쓰인다. resolver도 load 직후 실행해야 한다. |
| Finder Thumbnail | `QLFileThumbnailRequest.fileURL`, maximum size, scale | `HwpThumbnailCacheKey`에 path/mtime/size/pixel bucket/render signature | external resource signature가 cache key에 없다. |
| HostApp WKWebView | user-selected URL 또는 dropped bytes | `RhwpStudioDocumentPayload(data, filename, revision)` | source URL/base directory가 payload에 없다. dropped bytes는 external lookup 불가로 취급해야 한다. |
| HostApp native PDF export | payload data + filename | 새 `RhwpDocument`를 열어 PDF render | source URL context가 없어 external injection 불가. |

근거:

- `Sources/QLExtension/HwpPreviewProvider.swift:12-19` Preview request URL을 받아 `HwpPreviewPDFRenderer.load(fileURL:)`로 위임한다.
- `Sources/Shared/HwpPreviewPDFRenderer.swift:173-181` Preview load는 main file bytes와 basename으로 `RhwpDocument`를 연다.
- `Sources/ThumbnailExtension/HwpThumbnailProvider.swift:12-21` Thumbnail request URL로 render request를 만든다.
- `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift:19-35` Thumbnail cache key는 main file mtime/size와 renderer signature만 포함한다.
- `Sources/Shared/HwpPageImageRenderer.swift:128-141` Thumbnail render path도 main file bytes와 basename만 `RhwpDocument`에 넘긴다.
- `Sources/HostApp/Stores/DocumentViewerStore.swift:50-63` HostApp은 security-scoped access 안에서 main file을 읽지만 payload에는 data/filename만 전달한다.
- `Sources/HostApp/Services/RhwpStudioDocumentPayload.swift:3-6` payload model은 `data`, `filename`, `revision`만 갖는다.
- `Sources/HostApp/Services/RhwpStudioPDFExportController.swift:49-50` native PDF export는 payload data와 filename으로 새 `RhwpDocument`를 연다.

## Entitlement and permission boundary

| Surface | entitlement | resolver policy |
|---------|-------------|-----------------|
| Quick Look Preview | app sandbox + user-selected read-only | main file와 같은 directory의 basename match 후보만 허용한다. 권한 실패는 missing으로 degrade한다. |
| Finder Thumbnail | app sandbox + user-selected read-only | Preview와 같은 read-only policy를 쓰되, cache signature를 먼저 해결해야 한다. |
| HostApp open/export | app sandbox + user-selected read-write + security-scoped bookmark | source URL을 가진 문서에 한해 security scope를 열고 resolver를 실행한다. dropped bytes는 resolver disabled다. |
| WKWebView bundled studio | custom `alhangeul-studio`/`alhangeul-document` scheme | 현재는 bundled asset과 document bytes만 제공한다. external file serving은 별도 host bridge/permission 설계 없이는 추가하지 않는다. |

근거:

- `Sources/QLExtension/QLExtension.entitlements:5-8`, `Sources/ThumbnailExtension/ThumbnailExtension.entitlements:5-8`는 sandbox + user-selected read-only다.
- `Sources/HostApp/HostApp.entitlements:5-16`은 sandbox, user-selected read-write, network client, print entitlement를 갖는다.
- `Sources/HostApp/Services/RecentDocumentStore.swift:21-41`는 security-scoped bookmark를 저장/복원한다.
- `Sources/HostApp/Services/RhwpStudioDocumentSchemeHandler.swift:88-113`는 WKWebView에 current document bytes만 response로 보낸다.
- `Sources/HostApp/Services/RhwpStudioResourceSchemeHandler.swift:73-93`는 bundled `rhwp-studio` resource만 resolve한다.

## Shared resolver model

Stage 3 ABI 후보를 전제로 Swift layer에는 다음 shared model을 둔다.

```swift
struct RhwpDocumentOpenContext {
    let filename: String
    let sourceURL: URL?
    let surface: RhwpDocumentSurface
    let externalResourcePolicy: RhwpExternalResourcePolicy
}

enum RhwpDocumentSurface {
    case quickLookPreview
    case finderThumbnail
    case hostAppViewer
    case hostAppPDFExport
    case droppedDocument
}

struct RhwpExternalResourceResolution {
    let reference: RhwpExternalImageReference
    let decision: RhwpExternalResourceDecision
    let displayPath: String?
    let data: Data?
    let cacheComponent: RhwpExternalResourceCacheComponent?
}
```

resolver 실행 순서:

1. main file bytes를 읽는다.
2. `RhwpDocument(data:filename:)`를 열고 filename context를 설정한다.
3. `rhwp_external_image_refs_json`으로 external references를 얻는다.
4. Swift resolver가 surface policy에 따라 candidate file을 찾고 bytes를 읽는다.
5. 허용된 bytes만 `rhwp_inject_external_image_by_key`로 주입한다.
6. resolution report와 cache signature를 render diagnostics에 보관한다.
7. page count/page size/render tree를 조회한다.

`pageCount`와 `pageSize`는 injection 이후에 조회하는 것을 기본으로 둔다. 대부분 그림 geometry는 control property에 들어 있지만, external bytes가 layout/image metadata에 영향을 줄 가능성을 배제하지 않는 편이 안전하다.

## Path resolution policy

external reference의 `originalPath`는 다음 용도로만 쓴다.

- basename 추출
- extension 참고
- privacy-safe diagnostic 표시

access path로 직접 사용하지 않는다.

v1 후보 resolution:

1. `sourceURL`이 없으면 resolver disabled.
2. `sourceURL.isFileURL == false`면 resolver disabled.
3. `reference.basename` 또는 `originalPath`에서 basename을 추출한다.
4. basename이 비어 있거나 `.`, `..`, path separator를 포함하면 policy reject.
5. candidate URL은 `sourceURL.deletingLastPathComponent().appendingPathComponent(basename)` 하나만 만든다.
6. standardized/resolved path가 source parent 밖으로 나가면 reject.
7. candidate가 directory면 reject.
8. file size가 policy cap을 넘으면 reject.
9. read 성공 시 bytes를 injection한다.

명시 금지:

- `originalPath`가 absolute path여도 그대로 열지 않는다.
- Windows drive path, UNC/network path를 열지 않는다.
- `http`, `https`, `file://` string을 `originalPath`에서 파싱해 접근하지 않는다.
- symlink traversal로 source parent 밖 파일을 읽지 않는다.
- renderer 또는 RustBridge가 filesystem을 직접 읽지 않는다.

extension은 allow-list 보조 신호로만 쓴다. Swift CoreGraphics는 ImageIO + PCX decode를 쓰지만, injection 자체는 renderer backend가 해석할 수 있는 bytes를 core state에 넣는 일이다. 따라서 v1에서는 upstream reference extension과 file size/read success를 우선하고, decode failure는 Swift renderer diagnostic으로 분리한다.

## Surface-specific design

### Quick Look Preview

Preview는 `HwpPreviewPDFRenderer.load(fileURL:)`에서 document를 한 번 열고 단일 PNG 또는 PDF reply를 만든다. 따라서 external resolver 삽입 지점은 `loadDocument(fileURL:)` 안의 `RhwpDocument` 생성 직후가 적절하다.

후속 API 후보:

```swift
let context = RhwpDocumentOpenContext(
    filename: fileURL.lastPathComponent,
    sourceURL: fileURL,
    surface: .quickLookPreview,
    externalResourcePolicy: .quickLookReadOnly
)
let document = try RhwpDocument(data: data, context: context)
```

정책:

- main file size gate는 현행 유지.
- external image read는 read-only sibling basename 후보만 시도.
- resolver 실패는 preview failure가 아니라 missing placeholder/diagnostic으로 남긴다.
- full original path는 Quick Look title/log/placeholder에 노출하지 않는다.
- multi-page PDF는 같은 opened document와 injected state를 모든 page에 재사용한다.

### Finder Thumbnail

Thumbnail은 cache lookup 전에 key가 필요하므로 가장 주의가 필요하다. 현재 `HwpThumbnailRenderRequest`는 file URL resource values만으로 key를 만든 뒤 cache hit를 판단한다. external resource를 반영하려면 다음 중 하나를 선택해야 한다.

| 후보 | 설명 | 판단 |
|------|------|------|
| Prepared request | worker에서 document open + refs enumeration + resolver signature 산출 후 full cache key로 lookup | 권장. 정확하지만 cache flow refactor가 필요하다. |
| External refs cache bypass | external refs가 있는 문서는 memory cache를 쓰지 않고 매번 render | 안전한 v1 fallback. 성능 손해가 있다. |
| Directory mtime broad key | source parent directory mtime를 key에 넣는다 | 부정확하다. sibling file 변경을 놓칠 수 있어 기본안에서 제외한다. |
| Main file key 유지 | current key 유지 | external file 변경 시 stale thumbnail이 생겨 제외한다. |

권장 구조:

1. `HwpThumbnailRenderRequest`는 current preflight key가 아니라 source file/pixel/policy만 담는 lightweight request로 둔다.
2. worker queue에서 document를 열고 external refs를 조회한다.
3. resolver가 `RhwpExternalResourceCacheSignature`를 만든다.
4. `HwpThumbnailCacheKey`에 external signature를 포함해 cache lookup/store를 수행한다.

cache signature 후보:

```swift
struct RhwpExternalResourceCacheSignature: Hashable {
    let policyVersion: String
    let components: [RhwpExternalResourceCacheComponent]
}

struct RhwpExternalResourceCacheComponent: Hashable {
    let key: String
    let decision: String
    let basename: String
    let fileSize: Int?
    let modificationTime: TimeInterval?
}
```

주입을 위해 bytes를 이미 읽었다면 후속 구현에서 byte hash를 포함할 수 있다. 다만 hashing cost가 large image와 충돌할 수 있으므로 v1은 file size + mtime + decision을 기본 후보로 둔다.

### HostApp WKWebView

bundled `rhwp-studio`는 upstream WASM API를 갖지만 macOS host가 external file bytes를 제공하는 bridge는 없다. 현재 WKWebView document scheme은 current document bytes만 서빙하고, resource scheme은 bundled `rhwp-studio` asset만 서빙한다.

Stage 4 판단:

- WKWebView MVP path는 이번 #391 downstream native ABI 적용의 직접 대상에서 제외한다.
- external image injection을 WKWebView에도 맞추려면 JS host bridge가 external refs를 읽고 native host에 resource request를 보낸 뒤 bytes를 WASM에 inject하는 별도 이슈가 필요하다.
- HostApp native PDF export는 Swift/RustBridge path이므로 #391 ABI 적용 대상이다.

### HostApp native viewer/export

HostApp은 opened URL에 대해 security-scoped access를 시작하고 recent document bookmark도 저장한다. 그러나 current payload에는 source URL이 없다.

후속 설계:

- `RhwpStudioDocumentPayload`에 source URL을 직접 넣기보다, native render/export 호출에 `RhwpDocumentOpenContext`를 별도로 전달한다.
- opened document는 `sourceDocument.resolvedURL()` 또는 current open URL을 통해 security scope를 render/export 작업 동안 연다.
- dropped document는 `sourceURL == nil`이므로 external resolver disabled.
- save-as 이후 `recordSavedDocument(at:)`가 source document를 갱신하므로 이후 export/viewer resolver는 새 URL 기준으로 동작한다.

## Swift renderer placeholder policy

Stage 3에서 `ImageNode.externalPath` additive decode를 후보로 잡았다. Stage 4에서는 missing external image 시각 정책을 다음처럼 둔다.

| 상황 | Swift CoreGraphics 동작 후보 |
|------|-----------------------------|
| `binDataId > 0`, bytes 있음, decode 성공 | 현재처럼 이미지 렌더 |
| bytes 있음, decode 실패 | 이미지 bbox에 decode failure placeholder 또는 diagnostic count. render 전체 실패로 올리지 않음 |
| bytes 없음, `externalPath != nil` | external missing placeholder를 그림 |
| bytes 없음, `externalPath == nil` | 기존 embedded missing. placeholder 여부는 debug policy와 함께 결정 |

Quick Look/Thumbnail은 path privacy가 중요하므로 placeholder label은 full path가 아니라 `image` 또는 basename 정도로 제한한다. `originalPath` 전체는 user-facing preview에 표시하지 않는다.

Skia PNG path는 injection된 document state를 core가 replay하므로 Swift placeholder와 별개다. 단, Skia missing placeholder와 Swift missing placeholder가 visual diff에서 크게 갈라지지 않도록 #396 visual suite에 external fixture를 넣어야 한다.

## Diagnostics and logging

필요한 diagnostic shape:

```swift
struct RhwpExternalResourceReport {
    let referenceCount: Int
    let injectedCount: Int
    let missingCount: Int
    let rejectedCount: Int
    let decisions: [RhwpExternalResourceResolution]
}
```

logging 원칙:

- public log에는 filename, counts, decision kind만 남긴다.
- full resolved path는 privacy private 또는 debug artifact에만 남긴다.
- permission denied, file missing, too large, invalid basename, policy rejected를 구분한다.
- external resolver 실패는 render fallback reason과 분리한다. renderer backend fallback과 resource missing은 다른 축이다.

`HwpPageRenderDiagnostics`에는 external resource counts 또는 optional report summary를 추가하는 후보를 둔다. 전체 per-resource report는 Thumbnail cache key와 debug smoke 산출물에만 사용하고, user-facing log에는 축약한다.

## #390/#404 연결

| 이슈 | Stage 4 반영 |
|------|--------------|
| #390 | Skia default는 보류다. external resolver는 CoreGraphics default와 Skia opt-in 모두 같은 injected document state를 쓰도록 설계한다. |
| #404 | external/large image exact fixture가 미측정이다. ABI 구현 전후 검증에 external BinData Link, large BinData, placeholder fixture가 필요하다. |
| #396 | external fixture를 visual suite에 포함해야 Skia/SVG/CoreGraphics missing/injected placeholder 차이를 추적할 수 있다. |
| #392/#389 | Thumbnail cache signature와 diagnostic logging 변경은 external resolver 적용 시 같이 확장되어야 한다. |

## Downstream-only and upstream-dependent work

downstream-only 가능:

- Swift `RhwpDocumentOpenContext`와 resolver policy model 설계/구현
- Quick Look/Thumbnail/HostApp native render entry point에 context 전달
- Swift `ImageNode.externalPath` additive decode
- CoreGraphics missing external placeholder
- Thumbnail cache key external signature 확장
- resolver diagnostic/reporting

upstream/core 또는 ABI 선행 필요:

- `rhwp_set_file_name_utf8`
- `rhwp_external_image_refs_json`
- `rhwp_inject_external_image_by_key`
- `rhwp_image_state_json`
- generated header, `rhwp-ffi-symbols.txt`, `rhwp-core.lock` artifact metadata 갱신
- exact external/large fixture로 injected/missing state 검증

## Rollout order

1. RustBridge additive ABI 구현 spike
2. Swift wrapper에 filename setter, refs, injection API 추가
3. shared resolver model과 Quick Look Preview 적용
4. CoreGraphics `externalPath` decode와 missing placeholder 적용
5. Thumbnail prepared request 또는 cache bypass 선택 후 cache signature 반영
6. HostApp native export에 context 전달
7. WKWebView external image host bridge 별도 검토
8. #396 visual suite에 external/large image fixture 추가

Quick Look Preview를 Thumbnail보다 먼저 적용하는 이유는 cache 구조 변경이 없고, opened document context 하나에 injection state를 유지하기 쉽기 때문이다. Thumbnail은 cache correctness가 제품 품질에 직접 영향을 주므로 별도 단계로 분리한다.

## Stage 4 판정

#391의 macOS 책임 경계는 다음으로 고정한다.

1. Swift/macOS shell이 source URL 권한, path policy, bytes read, cache signature를 소유한다.
2. RustBridge는 filename context, external refs enumeration, explicit bytes injection만 수행한다.
3. renderer backend는 document state를 replay하고 missing/injected 상태를 표현한다.
4. external path는 access path가 아니라 metadata다.
5. Thumbnail은 external resource signature 없이는 resolver를 켜지 않는다.
6. dropped bytes 문서는 external resolver disabled가 기본이다.

이 설계는 Stage 3 후보 A와 정합된다. Stage 5에서는 실제 후속 구현 이슈를 `RustBridge ABI`, `Swift wrapper/resolver`, `Thumbnail cache`, `fixture/visual suite`, `WKWebView bridge` 단위로 나누는 것이 적절하다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `rg -n "providePreview|load(fileURL|Data(contentsOf|RhwpDocument(data|renderPage" ...` | 통과: Preview/Shared render entry point 확인 |
| `rg -n "provideThumbnail|HwpThumbnailRenderRequest|HwpThumbnailCacheKey|renderSignature" ...` | 통과: Thumbnail cache key current shape 확인 |
| `rg -n "startAccessingSecurityScopedResource|bookmarkData|RhwpStudioDocumentPayload" ...` | 통과: HostApp security scope, bookmark, payload 확인 |
| `rg -n "app-sandbox|user-selected|network.client|print" ...entitlements` | 통과: surface별 entitlement 확인 |
| `rg -n "Skia|Quick Look|Thumbnail|external|#391" mydocs/working/task_m020_390_stage4.md mydocs/working/task_m020_404_stage4.md` | 통과: #390/#404 연결 근거 확인 |

## 다음 단계 영향

Stage 5에서는 #391 최종 보고서와 후속 이슈 초안을 작성한다. 후속 구현을 바로 시작하려면 최소 `RustBridge additive ABI`, `Swift resolver + Quick Look`, `Thumbnail cache signature`, `external fixture suite`를 분리해 등록하는 편이 안전하다.

## 승인 요청

Stage 4 결과에 따라 Stage 5 `후속 이슈 초안과 최종 보고서`로 진행해도 되는지 승인 요청한다.
