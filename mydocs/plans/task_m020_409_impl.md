# Task M020 #409 구현계획서

수행계획서: `mydocs/plans/task_m020_409.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서와 해당 단계 변경을 함께 커밋하고, 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #409 `Swift external image wrapper/resolver와 Quick Look Preview 적용`
- Parent: #407 `external image context ABI 후속 구현 추적`
- 선행 조사: #391 `filename/external image context ABI 조사 및 bridge 설계`
- 선행 구현: #408 `RustBridge external image context C ABI 구현`
- 관련 측정: #404 `upstream 렌더 PR 대표 샘플 diff 측정`
- 후속 경계:
  - #410 CoreGraphics external missing/decode diagnostic
  - #411 Thumbnail external resource cache signature
  - #412 external/large image 정식 fixture suite
  - #413 HostApp WKWebView external image bridge
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task409`
- 목표: pinned `rhwp v0.7.18`의 external image context C ABI를 Swift wrapper로 노출하고, Quick Look Preview에서 안전한 basename-only sibling resolver를 page count/size/render 전에 실행한다.

## 구현 전 확인 결론

현재 코드와 pinned upstream checkout을 대조한 결론이다.

| 항목 | 현재 상태 | 구현 판단 |
|------|-----------|-----------|
| core provenance | `rhwp v0.7.18`, commit `93862a4e16df59834ebce46d91e948cd739208e9`, `native-skia` | core pin과 generated artifact를 변경하지 않는다. |
| C status | raw value 0~6의 `RhwpExternalImageStatus` | Swift 별도 enum으로 모두 보존하고 unknown raw value도 버리지 않는다. |
| filename setter | `rhwp_set_file_name_utf8(handle,name,len)` | Quick Look open helper가 explicit 호출한다. |
| refs query | `rhwp_external_image_refs_json(handle)` | Swift가 반환 C string을 즉시 복사하고 `rhwp_free_string`으로 해제한다. |
| key injection | `rhwp_inject_external_image_by_key(handle,key,data,display_path)` | resolver가 허용한 bytes와 basename display path만 전달한다. |
| refs JSON | `key`, `binDataId`, `originalPath`, `basename`, `extension`, `loaded` | `extension`은 Swift `fileExtension`에 매핑하고 unknown additive field는 무시한다. |
| current Swift open | `RhwpDocument(data:filename:)`가 `rhwp_open`만 호출 | 기존 initializer 동작은 유지하고 Quick Look 전용 Shared loader가 setter/query/injection을 조정한다. |
| current Preview load | document open 직후 page count와 첫 page size 조회 | external resolution이 끝난 document를 받은 뒤에만 page metadata를 조회하도록 순서를 바꾼다. |
| single/multi reply | 같은 `HwpPreviewDocumentContext.document`로 PNG 또는 PDF 생성 | resolved document 재사용 구조를 유지한다. |
| Thumbnail path | `HwpPageImageRenderer.renderFirstPage(fileURL:)`가 별도 open | #411 전 resolver를 연결하지 않는다. |
| bytes-only path | `render(previewInfo:)`, HostApp PDF export가 source URL 없이 open | filename/error context만 유지하고 sibling resolver는 비활성화한다. |
| Quick Look entitlement | app sandbox + user-selected read-only | entitlement를 변경하지 않고 실제 registered Preview smoke로 sibling 접근 가능 여부를 검증한다. |
| exact external fixture | pinned checkout에 `hwp3-sample10-{hwp5,hwpx}`와 `oracle.gif`, `rdb02.gif`, `s1.jpg` 존재 | MIT checkout fixture를 `build.noindex/`에 복사해 smoke에만 쓰고 저장소에는 편입하지 않는다. |

pinned checkout의 확인 경로는 `/Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/93862a4`다. 이 경로의 HEAD는 lock과 같은 `93862a4e16df59834ebce46d91e948cd739208e9`이며 repository license는 MIT다. fixture의 정식 저장소 편입과 장기 provenance는 #412가 소유한다.

## 구현 원칙

