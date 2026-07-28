# Task #409 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#409 Swift external image wrapper/resolver와 Quick Look Preview 적용](https://github.com/postmelee/alhangeul-macos/issues/409) |
| Parent | #407 external image context ABI 후속 구현 추적 |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 작업 브랜치 | `local/task409` |
| 단계 | Stage 1~5 |
| core 기준 | `rhwp` v0.7.18, commit `93862a4e16df59834ebce46d91e948cd739208e9`, feature `native-skia` |

#408에서 추가된 external image C ABI를 Swift에서 안전하게 감싸고, source document와 같은 directory의 regular sibling image만 `basename` 기준으로 주입하는 resolver를 구현했다. 이 resolver를 Quick Look Preview의 file URL open 경로에 연결하고 single-page PNG와 multi-page PDF가 injection이 끝난 동일한 `RhwpDocument` handle을 재사용하도록 했다.

핵심 결과:

- C ABI status raw value, refs JSON, UTF-8/data pointer와 반환 문자열 ownership을 Swift 계약으로 고정했다.
- `originalPath`를 filesystem discovery에 사용하지 않는 basename-only sibling 정책을 구현했다.
- invalid basename, source self-reference, symlink escape, directory, size, missing, permission, read와 bridge failure를 reference별 non-fatal report로 분류했다.
- pinned fixture의 external reference 3건을 source-level Preview 경로에서 모두 injection하고 final `loaded == true`와 764-page render를 확인했다.
- missing 1건과 oversize 1건은 각각 report에 남기면서 main render를 계속했다.
- 실제 registered Quick Look에서는 macOS 26.5.2 sandbox가 sibling capability를 부여하지 않아 `permissionDenied=3`이 됐지만, privacy-safe fallback으로 main document Preview를 유지했다.
- Thumbnail, HostApp WKWebView, renderer placeholder/diagnostic과 정식 fixture suite는 기존 후속 이슈의 책임으로 남겼다.

## 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/RhwpDocument.swift` | external image status/model/error, filename setter, refs query, key 기반 injection Swift wrapper |
| `Sources/Shared/HwpExternalImageResolver.swift` | open context/result, basename-only resolver, resolution/report/summary |
| `Sources/Shared/HwpPreviewPDFRenderer.swift` | file input → resolve/inject → metadata 순서와 resolved document context 재사용 |
| `Sources/QLExtension/HwpPreviewProvider.swift` | external resource state와 9개 summary count의 privacy-safe log |
| `Tests/ExternalImageTests/` | bridge 6개, resolver/security policy 18개 unit test |
| `project.yml` | 독립 `ExternalImageTests` target과 resolver source 선언 |
| `scripts/quicklook_skia_policy_smoke.swift` | source-level Preview smoke의 external state/count 출력 |
| `scripts/smoke-quicklook-skia-policy.sh` | resolver source compile 목록 추가 |
| `scripts/compare-quicklook-pdf-renderers.sh` | resolver source compile 목록 추가 |
| `mydocs/plans/task_m020_409.md` | 수행 범위와 책임 경계 |
| `mydocs/plans/task_m020_409_impl.md` | 5단계 구현·검증 계획 |
| `mydocs/working/task_m020_409_stage1.md` | Swift FFI wrapper 계약과 검증 |
| `mydocs/working/task_m020_409_stage2.md` | resolver와 security policy 검증 |
| `mydocs/working/task_m020_409_stage3.md` | Quick Look Preview 연결과 privacy-safe log |
| `mydocs/working/task_m020_409_stage4.md` | pinned fixture, registered Preview와 sandbox 제한 |
| `mydocs/report/task_m020_409_report.md` | 최종 계약, 검증, 잔여 위험과 handoff |
| `mydocs/orders/20260724.md` | #409 단계 진행 및 완료 상태 |

제품 Swift source의 최종 변경량은 `+642 / -20`이다. 이 중 `RhwpDocument.swift`가 `+149`, 신규 resolver가 `+441`, Preview renderer가 `+44 / -20`, provider가 `+8`이다. `ExternalImageTests`에는 test/support `+1,008`을 추가했다.

다음 영역은 변경하지 않았다.

- `RustBridge/**`
- `rhwp-ffi-symbols.txt`
- `rhwp-core.lock`
- `Frameworks/**`
- `Sources/ThumbnailExtension/**`
- `Sources/HostApp/Resources/rhwp-studio/**`
- entitlement와 source plist

`project.yml`을 Xcode project의 진실 원천으로 사용했다. 각 단계와 최종 검증에서 `xcodegen generate`를 실행했지만 생성된 `Alhangeul.xcodeproj/project.pbxproj`는 복원해 커밋하지 않았다.

