# Task M020 #409 Stage 1 보고서

## 단계 목적

Stage 1의 목적은 #408에서 추가한 external image C ABI를 Swift에서 포인터 수명 규칙에 맞게 호출하고, status와 refs JSON 계약을 독립 unit test로 고정하는 것이다.

이 단계에서는 filesystem resolver나 Quick Look Preview 연결을 구현하지 않는다. 기존 `RhwpDocument` initializer도 resolver를 자동 실행하지 않으며, filename context와 external image injection은 명시 호출 API로만 추가한다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `Sources/RhwpCoreBridge/RhwpDocument.swift` | Swift status/model/error와 filename setter, refs query, key 기반 image injection wrapper를 추가했다. 현재 409줄이다. |
| `Tests/ExternalImageTests/RhwpDocumentExternalImageBridgeTests.swift` | status, JSON decode, 실제 C ABI 호출, invalid input, 반복 query를 검증하는 test 6개를 추가했다. 현재 138줄이다. |
| `Tests/ExternalImageTests/ExternalImageTestSupport.swift` | repository sample을 test data로 읽는 helper를 추가했다. 현재 15줄이다. |
| `project.yml` | `ExternalImageTests` standalone unit test target과 `Rhwp.xcframework` link dependency를 추가했다. 현재 175줄이다. |
| `mydocs/working/task_m020_409_stage1.md` | Stage 1 변경, 검증, 잔여 위험과 Stage 2 handoff를 기록한다. |
| `mydocs/orders/20260724.md` | #409를 Stage 1 완료 및 Stage 2 승인 대기 상태로 갱신한다. |

## 구현 결과

### Swift status와 refs model

imported C enum과 이름 충돌을 피하도록 `RhwpExternalImageOperationStatus`를 추가하고 raw value를 다음처럼 보존했다.

| C raw value | Swift status |
|-------------|--------------|
| `0` | `.ok` |
| `1` | `.invalidHandle` |
| `2` | `.invalidInput` |
| `3` | `.invalidUTF8` |
| `4` | `.referenceNotFound` |
| `5` | `.alreadyLoaded` |
| `6` | `.failure` |
| 그 외 | `.unknown(rawValue)` |

`RhwpExternalImageReference`는 upstream JSON의 다음 필드를 decode한다.

- `key`
- `binDataId`
- `originalPath`
- `basename`
- `extension` → Swift `fileExtension`
- `loaded`

`JSONDecoder`의 기본 additive-field 허용 동작은 유지하면서 필수 필드 누락, `UInt16` 범위 초과, 배열이 아닌 root 같은 invalid shape는 `RhwpExternalImageBridgeError.invalidReferencesJSON`으로 정규화한다. `rhwp_external_image_refs_json`이 null을 반환하면 `.referencesUnavailable`로 구분한다.

### FFI wrapper와 수명 규칙

`RhwpDocument`에 다음 명시 호출 API를 추가했다.

```swift
func setFileName(_ filename: String) -> RhwpExternalImageOperationStatus
func externalImageReferences() throws -> [RhwpExternalImageReference]
func injectExternalImage(
    key: String,
    data: Data,
    displayPath: String? = nil
) -> RhwpExternalImageOperationStatus
```

수명과 ownership 규칙은 다음과 같이 적용했다.

- Swift `String`은 UTF-8 byte array로 변환하고 해당 `withUnsafeBufferPointer` closure 안에서만 C pointer를 사용한다.
- injection의 key, image data, optional display path buffer는 중첩 closure로 묶어 `rhwp_inject_external_image_by_key` 호출이 끝나기 전에 어느 pointer도 escape하지 않는다.
- nil 또는 빈 display path는 C ABI에 `(nil, 0)`으로 전달한다.
- refs JSON C string은 Swift `Data`로 즉시 복사한다.
- non-null refs pointer를 얻은 직후 `defer { rhwp_free_string(jsonPointer) }`를 등록하므로 JSON decode 성공과 throw 경로 모두에서 한 번 해제한다.

기존 `RhwpDocument` initializer, render, page tree, overlay, image data method signature는 변경하지 않았다. initializer는 기존 filename 인자를 계속 받지만 external image resolver나 injection을 자동 실행하지 않는다.

### 독립 test target

`project.yml`에 `ExternalImageTests`를 additive하게 추가했다. test target은 다음 source만 compile한다.

- `Tests/ExternalImageTests`
- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `Sources/RhwpCoreBridge/RenderTree.swift`

제품 target과 같은 `Rhwp.xcframework` 및 macOS system link dependency를 사용하되 HostApp, PreviewExtension, ThumbnailExtension을 test host로 두지 않는다. `xcodegen generate`로 생성한 `Alhangeul.xcodeproj/project.pbxproj`는 검증에만 사용한 뒤 복원했으며 커밋하지 않는다.

test 6개가 고정한 계약은 다음과 같다.

1. status raw value `0...6`과 unknown value 보존
2. refs JSON의 `extension` 매핑과 additive field 허용
3. 필수 필드 누락, `UInt16` overflow, non-array JSON 거부
4. repository `samples/basic/KTX.hwp`의 filename `.ok`, refs `[]`, 미등록 key `.referenceNotFound`
5. 빈 key와 빈 data의 `.invalidInput`
6. refs query 128회 반복 시 copy/free 경로 안정성