- `Sources/RhwpCoreBridge`에는 model과 FFI wrapper만 추가한다. AppKit/UIKit, URL resolution, `FileManager`, file read 정책을 넣지 않는다.
- 기존 `RhwpDocument(data:filename:)`의 제품 동작을 암묵적으로 확장하지 않는다. Quick Look만 `Sources/Shared`의 명시적 external-resource open helper를 호출한다.
- `RhwpDocument.handle`은 계속 `private`로 유지한다. FFI wrapper method는 같은 `RhwpDocument.swift` 안에 구현하고 handle을 다른 파일에 노출하지 않는다.
- Swift string은 UTF-8 bytes와 명시 길이로 전달하고, empty display path는 nil pointer/0 length로 전달한다.
- refs JSON C string은 `defer { rhwp_free_string(...) }`로 모든 decode 결과에서 해제한다.
- `rhwp_image_data` 결과는 기존처럼 즉시 `Data`로 복사한다. setter/injection 같은 mutable 호출을 넘겨 pointer를 보관하지 않는다.
- resolver는 `reference.basename`만 사용한다. `originalPath`는 decode 보존만 하고 filesystem 접근, report, log에 사용하지 않는다.
- source parent의 한 단계 sibling regular file만 허용한다. recursion, absolute/original path, URL/network, Windows drive/UNC 해석을 금지한다.
- source URL 없음/non-file URL은 disabled 상태다. 이 경우 refs query와 injection을 실행하지 않는다.
- 이미 loaded인 reference는 file lookup 없이 `alreadyLoaded`로 기록한다.
- reference 한 건의 missing/rejected/read/bridge failure는 다음 reference 처리를 막지 않고 main Preview render 실패로 승격하지 않는다.
- main document read/open, page count/size, PNG/PDF render의 기존 오류 계약은 유지한다.
- provider log는 report state와 count만 기록한다. external basename, original path, resolved candidate, absolute path는 기록하지 않는다.
- `project.yml`만 Xcode project 원본으로 수정하고 `Alhangeul.xcodeproj`는 생성·검증 후 commit하지 않는다.
- RustBridge, core lock, generated framework, entitlement, Thumbnail cache, HostApp WKWebView를 변경해야 하는 상황이 확인되면 현재 단계에서 멈추고 범위 확장 승인을 요청한다.

## Swift FFI wrapper 확정안

### Status model

Swift model 이름은 imported C enum과의 혼동을 피하기 위해 `RhwpExternalImageOperationStatus`로 고정한다.

```swift
enum RhwpExternalImageOperationStatus: Equatable {
    case ok
    case invalidHandle
    case invalidInput
    case invalidUTF8
    case referenceNotFound
    case alreadyLoaded
    case failure
    case unknown(UInt32)
}
```

| raw value | Swift case |
|-----------|------------|
| 0 | `.ok` |
| 1 | `.invalidHandle` |
| 2 | `.invalidInput` |
| 3 | `.invalidUTF8` |
| 4 | `.referenceNotFound` |
| 5 | `.alreadyLoaded` |
| 6 | `.failure` |
| 그 외 | `.unknown(rawValue)` |

initializer 입력 타입은 module qualification을 사용해 `Rhwp.RhwpExternalImageStatus`로 명시한다.

### Reference model

```swift
struct RhwpExternalImageReference: Decodable, Equatable {
    let key: String
    let binDataId: UInt16
    let originalPath: String
    let basename: String
    let fileExtension: String
    let loaded: Bool
}
```

- `CodingKeys.fileExtension = "extension"`으로 매핑한다.
- `JSONDecoder` 기본 동작으로 unknown additive field를 무시한다.
- 필수 field 누락, 타입 불일치, `UInt16` 범위 초과는 decode failure다.
- `originalPath`는 upstream 계약 보존과 test 검증에만 사용하며 resolver/report/log에 전달하지 않는다.

### Bridge error와 method

```swift
enum RhwpExternalImageBridgeError: Error, Equatable {
    case referencesUnavailable
    case invalidReferencesJSON
}

extension RhwpDocument {
    @discardableResult
    func setFileName(_ filename: String) -> RhwpExternalImageOperationStatus

    func externalImageReferences() throws -> [RhwpExternalImageReference]

    @discardableResult
    func injectExternalImage(
        key: String,
        data: Data,
        displayPath: String? = nil
    ) -> RhwpExternalImageOperationStatus
}
```

