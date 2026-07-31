# Task M900 #441 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#441 `v0.1.9 public release 준비와 배포 실행`](https://github.com/postmelee/alhangeul-macos/issues/441) |
| 마일스톤 | Release Operations |
| 기준 브랜치 | `devel` |
| 작업 브랜치 | `local/task441` |
| 공개 릴리즈 | [Alhangeul v0.1.9 (rhwp v0.8.2)](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.9) |
| release commit | `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` |
| release tag | annotated `v0.1.9` |
| app / extension | `0.1.9 (15)` |
| rhwp core / studio | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| final Rehearsal | [run 30520836152](https://github.com/postmelee/alhangeul-macos/actions/runs/30520836152) |
| signed draft | [run 30522259476](https://github.com/postmelee/alhangeul-macos/actions/runs/30522259476) |
| official Publish | [run 30559705357](https://github.com/postmelee/alhangeul-macos/actions/runs/30559705357) |
| Homebrew tap | [`postmelee/homebrew-tap` commit `b8c7b6a`](https://github.com/postmelee/homebrew-tap/commit/b8c7b6a544989a32da9034ca7c6e6d4e241d3d10) |
| 단계 | 수행계획, 구현계획, Stage 1~6 |

`v0.1.9` release source와 communication을 upstream `rhwp v0.8.2` 기준으로 정렬하고 source preflight, unsigned Rehearsal, signed/notarized draft 차단 gate를 거쳐 official stable release를 게시했다. public DMG, Pages, stable Sparkle appcast, 실제 `v0.1.8 -> v0.1.9` 업데이트와 Finder surface를 확인한 뒤 같은 official DMG를 maintainer Homebrew tap에도 배포했다.

릴리스 과정에서 발견한 반응형 툴바 회귀와 Thumbnail image buffer 수명 회귀는 각각 Issue #442와 #447로 분리했다. PR #443과 #448 변경을 반영한 새 후보에서 영향을 받는 source, workflow와 수동 gate를 처음부터 다시 검증했으며, 결함이 있던 이전 candidate와 artifact는 공개 근거에서 제외했다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행계획 | `a49facd` | `v0.1.9 (15)`, `rhwp v0.8.2`, 6단계 release gate와 외부 mutation 승인 경계 확정 |
| 구현계획 | `8daf54d` | source, Rehearsal, signed draft, official publish, Homebrew와 종료 정리 절차 구체화 |
| Stage 1 | `2e0529f` | app/extension과 workflow 기본 입력을 `0.1.9 (15)`, `v0.1.8`, `v0.8.2`로 정렬 |
| Stage 2 | `1d35810` | 포함 PR 분석, README, Pages, release note와 내부 release record 작성 |
| Stage 3 / 3.1 | `a9760bb`, `07b9f34`, `46a6703` | PR #443 반영, source preflight 재검증과 corrected Rehearsal 통과 |
| Stage 4 / 4.1 | `c4fe6ec`, `f7bff92` | PR #448 포함 final candidate, tag, Rehearsal, signed draft와 수동 차단 gate 통과 |
| Stage 5 | `9e5dcb8` | official stable publish, public artifact/Pages/appcast와 실제 Sparkle update 검증 |
| Stage 5.1 | `63b7014` | Homebrew Cask 게시, audit/install/uninstall와 설치본 복구 |
| Stage 6 | 이번 커밋 | 최종 release record, 최종 보고서와 오늘할일 완료 처리 |

Stage 1~3 source와 communication은 PR [#444](https://github.com/postmelee/alhangeul-macos/pull/444)로 `devel`에 반영했다. PR [#445](https://github.com/postmelee/alhangeul-macos/pull/445)는 `main` 전용 Pages 이력을 `devel`에 보존했고, PR [#446](https://github.com/postmelee/alhangeul-macos/pull/446)은 초기 release candidate를 `main`에 반영했다.

Thumbnail crash 수정 뒤 PR [#449](https://github.com/postmelee/alhangeul-macos/pull/449)로 final source를 `devel`에 반영하고 PR [#450](https://github.com/postmelee/alhangeul-macos/pull/450)으로 final `devel -> main` candidate를 확정했다. 이번 종료 정리 PR은 Stage 4~6 운영 기록과 official Homebrew/Pages source 보정을 다시 `devel`에 반영하는 범위다.

## Release Identity와 Publish

| 항목 | 값 |
|------|----|
| version / build | `0.1.9 (15)` |
| previous release | `v0.1.8 (14)` |
| tag peeled commit | `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` |
| expected rhwp tag | `v0.8.2` |
| expected rhwp commit | `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| `require_latest_rhwp` | `true` |
| `include_rhwp_in_title` | `true` |
| `draft` / `prerelease` | `false` / `false` |
| GitHub Release 상태 | non-draft, non-prerelease, latest stable |
| published at | `2026-07-30T16:17:53Z` |

official run `30559705357`의 release job `90929268201`과 Pages deploy job `90933101471`은 모두 성공했다. 실행 head는 annotated `v0.1.9`의 peeled commit `ab7a74b...`과 일치했다. release input validation, upstream latest guard, core/header/ABI lock, Developer ID signing, notarization, public artifact 검증, GitHub Release, stable appcast와 Pages deploy가 통과했다.

## 무효화한 Candidate와 수정

| 계층 | 무효화한 근거 | 발견한 문제 | 수정과 재검증 |
|------|---------------|-------------|----------------|
| Stage 3 Rehearsal | run `30365232108`, candidate `1d358103...` | 창 너비에 따라 상단 toolbar/style bar가 겹치거나 잘림 | Issue #442 / PR #443, run `30424930226`에서 source와 Rehearsal 재검증 |
| 초기 Stage 4 signed draft | run `30432036513`, initial `main` `1e7f5df...` | external image data 수명 회귀로 Thumbnail crash | Issue #447 / PR #448, PR #449/#450으로 final candidate 갱신 |

final candidate에서는 Rehearsal run `30520836152`와 signed draft run `30522259476`을 모두 새로 실행했다. 초기 tag 상태, 초기 Rehearsal과 signed draft의 URL·digest는 public release, Sparkle 또는 Homebrew 입력으로 사용하지 않았다.

## Public Artifact

| 항목 | 결과 |
|------|------|
| DMG | `alhangeul-macos-0.1.9.dmg` |
| URL | https://github.com/postmelee/alhangeul-macos/releases/download/v0.1.9/alhangeul-macos-0.1.9.dmg |
| size | 164,565,695 bytes |
| SHA256 | `8110dc4cc2d965b4fe4d0a8cd6b285488a1fb5443f5bda606a35207c5bccc6ca` |
| checksum asset digest | `052d91db0130513d58e0844d9a12b2e8b968f6b84293d65a85e0fc670c6d8ace` |
| DMG integrity | checksum과 `hdiutil verify` 통과 |
| code signature | deep/strict 검증과 Designated Requirement 통과 |
| notarization | app/DMG staple validate와 Gatekeeper `Notarized Developer ID` accepted |
| signing identity | Team ID `XH6JHKYXV8`, CDHash `30d6332479839f45ea74709c46cf303404f94e14` |
| architecture | HostApp, Preview, Thumbnail 모두 `x86_64 + arm64` |
| legal resources | `LICENSE`, `THIRD_PARTY_LICENSES.md`, `FONTS.md` 포함 |
| mounted layout | `Alhangeul.app`, `/Applications` symlink와 배경 확인 |

final Rehearsal DMG SHA256은 `175ebb4e...e1830`, signed draft DMG SHA256은 `e65c3697...a793f`다. official workflow가 public DMG를 새로 만들었으므로 공개 설치, Sparkle과 Homebrew에는 official SHA256 `8110dc4c...c6ca`만 사용한다.

## Signed Candidate 차단 Gate

| Gate | 결과 |
|------|------|
| source/header/ABI | final tag에서 core/studio `v0.8.2` provenance와 portable release artifact 경계 통과 |
| app/extensions | 세 target `0.1.9 (15)`, universal, signed/notarized |
| HWP/HWPX 앱 열기 | 실제 문서 화면과 page count 확인 |
| Finder Thumbnail | 대표 HWP/HWPX 반복 생성, non-empty 이미지와 신규 crash `0` |
| Finder Quick Look | HWP/HWPX 실제 provider path와 문서 내용 확인 |
| external sibling | sandbox `permissionDenied=3`, 외부 그림 누락 상태에서도 764쪽 main document render 유지 |
| 장문서 | 115쪽 도달, 원문상 비어 있지 않은 112쪽 실제 내용 repaint 확인 |
| 인쇄/PDF | 인쇄 preview `1/1`, PDF export save panel 진입 확인 후 취소 |
| 트랙패드 pinch zoom | 배율 숫자 변화, 반대 pinch로 약 `78%` 복귀와 문서 중심 유지 확인 |
| registration hygiene | development/legacy registration issue `0` |

local strict `librhwp.a` byte reference는 재현 환경 차이로 mismatch가 남았다. 이를 성공으로 바꾸어 기록하지 않았고, portable source/Cargo/header/FFI/XCFramework 결과와 release workflow의 문서화된 portable artifact 경계를 별도로 통과시켰다.

## Pages와 Sparkle

| surface | 결과 |
|---------|------|
| Pages home | 최신 다운로드가 tag-fixed public v0.1.9 DMG를 가리킴 |
| release note | `updates/v0.1.9.html` 공개 및 사용자 변경 요약 확인 |
| stable appcast SHA256 | `c80b7f52571780bc23f095f436a39d1e177a3ed935488d47bcdad8d1bd2e372d` |
| appcast version | `sparkle:version=15`, `sparkle:shortVersionString=0.1.9` |
| enclosure | public DMG URL, length `164565695`, non-empty EdDSA signature 일치 |
| minimum macOS | `12.0` |

clean official `/Applications/Alhangeul.app` `v0.1.8 (14)`에서 Sparkle UI로 `v0.1.9 (15)`를 설치하고 재실행했다. HostApp과 Preview/Thumbnail provider는 exact `/Applications`의 새 버전을 가리켰고 registration repair는 `0`이었다.

업데이트된 public 앱은 HWP 1쪽을 `232.0ms`, HWPX 9쪽을 `132.0ms`에 열었다. fresh HWP/HWPX의 Finder Thumbnail과 Quick Look도 같은 public provider에서 실제 문서 내용으로 렌더링됐다.

## Homebrew

| 항목 | 결과 |
|------|------|
| 설치 명령 | `brew install --cask postmelee/tap/alhangeul` |
| Cask version | `0.1.9` |
| Cask SHA256 | official public DMG와 같은 `8110dc4c...c6ca` |
| tap commit | `b8c7b6a544989a32da9034ca7c6e6d4e241d3d10` |
| lint | `brew style`, 일반 `brew audit`, 참고용 `brew audit --new` 통과 |
| install | Caskroom `0.1.9`, 앱과 두 extension `0.1.9 (15)` |
| artifact 정합성 | 실행 파일, architecture, signature, notarization과 identity가 official 설치본과 일치 |
| 실행/extension | 최초 앱 화면 로드, extension refresh와 registration repair `0` |
| uninstall | Cask와 테스트 설치본 제거 확인 |

smoke 전에 격리한 official `/Applications/Alhangeul.app` `0.1.9 (15)`와 기존 `/Users/melee/Applications/Alhangeul.app` `0.1.8 (14)`는 원래 위치로 복구했다. 최종 상태는 Homebrew Cask 미설치, official `/Applications` 앱 복구, HostApp 미실행과 rehearsal DMG 미마운트다.

public GitHub Release의 Homebrew 문단은 검증된 설치 명령으로 갱신했다. 이 저장소의 README와 Pages source도 같은 명령으로 보정했지만, public Pages에는 아직 기존 “별도 배포 예정” 안내가 남는다. 현재 종료 정리 변경을 `devel`에 통합한 뒤 `main`으로 승격하고 docs-only Pages workflow를 실행해야 공개 문구가 최종 정렬된다.

## 변경 파일과 기록

| 경로 | 내용 |
|------|------|
| app/extension Info.plist | `0.1.9 (15)` identity 정렬 |
| release workflow | `v0.1.9`, previous `v0.1.8`, expected rhwp `v0.8.2` 기본 입력 정렬 |
| README, `docs/` | 최신 공개 릴리즈, Homebrew 설치 명령과 Pages update 안내 |
| `Casks/alhangeul.rb` | official public DMG version과 SHA256 반영 |
| `mydocs/release/v0.1.9.md` | candidate 이동, public artifact, signed/public/Homebrew 검증 기록 |
| `mydocs/working/task_m900_441_stage1.md` ~ `stage5.md` | 단계별 source, Rehearsal, signed gate, publish와 Homebrew 기록 |
| `mydocs/report/task_m900_441_report.md` | 전체 release 실행과 최종 판정 |
| `mydocs/orders/20260729.md` | Task #441 완료 상태 |

제품 source와 초기 release communication은 PR #444, #445, #446, #449와 #450을 통해 release commit에 반영됐다. 이번 최종 PR은 Stage 4~6 이후 확정된 공개 artifact, Homebrew/Pages source와 post-publish 검증 기록을 `devel`에 추가한다.

## 미실행 항목과 잔여 위험

| 항목 | 상태 | 후속 |
|------|------|------|
| Intel Mac 실기기 | 미실행 | universal `x86_64 + arm64` 자동 검증과 별도로 가능한 환경에서 runtime smoke |
| Quick Look external sibling | registered sandbox에서 `permissionDenied=3` | 외부 그림이 없어도 main document 유지, 관련 후속 Issue 경계 유지 |
| upstream #3412 / #3450 | 알려진 문제 | signed editor smoke에서 blocker 미재현, 다음 upstream sync에서 재평가 |
| strict local archive | reference byte mismatch | portable source/header/FFI 경계 통과와 분리 유지 |
| 공식 Homebrew Cask 저장소 | 미제출 | 이번 범위는 maintainer tap `postmelee/homebrew-tap`까지 |
| public Pages Homebrew 안내 | source 보정 완료, live 반영 전 | `devel -> main` docs 승격과 Pages workflow 성공 뒤 확인 |
| `build.noindex/` 개발 app | 미등록 bundle warning | 실제 provider는 process path와 PlugInKit 결과로 판정 |

## 최종 결론

`v0.1.9 (15)`는 release commit `ab7a74b...`, upstream `rhwp v0.8.2`와 일치하는 signed/notarized universal app으로 public 배포됐다. source preflight, final Rehearsal, signed 앱/Finder/editor 차단 gate, official GitHub Release, public DMG, Pages/appcast, 실제 Sparkle update와 maintainer Homebrew tap 배포에 신규 blocker가 없다.

릴리스 과정에서 발견한 두 차단 회귀는 별도 Issue와 PR로 수정한 뒤 새 candidate에서 검증을 다시 수행했다. Intel Mac 실기기와 registered Quick Look external sibling 제한은 명시된 잔여 위험이며, official release와 Homebrew 배포 완료 판정을 뒤집는 blocker로 재현되지 않았다.

Task #441의 release 준비, official publish와 Homebrew 배포 실행 목표는 달성했다. 다만 README/Pages의 Homebrew source 보정은 아직 public Pages에 반영되지 않았으므로, 종료 정리 PR의 `devel` merge 뒤 `main` docs 승격과 Pages 결과를 확인할 때까지 Issue #441은 자동으로 닫지 않는다.

## 종료 및 정리 조건

1. 이번 Stage 6 종료 정리 PR을 `devel`에 merge한다.
2. `devel -> main` docs 승격 PR을 별도로 검토·merge한다.
3. docs-only Pages workflow 성공과 공개 Homebrew 설치 문구를 확인한다.
4. 위 공개 반영을 확인한 뒤 Issue #441을 close한다.
5. PR merge 확인 후 `publish/task441`, `local/task441`과 불필요한 worktree를 `pr-merge-cleanup` 절차로 정리한다.
