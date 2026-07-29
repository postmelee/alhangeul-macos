# Task M020 #438 Stage 3 보고서

## 단계 목적

Stage 3의 목적은 `rhwp v0.8.2` core가 current RustBridge와 Task #409 external image Swift 경로를 유지하는지 test하고, HostApp과 Quick Look/Thumbnail extension의 compile/link 및 bundled studio resource 포함을 확인하는 것이다.

검증 과정에서 Task #409의 `project.yml` 변경이 tracked `Alhangeul.xcodeproj/project.pbxproj`에 생성되지 않은 기존 drift를 발견했다. 작업지시자 승인에 따라 PR #436은 변경하지 않고 `local/task438`에서 generated project 한 파일만 정합화한 뒤, candidate 검증에 사용한 file과 byte identity 및 재생성 안정성을 확인했다.

## 산출물

| 산출물 | 결과 |
|--------|------|
| integration candidate | `/private/tmp/alhangeul-task438.7Mp2aG/integration-v2`, merge ref `2413549de446e63ab5605d5e3590841baea653fa` |
| generated Xcode project correction | `Alhangeul.xcodeproj/project.pbxproj` 151줄 추가, 삭제 0줄 |
| ExternalImageTests result bundle | `/private/tmp/alhangeul-task438.7Mp2aG/integration-v2/build.noindex/DerivedDataTask438Stage3Tests/Logs/Test/Test-ExternalImageTests-2026.07.28_19-19-19-+0900.xcresult` |
| HostApp Debug product | `build.noindex/DerivedDataTask438Stage3Host/Build/Products/Debug/Alhangeul.app` |
| QLExtension Debug product | `build.noindex/DerivedDataTask438Stage3QL/Build/Products/Debug/AlhangeulPreview.appex` |
| ThumbnailExtension Debug product | `build.noindex/DerivedDataTask438Stage3Thumbnail/Build/Products/Debug/AlhangeulThumbnail.appex` |
| `mydocs/plans/task_m020_438_impl.md` | 승인된 Stage 3 generated project 정합화 범위와 cleanup을 반영했다. |
| `mydocs/working/task_m020_438_stage3.md` | ABI, external image, 제품 target, bundle과 project drift 결과를 기록한다. |
| `mydocs/orders/20260728.md` | #438을 Stage 3 완료 및 Stage 4 승인 대기 상태로 갱신한다. |

모든 build/test 산출물은 task 전용 `build.noindex/` 아래에 있고 commit 대상이 아니다.

## 후보 identity

Stage 3 시작 시 `origin/devel`과 PR #436 ref를 다시 fetch했다.

| 구분 | SHA |
|------|-----|
| current `origin/devel` | `c968c1a4a059f31f5e9973900b276bbb00e452cb` |
| corrected PR #436 head | `e8d9b4acef5cc827207cc8fc676ccef7d4ce2041` |
| merge candidate | `2413549de446e63ab5605d5e3590841baea653fa` |
| candidate parent 1 | `c968c1a4a059f31f5e9973900b276bbb00e452cb` |
| candidate parent 2 | `e8d9b4acef5cc827207cc8fc676ccef7d4ce2041` |
| candidate tree | `cc12016b4feea0320449c6a7c749a400a603bca5` |

Stage 2 identity와 모두 일치했다. `Frameworks/Rhwp.xcframework`, generated header와 universal static library가 candidate에 유지돼 있었다.

Stage 3 검증 종료 후 candidate에서 `xcodegen`이 만든 `project.pbxproj` 변경만 exact HEAD로 복구했다. `git status --short`, `git diff --check`, `git diff --cached --check` 출력은 모두 비어 있다.

## Generated Xcode project 정합화

### 발견

candidate에서 다음 계획 명령을 실행했다.

```bash
xcodegen generate
```

명령 자체는 성공했지만 tracked `Alhangeul.xcodeproj/project.pbxproj`에 다음 diff가 생겼다.

```text
151	0	Alhangeul.xcodeproj/project.pbxproj
```

추가 항목은 다음 범위로 제한됐다.

