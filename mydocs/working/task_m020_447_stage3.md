# Task M020 #447 Stage 3 완료보고서

## 단계 목적

Stage 2에서 caller-owned allocation으로 전환한 `rhwp_image_data`를 Swift
caller가 모든 성공 경로에서 정확히 한 번 해제하도록 수정한다. 같은 Rust
source 상태로 static archive, generated header와 XCFramework를 다시 만들고,
artifact lock·ownership 문서·Swift 회귀 test를 함께 맞춘다.

Stage 3은 Swift wrapper, 기존 `ExternalImageTests`, ownership 문서와 생성
artifact 정합성까지 소유한다. 제품 target build와 Finder exact-provider 반복
smoke는 Stage 4에서 수행한다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `Sources/RhwpCoreBridge/RhwpDocument.swift` | `+17 / -5` | image data 두 wrapper에 exact pointer/length free와 안전한 `UInt`→`Int` 변환 추가 |
| `Tests/ExternalImageTests/RhwpDocumentExternalImageBridgeTests.swift` | `+59` | 반복 query, allocator pressure, document deinit과 invalid id 회귀 test 3개 추가 |
| `RustBridge/README.md` | `+3 / -2` | v0.8.2 provenance와 caller-owned image allocation 계약 반영 |
| `mydocs/tech/project_architecture.md` | `+5 / -5` | current core pin과 image buffer copy/free 경계 갱신 |
| `rhwp-core.lock` | `+5 / -5` | 새 archive/header의 built_at, hash와 size 반영 |
| `mydocs/working/task_m020_447_stage3.md` | 신규 | Stage 3 변경·검증과 잔여 위험 기록 |
| `mydocs/orders/20260729.md` | 1행 갱신 | #447을 Stage 3 완료·Stage 4 승인 대기로 전환 |

### Swift free 경계

`RhwpDocument.imageData(binDataId:)`와
`imageDataLength(binDataId:)`는 generated C header의 `uintptr_t`와 맞도록
length를 `UInt`로 받는다. non-null/non-zero 성공 allocation을 받은 직후
`defer rhwp_free_bytes(pointer, length)`를 설치하고, Swift `Int` 범위를
검사한 다음 `Data` 또는 length를 반환한다.

- `imageData`가 반환하는 `Data`는 Rust allocation과 독립된 복사본이다.
- `imageDataLength`도 query 결과 pointer를 사용하지 않더라도 즉시 해제한다.
- `hasImageData`는 기존처럼 `imageDataLength`를 사용하므로 같은 free 계약을
  따른다.
- null/zero/missing id는 기존 의미대로 `nil`을 반환한다.

### Swift 회귀 test

`samples/복학원서.hwp`의 embedded image id 1을 공통 fixture로 사용했다.

| Test | 검증 내용 |
|------|-----------|
| `testImageDataCopyAndLengthRemainStableUnderAllocationPressure` | Data와 length 일치, 128회 반복 query와 유사 크기 Data allocation 뒤 byte 안정성 |
| `testCopiedImageDataOutlivesDocument` | document scope 종료 뒤 copied Data 보존, 128개 allocation pressure 뒤 재개방 결과와 byte 동일성 |
| `testImageDataRejectsInvalidIdentifiers` | id 0과 `UInt16.max`에서 Data/length 모두 nil |

기존 external reference, injection, resolver test는 삭제하거나 완화하지 않았다.
전체 `ExternalImageTests`는 기존 24개와 신규 3개를 합쳐 27개다.

### Generated artifact와 lock

`./scripts/build-rust-macos.sh --update-lock`으로 arm64와 x86_64 static archive,
universal archive, generated C header와 `Rhwp.xcframework`를 같은 source에서
재생성했다.

| Artifact | 결과 |
|----------|------|
| `Frameworks/universal/librhwp.a` | arm64 + x86_64, 212,514,840 bytes, SHA-256 `5083f2a087bc390937c7b852ee832a10410d9f61e2cf5463affde8b0a737d9ca` |
| `Frameworks/generated_rhwp.h` | 3,242 bytes, SHA-256 `5dab4c02225c0d6b94e6ae07ed36aa8d6f496386dde3892e811e49f0c7bda614` |
| `rhwp_image_data` header | `uint8_t *` caller-owned mutable pointer |
| 공개 FFI | 기존 15개 symbol과 byte-identical |

`rhwp-core.lock`의 provenance는 release tag `v0.8.2`, resolved commit
`9b16aa9e23f476e2b335d7c029fc9f24a199d63c`, feature `native-skia`로
유지했다. 변경 필드는 `built_at`과 두 artifact의 hash·size뿐이다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source 변경은 `RhwpDocument.swift`의 image data wrapper 두 곳으로
  제한했다.
- 기존 Swift test 24개는 삭제·완화하지 않고 lifetime test 3개만 추가했다.
- RustBridge ownership 문서는 기존 external image 정책을 유지하면서 stale
  borrowed-pointer 문장과 core provenance만 현재 계약으로 교체했다.
- upstream `rhwp` source, `RustBridge/Cargo.toml`, `Cargo.lock`,
  `rhwp-ffi-symbols.txt`는 변경하지 않았다.
