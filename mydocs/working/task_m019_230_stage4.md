# Task M019 #230 Stage 4 완료보고서

## 단계 목적

Rust core static link 중복을 줄이는 shared 구조와 strip/LTO/build setting 후보를 구현 없이 검토하고, local-only 측정값과 required validation을 정리했다.

이번 단계는 제품 source, `project.yml`, release script, policy 문서를 수정하지 않았다. 모든 build/DMG 후보는 `build.noindex/task230/` 아래 local-only 산출물이다.

## 산출물

- `mydocs/working/task_m019_230_stage4.md`
  - Rust core 공유 구조, build setting 후보, 측정값, 검증 비용을 기록한 신규 단계 보고서
- local-only 측정 산출물
  - `build.noindex/task230/DerivedData-universal-deadstrip-only/`
  - `build.noindex/task230/DerivedData-universal-strip-settings/`
  - `build.noindex/task230/rust-lto-strip-target/`
  - `build.noindex/task230/dmg-sim-universal-deadstrip-only/`
  - `build.noindex/task230/dmg-sim-universal-deadstrip/`
  - `build.noindex/task230/dmg-sim-universal-stripx/`
  - `build.noindex/task230/strip-sim-stage4/`

## 본문 변경 정도 / 본문 무손실 여부

- 신규 단계 보고서 1건만 추가했다.
- 제품 code, XcodeGen source, RustBridge source, release script, release policy, Homebrew Cask는 수정하지 않았다.
- `Alhangeul.xcodeproj`는 수정하지 않았다.
- generated build 산출물과 DMG 후보는 commit 대상이 아니다.

## 현재 Rust bridge/link 구조

확인한 사실:

- `RustBridge/Cargo.toml`의 library type은 `crate-type = ["staticlib"]`이다.
- `scripts/build-rust-macos.sh`는 arm64/x86_64 staticlib를 각각 만들고 `xcrun lipo -create`로 `Frameworks/universal/librhwp.a`를 만든다.
- `xcodebuild -create-xcframework -library ... -headers ...`로 static library 기반 `Frameworks/Rhwp.xcframework`를 만든다.
- `project.yml`에서 HostApp, QLExtension, ThumbnailExtension은 모두 `Frameworks/Rhwp.xcframework`를 `embed: false`로 링크한다.
- `otool -L` 기준 app/extension 실행 파일은 `Rhwp` dynamic dependency를 갖지 않는다. Rust code는 각 실행 파일에 정적으로 포함된다.

Staticlib 크기:

| artifact | bytes | KiB |
|----------|-------|-----|
| `RustBridge/target/aarch64-apple-darwin/release/librhwp_mac_bridge.a` | `52817240` | `51579` |
| `RustBridge/target/x86_64-apple-darwin/release/librhwp_mac_bridge.a` | `54302832` | `53030` |
| `Frameworks/universal/librhwp.a` | `107120120` | `104610` |
| `Frameworks/Rhwp.xcframework` | - | `104624` |

현재 universal 실행 파일 크기:

| executable | bytes |
|------------|-------|
| HostApp `Alhangeul` | `53366456` |
| Quick Look `AlhangeulPreview` | `51450544` |
| Thumbnail `AlhangeulThumbnail` | `51519344` |
| 합계 | `156336344` |

해석:

- 세 실행 파일 합계 약 `149.1 MiB` 중 대부분은 Rust staticlib에서 온 native code와 link metadata로 보인다.
- shared Rust dynamic framework가 동작한다면 이론상 세 실행 파일에 반복되는 Rust-heavy payload를 한 번만 배치할 수 있다.
- 다만 각 실행 파일은 Swift/extension entry, system framework link, Swift metadata를 유지해야 하고, shared framework 자체의 bundle/signing overhead가 생기므로 `Preview + Thumbnail 실행 파일 전체 크기`를 그대로 절감량으로 볼 수 없다.
- 현재 상태만 기준으로 한 보수적 upper bound는 universal app bundle에서 약 `70-100 MiB` uncompressed 절감 가능성이다. DMG 압축 후 절감은 이보다 낮다.
- Stage 4 build setting 측정에서 `DEAD_CODE_STRIPPING=YES`가 이미 중복 native code를 크게 제거했기 때문에, 그 후보를 적용한 뒤에는 dynamic framework 전환의 추가 절감 여지가 크게 줄어든다.

## RPATH와 dynamic/shared framework 후보

