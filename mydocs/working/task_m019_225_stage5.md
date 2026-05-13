# Task M019 #225 Stage 5 완료보고서

## 단계 목적

`local/task225`의 `v0.1.2` release candidate가 source-level build, release helper, unsigned rehearsal DMG, Finder/Thumbnail, Sparkle refresh helper, GUI About smoke에서 가능한 범위만큼 검증되는지 확인했다.

public 배포에 해당하는 Developer ID signing, notarization, GitHub Release, stable appcast, actual Sparkle update from public v0.1.0/v0.1.1은 실행하지 않았다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `scripts/smoke-clean-quicklook-install.sh` | 수정 | unsigned/rehearsal app을 smoke staging copy에서 ad-hoc 재서명한 뒤 검증하도록 전제 보정. local ad-hoc HostApp 실행용 `disable-library-validation` entitlements를 staging copy에만 추가 |
| `mydocs/release/v0.1.2.md` | 수정 | Stage 5 local/rehearsal 검증 결과와 public 배포 잔여 gate 기록 |
| `mydocs/working/task_m019_225_stage5.md` | 신규 | Stage 5 수행과 검증 결과 기록 |

`Sources/HostApp/HostApp.entitlements`는 변경하지 않았다. `disable-library-validation`은 local smoke copy에서 ad-hoc signed Sparkle framework를 로드하기 위한 임시 entitlements 보정이다.

## 검증 결과

### Source guard

```text
$ ./scripts/build-rust-macos.sh --verify-lock
Verified: /Users/melee/Documents/projects/rhwp-mac/rhwp-core.lock
```

기본 sandbox 실행은 Cargo가 `/Users/melee/.cargo/git/db/...`를 만들 수 없어 실패했다. 동일 명령을 승인 경로로 재실행해 통과했다.

```text
$ ./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies

$ scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified at /Users/melee/Documents/projects/rhwp-mac/Sources/HostApp/Resources/rhwp-studio
```

### Xcode build

```text
$ xcodegen generate
Created project at /Users/melee/Documents/projects/rhwp-mac/Alhangeul.xcodeproj

$ xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [6.464 sec]

$ xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Release -derivedDataPath build.noindex/DerivedDataRelease CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [15.716 sec]
```

`build.noindex/DerivedDataRelease/.../Release/Alhangeul.app`는 local My Mac Release build라 host 실행 파일이 arm64 단일 slice였다. 따라서 universal 검증의 진실 원천으로 쓰지 않고, `scripts/release.sh --skip-notarize 0.1.2`가 만드는 generic/platform package 산출물을 기준으로 확인했다.

### Renderer smoke

```text
$ ./scripts/validate-stage3-render.sh
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=455004 png=/Users/melee/Documents/projects/rhwp-mac/output/stage3-render/KTX-page1.png
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=69375 png=/Users/melee/Documents/projects/rhwp-mac/output/stage3-render/request-page1.png
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=174843 png=/Users/melee/Documents/projects/rhwp-mac/output/stage3-render/exam_kor-page1.png
```

`KTX.hwp`에서 기존 renderer layout overflow diagnostic이 출력됐지만 smoke 기준은 통과했다.

### Rehearsal DMG

```text
$ ./scripts/release.sh --skip-notarize 0.1.2
WARN: Apple notarization is skipped. This rehearsal artifact is not a public release.
INFO: Verifying universal app architectures
Architectures in the fat file: .../Alhangeul are: x86_64 arm64
Architectures in the fat file: .../AlhangeulPreview are: x86_64 arm64
Architectures in the fat file: .../AlhangeulThumbnail are: x86_64 arm64
WARN: Skipping codesign verification because this rehearsal build is unsigned.
WARN: Skipping release signing preflight because this rehearsal build is unsigned.
hdiutil: verify: checksum of ".../alhangeul-macos-0.1.2-rehearsal.dmg" is VALID
INFO: Release artifact: /Users/melee/Documents/projects/rhwp-mac/build.noindex/release/alhangeul-macos-0.1.2-rehearsal.dmg
```

Rehearsal 산출물:

```text
build.noindex/release/Alhangeul.app
build.noindex/release/alhangeul-macos-0.1.2-rehearsal.dmg
build.noindex/release/alhangeul-macos-0.1.2-rehearsal.dmg.sha256
```