- `setFileName`은 empty String도 valid setter 요청으로 전달한다.
- refs pointer가 nil이면 `.referencesUnavailable`, JSON decode 실패면 `.invalidReferencesJSON`을 던진다.
- `injectExternalImage`는 key/data/display path의 nested buffer lifetime을 FFI 호출 범위 안에 고정한다.
- resolver는 `displayPath`에 absolute candidate path가 아니라 허용된 `basename`만 전달한다.

## Open context, resolver와 report 확정안

### Open context

```swift
struct RhwpDocumentOpenContext: Equatable {
    let sourceURL: URL?
    let displayFilename: String?
    let maximumExternalResourceBytes: Int
}
```

- Quick Look은 `sourceURL = request.fileURL`, `displayFilename = request.fileURL.lastPathComponent`, `maximumExternalResourceBytes = hwpQuickLookMaxFileSize`를 사용한다.
- 상한은 external resource 한 건당 적용한다. 기본값은 기존 Quick Look main document 상한과 같은 50 MB다.
- bytes-only caller는 이 context를 만들지 않고 기존 initializer를 사용하므로 resolver가 자동 활성화되지 않는다.

### Report state와 decision

```swift
enum RhwpExternalResourceReportState: Equatable {
    case disabledNoSourceURL
    case disabledNonFileURL
    case attempted
    case referenceQueryFailed
}

enum RhwpExternalResourceDecision: Equatable {
    case alreadyLoaded
    case injected(byteCount: Int)
    case missing
    case rejectedInvalidBasename
    case rejectedOutsideSourceDirectory
    case rejectedSourceDocument
    case rejectedNonRegularFile
    case tooLarge(actualBytes: Int?, limit: Int)
    case permissionDenied
    case readFailed
    case bridgeRejected(RhwpExternalImageOperationStatus)
    case verificationFailed
}

struct RhwpExternalResourceResolution: Equatable {
    let key: String
    let decision: RhwpExternalResourceDecision
}

struct RhwpExternalResourceReport: Equatable {
    let state: RhwpExternalResourceReportState
    let filenameStatus: RhwpExternalImageOperationStatus?
    let resolutions: [RhwpExternalResourceResolution]
}
```

- resolution에는 safe discovery key와 decision만 둔다.
- basename, original path, candidate URL/path는 report에 저장하지 않는다.
- report는 injected, alreadyLoaded, missing, rejected, tooLarge, permissionDenied, readFailed, bridgeFailed count를 computed summary로 제공한다.
- initial refs query 실패는 `referenceQueryFailed`이며 main render는 계속한다.
- injection `.ok`은 refs 재조회에서 같은 key의 `loaded == true`가 확인된 경우에만 최종 `.injected`다.
- injection과 refs 재조회 사이의 race 또는 query failure는 `.verificationFailed`다.
- injection 시점에 `.alreadyLoaded`가 반환되면 경쟁 상태를 허용해 `.alreadyLoaded`로 확정한다.

### Resolver algorithm

`Sources/Shared/HwpExternalImageResolver.swift`에 다음 역할을 둔다.

