# Task M020 #447 구현계획서

수행계획서: `mydocs/plans/task_m020_447.md`

이 문서는 Stage 1 조사 결과를 바탕으로 `rhwp_image_data`의 ownership 계약과
단계별 변경·검증 방법을 확정한다. 구현계획서 승인 전에는 RustBridge, Swift
caller, generated artifact와 Finder 등록 상태를 변경하지 않는다. 승인 후
Stage 1은 `task-stage-report` 절차로 조사 결과와 구현계획서를 묶어 종료하고,
Stage 2 진입은 단계 보고서에서 다시 승인받는다.

## 작업 개요

- 이슈: #447 `rhwp v0.8.2 반영 후 RustBridge image data 수명 회귀와 Thumbnail 크래시 수정`
- 마일스톤: M020 (`v0.2.x Skia Quick Look/Thumbnail Backend`)
- 기준 브랜치: `devel`
- 작업 브랜치: `local/task447`
- 기준 통합 SHA: `1b1213db5a0bd75638f54bf03d49fbf4cb63edcc`
- upstream 기준: `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c`
- 차단 대상: #441 이슈의 v0.1.9 public release
- 변경 소유 영역: app-owned RustBridge C ABI와 Swift `RhwpDocument` wrapper

## Stage 1 조사 결론

### 확인된 사실

| 항목 | 확인 결과 | 판단 |
|------|-----------|------|
| upstream API | `DocumentCore::get_bin_data(&self, index)`가 `Option<Vec<u8>>` 반환 | caller에게 소유값을 전달하는 것이 v0.8.2 공개 계약이다. |
| 변경 이유 | upstream Task #2263의 lazy BinData는 bytes를 빌려줄 수 없어 owned `Vec`를 반환 | downstream이 borrowed pointer로 되돌리려면 별도 장기 저장소가 필요하다. |
| 현재 bridge | `Some(data) => data.as_ptr()` 뒤 함수 종료 | 반환 직후 `Vec` drop으로 pointer가 무효화된다. |
| Swift copy | `rhwp_image_data` 반환 뒤 `Data(bytes:count:)` 실행 | 복사 시점이 Rust 함수 종료 뒤라 use-after-free다. |
| crash 증거 | v0.1.9 build 15에서 두 번 `EXC_BAD_ACCESS`, `_platform_memmove → Data.InlineSlice → RhwpDocument.imageData` | 이론상 위험이 아니라 signed candidate에서 재현된 release blocker다. |
| 기존 byte 해제 ABI | `rhwp_free_bytes(uint8_t *, uintptr_t)` 존재 | 새 free symbol 없이 owned byte contract를 제공할 수 있다. |
| 기존 구현 패턴 | thumbnail/Skia PNG는 `Vec → Box<[u8]> → forget → rhwp_free_bytes` 사용 | 검증된 저장소 내 ownership 패턴을 재사용할 수 있다. |
| C symbol lock | `rhwp_image_data`, `rhwp_free_bytes`가 이미 고정 | symbol 추가·삭제 없이 수정 가능하다. |
| generated header | 현재 `rhwp_image_data`가 `const uint8_t *` 반환 | owned contract에서는 `uint8_t *`로 source signature가 명확해져야 한다. |
| Swift caller | `RhwpDocument.imageData`, `imageDataLength` 두 wrapper가 직접 호출 | 모든 product caller를 한 곳에서 free-safe하게 바꿀 수 있다. |
| renderer cache | `CGTreeRenderer`가 decode된 `CGImage`를 `binDataId`별 cache | bridge raw bytes cache는 정상 render에서 중복 보유가 된다. |
| fixture | `samples/복학원서.hwp`는 id 1·2 embedded image와 기존 byte-count 기록이 있음 | 작고 결정적인 Rust/Swift lifetime fixture로 사용한다. |
| Finder 실행 경계 | crash queue가 `com.postmelee.alhangeul.thumbnail-render` | Thumbnail exact-provider 반복 smoke가 필수다. |

### 대안 비교와 선택

