# Task M020 #422 Stage 3 완료보고서

## 단계 목적

`rhwp v0.7.19` core/studio provenance로 RustBridge ABI와 locked dependency graph를 검증하고 HostApp, QLExtension, ThumbnailExtension compile/link를 확인한다. 대표 HWP/HWPX, embedded image, Quick Look/Thumbnail CoreGraphics·Skia policy runtime에서 crash, blank, timeout, fallback과 cache regression이 없는지 판정한다.

## 산출물

| 파일 또는 산출물 | 요약 |
|------------------|------|
| `mydocs/working/task_m020_422_stage3.md` | Rust/Xcode/runtime/registration 검증 결과 기록 |
| `mydocs/orders/20260719.md` | Stage 3 완료와 Stage 4 승인 대기 기록 |
| `build.noindex/DerivedData-task422-{host,ql,thumbnail}/` | 세 Xcode scheme의 ignored build output |
| `build.noindex/task422-image/` | embedded image native render output |
| `build.noindex/task422-quicklook-runtime/` | Quick Look policy summary와 output |
| `build.noindex/task422-thumbnail-runtime/` | Thumbnail policy/cache summary와 output |
| `output/stage3-render/` | 기본 native render output |

검증 산출물은 모두 ignored 경로이며 commit하지 않는다. Stage 3에서 product source, dependency, lock과 bundled studio asset 수정은 필요하지 않았다.

## Rust와 provenance 검증

### RustBridge

| 검증 | 결과 |
|------|------|
| `cargo fmt --check` | 통과 |
| `cargo check --locked` | `rhwp v0.7.19/f137b4c9`와 bridge compile 성공, 28.46초 |
| `cargo test --locked` | 4 passed, 0 failed, 0 ignored |

통과한 test:

```text
external_reference_lookup_reads_loaded_state
external_refs_json_has_owned_string_lifecycle
filename_context_validates_handle_and_utf8
injection_validates_inputs_and_missing_reference
```

external image reference lookup, Rust-owned JSON string lifecycle, UTF-8 filename input validation과 injection status contract가 모두 유지됐다.

### Artifact와 boundary

| 검증 | 결과 |
|------|------|
| `build-rust-macos.sh --verify-lock` | arm64/x86_64 archive, header, 15개 symbol, XCFramework와 lock 일치 |
| `check-no-appkit.sh` | Shared/RhwpCoreBridge에 AppKit/UIKit dependency 없음 |
| `verify-rhwp-core-build-info.sh` | `v0.7.19/f137.../native-skia` lock과 일치 |
| `verify-rhwp-studio-assets.sh` | bundled studio manifest와 copied asset hash 일치 |

Stage 2에서 고정한 core/studio provenance는 Stage 3 전체 검증 동안 변하지 않았다.

## 앱 target build

`xcodegen generate`로 `project.yml`에서 검증용 project를 생성했다. generated project는 commit 대상이 아니다.

| Scheme | Configuration | Signing | 결과 | 시간 |
|--------|---------------|---------|------|------|
| HostApp | Debug | `CODE_SIGNING_ALLOWED=NO` | BUILD SUCCEEDED | 13.524초 |
| QLExtension | Debug | `CODE_SIGNING_ALLOWED=NO` | BUILD SUCCEEDED | 11.379초 |
| ThumbnailExtension | Debug | `CODE_SIGNING_ALLOWED=NO` | BUILD SUCCEEDED | 10.968초 |

세 scheme은 current project dependency graph에 따라 HostApp, QLExtension, ThumbnailExtension과 Sparkle을 함께 compile/link했다. `Rhwp.xcframework`, updated `RhwpCoreBuildInfo.swift`와 bundled `rhwp-studio` resource copy/embedded extension validation까지 성공했다.

Xcode는 signing을 끈 build에서도 aggregate HostApp을 LaunchServices에 자동 등록했다. 등록 정리 결과는 아래 별도 절에 기록한다.