SHA256:

```text
fdf0e48cfbe8353fcf0a36bede9758603c922dd66da2d0d8d72167ab6626186f  alhangeul-macos-0.1.2-rehearsal.dmg
```

App/extension version:

```text
Alhangeul.app: 0.1.2 (5)
AlhangeulPreview.appex: 0.1.2 (5)
AlhangeulThumbnail.appex: 0.1.2 (5)
```

Universal 검증:

```text
$ scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app
Architectures in the fat file: build.noindex/release/Alhangeul.app/Contents/MacOS/Alhangeul are: x86_64 arm64
Architectures in the fat file: build.noindex/release/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview are: x86_64 arm64
Architectures in the fat file: build.noindex/release/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail are: x86_64 arm64
```

### Finder/Quick Look smoke

초기 `smoke-clean-quicklook-install.sh` 실행에서 입력 app이 unsigned/rehearsal 산출물이라 `codesign --verify`가 재서명 전에 실패할 수 있는 전제를 확인했다. 스크립트를 다음처럼 보정했다.

- 입력 app은 bundle 구조와 bundle identifier만 확인
- staging copy를 만든 뒤 Sparkle nested component, Quick Look/Thumbnail appex, HostApp을 ad-hoc runtime 서명
- signed staging copy만 `codesign --verify --deep --strict`로 확인
- local smoke HostApp에만 `com.apple.security.cs.disable-library-validation=true` 추가

최종 실행:

```text
$ ./scripts/smoke-clean-quicklook-install.sh --skip-package --app build.noindex/release/Alhangeul.app --install-app /Users/melee/Applications/Alhangeul.app --sample samples/basic/KTX.hwp --sample samples/group-drawing-02.hwp --sample samples/hwpx/hwpx-01.hwpx
OK: clean Quick Look visual smoke setup complete
Installed app: /Users/melee/Applications/Alhangeul.app
Fresh samples: /private/tmp/alhangeul-visual-smoke/20260512-145813/samples
Generated thumbnails: /private/tmp/alhangeul-visual-smoke/20260512-145813/thumbnails
Visual guide: /private/tmp/alhangeul-visual-smoke/20260512-145813/VISUAL_CHECK.md
Preview command: /private/tmp/alhangeul-visual-smoke/20260512-145813/open-preview.command
Crash check: /private/tmp/alhangeul-visual-smoke/20260512-145813/check-crashes.command
```

생성된 thumbnail:

```text
/private/tmp/alhangeul-visual-smoke/20260512-145813/thumbnails/alhangeul-smoke-01-20260512-145813.hwp/alhangeul-smoke-01-20260512-145813.hwp.png
/private/tmp/alhangeul-visual-smoke/20260512-145813/thumbnails/alhangeul-smoke-02-20260512-145813.hwp/alhangeul-smoke-02-20260512-145813.hwp.png
/private/tmp/alhangeul-visual-smoke/20260512-145813/thumbnails/alhangeul-smoke-03-20260512-145813.hwpx/alhangeul-smoke-03-20260512-145813.hwpx.png
```

Crash check:

```text
$ /private/tmp/alhangeul-visual-smoke/20260512-145813/check-crashes.command
OK: no new AlhangeulPreview/AlhangeulThumbnail crash reports since smoke setup.
```

Quick Look preview GUI는 자동으로 열지 않았다. 필요하면 위 `open-preview.command`로 수동 확인한다.

### Sparkle refresh helper

실제 public Sparkle update는 아직 수행할 수 없다. public appcast와 `v0.1.2` public signed/notarized asset이 없기 때문이다. 대신 설치된 v0.1.2 후보가 registration repair 없이 helper gate를 통과하는지 확인했다.

```text
$ ./scripts/smoke-sparkle-extension-refresh.sh --expected-version 0.1.2 --expected-build 5 --app /Users/melee/Applications/Alhangeul.app --sample-hwp samples/basic/KTX.hwp --sample-hwpx samples/hwpx/hwpx-01.hwpx
OK: post-Sparkle extension refresh smoke passed
Installed app: /Users/melee/Applications/Alhangeul.app
Expected: 0.1.2 (5)
Registration repair used: 0
Output: /private/tmp/alhangeul-sparkle-extension-refresh/20260512-145914
Diagnostics: /private/tmp/alhangeul-sparkle-extension-refresh/20260512-145914/diagnostics
Preview command: /private/tmp/alhangeul-sparkle-extension-refresh/20260512-145914/open-preview.command
```