- `ExternalImageTests` target, product, Debug/Release configuration
- `ExternalImageTestSupport.swift`
- `HwpExternalImageResolverTests.swift`
- `RhwpDocumentExternalImageBridgeTests.swift`
- `HwpExternalImageResolver.swift`의 HostApp, Quick Look, Thumbnail과 test target 연결
- test target의 `Rhwp.xcframework` 및 system framework/link library 연결

삭제되거나 기존 target 설정이 바뀐 항목은 없다.

### 원인 분리

Task #409 commit 이력을 확인했다.

| commit | 관련 변경 |
|--------|-----------|
| `7b527e8d39accf3e19de5e4140555a379f845155` | External image wrapper/test와 `project.yml` 변경 |
| `f9fb73519f3cdef981b5c59ec1a9c9770fd5c230` | Resolver/test와 `project.yml` 변경 |

두 commit은 `project.yml`을 변경했지만 `Alhangeul.xcodeproj/project.pbxproj`를 포함하지 않았다. current `project.yml`에는 `ExternalImageTests` target이 선언돼 있고 tracked project에는 없으므로 upstream sync PR에서 유입된 drift가 아니다.

PR CI, `scripts/package-release.sh`와 release script는 build 전에 `xcodegen generate`를 실행한다. 따라서 tracked project drift가 이번 CI/build를 실패시키지는 않았지만, 저장소의 generated project 정합성과 Stage 3 무손실 조건을 충족하지 못했다.

### 승인된 보정

작업지시자 승인에 따라 다음 경계로 보정했다.

- PR #436 head는 변경하지 않았다.
- `project.yml`은 수정하지 않았다.
- `local/task438`에서 `xcodegen generate`를 실행해 `Alhangeul.xcodeproj/project.pbxproj`만 갱신했다.
- correction은 Stage 3 보고서와 같은 commit에 포함한다.

`local/task438` generated file과 candidate에서 24개 test 및 세 제품 target build에 사용한 generated file을 비교했다.

```text
SHA-256:
3f54e0aa5bfc789fa8efd747b9cc7e33247f16fd935542acab590356f6514972

cmp:
byte-identical
```

`local/task438`에서 `xcodegen generate`를 다시 실행한 뒤에도 SHA-256과 `151 additions, 0 deletions` diff는 변하지 않았다. 따라서 correction의 생성 재현성과 실제 검증 file identity를 확인했다.

## RustBridge와 ABI 검증

### Rust formatting

```bash
cargo fmt --manifest-path RustBridge/Cargo.toml --check
```

결과: PASS.

### locked RustBridge test

```bash
cargo test --manifest-path RustBridge/Cargo.toml --locked
```

첫 sandbox 실행은 `skia-bindings` prebuilt archive와 source fallback을 받는 과정에서 `github.com`, `codeload.github.com` DNS 해석에 실패했다. 동일 명령을 네트워크 허용 환경에서 다시 실행해 통과했다.

```text
running 4 tests
test tests::external_reference_lookup_reads_loaded_state ... ok
test tests::filename_context_validates_handle_and_utf8 ... ok
test tests::injection_validates_inputs_and_missing_reference ... ok
test tests::external_refs_json_has_owned_string_lifecycle ... ok

test result: ok. 4 passed; 0 failed
```

검증한 계약은 external reference 조회, filename context validation, injection input/status, owned JSON string lifetime이다.

### Swift shared boundary와 build info

```bash
./scripts/check-no-appkit.sh
./scripts/verify-rhwp-core-build-info.sh
```

```text
OK: shared Swift code has no AppKit/UIKit dependencies
OK: RhwpCoreBuildInfo matches rhwp-core.lock
```

`RhwpCoreBridge`의 platform UI dependency 금지와 Stage 2에서 보정한 `v0.8.2` build metadata를 유지했다.

## ExternalImageTests

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ExternalImageTests \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask438Stage3Tests \
  CODE_SIGNING_ALLOWED=NO \
  test
```

첫 sandbox 실행은 Xcode service 접근 제한과 Sparkle dependency의 GitHub DNS 실패로 종료됐다. source compile/test failure가 아니다. 동일 명령을 Xcode service와 네트워크 접근이 가능한 환경에서 재실행했다.

```text
HwpExternalImageResolverTests:
  Executed 18 tests, with 0 failures

