# Task M900 #441 Stage 5 완료보고서

## 단계 목적

Stage 4 signed candidate 차단 gate를 통과한 exact `v0.1.9` tag를 official stable release로 게시하고, public GitHub Release·DMG·Pages·Sparkle와 실제 `v0.1.8 -> v0.1.9` 업데이트 뒤 앱·Preview·Thumbnail surface를 검증한다.

Homebrew Cask는 public DMG URL과 SHA256 확정 뒤에도 별도 승인 gate를 유지하므로 이번 단계에서는 수정하거나 설치·제거하지 않는다.

## 검증 기준점

| 항목 | 값 |
|------|----|
| annotated tag | `v0.1.9` |
| tag peeled commit | `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` |
| final `origin/main` | `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` |
| final `origin/devel` | `485c76cf32486d148fa88e30717e18c9794e810f` |
| app / extensions | `0.1.9 (15)` |
| rhwp core / studio | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| Stage 4 signed draft | run [`30522259476`](https://github.com/postmelee/alhangeul-macos/actions/runs/30522259476) |
| official Publish | run [`30559705357`](https://github.com/postmelee/alhangeul-macos/actions/runs/30559705357) |
| 직전 public baseline | `v0.1.8 (14)` |
| release issue | [#441](https://github.com/postmelee/alhangeul-macos/issues/441), `OPEN`, `Release Operations` |

official 실행 전에 tag와 `origin/main`, release body, Pages source, 앱·확장 version, core/studio provenance가 Stage 4 이후 바뀌지 않았음을 확인했다. `README.md`, `docs/`, release workflow, 앱·확장 source와 `rhwp-core.lock`은 tag와 동일했다. upstream latest도 계속 `v0.8.2`였고, release environment의 필요한 variable·secret 이름은 값을 노출하지 않고 확인했다.

## Official Publish 실행

별도 승인으로 annotated tag `v0.1.9`에서 다음 입력으로 `Release Publish DMG` workflow를 실행했다.

| 항목 | 값 |
|------|----|
| workflow run | [`30559705357`](https://github.com/postmelee/alhangeul-macos/actions/runs/30559705357) |
| exact head | `v0.1.9` / `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` |
| `version` | `0.1.9` |
| `previous_release_ref` | `v0.1.8` |
| `expected_rhwp_tag` | `v0.8.2` |
| `require_latest_rhwp` | `true` |
| `include_rhwp_in_title` | `true` |
| `draft` / `prerelease` | `false` / `false` |
| release job | `90929268201`, success |
| Pages deploy job | `90933101471`, success |

tag 입력 검증, upstream latest guard, source/header/ABI lock, signed/notarized DMG build, public artifact 검증, GitHub Release 게시, stable appcast 작성과 Pages artifact/deploy가 모두 성공했다. stable publish이므로 draft 정책용 skip 기록 step만 의도대로 skip됐다.

run annotation에는 runner에 이미 존재한 untrusted `aws/tap` Homebrew warning이 한 건 있었지만 이번 workflow나 공개 artifact에는 영향을 주지 않았다. 이번 단계에서는 Homebrew 명령을 실행하지 않았다.

## Public GitHub Release와 DMG

| 항목 | 결과 |
|------|------|
| GitHub Release | [Alhangeul v0.1.9 (rhwp v0.8.2)](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.9) |
| 공개 상태 | non-draft, non-prerelease, latest |
| published at | `2026-07-30T16:17:53Z` |
| DMG | `alhangeul-macos-0.1.9.dmg`, `164,565,695` bytes |
| DMG URL | https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.9/alhangeul-macos-0.1.9.dmg |
| SHA256 | `8110dc4cc2d965b4fe4d0a8cd6b285488a1fb5443f5bda606a35207c5bccc6ca` |
| checksum asset digest | `052d91db0130513d58e0844d9a12b2e8b968f6b84293d65a85e0fc670c6d8ace` |
| DMG integrity | checksum과 `hdiutil verify` 통과 |
| version | HostApp, Preview, Thumbnail 모두 `0.1.9 (15)` |
| architecture | HostApp, Preview, Thumbnail 모두 `x86_64 + arm64` |
| signing | deep/strict codesign과 Designated Requirement 통과 |
| notarization | app/DMG staple validate, Gatekeeper `Notarized Developer ID` accepted |
| signing identity | Team ID `XH6JHKYXV8`, CDHash `30d6332479839f45ea74709c46cf303404f94e14` |
| Legal | `LICENSE`, `THIRD_PARTY_LICENSES.md`, `FONTS.md` 포함 |
| mounted layout | `Alhangeul.app`, `/Applications` symlink와 배경 확인 |

workflow artifact는 `build.noindex/task441-official-30559705357/`에 내려받아 독립 검증했다. public DMG digest와 checksum asset은 workflow artifact와 일치했다. GitHub Release 본문도 official release note artifact와 일치했다.

Stage 4 draft DMG는 `164,565,668` bytes와 SHA256 `e65c3697...793f`였고 official workflow가 public DMG를 새로 생성했다. 따라서 Stage 5의 확정 공개 digest는 `8110dc4c...c6ca`이며 draft digest와 혼용하지 않는다.

## Pages와 Stable Appcast

| surface | 결과 |
|---------|------|
| Pages home | 최신 다운로드가 tag-fixed public v0.1.9 DMG를 가리킴 |
| v0.1.9 release note | https://postmelee.github.io/alhangeul-macos/updates/v0.1.9.html 접근 및 내용 확인 |
| updates index | v0.1.9 최신 DMG와 release note를 가리킴 |
| 이전 v0.1.8 note | v0.1.9 최신 안내와 링크 확인 |
| stable appcast SHA256 | `c80b7f52571780bc23f095f436a39d1e177a3ed935488d47bcdad8d1bd2e372d` |
| appcast version | `sparkle:version=15`, `sparkle:shortVersionString=0.1.9` |
| enclosure | public DMG URL과 length `164565695` 일치 |
| EdDSA | non-empty signature 확인 |
| minimum system | `12.0` |
| XML | `xmllint --noout` 통과 |

public appcast는 workflow artifact와 byte-identical했다. Pages home, `updates/`, `updates/v0.1.9.html`과 `updates/v0.1.8.html`도 tag source와 byte-identical했다. 고정 tag URL과 latest DMG URL은 같은 공개 asset으로 해석됐다.

## 실제 Sparkle Update와 Extension Refresh

### Clean baseline

기존 `/Applications/Alhangeul.app`은 official `v0.1.8 (14)` 설치본이었다.

| 항목 | 결과 |
|------|------|
| version | `0.1.8 (14)` |
| signature | deep/strict, staple와 Gatekeeper 통과 |
| CDHash | `8a9f55ae5ec255ae1ea07617bf3c068606b04c10` |
| Preview provider | `/Applications/Alhangeul.app`, `0.1.8` |
| Thumbnail provider | `/Applications/Alhangeul.app`, `0.1.8` |
| pre-update backup | `build.noindex/task441-official-30559705357/pre-update-backup/Alhangeul.app` |

표준 registration hygiene helper로 이전 Stage 4/static mount의 정확한 개발 registration만 해제한 뒤 clean baseline을 확정했다. baseline 앱 자체는 다시 설치하거나 수정하지 않았다.

### Sparkle UI

`알한글 > 업데이트 확인...`에서 public stable appcast의 `0.1.9`와 `164.6 MB` 업데이트를 확인했다. `업데이트 설치`와 `설치 & 재실행`을 거쳐 exact `/Applications/Alhangeul.app`이 다시 실행됐다.

| 항목 | 결과 |
|------|------|
| 설치본 | `/Applications/Alhangeul.app`, `0.1.9 (15)` |
| HostApp provenance | 실행 PID가 exact `/Applications` executable을 가리킴 |
| Preview provider | `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulPreview.appex`, `0.1.9 (15)` |
| Thumbnail provider | `/Applications/Alhangeul.app/Contents/PlugIns/AlhangeulThumbnail.appex`, `0.1.9 (15)` |
| registration repair | `0` |
| refresh smoke | `scripts/smoke-sparkle-extension-refresh.sh` 통과 |
| smoke 산출물 | `/private/tmp/alhangeul-sparkle-extension-refresh/20260731-012919` |
| update 재확인 | `알한글 0.1.9 이(가) 현재 최신 버전입니다.` |

자동 업데이트 preference는 변경하지 않았다. smoke용 문서에서 생긴 저장 상태는 원본에 기록하지 않고 `저장하지 않음`으로 종료했다.

## Public 앱과 Finder 검증

### Finder Thumbnail

refresh helper가 만든 fresh HWP/HWPX에서 첫 시도에 non-empty Thumbnail을 생성했다.

| 문서 | 크기 | SHA256 |
|------|------|--------|
| HWP | `345,577` bytes | `c502abade962875dfb6f341216c45e511841e0d155a4fe32e1e2975894d60ae3` |
| HWPX | `188,846` bytes | `5d43725798a96458ed7535e54e67e810b34f5919643e57002563d756ac9d948d` |

두 PNG를 직접 열어 실제 문서 내용이 정상 표시됨을 확인했다.

### Finder Quick Look

- HWP fresh sample은 KTX 노선도 1쪽을 정상 표시했다.
- HWPX fresh sample은 기획재정부 보도자료 9쪽과 page thumbnail navigation을 정상 표시했다.
- Quick Look 중 Preview process는 `/Applications/Alhangeul.app/.../AlhangeulPreview`를 가리켰다.
- Thumbnail process도 `/Applications/Alhangeul.app/.../AlhangeulThumbnail`을 가리켰다.

### HostApp 직접 열기

Sparkle로 갱신된 public 설치본에서 같은 fresh sample을 직접 열었다.

| 문서 | 결과 |
|------|------|
| HWP | KTX 노선도 `1`쪽을 `232.0ms`에 render, 실제 화면 확인 |
| HWPX | 기획재정부 보도자료 `9`쪽을 `132.0ms`에 render, 실제 화면 확인 |

두 문서 모두 `alhangeul-studio://app/index.html`의 current document revision으로 열렸고 상태 막대의 filename, page count와 render time이 일치했다. 테스트 후 앱은 종료했고 Finder 창은 검증 전의 다운로드 폴더로 복구했다.

## 설치본·registration 복구

- `/Applications/Alhangeul.app`은 실제 Sparkle update 결과인 official `v0.1.9 (15)`로 유지했다.
- HostApp은 종료했으며 남은 Preview/Thumbnail process는 official `/Applications` 경로만 사용했다.
- `scripts/check-extension-registration-hygiene.sh --check-only`는 development registration, legacy candidate와 issue가 모두 없다고 판정했다.
- 최종 hygiene diagnostics는 `/private/tmp/alhangeul-extension-registration-hygiene/20260731-020110`이다.
- `build.noindex/`의 미등록 개발 app bundle 존재와 PlugInKit provider path 미보고는 warning으로만 남았다.
- official publish 시점 이후 Alhangeul, Preview, Thumbnail 관련 신규 crash report는 `0`개다.
- signed DMG는 detach 상태이고 임시 mount registration은 남기지 않았다.

## 미실행 항목

- Homebrew Cask 수정과 `brew style/audit/install/uninstall`: public DMG URL과 SHA256은 확정했지만 별도 승인 전이라 실행하지 않음
- Intel Mac 실기기 설치와 실행: universal slice 자동 검증과 Apple Silicon 실기기 smoke로 대체했으며 미실행

## 검증 결과

| Gate | 결과 |
|------|------|
| exact tag와 upstream latest | 통과 |
| official release workflow | release / Pages jobs 성공 |
| GitHub Release stable/latest | 통과 |
| public DMG/checksum | SHA256, size와 asset 일치 |
| signing/notarization/staple/Gatekeeper | 통과 |
| universal app/extensions | 통과 |
| Pages와 stable appcast | version/build/URL/size와 EdDSA 정합성 통과 |
| v0.1.8 -> v0.1.9 Sparkle update | 통과 |
| extension refresh | repair `0`, exact public provider 통과 |
| HWP/HWPX 앱 직접 열기 | 통과 |
| HWP/HWPX Thumbnail / Quick Look | 통과 |
| 신규 crash | `0` |
| registration hygiene | issue `0` |
| Homebrew | 미진행, 별도 승인 gate |
| `git diff --check` | 통과 |

## 잔여 위험

- Intel Mac 실기기 설치·실행은 수행하지 않았다. `x86_64 + arm64` 자동 검증과 별개 위험으로 유지한다.
- registered Quick Look sandbox의 external sibling 접근 제한과 upstream Issue #3412, #3450은 Stage 4에 기록한 상태로 남는다. public update smoke에서 새 blocker는 재현하지 않았다.
- public DMG와 appcast digest는 확정했지만 Homebrew Cask는 아직 이전 공개 상태일 수 있다. 반영 전에는 GitHub Release DMG를 공식 설치 경로로 사용한다.
- helper가 발견하는 `build.noindex/` 개발 app bundle은 미등록 상태다. 실제 provider 검증은 process path와 PlugInKit 결과를 함께 사용했다.

## 판단

- official workflow의 release와 Pages job이 exact tag에서 성공했고 GitHub Release는 public stable/latest 상태다.
- public DMG의 checksum, signing, notarization, staple, Gatekeeper, universal slice와 layout이 통과했다.
- Pages와 stable appcast가 `0.1.9 (15)` 및 같은 public DMG URL과 size를 사용한다.
- clean official `v0.1.8 (14)`에서 실제 Sparkle update가 성공했고 수동 registration repair 없이 app/Preview/Thumbnail이 `v0.1.9 (15)`로 갱신됐다.
- public 설치본의 HWP/HWPX 앱 열기, Finder Thumbnail과 Quick Look이 exact `/Applications` provider에서 통과했다.
- Homebrew Cask는 별도 승인 gate로 남긴다.
- Stage 5 official publish와 post-publish public surface gate를 통과로 판정한다.

## 다음 단계 영향

Stage 6에서는 이 Stage 5 결과를 release record와 최종 보고서에 반영하고, Task #441 source/운영 기록을 `publish/task441` PR로 정리한다. Homebrew를 이번 타스크에 포함하려면 Stage 6 진입 전에 별도 승인을 받아 Cask 수정과 install/uninstall smoke를 먼저 수행해야 한다.

## 승인 요청

Stage 5 완료 결과를 승인하고 Stage 6 release record·최종 보고와 종료 정리 진행 승인을 요청한다.

Homebrew Cask를 이번 타스크에 포함할지는 별도 승인으로 결정한다.