생성된 thumbnail:

```text
/private/tmp/alhangeul-sparkle-extension-refresh/20260512-145914/thumbnails/alhangeul-sparkle-refresh-1-20260512-145914.hwp_/alhangeul-sparkle-refresh-1-20260512-145914.hwp.png
/private/tmp/alhangeul-sparkle-extension-refresh/20260512-145914/thumbnails/alhangeul-sparkle-refresh-2-20260512-145914.hwpx_/alhangeul-sparkle-refresh-2-20260512-145914.hwpx.png
```

### GUI About smoke

Computer Use로 `/Users/melee/Applications/Alhangeul.app`을 실행하고 About 창을 열어 확인했다.

local ad-hoc entitlements 보정 전 첫 GUI launch는 hardened runtime library validation이 ad-hoc signed `Sparkle.framework`를 거부해 dyld 오류로 종료됐다. `scripts/smoke-clean-quicklook-install.sh`의 staging HostApp entitlements에 `com.apple.security.cs.disable-library-validation=true`를 추가한 뒤 smoke app을 다시 설치했고, 이후 GUI launch와 About 확인은 통과했다. 이 실패는 local ad-hoc smoke 전제 문제이며, public Developer ID 서명에서는 Sparkle framework와 HostApp이 같은 Team ID로 서명되어야 한다.

확인된 표시:

```text
v0.1.2 (5)
버전 0.1.2
빌드 5
rhwp v0.7.11 (a9dcdee)
빠른 보기 미리보기: 앱에 포함됨 / 시스템 등록됨
빠른 보기 썸네일: 앱에 포함됨 / 시스템 등록됨
```

local ad-hoc app은 현재 실행된 상태로 About 창이 열려 있다.

## 미실행 항목

| 항목 | 사유 |
|------|------|
| Developer ID signing / notarization | public release 승인 전 단계이며 signing identity/notary workflow를 실행하지 않음 |
| public DMG Gatekeeper/stapler | public DMG가 아직 없음 |
| actual Sparkle update from `v0.1.0` or `v0.1.1` | public `v0.1.2` appcast/asset이 아직 없음 |
| Intel Mac 실기기 smoke | 현재 접근 가능한 환경에서 실행하지 않음 |
| Homebrew Cask 검증 | public DMG SHA256 확정 전이라 대상 아님 |

## 본문 변경 정도 / 본문 무손실 여부

application source는 변경하지 않았다. smoke script의 local ad-hoc validation flow와 release record/report 문서만 변경했다. `build.noindex/`, `output/`, `/private/tmp/`, `/Users/melee/Applications/Alhangeul.app`은 검증 산출물이다.

## 잔여 위험

- public release에서 Developer ID 서명과 notarization을 통과해야 한다. Stage 5의 ad-hoc smoke는 public trust policy를 대체하지 않는다.
- actual Sparkle update path는 public appcast와 signed/notarized DMG가 준비된 뒤 별도로 확인해야 한다.
- Quick Look preview GUI는 helper command를 생성했지만 자동 실행하지 않았다. Stage 5 자동 확인은 thumbnail 생성과 provider registration 중심이다.
- font sandbox deny 로그가 thumbnail smoke 중 출력될 수 있다. 이번 smoke에서는 thumbnail 생성과 extension crash 부재가 확인됐지만, signed/notarized public app에서도 동일 현상이 사용자-visible 문제로 이어지는지 확인이 필요하다.

## 다음 단계 영향

Stage 6에서는 최종 보고와 `publish/task225 -> devel-webview` PR 게시를 진행한다. public 배포 명령은 Stage 6에서도 별도 승인 없이 실행하지 않는다.

PR 전 확인할 내용:

- Stage 5 script 보정이 public release path를 바꾸지 않는지 review
- `mydocs/release/v0.1.2.md`의 public 미확정 항목 유지
- `docs/appcast.xml`, `Casks/alhangeul-macos.rb`가 아직 v0.1.2로 고정되지 않았음을 최종 보고서에 명시

## 승인 요청

Stage 5 완료를 승인하면 Stage 6 `최종 보고, PR 게시, main release handoff와 public 배포 조건 정리`를 진행한다.