1. main bytes로 `RhwpDocument`를 연다.
2. display filename이 있으면 `setFileName`을 호출하고 status를 report에 보존한다.
3. source URL이 nil이면 `disabledNoSourceURL`, file URL이 아니면 `disabledNonFileURL`로 즉시 반환한다.
4. refs를 query한다. 실패하면 `referenceQueryFailed` report와 document를 반환한다.
5. loaded ref는 `alreadyLoaded`로 기록한다.
6. unloaded ref의 `basename`을 검증한다.
   - empty, `.`, `..`
   - `/`, `\`, NUL 포함
7. source parent와 candidate를 standardized file URL로 계산한다.
8. candidate가 source document 자신이면 reject한다.
9. source parent와 candidate의 symlink-resolved parent가 정확히 같지 않으면 outside/symlink escape로 reject한다.
10. resource metadata를 읽어 missing, permission denied, non-regular file, size cap을 구분한다.
11. 허용된 candidate를 `.mappedIfSafe`로 읽고 실제 `Data.count`를 다시 size cap과 비교한다.
12. key/data/basename display path로 injection한다.
13. 모든 ref 처리 후 refs를 한 번 재조회해 `.ok` injection의 loaded 상태를 검증한다.
14. 완료된 document와 report를 `RhwpDocumentOpenResult`로 반환한다.
15. caller는 open result를 받은 뒤에만 page count/page size/render를 호출한다.

resolver test에서 permission/read failure를 결정적으로 재현할 수 있도록 production `Data(contentsOf:)`를 감싼 internal data-loader dependency를 주입 가능하게 한다. path metadata와 containment 정책은 실제 임시 디렉터리로 검증하고, 오류 분류만 test closure로 주입한다.

## Preview 소비 경로 확정

| caller | source URL | external resolver | 이유 |
|--------|------------|-------------------|------|
| `HwpPreviewPDFRenderer.load(fileURL:)` | 있음 | 활성 | Quick Look Preview 제품 경로 |
| `HwpPreviewPDFRenderer.render(fileURL:)` | 있음 | `load`를 통해 활성 | 같은 Preview convenience 경로 |
| single-page `HwpPreviewPNGRenderer.render(context:)` | resolved context 재사용 | 추가 실행 없음 | 한 handle에서 injection 후 PNG |
| multi-page `HwpPreviewPDFRenderer.render(context:)` | resolved context 재사용 | 추가 실행 없음 | 한 handle에서 injection 후 모든 page |
| `HwpPreviewPDFRenderer.inspect(fileURL:)` | 입력 URL은 있으나 반환 시 document 폐기 | 비활성 | 뒤의 bytes-only render가 source context를 보존하지 않음 |
| `HwpPreviewPDFRenderer.render(previewInfo:)` | 없음 | 비활성 | bytes-only diagnostic path |
| `HwpPageImageRenderer.renderFirstPage(fileURL:)` | 있음 | 비활성 | Thumbnail cache signature가 #411 전 미완료 |
| `RhwpStudioPDFExportController` | 없음 | 비활성 | HostApp WKWebView/export는 #413 경계 |
| 기타 script의 `RhwpDocument(data:filename:)` | 없음 | 비활성 | 기존 diagnostic/render 계약 유지 |

`HwpPreviewDocumentContext`에는 `externalResourceReport`를 추가한다. QLExtension은 load 직후 다음 항목만 log한다.

- report state identifier
- total reference resolution count
- injected/alreadyLoaded/missing/rejected/tooLarge
- permissionDenied/readFailed/bridgeFailed

external path나 basename은 log field에 넣지 않는다.

## Stage 1. Swift external image model과 FFI wrapper

### 목표

#408 C ABI를 Swift에서 수명 규칙을 지키며 호출하고, status/JSON 계약을 unit test로 고정한다.

### 대상

- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `Tests/ExternalImageTests/RhwpDocumentExternalImageBridgeTests.swift`
- `Tests/ExternalImageTests/ExternalImageTestSupport.swift`
- `project.yml`
- `mydocs/working/task_m020_409_stage1.md`
- `mydocs/orders/20260724.md`

### 작업

1. `RhwpExternalImageOperationStatus`, `RhwpExternalImageReference`, `RhwpExternalImageBridgeError`를 `RhwpDocument.swift`에 추가한다.
2. imported C enum의 raw value 0~6과 unknown mapping을 구현한다.
3. UTF-8 bytes/pointer/length를 FFI call 범위에 고정하는 private helper를 구현한다.
4. `setFileName`, `externalImageReferences`, `injectExternalImage`를 구현한다.
5. refs C string을 Swift `Data`로 복사한 뒤 `defer`로 해제하고 `JSONDecoder`로 decode한다.
6. `project.yml`에 standalone `ExternalImageTests` unit test target을 추가한다.
   - `RhwpDocument.swift`
   - `RenderTree.swift`
   - `Tests/ExternalImageTests`
   - `Rhwp.xcframework`와 기존 Rust staticlib link dependency
7. test에서 status raw mapping, unknown, 정상/additive/invalid JSON decode를 확인한다.
8. repository `KTX.hwp`로 filename `.ok`, refs `[]`, unknown key injection `.referenceNotFound`를 확인한다.
9. refs query를 반복 호출해 copy/free 경로가 안정적으로 동작하는지 확인한다.
10. 기존 initializer와 render/image method signature는 변경하지 않는다.

### 검증

```bash
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ExternalImageTests \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Stage1 \
  CODE_SIGNING_ALLOWED=NO \
  test
