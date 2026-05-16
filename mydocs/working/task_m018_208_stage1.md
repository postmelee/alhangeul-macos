# Task M018 #208 Stage 1 보고서

## 단계 목적

Intel Mac 지원과 다운로드 안내 보강 전에 현재 release/package build 동작, 산출물 architecture, GitHub runner 제약, Pages direct download 구조를 재검증한다. 이 단계에서는 구현 파일을 수정하지 않고 다음 단계 구현 방향을 확정한다.

## 확인한 환경

| 항목 | 값 |
|------|----|
| 로컬 CPU architecture | `arm64` |
| Xcode | `Xcode 26.4.1`, build `17E202` |
| 기준 브랜치 | `local/task208` |
| GitHub Actions 현재 release runner | `macos-15` |

GitHub 공식 문서 기준:

- Standard hosted runner에서 `macos-15`는 arm64 runner다.
- Intel runner label은 `macos-15-intel`이다.
- Larger runner 기준으로는 `macos-15-large`가 Intel, `macos-15-xlarge`가 arm64다.

참고:

- https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- https://docs.github.com/en/actions/how-tos/manage-runners/larger-runners/use-larger-runners

## 현재 산출물 architecture

기존 `build.noindex/release/Alhangeul.app` 기준:

| 대상 | 결과 |
|------|------|
| `Alhangeul.app/Contents/MacOS/Alhangeul` | `arm64` 단일 slice |
| `AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview` | `arm64` 단일 slice |
| `AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail` | `arm64` 단일 slice |
| `Frameworks/universal/librhwp.a` | `x86_64 arm64` |
| `Frameworks/Rhwp.xcframework/macos-arm64_x86_64/librhwp.a` | `x86_64 arm64` |
| bundled Sparkle framework binary | `x86_64 arm64` |
| bundled Sparkle updater binary | `x86_64 arm64` |

따라서 현재 문제 지점은 Rust/Sparkle dependency가 아니라 Swift app/extension 실행 파일 산출물이다.

## build setting과 실제 build 결과

`xcodebuild -showBuildSettings` 기준 Release 설정은 다음처럼 보인다.

```text
ARCHS = arm64 x86_64
ONLY_ACTIVE_ARCH = NO
NATIVE_ARCH = arm64
MACOSX_DEPLOYMENT_TARGET = 12.0
SUPPORTED_PLATFORMS = macosx
```

하지만 destination을 지정하지 않고 Release build를 실행하면 Xcode가 `My Mac arm64` destination을 먼저 선택하고, 실제 산출물은 `arm64` 단일 slice가 된다.

검증 명령:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -derivedDataPath /private/tmp/alhangeul-task208-dd \
  CONFIGURATION_BUILD_DIR=/private/tmp/alhangeul-task208-build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

| 대상 | 결과 |
|------|------|
| `/private/tmp/alhangeul-task208-build/Alhangeul.app/Contents/MacOS/Alhangeul` | `arm64` 단일 slice |
| `/private/tmp/alhangeul-task208-build/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview` | `arm64` 단일 slice |
| `/private/tmp/alhangeul-task208-build/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail` | `arm64` 단일 slice |

## generic macOS destination 검증

`-destination 'generic/platform=macOS'`를 지정하면 같은 project와 dependency 상태에서 `arm64 + x86_64` universal binary가 생성된다.

검증 명령:

```bash
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath /private/tmp/alhangeul-task208-generic-dd \
  CONFIGURATION_BUILD_DIR=/private/tmp/alhangeul-task208-generic-build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

| 대상 | 결과 |
|------|------|
| `/private/tmp/alhangeul-task208-generic-build/Alhangeul.app/Contents/MacOS/Alhangeul` | `x86_64 arm64` |
| `/private/tmp/alhangeul-task208-generic-build/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview` | `x86_64 arm64` |
| `/private/tmp/alhangeul-task208-generic-build/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail` | `x86_64 arm64` |

`lipo <binary> -verify_arch arm64 x86_64`도 세 실행 파일 모두 통과했다.

## Pages direct download 현황

현재 direct DMG 링크가 남아 있는 주요 위치:

| 파일 | 위치 |
|------|------|
| `docs/index.html` | header download button이 `v0.1.0` latest DMG를 직접 다운로드 |
| `docs/updates/index.html` | header button과 hero action이 `v0.1.1` latest DMG를 직접 다운로드 |
| `docs/updates/v0.1.1.html` | header button과 hero action이 `v0.1.1` latest DMG를 직접 다운로드 |
| `docs/updates/v0.1.0.html` | 과거 릴리즈 페이지가 `v0.1.0` direct DMG를 사용 |

`docs/updates/v0.1.0.html`은 과거 릴리즈 기록이므로 v0.1.1 universal 지원을 소급하지 않는다. 다만 공통 header 다운로드 버튼이 latest 성격인지, 해당 릴리즈 고정 다운로드인지 Stage 3에서 검토한다.

## 구현 결정

Stage 2에서는 다음 방향으로 구현한다.

1. `scripts/package-release.sh`와 `scripts/release.sh`의 `xcodebuild` 호출에 `-destination 'generic/platform=macOS'`를 추가한다.
2. release/package build에 `ARCHS="arm64 x86_64"`와 `ONLY_ACTIVE_ARCH=NO`를 명시할지 함께 검토하되, 핵심 보장은 `generic/platform=macOS`와 post-build `lipo` gate로 둔다.
3. app bundle 내부의 다음 세 binary를 공통 helper로 검증한다.
   - `Contents/MacOS/Alhangeul`
   - `Contents/PlugIns/AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview`
   - `Contents/PlugIns/AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail`
4. 검증 명령은 `lipo <binary> -verify_arch arm64 x86_64`를 사용한다.
5. release rehearsal/publish workflow는 script 자체 gate를 기본 신뢰하되, workflow summary나 별도 step에서 architecture 결과를 보여주는 보강을 검토한다.

Stage 3에서는 Pages direct download 안내를 보강한다.

- Intel Mac과 Apple Silicon Mac은 같은 universal DMG URL을 사용한다.
- 다운로드 버튼은 현재처럼 direct DMG 다운로드로 유지한다.
- UI 문구는 “두 Mac 모두 같은 universal DMG를 받는다”는 점을 명확히 한다.

## Stage 2 승인 요청

Stage 2에서 release/package script에 `generic/platform=macOS` destination과 universal binary 검증 helper를 추가하는 방향으로 진행한다. 이 단계에서는 Pages UI와 문서 보정은 아직 다루지 않고, build 산출물 gate에 집중한다.