| 대안 | 장점 | 문제 | 판단 |
|------|------|------|------|
| A. `RhwpHandle` stable cache | 기존 const pointer source contract 유지 | lazy BinData 원본 외 raw bytes를 handle 종료까지 중복 보유하고 interior mutability·mutation invalidation 계약이 추가됨 | 제외 |
| B. 신규 `rhwp_image_data_copy` 추가 | 기존 borrowed symbol을 그대로 보존 | 안전하지 않은 기존 symbol이 계속 남고 ABI/test/document 경로가 이중화됨 | 제외 |
| C. 기존 `rhwp_image_data`를 caller-owned buffer로 전환 | upstream owned `Vec`와 일치, 즉시 free 가능, 새 symbol 없음 | Swift 두 wrapper와 ownership 문서를 함께 바꿔야 함 | 채택 |

수행계획서의 기본안은 handle-owned 안정 저장소였지만, Stage 1 조사에서
`CGTreeRenderer`가 이미 decoded image를 cache하고 있고 upstream lazy loading
자체가 장기 raw-byte 보유를 피하기 위한 변경임을 확인했다. handle cache는
특히 multi-page Quick Look과 large BinData에서 image 원본 크기만큼의 bridge
복사본을 문서 handle 종료까지 유지한다. 반면 기존 `rhwp_free_bytes` 경로를
사용하면 Swift `Data` 복사 직후 raw allocation을 회수할 수 있다.

따라서 대안 C를 구현안으로 확정한다. 반환 pointer의 const/mut 구분은 C
machine ABI에서 같은 pointer representation이고 symbol 이름과 인자 목록도
유지된다. 다만 generated C header와 Swift imported type은 달라지므로
RustBridge, generated header, Swift wrapper와 test를 항상 같은 build에서
검증한다. 별도 배포 SDK나 dynamic library 호환을 전제로 하지 않고 앱의
static XCFramework를 세 target과 함께 재빌드한다.

## 확정 ownership 계약

### Rust C ABI

```rust
#[no_mangle]
pub extern "C" fn rhwp_image_data(
    handle: *const RhwpHandle,
    bin_data_id: u16,
    out_len: *mut usize,
) -> *mut u8
```

성공 계약:

1. core가 반환한 non-empty `Vec<u8>`를 `Box<[u8]>`로 바꿔 allocation 크기를
   `len`에 맞춘다.
2. `as_mut_ptr()`와 length를 caller에게 전달하고 box는 `forget`한다.
3. pointer는 `rhwp_free_bytes(pointer, len)` 호출 전까지 유효하다.
4. pointer allocation은 document handle과 독립이므로 handle close가 먼저
   일어나더라도 explicit free 전까지 bytes는 유효하다.
5. caller는 정확히 한 번, 반환받은 동일 pointer와 length로 free해야 한다.

실패 계약:

- null handle
- null `out_len`
- `bin_data_id == 0`
- core lookup 실패
- empty bytes
- panic

`out_len`이 non-null이면 함수 시작 시 0으로 초기화한다. 실패에서는 null
pointer와 length 0을 반환한다. panic은 FFI 경계 밖으로 전파하지 않고 null/0으로
격리한다.

`rhwp_free_bytes(null, len)`은 no-op이다. non-null pointer에는 반드시
`rhwp_image_data`, `rhwp_render_page_png`, `rhwp_extract_thumbnail` 등 같은
RustBridge가 반환한 pointer와 정확한 length만 전달한다.

### Swift wrapper

`RhwpDocument.imageData(binDataId:)`는 다음 구조를 사용한다.

```swift
var length = 0
guard let pointer = rhwp_image_data(handle, binDataId, &length),
      length > 0 else {
    return nil
}
defer {
    rhwp_free_bytes(pointer, length)
}
return Data(bytes: pointer, count: length)
```

`imageDataLength(binDataId:)`도 query가 owned allocation을 반환하므로
pointer를 사용하지 않더라도 같은 `defer` free를 수행한다. `hasImageData`는
기존처럼 `imageDataLength`를 사용해 의미를 유지한다.

