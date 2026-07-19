# Task M900 #424 Stage 5 완료보고서

## 단계 목적

Stage 4 signed candidate 차단 gate를 통과한 `v0.1.8 (14)`를 official stable release로 게시하고, public artifact, Pages, Sparkle와 설치 후 Finder surface를 검증한다.

## Official Publish 실행

별도 승인을 받아 annotated tag `v0.1.8`에서 다음 입력으로 `Release Publish DMG` workflow를 실행했다.

| 항목 | 값 |
|------|----|
| workflow run | [29671844342](https://github.com/postmelee/alhangeul-macos/actions/runs/29671844342) |
| release commit | `542a35f2179e5499996b2ab7d2b1a94774b544a2` |
| `version` | `0.1.8` |
| `previous_release_ref` | `v0.1.7` |
| `expected_rhwp_tag` | `v0.7.18` |
| `require_latest_rhwp` | `false` |
| `include_rhwp_in_title` | `true` |
| `draft` / `prerelease` | `false` / `false` |
| 결과 | build/publish job과 Pages deploy job 모두 성공 |

`require_latest_rhwp=false`는 upstream `v0.7.19`의 custom scheme legacy RPC 회귀 `edwardkim/rhwp#2396`을 피하기 위한 승인된 실행별 예외다. workflow 기본값 `true`는 변경하지 않았고 upstream Issue는 실행 시점에도 OPEN이었다.

## Public GitHub Release와 DMG

| 항목 | 결과 |
|------|------|
| GitHub Release | [Alhangeul v0.1.8 (rhwp v0.7.18)](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.8) |
| 공개 상태 | non-draft, non-prerelease, latest release |
| DMG | `alhangeul-macos-0.1.8.dmg`, 161,077,481 bytes |
| DMG URL | https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.8/alhangeul-macos-0.1.8.dmg |
| SHA256 | `ecf34e240c72c3d9123004f06e4d3a07806c8fa9f5323f471fd5c0cd19cfeb18` |
| checksum asset | `alhangeul-macos-0.1.8.dmg.sha256`, local checksum 일치 |
| DMG integrity | `hdiutil verify` 통과 |
| DMG signing | Gatekeeper Notarized Developer ID accepted, staple validate 통과 |
| app signing | deep/strict codesign, Gatekeeper와 staple validate 통과 |
| architecture | app, Preview, Thumbnail 모두 `arm64 + x86_64` |
| Legal | `LICENSE`, `THIRD_PARTY_LICENSES.md`, `FONTS.md` canonical hash 일치 |
| mounted layout | `Alhangeul.app`과 `Applications` symlink 구성 확인 |

sandbox 내부 `codesign --verify --deep --strict`는 resource 접근 제한 때문에 잘못된 invalid signature를 보고했다. 동일 app을 sandbox 밖에서 다시 검증해 `valid on disk`와 Designated Requirement 충족을 확인했으므로 제품 결함으로 판정하지 않았다.

## Pages와 Stable Appcast

official publish 전 public home과 stable appcast는 `v0.1.7 (13)`을 유지했고 `updates/v0.1.8.html`은 404였다. publish 뒤 다음 surface가 모두 v0.1.8로 전환됐다.

| surface | 결과 |
|---------|------|
| Pages home | 최신 다운로드가 public v0.1.8 DMG를 가리킴 |
| v0.1.8 release note | https://postmelee.github.io/alhangeul-macos/updates/v0.1.8.html 접근 및 내용 확인 |
| 이전 release note | v0.1.8 최신 릴리즈 고지와 링크 확인 |
| stable appcast | `sparkle:version=14`, `sparkle:shortVersionString=0.1.8` |
| enclosure | public DMG URL, length `161077481` 일치 |
| EdDSA | non-empty signature 확인 |
| XML | `xmllint --noout` 통과 |

appcast EdDSA signature는 다음과 같다.

```text
O55dgpadPSpSQfbH+XdZ4BMWalADNLYsq1FLt2SOwI8NqQbEixf6eBWLNFSGOIE31Zp42gTuZ030cLtvmMp6BQ==
```

## Public 설치본과 Finder 검증

공개 DMG의 app을 `/Users/melee/Applications/Alhangeul.app`에 설치해 기존 `/Applications/Alhangeul.app` v0.1.7을 덮어쓰지 않은 상태에서 먼저 검증했다.

| 경로 | 결과 |
|------|------|
| app identity | `0.1.8 (14)`, mounted public app과 실행 파일 SHA256 일치 |
| 첫 실행 HWP | `KTX.hwp`, 1페이지 정상 render |
| 첫 실행 HWPX | `hwpx-01.hwpx`, 9페이지 정상 render |
| Finder integration smoke | HWP와 HWPX Thumbnail 생성 통과 |
| smoke 산출물 | `/private/tmp/alhangeul-v018-official-finder/task151-20260719-124936` |
| UTI binding | 알한글 document type에 `net.golbin.hop.hwp`, `net.golbin.hop.hwpx` 포함 확인 |

생성된 HWP 512x363 PNG와 HWPX 363x512 PNG를 열어 실제 문서 내용이 비어 있지 않게 렌더링된 것을 확인했다. HOP과 한컴 Viewer가 함께 설치된 실제 LaunchServices 환경에서도 알한글의 HOP UTI binding이 유지됐다.

## 실제 Sparkle Update와 Extension Refresh

기존 `/Applications/Alhangeul.app` v0.1.7의 `알한글 > 업데이트 확인...`을 실행했다. Sparkle은 stable appcast에서 v0.1.8, public release note와 161.1MB DMG를 표시했고, `업데이트 설치`와 `설치 & 재실행`을 거쳐 앱을 `0.1.8 (14)`로 교체했다.

업데이트 뒤 결과는 다음과 같다.

| 항목 | 결과 |
|------|------|
| 설치본 | `/Applications/Alhangeul.app`, `0.1.8 (14)` |
| public app 동일성 | `/Users/melee/Applications` 공개 설치본과 실행 파일 SHA256 일치 |
| code signature | deep/strict 검증 통과 |
| notarization | Gatekeeper accepted, staple validate 통과 |
| refresh smoke | `OK: post-Sparkle extension refresh smoke passed` |
| 등록 보정 | `Registration repair used: 0` |
| Preview provider | `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex`, v0.1.8 단일 조회 |
| Thumbnail provider | `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex`, v0.1.8 단일 조회 |
| smoke 산출물 | `/private/tmp/alhangeul-v018-official-sparkle-refresh/20260719-125736` |

refresh smoke의 HWP 768x544와 HWPX 544x768 Thumbnail은 첫 시도에 생성됐고 실제 문서 내용이 정상 표시됐다. Finder에서 같은 fresh sample을 Space로 열어 HWP 1페이지와 HWPX 9페이지 Quick Look render 및 페이지 navigation을 확인했다. 전역 LaunchServices 수동 재등록이나 `--repair-registration`은 사용하지 않았다.

## 미실행 항목

- Homebrew Cask 반영과 install/uninstall smoke: public DMG URL과 SHA256은 확정했지만 별도 승인 전이라 실행하지 않음
- Intel Mac 실기기 설치와 실행: universal slice 자동 검증으로 대체했으며 실기기 미실행

## 판단

- official workflow의 release와 Pages job이 모두 성공했고 GitHub Release는 public stable 상태다.
- public DMG의 checksum, signing, notarization, staple, Gatekeeper, universal slice와 layout이 통과했다.
- Pages home, v0.1.8 release note와 stable appcast가 동일 version, build, DMG URL, size를 사용한다.
- 공개 설치본의 HWP/HWPX 앱 열기, Finder Thumbnail과 Quick Look이 통과했다.
- 실제 v0.1.7 -> v0.1.8 Sparkle update 뒤 수동 등록 보정 없이 Preview와 Thumbnail provider가 새 `/Applications` 경로로 갱신됐다.
- Homebrew Cask는 core release publish와 분리된 별도 승인 gate로 남긴다.
- Stage 5 official publish와 post-publish surface gate를 통과로 판정한다.

## 승인 요청

Stage 5 완료보고서와 단계 커밋 승인 후 Stage 6 최종 보고와 Task #424 cleanup handoff 진행 승인을 요청한다. Homebrew Cask를 이번 타스크에서 반영하려면 Stage 6 전에 별도 승인이 필요하다.