rg -n "RhwpExternalImageOperationStatus|RhwpExternalImageReference|setFileName|externalImageReferences|injectExternalImage|rhwp_free_string" \
  Sources/RhwpCoreBridge/RhwpDocument.swift Tests/ExternalImageTests
git diff --check
```

### 완료 조건

- status 0~6과 unknown mapping이 test로 고정되어 있다.
- refs JSON additive field와 invalid shape가 구분된다.
- C string이 모든 반환 경로에서 해제된다.
- key/data/display path buffer lifetime이 FFI call 안에 제한된다.
- `ExternalImageTests`가 통과하고 `RhwpCoreBridge` no-AppKit 경계를 유지한다.
- 기존 initializer가 resolver를 자동 실행하지 않는다.

### 커밋

```text
Task #409 Stage 1: Swift external image wrapper와 FFI 계약 구현
```

## Stage 2. Open context, basename-only resolver와 report

### 목표

filesystem policy와 FFI injection을 분리한 Shared loader를 구현하고, 실패를 non-fatal report로 고정한다.

### 대상

- 신규 `Sources/Shared/HwpExternalImageResolver.swift`
- `Tests/ExternalImageTests/HwpExternalImageResolverTests.swift`
- `Tests/ExternalImageTests/ExternalImageTestSupport.swift`
- `project.yml`
- `mydocs/working/task_m020_409_stage2.md`
- `mydocs/orders/20260724.md`

### 작업

1. open context, open result, report state, decision, resolution, summary model을 구현한다.
2. resolver가 사용할 최소 document-access protocol을 정의하고 `RhwpDocument`를 conform시킨다.
3. source nil/non-file disabled 경로에서는 refs query/injection이 호출되지 않게 한다.
4. basename invalid 조건과 source document self-reference reject를 구현한다.
5. standardized/resolved parent equality로 parent/symlink escape를 차단한다.
6. regular file, metadata size, read-after-size 검사를 구현한다.
7. missing, permission denied, read failure를 Foundation/POSIX error code로 구분한다.
8. ref 단위 실패 후 다음 ref를 계속 처리한다.
9. injection에는 safe key, bytes, basename display path만 전달한다.
10. final refs re-query로 loaded 상태를 확인한다.
11. report가 path/basename을 소유하지 않고 count summary만 제공하는지 test한다.
12. `ExternalImageTests` target에 Shared resolver source를 추가한다.

### 필수 test matrix

- source URL nil → disabled, refs query 0회
- non-file URL → disabled, refs query 0회
- refs empty → attempted, resolution 0건
- 이미 loaded → file read/injection 없이 alreadyLoaded
- valid sibling → injection, byte count, basename display path, loaded 재확인
- empty, `.`, `..`, slash, backslash, NUL basename reject
- candidate가 source document 자신인 경우 reject
- directory reject
- sibling symlink가 parent 밖으로 나가는 경우 reject
- parent 내부 regular sibling 허용
- metadata size cap 초과
- read 뒤 actual byte count cap 초과
- missing
- injected data-loader permission denied
- injected data-loader generic read failure
- bridge referenceNotFound/failure/unknown status
- 한 ref 실패 후 다음 valid ref injection 지속
- injection `.ok` 후 loaded 미전환 → verificationFailed
- final refs query 실패 → pending injection verificationFailed
- report summary 문자열/필드에 original/candidate path와 basename 없음

### 검증

```bash
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ExternalImageTests \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Stage2 \
  CODE_SIGNING_ALLOWED=NO \
  test
