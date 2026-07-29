# Task M020 #409 Stage 4 보고서

## 단계 목적

Stage 4의 목적은 고정된 upstream external image fixture로 Swift resolver의 실제 reference decode, sibling image injection, final loaded 상태와 Preview render를 통합 검증하고, 등록된 Quick Look extension의 sandbox에서 같은 동작이 가능한지 확인하는 것이다.

source-level 검증에서는 valid, missing, oversize fixture를 구분해 성공과 비치명 실패를 확인했다. registered Preview 검증에서는 macOS 26.5.2(25F84)의 Quick Look host가 main document에 부여한 sandbox capability만으로 sibling file capability를 발급하지 못하는 플랫폼 제한을 확인했다. read-only/read-write entitlement와 Foundation related-item API 조합을 추가로 실험했지만 결과가 같았다.

작업지시자는 이 결과를 확인한 뒤 Stage 4 완료 조건을 다음처럼 조정하는 데 승인했다.

- source-level 경로에서 external image 3건의 injection과 render 성공을 증명한다.
- 실제 registered Preview에서는 `permissionDenied`가 privacy-safe count로 남고 main document render가 계속되는 graceful fallback을 증명한다.
- #409에는 sandbox 해제, broad folder entitlement, 임시 absolute-path exception, unsandboxed broker 또는 사용자 folder authorization을 추가하지 않는다.

## 산출물

| 파일/산출물 | 결과 |
|-------------|------|
| `mydocs/working/task_m020_409_stage4.md` | pinned fixture, source-level smoke, registered Preview 실험, 플랫폼 제한과 검증 결과를 기록한다. |
| `mydocs/orders/20260724.md` | #409를 Stage 4 완료 및 Stage 5 승인 대기 상태로 갱신한다. |
| `build.noindex/task409-external-*-output/` | valid, missing, oversize source-level smoke 결과를 보존한다. Git 추적 대상은 아니다. |
| `build.noindex/task409-stage4-render/` | 기존 HWP/HWPX renderer 회귀 결과를 보존한다. Git 추적 대상은 아니다. |
| `build.noindex/DerivedDataTask409Stage4Tests/` | ExternalImageTests 결과 bundle을 보존한다. Git 추적 대상은 아니다. |
| source, plist, entitlement | Stage 4에서 최종 변경하지 않았다. sandbox 실험용 임시 변경은 모두 복원했다. |

## Pinned fixture

fixture는 `rhwp-core.lock`이 고정한 다음 upstream commit의 Cargo checkout에서 복사했다.

```text
93862a4e16df59834ebce46d91e948cd739208e9
```

checkout의 실제 `HEAD`가 위 commit과 일치하는지 확인했으며 upstream checkout과 repository sample 원본은 수정하지 않았다.

| Fixture | SHA-256 |
|---------|---------|
| `hwp3-sample10-hwpx.hwpx` | `3395e19bebea8b6689f383df1f4ea1ddb253dee91c4320392cc40e90e2e4f191` |
| `oracle.gif` | `464e863dd2c1650fc6997b03a5d96c9413e61bbabaf7337c783db27203cc2761` |
| `rdb02.gif` | `bfadf4cdbbeeb5f3d8632cb54c8c3696977f405204b651f99a7a24c8f39532cf` |
| `s1.jpg` | `77dea18ce7f8f93b0931e133dec222aec642eef0ed87b8f2031b94dcbea5c514` |

main document의 external reference는 3건이다. valid case에는 세 sibling image를 모두 배치했고, missing case에는 `oracle.gif`을 제외했으며, oversize case에는 한 sibling이 resolver의 resource별 50 MB 상한을 넘도록 구성했다.

## Source-level Preview 통합 결과

Stage 3에서 연결한 `HwpPreviewPDFRenderer.load(fileURL:)` 경로를 standalone Preview smoke로 실행했다.

