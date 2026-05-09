# Task M018 #208 Stage 2 보고서

## 단계 목적

release/package 산출물이 Intel Mac과 Apple Silicon Mac에서 실행 가능한 universal app bundle 기준을 만족하도록 빌드 인자와 검증 gate를 보강한다. 이 단계는 Pages 다운로드 선택 UI와 사용자 문서 보정 전에, 실제 배포 산출물의 architecture 보장을 먼저 고정하는 작업이다.

## 변경 요약

| 파일 | 변경 내용 |
|------|-----------|
| `scripts/ci/verify-universal-macos-app.sh` | app bundle 내부의 앱 본체, Quick Look extension, Thumbnail extension 실행 파일이 `arm64 + x86_64`를 모두 포함하는지 검증하는 공통 helper 추가 |
| `scripts/package-release.sh` | Release build에 `-destination "generic/platform=macOS"`, `ARCHS="arm64 x86_64"`, `ONLY_ACTIVE_ARCH=NO` 추가 및 package app copy 후 universal 검증 gate 연결 |
| `scripts/release.sh` | signed/unsigned release build 양쪽에 generic macOS destination과 universal build setting 추가, `verify_universal_app` 단계를 code signing/notarization 전에 실행하도록 연결 |

## 구현 상세

`verify-universal-macos-app.sh`는 다음 세 실행 파일을 직접 검사한다.

| 대상 | 경로 |
|------|------|
| 앱 본체 | `Contents/MacOS/Alhangeul` |
| Quick Look extension | `Contents/PlugIns/AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview` |
| Thumbnail extension | `Contents/PlugIns/AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail` |

검증 명령은 각 binary에 대해 `xcrun lipo <binary> -verify_arch arm64 x86_64`를 사용한다. 누락된 실행 파일, 실행 권한 누락, architecture slice 누락은 모두 즉시 실패한다. 성공 시에는 `xcrun lipo -info` 결과를 출력해 CI 로그에서 실제 slice를 확인할 수 있게 했다.

`scripts/release.sh`는 public signed build와 local rehearsal unsigned build가 같은 universal build policy를 쓰도록 양쪽 `xcodebuild` 호출 모두에 동일한 인자를 넣었다. 검증 gate는 `build_app` 이후, `verify_app_signature`와 notarization 전에 실행한다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| `bash -n scripts/package-release.sh` | 통과 |
| `bash -n scripts/release.sh` | 통과 |
| `bash -n scripts/ci/verify-universal-macos-app.sh` | 통과 |
| `scripts/ci/verify-universal-macos-app.sh /private/tmp/alhangeul-task208-generic-build/Alhangeul.app` | 통과, 세 실행 파일 모두 `x86_64 arm64` |
| `scripts/ci/verify-universal-macos-app.sh /private/tmp/alhangeul-task208-build/Alhangeul.app` | 예상 실패, 기존 arm64-only 산출물에서 `Contents/MacOS/Alhangeul` 누락 slice 감지 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -destination 'generic/platform=macOS' ... ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build` | 통과, 새 산출물 세 실행 파일 모두 universal |
| `scripts/ci/verify-universal-macos-app.sh /private/tmp/alhangeul-task208-stage2-build/Alhangeul.app` | 통과, 세 실행 파일 모두 `x86_64 arm64` |
| `ALHANGEUL_BUILD_ROOT=/private/tmp/alhangeul-task208-package scripts/package-release.sh 0.1.0` | 통과, package script 경로에서 helper 실행 후 zip 생성 |
| `git diff --check` | 통과 |

`xcodebuild`와 `package-release.sh`는 sandbox 내부에서 Sparkle package fetch가 DNS 제한으로 실패했기 때문에, 같은 명령을 권한 상승으로 재실행해 검증을 완료했다. 권한 상승 실행에서는 Sparkle 2.9.1이 cached source package로 해석됐고 빌드가 정상 완료됐다.

`package-release.sh` 검증 결과 생성된 zip checksum:

```text
af43d7f25ccd5b3673337a87c7603637c8ba6f10c66de91c64dbe289d090bd47  alhangeul-macos-0.1.0.zip
```

## 미실행 항목

`scripts/release.sh --skip-notarize <version>` 전체 DMG 생성은 이번 단계에서 실행하지 않았다. Stage 2의 핵심은 app bundle build와 architecture gate이며, `release.sh`는 동일 helper를 `build_app` 이후에 호출하도록 연결하고 문법 검증을 완료했다. signed/notarized DMG 생성과 Gatekeeper 검증은 #188 public release 실행 단계에서 수행한다.

실제 Intel Mac 실기기 실행 smoke도 이번 로컬 환경에서는 수행하지 않았다. 이번 단계의 보장은 binary slice 존재와 universal package gate이며, 실기기 smoke 가능 여부는 #188 handoff에서 다시 확인한다.

## 다음 단계

Stage 3에서는 GitHub Pages 다운로드 진입점을 Intel Mac / Apple Silicon 선택 UI로 바꾼다. 선택 UI는 단일 universal DMG 정책을 유지하되, 사용자가 자신의 Mac에 맞는 안내를 확인한 뒤 같은 DMG를 받는 흐름으로 구현한다.

## Stage 3 승인 요청

Stage 3에서 `docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.1.html`, `docs/styles.css` 중심으로 다운로드 선택 UI를 구현한다. 과거 릴리즈 페이지인 `docs/updates/v0.1.0.html`은 v0.1.1 universal 지원을 소급하지 않는 방향으로 검토한다.
