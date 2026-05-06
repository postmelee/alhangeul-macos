# 빌드 및 실행 가이드

## 목적

이 문서는 개발 중 필요한 빌드/실행/검증 절차를 정리한다. `AGENTS.md`에는 최소 강제 규칙만 유지하고, 상세 명령은 이 문서를 참조한다.

## 먼저 읽을 문서

새로 프로젝트에 들어온 개발자는 다음 순서로 읽는다.

1. `README.md`의 `Project Structure`: 저장소 최상위 구조와 현재 Demo/Preview release 기준
2. `mydocs/tech/project_architecture.md`: 제품 타깃, 공통 Swift 계층, Rust bridge, generated artifact 경계
3. `Sources/README.md`: `Sources/` 아래 macOS 제품 타깃과 공통 Swift 계층의 역할
4. `RustBridge/README.md`: Rust FFI crate, generated `Rhwp.xcframework`, lock 파일 관계
5. 이 문서의 build/run 명령

## 기본 실행 순서

새 checkout 또는 새 worktree에서 기본 순서는 다음과 같다.

1. 개발 도구와 Rust target을 준비한다.
2. `./scripts/build-rust-macos.sh`로 `Frameworks/Rhwp.xcframework`를 생성한다.
3. `xcodegen generate`로 `Alhangeul.xcodeproj`를 생성한다.
4. `xcodebuild`로 `HostApp`을 build한다.
5. `./scripts/check-no-appkit.sh`와 render smoke test로 문서 렌더 경계를 확인한다.
6. Finder/Quick Look/Thumbnail 통합은 signed/sealed된 Release package 산출물 기준으로 별도 확인한다.

## 초기 설정

현재 core dependency는 `RustBridge/Cargo.toml`의 `edwardkim/rhwp` git dependency로 고정한다. `RustBridge/Cargo.lock`은 Cargo가 해석한 실제 source commit을, `rhwp-core.lock`은 배포 provenance와 산출물 hash/size를 기록한다.

```bash
rustup target add aarch64-apple-darwin x86_64-apple-darwin
cargo install cbindgen
brew install xcodegen
```

## Core dependency 모드

현재 기본 개발 흐름은 `RustBridge/Cargo.toml`의 `edwardkim/rhwp` git dependency와 `RustBridge/Cargo.lock`, `rhwp-core.lock`을 함께 검증한다. 현재 v0.1.0 목표는 Demo/Preview release이며, 기본 업데이트 경로는 `--channel demo --rev`다.

채널별 dependency/lock 기준과 compatibility gate 상세는 [`core_release_compatibility.md`](../tech/core_release_compatibility.md)를 따른다.

core 업데이트는 다음 형태로 분리한다.

```bash
./scripts/update-rhwp-core.sh --channel demo --rev <commit-sha>
./scripts/update-rhwp-core.sh --channel stable --tag <release-tag>
```

첫 번째는 prerelease 성격의 Demo/Preview 기준이고, 두 번째는 정식 Stable 기준이다. 두 경우 모두 branch나 floating ref는 사용하지 않는다.

## Rust bridge 및 XCFramework

```bash
./scripts/build-rust-macos.sh
```

이 스크립트가 수행하는 일:

- `RustBridge` staticlib arm64/x86_64 빌드
- `lipo`로 universal staticlib 생성
- `cbindgen`으로 C header 생성
- `rhwp-ffi-symbols.txt`와 생성 심볼 비교
- `Frameworks/Rhwp.xcframework` 생성

일반 build는 `rhwp-core.lock`을 수정하지 않는다. core commit 또는 Rust bridge 산출물을 lock에 반영해야 할 때만 명시적으로 update 모드를 사용한다.

```bash
./scripts/build-rust-macos.sh --update-lock
```

lock과 현재 산출물의 일치 여부만 확인할 때는 verify 모드를 사용한다.

```bash
./scripts/build-rust-macos.sh --verify-lock
```

검증 대상:

- `RustBridge/Cargo.toml`의 `rhwp` repo/ref
- `RustBridge/Cargo.lock`의 `rhwp` source commit
- `rhwp-core.lock`의 repo/ref kind/release tag/commit
- `Frameworks/universal/librhwp.a` sha256/size
- `Frameworks/generated_rhwp.h` sha256/size

불일치 유형은 `Cargo.lock mismatch`, `artifact hash mismatch`, `FFI symbol diff`로 분리해 기록한다.

## Xcode 프로젝트 생성

```bash
xcodegen generate
```

`project.yml`이 원본이며 `Alhangeul.xcodeproj`를 직접 수정하지 않는다.

## HostApp 빌드

새 worktree에서는 generated framework가 없을 수 있다. 빌드 전에 Rust bridge 산출물이 준비되어 있어야 한다.

```bash
./scripts/build-rust-macos.sh
```

`Frameworks/Rhwp.xcframework`는 생성 산출물이며 git에 commit하지 않는다. 새 worktree에서 이 산출물이 없어서 `xcodebuild`가 실패하는 것은 코드 회귀가 아니라 준비 단계 누락이다.