## Native representative render

`validate-stage3-render.sh` 기본 suite:

| Sample | Page | Pixel | Text runs | Hangul runs/scalars | Non-white pixels | 결과 |
|--------|------|-------|-----------|---------------------|------------------|------|
| `KTX.hwp` | 1 | 1123x794 | 410 | 76 / 209 | 455,341 | OK |
| `request.hwp` | 1 | 567x794 | 102 | 36 / 309 | 70,188 | OK |
| `exam_kor.hwp` | 1 | 1123x1588 | 133 | 86 / 1,368 | 173,981 | OK |

세 문서 모두 page load, tree decode와 PNG generation에 성공했으며 blank output이 아니다.

embedded image fixture:

| Sample | Page | Pixel | Text runs | Hangul runs/scalars | Non-white pixels | 결과 |
|--------|------|-------|-----------|---------------------|------------------|------|
| `hwp-img-001.hwp` | 1 | 794x1123 | 66 | 35 / 190 | 51,581 | OK |

생성 PNG를 직접 확인해 상단 정부혁신 로고와 하단 캠페인 로고가 모두 표시되는 것을 확인했다. `v0.7.19` BinData 지연 로딩 변경 뒤에도 embedded image lookup/data copy/render가 유지된다.

## Quick Look policy runtime

DEBUG resolver contract와 대표 3문서를 CoreGraphics only, Skia decode와 가능한 경우 Skia direct PNG 경로로 실행했다.

| Sample | Reply | Pages | CoreGraphics | Skia decode | Skia direct | Direct fallback |
|--------|-------|-------|--------------|-------------|-------------|-----------------|
| `request.hwp` | PNG | 1 | `cg:1` | `skia:1` | `skia:1` | 0 |
| `KTX.hwp` | PNG | 1 | `cg:1` | `skia:1` | `skia:1` | 0 |
| `hwpx-01.hwpx` | PDF | 9 | `cg:9` | `skia:9` | N/A | N/A |

세 문서 load/reply generation이 모두 성공했다. HWP 단일 페이지는 PNG, HWPX 9페이지는 PDF reply contract를 유지한다. CoreGraphics와 Skia decode 모두 fallback 0이며 HWP direct PNG에도 fallback이 없다.

측정값은 다음과 같다.

| Sample | CG seconds | Skia decode seconds | Skia direct seconds |
|--------|------------|---------------------|---------------------|
| `request.hwp` | 1.004792 | 0.123412 | 0.007664 |
| `KTX.hwp` | 0.074804 | 0.044977 | 0.017065 |
| `hwpx-01.hwpx` | 0.448475 | 0.234607 | N/A |

이 값은 single local smoke 관찰치이며 performance claim이나 release threshold로 사용하지 않는다.

## Thumbnail policy와 cache runtime

resolver의 missing/empty/invalid/CoreGraphics/Skia env 입력 7개가 모두 expected policy로 해석됐다. 대표 3문서에 두 policy와 네 request shape를 적용했다.

| Sample | 총 render | 실패 | CG first | Skia first | 반복/cache |
|--------|-----------|------|----------|------------|------------|
| `request.hwp` | 8 | 0 | miss | miss | exact hit와 larger bucket hit 유지 |
| `KTX.hwp` | 8 | 0 | miss | miss | exact hit와 larger bucket hit 유지 |
| `hwpx-01.hwpx` | 8 | 0 | miss | miss | exact hit와 larger bucket hit 유지 |

총 24회 render가 모두 성공했다. 각 policy에서 large request는 miss, 동일 large 반복은 exact hit, medium/small request는 `largerBucketHit(1024x1024)`로 처리됐다. fallback은 없었다.

cache signature에는 다음 provenance가 포함되고 CoreGraphics/Skia가 분리된다.

```text
v0.7.19
f137b4c9468eaff5bb43e25108e9c9d39a2ed15b
native-skia
skia-max-dimension-thumbnail-v1
```