| Case | Total | Injected | Missing | Too large | Permission denied | Render |
|------|------:|---------:|--------:|----------:|------------------:|--------|
| valid | 3 | 3 | 0 | 0 | 0 | CoreGraphics/SkiaDecode 각 764 pages, `Status: OK` |
| missing | 3 | 2 | 1 | 0 | 0 | CoreGraphics/SkiaDecode 각 764 pages, `Status: OK` |
| oversize | 3 | 2 | 0 | 1 | 0 | CoreGraphics/SkiaDecode 각 764 pages, `Status: OK` |

valid case는 initial unloaded reference 3건을 모두 injection한 뒤 final verification을 통과했다. `alreadyLoaded=0`이므로 세 건 모두 이번 open에서 injection된 결과다. output은 비어 있지 않았다.

| Backend | valid output bytes | missing/oversize output bytes |
|---------|-------------------:|------------------------------:|
| CoreGraphics | 78,200,238 | 78,273,662 |
| SkiaDecode | 59,036,272 | 59,137,709 |

missing과 oversize case도 main document load와 764-page render를 유지했다. 따라서 개별 external resource 실패를 document-fatal error로 승격하지 않는 Stage 2 정책이 실제 fixture에서도 보존됐다.

계획서의 `rg` 예시는 lowercase field 이름을 가정했지만 smoke detail은 `LoadStatus`, `ExternalResourceInjected`처럼 CamelCase를 사용한다. 같은 결과 파일을 `rg -ni`로 다시 검사해 valid의 `total=3`, `injected=3`, `missing=0`과 missing의 `injected=2`, `missing=1`, 양쪽 renderer의 `Status: OK`를 확인했다.

## Registered Quick Look Preview 검증

### 실행 범위

signed temporary app의 실제 active Preview provider를 확인한 뒤 `qlmanage -p`와 Finder Space Preview에서 valid fixture를 열었다. 초기 read-only entitlement 결과가 `permissionDenied=3`이어서 작업지시자 승인 아래 Foundation related-item 접근과 read-write entitlement까지 범위를 확장했다.

| 실험 | 요청 경로 | 결과 |
|------|-----------|------|
| 기존 read-only entitlement, direct sibling read | `qlmanage -p`, Finder | injected 0, permissionDenied 3 |
| `NSFilePresenter`/`NSFileCoordinator`, sibling별 presenter | `qlmanage -p`, Finder | injected 0, permissionDenied 3 |
| same-stem main document와 related image | `qlmanage -p` | injected 0, permissionDenied 3 |
| parent directory presenter/coordinator | `qlmanage -p` | injected 0, permissionDenied 3 |
| read-write entitlement, sibling별 presenter | `qlmanage -p` | injected 0, permissionDenied 3 |
| read-write entitlement, directory presenter | `qlmanage -p` | injected 0, permissionDenied 3 |

모든 실제 provider 요청에서 제품 log는 다음 privacy-safe summary로 수렴했다.

```text
Preview externalResource state=attempted total=3 injected=0 alreadyLoaded=0 missing=0 rejected=0 tooLarge=0 permissionDenied=3 readFailed=0 bridgeFailed=0
```

제품 log에는 original path, candidate absolute path, external basename과 bridge key가 포함되지 않았다. Finder Preview에서도 main document는 graceful fallback으로 계속 표시됐고 extension crash는 없었다.

Foundation 진단에는 다음 sandbox extension 발급 실패가 반복됐다.

```text
NSFileSandboxingRequestRelatedItemExtension: Failed to issue extension
+[NSFileCoordinator addFilePresenter:] could not get a sandbox extension
```

same-stem case에서도 related image의 read capability를 얻지 못했고, main document에 write capability를 요구하는 경로도 거부됐다. directory presenter는 parent directory read capability를 얻지 못했다. 이 관찰을 종합하면 현재 Quick Look host가 extension에 전달한 main document capability는 Foundation related-item sandbox extension을 파생하기에 충분하지 않으며, extension entitlement를 read-write로 넓히는 것만으로 host가 부여하지 않은 capability가 추가되지 않는다.

