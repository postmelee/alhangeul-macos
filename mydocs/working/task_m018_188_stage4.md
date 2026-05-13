# Task M018 #188 Stage 4 완료 보고서

## 단계 목적

`v0.1.1` public release workflow를 실행해 signed/notarized DMG, GitHub Release asset, stable Sparkle appcast, Pages release notes를 게시하고, public 산출물을 로컬에서 재검증한다.

확인 시각: `2026-05-11 01:35 KST`

## 산출물

| 파일 | 내용 |
|------|------|
| `scripts/release.sh` | CI notarization diagnostics, Sparkle nested component Developer ID signing, app/extension release entitlements signing 보정 |
| `.github/workflows/release-publish.yml` | release publish workflow 인증, cbindgen 설치, staticlib hash CI 예외 보정 |
| `.github/workflows/release-rehearsal.yml` | cbindgen 설치와 CI staticlib hash 예외 보정 |
| `scripts/ci/import-developer-id-certificate.sh` | keychain path output 오염 방지 |
| `scripts/build-rust-macos.sh` | CI toolchain static archive byte-for-byte mismatch 예외 환경변수 추가 |
| `Casks/alhangeul-macos.rb` | `0.1.1`과 public DMG SHA256 고정 |
| `mydocs/release/v0.1.1.md` | public release 결과와 검증 기록 반영 |
| `mydocs/working/task_m018_188_stage4.md` | Stage 4 완료 보고서 |
| `mydocs/orders/20260511.md` | Stage 5 승인 대기 상태 기록 |

## GitHub 설정 변경

| 항목 | 결과 |
|------|------|
| Pages source | `build_type=workflow`로 전환 |
| Pages URL | `https://postmelee.github.io/alhangeul-macos/` |
| `github-pages` environment | tag deployment policy `v*` 추가 |
| `v*` policy id | `49055451` |

## Release workflow 결과

| 항목 | 값 |
|------|----|
| 최종 run | `25633522344` |
| run URL | https://github.com/postmelee/alhangeul-macos/actions/runs/25633522344 |
| 결론 | success |
| release tag | `v0.1.1` |
| release commit | `2c750fb10c1458934cfab37d41cd5d9c6b82c600` |
| GitHub Release | https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.1 |
| publishedAt | `2026-05-10T16:22:39Z` |
| draft / prerelease | `false` / `false` |
| latest release | `v0.1.1` |

## Public asset

| 항목 | 값 |
|------|----|
| DMG | `alhangeul-macos-0.1.1.dmg` |
| size | `91427682` bytes |
| SHA256 | `5b17271d7724cf9d9aff2badbdbbe936eccc16178c66b28c6207e89cd6de5d29` |
| checksum asset | `alhangeul-macos-0.1.1.dmg.sha256` |
| appcast | `https://postmelee.github.io/alhangeul-macos/appcast.xml` |
| release notes | `https://postmelee.github.io/alhangeul-macos/updates/v0.1.1.html` |

## 검증 결과

| 명령/확인 | 결과 | 비고 |
|-----------|------|------|
| `git ls-remote --tags origin 'v0.1.1^{}'` | OK | `2c750fb10c1458934cfab37d41cd5d9c6b82c600` |
| `gh release view v0.1.1` | OK | DMG와 checksum asset 게시, draft/prerelease false |
| `gh release view` | OK | latest release가 `v0.1.1` |
| `shasum -a 256 -c alhangeul-macos-0.1.1.dmg.sha256` | OK | downloaded public asset 기준 |
| `hdiutil verify alhangeul-macos-0.1.1.dmg` | OK | checksum VALID |
| `codesign --verify --deep --strict` | OK | public app copy 기준, sandbox 밖 검증 |
| `codesign --verify --strict` | OK | Quick Look/Thumbnail extension 단독 검증 통과 |
| `xcrun stapler validate` | OK | mounted app과 DMG 모두 validate 통과 |
| `spctl --assess` | OK | copied public app과 DMG 모두 `source=Notarized Developer ID` |
| `scripts/ci/verify-universal-macos-app.sh` | OK | app/preview/thumbnail 모두 `x86_64 arm64` |
| `xmllint --noout appcast.xml` | OK | public appcast XML 검증 통과 |
| public release notes fetch | OK | `updates/v0.1.1.html` 다운로드 확인 |
| public updates index fetch | OK | latest DMG link와 `v0.1.1` entry 확인 |
| Legal canonical diff | OK | `LICENSE`, `THIRD_PARTY_LICENSES.md`, `FONTS.md` 모두 일치 |

