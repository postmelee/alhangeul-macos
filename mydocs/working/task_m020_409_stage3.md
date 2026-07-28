# Task M020 #409 Stage 3 보고서

## 단계 목적

Stage 3의 목적은 Stage 2에서 구현한 basename-only external image resolver를 Quick Look Preview의 실제 open 경로에 연결하고, resolver가 완료된 동일한 document handle을 single-page PNG와 multi-page PDF render가 재사용하게 하는 것이다.

제품 경로에서 남기는 진단은 external resource의 상태와 집계 count로 제한한다. external basename, 원본 path, candidate path, bridge key는 log와 smoke report에 기록하지 않는다. `inspect(fileURL:)`, bytes-only `render(previewInfo:)`, HostApp PDF export와 Thumbnail 경로는 source context가 없으므로 resolver 비활성 상태를 유지한다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `Sources/Shared/HwpPreviewPDFRenderer.swift` | Preview load를 input read, external resolve, preview metadata 조회 순서로 분리하고 context에 external report를 포함했다. 현재 224줄이다. |
| `Sources/QLExtension/HwpPreviewProvider.swift` | load 직후 external report의 state와 summary count만 한 번 기록한다. 현재 188줄이다. |
| `scripts/smoke-quicklook-skia-policy.sh` | source-level smoke compile 목록에 resolver source를 추가했다. 현재 81줄이다. |
| `scripts/quicklook_skia_policy_smoke.swift` | external state와 9개 summary count를 detail/summary 결과에 추가했다. 현재 662줄이다. |
| `scripts/compare-quicklook-pdf-renderers.sh` | PDF renderer compare compile 목록에 resolver source를 추가했다. 현재 77줄이다. |
| `mydocs/working/task_m020_409_stage3.md` | Stage 3 변경, 검증, 잔여 위험과 Stage 4 handoff를 기록한다. |
| `mydocs/orders/20260724.md` | #409를 Stage 3 완료 및 Stage 4 승인 대기 상태로 갱신한다. |

## 구현 결과

### Quick Look Preview open 순서

`HwpPreviewPDFRenderer.load(fileURL:)`의 순서를 다음처럼 명시적으로 분리했다.

1. main document의 file size를 확인해 기존 50 MB 상한을 적용한다.
2. main bytes를 `.mappedIfSafe`로 읽고 display filename을 보존한다.
3. source URL, display filename, external resource별 50 MB 상한으로 `RhwpDocumentOpenContext`를 만든다.
4. `HwpExternalImageResolver.open(data:context:)`로 main document를 열고 external reference query/read/injection/final verification을 마친다.
5. resolver가 반환한 document에서 page count와 first page size를 조회한다.
6. 같은 document와 external report를 `HwpPreviewDocumentContext`에 담는다.

따라서 filename setter와 external reference resolution이 page count/size 조회보다 먼저 완료된다. `render(fileURL:)`는 기존처럼 `load(fileURL:)`를 통하므로 resolver가 활성화된다.

### 동일 document handle 재사용

`HwpPreviewDocumentContext`는 resolver가 반환한 `RhwpDocument`와 page metadata를 함께 소유한다.

- single-page PNG reply는 context를 `HwpPreviewPNGRenderer`에 전달한다.
- multi-page PDF reply는 같은 context를 `HwpPreviewPDFRenderer.render(context:)`에 전달한다.
- PDF page loop는 context의 같은 document handle로 모든 page를 render한다.

resolver 이후 document를 다시 열지 않으므로 injected external image 상태가 reply 유형과 무관하게 유지된다.

### Resolver 활성·비활성 경계

| 경로 | Resolver | 근거 |
|------|----------|------|
| Quick Look `HwpPreviewProvider` → `load(fileURL:)` | 활성 | 실제 source file URL을 open context에 전달한다. |
| `render(fileURL:)` | 활성 | 내부에서 `load(fileURL:)`를 사용한다. |
| `inspect(fileURL:)` | 비활성 | bytes와 filename으로 `RhwpDocument`를 직접 열고 source context를 보존하지 않는다. |
| `render(previewInfo:)` | 비활성 | 보존된 bytes와 filename으로 document를 직접 다시 연다. |
| HostApp PDF export | 비활성 | `inspect`와 `render(previewInfo:)` 경로를 사용한다. |
| ThumbnailExtension | 비활성 | resolver open 호출을 추가하지 않았다. |

제품 source에서 `HwpExternalImageResolver.open` 호출은 `HwpPreviewPDFRenderer.load(fileURL:)` 한 곳뿐이며, 실제 제품 caller는 QLExtension의 `HwpPreviewProvider` 한 곳이다.

### Privacy-safe provider log

`HwpPreviewProvider`는 `load` 성공 직후 report를 한 번 log한다. 추가한 field는 다음 값뿐이다.

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