rg -n "originalPath|basename|resolvingSymlinksInPath|isRegularFile|fileSize|permissionDenied|verificationFailed" \
  Sources/Shared/HwpExternalImageResolver.swift Tests/ExternalImageTests
git diff --check
```

### 완료 조건

- resolver가 basename 외 external path 정보를 filesystem 접근에 사용하지 않는다.
- parent/symlink escape, directory, source self-reference, size cap이 차단된다.
- permission/missing/read/bridge failure가 render-fatal exception 대신 report로 남는다.
- valid sibling이 key injection되고 final loaded 상태가 확인된다.
- report와 summary가 privacy-safe하다.

### 커밋

```text
Task #409 Stage 2: basename-only resolver와 진단 report 구현
```

## Stage 3. Quick Look Preview open flow와 privacy-safe log 연결

### 목표

Quick Look Preview의 실제 load 경로에 external resolution을 연결하고, single/multi reply가 resolved document를 재사용하게 한다.

### 대상

- `Sources/Shared/HwpPreviewPDFRenderer.swift`
- `Sources/QLExtension/HwpPreviewProvider.swift`
- `scripts/smoke-quicklook-skia-policy.sh`
- `scripts/quicklook_skia_policy_smoke.swift`
- `scripts/compare-quicklook-pdf-renderers.sh`
- 필요 시 `Tests/ExternalImageTests/`의 Preview contract test
- `mydocs/working/task_m020_409_stage3.md`
- `mydocs/orders/20260724.md`

### 작업

1. `HwpPreviewDocumentContext`에 `externalResourceReport`를 추가한다.
2. `HwpPreviewPDFRenderer.load(fileURL:)`가 50 MB main file preflight와 data read 후 `RhwpDocumentOpenContext`를 생성하게 한다.
3. Shared loader가 resolve/inject를 마친 뒤 반환한 document에서만 page count와 first page size를 조회한다.
4. `render(fileURL:)`는 기존처럼 `load`를 사용해 resolver가 활성화된다.
5. `inspect(fileURL:)`와 `render(previewInfo:)`는 source context를 보존하지 않으므로 resolver disabled를 유지한다.
6. single-page PNG와 multi-page PDF는 context의 같은 document handle을 사용한다.
7. `HwpPreviewProvider`가 external report summary를 load 직후 한 번 기록한다.
8. log field를 state/count로 제한하고 external basename/path를 전달하지 않는다.
9. source-level Quick Look smoke helper에 external report count를 detail/summary로 추가한다.
10. `HwpExternalImageResolver.swift`를 compile list에 추가해야 하는 두 shell helper를 갱신한다.
11. standard no-external HWP/HWPX에서 attempted + resolution 0건과 기존 output을 확인한다.
12. HostApp/Thumbnail target은 새 Shared source를 compile하되 resolver 호출 경로가 추가되지 않았는지 확인한다.

### 검증

```bash
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ExternalImageTests \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Stage3Tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Stage3 \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Stage3QL \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ThumbnailExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Stage3Thumb \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/smoke-quicklook-skia-policy.sh \
  build.noindex/task409-stage3-quicklook \
  samples/basic/request.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
rg -n "externalResource|injected|missing|rejected|permissionDenied|readFailed|bridgeFailed" \
  Sources/QLExtension/HwpPreviewProvider.swift scripts/quicklook_skia_policy_smoke.swift
git diff --check
```

### 완료 조건

- Preview open 순서가 setter/query/injection 완료 후 page count/size다.
- single-page PNG와 multi-page PDF가 같은 resolved handle을 사용한다.
- no-external fixture output과 reply shape에 회귀가 없다.
- inspect/bytes-only/Thumbnail/HostApp 경로에서 resolver가 활성화되지 않는다.
- provider log에 external path와 basename이 없다.
- 세 제품 target과 unit test가 통과한다.

### 커밋

```text
Task #409 Stage 3: Quick Look Preview external image 연결
```

## Stage 4. Pinned external fixture와 registered Preview 통합 검증

### 목표

실제 external refs와 sibling image bytes로 injection/loaded/render를 증명하고, Quick Look sandbox 제품 경로에서 sibling 접근을 확인한다.

### 대상

- pinned upstream checkout의 다음 비커밋 fixture
  - `samples/hwp3-sample10-hwpx.hwpx`
  - `samples/oracle.gif`
  - `samples/rdb02.gif`
  - `samples/s1.jpg`
- `build.noindex/task409-*` 검증 산출물
- 필요 시 Stage 4 안에서 발견된 #409 범위 source/test 보정
- `mydocs/working/task_m020_409_stage4.md`
- `mydocs/orders/20260724.md`

### fixture 준비

```bash
TASK409_RHWP_ROOT=/Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/93862a4
test "$(git -C "$TASK409_RHWP_ROOT" rev-parse HEAD)" = "93862a4e16df59834ebce46d91e948cd739208e9"