Swift가 반환하는 `Data`는 독립 복사본이다. 따라서 `RhwpDocument` deinit과
Rust allocation free 뒤에도 유효하다. pointer나 `UnsafeBufferPointer`를 Swift
객체에 저장하지 않는다.

## 회귀 테스트 확정안

### Rust unit test

`RustBridge/src/lib.rs`의 기존 test module에 다음을 추가한다.

1. `open_fixture_at(relative_path:)` helper로
   `samples/복학원서.hwp`를 연다.
2. `bin_data_id = 1`에서 non-null pointer와 non-zero length를 확인한다.
3. 첫 allocation을 즉시 복사해 expected bytes를 만들고 free한다.
4. 두 번째 allocation을 받은 뒤 다른 크기의 `Vec` allocation을 반복 생성해
   allocator pressure를 만든다.
5. pressure 뒤 pointer bytes를 expected와 비교하고 free한다.
6. 같은 id의 두 allocation을 동시에 유지하고 한쪽을 free한 뒤에도 다른 쪽
   bytes가 유지되는지 확인한다.
7. image pointer를 받은 뒤 handle을 close하고, bytes 비교 뒤 pointer를
   free해 allocation이 handle과 독립임을 확인한다.
8. null handle, id 0, lookup 불가 id에서 null/0을 확인한다.

test code는 pointer를 `from_raw_parts`로 읽을 때 free 전인지 명시하고,
각 성공 pointer는 test 종료 경로에서 정확히 한 번 해제한다. panic으로 test가
중간 종료될 때 leak은 process 종료로 회수되지만, 정상·assertion 전 순서에서
가능한 한 RAII test wrapper를 사용한다.

### Swift `ExternalImageTests`

기존
`Tests/ExternalImageTests/RhwpDocumentExternalImageBridgeTests.swift`에
다음을 추가한다.

1. `samples/복학원서.hwp`에서 image id 1의 `Data`와 length가 일치한다.
2. 같은 id를 반복 조회해 bytes가 동일하다.
3. 중간에 여러 `Data` allocation을 만들어도 결과가 동일하다.
4. document scope 밖으로 반환한 copied `Data`가 유지된다.
5. id 0과 lookup 불가 id가 nil이다.
6. 기존 external refs/injection 6개 test가 그대로 통과한다.

새 test target이나 source 구성은 만들지 않는다. 기존
`ExternalImageTests` target이 `RhwpDocument.swift`, sample helper와
`Rhwp.xcframework`를 이미 포함하므로 `project.yml`은 변경하지 않는다.

## Stage 1. Ownership 계약과 구현 경계 확정

### 목표

signed candidate crash 증거, upstream API, bridge/Swift caller와 fixture를
대조해 위 owned-buffer 계약과 단계별 작업 범위를 승인 가능한 상태로 고정한다.

### 대상

- `mydocs/plans/task_m020_447_impl.md`
- `mydocs/working/task_m020_447_stage1.md`
- `mydocs/orders/20260729.md`

### 작업

1. upstream v0.8.2 `get_bin_data` 반환형과 변경 사유를 기록한다.
2. 현재 `rhwp_image_data → Data(bytes:count:)`의 drop/copy 순서를 기록한다.
3. 두 crash report의 exact version, queue와 대표 stack을 교차 확인한다.
4. handle cache, 신규 copy symbol, 기존 symbol owned 전환을 비교한다.
5. existing free ABI와 Swift caller 수를 확인해 대안 C를 확정한다.
6. `samples/복학원서.hwp`의 기존 image id 1·2 기록을 test fixture 근거로
   고정한다.
7. Stage 2~5의 파일, 검증, 중단 조건과 커밋 메시지를 확정한다.

### 검증

