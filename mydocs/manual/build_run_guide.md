# 빌드 및 실행 가이드

## 목적

이 문서는 개발 중 필요한 빌드/실행/검증 절차를 정리한다. `AGENTS.md`에는 최소 강제 규칙만 유지하고, 상세 명령은 이 문서를 참조한다.

## 초기 설정

```bash
git submodule update --init --recursive
rustup target add aarch64-apple-darwin x86_64-apple-darwin
cargo install cbindgen
brew install xcodegen
```

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

## Xcode 프로젝트 생성

```bash
xcodegen generate
```

`project.yml`이 원본이며 `AlhangeulMac.xcodeproj`를 직접 수정하지 않는다.

## HostApp 빌드

새 worktree에서는 `Vendor/rhwp` submodule과 generated framework가 없을 수 있다. 빌드 전에 다음이 준비되어 있어야 한다.

```bash
git submodule update --init --recursive
./scripts/build-rust-macos.sh
```

`Frameworks/Rhwp.xcframework`는 생성 산출물이며 git에 commit하지 않는다. 새 worktree에서 이 산출물이 없어서 `xcodebuild`가 실패하는 것은 코드 회귀가 아니라 준비 단계 누락이다.

Debug:

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
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
xcodebuild -project AlhangeulMac.xcodeproj \
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

기본 샘플:

- `Vendor/rhwp/samples/basic/KTX.hwp`
- `Vendor/rhwp/samples/basic/request.hwp`
- `Vendor/rhwp/samples/exam_kor.hwp`

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
open build.noindex/DerivedData/Build/Products/Debug/AlhangeulMac.app
```

### 표준 smoke test 흐름

Finder 통합은 signed/sealed된 단일 설치본 기준으로 확인한다. 반복 삭제/재설치를 피하기 위해 표준 경로는 `$HOME/Applications/AlhangeulMac.app` 하나만 사용한다.

```bash
./scripts/package-release.sh 0.1.0

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
APP="$HOME/Applications/AlhangeulMac.app"
mkdir -p "$HOME/Applications"
"$LSREGISTER" -u "$APP" >/dev/null 2>&1 || true
rm -rf "$APP"
ditto build.noindex/release/AlhangeulMac.app "$APP"
"$LSREGISTER" -f -R -trusted "$APP"
pluginkit -a "$APP"
```

앱과 extension의 사용자 표시명은 `Info.plist`와 localized `InfoPlist.strings`에서 제공한다. Finder/Quick Look smoke test용 filesystem bundle path는 ExtensionKit lookup 안정성을 위해 `AlhangeulMac.app`처럼 ASCII 이름을 유지한다.

표시명 현지화 기준:

- 기본 `Info.plist`의 `CFBundleDisplayName`/`CFBundleName`은 실제 bundle filesystem name과 맞춘다. 예: `AlhangeulMac.app`의 기본값은 `AlhangeulMac`이다.
- `ko.lproj/InfoPlist.strings`에서 사용자 표시명 `알한글`을 제공한다.
- `en.lproj/InfoPlist.strings`에서 영어 사용자 표시명 `AlhangeulMac`을 제공한다.
- 각 app/extension bundle의 `Info.plist`에는 `LSHasLocalizedDisplayName`을 명시한다.
- Finder/Spotlight 표시명 문제를 해결하려고 `.app` 또는 `.appex` 디렉터리 자체를 한글로 rename하지 않는다.

extension 등록 확인:

```bash
pluginkit -mAvvv | grep com.postmelee.alhangeulmac
```

Quick Look 캐시 갱신:

```bash
qlmanage -r
qlmanage -r cache
```

preview 확인:

```bash
qlmanage -p Vendor/rhwp/samples/basic/KTX.hwp
```

thumbnail 확인:

```bash
mkdir -p /tmp/alhangeul-ql
qlmanage -t -x -s 512 -o /tmp/alhangeul-ql Vendor/rhwp/samples/basic/KTX.hwp
```

### 반복 시행착오 방지 규칙

- `CODE_SIGNING_ALLOWED=NO` Debug 산출물로 `pluginkit` 등록 여부를 판정하지 않는다.
- Debug/Release 중간 산출물은 `build.noindex/` 아래에 둔다. Spotlight 검색 결과에 `build/DerivedData/.../AlhangeulMac.app` 같은 개발 앱이 보이면 오래된 산출물 오염으로 보고 제거하거나 Spotlight 인덱스를 갱신한다.
- `qlmanage -m plugins`는 app extension 기반 Quick Look/Thumbnail 등록 상태를 직접 반영하지 않을 수 있으므로 실패 판정의 근거로 쓰지 않는다.
- `RhwpMac.app` 또는 `알한글.app` 같은 이전 설치본이 남아 discovery 충돌이 의심될 때만 작업지시자 승인 후 제거한다.
- 동일 검증 중에는 설치 후보를 `$HOME/Applications/AlhangeulMac.app` 하나로 고정한다.
- `pluginkit`에 나타나지 않으면 먼저 `codesign -dv`, `plutil -p Contents/Info.plist`, `find ... InfoPlist.strings`로 산출물 상태를 확인한다. 바로 삭제/재설치를 반복하지 않는다.
- Spotlight/Dock/Finder 표시명은 현재 사용자 언어와 LaunchServices/Spotlight 캐시 영향을 받는다. 표시명 문제를 extension 실행 실패와 혼동하지 않는다. 다만 기본 `Info.plist` 표시명이 실제 bundle filesystem name과 불일치하면 localized 표시명이 선택되지 않을 수 있으므로 먼저 plist와 `InfoPlist.strings` 구조를 확인한다.