현재 `LC_RPATH`:

| target | 주요 rpath |
|--------|------------|
| HostApp | `/usr/lib/swift`, `@executable_path/../Frameworks` |
| QLExtension | `/usr/lib/swift`, `@executable_path/../Frameworks`, `@executable_path/../../../../Frameworks` |
| ThumbnailExtension | `/usr/lib/swift`, `@executable_path/../Frameworks`, `@executable_path/../../../../Frameworks` |

관찰:

- app extension 실행 파일에는 parent app의 `Contents/Frameworks`를 가리키는 rpath가 이미 있다.
- 따라서 `Alhangeul.app/Contents/Frameworks/Rhwp.framework` 하나를 HostApp에 embed하고, extension은 `@executable_path/../../../../Frameworks`를 통해 load하는 구조가 후보가 될 수 있다.
- 하지만 현재 project는 static `Rhwp.xcframework`를 `embed: false`로 링크하므로, 이 후보는 RustBridge 산출물 형식과 XcodeGen dependency 구조 변경이 필요하다.

필요한 구조 변경 후보:

1. `RustBridge` 산출물 형식 변경
   - `crate-type = ["cdylib"]` 또는 `["staticlib", "cdylib"]` 후보 검토
   - per-arch dylib build, install name/rpath 설정, universal framework 또는 dynamic XCFramework packaging
   - `cbindgen` header/modulemap 유지
2. `project.yml` dependency 변경
   - HostApp은 `Rhwp.framework`를 embed/sign
   - QLExtension/ThumbnailExtension은 link만 하고 embed하지 않는 후보
   - extension 단독 scheme build/debug 시 parent app framework가 없는 문제 보완
3. release signing/notarization 변경
   - `Rhwp.framework`를 app bundle signing 전에 먼저 sign
   - app extension, Sparkle framework, Rhwp framework, app bundle 순서 재검토
   - `codesign --verify --deep --strict`, `spctl`, `xcrun stapler validate` 검증 추가
4. Sparkle update 검증
   - update archive에 nested `Rhwp.framework`가 포함되고 signature가 유지되는지 확인
   - Sparkle update 후 Quick Look/Thumbnail extension이 parent framework를 load하는지 smoke

필수 검증 범위:

- HostApp viewer open
- HostApp PDF export/print path
- Quick Look preview path
- Finder thumbnail path
- clean install smoke
- ad-hoc signed smoke
- Developer ID signed + notarized app/DMG smoke
- Sparkle update 후 extension refresh smoke
- Intel Mac 또는 x86_64 실행 환경 smoke

Stage 4 판단:

- shared dynamic Rust core는 구조적으로 검토할 가치가 있지만 `v0.1.x` 즉시 적용 후보로는 고위험이다.
- `DEAD_CODE_STRIPPING=YES`가 동등하거나 더 큰 절감 효과를 보였기 때문에, dynamic framework 전환은 먼저 build setting 최적화 적용 가능성을 검증한 뒤 재평가하는 편이 낫다.

## 현재 Release build setting

`xcodebuild -showBuildSettings`로 확인한 HostApp/QLExtension/ThumbnailExtension Release 후보의 공통 핵심값:

| setting | current |
|---------|---------|
| `SWIFT_OPTIMIZATION_LEVEL` | `-O` |
| `SWIFT_COMPILATION_MODE` | `wholemodule` |
| `STRIP_INSTALLED_PRODUCT` | `YES` |
| `DEPLOYMENT_POSTPROCESSING` | `NO` |
| `COPY_PHASE_STRIP` | `NO` |
| `DEAD_CODE_STRIPPING` | `NO` |
| `MACH_O_TYPE` | `mh_execute` |

해석:

- `STRIP_INSTALLED_PRODUCT=YES`가 있어도 `DEPLOYMENT_POSTPROCESSING=NO`라서 일반 local Release build에서는 product strip 단계가 충분히 적용되지 않는다.
- 더 큰 차이는 linker의 `-dead_strip` 유무다. `DEAD_CODE_STRIPPING=YES` build에서는 link command에 `-Xlinker -dead_strip`이 들어갔다.

## Build setting 후보 측정

### 후보 A: 수동 `strip -S`

Stage 2 universal 실행 파일 복사본에 `xcrun strip -S`를 적용했다.

