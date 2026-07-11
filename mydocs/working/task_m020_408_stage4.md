# Task M020 #408 Stage 4 보고서

## 단계 목적

Stage 4의 목적은 Stage 3에서 생성한 `Rhwp.xcframework`가 기존 Swift HostApp, Quick Look Preview, Finder Thumbnail target과 compile/link되고, `HwpDocument` handle 전환과 additive external image ABI가 기존 page/render/embedded image 경로를 회귀시키지 않는지 검증하는 것이다.

이 단계는 검증 전용이며 제품 Swift/Rust source를 변경하지 않는다. Finder extension 등록 smoke와 external image resolver 적용은 범위 밖이다.

## 산출물

| 산출물 | 요약 |
|--------|------|
| `mydocs/working/task_m020_408_stage4.md` | Swift/Xcode, render fixture, Rust test, symbol, import signature 검증 결과를 기록한다. |
| `mydocs/orders/20260711.md` | #408을 Stage 4 완료 및 Stage 5 승인 대기 상태로 갱신한다. |
| `build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app` | HostApp Debug compile/link 검증 산출물. ignored이며 commit하지 않는다. |
| `output/stage3-render/*.png` | 기본 fixture native render 결과. ignored이며 commit하지 않는다. |
| `build.noindex/task408-render/hwp-img-001-page1.png` | embedded image fixture native render 결과. ignored이며 commit하지 않는다. |

## Swift/Xcode compile·link 결과

`xcodegen generate`가 `project.yml`에서 `Alhangeul.xcodeproj`를 생성한 뒤 HostApp Debug build가 성공했다.

```text
Target dependency graph (4 targets)
- HostApp
- QLExtension
- ThumbnailExtension
- Sparkle
...
-lrhwp
...
** BUILD SUCCEEDED **
```

build log에서 `ProcessXCFramework`가 `Frameworks/Rhwp.xcframework`를 macOS static library로 처리했고 HostApp linker가 `-lrhwp`를 사용했음을 확인했다. `RhwpDocument.swift`, `RenderTree.swift`, `CGTreeRenderer.swift`를 포함한 HostApp과 두 extension target이 같은 generated module로 compile됐다.

첫 sandbox build는 Swift package `Sparkle 2.9.1` fetch 중 GitHub DNS 제한으로 실패했다. 네트워크 권한이 있는 동일 명령으로 package를 내려받은 뒤 build가 성공했으므로 source 또는 ABI compile failure가 아니다.

Xcode는 CoreSimulatorService, provisioning profile, plist type detector 관련 경고를 출력했지만 macOS Debug build exit code는 0이고 최종 app/appex validation까지 완료됐다.

## Render regression 결과

### 기본 fixture

```bash
./scripts/validate-stage3-render.sh
```

| fixture | page | bitmap | textRuns | hangulRuns | hangulScalars | nonWhitePixels |
|---------|------|--------|----------|------------|---------------|----------------|
| `KTX.hwp` | 1 | 1123x794 | 410 | 76 | 209 | 455,061 |
| `request.hwp` | 1 | 567x794 | 102 | 36 | 309 | 70,188 |
| `exam_kor.hwp` | 1 | 1123x1588 | 133 | 86 | 1,368 | 173,981 |

세 fixture 모두 document open, page size, render tree, 한글 glyph, native PNG, non-blank gate를 통과했다.

### Embedded image fixture

```bash
./scripts/validate-stage3-render.sh build.noindex/task408-render samples/hwp-img-001.hwp
```

결과:

```text
OK hwp-img-001.hwp: page=1 size=794x1123 textRuns=66
hangulRuns=35 hangulScalars=190 nonWhitePixels=57037
```

생성 PNG는 794x1123 RGBA이며 sha256은 `c8744c304ccb847cbdaa72b079f44762794efcee2a7b48205f74496f7463e49d`다. 직접 확인 결과 페이지 상단 정부 로고와 하단 기관/OPEN 로고를 포함한 embedded image가 표시되어 기존 `bin_data_id -> rhwp_image_data -> CoreGraphics` 경로가 유지됨을 확인했다.

이 검증은 embedded image 회귀 gate이며 external image 성공 injection visual 검증을 대신하지 않는다.

## Swift import signature

저장소 밖 임시 Swift 파일에서 `import Rhwp` 후 신규 enum과 세 함수를 참조하고 generated header module을 직접 typecheck했다.

```bash
xcrun swiftc -typecheck -dump-ast \
  -module-cache-path /private/tmp/task408-swift-module-cache \
  -Xcc -fmodules-cache-path=/private/tmp/task408-clang-module-cache \
  -I Frameworks/Rhwp.xcframework/macos-arm64_x86_64/Headers \
  /private/tmp/task408_swift_import.swift
```

확인된 Swift interface type:

```swift
RhwpExternalImageStatus(rawValue: UInt32) -> RhwpExternalImageStatus

rhwp_set_file_name_utf8:
  (OpaquePointer?, UnsafePointer<UInt8>?, UInt)
    -> RhwpExternalImageStatus

rhwp_external_image_refs_json:
  (OpaquePointer?) -> UnsafeMutablePointer<CChar>?

rhwp_inject_external_image_by_key:
  (OpaquePointer?,
   UnsafePointer<UInt8>?, UInt,
   UnsafePointer<UInt8>?, UInt,
   UnsafePointer<UInt8>?, UInt)
    -> RhwpExternalImageStatus
```