```bash
rg -n "pub fn get_bin_data|Option<Vec<u8>>|지연 로딩" \
  /Users/melee/Documents/projects/forks/rhwp/src/document_core/queries/rendering.rs
rg -n "rhwp_image_data|rhwp_free_bytes|imageData\\(|imageDataLength" \
  RustBridge/src/lib.rs \
  Frameworks/generated_rhwp.h \
  Sources/RhwpCoreBridge/RhwpDocument.swift \
  rhwp-ffi-symbols.txt
rg -n "binDataId|byteCount" \
  mydocs/working/task_m014_116_stage1.md
rg -n "_platform_memmove|Data.InlineSlice|RhwpDocument.imageData|thumbnail-render" \
  ~/Library/Logs/DiagnosticReports/AlhangeulThumbnail-2026-07-29-171601.ips \
  ~/Library/Logs/DiagnosticReports/AlhangeulThumbnail-2026-07-29-171610.ips
rg -n "owned-buffer|rhwp_free_bytes|Stage 2|Stage 3|Stage 4|Stage 5" \
  mydocs/plans/task_m020_447_impl.md
git diff --check
```

### 완료 조건

- 임시 `Vec` pointer escape가 직접 원인임이 코드와 crash stack으로 연결된다.
- caller-owned buffer/free 계약이 단일 구현안으로 고정된다.
- symbol 추가 없이 generated header와 Swift caller를 함께 바꾸는 경계가
  명시된다.
- Rust와 Swift가 공유할 fixture 및 lifetime test matrix가 확정된다.
- Stage 2 진입 전 RustBridge와 Swift source에는 변경이 없다.

### 커밋

```text
Task #447 Stage 1: image data ownership 계약과 구현 경계 확정
```

## Stage 2. RustBridge owned image buffer와 unit test

### 목표

`rhwp_image_data`가 유효한 caller-owned allocation을 반환하도록 수정하고,
allocator pressure와 handle lifetime을 포함한 Rust 회귀 test로 계약을
고정한다.

### 대상

- `RustBridge/src/lib.rs`
- `mydocs/working/task_m020_447_stage2.md`
- `mydocs/orders/20260729.md`

### 작업

1. `rhwp_image_data` 반환형을 `*mut u8`로 변경한다.
2. out length를 query 시작 시 0으로 초기화한다.
3. core lookup과 owned allocation 전환을 `catch_unwind` 경계 안에 둔다.
4. empty bytes는 allocation을 넘기지 않고 null/0으로 정규화한다.
5. non-empty `Vec`는 `Box<[u8]>`로 바꾼 뒤 pointer/length를 반환한다.
6. `rhwp_free_bytes`와 같은 allocation layout을 사용한다.
7. `open_fixture_at`과 owned image lifetime test를 추가한다.
8. invalid input, repeated simultaneous allocation, handle close 전후와
   allocator pressure matrix를 실행한다.
9. 기존 external context와 rendering test를 모두 유지한다.

### 검증

```bash
cargo fmt --manifest-path RustBridge/Cargo.toml --check
cargo check --manifest-path RustBridge/Cargo.toml --locked
cargo test --manifest-path RustBridge/Cargo.toml --locked
rg -n "rhwp_image_data|into_boxed_slice|rhwp_free_bytes|복학원서|allocator|pressure" \
  RustBridge/src/lib.rs
git diff --check -- RustBridge/src/lib.rs mydocs
```

### 완료 조건

- `rhwp_image_data`가 임시 Vec pointer를 반환하지 않는다.
- 성공 pointer는 explicit free 전까지 유효하고 handle lifetime과 독립이다.
- 모든 성공 test allocation이 정확히 한 번 해제된다.
- null/zero/missing/panic 경로가 null/0으로 정규화된다.
- 전체 locked Rust test가 통과한다.

### 커밋

```text
Task #447 Stage 2: RustBridge image data ownership 회귀 수정
```

## Stage 3. Swift free 계약, 문서와 artifact 정합성

### 목표

Swift caller가 owned pointer를 모든 경로에서 해제하게 하고, generated header,
static archive, lock metadata와 ownership 문서를 같은 source 상태로 맞춘다.

### 대상

- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `Tests/ExternalImageTests/RhwpDocumentExternalImageBridgeTests.swift`
- `RustBridge/README.md`
- `mydocs/tech/project_architecture.md`
- `rhwp-core.lock`
- `mydocs/working/task_m020_447_stage3.md`
- `mydocs/orders/20260729.md`

