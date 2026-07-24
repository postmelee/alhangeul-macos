# Task M020 #409 Stage 2 보고서

## 단계 목적

Stage 2의 목적은 filesystem 정책을 Rust FFI wrapper와 분리한 Shared open helper를 구현하고, source document와 같은 디렉터리의 regular sibling만 `basename`으로 읽어 external image key에 주입하는 것이다.

reference 단위의 missing, reject, size, permission, read, bridge, verification 실패는 main document open이나 이후 render의 fatal error로 올리지 않고 privacy-safe report에 남긴다. 이 단계에서는 Quick Look Preview 제품 경로에 resolver를 아직 연결하지 않는다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `Sources/Shared/HwpExternalImageResolver.swift` | open context/result, document-access protocol, basename-only resolver, resolution/report/summary를 추가했다. 현재 441줄이다. |
| `Tests/ExternalImageTests/HwpExternalImageResolverTests.swift` | filesystem 정책, 실패 분류, injection, 최종 loaded 검증, privacy-safe summary를 검증하는 test 18개를 추가했다. 현재 826줄이다. |
| `Tests/ExternalImageTests/ExternalImageTestSupport.swift` | test별 임시 디렉터리와 file 생성 helper를 추가했다. 현재 44줄이다. |
| `project.yml` | `ExternalImageTests` target에 Shared resolver source를 추가했다. 현재 176줄이다. |
| `mydocs/working/task_m020_409_stage2.md` | Stage 2 변경, 검증, 잔여 위험과 Stage 3 handoff를 기록한다. |
| `mydocs/orders/20260724.md` | #409를 Stage 2 완료 및 Stage 3 승인 대기 상태로 갱신한다. |

## 구현 결과

### Open context와 document 경계

`RhwpDocumentOpenContext`는 다음 세 입력만 소유한다.

- optional `sourceURL`
- optional `displayFilename`
- external resource 한 건당 `maximumExternalResourceBytes`

`HwpExternalImageResolver.open(data:context:)`는 main bytes로 `RhwpDocument`를 생성하고 resolver가 끝난 document와 report를 `RhwpDocumentOpenResult`로 반환한다. resolver가 사용할 bridge 표면은 `RhwpExternalImageDocumentAccess` protocol의 다음 세 method로 제한했다.

- `setFileName`
- `externalImageReferences`
- `injectExternalImage`

`RhwpDocument`는 이 protocol을 별도 handle 노출 없이 채택한다. test는 fake document를 사용해 filesystem policy와 FFI status 처리를 독립적으로 검증한다.

display filename이 있으면 source 활성 여부보다 먼저 setter를 호출하고 결과를 `filenameStatus`에 보존한다. setter 실패는 report 값이며 main document open을 실패시키지 않는다.

source가 nil이면 `.disabledNoSourceURL`, file URL이 아니면 `.disabledNonFileURL`을 반환한다. 두 disabled 경로에서는 refs query와 injection을 호출하지 않는다. bytes-only 기존 caller는 계속 기존 initializer를 직접 사용할 수 있고 resolver가 자동 활성화되지 않는다.

### Basename-only sibling 정책

filesystem 후보를 만들 때 사용하는 external reference field는 `basename` 하나뿐이다. `originalPath`는 resolver source에서 참조하지 않으며, test에서 실제 outside file path를 `originalPath`로 주더라도 sibling basename이 없으면 `.missing`이 되는 계약을 고정했다.

다음 basename은 candidate 계산 전에 `.rejectedInvalidBasename`으로 거부한다.

