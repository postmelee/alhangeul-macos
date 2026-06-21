# Task M900 #360 최종 보고서

## 개요

`v0.1.6` public release 준비, main 반영, signed/notarized DMG 게시, Sparkle/Pages 배포, Homebrew Cask 반영과 smoke를 완료했다.

| 항목 | 값 |
|------|----|
| Issue | [#360](https://github.com/postmelee/alhangeul-macos/issues/360) |
| Release | [Alhangeul v0.1.6](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.6) |
| App version | `0.1.6` |
| Build | `12` |
| rhwp | `v0.7.16` / `de02159ab4d2c5d165d6e25568bad3f8af5ef6cb` |
| Public DMG SHA256 | `87e37549a569813a3e22606f497ce837b350243cf3fed2ccd286af3ab8b02b9a` |
| Homebrew Cask | `brew install --cask postmelee/tap/alhangeul` |

## 반영 PR

| PR | 대상 | 내용 |
|----|------|------|
| [#361](https://github.com/postmelee/alhangeul-macos/pull/361) | `devel` | v0.1.6 source metadata, release communication, source preflight/rehearsal 기록 |
| [#362](https://github.com/postmelee/alhangeul-macos/pull/362) | `main` | v0.1.6 release candidate main 반영 |
| [#363](https://github.com/postmelee/alhangeul-macos/pull/363) | `devel` | DMG 숨김 폴더 위치 보정 |
| [#364](https://github.com/postmelee/alhangeul-macos/pull/364) | `main` | DMG layout 보정 main 반영 |
| [#365](https://github.com/postmelee/alhangeul-macos/pull/365) | `main` | Homebrew Cask 배포 기록과 공개 안내 갱신 |

## 배포 결과

- `v0.1.6` tag는 최종 main commit `ac54b0c3987934bd5649c62d544ac98f1468359e`를 가리키도록 보정했다.
- official stable workflow [`27901135462`](https://github.com/postmelee/alhangeul-macos/actions/runs/27901135462)가 성공했다.
- GitHub Release는 `draft=false`, `prerelease=false`, title `Alhangeul v0.1.6 (rhwp v0.7.16)`로 게시됐다.
- public DMG `alhangeul-macos-0.1.6.dmg`는 size `156184253`, SHA256 `87e37549a569813a3e22606f497ce837b350243cf3fed2ccd286af3ab8b02b9a`로 확정됐다.
- Sparkle appcast는 `sparkle:version=12`, `sparkle:shortVersionString=0.1.6`, public DMG URL, length `156184253`, EdDSA signature를 포함한다.
- Docs-only Pages Deploy [`27902064305`](https://github.com/postmelee/alhangeul-macos/actions/runs/27902064305)가 성공해 Homebrew 안내까지 public Pages에 반영됐다.

## Homebrew

- repository Cask source `Casks/alhangeul.rb`를 `0.1.6`과 public DMG SHA256으로 갱신했다.
- `postmelee/homebrew-tap` main commit `68c3be6870e37f05c308d41c556993b404f7340a`에 같은 Cask를 반영했다.
- `brew style --cask alhangeul`과 `brew audit --cask alhangeul`이 통과했다.
- 임시 appdir `/private/tmp/alhangeul-homebrew-smoke-apps` 기준으로 `brew install --cask --appdir=... postmelee/tap/alhangeul`과 `brew uninstall --cask alhangeul` smoke를 완료했다.
- Homebrew 설치본은 `0.1.6 (12)`였고, `codesign --verify --deep --strict`와 `spctl --assess --type execute`가 통과했다.
- 검증 환경의 Homebrew 6.0.2는 `HOMEBREW_REQUIRE_TAP_TRUST`가 설정되어 third-party Cask 로드 전 `brew trust --cask postmelee/tap/alhangeul`이 필요했다. README, Pages, GitHub Release 본문에 해당 안내를 추가했다.
- 참고 검증인 `brew audit --cask --new alhangeul`은 official cask 신규 제출 수준의 signature verification에서 `software has been altered`로 실패했다. maintainer tap 공개 gate는 일반 audit과 install/uninstall smoke 통과를 기준으로 완료 판단했다.

## 주요 검증

| 검증 | 결과 |
|------|------|
| source preflight, Debug build, render smoke | 통과 |
| local rehearsal DMG | 통과 |
| pre-public signed/notarized draft DMG smoke | 통과 |
| public DMG `hdiutil verify` | 통과 |
| public DMG codesign/stapler/Gatekeeper | 통과 |
| public app bundle `0.1.6 (12)` 확인 | 통과 |
| public app bundle codesign/Gatekeeper | 통과 |
| DMG hidden folder layout 보정 | 통과 |
| public Pages Homebrew 안내 반영 | 통과 |
| appcast 유지 확인 | 통과 |

## 남은 항목

- Issue #360 close와 `local/task360`/`publish/task360` 정리는 최종 보고 PR merge 확인 후 수행한다.
- `v0.1.6` 이후 제품 기능/renderer parity 개선은 별도 제품 milestone 이슈에서 다룬다.