#409 Swift wrapper는 기존 `RhwpRenderStatus`와 같은 방식으로 `RhwpExternalImageStatus.rawValue`를 downstream enum에 매핑할 수 있다. refs JSON pointer는 `String(cString:)` 또는 `Data`로 복사한 뒤 반드시 `rhwp_free_string`으로 해제해야 한다.

첫 typecheck는 default Clang module cache가 sandbox 밖 `~/.cache`에 있어 실패했다. Swift/Clang module cache를 `/private/tmp`로 지정한 동일 typecheck는 통과했다. 임시 Swift source는 검증 후 삭제했다.

## 본문 변경 정도 / 본문 무손실 여부

- Stage 4에서는 제품 Swift/Rust source, cbindgen, symbol lock, core lock을 변경하지 않았다.
- `xcodegen generate`는 `project.yml`을 읽어 ignored/generated `Alhangeul.xcodeproj`를 만들었으며 project 원본은 무변경이다.
- Xcode build, Rust target, render PNG와 module cache는 모두 `build.noindex/`, `output/`, `Frameworks/`, `RustBridge/target/` 아래 ignored 산출물이다.
- tracked 변경은 Stage 4 보고서와 오늘할일 진행 메모뿐이다.
- Quick Look/Thumbnail 제품 동작과 extension 등록 정책은 변경하지 않았다.

## 검증 결과

### Core artifact lock

```bash
./scripts/build-rust-macos.sh --verify-lock
```

결과: 통과. arm64/x86_64 staticlib, 15개 symbol, generated header, xcframework와 `rhwp-core.lock` 일치를 확인했다.

### Shared bridge dependency boundary

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### Xcode project와 HostApp build

```bash
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과: 통과, `** BUILD SUCCEEDED **`.

### Native render smoke

```bash
./scripts/validate-stage3-render.sh
./scripts/validate-stage3-render.sh build.noindex/task408-render samples/hwp-img-001.hwp
```

결과: 기본 3개와 image fixture 모두 통과. 세부 metric과 시각 확인은 앞 절에 기록했다.

### Rust unit test

```bash
cargo test --manifest-path RustBridge/Cargo.toml --locked
```

결과: 4개 test 모두 통과.

```text
test result: ok. 4 passed; 0 failed
```

### Staticlib symbol

```bash
nm -gU Frameworks/universal/librhwp.a | \
  rg "rhwp_(open|image_data|set_file_name_utf8|external_image_refs_json|inject_external_image_by_key|close)"
```

결과: 기존 open/image/close와 신규 세 symbol 모두 존재한다.

### Tracked diff와 개발 등록 정리

```bash
git diff --check
git status --short --branch
```

결과: 검증 산출물 생성 직후 tracked working tree는 clean이었다.

Xcode build가 Debug app에 `RegisterWithLaunchServices`를 실행했으므로 종료 시 해당 path 등록 해제를 시도했다. `lsregister -u`는 `-10814`를 반환했지만 이어서 registration dump를 조회했을 때 `build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app` path가 존재하지 않아 개발 산출물 등록이 남아 있지 않음을 확인했다.

## 잔여 위험

- external image exact fixture가 없어 실제 resolver bytes injection 후 refs `loaded` 전환과 Quick Look output은 검증하지 못했다. #409와 #412 범위다.
- Stage 4 image fixture는 embedded image 회귀를 확인하지만 external missing, oversized image, decode failure를 포함하지 않는다.
- 신규 ABI는 generated module에 import되지만 Swift wrapper에서 아직 호출하지 않는다. #409에서 pointer/length와 status mapping test가 필요하다.
- Debug build는 compile/link gate이며 signed/sealed Finder extension smoke의 진실 원천이 아니다. 이 단계에서는 extension 등록 smoke를 의도적으로 실행하지 않았다.
- CoreSimulator와 provisioning 관련 Xcode 경고는 비치명적이었지만 CI/다른 Xcode 버전에서도 warning noise가 발생할 수 있다.
- render smoke는 non-blank와 glyph sanity 중심이며 pixel equivalence를 보장하지 않는다. Full external/large visual regression은 #412가 소유한다.

## 다음 단계 영향

Stage 5에서는 다음을 최종 보고서와 #409 handoff로 정리한다.

1. 최종 public symbol과 `RhwpExternalImageStatus` 값
2. refs JSON shape와 pointer/length/free/lifetime 계약
3. `rhwp_image_state_json` 보류와 external fixture 미측정 위험
4. Swift import signature와 #409 wrapper/status mapping 입력
5. Stage 1-4 검증 결과, artifact provenance와 build gate 보정
6. 오늘할일 완료 처리와 task-final-report 전 최종 승인 요청

## 승인 요청

Stage 4 `Swift compile/link와 embedded render 회귀 검증`은 완료됐다. Stage 5 `최종 보고서와 #409 handoff`로 진행하려면 작업지시자 승인이 필요하다.