- empty
- `.`
- `..`
- `/` 포함
- `\` 포함
- NUL 포함

허용된 basename은 source document의 standardized parent에 단일 path component로만 붙인다. source, source parent, candidate에 표준화와 symlink resolution을 적용하고 다음을 구분한다.

- candidate 또는 resolved candidate가 source document와 같음 → `.rejectedSourceDocument`
- symlink-resolved candidate parent가 symlink-resolved source parent와 다름 → `.rejectedOutsideSourceDirectory`
- metadata상 regular file이 아님 → `.rejectedNonRegularFile`

따라서 directory, source self-reference, parent 밖을 가리키는 sibling symlink는 file read 전에 차단된다. parent 내부 direct regular sibling은 허용된다.

### Metadata, read와 실패 분류

candidate metadata에서 `.isRegularFileKey`와 `.fileSizeKey`를 조회한다. metadata size가 상한을 넘으면 read하지 않고 `.tooLarge(actualBytes:limit:)`를 기록한다.

허용된 candidate는 production에서 `Data(contentsOf:options: [.mappedIfSafe])`로 읽는다. test에서는 data-loader closure를 주입할 수 있어 실제 metadata 정책을 유지한 채 permission/read 오류와 read-after-size를 결정적으로 검증한다. read 후 `Data.count`를 다시 상한과 비교하므로 metadata 이후 크기가 커진 입력도 injection 전에 `.tooLarge`가 된다.

Foundation/POSIX 오류는 다음처럼 분류한다.

- Cocoa no-such-file 또는 POSIX `ENOENT` → `.missing`
- Cocoa no-permission 또는 POSIX `EACCES`/`EPERM` → `.permissionDenied`
- 그 외 metadata/read 오류 → `.readFailed`

underlying error가 permission/missing을 제공하면 같은 분류를 보존한다. 한 reference의 실패 후에도 다음 reference 처리는 계속된다.

### Injection과 최종 verification

허용된 candidate는 다음 값만 bridge에 전달한다.

- upstream reference `key`
- 읽은 image bytes
- 검증된 `basename` display path

bridge status 처리는 다음과 같다.

- `.ok` → pending verification
- injection 시점 `.alreadyLoaded` → 경쟁 상태를 허용하고 최종 `.alreadyLoaded`
- 나머지 status → raw 의미를 보존한 `.bridgeRejected(status)`

모든 reference 처리가 끝난 뒤 pending `.ok` injection이 하나라도 있으면 refs를 한 번만 재조회한다. 같은 key의 `loaded == true`가 확인된 경우에만 `.injected(byteCount:)`를 유지한다. key가 없거나 loaded가 false이거나 final query가 실패하면 `.verificationFailed`로 바꾼다.

### Privacy-safe report

reference별 `RhwpExternalResourceResolution`은 safe discovery `key`와 decision만 소유한다. basename, original path, candidate URL, resolved absolute path를 report에 저장하지 않는다.

`RhwpExternalResourceSummary`는 다음 count만 제공한다.

- total
- injected
- alreadyLoaded
- missing
- rejected
- tooLarge
- permissionDenied
- readFailed
- bridgeFailed

`privacySafeDescription`은 report state identifier와 이 count만 문자열화한다. `.bridgeRejected`와 `.verificationFailed`는 `bridgeFailed` 집계에 포함한다.

## Test matrix 결과

신규 resolver test 18개가 다음 계약을 검증한다.

1. 실제 `KTX.hwp` bytes-only open은 document를 열되 resolver를 disabled로 유지
2. source URL nil/non-file에서 refs query와 injection 0회
3. refs empty에서 attempted/0건
4. initial refs query 실패가 non-fatal `referenceQueryFailed`
5. 이미 loaded인 ref는 read/injection 없이 `alreadyLoaded`
6. valid sibling bytes/key/basename injection과 final loaded 확인
7. 실제 outside `originalPath`를 filesystem discovery에 사용하지 않음
8. injection 시점 `.alreadyLoaded` 경쟁 상태 허용
9. empty, `.`, `..`, slash, backslash, NUL basename 거부
10. source document self-reference와 directory 거부
11. parent 밖 sibling symlink 거부
12. metadata size와 read 후 실제 byte size 상한을 각각 적용
13. missing, permission denied, generic read failure 구분
14. bridge `.referenceNotFound`, `.failure`, `.unknown` 보존
15. 한 ref 실패 후 다음 valid ref injection 지속
16. `.ok` injection 후 loaded 미전환 시 verification failure
17. final refs query 실패 시 pending injection 전체 verification failure
18. summary field와 문자열이 count만 포함하는지 확인

Stage 1 bridge test 6개도 함께 실행해 총 24개가 통과했다.

## 본문 변경 정도 / 본문 무손실 여부

- 신규 구현은 `Sources/Shared/HwpExternalImageResolver.swift` 한 파일에 격리했다.
- `Sources/RhwpCoreBridge/RhwpDocument.swift`와 Rust FFI 본문은 변경하지 않았다.
- `Sources/RhwpCoreBridge`에 Foundation filesystem 정책이나 AppKit/UIKit 의존성을 추가하지 않았다.
- `project.yml`은 기존 `ExternalImageTests` source 목록에 resolver 파일 한 건만 추가했다.
- HostApp, QLExtension, ThumbnailExtension의 기존 open/render 호출 순서와 제품 동작은 변경하지 않았다.
- entitlement, RustBridge, `rhwp-core.lock`, FFI symbol, generated framework를 변경하지 않았다.
- `xcodegen generate`로 검증한 `Alhangeul.xcodeproj/project.pbxproj`는 복원했으며 커밋하지 않는다.

## 검증 결과

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
  -derivedDataPath build.noindex/DerivedDataTask409Stage2 \
  CODE_SIGNING_ALLOWED=NO \
  test
```

