# Task M900 #378 Stage 5 post-publish public surface 보고서

## 단계 요약

`v0.1.7` official stable publish를 완료하고 public GitHub Release, DMG asset, Sparkle appcast, Pages 업데이트 표면을 확인했다. Homebrew Cask 반영은 이번 승인 범위 밖의 별도 gate로 남겼다.

| 항목 | 값 |
|------|----|
| Release | [Alhangeul v0.1.7](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.7) |
| Workflow run | [`28130401337`](https://github.com/postmelee/alhangeul-macos/actions/runs/28130401337) |
| Tag commit | `876d2667c2bff60e8599af8bccb45c4cab19099f` |
| Public DMG | `alhangeul-macos-0.1.7.dmg` |
| Public DMG size | `156747415` |
| Public DMG SHA256 | `332208ff6f68c78a49d0fc60b895eeabb41d4996dad38fde158fa1935ab4b09d` |
| Pages release note | https://postmelee.github.io/alhangeul-macos/updates/v0.1.7.html |
| Sparkle appcast | https://postmelee.github.io/alhangeul-macos/appcast.xml |

## Workflow 결과

| Job | 결과 | 비고 |
|-----|------|------|
| Build signed/notarized DMG and publish release asset | 성공 | signed/notarized DMG build, public artifact verify, release notes, GitHub Release asset, stable appcast artifact 생성 |
| Deploy GitHub Pages | 성공 | generated appcast를 포함한 Pages artifact 배포 |

`Release Publish DMG` run은 `draft=false`, `prerelease=false`로 실행했으며 GitHub Release 상태 검증 step도 통과했다.

## Public surface 확인

| 검증 | 결과 |
|------|------|
| 최신 GitHub Release | `v0.1.7`, `draft=false`, `prerelease=false` |
| Release title | `Alhangeul v0.1.7 (rhwp v0.7.17)` |
| DMG asset digest | `sha256:332208ff6f68c78a49d0fc60b895eeabb41d4996dad38fde158fa1935ab4b09d` |
| `.dmg.sha256` 내용 | public DMG SHA256과 일치 |
| appcast item | `sparkle:shortVersionString=0.1.7`, `sparkle:version=13`, DMG URL, length `156747415`, EdDSA signature 포함 |
| Pages v0.1.7 note | v0.1.7 DMG URL, `rhwp v0.7.17`, `0.1.7 (13)` 안내 확인 |
| Pages updates index | 최신 항목과 다운로드 link가 v0.1.7 DMG를 가리킴 |

## 실행하지 않은 항목

| 항목 | 사유 |
|------|------|
| Homebrew Cask 갱신과 tap smoke | 별도 승인 gate. public SHA256은 확정됐지만 이번 지시는 GitHub Release/Pages/Sparkle 공개 배포까지로 처리 |
| Sparkle old-version update smoke | 기존 public 설치본에서 업데이트를 시작하는 별도 수동 검증이 필요함. 이번에는 stable appcast public surface 확인까지만 수행 |
| official stable DMG 재다운로드 후 로컬 Finder smoke | pre-public draft DMG는 작업지시자가 직접 smoke 완료. official stable DMG는 workflow의 signing/notarization/public artifact 검증과 public surface 확인으로 기록 |

## 다음 단계

Stage 6에서는 release record의 남은 pre-public 기록을 실제 결과로 보정하고 최종 보고서를 작성한다. Homebrew를 이번 릴리즈에 이어서 공개할 경우 별도 승인 후 public DMG SHA256 `332208ff6f68c78a49d0fc60b895eeabb41d4996dad38fde158fa1935ab4b09d` 기준으로 Cask와 tap 검증을 진행한다.