## Swift와 FFI 계약

### Status mapping

`RhwpExternalImageOperationStatus`는 C enum의 raw value를 다음처럼 보존한다.

| C raw value | Swift |
|-------------|-------|
| `0` | `.ok` |
| `1` | `.invalidHandle` |
| `2` | `.invalidInput` |
| `3` | `.invalidUTF8` |
| `4` | `.referenceNotFound` |
| `5` | `.alreadyLoaded` |
| `6` | `.failure` |
| 그 외 | `.unknown(rawValue)` |

알 수 없는 값을 `.failure`로 합치지 않아 ABI가 additive하게 확장될 때 raw 의미를 잃지 않는다.

### External reference JSON

`rhwp_external_image_refs_json`의 array element를 `RhwpExternalImageReference`로 decode한다.

| JSON field | Swift property | 용도 |
|------------|----------------|------|
| `key` | `key` | injection과 final loaded verification |
| `binDataId` | `binDataId: UInt16` | reference metadata |
| `originalPath` | `originalPath` | metadata로만 decode하며 filesystem discovery에는 사용하지 않음 |
| `basename` | `basename` | 유일한 filesystem candidate 입력 |
| `extension` | `fileExtension` | 안전한 Swift property 이름으로 매핑 |
| `loaded` | `loaded` | initial skip와 final injection verification |

알 수 없는 additive field는 `JSONDecoder` 기본 동작으로 무시한다. 필수 field 누락, 타입 불일치, `UInt16` 범위 초과 또는 array가 아닌 root는 `.invalidReferencesJSON`으로 정규화한다. C 함수가 null을 반환하면 `.referencesUnavailable`로 구분한다.

### Pointer, 문자열과 handle 수명

- Swift `String`은 UTF-8 byte array로 변환하고 `withUnsafeBufferPointer` closure 안에서만 C pointer와 length를 사용한다.
- key, image `Data`, optional display path는 중첩 closure 안에서 한 번의 `rhwp_inject_external_image_by_key` 호출 동안만 빌린다.
- nil 또는 빈 display path는 `(nil, 0)`으로 전달한다.
- refs JSON의 non-null C string은 Swift `Data`로 즉시 복사한다.
- JSON pointer를 얻은 직후 `defer { rhwp_free_string(jsonPointer) }`를 등록해 decode 성공과 throw 양쪽에서 한 번 해제한다.
- `RhwpDocument`는 opaque handle을 소유하고 `deinit`에서 `rhwp_close`를 호출한다.
- main document와 external image caller-owned buffer는 FFI call 밖으로 노출하지 않는다. mutation 뒤 render는 document handle의 새 상태를 조회한다.

호출 순서는 다음으로 고정했다.

```text
rhwp_open
→ rhwp_set_file_name_utf8
→ refs JSON query/copy/free
→ sibling validate/read
→ key-based injection
→ refs JSON 재조회와 loaded 검증
→ page count/page size/render
```

## Basename-only resolver와 security policy

### 책임 경계

| 계층 | 책임 |
|------|------|
| `Sources/RhwpCoreBridge` | FFI model/wrapper와 handle 수명 |
| `Sources/Shared` | Foundation source context, filesystem policy, injection orchestration와 report |
| `Sources/QLExtension` | Quick Look request와 privacy-safe summary log |
| RustBridge/core | filename context, refs enumeration, explicit bytes injection과 render |

`Sources/RhwpCoreBridge`에는 filesystem 탐색과 AppKit/UIKit dependency를 추가하지 않았다. RustBridge/core도 product path에서 external file을 직접 열지 않는다.

### Candidate 제한

resolver가 filesystem candidate를 만드는 입력은 `reference.basename` 하나뿐이다. `originalPath`는 절대 경로, URL, Windows drive/UNC path 또는 basename 추출 원본으로도 사용하지 않는다.

다음 basename은 read 전에 `.rejectedInvalidBasename`으로 거부한다.

