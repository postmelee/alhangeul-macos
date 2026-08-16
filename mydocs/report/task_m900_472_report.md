# Task M900 #472 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#472 `v0.1.10 public release 준비와 배포 실행`](https://github.com/postmelee/alhangeul-macos/issues/472) |
| 마일스톤 | Release Operations |
| 기준 브랜치 | `devel` |
| 작업 브랜치 | `local/task472` |
| 공개 릴리즈 | [Alhangeul v0.1.10 (rhwp v0.8.4)](https://github.com/postmelee/alhangeul-macos/releases/tag/v0.1.10) |
| release commit | `fafed425d4b87162c2188d1384d618adc2211eb6` |
| release tag | annotated `v0.1.10` |
| app / extension | `0.1.10 (16)` |
| rhwp core / studio | `v0.8.4` / `496333b27d21ddb9114ba9ae340bcb895870c9a7` |
| Rehearsal | [run `31681525166`](https://github.com/postmelee/alhangeul-macos/actions/runs/31681525166) |
| signed draft | [run `31806721517`](https://github.com/postmelee/alhangeul-macos/actions/runs/31806721517) |
| official Publish | [run `31812500336`](https://github.com/postmelee/alhangeul-macos/actions/runs/31812500336) |
| Homebrew tap | [`postmelee/homebrew-tap` commit `f712c88`](https://github.com/postmelee/homebrew-tap/commit/f712c88e7e468395aeb09210cb6e24503dfb7d4f) |
| main closeout | PR [#477](https://github.com/postmelee/alhangeul-macos/pull/477) merge `7162a80`, [Pages run `31975531842`](https://github.com/postmelee/alhangeul-macos/actions/runs/31975531842) 성공 |
| 단계 | 수행계획, 구현계획, Stage 1~6 |

`v0.1.10` release source와 communication을 upstream `rhwp v0.8.4` 기준으로 정렬하고 source preflight, unsigned Rehearsal, signed/notarized draft 차단 gate를 거쳐 official stable release를 게시했다. public DMG, Pages, stable Sparkle appcast, 실제 `v0.1.9 -> v0.1.10` 업데이트와 app/Finder provider를 확인한 뒤 같은 official DMG를 maintainer Homebrew tap에도 배포했다.

Stage 6에서는 release identity와 public surface를 다시 조회하고 repository Cask, README, Pages source와 GitHub Release body의 Homebrew 대기 문구를 closeout 대상으로 확정했다. source 변경, appcast 보존 Pages artifact와 Release body 후보를 검증했고, 작업지시자 승인 뒤 공개 GitHub Release 본문을 후보와 일치하도록 보정했다. main closeout PR [#477](https://github.com/postmelee/alhangeul-macos/pull/477)은 merge commit `7162a80...`으로 반영됐고 docs-only Pages run `31975531842` 성공 뒤 public Homebrew 문구와 stable appcast byte 보존을 재확인했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Casks/alhangeul.rb` | public v0.1.10 DMG version/SHA256과 repository Cask 정렬 |
| `README.md` | 현재 Homebrew 설치 명령 반영 |
| `docs/index.html` | public 홈의 v0.1.10 Homebrew 안내 반영 |
| `docs/updates/index.html` | 업데이트 목록의 v0.1.10 및 Homebrew 안내 반영 |
| `docs/updates/v0.1.10.html` | 버전별 설치 안내 반영 |
| `mydocs/orders/20260813.md` | Stage 5/6 이력 상태 반영 |
| `mydocs/orders/20260816.md` | closeout source와 최종 보고 준비 완료 기록 |
| `mydocs/orders/20260817.md` | PR #477 merge·Pages 확인과 devel 최종 handoff 완료 기록 |
| `mydocs/release/index.md` | v0.1.10 closeout 완료 상태 반영 |
| `mydocs/release/v0.1.10.md` | release, Homebrew, main closeout과 public 재검증 장기 기록 |
| `mydocs/report/task_m900_472_report.md` | Task #472 최종 결과와 종료 조건 기록 |
| `mydocs/working/task_m900_472_stage4.md` | signed candidate 차단 gate 결과 기록 |
| `mydocs/working/task_m900_472_stage5.md` | official publish와 Homebrew 검증 결과 기록 |

최종 `devel` PR은 위 release/public 문서와 운영 기록 13파일만 변경하며 제품 `Sources/`, Xcode project, workflow와 이미 게시된 v0.1.10 release tag tree에는 영향을 주지 않는다.

## 변경 전·후 정량 비교

| 항목 | closeout 전 | closeout 후 |
|------|-------------|-------------|
| repository Cask | `0.1.9`, 이전 SHA256 | `0.1.10`, public DMG SHA256 `800ea0df...e5dafd0e` |
| public Homebrew 안내 | Release/Pages에 배포 전 문구 잔존 | GitHub Release와 Pages 3화면에 현재 설치 명령 반영 |
| stable appcast | `0.1.10 (16)`, SHA256 `36b5d62b...af5a` | 동일 version/SHA256 및 byte content 보존 |
| main closeout | 미반영 12파일 | PR #477 merge commit `7162a80...`, Pages run `31975531842` 성공 |
| devel 최종 PR 범위 | closeout 미반영 | 운영/문서 13파일, 제품 source/project/workflow 0파일 |

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행계획 | `8f6134f` | `v0.1.10 (16)`, `rhwp v0.8.4`, 6단계 release gate와 외부 mutation 승인 경계 확정 |
| 구현계획 | `b57d0bd` | source, Rehearsal, signed draft, official publish, Homebrew와 main closeout 절차 구체화 |
| Stage 1 | `58424de` | 세 app target과 release workflow 입력을 `0.1.10 (16)`, `v0.1.9`, `v0.8.4`로 정렬 |
| Stage 2 | `95800ee` | 포함 PR 분석, README, Pages, GitHub Release body 후보와 release record 작성 |
| Stage 3 | `aa1610f`, `4613106` | source/preflight, portable artifact, local package와 Rehearsal 통과, source PR handoff 보정 |
| Stage 4.1 | `8a59ce9`, `462944d` | release transport ancestry와 실제 content drift를 분리하고 history-only back-merge 생략 |
| Stage 4.2 / 4 | `868b119`, `8292782` | release PR/tag identity, signed draft와 저장·PDF·인쇄·Finder 차단 gate 통과 |
| Stage 5 | `2c6ba3a` | official stable Publish, public artifact/Pages/appcast와 실제 Sparkle update 검증 |
| Stage 5.1 | `870fa90` | repository/tap Cask 게시, audit/install/uninstall과 설치본 복구 |
| Stage 6 | `43390f2` | public communication closeout source, 최종 release record와 최종 보고 준비 |
| Stage 6.1 | `2f62314` | GitHub Release body 보정, 공개 본문 재검증과 closeout 기록 갱신 |
| Stage 6.2 | `12234b6` | main closeout PR #477 게시 결과와 exact diff 기록 |

Stage 1~3 변경은 PR [#473](https://github.com/postmelee/alhangeul-macos/pull/473)으로 `devel` merge commit `447b31b...`에 반영했다. PR [#475](https://github.com/postmelee/alhangeul-macos/pull/475)는 history-only back-merge 생략 판정을 `devel` merge commit `34ba512...`에 반영했고, PR [#476](https://github.com/postmelee/alhangeul-macos/pull/476)은 같은 tree를 `main` release commit `fafed425...`으로 승격했다.

## Release Identity와 브랜치 판정

| 항목 | 값 |
|------|----|
| previous release | `v0.1.9`, `ab7a74b5fc35dcdb56b121a8b74d00460a967e7b` |
| final source candidate | `34ba5127b9cd6614cffac6f0091201d3c3b1c13f` |
| release merge commit | `fafed425d4b87162c2188d1384d618adc2211eb6` |
| release tree | `7320f3a7e68a7a8926a40a041f44fc612d02db27` |
| tag object | `cd74a7ec8f3bc5bcc5862931b1eda9bbfeecc1b3` |
| tag peeled commit | `fafed425d4b87162c2188d1384d618adc2211eb6` |
| Stage 6 `origin/main` / `origin/devel` | `fafed425...` / `34ba512...` |
| Stage 6 left/right | `origin/main...origin/devel` = `4 0` |
| closeout `origin/main` / `origin/devel` | `7162a80...` / `34ba512...` |
| closeout left/right | `origin/main...origin/devel` = `12 0`, 기존 transport 4 + closeout head 7 + merge commit 1 |

`main` 전용 네 commit은 이전 release transport PR #446, #450, #452와 현재 release PR #476 merge다. 각 release merge tree는 대응 `devel` source parent tree와 같고 main 전용 non-merge 제품 content가 없으므로 history-only back-merge를 만들지 않았다. 이 판정을 반복 가능한 정책과 자동 gate로 만드는 후속은 Issue [#474](https://github.com/postmelee/alhangeul-macos/issues/474)로 분리했다.

Stage 5 이후에는 repository Cask, release record와 public Homebrew 문구라는 실제 closeout content가 생겼다. 이는 transport-only ancestry와 다르므로 Stage 6의 단일 `main` 대상 closeout PR과 `devel` 운영 기록 반영 대상으로 유지한다.

## Source, Provenance와 Rehearsal

| 검증 | 결과 |
|------|------|
| core/studio provenance | `v0.8.4` / `496333b...` 일치 |
| upstream root `Cargo.lock` | SHA256 `217783dc...`, bundled manifest fingerprint와 일치 |
| RustBridge tests | `7/7` 통과 |
| HostAppTests | `128/128` 통과 |
| ExternalImageTests | `27/27` 통과 |
| build-info/Cargo/decoder fixture | 모두 통과 |
| 세 target Release build | HostApp, Preview, Thumbnail 모두 성공 |
| renderer | HWP 4개와 HWPX 1개 page 1 PNG `5/5` |
| local universal package | 앱과 두 extension 모두 `x86_64 + arm64` |

local Rust/Cargo `1.94.1`, Xcode `26.6` 환경에서 strict static archive는 lock reference와 byte hash/size가 달랐다. reference `8c8b831f...` / 219,489,584 bytes에 대해 local 결과는 `65ee0ff3...` / 219,502,168 bytes였다. 이를 성공으로 바꾸거나 lock을 갱신하지 않았고, 작업지시자 승인에 따라 source, Cargo, generated header, FFI symbol과 XCFramework를 유지하는 portable 경계만 release artifact 허용 기준으로 사용했다.

Rehearsal run `31681525166`은 exact candidate `95800ee...`에서 성공했다. unsigned DMG는 167,711,221 bytes, SHA256 `ee9a25bf...dfdc`이며 checksum, `hdiutil verify`, mounted layout과 세 universal target이 통과했다. unsigned Rehearsal은 signing/notarization이나 public 배포 근거로 사용하지 않았다.

## Signed Candidate 차단 Gate

signed draft run `31806721517`은 exact release tag target `fafed425...`에서 성공했다. draft DMG는 169,177,242 bytes, SHA256 `e54d5a1d...a7af`이며 앱/extension 서명, notarization, staple, Gatekeeper, universal architecture, Legal resource와 mounted layout이 통과했다.

| Gate | 결과 |
|------|------|
| HWP/HWPX open | 1쪽 HWP와 9쪽 HWPX non-blank render |
| HWP 저장·재열기 | CFB signature, 별도 결과 파일과 1쪽 render 확인 |
| HWPX 저장·재열기 | ZIP integrity, 별도 결과 파일과 9쪽 render 확인 |
| 원본 보존 | 두 원본 SHA256 유지 |
| PDF | HWP 1쪽, HWPX 9쪽, geometry/searchable text/non-blank 확인 |
| 인쇄 | native panel HWP `1/1`, HWPX `9페이지 모두`, 취소 후 복귀 |
| WebKit 경계 | 자동 script/resource/navigation 차단 회귀와 signed 앱 정상 경로 통과 |
| Finder | 후보만 단독 등록해 Preview/Thumbnail executable path와 HWP/HWPX 결과 확인 |
| crash | 신규 DiagnosticReport 없음 |

첫 Finder smoke가 기존 `/Applications` v0.1.9 Thumbnail provider를 선택한 결과는 정상 이미지여도 v0.1.10 provenance 근거에서 제외했다. 기존 provider 등록을 잠시 격리한 뒤 signed candidate만 단독 등록해 다시 통과시켰고 검증 후 사용자 설치와 등록 상태를 복원했다.

## Official Public Artifact와 업데이트

| 항목 | 결과 |
|------|------|
| workflow | [run `31812500336`](https://github.com/postmelee/alhangeul-macos/actions/runs/31812500336), success |
| release job / Pages job | `94806246847` / `94810917280`, 모두 success |
| GitHub Release | non-draft, non-prerelease, latest |
| DMG | `alhangeul-macos-0.1.10.dmg`, 169,177,234 bytes |
| SHA256 | `800ea0df2aee7ef380fb6af316f34d5a3c6bbbe60ef9b96054defac1e5dafd0e` |
| artifact trust | checksum, integrity, deep/strict signature, notarization, staple, Gatekeeper 통과 |
| version / architecture | 앱과 extension 모두 `0.1.10 (16)`, `x86_64 + arm64` |
| stable appcast | `0.1.10 (16)`, public DMG URL/size, EdDSA signature |
| Stage 6 appcast SHA256 | `36b5d62bc9477bf6b586c19888071ba8610be0ac42a116b2a8be7bf5cee3af5a` |

clean official `/Applications/Alhangeul.app` `v0.1.9 (15)`에서 Sparkle UI로 `v0.1.10 (16)`을 download/install/relaunch했다. Preview와 Thumbnail provider가 registration repair 없이 같은 `/Applications` 설치본으로 자연 갱신됐고 `Registration repair used: 0`이었다.

public 설치본에서 HWP/HWPX 앱 열기, Quick Look와 Thumbnail을 다시 확인했다. 실제 Preview/Thumbnail process는 `/Applications/Alhangeul.app` 아래 executable이었고 신규 crash가 없었다. 사용자 경로 v0.1.8 앱 파일과 registration은 검증 뒤 복원했다.

## Homebrew

| 항목 | 결과 |
|------|------|
| 설치 명령 | `brew install --cask postmelee/tap/alhangeul` |
| Cask version | `0.1.10` |
| Cask SHA256 | official public DMG와 같은 `800ea0df...e5dafd0e` |
| tap commit | `f712c88e7e468395aeb09210cb6e24503dfb7d4f` |
| lint | `brew style`, 일반 `brew audit`, 참고용 `brew audit --new` 통과 |
| install | fully-qualified untrusted tap에서 `0.1.10 (16)` 설치 성공 |
| trust | deep/strict signature, staple과 Gatekeeper 통과 |
| uninstall | Caskroom과 Homebrew 설치 앱 제거 확인 |

tap의 기존 `Untrusted` 상태를 바꾸지 않았고 `brew trust` 같은 전역 신뢰 변경도 하지 않았다. smoke 중 Homebrew 자체는 `6.0.15`에서 `6.0.17`로 자동 갱신됐지만 다른 formula/cask는 변경하지 않았다. 종료 시 Homebrew Cask는 미설치 상태이며 기존 Sparkle 설치본 `/Applications/Alhangeul.app` `0.1.10 (16)`과 사용자 경로 v0.1.8 provider 등록을 복원했다.

## Stage 6 Closeout 완료

2026-08-16~17 live 재확인 결과는 다음과 같다.

| surface | 최종 live 상태 | 검증 결과 |
|---------|----------------|-----------|
| GitHub Release/DMG | v0.1.10 stable/latest와 exact asset 유지, Homebrew 설치 명령 반영 | 검증된 후보와 공개 본문 일치 |
| Homebrew tap | public v0.1.10 Cask 제공 | repository Cask와 같은 version/SHA256 |
| Pages home/update | v0.1.10 다운로드, 릴리즈 노트와 Homebrew 설치 명령 제공 | run `31975531842` 성공 뒤 세 화면 직접 확인 |
| stable appcast | `0.1.10 (16)`, SHA256 `36b5d62b...af5a` | closeout 전 public appcast와 byte-identical |
| release record | public/Homebrew/closeout 실제 결과 반영 | devel 최종 보고 handoff 준비 |

준비한 public source diff는 `README.md`, `docs/index.html`, `docs/updates/index.html`, `docs/updates/v0.1.10.html`의 Homebrew 문구다. repository Cask, release index/record, Stage 4~5 기록과 이 최종 보고서를 함께 release closeout 기록으로 유지한다.

`scripts/ci/update-release-version-notices.sh --updates-dir docs/updates --check`, release note template check, GitHub body validator와 prepared Pages artifact가 통과했다. prepared artifact와 closeout 뒤 public `appcast.xml`은 기존 public appcast와 byte-identical하다. GitHub Release body는 검증된 후보 파일과 전체 본문이 일치하고 현재 Homebrew 명령을 포함하며 이전 대기 문구가 제거됐다.

PR #477 게시 시점의 Stage 6 head를 당시 `origin/main`과 `origin/devel`에 각각 비교한 tree diff는 같은 12파일이었다. main closeout merge 뒤 devel 최종 후보에는 2026-08-17 오늘할일 기록을 더한 13파일만 남으며 `Sources/`, project, workflow와 release tag 제품 tree는 바꾸지 않는다.

main closeout PR [#477](https://github.com/postmelee/alhangeul-macos/pull/477)은 `main` 대상 exact 12파일로 merge됐다. merge commit `7162a80...`에서 실행된 docs-only Pages workflow도 성공했고 public 홈, 업데이트 목록, v0.1.10 note와 stable appcast를 직접 재검증했다.

## 승인 이력과 주요 결정

- release version/build, `rhwp v0.8.4`, 6단계 실행 계획과 단계별 승인 gate를 확정했다.
- strict static archive mismatch를 숨기지 않고 portable source/Cargo/header/FFI/XCFramework 경계를 release artifact 기준으로 별도 승인했다.
- source PR #473, branch 판정 PR #475, release PR #476 merge와 annotated tag 생성은 각각 검토 뒤 진행했다.
- signed draft, official stable Publish와 Homebrew tap 배포를 각각 별도 승인받았다.
- 익명 최초 실행·version transition event의 기본 활성화와 opt-out 전 첫 event 가능성을 인지한 상태에서 v0.1.10 정책으로 승인했다.
- stale LaunchServices record만 없애기 위한 전역 reset은 수행하지 않고 실제 provider path와 process provenance로 판정했다.
- Stage 6 closeout source와 최종 보고 작성은 2026-08-16 별도 승인으로 진행했다.
- 검증된 body file을 사용한 GitHub Release Homebrew 문구 보정과 공개 본문 재검증은 2026-08-16 후속 승인으로 진행했다.
- main closeout branch push와 draft PR #477 게시도 같은 후속 승인 범위에서 진행했다.
- PR #477 merge, public Pages 재검증, devel 최종 PR 게시·merge와 cleanup은 2026-08-17 작업지시자가 승인했다.

## 최종 수용 기준 검증

| 수용 기준 | 결과 | 상태 |
|-----------|------|------|
| release record/최종 보고 실제 값 | public DMG, run, commit, appcast와 Homebrew 값을 placeholder 없이 기록 | OK |
| public/repository communication 일치 | GitHub Release, Pages 3화면, Cask와 설치 명령 일치 | OK |
| main closeout 단일 PR | PR #477 exact 12파일 merge와 Pages 성공 | OK |
| devel 최종 PR exact diff | 오늘할일 포함 문서/운영 13파일, 제품 변경 없음 | OK |
| 오늘할일 완료 | `mydocs/orders/20260817.md`, 완료 시각 `07:12` | OK |
| cleanup 대상 확정 | Issue #472, `publish/task472`, `local/task472`, 분리 worktree 없음 | OK |

## 미실행 항목과 잔여 위험

| 항목 | 상태 | 후속 |
|------|------|------|
| Intel Mac 실기기 | 미실행 | universal `x86_64 + arm64` 자동 검증과 별도로 가능한 환경에서 runtime smoke |
| deployment target macOS 12 실장 | 미실행 | 지원 OS 실기기 검증 기회에 확인 |
| strict local static archive | byte mismatch | portable 승인 경계와 분리 유지, lock을 로컬 결과로 갱신하지 않음 |
| 실제 가로·세로 혼합 fixture | 없음 | 합성 SVG geometry와 orientation 미강제 자동 테스트로 보완 |
| PDF 전체 문서 progress/deadline | 미구현 | Issue #459 lifecycle 후속과 함께 검토 |
| render-tree producer golden | 미구현 | Issue #469 |
| known payload decode 진단 | 미구현 | Issue #470 |
| main/devel content gate | 규칙·자동화 미구현 | Issue #474 |
| 비활성 개발 LaunchServices record | 일부 잔존 | 활성 provider와 무관, 전역 reset 미사용 |

## 최종 결론

`v0.1.10 (16)`은 release commit `fafed425...`, upstream `rhwp v0.8.4`와 일치하는 signed/notarized universal app으로 public 배포됐다. source preflight, Rehearsal, signed 저장·PDF·인쇄·Finder 차단 gate, official GitHub Release, public DMG, Pages/appcast, 실제 Sparkle update와 maintainer Homebrew tap 배포에서 미해결 release blocker가 없다.

strict local static archive, Intel Mac/macOS 12 실기기, 일부 renderer/lifecycle 후속과 비활성 LaunchServices record는 실제 결과와 분리해 잔여 위험으로 기록했다. 어느 항목도 public v0.1.10 identity, signing/notarization, 실제 Apple Silicon 설치·업데이트·Finder 또는 Homebrew smoke를 실패시키는 blocker로 재현되지 않았다.

Task #472의 release 준비, official publish, Homebrew 배포 실행, GitHub Release 본문 보정과 repository `main`/public Pages closeout 목표를 모두 달성했다. 남은 절차는 이 최종 기록을 `devel`에 merge하고 Issue #472와 작업 브랜치를 정리하는 운영 종료뿐이다.

## 작업지시자 승인 및 종료 조건

2026-08-17 작업지시자가 `devel` 최종 PR 생성·merge와 `pr-merge-cleanup`까지 명시 승인했다.

1. Task #472 최종 기록 PR을 `devel` 대상으로 게시하고 CI를 확인한다.
2. merge commit 방식으로 PR을 merge해 단계별 커밋 의미를 보존한다.
3. Issue #472를 close하고 `publish/task472`, `local/task472`과 임시 worktree를 정리한다.