### 작업

1. `imageData`가 `defer rhwp_free_bytes` 뒤 Swift `Data`를 반환하게 한다.
2. `imageDataLength`도 pointer를 즉시 free하게 한다.
3. document deinit 뒤 copied Data, 반복 query와 invalid id Swift test를 추가한다.
4. RustBridge README의 image data ownership과 current v0.8.2 provenance를
   실제 lock에 맞춘다.
5. project architecture의 borrowed document buffer 설명을 caller-owned
   allocation/free 계약으로 갱신한다.
6. Rust static archive와 generated header를 재생성한다.
7. generated header가 `uint8_t *rhwp_image_data`를 제공하는지 확인한다.
8. symbol 목록이 기존 15개와 byte-identical한지 확인한다.
9. `rhwp-core.lock`의 archive/header hash, size와 built_at만 갱신하고
   core tag/commit/features는 유지한다.
10. `project.yml`과 `Alhangeul.xcodeproj`에는 Task #447 diff가 없는지 확인한다.

### 검증

```bash
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/verify-rhwp-core-build-info.sh
diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
rg -n "uint8_t \\*rhwp_image_data|rhwp_free_bytes" \
  Frameworks/generated_rhwp.h
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ExternalImageTests \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task447-stage3-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
git diff --exit-code -- project.yml Alhangeul.xcodeproj/project.pbxproj
git diff --check
```

### 완료 조건

- Swift의 두 image data wrapper가 성공 allocation을 항상 free한다.
- copied Data가 document와 Rust allocation lifetime에서 독립이다.
- ExternalImageTests 전체가 통과한다.
- generated header는 owned mutable pointer contract를 나타낸다.
- FFI symbol 목록과 core tag/commit/features는 변하지 않는다.
- lock metadata와 ownership 문서가 새 artifact와 일치한다.

### 커밋

```text
Task #447 Stage 3: Swift image buffer 해제와 ABI 문서 정합성 반영
```

## Stage 4. 제품 target과 Finder Thumbnail crash 회귀 검증

### 목표

수정 artifact를 사용하는 App, Preview, Thumbnail을 build하고 renderer 및
exact-provider Finder 반복 smoke에서 신규 crash가 발생하지 않는지 확인한다.

### 자동 build와 renderer 검증

```bash
cargo test --manifest-path RustBridge/Cargo.toml --locked
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task447-stage4-host \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task447-stage4-ql \
  CODE_SIGNING_ALLOWED=NO \
  build
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ThumbnailExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task447-stage4-thumbnail \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/validate-stage3-render.sh
./scripts/preview-visual-diff-harness.sh \
  build.noindex/task447-stage4-images \
  --page 1 \
  samples/복학원서.hwp \
  samples/hwp-img-001.hwp \
  samples/img-start-001.hwp \
  samples/hwpx/hwpx-01.hwpx
```

### Finder/package 검증

Stage 4 진입 시 다음 상태를 먼저 보고한다.

- 사용할 candidate app absolute path, version/build와 code-sign identity
- 현재 `/Users/melee/Applications/Alhangeul.app` 존재 여부와 backup 경로
- active Preview/Thumbnail provider 목록
- 기존 두 crash report와 Stage 4 시작 시각
- smoke 후 candidate unregister와 사용자 설치본 복원 절차

사용자 Applications와 extension registration을 바꾸는 실제 smoke, package
signing 또는 release workflow는 작업지시자의 명시 승인 뒤에만 실행한다.
승인되면 표준 helper를 사용한다.

```bash
scripts/check-extension-registration-hygiene.sh --check-only
scripts/smoke-finder-integration.sh \
  --skip-package \
  --app build.noindex/release/Alhangeul.app \
  --output-dir build.noindex/task447-stage4-finder \
  --sample-hwp samples/복학원서.hwp \
  --sample-hwpx samples/hwpx/hwpx-01.hwpx
```