- empty
- `.`
- `..`
- `/` 포함
- `\` 포함
- NUL 포함

허용된 이름은 source document의 standardized parent에 단일 path component로 붙인다. source, parent와 candidate를 standardize하고 symlink를 resolve한 뒤 다음을 적용한다.

- source document 자신을 가리킴 → `.rejectedSourceDocument`
- resolved parent가 source parent 밖임 → `.rejectedOutsideSourceDirectory`
- regular file이 아님 → `.rejectedNonRegularFile`

따라서 directory, source self-reference와 sibling symlink를 통한 parent escape는 image read 전에 차단한다.

### Size, read와 failure taxonomy

external resource별 상한은 Quick Look main file 정책과 같은 50 MB다.

1. metadata `fileSize`가 상한을 넘으면 read 없이 `.tooLarge`
2. `.mappedIfSafe` read 후 실제 `Data.count`가 상한을 넘으면 injection 없이 `.tooLarge`

file error는 다음처럼 분류한다.

| Foundation/POSIX 결과 | Decision |
|-----------------------|----------|
| no-such-file, `ENOENT` | `.missing` |
| no-permission, `EACCES`, `EPERM` | `.permissionDenied` |
| 그 밖의 metadata/read 오류 | `.readFailed` |

underlying error가 더 구체적인 missing/permission 정보를 제공하면 그 분류를 보존한다. 한 reference가 실패해도 다음 reference를 계속 처리한다.

### Injection과 final loaded verification

검증을 통과한 sibling에 대해서만 upstream `key`, image bytes와 검증된 `basename` display path를 bridge에 전달한다.

- `.ok` → pending verification
- injection 시점 `.alreadyLoaded` → 경쟁 상태를 허용하고 `.alreadyLoaded`
- 나머지 status → `.bridgeRejected(status)`

모든 reference 처리 후 refs를 한 번 재조회한다. 같은 key가 `loaded == true`일 때만 `.injected(byteCount:)`를 유지하며, key 누락/false/final query failure는 `.verificationFailed`로 바꾼다.

### Privacy-safe report

reference report에는 key와 decision만 남기고 basename, `originalPath`, candidate URL, resolved absolute path를 저장하지 않는다. 제품 log는 다음 state/count만 기록한다.

- state
- total
- injected
- alreadyLoaded
- missing
- rejected
- tooLarge
- permissionDenied
- readFailed
- bridgeFailed

`.bridgeRejected`와 `.verificationFailed`는 `bridgeFailed`에 집계한다. external basename/path/key는 Quick Look provider log formatter에 전달하지 않는다.

## Quick Look Preview 적용 경계

`HwpPreviewPDFRenderer.load(fileURL:)`는 main file size/read 뒤 `RhwpDocumentOpenContext`를 만들고 resolver가 완료된 document에서만 page count와 first page size를 조회한다.

`HwpPreviewDocumentContext`가 같은 `RhwpDocument`를 소유하므로:

- single-page reply는 같은 context를 `HwpPreviewPNGRenderer`에 전달한다.
- multi-page reply는 같은 context를 `HwpPreviewPDFRenderer.render(context:)`에 전달한다.
- PDF의 모든 page는 같은 injected document handle로 render된다.

resolver 활성 범위는 source file URL을 보존한 Quick Look Preview open뿐이다.

| 경로 | Resolver |
|------|----------|
| QLExtension `HwpPreviewProvider` → `load(fileURL:)` | 활성 |
| `render(fileURL:)` | 활성 |
| `inspect(fileURL:)` | 비활성 |
| bytes-only `render(previewInfo:)` | 비활성 |
| HostApp PDF export | 비활성 |
| ThumbnailExtension | 비활성 |

source URL이 nil이면 `.disabledNoSourceURL`, file URL이 아니면 `.disabledNonFileURL`이고 refs query/read/injection을 실행하지 않는다.

## External fixture 통합 검증

fixture는 core pin과 같은 upstream commit `93862a4e16df59834ebce46d91e948cd739208e9`의 Cargo checkout에서 `build.noindex`로 복사했다.

| Fixture | SHA-256 |
|---------|---------|
| `hwp3-sample10-hwpx.hwpx` | `3395e19bebea8b6689f383df1f4ea1ddb253dee91c4320392cc40e90e2e4f191` |
| `oracle.gif` | `464e863dd2c1650fc6997b03a5d96c9413e61bbabaf7337c783db27203cc2761` |
| `rdb02.gif` | `bfadf4cdbbeeb5f3d8632cb54c8c3696977f405204b651f99a7a24c8f39532cf` |
| `s1.jpg` | `77dea18ce7f8f93b0931e133dec222aec642eef0ed87b8f2031b94dcbea5c514` |

### Source-level Preview

| Case | Total | Injected | Missing | Too large | Render |
|------|------:|---------:|--------:|----------:|--------|
| valid | 3 | 3 | 0 | 0 | CoreGraphics/SkiaDecode 각 764 pages, OK |
| missing | 3 | 2 | 1 | 0 | CoreGraphics/SkiaDecode 각 764 pages, OK |
| oversize | 3 | 2 | 0 | 1 | CoreGraphics/SkiaDecode 각 764 pages, OK |

valid case의 `alreadyLoaded=0`, `injected=3`과 final query 결과로 initial unloaded 3건이 이번 open에서 모두 loaded로 전환됐음을 확인했다. missing/oversize case도 reference 실패를 document-fatal error로 올리지 않고 764-page main render를 유지했다.

### Registered Quick Look

macOS 26.5.2(25F84)의 signed temporary app과 실제 active provider를 사용해 `qlmanage -p`와 Finder Space Preview를 실행했다.

다음 조합을 검사했다.

- 기존 read-only entitlement와 direct sibling read
- `NSFilePresenter`/`NSFileCoordinator` sibling별 접근
- same-stem main document/related image
- parent directory presenter/coordinator
- 작업지시자가 승인한 read-write entitlement 실험

모든 경우의 제품 log는 다음 결과로 수렴했다.

```text
Preview externalResource state=attempted total=3 injected=0 alreadyLoaded=0 missing=0 rejected=0 tooLarge=0 permissionDenied=3 readFailed=0 bridgeFailed=0
```

Foundation은 related-item sandbox extension과 file presenter sandbox extension을 발급하지 못했다. 현재 Quick Look host가 extension에 전달한 main document capability만으로는 sibling file capability를 파생할 수 없고, extension entitlement를 read-write로 넓히는 것만으로 이 capability가 추가되지 않았다.

작업지시자 승인으로 Stage 4 완료 조건을 다음처럼 조정했다.

- source-level 경로의 3건 injection과 render 성공을 구현 성립 근거로 사용한다.
- actual registered Preview에서는 `permissionDenied=3`의 privacy-safe graceful fallback과 main render 유지를 수용한다.
- sandbox 해제, broad folder entitlement, temporary absolute-path exception, unsandboxed broker와 사용자 folder authorization은 #409에 추가하지 않는다.

실험용 plist/entitlement/Foundation presenter 변경은 모두 복원했으며 제품 변경으로 남기지 않았다.

## 최종 검증 결과

### Core, shared boundary와 generated project

```bash
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
```

결과: 모두 통과.

- arm64/x86_64 universal static library와 XCFramework를 생성·검증했다.
- external image 3개를 포함한 총 15개 FFI symbol과 `rhwp-core.lock` 일치를 확인했다.
- shared Swift code의 AppKit/UIKit dependency가 없다.
- generated Xcode project는 검증 후 복원했다.
- CoreSimulator service 관련 출력은 macOS artifact 결과에 영향을 주지 않는 비차단 warning이다.

### ExternalImageTests

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ExternalImageTests \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409FinalTests \
  CODE_SIGNING_ALLOWED=NO \
  test
```