RhwpDocumentExternalImageBridgeTests:
  Executed 6 tests, with 0 failures

ExternalImageTests.xctest:
  Executed 24 tests, with 0 failures

** TEST SUCCEEDED **
```

`xcresulttool get test-results summary`로 result bundle을 다시 읽었다.

| 항목 | 값 |
|------|----|
| total | 24 |
| passed | 24 |
| failed | 0 |
| skipped | 0 |
| expected failures | 0 |
| result | `Passed` |
| device | arm64 Mac, macOS 26.5.2 |

status raw-value mapping, refs JSON decoder, repeated owned buffer lifetime, missing-key/input rejection, basename-only sibling resolver, symlink escape, byte limit, privacy-safe summary와 Preview open contract를 포함한다.

XCTest link 시 target deployment 12.0과 현재 XCTest runtime 14.0의 minimum-version warning이 있었지만 link와 24개 test 실행은 성공했다.

## 앱과 extension compile/link

검증 도구는 XcodeGen `2.45.4`, Xcode `26.6` build `17F113`이다. 세 명령은 모두 network/Xcode service 접근이 가능한 같은 host에서 실행했다.

### HostApp

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask438Stage3Host \
  CODE_SIGNING_ALLOWED=NO \
  build
```

```text
** BUILD SUCCEEDED ** [12.526 sec]
```

HostApp dependency graph에서 QLExtension, ThumbnailExtension과 Sparkle을 함께 compile/link했고 두 `.appex`를 app bundle에 embed했다.

### QLExtension

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme QLExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask438Stage3QL \
  CODE_SIGNING_ALLOWED=NO \
  build
```

```text
** BUILD SUCCEEDED ** [11.470 sec]
```

### ThumbnailExtension

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ThumbnailExtension \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask438Stage3Thumbnail \
  CODE_SIGNING_ALLOWED=NO \
  build
```

```text
** BUILD SUCCEEDED ** [11.399 sec]
```

현재 generated scheme의 extension build action에는 HostApp과 두 extension dependency graph가 함께 포함된다. 각 task 전용 DerivedData에서 대상 `.appex`, HostApp과 embedded extension validation이 모두 성공했다.

## HostApp bundled studio 검증