mkdir -p build.noindex/task409-external-valid
ditto "$TASK409_RHWP_ROOT/samples/hwp3-sample10-hwpx.hwpx" \
  build.noindex/task409-external-valid/hwp3-sample10-hwpx.hwpx
ditto "$TASK409_RHWP_ROOT/samples/oracle.gif" \
  build.noindex/task409-external-valid/oracle.gif
ditto "$TASK409_RHWP_ROOT/samples/rdb02.gif" \
  build.noindex/task409-external-valid/rdb02.gif
ditto "$TASK409_RHWP_ROOT/samples/s1.jpg" \
  build.noindex/task409-external-valid/s1.jpg

TASK409_MISSING_DIR="$(mktemp -d build.noindex/task409-external-missing.XXXXXX)"
ditto "$TASK409_RHWP_ROOT/samples/hwp3-sample10-hwpx.hwpx" \
  "$TASK409_MISSING_DIR/hwp3-sample10-hwpx.hwpx"
ditto "$TASK409_RHWP_ROOT/samples/rdb02.gif" \
  "$TASK409_MISSING_DIR/rdb02.gif"
ditto "$TASK409_RHWP_ROOT/samples/s1.jpg" \
  "$TASK409_MISSING_DIR/s1.jpg"
```

missing case에는 `oracle.gif`을 복사하지 않는다. upstream checkout과 repository sample 원본은 수정하지 않는다.

### 작업

1. valid fixture에서 initial refs 3건이 unloaded인지 확인한다.
2. Preview source-level smoke로 sibling 3건 injection, final loaded 3건, non-empty PNG/PDF output을 확인한다.
3. missing fixture에서 available ref는 injection되고 missing ref는 report에 남으며 main render가 계속되는지 확인한다.
4. unit test 전체 matrix로 invalid basename, escape, directory, too large, permission/read failure를 다시 확인한다.
5. 기본 HWP/HWPX/embedded/multi-page renderer 회귀를 실행한다.
6. strict log/code inspection으로 external original/candidate path 미노출을 확인한다.
7. Quick Look registration hygiene를 check-only로 확인한다.
8. 실제 registered Preview smoke는 작업지시자에게 local package·registration·cleanup 승인을 별도로 받은 뒤 표준 helper로 수행한다.
   - signed/sealed local app만 사용한다.
   - active provider path를 확인한다.
   - valid sibling fixture를 `qlmanage -p`로 연다.
   - QLExtension subsystem log에서 injected count를 확인한다.
   - external path/basename이 log에 없는지 확인한다.
   - 검증 종료 시 개발 산출물 registration을 표준 cleanup helper로 해제한다.
9. registered smoke에서 sandbox permission denied가 나오면 entitlement를 임의 변경하지 않는다. exact error/report와 active provider path를 기록하고 범위 확장 승인을 요청한다.

### 검증

#### Source-level external fixture

```bash
./scripts/smoke-quicklook-skia-policy.sh \
  build.noindex/task409-external-valid-output \
  build.noindex/task409-external-valid/hwp3-sample10-hwpx.hwpx
rg -n "external.*3|injected.*3|missing.*0|loadStatus=OK|status=OK" \
  build.noindex/task409-external-valid-output

./scripts/smoke-quicklook-skia-policy.sh \
  build.noindex/task409-external-missing-output \
  "$TASK409_MISSING_DIR/hwp3-sample10-hwpx.hwpx"