표준 smoke 뒤 Finder 또는 save panel에서 image-heavy sample 폴더를 반복
표시한다. 다음을 함께 확인한다.

- 실제 Thumbnail process가 candidate appex path에서 실행됨
- `복학원서.hwp`, `hwp-img-001.hwp`, `img-start-001.hwp`, HWPX thumbnail 생성
- 반복 cache miss/reload 뒤에도 thumbnail 생성
- Stage 4 시작 시각 이후 신규 `AlhangeulThumbnail-*.ips` 없음
- candidate unregister와 이전 app/provider 복원
- 개발 산출물 provider 잔존 없음

### 완료 조건

- Rust, ExternalImageTests와 세 제품 target이 모두 통과한다.
- image-heavy renderer harness에 crash/FAIL이 없다.
- exact candidate provider가 HWP/HWPX thumbnail을 반복 생성한다.
- Stage 4 baseline 이후 신규 Thumbnail crash report가 없다.
- smoke 종료 뒤 사용자 설치본과 provider가 원래 상태로 복원된다.
- signing/notarization/GitHub workflow를 승인 없이 실행하지 않는다.

### 커밋

```text
Task #447 Stage 4: image-heavy Thumbnail crash 회귀 검증
```

## Stage 5. 최종 보고, PR 게시와 #441 인계

### 작업

1. 선택한 ownership 계약, source/header 차이와 memory trade-off를 최종
   보고서에 기록한다.
2. Rust/Swift test, artifact provenance, target build, renderer와 Finder
   exact-provider 결과를 정리한다.
3. #441 이슈에 전달할 fix commit, PR/merge SHA와 candidate 재생성 조건을
   명시한다.
4. `task-final-report` 절차로 오늘할일 완료, 최종 커밋,
   `publish/task447` push와 `devel` 대상 ready PR을 생성한다.
5. PR CI에서 Rust locked test, ABI/provenance, ExternalImageTests와 macOS
   target gate를 확인한다.
6. merge는 작업지시자의 별도 승인을 기다린다.
7. merge 뒤 #441 이슈는 이전 v0.1.9 draft artifact를 재사용하지 않고 새 merge
   SHA가 포함된 signed candidate를 별도 release 승인으로 생성한다.

Task #447은 release source crash 수정과 package regression까지만 소유한다.
v0.1.9 tag 처리, GitHub Release publish, Pages/Sparkle와 Homebrew는 #441
이슈가 소유한다.

### 완료 조건

- 최종 보고서와 PR body가 Issue #447 범위와 검증 결과를 일치하게 설명한다.
- `devel` 대상 ready PR의 필수 CI가 통과한다.
- 기존 unsafe borrowed-pointer 설명이 source와 문서에 남지 않는다.
- #441 이슈가 새 merge SHA로 candidate를 재생성할 충분한 handoff를 받는다.

## 중단·재승인 조건

- `rhwp_image_data` pointer mutability 변경으로 예상 밖의 C/Swift caller가
  compile되지 않음
- 기존 `rhwp_free_bytes`가 `Box<[u8]>` allocation을 정확히 해제하지 못함
- caller-owned contract에서 symbol 추가 또는 dependency 변경이 필요함
- `RustBridge/Cargo.toml`, `Cargo.lock`, core tag/commit/features 변경이 필요함
- `project.yml` 또는 Xcode target 구성 변경이 필요함
- `imageDataLength`의 full bytes load가 별도 metadata ABI 없이는 허용할 수 없는
  memory 회귀로 측정됨
- source test는 통과하지만 image-heavy renderer/Finder에서 crash가 재현됨
- active provider exact path를 확정할 수 없어 Finder 결과가 모호함
- 사용자 설치본을 안전하게 backup/복원할 수 없음
- release tag, signing/notarization 또는 GitHub workflow 변경이 필요함

이 조건 중 하나가 발생하면 관련 범위를 임의로 확장하지 않고 실패 증거,
영향과 최소 대안을 보고해 수행·구현계획 수정 또는 release owner 승인을
요청한다.
