# Task M900 #472 Stage 5 완료보고서

## 단계 목적

Stage 4 signed draft 차단 gate를 통과한 exact `v0.1.10` tag를 official stable release로 게시하고, public DMG, GitHub Pages, stable Sparkle appcast와 실제 `v0.1.9 -> v0.1.10` 업데이트·Finder provider를 공개 산출물 기준으로 검증한다. Homebrew는 이 단계 안에서도 별도 승인 gate로 유지했고, official publish 검증 뒤 추가 승인을 받아 실행했다.

## Official stable Publish

2026-08-15 KST 작업지시자의 별도 승인을 받아 annotated tag `v0.1.10`에서 다음 입력으로 `Release Publish DMG` workflow를 실행했다.

| 입력 | 값 |
|------|----|
| `version` | `0.1.10` |
| `previous_release_ref` | `v0.1.9` |
| `expected_rhwp_tag` | `v0.8.4` |
| `require_latest_rhwp` | `true` |
| `include_rhwp_in_title` | `true` |
| `draft` / `prerelease` | `false` / `false` |

실행 전 `origin/main`, tag peeled commit과 checkout 대상이 모두 `fafed425d4b87162c2188d1384d618adc2211eb6`임을 확인했다. Stage 3 제품 경계와 tag 사이 source diff는 없었고 upstream latest도 `rhwp v0.8.4`였다. release environment의 필요한 variable/secret 이름은 값 노출 없이 확인했다.