- `project.yml`을 원본으로 `xcodegen generate`를 실행했으며
  `project.yml`과 `Alhangeul.xcodeproj/project.pbxproj`에는 diff가 없다.
- App, Preview, Thumbnail 실행·등록, 사용자 Applications와 release
  signing/notarization 상태는 변경하지 않았다.

## 검증 결과

구현계획서 Stage 3에 고정한 검증 명령을 단계 종료 source 상태에서 다시
실행했다.

| 검증 | 결과 | 핵심 출력 |
|------|------|-----------|
| `build-rust-macos.sh --update-lock` | PASS | arm64/x86_64 staticlib, universal archive와 XCFramework 생성 |
| `build-rust-macos.sh --verify-lock` | PASS | `Verified: rhwp-core.lock` |
| `verify-rhwp-core-build-info.sh` | PASS | `RhwpCoreBuildInfo matches rhwp-core.lock` |
| FFI symbol diff | PASS | diff 출력 없음, 기존 15개 유지 |
| generated header marker | PASS | line 78 mutable `rhwp_image_data`, line 82 `rhwp_free_bytes` |
| `check-no-appkit.sh` | PASS | shared Swift code에 AppKit/UIKit 의존 없음 |
| `xcodegen generate` | PASS | project 생성 성공 |
| `ExternalImageTests` | PASS | 27 passed, 0 failed, 0 unexpected |
| project diff gate | PASS | `project.yml`, generated pbxproj diff 없음 |
| `git diff --check` | PASS | whitespace 오류 없음 |

최종 Swift test 요약:

```text
Test Suite 'HwpExternalImageResolverTests' passed
Executed 18 tests, with 0 failures

Test Suite 'RhwpDocumentExternalImageBridgeTests' passed
Executed 9 tests, with 0 failures

Test Suite 'All tests' passed
Executed 27 tests, with 0 failures (0 unexpected)
** TEST SUCCEEDED **
```

XCFramework 생성 중 sandbox의 CoreSimulator service 접근 경고가 출력됐지만,
이 단계는 macOS universal static library 생성 경로이며 command는 exit 0으로
완료됐다. 네트워크 허용 환경에서 실행한 macOS `ExternalImageTests`도 build와
runtime test를 모두 통과했으므로 제품/source 실패로 판정하지 않는다.

## 잔여 위험

- Stage 3 test는 Swift bridge 단위의 copy/free 계약을 검증한다. HostApp,
  QLExtension, ThumbnailExtension 전체 target build는 아직 수행하지 않았다.
- image-heavy renderer harness와 Finder가 실제로 선택한 Thumbnail provider
  process에서는 수정 archive를 아직 반복 검증하지 않았다.
- 기존 v0.1.9 build 15 crash report 두 건 이후 동일 candidate 조건에서 신규
  crash가 없는지는 Stage 4 baseline 시각과 exact-provider smoke로 확인해야
  한다.
- `imageDataLength`는 안전하게 allocation을 free하지만 upstream API 특성상
  length 확인에도 전체 lazy bytes allocation이 발생한다. 성능 최적화용 별도
  metadata ABI는 이번 타스크 범위가 아니다.
- `rhwp_free_bytes`는 반환받은 동일 pointer와 exact length를 한 번 전달해야
  한다. 현재 두 Swift wrapper와 test는 이 경계를 지키지만 신규 raw caller가
  추가되면 같은 규칙을 적용해야 한다.
- x86_64 slice는 archive 생성과 symbol 검증까지 통과했으며 실제 XCTest
  runtime은 현재 arm64 Mac에서 실행했다.

## 다음 단계 영향

Stage 4는 새 artifact를 실제 제품 경로에서 검증한다.

1. locked Rust test와 artifact lock을 다시 확인한다.
2. HostApp, QLExtension, ThumbnailExtension Debug target을 각각 build한다.
3. native renderer와 image-heavy visual diff harness를 실행한다.
4. Finder smoke 전 candidate app 경로·version/build·서명, 현재 사용자
   설치본과 active provider, 기존 crash baseline을 보고한다.
5. 사용자 Applications와 extension registration 변경은 별도 명시 승인 후
   표준 smoke helper로만 수행한다.
6. `복학원서.hwp` 등 HWP/HWPX thumbnail을 exact candidate provider로
   반복 생성하고 baseline 이후 신규 `AlhangeulThumbnail-*.ips`가 없는지
   확인한다.
7. smoke 종료 후 candidate를 unregister하고 사용자 설치본/provider 상태를
   복원한다.

Stage 4에서 core dependency, FFI symbol, 제품 동작 변경 또는 signing/
notarization/release workflow 실행이 필요하면 계획대로 중단하고 재승인을
요청한다.

## 승인 요청

Stage 3 Swift free 계약, generated artifact 정합성과 27/27 test 결과를
승인하고, 구현계획서의 Stage 4 `제품 target과 Finder Thumbnail crash 회귀
검증`에 진입할지 승인 요청한다.

Stage 4 승인 전에는 제품 target build, Finder provider 등록, 사용자
Applications 변경과 release workflow를 실행하지 않는다.