| executable | before bytes | after bytes | 절감 bytes | 절감률 |
|------------|--------------|-------------|------------|--------|
| HostApp | `53366456` | `52611664` | `754792` | `1.41%` |
| Preview | `51450544` | `50915704` | `534840` | `1.04%` |
| Thumbnail | `51519344` | `50981648` | `537696` | `1.04%` |
| 합계 | `156336344` | `154509016` | `1827328` | `1.17%` |

판단:

- 단독 효과가 작다.
- 별도 적용 가치는 낮다.

### 후보 B: 수동 `strip -x`

Stage 2 universal 실행 파일 복사본에 `xcrun strip -x`를 적용했다.

| executable | before bytes | after bytes | 절감 bytes | 절감률 |
|------------|--------------|-------------|------------|--------|
| HostApp | `53366456` | `43585768` | `9780688` | `18.33%` |
| Preview | `51450544` | `42717760` | `8732784` | `16.97%` |
| Thumbnail | `51519344` | `42750544` | `8768800` | `17.02%` |
| 합계 | `156336344` | `129054072` | `27282272` | `17.45%` |

local-only DMG 비교:

| candidate | DMG bytes | universal local-only 대비 |
|-----------|-----------|---------------------------|
| current universal local-only | `92949438` | - |
| manual `strip -x` local-only | `88243712` | `4705726 bytes`, `5.1%` 절감 |

판단:

- 실행 파일에서는 눈에 띄지만 DMG 압축 후 절감은 제한적이다.
- crash symbolication/debuggability 영향이 있으므로 단독 수동 strip 후보로 권고하기 어렵다.

### 후보 C: `DEAD_CODE_STRIPPING=YES`

실행 명령:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath build.noindex/task230/DerivedData-universal-deadstrip-only \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  DEAD_CODE_STRIPPING=YES \
  build
```

결과:

- build 통과
- 세 실행 파일 모두 universal slice 유지
- app bundle: `192300 KiB` -> `80424 KiB`
- 실행 파일 합계: `156336344 bytes` -> `41772344 bytes`

| executable | current bytes | `DEAD_CODE_STRIPPING=YES` bytes | 절감 bytes | 절감률 |
|------------|---------------|----------------------------------|------------|--------|
| HostApp | `53366456` | `15173256` | `38193200` | `71.6%` |
| Preview | `51450544` | `13239424` | `38211120` | `74.3%` |
| Thumbnail | `51519344` | `13359664` | `38159680` | `74.1%` |
| 합계 | `156336344` | `41772344` | `114564000` | `73.3%` |

local-only DMG 비교:

| candidate | DMG bytes | current universal 대비 |
|-----------|-----------|------------------------|
| current universal local-only | `92949438` | - |
| `DEAD_CODE_STRIPPING=YES` local-only | `50425282` | `42524156 bytes`, `45.7%` 절감 |

판단:

- 현재까지 가장 강한 저구조변경 후보이다.
- arch별 DMG split보다 운영 표면 변경이 작고, universal 단일 DMG 정책을 유지할 수 있다.
- 다만 Rust/Swift FFI 경로가 실제 문서 렌더링에서 모두 정상인지 smoke가 필요하다. build/link 성공만으로 기능 보존을 단정하지 않는다.

### 후보 D: `DEAD_CODE_STRIPPING=YES` + postprocessing strip

실행 명령:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath build.noindex/task230/DerivedData-universal-strip-settings \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  DEPLOYMENT_POSTPROCESSING=YES \
  COPY_PHASE_STRIP=YES \
  DEAD_CODE_STRIPPING=YES \
  build
```

결과:

- build 통과
- 세 실행 파일 모두 universal slice 유지
- app bundle: `192300 KiB` -> `71200 KiB`
- 실행 파일 합계: `156336344 bytes` -> `32329784 bytes`

| executable | current bytes | postprocessing 후보 bytes | 절감 bytes | 절감률 |
|------------|---------------|----------------------------|------------|--------|
| HostApp | `53366456` | `10714376` | `42652080` | `79.9%` |
| Preview | `51450544` | `10774816` | `40675728` | `79.1%` |
| Thumbnail | `51519344` | `10840592` | `40678752` | `79.0%` |
| 합계 | `156336344` | `32329784` | `124006560` | `79.3%` |

local-only DMG 비교:

| candidate | DMG bytes | current universal 대비 |
|-----------|-----------|------------------------|
| current universal local-only | `92949438` | - |
| `DEAD_CODE_STRIPPING=YES` local-only | `50425282` | `45.7%` 절감 |
| `DEAD_CODE_STRIPPING=YES` + postprocessing local-only | `48835652` | `47.5%` 절감 |

판단:

- `DEAD_CODE_STRIPPING=YES` 단독 대비 추가 DMG 절감은 약 `1589630 bytes`다.
- 추가 절감은 작고 symbol/debuggability 영향은 더 커질 수 있다.
- 우선순위는 `DEAD_CODE_STRIPPING=YES` 단독 검증이 먼저다. postprocessing strip은 후순위 후보로 둔다.

## Rust release profile 후보

소스 변경 없이 별도 Cargo target directory에서 다음 profile을 env override로 측정했다.

```bash
CARGO_TARGET_DIR=build.noindex/task230/rust-lto-strip-target \
CARGO_PROFILE_RELEASE_LTO=fat \
CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1 \
CARGO_PROFILE_RELEASE_PANIC=abort \
CARGO_PROFILE_RELEASE_STRIP=symbols \
cargo build --release --manifest-path RustBridge/Cargo.toml --target aarch64-apple-darwin --locked
```

x86_64도 같은 조건으로 빌드했다.

| artifact | current bytes | profile 후보 bytes | 절감률 |
|----------|---------------|---------------------|--------|
| arm64 staticlib | `52817240` | `10581728` | `80.0%` |
| x86_64 staticlib | `54302832` | `10823776` | `80.1%` |
| universal staticlib | `107120120` | `21405552` | `80.0%` |

FFI 공개 심볼 확인:

- current staticlib와 profile 후보 staticlib 모두 `rhwp-ffi-symbols.txt`의 `rhwp_*` 심볼을 유지했다.

판단:

- `Frameworks/universal/librhwp.a` 자체의 lock artifact 크기는 크게 줄일 수 있다.
- 그러나 staticlib archive는 public app bundle에 그대로 배포되지 않는다. 실제 사용자 체감 크기는 app link 결과와 DMG 압축 후 크기로 판단해야 한다.
- `DEAD_CODE_STRIPPING=YES`가 final executable에서 이미 큰 절감을 만들었으므로, Rust profile 최적화는 dead strip 적용 후 추가 효과를 별도 full app build로 검증해야 한다.
- `panic=abort`, `strip=symbols`, `lto=fat`은 crash 분석, build time, Rust panic 진단, byte-for-byte lock 안정성에 영향을 줄 수 있어 저위험 즉시 적용으로 분류하지 않는다.

## 후보 분류

| 후보 | 측정 효과 | 구조 변경 | 운영 리스크 | Stage 4 분류 |
|------|-----------|-----------|-------------|--------------|
| `DEAD_CODE_STRIPPING=YES` | DMG `45.7%` 절감 | 낮음 | 기능 smoke 필요 | 우선 검증 후보 |
| `DEAD_CODE_STRIPPING=YES` + postprocessing strip | DMG `47.5%` 절감 | 낮음-중간 | symbol/debuggability 영향 증가 | 후순위 검증 후보 |
| manual `strip -S` | 실행 파일 합계 `1.17%` 절감 | 낮음 | 효과 작음 | 비권고 |
| manual `strip -x` | DMG `5.1%` 절감 | 낮음 | symbol/debuggability 영향 | 비권고 또는 후순위 |
| Rust LTO/codegen/panic/strip profile | staticlib artifact `80.0%` 절감 | 중간 | build time, lock, symbolication 영향 | 후속 검증 후보 |
| shared dynamic Rust framework | theoretical app bundle `70-100 MiB` 후보 | 높음 | rpath/signing/notarization/Sparkle/extension smoke | v0.1.x 즉시 적용 비권고 |

## Stage 4 결론

- 이슈 #230의 핵심 원인은 arch split 자체보다 `DEAD_CODE_STRIPPING=NO` 상태에서 Rust staticlib의 미사용 code가 세 실행 파일에 크게 남는 점이 더 크다.
- `DEAD_CODE_STRIPPING=YES`만으로도 단일 universal DMG 정책을 유지하면서 local-only DMG 기준 `45.7%` 절감 후보가 확인됐다.
- arch별 DMG split은 Stage 3 기준 `29.6-31.6%` 절감이었으므로, 현 시점에서는 `DEAD_CODE_STRIPPING=YES` 검증이 arch별 DMG 전환보다 우선순위가 높다.
- shared dynamic Rust framework는 설계 후보로 남기되, build setting 최적화를 먼저 검증한 뒤에도 용량 문제가 남을 때 별도 task로 분리하는 편이 합리적이다.
- Rust profile 최적화는 staticlib artifact에는 매우 효과적이지만, final app/DMG 기준 추가 효과를 별도 full build로 확인해야 한다.

