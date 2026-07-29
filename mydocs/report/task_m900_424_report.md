# Task M900 #424 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#424 `v0.1.8 public release 준비와 배포 실행`](https://github.com/postmelee/alhangeul-macos/issues/424) |
| 마일스톤 | Release Operations |
| 기준 브랜치 | `devel` |
| 작업 브랜치 | `local/task424` |
| 공개 릴리즈 | [Alhangeul v0.1.8 (rhwp v0.7.18)](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.8) |
| release commit | `542a35f2179e5499996b2ab7d2b1a94774b544a2` |
| release tag | annotated `v0.1.8` |
| app / extension | `0.1.8 (14)` |
| rhwp core / studio | `v0.7.18` / `93862a4e16df59834ebce46d91e948cd739208e9` |
| official workflow | [run 29671844342](https://github.com/postmelee/alhangeul-macos/actions/runs/29671844342) |
| 단계 | 수행계획, 구현계획, Stage 1~6 |

`v0.1.8` release source와 communication을 `rhwp v0.7.18` 기준으로 정렬하고, source preflight, unsigned rehearsal, signed/notarized draft 차단 gate를 거쳐 official stable release를 게시했다. public DMG, Pages, stable Sparkle appcast와 실제 v0.1.7 업데이트 경로까지 확인했다.

이번 릴리즈에는 HOP이 등록한 `net.golbin.hop.hwp`, `net.golbin.hop.hwpx` 호환 선언과 `rhwp v0.7.18` core/studio 개선이 포함된다. upstream latest `v0.7.19`는 custom scheme legacy Host RPC 회귀 `edwardkim/rhwp#2396` 때문에 제외했다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행계획 | `0c81dce` | 별도 worktree, Task 문서와 오늘할일 생성 |
| 구현계획 | `a24f4ad` | 6단계 release source, signed gate, publish와 cleanup 계약 확정 |
| Stage 1 | `be406ef` | app/extension `0.1.8 (14)`, workflow `v0.7.18` metadata 정렬 |
| Stage 2 | `2872cd1` | README, Pages, release note와 내부 release record 작성 |
| Stage 3 | `086ff46`, `8966128` | source preflight, universal package와 local rehearsal DMG 검증 |
| Stage 4 | `db4173f` | main/tag 확정, signed/notarized draft의 HOP exact UTI와 Host RPC 차단 gate 통과 |
| Stage 5 | `d117200` | official publish, public artifact/Pages/appcast와 실제 Sparkle 갱신 검증 |
| Stage 6 | 이번 커밋 | 최종 release record, 최종 보고와 오늘할일 완료 처리 |

Stage 1~3 source와 communication은 PR #425로 `devel`에 반영됐다. release PR #426은 `devel -> main`을 merge했고, main closeout은 PR #427로 `devel`에 역병합했다. 현재 최종 PR은 Stage 4~6 운영 기록을 `devel`에 반영하는 범위다.

## Release Identity와 Publish

| 항목 | 값 |
|------|----|
| version / build | `0.1.8 (14)` |
| previous release | `v0.1.7 (13)` |
| tag peeled commit | `542a35f2179e5499996b2ab7d2b1a94774b544a2` |
| expected rhwp tag | `v0.7.18` |
| expected rhwp commit | `93862a4e16df59834ebce46d91e948cd739208e9` |
| `include_rhwp_in_title` | `true` |
| `draft` / `prerelease` | `false` / `false` |
| GitHub Release 상태 | non-draft, non-prerelease, latest stable |
| published at | `2026-07-19T03:42:35Z` |

official run의 build/publish job과 Pages deploy job은 모두 성공했다. release tag ref와 head SHA가 확정 release commit에 일치하며, release input validation, core/header/ABI lock, Developer ID signing, notarization, public artifact, release notes, Sparkle appcast와 Pages deploy가 통과했다.

## Latest Guard 예외

workflow 기본값 `require_latest_rhwp=true`는 유지했다. Stage 4 draft와 Stage 5 official 실행에서만 별도 승인으로 `require_latest_rhwp=false`를 사용했다.

실행 시점 upstream latest는 `rhwp v0.7.19`였지만 Task #422에서 다음 release blocker를 확인했다.

- original v0.7.19 bundled studio가 `alhangeul-studio:` custom scheme에서 legacy `rhwp-request` Host RPC를 차단한다.
- 문서 표시는 가능해도 readiness, page count, 저장, 공유, 인쇄와 PDF 내보내기 command가 timeout된다.
- 원인은 upstream MessageChannel origin 검증으로 축소했고 [edwardkim/rhwp#2396](https://github.com/edwardkim/rhwp/issues/2396)에 등록했다. official publish 실행 시점에는 OPEN이었다.
- downstream vendor patch 없이 검증된 `v0.7.18`을 사용하고 수정된 후속 stable tag를 다음 core sync에서 검토한다.

따라서 latest guard skip은 임의 우회가 아니라 승인된 release decision이며, workflow의 안전 기본값은 약화하지 않았다.

official publish 뒤 upstream [PR #2398](https://github.com/edwardkim/rhwp/pull/2398)이 merge commit `7a64a7cef977f157893dd89cfd66d82c0d40e99a`로 반영되어 #2396은 CLOSED됐다. 그러나 Stage 6 조회에서도 최신 stable release는 계속 `v0.7.19`이므로 이 수정은 아직 release tag로 배포되지 않았고 v0.1.8의 `v0.7.18` provenance는 변경하지 않는다.

## Public Artifact

| 항목 | 결과 |
|------|------|
| DMG | `alhangeul-macos-0.1.8.dmg` |
| URL | https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.8/alhangeul-macos-0.1.8.dmg |
| size | 161,077,481 bytes |
| SHA256 | `ecf34e240c72c3d9123004f06e4d3a07806c8fa9f5323f471fd5c0cd19cfeb18` |
| checksum asset | `alhangeul-macos-0.1.8.dmg.sha256`, 92 bytes |
| DMG integrity | checksum과 `hdiutil verify` 통과 |
| code signature | deep/strict 검증, Designated Requirement 충족 |
| notarization | app과 DMG staple validate, Gatekeeper Notarized Developer ID accepted |
| architecture | app, Preview, Thumbnail 모두 `arm64 + x86_64` |
| legal resources | LICENSE, THIRD_PARTY_LICENSES, FONTS canonical hash 일치 |
| mounted layout | app과 Applications symlink 확인 |

draft run `29670015725`의 DMG SHA256은 `5d16eced...`이고 official DMG와 다르다. public 설치와 Homebrew 입력에는 official SHA256만 사용해야 한다. Stage 3 rehearsal DMG는 unsigned 검증 산출물이므로 배포에 사용할 수 없다.

## Signed Candidate Gate

### HOP Exact UTI와 Finder

signed app의 HostApp, Preview와 Thumbnail built plist에서 다음 호환 타입을 확인했다.

- `net.golbin.hop.hwp`
- `net.golbin.hop.hwpx`

exact handler 조회에 알한글이 포함됐고 Finder `다음으로 열기`에서 실제 알한글 후보를 선택해 9페이지 HWPX를 열었다. 기존 v0.1.7 provider와 HOP provider를 잠시 배제한 격리 smoke에서는 v0.1.8 Preview와 Thumbnail 실제 프로세스 경로, 9페이지 Quick Look과 non-blank PNG를 확인한 뒤 등록을 복원했다.

이 Mac의 `mdls`는 한컴 Viewer UTI cache를 우선했으므로 파일의 실제 content type을 `net.golbin.hop.*`로 직접 분류하지는 못했다. 이는 signed plist, exact handler, Finder 후보와 실제 open 결과와 분리해 기록했으며 release 차단 사유는 아니다.

### Host RPC와 앱 경로

signed candidate의 bundled `rhwp-studio v0.7.18`에서 HWP와 HWPX의 custom scheme readiness, load, page count와 non-white render가 통과했다. 실제 앱 UI에서 HWP/HWPX open, 저장 panel 시작, share 후보 표시, 1페이지 PDF export와 print preview까지 확인했다. 저장 원본 변경, 외부 공유 전송과 실제 print job은 수행하지 않았다.

## Pages와 Sparkle

| surface | 결과 |
|---------|------|
| Pages home | 최신 다운로드가 v0.1.8 public DMG를 가리킴 |
| release note | `updates/v0.1.8.html`, HTTP 200 |
| stable appcast version | `14` / `0.1.8` |
| enclosure | public DMG URL과 length `161077481` 일치 |
| release notes link | v0.1.8 Pages 문서 일치 |
| EdDSA | non-empty signature 확인 |
| minimum macOS | `12.0` |

기존 `/Applications/Alhangeul.app` v0.1.7에서 실제 `업데이트 확인...`을 실행했다. Sparkle이 v0.1.8 release note와 161.1MB public DMG를 표시했고 설치와 재실행 뒤 앱을 `0.1.8 (14)`로 교체했다.

post-update smoke는 `Registration repair used: 0`으로 통과했다. Preview와 Thumbnail provider는 각각 `/Applications/Alhangeul.app`의 v0.1.8 extension 경로 하나로 조회됐고, HWP/HWPX Thumbnail과 Finder Space Quick Look이 모두 실제 문서 내용으로 렌더링됐다.

## 변경 파일과 기록

| 경로 | 내용 |
|------|------|
| app/extension Info.plist | `0.1.8 (14)` identity 정렬 |
| release workflow | v0.1.8, previous v0.1.7, expected rhwp v0.7.18 기본 입력 정렬 |
| README, `docs/` | 최신 공개 릴리즈, Pages home/update와 이전 버전 고지 |
| `mydocs/release/v0.1.8.md` | release decision, delta, public artifact와 검증 기록 |
| `mydocs/working/task_m900_424_stage1.md` ~ `stage5.md` | 단계별 source, rehearsal, signed gate와 official publish 기록 |
| `mydocs/report/task_m900_424_report.md` | 전체 release 실행과 최종 판정 |
| `mydocs/orders/20260719.md` | Task #424 완료 상태 |

제품 source와 release communication은 이미 PR #425, #426과 #427을 통해 반영됐다. 이번 최종 PR은 Stage 4~6 이후 확정된 공개 artifact와 post-publish 검증 기록을 추가한다.

## Homebrew와 미실행 항목

Homebrew Cask는 public DMG URL과 SHA256을 확정했지만 별도 승인 없이 실행하지 않았다. 따라서 Cask 변경, `brew style`, `brew audit`, install/uninstall smoke와 Homebrew digest는 이번 Task 완료 근거에 포함하지 않는다. GitHub Release DMG와 Sparkle update는 정상적인 공개 설치 경로로 제공된다.

Intel Mac 실기기 설치와 실행도 수행하지 않았다. app과 두 extension의 universal `arm64 + x86_64` slice는 자동 검증했지만 Intel 실기기 runtime은 잔여 위험이다.

로컬 검증 결과 `/Applications/Alhangeul.app`은 public v0.1.8로 업데이트됐다. 공개 DMG 첫 설치 smoke에 사용한 `/Users/melee/Applications/Alhangeul.app` v0.1.8 복사본도 남아 있으므로 merge 후 cleanup에서 작업지시자 확인을 받아 정리한다.

## 잔여 위험과 후속

| 항목 | 상태 | 후속 |
|------|------|------|
| upstream #2396 | CLOSED, PR #2398 merge | 수정이 포함된 새 stable tag 확인 후 다음 core sync |
| Homebrew Cask | 미반영 | 별도 승인된 배포 작업에서 official SHA256 사용 |
| Intel Mac 실기기 | 미실행 | 가능한 환경에서 설치와 Quick Look smoke |
| external linked image | #408 C ABI 기반만 포함 | open #409 이후 제품 지원 판단 |
| Skia renderer | DEBUG/internal opt-in | production CoreGraphics default 유지 |
| Finder 후보 | 설치 앱과 LaunchServices 상태 영향 | 기본 앱 자동 변경을 주장하지 않음 |

## 최종 결론

`v0.1.8 (14)`는 release commit `542a35f...`, `rhwp v0.7.18`과 동일한 signed/notarized universal app으로 public 배포됐다. source preflight, rehearsal, signed HOP exact UTI, custom scheme Host RPC, public artifact, Pages/appcast, Finder와 실제 Sparkle update에 신규 blocker가 없다.

Homebrew와 Intel 실기기 검증은 명시된 미실행 항목으로 남지만 GitHub Release DMG와 Sparkle 경로의 official stable publish는 완료됐다. Task #424의 release 준비와 배포 실행 목표를 달성한 것으로 판정한다.

## 작업지시자 승인 요청

최종 보고서와 Stage 6 커밋을 승인해 주시면 `publish/task424` 원격 브랜치로 push하고 `devel` 대상 최종 운영 기록 PR을 게시한다. PR merge 뒤에는 Issue #424, local/publish branch와 분리 worktree를 `pr-merge-cleanup` 절차로 정리한다.