external basename, original path, candidate/resolved URL, reference key는 log formatter에 전달하지 않는다. 기존 main document filename 진단은 변경하지 않았다.

### Source-level smoke report

`quicklook_skia_policy_smoke.swift`의 file measurement에 external state와 summary를 추가했다.

- summary table에 state와 9개 count column을 추가했다.
- fixture별 detail file에도 같은 state/count를 기록한다.
- console summary는 `external={state}:{total}`만 추가한다.
- external path, basename, key는 결과 형식에 추가하지 않았다.

`HwpPreviewPDFRenderer`가 resolver source를 참조하게 됐으므로 다음 두 standalone `swiftc` helper의 compile 목록에 `HwpExternalImageResolver.swift`를 추가했다.

- `smoke-quicklook-skia-policy.sh`
- `compare-quicklook-pdf-renderers.sh`

## 본문 변경 정도 / 본문 무손실 여부

- `HwpPreviewPDFRenderer`의 기존 file-size 상한, mapped data read, empty-document 검사, first-page size 검사와 PDF page render 본문을 보존했다.
- 기존 `loadDocument` 책임을 `loadInput`과 `previewMetadata`로 분리해 resolver 호출 순서를 사이에 배치했다.
- single-page PNG와 multi-page PDF reply 선택 및 render 정책을 변경하지 않았다.
- `inspect(fileURL:)`와 `render(previewInfo:)`는 의도적으로 resolver를 사용하지 않으며 기존 bytes-only 동작을 보존했다.
- `Sources/RhwpCoreBridge`, Rust FFI, RustBridge header, `Rhwp.xcframework`, `rhwp-core.lock`, entitlement와 `project.yml`은 변경하지 않았다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 또는 filesystem resolver 정책을 추가하지 않았다.
- `xcodegen generate`로 검증한 `Alhangeul.xcodeproj/project.pbxproj`는 복원했으며 커밋하지 않는다.
- Stage 3는 실제 Quick Look 등록, Finder preview 요청, pinned external fixture 복사를 수행하지 않았다. 해당 범위는 승인 후 Stage 4에서 수행한다.

## 검증 결과

### Rust artifact와 lock

```bash
./scripts/build-rust-macos.sh --verify-lock
```

결과: 통과.

- x86_64와 arm64 macOS artifact를 다시 검증했다.
- external image setter/query/injection symbol을 포함한 C ABI surface를 확인했다.
- `Rhwp.xcframework` 생성과 `rhwp-core.lock` 일치를 확인했다.
- Xcode의 simulator destination 관련 안내는 macOS artifact 결과에 영향을 주지 않는 비차단 warning이었다.

### Shared boundary와 Xcode project 생성

```bash
./scripts/check-no-appkit.sh
xcodegen generate
```

결과: 모두 통과.

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

생성된 Xcode project diff는 검증 후 복원했다.

### ExternalImageTests

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ExternalImageTests \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Stage3Tests \
  CODE_SIGNING_ALLOWED=NO \
  test
```

결과: 통과.

```text
Test Suite 'HwpExternalImageResolverTests' passed
Executed 18 tests, with 0 failures
Test Suite 'RhwpDocumentExternalImageBridgeTests' passed
Executed 6 tests, with 0 failures
Test Suite 'All tests' passed
Executed 24 tests, with 0 failures
** TEST SUCCEEDED **
```

test result bundle:

```text
build.noindex/DerivedDataTask409Stage3Tests/Logs/Test/
Test-ExternalImageTests-2026.07.24_23-31-19-+0900.xcresult
```

첫 sandbox 실행은 Sparkle package 조회 중 GitHub DNS 제한으로 중단됐다. 네트워크 접근이 가능한 동일 명령으로 재실행해 compile/link와 24개 test가 통과했다. source 또는 assertion 실패는 없었다.

test target deployment target과 XCTest minimum version 차이, AppIntents metadata 부재 안내는 기존 비차단 warning이며 test 결과에 영향을 주지 않았다.

### 제품 target build

다음 세 명령을 `CODE_SIGNING_ALLOWED=NO`로 실행했다.

```bash
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
```

결과: HostApp, QLExtension, ThumbnailExtension 모두 `** BUILD SUCCEEDED **`.

### 계획된 Quick Look source-level smoke

```bash
./scripts/smoke-quicklook-skia-policy.sh \
  build.noindex/task409-stage3-quicklook \
  samples/basic/request.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