## 검증 결과

구현계획서 Stage 4 검증 명령과 추가 측정 명령을 실행했다.

```bash
stat -f "%N %z" Frameworks/universal/librhwp.a
find build.noindex/task230 -path "*/Alhangeul.app/Contents/MacOS/Alhangeul" -print -exec stat -f "%N %z" {} \;
find build.noindex/task230 -path "*/AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview" -print -exec stat -f "%N %z" {} \;
find build.noindex/task230 -path "*/AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail" -print -exec stat -f "%N %z" {} \;
rg -n --glob '!RustBridge/target/**' "staticlib|lto|panic|strip|crate-type|Rhwp.xcframework|librhwp" RustBridge Frameworks scripts mydocs/tech mydocs/manual project.yml
xcodebuild -showBuildSettings -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -derivedDataPath build.noindex/task230/DerivedData-universal
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -destination "generic/platform=macOS" -derivedDataPath build.noindex/task230/DerivedData-universal-deadstrip-only ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO DEAD_CODE_STRIPPING=YES build
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -destination "generic/platform=macOS" -derivedDataPath build.noindex/task230/DerivedData-universal-strip-settings ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO DEPLOYMENT_POSTPROCESSING=YES COPY_PHASE_STRIP=YES DEAD_CODE_STRIPPING=YES build
hdiutil verify build.noindex/task230/dmg-sim-universal-deadstrip-only/alhangeul-macos-0.1.1-universal-deadstrip-only-local-only.dmg
hdiutil verify build.noindex/task230/dmg-sim-universal-deadstrip/alhangeul-macos-0.1.1-universal-deadstrip-local-only.dmg
git diff --check -- mydocs/working/task_m019_230_stage4.md
```

결과:

- staticlib/executable 크기 측정: 통과
- current `otool -L`/`LC_RPATH` 확인: 통과
- Release build setting 확인: 통과
- `DEAD_CODE_STRIPPING=YES` local-only build: 통과
- `DEAD_CODE_STRIPPING=YES` + postprocessing local-only build: 통과
- local-only DMG 생성/verify: 통과
- Rust profile 후보 build: arm64/x86_64 통과
- Rust profile 후보 FFI 심볼 확인: 통과
- 보고서 `git diff --check`: 통과

## 잔여 위험

- `DEAD_CODE_STRIPPING=YES` 후보는 build/link와 DMG verify만 확인했다. 실제 문서 rendering, PDF export, Quick Look preview, Thumbnail smoke는 아직 수행하지 않았다.
- public signed/notarized DMG, Gatekeeper, Sparkle update 후 extension refresh는 검증하지 않았다.
- local-only unsigned build에서의 절감률이 public signed/notarized 산출물과 byte-for-byte 같다고 볼 수 없다.
- Rust profile 후보는 staticlib artifact만 측정했고, 해당 optimized staticlib를 실제 app link에 적용한 full app build는 수행하지 않았다.
- `DEAD_CODE_STRIPPING=YES`가 core의 lazy/path-dependent code를 잘못 제거할 가능성은 낮아 보이지만, HWP/HWPX sample set 기반 기능 smoke 전에는 적용 완료로 볼 수 없다.
- postprocessing strip은 dSYM/symbolication 정책과 함께 검토해야 한다.

## 다음 단계 영향

Stage 5에서는 Stage 1-4 결과를 종합해 `v0.1.x` 권고안을 정리한다.

우선순위:

1. `DEAD_CODE_STRIPPING=YES`를 별도 후속 구현 후보 1순위로 둔다.
2. arch별 DMG split은 운영 표면 변경이 크므로 후순위로 둔다.
3. shared dynamic Rust framework는 build setting 최적화 후에도 문제가 남을 때 별도 구조 변경 task로 분리한다.
4. Rust LTO/strip profile은 full app build와 기능 smoke를 포함하는 후속 검증 후보로 둔다.

## 승인 요청

Stage 4 결과를 승인하면 Stage 5 `권고안, 최종 검증, 보고`로 진행한다.