결과: 최종 통과.

```text
Test Suite 'HwpExternalImageResolverTests' passed
Executed 18 tests, with 0 failures
Test Suite 'RhwpDocumentExternalImageBridgeTests' passed
Executed 6 tests, with 0 failures
Test Suite 'All tests' passed
Executed 24 tests, with 0 failures
** TEST SUCCEEDED **
```

최종 test result bundle:

```text
build.noindex/DerivedDataTask409Stage2/Logs/Test/
Test-ExternalImageTests-2026.07.24_23-20-55-+0900.xcresult
```

첫 sandbox 실행은 Sparkle package fetch의 GitHub DNS 제한으로 중단됐다. 네트워크 권한으로 같은 명령을 실행해 compile/link와 22개 당시 test가 통과했다. 정책 보완 test 2개를 추가한 뒤 sandbox 재검증은 SwiftPM/Clang 사용자 cache 쓰기 제한으로 중단됐고, 정상 Xcode cache 접근이 가능한 같은 명령에서 최종 24개가 통과했다. 두 실패 모두 source/test assertion 실패가 아니다.

비차단 warning으로 test target deployment target 12.0과 XCTest link minimum 14.0 차이, AppIntents metadata가 없다는 안내가 출력됐다. Stage 1과 같은 기존 test 환경 warning이며 실행 결과에는 영향을 주지 않았다.

### 정책 symbol과 변경 점검

```bash
rg -n "originalPath|basename|resolvingSymlinksInPath|isRegularFile|fileSize|permissionDenied|verificationFailed" \
  Sources/Shared/HwpExternalImageResolver.swift Tests/ExternalImageTests
git diff --check
git status --short
```

결과: 통과.

- resolver source에는 `originalPath` 참조가 없고 filesystem candidate는 `reference.basename`으로만 만든다.
- standardized/resolved parent, regular-file, metadata/read size, permission, verification 정책 symbol이 source와 test에 존재한다.
- whitespace 오류가 없다.
- 생성된 Xcode project와 build 산출물은 변경 목록에 남지 않았다.
- 변경 목록은 Stage 2 resolver, test/support, `project.yml`, 보고서, 오늘할일로 한정된다.

## 잔여 위험

- 성공 injection의 실제 FFI `loaded: false → true` 전이는 아직 protocol fake로 고정한 상태다. pinned upstream external fixture와 실제 bridge를 사용하는 end-to-end 검증은 Stage 4가 수행한다.
- 실제 Quick Look extension sandbox에서 sibling read 권한이 유지되는지는 Stage 3 연결 뒤 Stage 4 registered smoke로 확인해야 한다.
- permission/read 분류는 deterministic data-loader 오류로 검증했다. extension sandbox가 반환하는 실제 NSError/POSIX 조합은 Stage 4 report와 log에서 다시 확인한다.
- v1 resolver는 계획대로 standardized path, symlink resolution, metadata, read를 순차 수행한다. 파일시스템 항목이 각 단계 사이에서 공격적으로 교체되는 TOCTOU까지 원자적으로 막는 file-descriptor 기반 resolver는 이번 범위가 아니며, 실제 smoke나 보안 검토에서 필요성이 확인되면 별도 작업으로 분리해야 한다.
- report resolution은 upstream key를 보존한다. 현재 key는 `binData:{id}` 계약이며 Stage 3 log에는 resolution key 자체를 기록하지 않고 summary count만 사용해야 한다.

## 다음 단계 영향

Stage 3는 이번 단계의 open result를 Quick Look Preview 제품 경로에 연결한다.

- `HwpPreviewPDFRenderer.load(fileURL:)`의 main file preflight/read 뒤 `RhwpDocumentOpenContext`를 만든다.
- `HwpExternalImageResolver.open`이 끝난 document에서만 page count와 first page size를 조회한다.
- `HwpPreviewDocumentContext`에 external resource report를 포함한다.
- single-page PNG와 multi-page PDF는 같은 resolved document handle을 재사용한다.
- `HwpPreviewProvider`는 state identifier와 summary count만 log하고 external basename/path/key는 기록하지 않는다.
- Thumbnail, bytes-only render, HostApp WKWebView 경로는 resolver 비활성 상태를 유지한다.

## 승인 요청

Stage 2 `Open context, basename-only resolver와 report`는 완료됐다. Stage 3 `Quick Look Preview open flow와 privacy-safe log 연결`로 진행하려면 작업지시자 승인이 필요하다.
