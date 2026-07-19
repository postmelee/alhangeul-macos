# Task M900 #378 최종 보고서

## 개요

`v0.1.7` public release 준비, `devel -> main` 반영, `v0.1.7` tag 생성, pre-public signed/notarized DMG smoke, official stable GitHub Release 게시, Sparkle appcast와 Pages 배포, Homebrew Cask 반영과 smoke를 완료했다.

| 항목 | 값 |
|------|----|
| Issue | [#378](https://github.com/postmelee/alhangeul-macos/issues/378) |
| Release | [Alhangeul v0.1.7](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.7) |
| App version | `0.1.7` |
| Build | `13` |
| rhwp | `v0.7.17` / `03351190ec35436e58cbfee0aa9278a8fdc04a59` |
| Tag commit | `876d2667c2bff60e8599af8bccb45c4cab19099f` |
| Public DMG SHA256 | `332208ff6f68c78a49d0fc60b895eeabb41d4996dad38fde158fa1935ab4b09d` |
| Homebrew Cask | `brew install --cask postmelee/tap/alhangeul` |

## 반영 PR

| PR | 대상 | 내용 |
|----|------|------|
| [#379](https://github.com/postmelee/alhangeul-macos/pull/379) | `devel` | v0.1.7 source metadata, release communication, source preflight/rehearsal, publish gate 준비 |
| [#380](https://github.com/postmelee/alhangeul-macos/pull/380) | `main` | v0.1.7 release candidate main 반영 |

## 배포 결과

- `v0.1.7` tag는 main merge commit `876d2667c2bff60e8599af8bccb45c4cab19099f`를 가리킨다.
- pre-public draft workflow [`28116263365`](https://github.com/postmelee/alhangeul-macos/actions/runs/28116263365)가 성공했고, 작업지시자가 draft DMG 설치 smoke 완료를 확인했다.
- official stable workflow [`28130401337`](https://github.com/postmelee/alhangeul-macos/actions/runs/28130401337)가 성공했다.
- GitHub Release는 `draft=false`, `prerelease=false`, title `Alhangeul v0.1.7 (rhwp v0.7.17)`로 게시됐다.
- public DMG `alhangeul-macos-0.1.7.dmg`는 size `156747415`, SHA256 `332208ff6f68c78a49d0fc60b895eeabb41d4996dad38fde158fa1935ab4b09d`로 확정됐다.
- Sparkle appcast는 `sparkle:version=13`, `sparkle:shortVersionString=0.1.7`, public DMG URL, length `156747415`, EdDSA signature를 포함한다.
- GitHub Pages 배포 job이 성공했고, `updates/v0.1.7.html`과 updates index가 v0.1.7 public DMG를 가리킨다.

## Homebrew

- repository Cask source `Casks/alhangeul.rb`를 `0.1.7`과 public DMG SHA256으로 갱신했다.
- `postmelee/homebrew-tap` main commit `f1567d507f69e8b58164a879f008e754eda4b35e`에 같은 Cask를 반영했다.
- `brew style --cask alhangeul`, `brew audit --cask alhangeul`, `brew audit --cask --new alhangeul`이 통과했다.
- 임시 appdir `/private/tmp/alhangeul-homebrew-smoke-apps` 기준으로 `brew install --cask --appdir=... postmelee/tap/alhangeul`과 `brew uninstall --cask alhangeul` smoke를 완료했다.
- Homebrew 설치본은 `0.1.7 (13)`였고, `codesign --verify --deep --strict`와 `spctl --assess --type execute`가 통과했다.
- 검증 환경의 Homebrew 6.0.3은 `postmelee/tap`을 untrusted tap으로 차단해 `brew trust --cask postmelee/tap/alhangeul`을 선행했다. README, Pages, GitHub Release 본문에 같은 보조 명령을 안내한다.
- GitHub Release body는 Homebrew 설치 명령으로 직접 갱신했고 `scripts/validate-github-body.sh`를 통과했다.

## 주요 검증

| 검증 | 결과 |
|------|------|
| source preflight, Debug build, render smoke | 통과 |
| local rehearsal DMG | 통과 |
| pre-public signed/notarized draft DMG smoke | 통과 |
| official stable workflow signed/notarized DMG build | 통과 |
| GitHub Release public state | 통과 |
| public `.dmg.sha256` 내용 | 통과 |
| public appcast stable item | 통과 |
| Pages v0.1.7 release note와 updates index | 통과 |
| Homebrew Cask source/tap/style/audit | 통과 |
| Homebrew install/uninstall smoke | 통과 |
| GitHub Release Homebrew 안내 갱신 | 통과 |

## 남은 항목

- 기존 public 설치본에서 Sparkle update를 실제로 시작하는 smoke는 별도 수동 검증이 필요하다.
- Issue #378 close와 branch cleanup은 이 최종 기록 반영 후 수행한다.