결과:

```text
HwpExternalImageResolverTests: 18 passed
RhwpDocumentExternalImageBridgeTests: 6 passed
Total: 24 tests, 0 failures
** TEST SUCCEEDED **
```

result bundle:

```text
build.noindex/DerivedDataTask409FinalTests/Logs/Test/
Test-ExternalImageTests-2026.07.28_15-31-54-+0900.xcresult
```

첫 sandbox 실행은 Sparkle package 조회 중 GitHub DNS 제한으로 exit 74가 발생했다. 네트워크 접근이 가능한 환경에서 같은 명령을 재실행해 compile/link와 24개 test가 통과했다. source 또는 assertion 실패는 없었다.

### HostApp build

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Final \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과: `** BUILD SUCCEEDED **` (`12.252 sec`).

HostApp과 embedded QLExtension/ThumbnailExtension dependency graph가 모두 compile/link됐다. 첫 sandbox 실행의 Sparkle DNS 제한은 test와 같은 환경 요인이며 동일 명령 재실행에서 통과했다.

### Renderer 회귀

```bash
./scripts/validate-stage3-render.sh build.noindex/task409-final-render
```

결과:

| Fixture | First page | Text runs | Hangul runs | Scalars | Non-white pixels |
|---------|------------|----------:|------------:|--------:|-----------------:|
| `KTX.hwp` | 1123×794 | 410 | 76 | 209 | 455,341 |
| `request.hwp` | 567×794 | 102 | 36 | 309 | 70,188 |
| `exam_kor.hwp` | 1123×1588 | 133 | 86 | 1,368 | 173,981 |

세 fixture 모두 page 1 render와 text/Hangul/non-white sanity를 통과했다. Stage 4에서는 embedded image와 HWPX를 포함한 5개 fixture 회귀도 별도로 통과했다.

### Registration hygiene와 diff