### 완료 조건 조정

원래 계획의 “actual registered QLExtension에서 valid sibling 3건 injection” 조건은 현재 macOS Quick Look sandbox에서는 충족할 수 없었다. 이를 우회하려면 user-selected folder authorization/security-scoped bookmark, 별도 broker 또는 sandbox 정책 변경처럼 #409의 보안·제품 구조 범위를 넘는 설계가 필요하다.

작업지시자 승인에 따라 Stage 4는 다음 근거로 완료 처리한다.

- Swift/FFI/source-level Preview 경로는 pinned fixture 3건을 정상 injection하고 764-page render를 완료한다.
- actual registered Preview는 sibling 접근 거부를 `permissionDenied=3`으로 분류하고 main render를 중단하지 않는다.
- provider 진단은 path/basename/key를 노출하지 않는다.
- 효과가 없었던 plist/entitlement/Foundation presenter 실험은 제품 변경으로 남기지 않는다.
- 플랫폼 제한과 후속 설계 필요성을 Stage 5 최종 보고서에 인계한다.

## 본문 변경 정도 / 본문 무손실 여부

- Stage 4에는 최종 source, test, script, plist, entitlement 변경이 없다.
- Stage 1~3에서 구현한 Swift wrapper, basename-only resolver, Preview 연결과 privacy-safe log를 그대로 검증했다.
- related-item type declaration, same-stem presenter, directory presenter와 read-write entitlement 실험은 모두 임시 산출물에서 수행했고 tracked source를 `HEAD` 상태로 복원했다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 또는 filesystem resolver 정책을 추가하지 않았다.
- sandbox 해제, broad folder entitlement, temporary absolute-path entitlement, user-selected folder permission 또는 별도 broker를 추가하지 않았다.
- `xcodegen generate`가 만든 `Alhangeul.xcodeproj/project.pbxproj` 변경은 검증 후 복원했으며 커밋하지 않는다.
- `RustBridge`, `rhwp-ffi-symbols.txt`, `rhwp-core.lock`, `Frameworks/Rhwp.xcframework`는 변경되지 않았다.
- 임시 registered provider와 `/Users/melee/Applications/Alhangeul.app`은 제거했고 개발용 launch environment도 해제했다.

## 검증 결과

### Rust artifact, shared boundary와 Xcode project

```bash
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
```

결과: 모두 통과.

- external image setter/query/injection symbol을 포함한 FFI surface와 lock을 확인했다.
- `Rhwp.xcframework` 생성 결과가 lock과 일치했다.
- shared Swift code에 AppKit/UIKit dependency가 없음을 확인했다.
- `xcodegen` 생성 project는 검증에 사용한 뒤 tracked project를 복원했다.
- CoreSimulator 관련 안내는 macOS artifact 결과에 영향을 주지 않는 비차단 warning이었다.

### ExternalImageTests

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme ExternalImageTests \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Stage4Tests \
  CODE_SIGNING_ALLOWED=NO \
  test
```

결과: 통과.

```text
HwpExternalImageResolverTests: 18 tests passed
RhwpDocumentExternalImageBridgeTests: 6 tests passed
Total: 24 tests, 0 failures
** TEST SUCCEEDED **
```

test result bundle:

```text
build.noindex/DerivedDataTask409Stage4Tests/Logs/Test/
Test-ExternalImageTests-2026.07.27_21-14-39-+0900.xcresult
```

첫 sandbox 실행은 Sparkle package 조회 중 GitHub DNS 제한으로 exit 74가 발생했다. 네트워크 접근이 가능한 환경에서 같은 명령을 재실행해 compile/link와 24개 test가 통과했다. source 또는 assertion 실패는 없었다.

### HostApp build

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedDataTask409Stage4 \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과: `** BUILD SUCCEEDED **`.

첫 sandbox 실행의 Sparkle DNS 제한은 ExternalImageTests와 같았고, 동일 명령 재실행에서 HostApp, QLExtension, ThumbnailExtension dependency graph가 모두 build됐다.

### 기존 renderer 회귀

```bash
./scripts/validate-stage3-render.sh \
  build.noindex/task409-stage4-render \
  samples/basic/KTX.hwp \
  samples/basic/request.hwp \
  samples/hwp-img-001.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
