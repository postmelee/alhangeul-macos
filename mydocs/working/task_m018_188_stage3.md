# Task M018 #188 Stage 3 완료 보고서

## 단계 목적

`v0.1.1` public release workflow 실행 전에 release candidate source를 로컬에서 가능한 범위까지 검증한다. Rust bridge lock, bundled `rhwp-studio` asset, Xcode project generation, Debug/Release build, universal slice, renderer smoke, app bundle legal notice 포함 기준을 확인한다.

확인 시각: `2026-05-10 23:46 KST`

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m018_188_stage3.md` | Stage 3 로컬 검증 결과 기록 |
| `mydocs/release/v0.1.1.md` | Stage 3 unsigned Release bundle 검증 결과 보강 |
| `mydocs/orders/20260510.md` | #188 현재 상태를 Stage 4 승인 대기로 갱신 |

이번 단계에서 앱 source code, release workflow, Pages 문서, Cask 본문은 변경하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- 신규 단계 보고서를 추가했다.
- release 기록은 public DMG 검증 완료로 단정하지 않고, `build.noindex/DerivedDataRelease`의 unsigned local Release bundle 기준 통과 항목만 보강했다.
- 오늘할일은 #188의 진행 상태 메모만 갱신했다.
- `Alhangeul.xcodeproj`는 `xcodegen generate`로 재생성했지만 diff는 없었다.
- renderer smoke 산출물은 `output/stage3-render/`에 생성됐고 git 추적 대상은 아니다.
- 기존 로컬 public `v0.1.0` 설치본은 삭제하지 않았다.

## 확인 결과

### Core / asset preflight

| 항목 | 결과 |
|------|------|
| `rhwp-core.lock` | `rhwp` `v0.7.10`, commit `62a458aa317e962cd3d0eec6096728c172d57110` |
| universal `librhwp.a` | lock 검증 통과, `x86_64 arm64` 포함 |
| generated bridge header | lock 검증 통과 |
| FFI symbol smoke | `rhwp_open`, `rhwp_close`, `rhwp_render_page_svg`, `rhwp_render_page_tree`, `rhwp_extract_thumbnail` 등 확인 |
| shared Swift dependency rule | `Sources/RhwpCoreBridge` AppKit/UIKit 직접 의존 없음 |
| bundled `rhwp-studio` asset | manifest/resource tree 검증 통과 |

`./scripts/build-rust-macos.sh --verify-lock` 실행 중 Xcode의 CoreSimulator/cache 관련 경고가 출력됐지만, 명령은 `Verified: rhwp-core.lock`과 함께 exit code 0으로 종료했다.

### Xcode build

| 빌드 | 결과 | 비고 |
|------|------|------|
| `xcodegen generate` | OK | `Alhangeul.xcodeproj` 재생성, diff 없음 |
| Debug build | OK | restricted sandbox에서는 SwiftPM/clang cache 권한 문제로 실패 후, 로컬 권한으로 재실행해 성공 |
| Release build | OK | 기본 destination 빌드는 성공했으나 실행 파일이 `arm64` 단일 slice라 universal 검증에는 부적합 |
| Universal Release build | OK | `-destination generic/platform=macOS`, `ONLY_ACTIVE_ARCH=NO`, `ARCHS="arm64 x86_64"`로 재빌드 성공 |

Release build 중 `appintentsmetadataprocessor`가 `No AppIntents.framework dependency found` warning을 출력했지만 build는 성공했다. 현재 앱은 AppIntents 의존을 사용하지 않으므로 Stage 3 blocker로 보지 않는다.

### Renderer smoke

`./scripts/validate-stage3-render.sh` 결과:

| Fixture | 결과 | PNG |
|---------|------|-----|
| `KTX.hwp` | OK, page 1 `1123x794`, textRuns `436`, hangulRuns `76`, nonWhitePixels `454739` | `output/stage3-render/KTX-page1.png` |
| `request.hwp` | OK, page 1 `567x794`, textRuns `104`, hangulRuns `36`, nonWhitePixels `69375` | `output/stage3-render/request-page1.png` |
| `exam_kor.hwp` | OK, page 1 `1123x1588`, textRuns `133`, hangulRuns `86`, nonWhitePixels `174843` | `output/stage3-render/exam_kor-page1.png` |

`KTX.hwp`에서 renderer diagnostic `LAYOUT_OVERFLOW*` warning이 출력됐지만 스크립트는 정상 종료했고 PNG smoke 기준은 통과했다.

### Universal bundle

`scripts/ci/verify-universal-macos-app.sh build.noindex/DerivedDataRelease/Build/Products/Release/Alhangeul.app` 결과:

| 실행 파일 | 확인된 architecture |
|-----------|---------------------|
| `Alhangeul.app/Contents/MacOS/Alhangeul` | `x86_64 arm64` |
| `AlhangeulPreview.appex/Contents/MacOS/AlhangeulPreview` | `x86_64 arm64` |
| `AlhangeulThumbnail.appex/Contents/MacOS/AlhangeulThumbnail` | `x86_64 arm64` |

### Version / legal notice

unsigned local Release bundle 기준:

| 항목 | 값 |
|------|----|
| `CFBundleShortVersionString` | `0.1.1` |
| `CFBundleVersion` | `2` |
| `NSHumanReadableCopyright` | `Copyright © 2025-2026 Taegyu Lee` |
| `SUFeedURL` | `https://postmelee.github.io/alhangeul-macos/appcast.xml` |

`Contents/Resources/Legal` 포함 파일:

| Bundle file | Canonical source | 결과 |
|-------------|------------------|------|
| `LICENSE` | `LICENSE` | `diff -u` 일치 |
| `THIRD_PARTY_LICENSES.md` | `THIRD_PARTY_LICENSES.md` | `diff -u` 일치 |
| `FONTS.md` | `Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md` | `diff -u` 일치 |

## 검증 결과

| 명령 | 결과 | 비고 |
|------|------|------|
| `git status --short --branch` | OK | `## local/task188`, 시작 시 clean |
| `cat rhwp-core.lock` | OK | `rhwp` `v0.7.10`, resolved commit 확인 |
| `./scripts/build-rust-macos.sh --verify-lock` | OK | lock 검증과 `Rhwp.xcframework` 생성 성공 |
| `./scripts/check-no-appkit.sh` | OK | shared Swift direct AppKit/UIKit dependency 없음 |
| `scripts/verify-rhwp-studio-assets.sh` | OK | bundled asset 검증 통과 |
| `xcodegen generate` | OK | project 재생성, diff 없음 |
| `xcodebuild ... Debug ... CODE_SIGNING_ALLOWED=NO build` | OK | restricted sandbox cache 실패 후 로컬 권한 재실행 성공 |
| `xcodebuild ... Release ... CODE_SIGNING_ALLOWED=NO build` | OK | 기본 Release build 성공, 단일 `arm64` 산출 |
| `xcodebuild ... Release -destination generic/platform=macOS ONLY_ACTIVE_ARCH=NO ARCHS="arm64 x86_64" ... build` | OK | universal Release bundle 생성 |
| `./scripts/validate-stage3-render.sh` | OK | 3 fixture PNG smoke 통과, `KTX.hwp` layout overflow warning 기록 |
| `scripts/ci/verify-universal-macos-app.sh build.noindex/DerivedDataRelease/Build/Products/Release/Alhangeul.app` | OK | app/preview/thumbnail 모두 `x86_64 arm64` |
| `plutil -p .../Alhangeul.app/Contents/Info.plist` | OK | `0.1.1` / `2` / copyright 확인 |
| `find .../Contents/Resources/Legal -maxdepth 1 -type f` | OK | `LICENSE`, `FONTS.md`, `THIRD_PARTY_LICENSES.md` 포함 |
| `diff -u LICENSE .../Resources/Legal/LICENSE` | OK | 출력 없음 |
| `diff -u THIRD_PARTY_LICENSES.md .../Resources/Legal/THIRD_PARTY_LICENSES.md` | OK | 출력 없음 |
| `diff -u Sources/HostApp/Resources/rhwp-studio/fonts/FONTS.md .../Resources/Legal/FONTS.md` | OK | 출력 없음 |
| `git diff --check` | OK | 출력 없음 |
| `git status --short` | OK | Stage 3 보고서 작성 전 clean |

## 실행하지 않은 항목

- `./scripts/release.sh --skip-notarize 0.1.1` rehearsal DMG는 실행하지 않았다. Stage 3의 필수 local gate가 모두 통과했고, public DMG는 Stage 4의 release workflow에서 생성해야 하므로 별도 rehearsal 산출물을 만들지 않았다.
- Finder integration smoke는 실행하지 않았다. extension 등록, Gatekeeper quarantine, signed/sealed app bundle 조건이 필요하므로 Stage 5 public DMG 설치본 기준으로 반복한다.
- Sparkle update 감지는 실행하지 않았다. stable appcast와 public DMG가 아직 배포되지 않았고, 기존 `v0.1.0` 설치본은 Stage 5까지 보존해야 한다.
- public DMG mount 후 legal notice 검증은 실행하지 않았다. 이번 단계의 legal 검증은 unsigned local Release bundle 기준이며, Stage 4/5에서 signed/notarized DMG 기준으로 반복해야 한다.

## 잔여 위험

- GitHub Pages source는 Stage 1 기준 아직 `legacy`이고, `github-pages` environment에 `v*` tag policy가 없다. Stage 4 release workflow 실행 전 별도 승인/설정 변경이 필요하다.
- public DMG SHA256, Sparkle EdDSA signature, public appcast item은 아직 없다.
- 기본 Release build는 현재 machine destination을 따라 `arm64` 단일 slice를 만들 수 있다. public packaging path에서는 #208의 universal gate와 같이 generic destination 또는 package workflow 산출물 기준으로 `arm64 + x86_64`를 반드시 검증해야 한다.
- `KTX.hwp` renderer smoke에서 layout overflow diagnostic이 남아 있다. PNG smoke는 통과했지만 renderer parity 개선 이슈와 혼동하지 않도록 release blocker로 승격하지 않는다.
- Intel Mac 실기기 smoke는 이번 로컬 환경에서 수행하지 않았다.

## 다음 단계 영향

Stage 4 진입 전 다음 승인/실행 항목이 필요하다.

1. Pages source를 `workflow`로 전환
2. `github-pages` environment에 `v*` tag policy 추가
3. release candidate commit 확정
4. `v0.1.1` tag 생성
5. `Release Publish DMG` workflow를 public 설정으로 실행
6. workflow artifact, GitHub Release asset, Pages/appcast public URL 검증
7. Cask SHA256 갱신 여부와 #209 handoff 기록

## 승인 요청

1. Stage 3 결과 승인
2. Stage 4 `public release workflow 실행과 산출물 검증` 진입 승인
3. Stage 4 시작 시 repository setting 변경을 먼저 실행하는 방향 승인