첫 Rust bridge build에서 Cargo가 `edwardkim/rhwp`를 fetch할 수 있다. 네트워크 실패는 core compatibility 실패가 아니라 dependency fetch failure로 분리해 기록한다.

Debug:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Debug 빌드는 compile/link 확인용이다. `CODE_SIGNING_ALLOWED=NO` 산출물은 `Info.plist`와 resource sealing이 PlugInKit registration smoke test에 충분하지 않을 수 있으므로 Finder Quick Look/Thumbnail 등록 검증에 사용하지 않는다.

개발 build 산출물은 Spotlight 앱 검색 후보에 섞이지 않도록 `build.noindex/` 아래에 둔다. `build/DerivedData`처럼 일반 디렉터리 아래에 `.app`을 만들면 Spotlight가 개발 산출물을 별도 앱으로 인덱싱해 표준 설치본과 경쟁할 수 있다.

Release:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath build.noindex/DerivedDataRelease \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 렌더링 smoke test

```bash
./scripts/validate-stage3-render.sh
```

역할:

- 기본 샘플에서 `RhwpDocument` open, page count, render tree 생성, page size 조회가 가능한지 확인한다.
- render tree에 text run과 한글 text run이 있는지 확인한다.
- CoreText glyph lookup에서 한글 glyph가 빠지지 않는지 확인한다.
- `CGTreeRenderer`로 첫 페이지 native PNG를 만들고, 완전히 빈 bitmap이 아닌지 확인한다.

기본 출력 위치는 `output/stage3-render/`다. 첫 번째 인자로 출력 디렉터리를 바꾸고, 그 뒤에 샘플 파일을 나열하면 특정 파일만 smoke 확인할 수 있다.

```bash
./scripts/validate-stage3-render.sh output/stage3-render-custom path/to/sample.hwp
```

사용법만 확인할 때는 Rust bridge 산출물 없이도 다음 명령을 사용할 수 있다.

```bash
./scripts/validate-stage3-render.sh --help
```

기본 샘플:

- `samples/basic/KTX.hwp`
- `samples/basic/request.hwp`
- `samples/exam_kor.hwp`

기본 render smoke fixture는 앱 저장소 루트의 `samples/`가 소유한다. core 저장소 내부 샘플 경로는 기본 검증 경로로 사용하지 않는다.

이 smoke test는 최소 회귀 관문이다. 통과해도 한컴 viewer 또는 rhwp core SVG와의 시각 정합성을 보장하지 않는다. 특정 문서에서 본문, 표, 도형, 이미지가 빠지거나 위치가 어긋나 보이면 다음의 core/native 렌더 비교 디버깅으로 넘어간다.

renderer 변경 작업에서는 기본 smoke test에 더해 해당 task 문서에서 정한 대표 샘플 smoke/diff를 추가 수행한다.

```bash
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task-smoke path/to/representative-sample.hwp
```

기능별 대표 샘플은 수행계획서, 구현계획서, tech 문서, 단계 보고서 중 하나에 task 범위로 남긴다. `NativeNonWhitePixels`, `CoreSVGBytes`, `DiffReason` 같은 summary 기록 기준과 산출물 보관 규칙은 [`render_core_native_compare_guide.md`](render_core_native_compare_guide.md)를 따른다.

## core/native 렌더 비교 디버깅

특정 파일에서 앱 native renderer와 rhwp core SVG 결과가 다른지 확인할 때:

```bash
./scripts/render-debug-compare.sh output/render-debug path/to/sample.hwp
```

이 스크립트는 render tree JSON, rhwp core SVG, native renderer PNG, summary를 생성한다. `qlmanage`가 동작하는 환경에서는 core SVG raster PNG와 pixel diff PNG도 선택적으로 생성한다.

사용 시점:

- `validate-stage3-render.sh`는 통과했지만 특정 문서의 시각 결과가 이상할 때
- rhwp core SVG에는 보이는 내용이 native PNG에는 빠질 때
- render tree JSON에 필요한 node, transform, clipping, image id, text style이 있는지 확인해야 할 때
- renderer 수정 전후 같은 문서에서 차이가 줄었는지 비교 자료를 남겨야 할 때

상세 절차와 판단 기준은 [`render_core_native_compare_guide.md`](render_core_native_compare_guide.md)를 따른다.

## Shared Swift bridge 검사

```bash
./scripts/check-no-appkit.sh
```

`Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 넣지 않는다.

## Finder 통합 확인

### 목적 분리

Finder 통합 검증은 세 계층을 분리한다.

| 목적 | 권장 산출물 | 확인 도구 |
|------|------------|-----------|
| compile/link 확인 | Debug build | `xcodebuild` |
| bundle resource 포함 확인 | Debug 또는 Release build | `find`, `plutil` |
| LaunchServices/PlugInKit/Quick Look 실행 확인 | Release package 산출물 | `lsregister`, `pluginkit`, `qlmanage -t` |

앱 실행만 확인할 때는 Debug 산출물을 바로 열 수 있다.

```bash
open build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app
```

## HostApp WKWebView viewer smoke test

WKWebView 기반 HostApp viewer 경로를 바꾼 경우에는 Debug build 후 다음 항목을 확인한다.

1. app bundle에 `rhwp-studio` 정적 asset이 포함되어 있어야 한다.
2. HWP 샘플을 Debug app으로 열었을 때 `Alhangeul` 프로세스와 앱 창이 유지되어야 한다.
3. HWPX 샘플을 같은 Debug app으로 열었을 때 프로세스와 앱 창이 유지되어야 한다.

기본 확인 명령:

```bash
test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/index.html
test -f build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app/Contents/Resources/rhwp-studio/assets/rhwp_bg-BZNodj2e.wasm
scripts/verify-rhwp-studio-assets.sh
/usr/bin/open -n -a /absolute/path/to/Alhangeul.app /absolute/path/to/samples/basic/KTX.hwp
/usr/bin/open -a /absolute/path/to/Alhangeul.app /absolute/path/to/samples/hwpx/hwpx-01.hwpx
pgrep -x Alhangeul
/usr/bin/osascript -e 'tell application "System Events" to tell process "Alhangeul" to get name of windows'
```

`/absolute/path/to/Alhangeul.app`은 현재 worktree의 `build.noindex/DerivedData/Build/Products/Debug/Alhangeul.app`로 바꾼다. 이 smoke는 local launch, document open handoff, WKWebView bundle resource 연결의 최소 확인이다. 실제 문서 내용의 시각 정합성은 foreground 앱에서 수동 확인하거나 별도 UI 자동화로 보강한다.

### 표준 smoke test 흐름

Finder 통합은 signed/sealed된 단일 설치본 기준으로 확인한다. 반복 삭제/재설치를 피하기 위해 표준 경로는 `$HOME/Applications/Alhangeul.app` 하나만 사용한다.

```bash
./scripts/package-release.sh 0.1.0

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
APP="$HOME/Applications/Alhangeul.app"
mkdir -p "$HOME/Applications"
"$LSREGISTER" -u "$APP" >/dev/null 2>&1 || true
rm -rf "$APP"
ditto build.noindex/release/Alhangeul.app "$APP"
"$LSREGISTER" -f -R -trusted "$APP"
pluginkit -a "$APP"
```

앱과 extension의 사용자 표시명은 `Info.plist`와 localized `InfoPlist.strings`에서 제공한다. Finder/Quick Look smoke test용 filesystem bundle path는 ExtensionKit lookup 안정성을 위해 `Alhangeul.app`처럼 ASCII 이름을 유지한다.

표시명 현지화 기준:

- 기본 `Info.plist`의 `CFBundleDisplayName`/`CFBundleName`은 실제 bundle filesystem name과 맞춘다. 예: `Alhangeul.app`의 기본값은 `Alhangeul`이다.
- `ko.lproj/InfoPlist.strings`에서 사용자 표시명 `알한글`을 제공한다.
- `en.lproj/InfoPlist.strings`에서 영어 사용자 표시명 `Alhangeul`을 제공한다.
- 각 app/extension bundle의 `Info.plist`에는 `LSHasLocalizedDisplayName`을 명시한다.
- Finder/Spotlight 표시명 문제를 해결하려고 `.app` 또는 `.appex` 디렉터리 자체를 한글로 rename하지 않는다.

extension 등록 확인:

```bash
pluginkit -mAvvv | grep com.postmelee.alhangeul
```

Quick Look 캐시 갱신:

```bash
qlmanage -r
qlmanage -r cache
```

preview 확인:

```bash
qlmanage -p samples/basic/KTX.hwp
```

thumbnail 확인:

```bash
mkdir -p /tmp/alhangeul-ql
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql samples/basic/KTX.hwp
```

### 반복 시행착오 방지 규칙

핵심 3개:

- `CODE_SIGNING_ALLOWED=NO` Debug 산출물로 `pluginkit` 등록 여부를 판정하지 않는다.
- Debug/Release 중간 산출물은 `build.noindex/` 아래에 둔다. Spotlight 검색 결과에 `build/DerivedData/.../Alhangeul.app` 같은 개발 앱이 보이면 오래된 산출물이 남은 상태로 보고 제거하거나 Spotlight 인덱스를 갱신한다.
- 동일 검증 중에는 설치 후보를 `$HOME/Applications/Alhangeul.app` 하나로 고정한다.

`qlmanage -m plugins` 미노출 처리, `pluginkit -mAvvv` 미노출 시 진단 순서, 이전 이름(`RhwpMac.app`, `알한글.app`) 설치본 처리, 표시명 문제와 extension 실패 혼동 방지 등 추가 진단 기준은 [`finder_integration_validation_pitfalls.md`](../troubleshootings/finder_integration_validation_pitfalls.md)를 따른다.