rg -n "injected|missing|loadStatus=OK|status=OK" \
  build.noindex/task409-external-missing-output
```

#### 전체 회귀

```bash
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ExternalImageTests \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Stage4Tests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Stage4 \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh \
  build.noindex/task409-stage4-render \
  samples/basic/KTX.hwp \
  samples/basic/request.hwp \
  samples/hwp-img-001.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
./scripts/check-extension-registration-hygiene.sh --check-only
git diff --check
git diff --exit-code -- RustBridge rhwp-ffi-symbols.txt rhwp-core.lock Frameworks
```

### 완료 조건

- pinned fixture 세 external ref가 Swift wrapper에서 decode된다.
- valid sibling 3건이 injection되고 final `loaded == true`로 확인된다.
- source-level Preview output이 non-empty이며 main render가 성공한다.
- missing/rejected/tooLarge/permission/read/bridge failure가 report로 남고 render-fatal로 승격되지 않는다.
- actual registered QLExtension에서 valid sibling 접근과 injected count가 확인된다.
- provider log에 original path, candidate absolute path, basename이 없다.
- 기존 HWP/HWPX, embedded image, single/multi reply에 회귀가 없다.
- 개발 산출물 registration cleanup과 active provider hygiene가 확인된다.

### 커밋

```text
Task #409 Stage 4: external fixture와 Preview 통합 검증
```

## Stage 5. 최종 보고서와 후속 handoff

### 목표

wrapper/resolver/Preview 계약과 검증 근거를 최종 정리하고, 후속 external image 작업의 책임 경계를 확정한다.

### 대상

- `mydocs/report/task_m020_409_report.md`
- `mydocs/orders/20260724.md`

### 작업

1. Stage 1-4 source, test, smoke 결과와 commit을 요약한다.
2. status mapping, refs JSON, C string free, UTF-8/data lifetime을 기록한다.
3. basename-only containment, symlink, size, permission, privacy 정책을 기록한다.
4. source-level fixture와 registered QLExtension smoke 결과를 분리해 기록한다.
5. Thumbnail #411, fixture suite #412, WKWebView #413, renderer diagnostic #410에 남긴 범위를 명시한다.
6. actual sandbox sibling access와 잔여 TOCTOU/total-memory risk를 기록한다.
7. 오늘할일을 완료로 갱신한다.
8. 최종 검증 후 `task-final-report` 실행 전 승인을 요청한다.

### 검증

```bash
rg -n "#409|RhwpExternalImageOperationStatus|basename|sibling|injected|loaded|permission|privacy|Quick Look|#410|#411|#412|#413" \
  mydocs/report/task_m020_409_report.md mydocs/orders/20260724.md
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ExternalImageTests \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409FinalTests \
  CODE_SIGNING_ALLOWED=NO \
  test
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Final \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh build.noindex/task409-final-render
git diff --check
git status --short
git log --oneline origin/devel..HEAD
```

### 완료 조건

- 최종 보고서가 구현, security policy, FFI lifetime, source/registered smoke, 잔여 리스크를 포함한다.
- 모든 단계 보고서와 검증 결과가 commit과 대응한다.
- 오늘할일이 완료 처리되어 있다.
- working tree가 clean하고 최종 PR 게시 승인 요청이 가능하다.

### 커밋

```text
Task #409 Stage 5 + 최종 보고서: Quick Look external image 지원 정리
```

## 단계별 승인 지점

1. 이 구현계획서 승인 후 Stage 1을 시작한다.
2. Stage 1 완료보고서 승인 후 Stage 2를 시작한다.
3. Stage 2 완료보고서 승인 후 Stage 3을 시작한다.
4. Stage 3 완료보고서 승인 후 Stage 4를 시작한다.
5. Stage 4의 actual Quick Look registration smoke 전 local package·registration·cleanup 승인을 별도로 확인한다.
6. Stage 4 완료보고서 승인 후 Stage 5를 시작한다.
7. 최종 결과보고서 승인 후 `task-final-report` 절차로 PR을 게시한다.

구현계획서 승인 전에는 Swift source, `project.yml`, test, script, fixture, Quick Look registration을 변경하지 않는다.