```bash
./scripts/check-extension-registration-hygiene.sh --check-only
git diff --check
git diff --exit-code -- RustBridge rhwp-ffi-symbols.txt rhwp-core.lock Frameworks
```

결과: 모두 통과.

- development registration, provider app root, legacy candidate와 issue가 없다.
- `build.noindex` 아래 Debug app은 존재하지만 등록되지 않은 검증 산출물이다.
- PlugInKit이 provider path를 보고하지 않은 warning만 있고 development registration 오염은 없다.
- core/FFI/framework tracked diff와 whitespace 오류가 없다.

## 단계 요약

| Stage | 커밋 | 요약 |
|-------|------|------|
| 수행계획 | `15f70da` | 범위, 책임 경계와 오늘할일 등록 |
| 구현계획 | `54da246` | 5단계 구현·검증 계획 |
| Stage 1 | `7b527e8` | Swift external image model과 FFI wrapper |
| Stage 2 | `f9fb735` | basename-only resolver와 privacy-safe report |
| Stage 3 | `3b8058c` | Quick Look Preview open flow와 summary log |
| Stage 4 | `0760013` | pinned fixture와 registered Preview 통합 검증 |
| Stage 5 | 이번 커밋 | 최종 보고서, 후속 handoff와 최종 검증 |

## 후속 이슈 handoff

| 이슈 | 남긴 책임 |
|------|-----------|
| #410 | `ImageNode.externalPath` decode, missing external/decode failure placeholder와 renderer diagnostic |
| #411 | Thumbnail prepared request, external resource cache signature와 resolver 활성화 |
| #412 | 라이선스·개인정보가 확인된 external/large fixture suite, visual/performance regression |
| #413 | HostApp WKWebView와 bundled `rhwp-studio` 사이 external bytes JS/native bridge |

#409는 Quick Look native Preview의 Swift wrapper/resolver와 open orchestration까지만 소유한다. 후속 이슈의 cache, renderer 표현, fixture vendoring과 WKWebView bridge를 미리 구현하지 않았다.

## 잔여 위험

| 항목 | 상태와 처리 |
|------|-------------|
| actual Quick Look sibling access | macOS 26.5.2에서 `permissionDenied=3`. main render fallback을 수용하며 broader authorization/broker 설계는 별도 이슈가 필요하다. |
| TOCTOU | standardize/symlink/metadata/read가 순차적이라 검사 사이 file 교체 가능성이 남는다. file-descriptor 기반 hardening은 후속 security 작업이다. |
| total memory | resource별 50 MB 상한은 있으나 document 전체 external resource 합계 상한은 없다. 다수 reference의 aggregate memory 정책은 후속 성능/보안 검토 대상이다. |
| refs JSON schema | additive field에는 안전하지만 필수 field 제거/타입 변경은 `.invalidReferencesJSON`이 된다. bridge failure report로 남고 main render는 계속된다. |
| Thumbnail | #411 전 resolver 비활성이다. current cache key가 sibling 변경을 반영하지 않으므로 조기 활성화하지 않는다. |
| HostApp/WKWebView | #413 전 external image 지원을 보장하지 않는다. bytes-only PDF export도 source context가 없어 resolver 비활성이다. |
| renderer 표현 | injection 실패 시 main render는 계속되지만 missing/decode placeholder와 세분화 diagnostic은 #410 범위다. |
| fixture 관리 | upstream fixture는 `build.noindex`에서만 사용했다. 정식 repository fixture 편입과 visual gate는 #412가 소유한다. |

## 결론

#409는 #408의 external image C ABI를 Swift에서 안전하게 소비하는 wrapper와 basename-only sibling resolver를 구현하고, Quick Look Preview open 순서에 연결했다. source-level pinned fixture에서는 3건 injection, final loaded 확인과 764-page render가 성공했고, missing/oversize는 non-fatal report로 분리됐다.

실제 registered Quick Look에서는 macOS sandbox가 sibling read capability를 제공하지 않는 플랫폼 제한이 확인됐다. 임의 entitlement 확대나 sandbox 우회는 제품 변경으로 남기지 않고, `permissionDenied` count와 main document graceful fallback을 현재 지원 계약으로 확정했다.

따라서 Swift/FFI/resolver/Preview orchestration 구현은 완료됐으며, 실제 sibling access를 가능하게 하는 별도 authorization 또는 broker 설계가 필요할 경우 #409와 분리해 보안 검토와 함께 진행해야 한다.

## 승인 요청

Stage 5 최종 보고서와 검증 결과의 승인을 요청한다. 승인 후 명시적으로 `task-final-report` 절차를 실행해 `publish/task409` push와 `devel` 대상 Open PR 게시를 진행한다.