## 서명/공증 보정 내역

초기 Stage 4 workflow는 public asset을 게시하기 전에 여러 차례 실패했다. 각 실패는 release workflow 또는 release script의 배포 전 gate에서 발생했고, 최종 성공 전 모두 보정했다.

| run | 실패 지점 | 원인 | 보정 |
|-----|-----------|------|------|
| `25632437884` | upstream latest rhwp release 확인 | workflow에서 `GH_TOKEN`을 제거해 `gh` 인증 실패 | release workflow 인증 보정 |
| `25632495693` | Developer ID certificate import | helper stdout에 `security` output이 섞여 `$GITHUB_OUTPUT` format 오류 | keychain path stdout만 남기도록 보정 |
| `25632545387` | rhwp lock verify | runner에 `cbindgen` 없음 | release/rehearsal workflow에서 `brew install cbindgen` 보정 |
| `25632598126` | rhwp staticlib hash verify | CI Rust/Xcode toolchain static archive byte-for-byte non-reproducibility | source lock, Cargo lock, header, FFI symbol 검증은 유지하고 staticlib hash만 CI 예외 |
| `25632780594` | app notarization | notary status `Invalid` 후 로그 없이 stapling 진행 | notary JSON status 파싱과 log 출력 보정 |
| `25633064531` | app notarization | Sparkle nested XPC/Autoupdate가 ad-hoc signature와 timestamp 없음 | Sparkle nested component Developer ID/timestamp signing 보정 |
| `25633267598` | app notarization | Quick Look/Thumbnail extension에 `get-task-allow`와 timestamp 없음 | app/extension 배포용 entitlements로 재서명 |
| `25633522344` | 없음 | 최종 workflow 성공 | public release 게시 완료 |

## Legal 확인

| 항목 | 결과 |
|------|------|
| `NSHumanReadableCopyright` | `Copyright © 2025-2026 Taegyu Lee` |
| `Contents/Resources/Legal/LICENSE` | 포함, root `LICENSE`와 일치 |
| `Contents/Resources/Legal/THIRD_PARTY_LICENSES.md` | 포함, canonical file과 일치 |
| `Contents/Resources/Legal/FONTS.md` | 포함, canonical file과 일치 |
| rhwp/rhwp-studio provenance | `THIRD_PARTY_LICENSES.md`에 고지 |
| Sparkle provenance | `THIRD_PARTY_LICENSES.md`에 고지 |
| bundled WOFF2 font provenance | `THIRD_PARTY_LICENSES.md`, `FONTS.md`에 고지 |
| app icon/logo provenance | `THIRD_PARTY_LICENSES.md`에 고지 |

## 실행하지 않은 항목

- 기존 로컬 public `v0.1.0` 설치본의 Sparkle 수동 업데이트 확인은 아직 실행하지 않았다. 사용자 지시에 따라 Stage 5에서 기존 설치본 보존 상태로 진행한다.
- public `v0.1.1`을 완전히 삭제 후 재설치하는 smoke는 아직 실행하지 않았다. Stage 5에서 Sparkle 업데이트 확인 후 진행한다.
- Intel Mac 실기기 smoke는 이번 Stage 4에서 실행하지 않았다. 접근 가능한 Intel Mac 환경에서만 성공으로 기록한다.
- Homebrew tap 공개, `brew style`, `brew audit`, tap install smoke는 #209 범위로 남긴다.

## 다음 단계

Stage 5 진입 승인 후 다음 순서로 진행한다.

1. 현재 로컬 public `v0.1.0` 설치본에서 Sparkle 업데이트 확인
2. `v0.1.0` 설치본 완전 삭제
3. public `v0.1.1` DMG 재설치
4. 앱 실행, 문서 열기, window zoom/resize, Quick Look preview, Finder thumbnail smoke
5. Stage 5 결과를 `mydocs/release/v0.1.1.md`와 최종 보고서에 반영
