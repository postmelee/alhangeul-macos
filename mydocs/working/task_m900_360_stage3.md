# Task M900 #360 Stage 3 완료보고서

## 단계 요약

`v0.1.6` release candidate source에 대해 source preflight, Debug/Release build, native render smoke, local package, local rehearsal DMG 검증을 완료했다. Stage 3 산출물은 모두 local unsigned rehearsal 용도이며 public release, Sparkle, Homebrew에는 사용하지 않는다.

| 항목 | 결과 |
|------|------|
| Release version | `0.1.6` |
| Build | `12` |
| Previous release ref | `v0.1.5` |
| Expected rhwp tag | `v0.7.16` |
| rhwp commit | `de02159ab4d2c5d165d6e25568bad3f8af5ef6cb` |

## 변경 내용

| 파일 | 변경 |
|------|------|
| `mydocs/release/v0.1.6.md` | Stage 3 source preflight, local package, rehearsal DMG 검증 결과와 local artifact hash/size 기록 |
| `mydocs/orders/20260621.md` | #360 상태를 Stage 4 승인 대기로 갱신 |
| `mydocs/working/task_m900_360_stage3.md` | Stage 3 완료보고서 작성 |

`build.noindex/`와 `output/stage3-render/` 산출물은 검증용 local artifact라 커밋하지 않는다.

## 검증 결과

| 검증 | 결과 | 비고 |
|------|------|------|
| `git status --short --branch` | 통과 | 시작 시 `## local/task360`, tracked 변경 없음 |
| App/extension source version 추출 | 통과 | HostApp, Preview, Thumbnail 모두 `0.1.6 (12)` |
| `rhwp-core.lock` 추출 | 통과 | `v0.7.16`, `de02159ab4d2c5d165d6e25568bad3f8af5ef6cb` |
| `scripts/verify-rhwp-studio-assets.sh` | 통과 | bundled `rhwp-studio` asset manifest와 entrypoint hash 확인 |
| `./scripts/check-no-appkit.sh` | 통과 | shared Swift code의 AppKit/UIKit 직접 의존 없음 |
| `./scripts/build-rust-macos.sh --verify-lock` | 경고 기록 | static archive byte hash/size가 local toolchain 산출물과 불일치. lock은 수정하지 않음 |
| `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/build-rust-macos.sh --verify-lock` | 통과 | static archive byte hash만 skip, source provenance, Cargo.lock, generated header, FFI symbols 검증 통과 |
| `xcodegen generate` | 통과 | `project.yml` 기준 Xcode project 재생성 |
| Debug build | 통과 | sandbox 밖 Xcode cache 접근 승인 후 `HostApp` Debug build 성공 |
| `./scripts/validate-stage3-render.sh` | 통과 | `KTX.hwp`, `request.hwp`, `exam_kor.hwp` 첫 페이지 PNG 생성과 text/pixel smoke 통과 |
| `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/package-release.sh 0.1.6` | 통과 | sandbox 밖 네트워크 접근 승인 후 unsigned Release zip 생성 |
| `scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app` | 통과 | app, Preview extension, Thumbnail extension 모두 `x86_64 arm64` |
| Release app/extension bundle version | 통과 | build.noindex release app 기준 HostApp, Preview, Thumbnail 모두 `0.1.6 (12)` |
| `./scripts/release.sh --help` | 통과 | release helper 사용 가능 |
| `scripts/ci/write-release-delta-checklist.sh v0.1.5 HEAD ...` | 통과 | `build.noindex/release/delta-checklist-0.1.6.md` 생성 |
| `scripts/ci/write-release-notes.sh 0.1.6 ...` + template check | 통과 | generated release note와 필수 section 검증 |
| `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/release.sh --skip-notarize 0.1.6` | 통과 | unsigned rehearsal DMG 생성 |
| `hdiutil verify build.noindex/release/alhangeul-macos-0.1.6-rehearsal.dmg` | 통과 | checksum valid, CRC32 `$A428E103` |

## Local artifacts

| 산출물 | 크기 | SHA256 |
|--------|------|--------|
| `build.noindex/release/alhangeul-macos-0.1.6.zip` | `155314914` bytes | `f09bcf2aec75604e39513a388d7ee5ac8618cc23a81ba9cb327486ec48da9e7a` |
| `build.noindex/release/alhangeul-macos-0.1.6-rehearsal.dmg` | `154782344` bytes | `1fd40fa9aafa858bf60c156aa06ff0ee7baa4a8caa0c980d16495fee3b30782e` |

## 남은 위험

- Rust static archive byte hash는 같은 source provenance에서도 local Rust/Xcode/macOS/toolchain/path 차이로 달라질 수 있어 strict hash 검증이 불일치했다. 문서화된 정책대로 `rhwp-core.lock`은 수정하지 않았고, source provenance/header/ABI 검증은 static archive byte hash만 skip한 상태에서 통과했다.
- Debug build, package, rehearsal은 local sandbox 밖 Xcode cache와 network 접근 승인을 거쳐 수행했다. GitHub Actions 환경에서는 workflow summary로 별도 확인해야 한다.
- Stage 3 산출물은 unsigned rehearsal artifact다. public DMG, notarization, Sparkle appcast, Pages deploy, GitHub Release latest 상태, Homebrew digest는 아직 확정하지 않았다.
- installed candidate 기준 Finder Quick Look/Thumbnail smoke와 About 창 확인은 Stage 4의 signed/notarized draft DMG smoke에서 수행해야 한다.

## 다음 단계 요청

Stage 4에서는 `local/task360` 변경을 publish PR로 게시해 `devel`에 반영하고, 별도 승인 gate에 따라 `main` release PR, `v0.1.6` tag, pre-public signed/notarized DMG smoke, official stable publish를 진행한다.

Stage 4 진행 승인을 요청한다.