```bash
./scripts/verify-rhwp-studio-assets.sh \
  build.noindex/DerivedDataTask438Stage3Host/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

```text
OK: rhwp-studio assets verified at
build.noindex/DerivedDataTask438Stage3Host/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio
```

app bundle에서 다음 항목을 별도로 확인했다.

- `rhwp-studio/index.html`
- `rhwp-studio/manifest.json`
- `rhwp-studio/print.html`
- 단일 `assets/rhwp_bg-ftaI0hCm.wasm`
- `Contents/PlugIns/AlhangeulPreview.appex`
- `Contents/PlugIns/AlhangeulThumbnail.appex`

source manifest와 app bundle copy가 일치한다.

## 개발 등록 cleanup

Xcode build는 task 전용 Debug app 세 개와 embedded extension을 LaunchServices에 자동 등록했다. 표준 hygiene helper의 check-only 결과에는 이전 Task #409/#433 등의 개발 등록도 함께 존재했다.

기존 다른 작업의 등록은 변경하지 않고 이번 Stage 3의 다음 exact 경로만 해제했다.

- `DerivedDataTask438Stage3Host` app, Preview/Thumbnail extension, Sparkle updater
- `DerivedDataTask438Stage3QL` app, Preview/Thumbnail extension, Sparkle updater
- `DerivedDataTask438Stage3Thumbnail` app, Preview/Thumbnail extension, Sparkle updater

각 extension은 `pluginkit -r`, app과 Sparkle updater는 `lsregister -u`로 해제하고 `qlmanage -r cache`를 실행했다. 최종 `lsregister -dump`에서 `/private/tmp/alhangeul-task438.7Mp2aG/integration-v2/build.noindex/DerivedDataTask438Stage3` 경로 match는 0개다.

app bundle이나 build output은 삭제하지 않았고 전역 LaunchServices reset, daemon kill과 설치본 변경은 하지 않았다.

## 본문 변경 정도와 무손실 여부

`local/task438`의 Stage 3 변경은 다음으로 제한된다.

| 파일 | 변경 |
|------|------|
| `Alhangeul.xcodeproj/project.pbxproj` | `project.yml` 기반 generated 정합화, 151 additions |
| `mydocs/plans/task_m020_438_impl.md` | 승인된 Stage 3 범위 보정 기록 |
| `mydocs/working/task_m020_438_stage3.md` | 단계 결과 보고 |
| `mydocs/orders/20260728.md` | Stage 3 완료 상태 |

`project.yml`, Swift/Rust source, test, PR #436 core/studio asset과 lock은 수정하지 않았다. generated correction은 candidate 검증 file과 byte-identical하다.

candidate는 검증 후 exact merge ref 상태로 복구했으며 tracked drift가 없다. build/test output은 ignored `build.noindex/`, Rust target과 generated framework 경로에만 존재한다.

## 검증 결과

| gate | 결과 |
|------|------|
| candidate base/head/tree identity | PASS |
| Rust formatting | PASS |
| locked RustBridge tests | 4/4 PASS |
| RhwpCoreBridge AppKit/UIKit dependency boundary | PASS |
| build info와 core lock 정합성 | PASS |
| Xcode project generation | PASS |
| generated project correction 범위 | 1 file, 151 additions, 0 deletions |
| local/candidate generated project byte identity | PASS |
| repeated xcodegen reproducibility | PASS |
| ExternalImageTests | 24/24 PASS |
| HostApp Debug compile/link | PASS |
| QLExtension Debug compile/link | PASS |
| ThumbnailExtension Debug compile/link | PASS |
| HostApp studio bundle copy | PASS |
| embedded Preview/Thumbnail extension | PASS |
| candidate diff check와 tracked hygiene | PASS |
| task 전용 Debug registration cleanup | PASS |

Stage 3 완료 조건을 모두 충족한다. sandbox DNS/Xcode service 실패는 동일 명령의 승인된 환경 재실행 성공으로 source 실패와 분리했다.

## 잔여 위험

- Stage 2의 strict `librhwp.a` byte reference 차이는 그대로다. portable source/header/symbol gate는 통과했다.
- generated project correction은 아직 `local/task438` commit에만 포함될 예정이므로 Task #438 PR merge 전 current `devel`의 tracked project는 stale 상태다. release 전에 Task #438 PR 반영이 필요하다.
- 작업지시자가 이전 개발 등록 전체 cleanup을 승인하지 않았으므로 Task #409/#433 등 기존 `build.noindex/` 등록은 남아 있다. Stage 4 actual Finder smoke 전 표준 hygiene cleanup 범위 승인이 필요하다.
- Debug `CODE_SIGNING_ALLOWED=NO` build는 compile/link와 resource 검증 결과다. Finder provider 등록, thumbnail output과 signed/sealed bundle gate를 대체하지 않는다.
- 대표 HWP/HWPX render, external sibling fixture, Quick Look/Thumbnail policy와 runtime 결과는 Stage 4에서 확인해야 한다.
- PR #436은 아직 merge하지 않았다.

## 다음 단계 영향

Stage 4는 같은 PR #436 merge candidate와 upstream checkout을 사용해 renderer와 Finder surface 회귀를 확인한다.

- 대표 HWP 세로/가로/다중 페이지와 HWPX first-page render sanity
- upstream external sibling fixture injection 및 privacy-safe summary
- CoreGraphics/Skia Quick Look policy smoke
- Thumbnail scale/cache/memory policy smoke
- bundled studio/runtime release handoff

actual Finder 등록 smoke는 signed/sealed Release package를 사용하며 실행 직전 별도 승인이 필요하다. 그 전에 기존 개발/테스트 등록 cleanup 범위를 다시 확인한다.

PR #436 merge와 public release는 Stage 4 및 최종 보고 승인 뒤 별도 절차로 진행한다. Task #438 generated project correction도 release 전에 `devel`에 반영돼야 한다.

## 승인 요청

Stage 3 `ABI·external image·앱 target 통합 검증`은 완료됐다.

다음 단계인 Stage 4 `Renderer·Finder surface 회귀와 release handoff` 진입 승인을 요청한다.