## 본문 변경 정도 / 본문 무손실 여부

- `RhwpDocument.swift`의 기존 본문은 그대로 두고 external image model과 명시 호출 method를 additive하게 추가했다.
- 기존 initializer의 parse/handle 소유 흐름과 `deinit`의 `rhwp_close` 호출은 변경하지 않았다.
- 기존 SVG/tree/overlay/PNG/image data API의 signature와 구현은 변경하지 않았다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 의존성을 추가하지 않았다.
- `project.yml`의 기존 target 정의는 수정하지 않고 신규 unit test target만 추가했다.
- RustBridge source, `rhwp-core.lock`, FFI symbol 목록, entitlement, Quick Look/Thumbnail 제품 경로는 변경하지 않았다.
- `build-rust-macos.sh --verify-lock`이 재생성한 framework/staticlib는 lock 기준과 동일해 Git 변경으로 남지 않았다.

## 검증 결과

### Core lock과 XCFramework 검증

```bash
./scripts/build-rust-macos.sh --verify-lock
```

결과: 최종 통과.

```text
Architectures in the fat file: .../Frameworks/universal/librhwp.a are: x86_64 arm64
FFI symbols:
rhwp_external_image_refs_json
rhwp_inject_external_image_by_key
rhwp_set_file_name_utf8
...
Verified: .../rhwp-core.lock
```

첫 sandbox 실행은 `skia-bindings v0.99.0` binary와 source를 내려받는 과정에서 GitHub DNS가 제한되어 실패했다. 네트워크 권한으로 같은 명령을 다시 실행해 두 architecture build, cbindgen header check, XCFramework 생성, lock 검증을 모두 통과했다. 이는 source 또는 lock 불일치가 아니다.

### Shared boundary

```bash
./scripts/check-no-appkit.sh
```

결과: 통과.

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### Xcode project 생성과 unit test

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ExternalImageTests \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Stage1 \
  CODE_SIGNING_ALLOWED=NO \
  test
```

결과: 통과.

```text
Test Suite 'RhwpDocumentExternalImageBridgeTests' passed
Executed 6 tests, with 0 failures
** TEST SUCCEEDED **
```

test result bundle:

```text
build.noindex/DerivedDataTask409Stage1/Logs/Test/
Test-ExternalImageTests-2026.07.24_21-57-21-+0900.xcresult
```

첫 sandbox test 실행은 Swift compile 문제가 아니라 Sparkle package fetch의 DNS 제한으로 실패했다. 네트워크 권한이 있는 같은 명령에서 Sparkle 2.9.1을 resolve한 뒤 compile/link와 test가 모두 성공했다.

비차단 warning으로 test target deployment target 12.0과 XCTest link minimum 14.0 차이, AppIntents metadata가 없다는 안내가 출력됐다. test 실행과 제품 source compile에는 영향을 주지 않았다.

### 계약 및 변경 점검

```bash
rg -n "RhwpExternalImageOperationStatus|RhwpExternalImageReference|setFileName|externalImageReferences|injectExternalImage|rhwp_free_string" \
  Sources/RhwpCoreBridge/RhwpDocument.swift Tests/ExternalImageTests
git diff --check
git status --short
```

결과: 통과.

- wrapper/model/test symbol이 계획된 source에 존재한다.
- whitespace 오류가 없다.
- 생성된 Xcode project와 framework는 변경 목록에 남지 않았다.
- 변경 목록은 Stage 1 source, test, `project.yml`, 보고서, 오늘할일로 한정된다.

## 잔여 위험

- repository의 `KTX.hwp`는 external refs가 없는 sample이므로 refs query와 실패 status는 실제 ABI로 검증했지만 성공 injection의 `loaded: false → true` 전이는 아직 검증하지 못했다.
- 현재 refs decode는 #408/upstream의 여섯 필드를 필수 계약으로 둔다. upstream이 필드를 제거하거나 타입을 바꾸면 의도대로 `.invalidReferencesJSON`이 된다.
- `strlen`은 #408이 반환하는 null-terminated JSON 계약에 의존한다. pointer가 null이면 decode를 시도하지 않고 `.referencesUnavailable`로 종료한다.
- standalone test target은 계획된 bridge source만 compile한다. Stage 2 resolver source를 추가할 때 target source 목록과 compile helper 목록을 함께 갱신해야 한다.
- Quick Look runtime과 sandbox filesystem 접근은 Stage 3 및 Stage 4 검증 전까지 확인되지 않는다.

## 다음 단계 영향

Stage 2는 이번 단계의 model과 wrapper 위에 open context, basename-only sibling resolver, non-fatal report를 구현한다.

- filesystem 접근에는 `originalPath`를 사용하지 않고 `reference.basename`만 사용한다.
- 절대 경로, 경로 구분자, `.`/`..`, symlink escape, non-regular file을 거부한다.
- read/permission/verification/bridge rejection을 report로 분리하고 문서 open 자체는 실패시키지 않는다.
- 허용된 sibling file bytes와 basename display path만 이번 단계의 `injectExternalImage`에 전달한다.
- `ExternalImageTests` target에 resolver source와 policy test를 추가한다.

## 승인 요청

Stage 1 `Swift external image model과 FFI wrapper`는 완료됐다. Stage 2 `Open context, basename-only resolver와 report`로 진행하려면 작업지시자 승인이 필요하다.
