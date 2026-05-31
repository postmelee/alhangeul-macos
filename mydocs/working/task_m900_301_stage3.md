# Task #301 Stage 3 완료 보고서

## 단계

- Stage 3: Source Preflight와 Rehearsal
- 기준 version/build: `0.1.4` / `10`
- 기준 upstream: `rhwp v0.7.13`
- 기준 candidate commit: `43438bcc61c9d4d193faeb1dbb0d877b6a71d9de`

## 수행 내용

- Rust bridge lock, bundled `rhwp-studio`, shared Swift boundary를 검증했다.
- Xcode project를 재생성하고 Debug build를 수행했다.
- native renderer smoke를 기본 샘플 3개로 실행했다.
- Release configuration package 산출물을 만들고 app/extension universal slice를 확인했다.
- release helper dry-run, release notes template check, delta checklist 생성을 재실행했다.
- `./scripts/release.sh --skip-notarize 0.1.4`로 local rehearsal DMG를 생성하고 `hdiutil verify`를 확인했다.
- release record에 Stage 3 검증 결과와 local 산출물 SHA256을 반영했다.

## 검증 결과

| 명령 | 결과 | 비고 |
|------|------|------|
| `git status --short --branch` | 통과 | `local/task301`, 검증 시작 시 clean |
| `./scripts/build-rust-macos.sh --verify-lock` | 통과 | `rhwp-core.lock` 확인 |
| `scripts/verify-rhwp-studio-assets.sh` | 통과 | source bundled asset 확인 |
| `./scripts/check-no-appkit.sh` | 통과 | shared Swift boundary 확인 |
| `xcodegen generate` | 통과 | project 생성 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` | 통과 | sandbox DNS 실패 후 네트워크 허용 재실행 성공 |
| `./scripts/validate-stage3-render.sh` | 통과 | `KTX.hwp`, `request.hwp`, `exam_kor.hwp` |
| `./scripts/package-release.sh 0.1.4` | 통과 | sandbox DNS 실패 후 네트워크 허용 재실행 성공 |
| `scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app` | 통과 | app/Preview/Thumbnail 모두 `x86_64 arm64` |
| `scripts/ci/write-release-delta-checklist.sh v0.1.3 HEAD build.noindex/release/delta-checklist-0.1.4.md` | 통과 | candidate commit `43438bcc...` |
| `scripts/ci/write-release-notes.sh 0.1.4 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef build.noindex/release/release-notes-0.1.4.md` | 통과 | placeholder SHA로 template 생성 |
| `scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.4.md` | 통과 | 최초 병렬 check는 write와 겹쳐 실패했고, 순차 재실행 통과 |
| `./scripts/release.sh --skip-notarize 0.1.4` | 통과 | unsigned local rehearsal DMG 생성 |
| `hdiutil verify build.noindex/release/alhangeul-macos-0.1.4-rehearsal.dmg` | 통과 | checksum valid |
| `scripts/verify-rhwp-studio-assets.sh build.noindex/release/Alhangeul.app/Contents/Resources/rhwp-studio` | 통과 | Release app bundle asset 확인 |

## 산출물

| 산출물 | SHA256 |
|--------|--------|
| `build.noindex/release/alhangeul-macos-0.1.4.zip` | `d4e48e1378d22b333e7c494a4a6beefd5b57511a39d5f9b2d4f35e334ff5bb9b` |
| `build.noindex/release/alhangeul-macos-0.1.4-rehearsal.dmg` | `24d3ce29183b277a79cacc4d051e4f02a81cd9f94eb64f4078edc7da4ec84a56` |

Release app bundle 기준 app, Quick Look preview extension, Finder thumbnail extension은 모두 `0.1.4 (10)`이다.

## 남은 작업

- Stage 4에서 `devel -> main` release PR, `v0.1.4` tag, public publish workflow gate를 별도 승인으로 진행한다.
- Stage 4 이후 signed/notarized public DMG, GitHub Release asset, stable Sparkle appcast, Pages deploy, public SHA256을 실제 산출물 기준으로 기록한다.
- Homebrew Cask 반영은 public DMG SHA256 확정 후 Stage 5에서 별도 승인으로 진행한다.