```

결과: 다섯 fixture 모두 통과.

| Fixture | First page | Text runs | Hangul runs | Scalars | Non-white pixels |
|---------|------------|----------:|------------:|--------:|-----------------:|
| `KTX.hwp` | 1123×794 | 410 | 76 | 209 | 455,341 |
| `request.hwp` | 567×794 | 102 | 36 | 309 | 70,188 |
| `hwp-img-001.hwp` | 794×1123 | 66 | 35 | 190 | 57,024 |
| `hwp-multi-001.hwp` | 794×1123 | 279 | 113 | 409 | 142,602 |
| `hwpx-01.hwpx` | 794×1123 | 269 | 118 | 440 | 134,090 |

### 등록 위생과 최종 무변경 점검

```bash
./scripts/check-extension-registration-hygiene.sh --check-only
git diff --check
git diff --exit-code -- RustBridge rhwp-ffi-symbols.txt rhwp-core.lock Frameworks
```

결과: 모두 통과.

- development registration, provider app root, legacy candidate와 issue가 없다.
- `build.noindex` 아래 Debug app bundle은 존재하지만 등록되지 않은 검증 산출물이다.
- PlugInKit이 최종 check-only 시점에 Preview/Thumbnail provider path를 보고하지 않아 warning만 남았고, development registration 오염은 없었다.
- whitespace 오류와 core/FFI/framework tracked diff가 없다.

## 잔여 위험

- macOS 26.5.2 Quick Look sandbox에서는 main document와 같은 directory의 external image도 extension이 읽지 못한다. 해당 image는 Preview에서 누락되지만 main document render는 계속된다.
- Foundation related-item API와 read-write entitlement가 향후 macOS에서 다른 결과를 낼 가능성은 있으나, 현재 관찰만으로 지원을 보장할 수 없다.
- sibling injection 자체의 Swift/FFI 계약은 source-level process가 directory read capability를 가진 경우에만 제품과 동일하게 동작한다.
- user-selected folder authorization, security-scoped bookmark, broker 또는 entitlement 정책 변경은 별도 issue의 제품·보안 설계와 검토가 필요하다.
- ThumbnailExtension과 HostApp external image resolution은 #409에서 의도적으로 활성화하지 않았다.
- total external resource memory 상한과 open/read 사이 TOCTOU는 기존 resource별 상한과 containment 검사만 적용된다. 필요하면 후속 issue에서 별도 강화한다.

## 다음 단계 영향

Stage 5는 Stage 1~4 구현과 검증을 최종 보고서로 통합한다.

- status mapping, reference JSON, C string free와 UTF-8/data lifetime을 정리한다.
- basename-only containment, symlink, size, permission과 privacy 정책을 정리한다.
- source-level 3건 injection 성공과 registered Preview의 sandbox `permissionDenied` fallback을 분리해 기록한다.
- Thumbnail #411, fixture suite #412, WKWebView #413, renderer diagnostic #410으로 남긴 책임 경계를 명시한다.
- current Quick Look sibling sandbox 제한, 잔여 TOCTOU와 total-memory risk를 기록한다.
- 최종 검증과 오늘할일 완료 처리는 Stage 5 승인 후 수행한다.

## 승인 요청

Stage 4 `Pinned external fixture와 registered Preview 통합 검증`은 승인된 완료 조건 조정에 따라 완료됐다. Stage 5 `최종 보고서와 후속 handoff`로 진행하려면 작업지시자 승인이 필요하다.
