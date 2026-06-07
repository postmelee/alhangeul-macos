# Task M900 #351 Stage 3 완료 보고서

## 단계 목표

`v0.1.5` release candidate source가 Rust/core provenance, bundled asset, Swift boundary, Debug/Release build, native render smoke, release package, rehearsal DMG 기준을 통과하는지 검증했다.

## 실행 결과 요약

| 영역 | 결과 | 비고 |
|------|------|------|
| Git 상태 | 통과 | `local/task351`, 시작/종료 시 source 변경 외 작업 트리 clean |
| Rust bridge strict verify | 실패 | `Frameworks/universal/librhwp.a` byte hash/size mismatch |
| Rust bridge source/header/ABI verify | 통과 | `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1` 사용, lock은 수정하지 않음 |
| bundled `rhwp-studio` asset | 통과 | source와 Release app bundle 모두 확인 |
| Shared Swift boundary | 통과 | AppKit/UIKit 직접 의존 없음 |
| Xcode project generation | 통과 | `xcodegen generate` |
| Debug build | 통과 | Sparkle package resolve 때문에 네트워크 허용 재실행 |
| Native renderer smoke | 통과 | `KTX.hwp`, `request.hwp`, `exam_kor.hwp` |
| Release package | 통과 | Sparkle package resolve 때문에 네트워크 허용 재실행 |
| Universal slice | 통과 | app, Quick Look extension, Thumbnail extension 모두 `x86_64 arm64` |
| Release package version | 통과 | app, Preview, Thumbnail 모두 `0.1.5 (11)` |
| Rehearsal DMG | 통과 | unsigned, non-notarized local rehearsal artifact |
| Release helper dry-run | 통과 | release notes template check 통과 |
| Delta checklist | 통과 | `v0.1.4..HEAD`, candidate `b6b85829dbfc7f6f0d3557d41d082e56e26532fa` |

## 주요 명령

| 명령 | 결과 |
|------|------|
| `./scripts/build-rust-macos.sh --verify-lock` | 실패: `librhwp.a` byte hash/size mismatch |
| `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/build-rust-macos.sh --verify-lock` | 통과 |
| `scripts/verify-rhwp-studio-assets.sh` | 통과 |
| `./scripts/check-no-appkit.sh` | 통과 |
| `xcodegen generate` | 통과 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` | 통과 |
| `./scripts/validate-stage3-render.sh` | 통과 |
| `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/package-release.sh 0.1.5` | 통과 |
| `scripts/ci/verify-universal-macos-app.sh build.noindex/release/Alhangeul.app` | 통과 |
| `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/release.sh --skip-notarize 0.1.5` | 통과 |
| `hdiutil verify build.noindex/release/alhangeul-macos-0.1.5-rehearsal.dmg` | 통과 |
| `scripts/ci/write-release-delta-checklist.sh v0.1.4 HEAD build.noindex/release/delta-checklist-0.1.5.md` | 통과 |
| `scripts/ci/write-release-notes.sh 0.1.5 <64hex> build.noindex/release/release-notes-0.1.5.md` | 통과 |
| `scripts/ci/check-release-notes-template.sh build.noindex/release/release-notes-0.1.5.md` | 통과 |
| `scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check` | 통과 |
| `git diff --check` | 통과 |

## 산출물

| 산출물 | 크기 | SHA256 |
|--------|------|--------|
| `build.noindex/release/alhangeul-macos-0.1.5.zip` | `153730298` bytes | `9f2420b9a6ffc6edadd10252e488d038b3f59c4397c25ad74b22eff283f706f3` |
| `build.noindex/release/alhangeul-macos-0.1.5-rehearsal.dmg` | `153229477` bytes | `190a171e0ee66079507aabe2f0b7939f1b43274a1dd85677b3ce1cad01a1078b` |
| `build.noindex/release/delta-checklist-0.1.5.md` | git 제외 | release delta checklist draft |
| `build.noindex/release/release-notes-0.1.5.md` | git 제외 | GitHub Release body template dry-run |

`build.noindex/` 산출물은 git에 포함하지 않는다.

## 특이 사항

`./scripts/build-rust-macos.sh --verify-lock`의 strict staticlib byte hash 검증은 실패했다.

| 항목 | 값 |
|------|----|
| expected sha256 | `6049b39c078a4c59a4efe0e39c71fc557cf178aa02fe847f7d0c21902aeff62f` |
| actual sha256 | `e2b328dc3f4dfc1fdd5cc250ab988724dd9b1795a07814774c7a843117608bc5` |
| expected size | `200925744` |
| actual size | `200888664` |

스크립트 안내와 `build_run_guide.md` 정책에 따라 이 값만으로 `rhwp-core.lock`을 갱신하지 않았다. 대신 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`을 사용해 source provenance, `Cargo.lock`, generated header, FFI symbol set 검증을 유지했고 해당 검증은 통과했다. Stage 4/CI에서 GitHub-hosted release workflow가 같은 정책으로 통과하는지 별도 확인해야 한다.

Debug build, Release package, rehearsal DMG 최초 시도는 sandbox DNS 제한으로 Sparkle package resolve에 실패했고, 네트워크 허용 재실행에서 통과했다.

## 후속 단계로 넘길 항목

- Stage 4에서 `devel -> main` release PR 범위와 candidate commit을 확정한다.
- Stage 4에서 `v0.1.5` tag 생성과 pre-public signed/notarized draft DMG는 별도 승인 후 진행한다.
- Stage 4/5에서 public DMG SHA256, notarization/staple/Gatekeeper, Sparkle appcast, Pages deploy, Homebrew Cask digest를 확정한다.
- HostApp viewer smoke와 public 설치본 Finder Quick Look/Thumbnail smoke는 signed/notarized draft 또는 public DMG 기준으로 분리해 확인한다.

## 다음 승인 요청

Stage 4: Main/Tag/Pre-public Smoke와 Official Publish Gate 진행 승인을 요청한다.