```

결과: 통과.

| Fixture | Load | Reply | Pages | External state | 9개 summary count |
|---------|------|-------|-------|----------------|-------------------|
| `request.hwp` | OK | png | 1 | attempted | 모두 0 |
| `hwp-multi-001.hwp` | OK | pdf | 9 | attempted | 모두 0 |
| `hwpx-01.hwpx` | OK | pdf | 9 | attempted | 모두 0 |

세 fixture 모두 external refs가 없어 `total=0`이며 injected, alreadyLoaded, missing, rejected, tooLarge, permissionDenied, readFailed, bridgeFailed도 0이다. 기존 PNG/PDF reply shape, page count, CoreGraphics/Skia backend와 fallback 결과를 보존했다.

결과 파일:

```text
build.noindex/task409-stage3-quicklook/summary.txt
build.noindex/task409-stage3-quicklook/*-quicklook-skia-policy.txt
```

### 변경된 PDF compare helper smoke

compile 목록 변경을 별도로 확인하기 위해 다음 명령도 실행했다.

```bash
./scripts/compare-quicklook-pdf-renderers.sh \
  build.noindex/task409-stage3-compare \
  samples/basic/request.hwp
```

결과: 통과.

```text
request.hwp: OK, pages=1, currentReply=png, nativePDFPages=1
```

결과 파일:

```text
build.noindex/task409-stage3-compare/summary.txt
```

### 활성 경계, privacy와 등록 위생

```bash
rg -n "HwpExternalImageResolver\.open|externalResourceReport|externalResourceState|alreadyLoaded|permissionDenied|bridgeFailed" \
  Sources/QLExtension Sources/Shared scripts/quicklook_skia_policy_smoke.swift
rg -n "HwpPreviewPDFRenderer\.(load|inspect|render)" Sources Tests scripts
./scripts/check-extension-registration-hygiene.sh --check-only
```

결과: 통과.

- resolver open은 `HwpPreviewPDFRenderer.load(fileURL:)` 한 곳에만 있다.
- QLExtension은 `load(fileURL:)`, HostApp export는 disabled인 `inspect`/`render(previewInfo:)`를 사용한다.
- provider와 smoke에는 state/count field만 추가됐고 external basename/path/key는 없다.
- 등록 위생 검사에서 development registration, provider app root, legacy candidate와 issue가 모두 없었다.
- `build.noindex` 아래 세 Debug app bundle은 존재하지만 등록되지 않은 산출물이다. 따라서 등록 해제 작업은 수행할 대상이 없었다.

### 최종 변경 점검

```bash
bash -n \
  scripts/smoke-quicklook-skia-policy.sh \
  scripts/compare-quicklook-pdf-renderers.sh
git diff --check
git status --short
```

결과: 통과.

- shell helper 두 개의 syntax 오류가 없다.
- whitespace 오류가 없다.
- 생성된 Xcode project와 framework 변경은 목록에 남지 않았다.
- 변경 범위는 Stage 3 Preview 연결, provider log, smoke helper, 단계 보고서와 오늘할일로 한정된다.

## 잔여 위험

- no-external fixture는 resolver 호출과 report shape를 검증하지만 실제 FFI injection의 `loaded: false → true` 전이를 증명하지 않는다. pinned upstream external fixture를 사용하는 검증은 Stage 4가 수행한다.
- 실제 Quick Look extension sandbox에서 source document sibling image read가 허용되는지는 등록된 extension을 통해 확인해야 한다.
- provider의 privacy-safe OSLog는 source와 build 수준에서 확인했다. 실제 등록 Preview 요청에서 state/count가 한 번 기록되는지는 Stage 4에서 확인한다.
- external image가 single-page PNG와 multi-page PDF 출력에 실제 반영되는지는 Stage 4의 valid/missing/oversize fixture matrix와 output inspection으로 확인한다.
- ThumbnailExtension과 HostApp는 의도적으로 resolver 비활성이다. 해당 제품에도 external image가 필요해지면 별도 issue에서 source-context 계약과 sandbox 정책을 설계해야 한다.

## 다음 단계 영향

Stage 4는 이번 단계에서 연결한 Preview open 경로를 실제 pinned external fixture와 등록된 QLExtension에서 검증한다.

- pinned upstream commit과 fixture checksum/구성을 확인한다.
- valid sibling image, missing sibling, oversize sibling matrix를 `build.noindex`에 준비한다.
- source-level resolver report로 injection/loaded 상태와 non-fatal 실패 분류를 확인한다.
- signed Debug app과 QLExtension을 표준 smoke 절차로 등록해 Finder/Quick Look Preview를 요청한다.
- actual provider log가 state/count만 기록하는지 확인한다.
- PNG/PDF 결과와 external image 반영 여부를 검사한다.
- smoke 종료 후 개발용 Quick Look/Thumbnail 등록을 해제하고 등록 위생을 다시 확인한다.

## 승인 요청

Stage 3 `Quick Look Preview open flow와 privacy-safe log 연결`은 완료됐다. Stage 4 `Pinned external fixture와 registered Preview 통합 검증`으로 진행하려면 작업지시자 승인이 필요하다.
