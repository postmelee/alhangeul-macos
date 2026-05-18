# Task M010 #267 Stage 4 보고서

## 개요

- 단계: Stage 4. Release candidate 로컬 검증과 rehearsal 준비
- 이슈: #267 rhwp v0.7.12 반영과 v0.1.3 public release 준비/배포
- 마일스톤: M010 (`v0.1`)
- 브랜치: `local/task267`
- 완료 시각: 2026-05-18 13:44 KST

이번 단계에서는 `v0.1.3 (9)` release candidate source를 기준으로 core lock, bundled `rhwp-studio`, Debug/Release build, native renderer smoke, release helper, local rehearsal DMG를 검증했다. public tag, GitHub Release, signed/notarized DMG, Pages/appcast 공개, Homebrew Cask 반영은 Stage 5 이후 승인 지점으로 유지한다.

## 변경 사항

| 파일 | 내용 |
|------|------|
| `scripts/validate-stage3-render.sh` | standalone `swiftc` smoke에 `libc++`, `libiconv`, `libz` 링크 플래그 추가 |
| `scripts/render-debug-compare.sh` | 같은 링크 플래그 추가 |
| `scripts/compare-quicklook-pdf-renderers.sh` | 같은 링크 플래그 추가 |
| `mydocs/release/v0.1.3.md` | Stage 4 검증 결과와 rehearsal checksum 기록 |
| `mydocs/orders/20260518.md` | #267 상태를 Stage 5 승인 대기로 갱신 |

`rhwp v0.7.12` native-skia 정적 라이브러리는 standalone Swift smoke binary에서도 Xcode target과 같은 C++/iconv/zlib 링크가 필요하다. 앱/extension target은 이미 `project.yml`에서 해당 SDK 의존성을 갖고 있었고, 이번 보정은 독립 검증 스크립트에 한정된다.

## 검증 결과

| 항목 | 결과 | 비고 |
|------|------|------|
| 작업트리 시작 상태 | 통과 | `## local/task267`, clean |
| `./scripts/build-rust-macos.sh --verify-lock` | 통과 | FFI symbol set 유지, `rhwp-core.lock` 검증 통과 |
| `./scripts/check-no-appkit.sh` | 통과 | `Sources/RhwpCoreBridge` AppKit/UIKit 직접 의존 없음 |
| `scripts/verify-rhwp-studio-assets.sh --tag v0.7.12 --commit 1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` | 통과 | bundled asset provenance 일치 |
| `xcodegen generate` | 통과 | tracked project diff 없음 |
| Debug HostApp build | 통과 | 일반 실행은 Sparkle fetch DNS 제한으로 실패, escalated retry로 성공 |
| Release HostApp build | 통과 | 일반 My Mac destination 산출물 생성 성공 |
| 일반 Release 산출물 universal check | 실패/분리 | `build.noindex/DerivedDataTask267Stage4Release/.../Alhangeul.app`은 `arm64` 단일 slice |
| `./scripts/validate-stage3-render.sh build.noindex/stage4-render` | 통과 | 링크 플래그 보정 후 3개 기본 샘플 통과 |
| `scripts/render-debug-compare.sh build.noindex/stage4-render-debug samples/basic/KTX.hwp` | 통과 | 보정한 standalone 링크 경로 확인 |
| `scripts/compare-quicklook-pdf-renderers.sh build.noindex/stage4-quicklook-compare samples/basic/KTX.hwp` | 통과 | 보정한 standalone 링크 경로 확인 |
| release delta checklist dry-run | 통과 | `build.noindex/release/delta-checklist-0.1.3.md` 생성 |
| release notes dry-run/template check | 통과 | `build.noindex/release/release-notes-0.1.3.md` template check 통과 |
| `./scripts/release.sh --skip-notarize 0.1.3` | 통과 | unsigned rehearsal artifact 생성, public release 산출물 아님 |
| rehearsal app universal check | 통과 | `Alhangeul.app`, `AlhangeulPreview.appex`, `AlhangeulThumbnail.appex` 모두 `x86_64 arm64` |
| rehearsal app/extension version | 통과 | app/Preview/Thumbnail 모두 `0.1.3 (9)` |
| rehearsal DMG verify | 통과 | `hdiutil verify` checksum valid |
| rehearsal DMG SHA256 | 기록 | `4aca645bc91b908844736cacb680acf9a08cd93f708435acb6721a24df5302aa` |

일반 `xcodebuild -configuration Release`를 My Mac destination으로 실행한 산출물은 현재 장비 기준 `arm64`만 포함한다. universal 배포 검증의 기준은 `scripts/release.sh`가 실행하는 `generic/platform=macOS`, `ARCHS="arm64 x86_64"`, `ONLY_ACTIVE_ARCH=NO` 경로로 분리한다.

## 미실행 및 이관 항목

- signed/notarized public DMG 검증: Stage 5 release workflow 실행 뒤 확인
- GitHub Release public asset, `.sha256`, Sparkle stable appcast, Pages deploy 확인: Stage 5 이관
- public installed app 기준 Finder Quick Look/Thumbnail smoke: Stage 6 이관
- About 창의 `rhwp v0.7.12 (1899ef9)` 표시 확인: Stage 6 이관
- Homebrew Cask digest 반영: public DMG SHA256 확정 뒤 별도 승인

## 다음 단계

Stage 5에서는 `publish/task267 -> devel` 통합 PR handoff와 public release 실행 경계를 처리한다. Stage 5 진입 전 작업지시자 승인이 필요하다.