| 항목 | 결과 |
|------|------|
| workflow | [run `31812500336`](https://github.com/postmelee/alhangeul-macos/actions/runs/31812500336), success |
| exact head | tag `v0.1.10`, `fafed425d4b87162c2188d1384d618adc2211eb6` |
| release job | `94806246847`, 2026-08-15 00:02:32~00:19:40 KST, success |
| Pages job | `94810917280`, 2026-08-15 00:19:44~00:19:53 KST, success |
| GitHub Release | [`Alhangeul v0.1.10 (rhwp v0.8.4)`](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.10) |
| 공개 시각 | 2026-08-15 00:19:19 KST |
| 상태 | non-draft, non-prerelease, latest |

release job의 source/header/ABI/build-info 검증, Developer ID signing, notarization, staple, public artifact 검증, Release 게시, Sparkle EdDSA appcast 생성과 Pages artifact upload가 모두 통과했다. Pages job은 같은 release commit을 `pages_build_version`으로 사용해 성공했다. Actions에는 public DMG, appcast, Pages, release delta checklist와 PR analysis artifact가 남아 있다. runner의 `aws/tap` trust annotation은 build dependency 설치 환경 경고이며 Homebrew Cask 반영을 실행한 결과가 아니다.

## Public DMG 검증

| 항목 | 결과 |
|------|------|
| 파일 | `alhangeul-macos-0.1.10.dmg` |
| URL | https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.10/alhangeul-macos-0.1.10.dmg |
| 크기 | 169,177,234 bytes |
| SHA256 | `800ea0df2aee7ef380fb6af316f34d5a3c6bbbe60ef9b96054defac1e5dafd0e` |
| GitHub asset digest | actual SHA256와 일치 |
| checksum asset | `shasum -a 256 -c` 통과 |
| DMG integrity | `hdiutil verify` 통과 |
| version/build | 앱과 extension 모두 `0.1.10 (16)` |
| architecture | 앱, Preview와 Thumbnail 모두 `x86_64 + arm64` |
| code signature | deep/strict 검증 통과 |
| notarization / staple | 앱과 DMG 모두 통과 |
| Gatekeeper | 앱과 DMG 모두 `Notarized Developer ID` accepted |
| layout / Legal | root 앱과 `Applications` link, background, canonical Legal resource 확인 |

official run은 draft asset을 새로 생성한 public 산출물로 교체했다. 따라서 Stage 4 draft SHA256 `e54d5a1...a7af`가 아니라 위 public SHA256만 appcast와 후속 Homebrew 입력으로 사용할 수 있다. 다운로드한 public DMG와 checksum을 `build.noindex/task472-stage5-public/`에서 독립 검증한 뒤 DMG를 정상 detach했다.

## Pages와 stable appcast

| 표면 | 결과 |
|------|------|
| Pages home | https://postmelee.github.io/alhangeul-macos/, public v0.1.10 DMG 연결 |
| release note | https://postmelee.github.io/alhangeul-macos/updates/v0.1.10.html |
| 이전 release notice | v0.1.9 문서가 v0.1.10 note와 GitHub latest로 연결 |
| stable appcast | https://postmelee.github.io/alhangeul-macos/appcast.xml |
| appcast version/build | `0.1.10 (16)` |
| enclosure | public tag 고정 DMG URL, length `169177234` |
| signature | `sparkle:edSignature` 존재 |

Pages deployment 직후 공개 URL을 cache-busting query로 다시 내려받았다. home과 v0.1.10 note의 다운로드 링크, v0.1.9 최신 버전 안내와 stable appcast가 같은 public release를 가리켰고 appcast XML validity도 통과했다. 당시 Homebrew가 별도 승인 전이었으므로 v0.1.10 Pages의 “별도 배포 단계에서 반영” 문구를 유지했다. 이후 Cask 배포가 완료됐지만 public 문구는 Stage 6의 별도 `main` 대상 closeout PR과 Pages 재배포 전까지 그대로 둔다.

## 실제 Sparkle 업데이트

업데이트 전 `/Applications/Alhangeul.app`은 official `0.1.9 (15)`였고 deep/strict signature, Gatekeeper와 Preview/Thumbnail provider가 모두 유효했다. provenance가 섞이지 않도록 사용자 경로 `/Users/melee/Applications/Alhangeul.app` `0.1.8 (14)`의 registration만 잠시 해제해 `/Applications` v0.1.9을 유일한 기준선으로 만들었다. 기존 v0.1.9 app은 `build.noindex/task472-stage5-public/baseline-v0.1.9/`에 복구용으로 보관했다.

| 경로 | 결과 |
|------|------|
| update 발견 | v0.1.9 실행 시 public `0.1.10` update alert 표시 |
| download | Sparkle UI에서 169.2MB enclosure 다운로드 완료 |
| install | `설치 & 재실행` 완료 |
| 설치 결과 | `/Applications/Alhangeul.app`이 `0.1.10 (16)`으로 교체 |
| 앱 provenance | 재실행 직후 `rhwp v0.8.4 (496333b)` 확인 |
| trust | 설치본 deep/strict signature, staple와 Gatekeeper 통과 |
| natural provider refresh | Preview/Thumbnail 모두 `/Applications/Alhangeul.app`, `0.1.10` 한 항목으로 자연 갱신 |
| repair 사용 | 없음, `Registration repair used: 0` |

`scripts/smoke-sparkle-extension-refresh.sh` 기본 모드가 통과했다. HWP와 HWPX fresh sample thumbnail은 각각 `768x544`, `544x768` PNG로 생성됐고 SHA256은 `7391735b...7414dbb`, `9751c84c...cb4f618`이다. registration repair를 쓰지 않았으므로 업데이트 뒤 app extension refresh의 자연 상태를 release gate 근거로 사용한다.

## Public 앱과 Finder smoke

| 항목 | 결과 |
|------|------|
| HWP 앱 열기 | `samples/basic/KTX.hwp`, 1페이지 render |
| HWPX 앱 열기 | `samples/hwpx/hwpx-01.hwpx`, 9페이지 render |
| HWP Quick Look | KTX 노선도 non-blank render 확인 |
| HWPX Quick Look | 9페이지 navigation과 1페이지 non-blank render 확인 |
| Preview process | `/Applications/Alhangeul.app/.../AlhangeulPreview`, PID `35552` |
| Thumbnail process | `/Applications/Alhangeul.app/.../AlhangeulThumbnail`, PID `35312` |
| extension log | 두 executable 모두 `/Applications/Alhangeul.app`에서 launch, expected bundle identity 확인 |
| crash | publish·update·Finder smoke 이후 신규 DiagnosticReport 없음 |

HWPX 글꼴 안내에서는 원본 파일을 수정하지 않도록 대체 글꼴 표시로 render만 완료했고, 종료 시 검증 중 생긴 미저장 UI 상태는 저장하지 않았다. 저장·PDF·인쇄는 같은 candidate의 Stage 4 signed draft 차단 gate에서 이미 통과했으므로 Stage 5에서는 public update provenance와 open/Finder 경로에 집중했다.

## 등록과 설치 상태 정리

actual update 결과인 `/Applications/Alhangeul.app` `0.1.10 (16)`은 public 설치본으로 유지한다. smoke 중 잠시 격리했던 사용자 경로 v0.1.8은 파일을 변경하지 않고 LaunchServices/PlugInKit registration을 원상 복원했다. 최종 PlugInKit에는 public v0.1.10과 기존 사용자 v0.1.8 두 설치 root만 있고 개발·candidate provider는 없다.

과거 `build.noindex`의 비활성 LaunchServices record는 Stage 4와 같이 exact unregister가 `-10814`를 반환하는 상태다. 활성 provider provenance를 흐리지 않고 전역 reset은 다른 앱 등록까지 변경하므로 이번에도 수행하지 않았다. 실제 public smoke는 사용자 v0.1.8을 격리한 단일 v0.1.10 provider 상태에서 완료했다. 검증 앱과 provider process를 종료하고 DMG를 detach했으며 새 crash가 없음을 확인했다.

## Homebrew Cask 배포와 미실행 항목

official public DMG 검증 뒤 작업지시자의 별도 승인을 받아 repository와 public tap의 Cask를 같은 입력으로 갱신했다.

| 항목 | 결과 |
|------|------|
| Cask version | `0.1.10` |
| Cask SHA256 | `800ea0df2aee7ef380fb6af316f34d5a3c6bbbe60ef9b96054defac1e5dafd0e` |
| repository source | `Casks/alhangeul.rb`, public DMG checksum helper의 exact 결과 |
| public tap | [`postmelee/homebrew-tap` commit `f712c88`](https://github.com/postmelee/homebrew-tap/commit/f712c88e7e468395aeb09210cb6e24503dfb7d4f) |
| public raw Cask | `main`에서 version과 SHA256 일치 확인 |
| style | `brew style --cask alhangeul` 통과 |
| audit | `brew audit --cask alhangeul` 통과 |
| new-cask 참고 audit | `brew audit --cask --new alhangeul` 통과 |
| install | `brew install --cask postmelee/tap/alhangeul` 통과, `0.1.10 (16)` 설치 |
| installed trust | deep/strict signature, staple과 Gatekeeper 통과 |
| uninstall | `brew uninstall --cask alhangeul` 통과, Caskroom과 설치 앱 제거 확인 |

tap은 기존 `Untrusted` 상태를 유지했지만 fully-qualified install이 성공해 `brew trust` 같은 전역 신뢰 변경은 하지 않았다. smoke 과정에서 Homebrew 자체는 `6.0.15`에서 `6.0.17`로 자동 갱신됐고 다른 formula/cask는 변경하지 않았다.

기존 Sparkle 업데이트 결과인 `/Applications/Alhangeul.app` `0.1.10 (16)`을 `build.noindex/task472-stage5-public/pre-homebrew/`에 백업하고 등록을 해제한 뒤 `/private/tmp/alhangeul-task472-pre-homebrew-v0.1.10.app`로 옮겨 Homebrew 설치본과 격리했다. uninstall 후 이 원본을 exact path로 복원하고 LaunchServices/PlugInKit에 다시 등록했다. 최종 상태는 Homebrew cask 미설치, `/Applications` public v0.1.10과 기존 사용자 v0.1.8 provider 등록이며 앱 signature와 Gatekeeper가 유효하고 신규 crash가 없다.

Stage 6 closeout의 exact public 문서 범위는 다음과 같다. 아직 source나 public Pages는 변경하지 않았다.

- `README.md`: 최신 릴리즈 Homebrew 항목을 v0.1.10 제공 완료와 설치 명령으로 보정
- `docs/index.html`: FAQ의 배포 전/후 조건문을 현재 설치 가능 문구로 보정
- `docs/updates/index.html`: Homebrew 섹션을 현재 v0.1.10 설치 가능 문구로 보정
- `docs/updates/v0.1.10.html`: “별도 배포 단계에서 반영” 문구를 현재 설치 명령으로 보정

Stage 5 계획은 앞의 세 문서를 closeout 대상으로 열거했지만 실제 공개 release note에도 같은 대기 문구가 남아 있음을 재확인했다. Stage 6 대상 파일에는 `docs/updates/v0.1.10.html`이 이미 필요 시 범위로 포함돼 있으므로 네 파일을 한 PR과 Pages 재배포로 정렬한다.

Intel Mac 실기기 설치·실행은 수행하지 않았으며 성공으로 기록하지 않는다.

## 판정

- official Publish의 release job과 Pages job이 exact tag commit에서 성공했다.
- GitHub Release는 public stable/latest이고 DMG URL, SHA256과 size가 확정됐다.
- public DMG와 app/extension의 integrity, universal slice, signing, notarization, staple, Gatekeeper와 Legal gate가 통과했다.
- Pages와 stable appcast가 `0.1.10 (16)` 및 같은 public DMG를 가리킨다.
- clean official v0.1.9 baseline에서 실제 Sparkle update와 repair 없는 extension refresh가 통과했다.
- public 설치본에서 HWP/HWPX app open, Quick Look, Thumbnail과 실제 `/Applications` provider provenance를 확인했다.
- 신규 crash가 없고 대상 외 사용자 앱 파일과 registration을 복원했다.
- 별도 승인된 Homebrew Cask와 public tap 배포, style/audit/install/uninstall smoke가 통과했다.
- Stage 5 official stable publish, public surface와 Homebrew sub-gate를 모두 통과로 판정한다.

## 다음 승인 요청

Stage 6 release record·최종 보고와 종료 정리 진입 승인을 요청한다. 승인 뒤 네 public 문서의 Homebrew 완료 문구를 단일 `main` 대상 closeout PR로 반영하고, merge 후 Pages 재배포를 확인한다.
