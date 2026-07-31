# Task M900 #441 Stage 4 완료보고서

## 단계 목적

Stage 1~3에서 검증한 `v0.1.9 (15)` source와 release communication을 `devel`에 반영하고, `main` 전용 이력을 보존한 final release candidate를 annotated `v0.1.9` tag로 확정한다. 이어서 exact tag의 unsigned Rehearsal과 signed/notarized draft DMG를 다시 생성하고, 실제 앱·Finder·Preview·Thumbnail·editor 차단 smoke를 통과하는지 확인한다.

초기 signed candidate에서 발견한 Thumbnail crash는 Issue #447 / PR #448로 분리해 수정했다. 따라서 초기 `main` commit, tag 상태, Rehearsal과 signed draft를 final candidate 근거로 재사용하지 않고 PR #448 포함 candidate에서 모두 다시 검증했다.

## 검증 기준점

| 항목 | 값 |
|------|----|
| source PR | [#444](https://github.com/postmelee/alhangeul-macos/pull/444), head `46a67037147ddff887eaff92e3683d28b11a79fa`, merge `2b4c255b07c697dd101ddd4b2011391ef6833dcc` |
| main back-merge PR | [#445](https://github.com/postmelee/alhangeul-macos/pull/445), head `32c1129477dfd3c812f1eac758654f1e591b1888`, merge `1b1213db5a0bd75638f54bf03d49fbf4cb63edcc` |
| 초기 release PR | [#446](https://github.com/postmelee/alhangeul-macos/pull/446), merge `1e7f5df59684713745cb9d59c0a0e9dfdaaf0272`, PR #448 미포함으로 superseded |
| blocker 수정 PR | [#448](https://github.com/postmelee/alhangeul-macos/pull/448), head `ce720c4e34f1da4dfc219d9d811ab2628cd94c60`, merge `f2a78b799f62985d2767afc9ba4434581e9b10be` |
| candidate 갱신 PR | [#449](https://github.com/postmelee/alhangeul-macos/pull/449), head `c4fe6ecdec04d863a5506d3913b387a41835d62b`, merge `485c76cf32486d148fa88e30717e18c9794e810f` |
| final release PR | [#450](https://github.com/postmelee/alhangeul-macos/pull/450), head `485c76cf32486d148fa88e30717e18c9794e810f`, merge `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` |
| final `origin/devel` | `485c76cf32486d148fa88e30717e18c9794e810f` |
| final `origin/main` | `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` |
| annotated tag object | `v0.1.9` / `efc4423c6ab760024e2c8c92fbac0302e1f82c23` |
| tag peeled commit | `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` |
| app / extensions | `0.1.9 (15)` |
| rhwp core / studio | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| final Rehearsal | [run `30520836152`](https://github.com/postmelee/alhangeul-macos/actions/runs/30520836152) |
| signed draft Publish | [run `30522259476`](https://github.com/postmelee/alhangeul-macos/actions/runs/30522259476), `draft=true`, `prerelease=false` |
| 최신 공개 앱 | [`v0.1.8`](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.8), non-draft / non-prerelease |
| 최신 upstream | [`rhwp v0.8.2`](https://github.com/edwardkim/rhwp/releases/tag/v0.8.2), candidate lock과 일치 |
| release issue | [#441](https://github.com/postmelee/alhangeul-macos/issues/441), `OPEN`, `Release Operations` |

## 산출물

### GitHub와 release candidate

- PR #444, #445, #446, #448, #449, #450의 merge commit과 CI 결과
- annotated `v0.1.9` tag와 final `main` release commit
- exact tag의 final Rehearsal run `30520836152`
- exact tag의 signed/notarized draft Publish run `30522259476`
- 비공개 draft Release와 DMG/checksum asset

### 로컬 검증 산출물

- `build.noindex/task441-rehearsal-30520836152/`
- `build.noindex/task441-signed-draft-30522259476/`
- signed smoke 전 설치본 backup `build.noindex/task441-signed-draft-30522259476/pre-smoke-backup/Alhangeul.app`
- 외부 연결 그림 fixture `build.noindex/task441-stage3-07b9f34-external/hwp3-sample10-hwpx.hwpx`

`build.noindex/` 산출물은 검증 전용이며 Git 추적 대상이 아니다.

### 추적 문서

- 보정한 `mydocs/release/v0.1.9.md`
- 이 Stage 4 완료보고서

## 본문 변경 정도 / 본문 무손실 여부

이번 Stage 보고 commit은 제품 source, Xcode project, bundled studio asset과 public Pages 문서를 수정하지 않는다. 이미 merge된 exact candidate의 상태와 검증 결과만 release record와 단계 보고서에 반영한다.

- 기존 사용자용 release 요약과 포함 PR 판정은 유지했다.
- PR #448 이후 candidate 이동, final tag, workflow, draft DMG와 signed smoke 결과만 보정했다.
- public `v0.1.8` 다운로드, stable appcast와 Pages는 변경하지 않았다.
- official public DMG SHA256, appcast signature와 Homebrew digest는 여전히 미확정으로 남겼다.

따라서 제품 본문과 public surface는 무손실이며 문서 상태만 Stage 4 실제 결과와 일치시켰다.

## Source, main과 tag 정합성

### PR 반영

- PR #444는 `publish/task441 -> devel` source 반영이며 PR CI 4개 job이 모두 성공했다.
- PR #445는 PR #432의 `main` 전용 Pages 이력을 `devel`에 보존한 reviewed back-merge다. docs-only 분류에 따라 macOS/release helper job은 skip되고 classify/script job은 성공했다.
- PR #446은 최초 `devel -> main` transport였으나 뒤에 발견한 Thumbnail crash 수정 PR #448을 포함하지 않아 final candidate로 사용하지 않는다.
- PR #448은 RustBridge image data caller-owned buffer와 Swift exact free를 반영했고 macOS validation을 포함한 관련 CI가 성공했다.
- PR #449는 PR #448과 release communication을 final `devel` candidate로 묶었다. 변경 분류에 따른 macOS job skip을 제외하고 classify/script/release helper가 성공했다.
- PR #450은 final `devel -> main` transport이며 PR CI 4개 job이 모두 성공했다.

### Branch와 tree

최종 조회 결과:

```text
origin/main  = ab7a74b5fc35dcdb56b121a8b74d00460a967e7b
origin/devel = 485c76cf32486d148fa88e30717e18c9794e810f
origin/main...origin/devel = 2 0
```

`main` 전용 두 commit은 PR #446과 PR #450의 release transport다. `git diff --exit-code origin/main^{tree} origin/devel^{tree}`가 통과해 양 branch tree는 같다.

`git cat-file -t v0.1.9`은 `tag`이고, tag object `efc4423...`의 peeled commit은 final PR #450 merge commit `ab7a74b...`과 일치한다. annotation은 `Alhangeul v0.1.9`이다.

## Final Release Rehearsal

final tag에서 Rehearsal workflow를 처음부터 다시 실행했다.

| 항목 | 결과 |
|------|------|
| run | [`30520836152`](https://github.com/postmelee/alhangeul-macos/actions/runs/30520836152) |
| workflow / job | `Release Rehearsal DMG` / `Build rehearsal DMG` |
| head | `v0.1.9` / `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` |
| conclusion | `success` |
| DMG | `alhangeul-macos-0.1.9-rehearsal.dmg` |
| size | `163,109,772` bytes |
| SHA256 | `175ebb4ee421220ea6159bba4b9ecefa0c51d35ab7a7555412f59398023e1830` |
| checksum | `shasum -a 256 -c` 통과 |
| DMG integrity | `hdiutil verify` / `VALID` |

Workflow에서 release PR analysis, delta checklist, source/header/ABI lock, Rehearsal package와 artifact 검증이 모두 성공했다. 자동 분석의 candidate commit도 `ab7a74b...`과 일치한다.

## Signed/notarized draft

별도 승인으로 exact tag에서 `draft=true`, `prerelease=false` Publish workflow를 실행했다.

| 항목 | 결과 |
|------|------|
| run | [`30522259476`](https://github.com/postmelee/alhangeul-macos/actions/runs/30522259476) |
| head | `v0.1.9` / `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` |
| latest guard | upstream latest `v0.8.2` 확인 성공 |
| build job | signed/notarized DMG build와 release asset publish 성공 |
| Release 상태 | `draft=true`, `prerelease=false`, `publishedAt=null` |
| title | `Alhangeul v0.1.9 (rhwp v0.8.2)` |
| DMG | `alhangeul-macos-0.1.9.dmg`, `164,565,668` bytes |
| DMG SHA256 | `e65c3697ff46542137ee79fbfed0cf9f3c5f5b6ce7ef8e337f7b7b9be19a793f` |
| asset download count | `0` |
| stable appcast / Pages | 정책대로 skip |
| Pages deploy job | skip |

비공개 draft URL은 `https://github.com/postmelee/alhangeul-macos/releases/tag/untagged-43fc1d315706a98311c2`다. 이 URL과 digest는 Stage 4 후보 검증 근거이며 official public asset을 뜻하지 않는다.

## Signed artifact 정적 gate

다운로드한 draft artifact를 독립 재검증했다.

| 검증 | 결과 |
|------|------|
| checksum file | `shasum -a 256 -c` 통과 |
| DMG integrity | `hdiutil verify` / `VALID` |
| HostApp / Preview / Thumbnail version | 모두 `0.1.9 (15)` |
| HostApp architecture | `x86_64 + arm64` |
| Preview architecture | `x86_64 + arm64` |
| Thumbnail architecture | `x86_64 + arm64` |
| app deep signature | `valid on disk`, designated requirement 충족 |
| app staple | validate 성공 |
| DMG staple | validate 성공 |
| app Gatekeeper | `accepted`, `Notarized Developer ID` |
| DMG Gatekeeper | `accepted`, `Notarized Developer ID` |
| signing team | `XH6JHKYXV8` |
| candidate CDHash | `30d6332479839f45ea74709c46cf303404f94e14` |
| Legal | `LICENSE`, `THIRD_PARTY_LICENSES.md`, `FONTS.md` 포함 |
| mounted layout | `Alhangeul.app`, `/Applications` link, background 확인 |

제한된 sandbox 안에서 처음 호출한 `codesign`과 macOS 보안 서비스는 invalid/internal error를 반환했다. 동일 artifact의 절대 경로를 시스템 보안 서비스 권한으로 재실행하자 deep signature, staple와 Gatekeeper가 모두 통과했다. artifact 실패가 아니라 검증 환경 차이로 판정했다.

## Installed signed candidate smoke

### 후보 격리와 provenance

기존 public `/Applications/Alhangeul.app`과 분리해 candidate를 `/Users/melee/Applications/Alhangeul.app`에 설치했다.

- 실행 HostApp PID가 candidate 절대 경로를 가리킴을 확인했다.
- Preview process가 candidate의 `AlhangeulPreview` 절대 경로를 가리킴을 확인했다.
- Thumbnail process가 candidate의 `AlhangeulThumbnail` 절대 경로를 가리킴을 확인했다.
- 초기 표준 helper smoke 한 번은 `/Applications`의 v0.1.8 provider를 사용한 false positive였으므로 결과를 무효화했다.
- 이후 exact candidate provider만 남긴 상태에서 Finder 검증을 다시 수행했다.

### Finder Thumbnail

candidate Thumbnail provider에서 다음 6개 문서의 non-empty PNG를 생성했다.

| 문서 | PNG SHA256 앞 8자리 |
|------|---------------------|
| `KTX.hwp` | `a6aeb454` |
| `hwpx-01.hwpx` | `3ef08ff5` |
| external HWPX fixture | `6186603a` |
| `복학원서` HWP | `979482bb` |
| `img-start-001` HWP | `cbd796a1` |
| `hwp-img-001` HWP | `f4f0ffa1` |

검증 기준선 이후 Alhangeul 관련 crash report는 생성되지 않았다. 다른 시스템 서비스 crash는 제품 결과에서 제외했다.

### Finder Preview와 external fallback

- `KTX.hwp` Finder Space preview에서 실제 문서가 표시됐다.
- external fixture는 candidate Preview provider에서 `764`쪽 PDF를 만들었다.
- OSLog는 `externalResource attempted total=3 injected=0 permissionDenied=3`을 기록했다.
- 외부 그림 placeholder는 남았지만 main document는 fallback `0`, 출력 `78,138,983` bytes로 유지됐다.

이는 registered Quick Look sandbox에서 sibling 접근이 거부되는 현재 제한과 main document fallback 계약이 함께 성립함을 뜻한다.

### HostApp editor

- `KTX.hwp`는 `1`쪽으로 정상 열렸다.
- HWPX 앱 smoke에서는 `hwpx-02.hwpx`를 실제로 열었고 `7`쪽을 약 `137ms`에 렌더했다. Thumbnail의 `hwpx-01.hwpx`와 혼동하지 않는다.
- `issue1949_giant_cell_nested_tables_perf.hwp`는 `115`쪽을 약 `1702ms`에 열고 `115/115`까지 이동했다.
- 마지막 115쪽은 시각적으로 빈 페이지였지만 112쪽에서 실제 한글 내용 repaint를 확인했다. 따라서 end reach와 late-page repaint를 분리해 통과로 기록한다.
- 인쇄 dialog에서 preview `1/1`을 확인하고 취소했다.
- PDF export save panel에서 기본 파일명 `KTX.pdf`를 확인하고 취소했다.

smoke-only autosave/recovery 변경은 저장하지 않고 앱을 종료했다.

## 복구와 registration hygiene

- `/Users/melee/Applications/Alhangeul.app`은 smoke 전 backup의 v0.1.8 build 14로 복원했다.
- `/Applications/Alhangeul.app`은 기존 v0.1.8 build 14 설치본을 변경하지 않았다.
- candidate extension과 nested Sparkle Updater의 개발 registration을 제거했다.
- stale temporary Updater registration은 정확한 대상만 재구성해 unregister한 뒤 임시 app만 제거했다.
- `scripts/check-extension-registration-hygiene.sh --check-only`는 development registration, legacy candidate와 issue가 모두 없다고 판정했다.
- `build.noindex/`의 미등록 개발 app bundle 존재와 PlugInKit provider path 미보고는 warning으로만 남았다.
- signed DMG는 detach했고 임시 mount point를 정리했다.

## 검증 결과

| Gate | 결과 |
|------|------|
| source PR과 CI | 통과 |
| main-only 이력 보존 | PR #445 back-merge로 통과 |
| final release PR과 branch tree | PR #450 merge, tree 동일 |
| annotated tag identity | `v0.1.9^{}` = `ab7a74b...` |
| final Rehearsal | run `30520836152` 성공 |
| signed draft workflow | run `30522259476` 성공 |
| checksum / DMG integrity | 통과 |
| universal app / extensions | 통과 |
| signing / notarization / staple / Gatekeeper | 통과 |
| exact candidate app / Preview / Thumbnail provenance | 통과 |
| HWP/HWPX app와 Finder smoke | 통과 |
| external sibling permission fallback | 접근 거부와 main document 유지 확인 |
| 장문서 repaint / 인쇄 / PDF 시작 경로 | 통과 |
| crash | candidate 관련 신규 crash 0 |
| registration·설치본 복구 | 통과 |
| stable appcast / Pages 비변경 | draft 정책 skip, public v0.1.8 유지 |
| `git diff --check` | 통과 |

## 잔여 위험

- Intel Mac 실기기 설치·실행은 수행하지 않았다. `x86_64 + arm64` 자동 검증과 별개 위험으로 유지한다.
- registered Quick Look sandbox는 external sibling 3개 접근을 모두 거부했다. main document는 유지되지만 외부 그림은 표시되지 않는다.
- 초기 helper smoke가 다른 설치본 provider를 선택했다. 이후 exact provider 격리로 다시 검증했지만 향후 release smoke도 process path와 registration을 함께 확인해야 한다.
- 115쪽 문서의 마지막 페이지는 원문상 시각적으로 비어 있어 112쪽 실제 내용 repaint로 late-page gate를 보완했다. 전체 페이지 pixel regression suite는 이번 범위가 아니다.
- signed draft digest는 확정했지만 official workflow가 새 DMG를 만들면 public digest를 별도로 다시 기록해야 한다.
- `v0.1.8 -> v0.1.9` Sparkle update, public Pages/appcast와 Homebrew install/uninstall은 아직 실행하지 않았다.
- upstream page-local repaint Issue #3412 이슈와 PDF 안내 modal Issue #3450 이슈는 남아 있으나 이번 signed smoke에서는 blocker를 재현하지 않았다.

## 다음 단계 영향

Stage 5는 source, tag 또는 draft release body가 바뀌지 않은 동일 `ab7a74b...` candidate에서 시작해야 한다. candidate가 이동하면 Rehearsal과 signed draft gate를 다시 수행한다.

Stage 5 진입 뒤에도 다음 mutation은 분리한다.

1. `draft=false`, `prerelease=false` official stable Publish workflow
2. public GitHub Release, DMG/checksum, Pages와 stable appcast 검증
3. clean public v0.1.8 기준 Sparkle update와 extension refresh
4. 별도 승인된 Homebrew Cask 반영과 install/uninstall smoke

## 판정

- final `main`, annotated tag, Rehearsal과 signed draft가 같은 `ab7a74b...` candidate다.
- PR #448 이전의 초기 tag 상태와 run `30432036513` artifact는 계속 폐기한다.
- signed/notarized candidate의 앱, Finder, Preview, Thumbnail과 editor 차단 gate가 통과했다.
- 설치본과 extension registration을 복구했고 public v0.1.8 surface는 유지됐다.
- Stage 5 진입을 막는 미해결 Stage 4 blocker는 없다.

## 승인 요청

Stage 4 완료 결과를 승인하고 Stage 5 `Official stable publish와 public surface` 진입을 요청한다.

Stage 5의 official Publish와 Homebrew 반영은 각각 별도 승인 gate를 유지한다.