따라서 core update 뒤 stale `v0.7.18` thumbnail cache와 충돌하지 않는다.

## Development registration 정리

세 Xcode build가 다음 Debug app을 LaunchServices에 자동 등록했다.

```text
build.noindex/DerivedData-task422-host/Build/Products/Debug/Alhangeul.app
build.noindex/DerivedData-task422-ql/Build/Products/Debug/Alhangeul.app
build.noindex/DerivedData-task422-thumbnail/Build/Products/Debug/Alhangeul.app
```

각 앱을 `lsregister -u`로 해제했다. 최초 dump 검색에서 각 build에 포함된 Sparkle `Updater.app` 3개가 별도 잔여로 확인돼 이 경로도 모두 해제했다. 재검색 결과 `rhwp-mac-task422` 또는 `DerivedData-task422` 경로는 0건이다.

PlugInKit 확인 결과:

- Quick Look Preview: `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex` v0.1.7만 등록
- Thumbnail: `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex` v0.1.7만 등록
- Task #422 Debug provider path: 없음

기존 `/Applications` 공개 설치본과 HOP provider는 변경하거나 해제하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- product source 변경: 없음
- dependency/lock/build info 변경: 없음
- bundled studio asset 변경: 없음
- generated/ignored build·runtime output만 생성
- Xcode project 원본 `project.yml`: 변경 없음
- remote GitHub state와 PR #421: 변경 없음
- 기존 `/Applications/Alhangeul.app`, HOP 등록: 보존

Stage 3는 Stage 2 source를 수정하지 않고 compile/runtime 검증만 수행했다. tracked 변경은 이 보고서와 orders 진행 상태뿐이다.

## 검증 결과

| Gate | 결과 |
|------|------|
| Rust fmt/check/test locked | 통과, 4/4 tests |
| universal artifact/15 ABI/lock | 통과 |
| no-AppKit boundary | 통과 |
| core build info/studio asset | 통과 |
| HostApp/QLExtension/ThumbnailExtension | 세 scheme BUILD SUCCEEDED |
| 기본 HWP render | 3/3 성공, non-blank |
| embedded image render | 성공, 상·하단 로고 확인 |
| Quick Look policy | 3/3 성공, HWP PNG/HWPX 9-page PDF, fallback 0 |
| Thumbnail policy/cache | 24/24 성공, failure 0, cache contract 유지 |
| development registration cleanup | Task Debug app/provider/Updater 잔여 0 |
| `git status` before report | clean |

## 잔여 위험

- Stage 3는 compile과 helper runtime 검증이며 실제 signed app의 WKWebView UI를 실행하지 않았다.
- bundled studio entrypoint/WASM/NotoSansKR font의 실제 load와 첫 페이지 visual은 Stage 4에서 확인한다.
- 저장 지오메트리와 표 페이지네이션의 changed-percent 및 content loss 여부는 representative visual comparison이 필요하다.
- `KTX.hwp` known Skia delta가 유지되는지 아직 재측정하지 않았다.
- runtime 시간은 single local run이며 성능 회귀 또는 개선을 단정할 표본이 아니다.
- signed HOP exact UTI/Finder routing은 public release blocking gate로 남는다.

## 다음 단계 영향

Stage 4는 source를 변경하지 않고 Task #396/Task #418과 같은 quick 5-sample suite를 CoreGraphics/Skia 두 policy로 실행한다. page size/count, changed-percent, blank/fallback과 `KTX.hwp` sentinel을 이전 수치와 비교하고 bundled studio entrypoint/WASM/font load를 별도로 확인한다.

Stage 4에서 blocking visual 또는 studio load regression이 발견되면 최종 handoff로 넘어가지 않고 원인과 수정 범위를 판단한다.

## 승인 요청

Stage 3의 Rust ABI, 앱 build와 representative runtime 회귀 검증 결과를 승인해 주시면 Stage 4 renderer와 bundled studio visual 회귀 판정을 진행한다.
