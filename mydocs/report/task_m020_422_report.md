# Task M020 #422 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#422 `rhwp v0.7.19 회귀 판정과 v0.7.18 릴리스 후보 확정`](https://github.com/postmelee/alhangeul-macos/issues/422) |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 기준 브랜치 | `devel` |
| 작업 브랜치 | `local/task422` |
| 검토 release | [edwardkim/rhwp v0.7.19](https://github.com/edwardkim/rhwp/releases/tag/v0.7.19) |
| 최종 release candidate | [edwardkim/rhwp v0.7.18](https://github.com/edwardkim/rhwp/releases/tag/v0.7.18) |
| 최종 resolved commit | `93862a4e16df59834ebce46d91e948cd739208e9` |
| automation candidate | [PR #421](https://github.com/postmelee/alhangeul-macos/pull/421), `ddcc0329ae1b6bef7c6dacb51ee8375de3b6d42c` |
| upstream regression | [edwardkim/rhwp#2396](https://github.com/edwardkim/rhwp/issues/2396) |
| 단계 | 수행계획, 구현계획, Stage 1~5 |

upstream `v0.7.19` full sync 후보를 current RustBridge, 앱 세 target과 custom scheme WKWebView에서 검증했다. native ABI와 renderer helper smoke는 통과했지만 bundled studio가 legacy `rhwp-request` Host RPC를 차단해 저장, 공유, 인쇄, PDF 내보내기와 자동화가 동작하지 않는 release blocker를 확인했다.

회귀를 upstream commit `023041f55febf0e987c947c74cc5f5d67affdf69`의 MessageChannel origin 검증으로 축소해 upstream #2396에 등록했다. downstream 임시 patch를 제품에 포함하지 않고 core와 bundled studio를 `v0.7.18`로 복원했다. 재생성한 native artifact, 15개 C ABI, 앱 세 target, representative visual, Quick Look/Thumbnail과 실제 Host RPC가 모두 통과해 `v0.1.8 (14)` public release 입력을 `v0.7.18`로 확정했다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행계획 | `bad1564` | 별도 worktree, Task 문서와 오늘할일 생성 |
| 구현계획 | `cec8197` | 5단계 sync, ABI, runtime, visual, release handoff 계약 확정 |
| Stage 1 | `47099a5` | `v0.7.19` 영향, PR #421 freshness, 15개 ABI와 통합 계약 확정 |
| Stage 2 | `c19bd73` | exact automation candidate 통합, `v0.7.19` core/studio와 artifact 정렬 |
| Stage 3 | `2abacab` | Rust/Xcode/Quick Look/Thumbnail runtime 검증 통과 |
| Stage 4 | `5796277` | Host RPC blocker 판정, upstream #2396 등록, `v0.7.18` 복원·재검증 |
| Stage 5 | 이번 커밋 | 최종 보고, 포함 PR 분석, `v0.1.8 (14)` release handoff 정리 |

Stage 1~3 commit은 최종 product state가 아니라 `v0.7.19` 후보를 실제 통합한 뒤 회귀를 발견한 조사 증거다. Stage 4가 제품 dependency와 bundled studio를 `v0.7.18`로 되돌리므로 개별 Stage 2 commit만 release candidate로 사용하면 안 된다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/plans/task_m020_422.md` | `v0.7.19` 검토에서 `v0.7.18` release candidate 확정으로 변경된 수행 범위 기록 |
| `mydocs/plans/task_m020_422_impl.md` | 5단계 구현·검증, blocker 판정과 rollback 계약 기록 |
| `mydocs/working/task_m020_422_stage1.md` | upstream 변화, automation freshness와 통합 기준 조사 |
| `mydocs/working/task_m020_422_stage2.md` | `v0.7.19` core/studio 통합 및 provenance 재생성 결과 |
| `mydocs/working/task_m020_422_stage3.md` | Rust ABI, 앱 세 target과 extension runtime 결과 |
| `mydocs/working/task_m020_422_stage4.md` | Host RPC 원인, upstream 이슈, `v0.7.18` 복원과 실제 UI 검증 결과 |
| `mydocs/report/task_m020_422_report.md` | 최종 판정, release handoff와 후속 정리 조건 |
| `mydocs/orders/20260718.md`, `mydocs/orders/20260719.md` | Task 시작·진행·완료 상태 기록 |
| `mydocs/tech/core_release_compatibility.md` | current stable pin 검증일을 2026-07-19로 갱신 |
| `rhwp-core.lock` | 동일 `v0.7.18` artifact 재생성 시각 갱신, artifact hash와 size는 `devel`과 동일 |

Stage 2와 Stage 4 사이에서는 `RustBridge/Cargo.toml`, `Cargo.lock`, `RhwpCoreBuildInfo.swift`, core 운영·architecture 문서와 bundled studio hashed asset이 변경됐다. 그러나 Task branch 최종 상태를 `origin/devel`과 비교하면 해당 제품 파일은 모두 기존 `v0.7.18` 상태와 일치한다. 최종 제품 동작 변경은 없고 release 판단 근거와 재검증 provenance가 추가된다.

## 변경 전·후 정량 비교

### Release candidate

| 항목 | Task 시작 | 검토 후보 | 최종 |
|------|-----------|-----------|------|
| core/studio tag | `v0.7.18` | `v0.7.19` | `v0.7.18` |
| resolved commit | `93862a4e...` | `f137b4c...` | `93862a4e...` |
| legacy Host RPC | 정상 | custom scheme에서 timeout | 정상 |
| FFI symbol | 15개 | 15개 | 15개 |
| production renderer | CoreGraphics | CoreGraphics | CoreGraphics |
| external image 제품 지원 | 미완료 | 미완료 | 미완료 |

최종 local artifact provenance:

| 필드 | 값 |
|------|----|
| `librhwp.a` SHA-256 | `b7029e88c44774d44e4e30c624113eced4b305918a114834acb5725584c8b0a7` |
| `librhwp.a` size | `208707280` bytes |
| generated header SHA-256 | `c4cba0728b7e443ba78541dc1184d6aa286b91b72006e423e9283d998c31d8e5` |
| generated header size | `3310` bytes |
| studio source `Cargo.lock` SHA-256 | `5cf25bdd98a070906ff6c78126f8384bb3122db974143dcd8e39cd3099359045` |
| studio copied asset | 60개 / 39,392,653 bytes |
| main JS | `assets/index-D5QjYkw5.js` |
| main CSS | `assets/index-BKc-ZB2H.css` |
| WASM | `assets/rhwp_bg-CfVwz6LI.wasm` |

artifact hash와 size는 PR #420으로 반영된 current `devel`의 `v0.7.18` 기준과 동일하다. `rhwp-core.lock`의 `built_at`만 current RustBridge 재생성 시각으로 갱신됐다.

## v0.7.19 회귀와 책임 경계

### 재현

original `v0.7.19` bundled studio를 `alhangeul-studio://app/index.html` 최상위 문서로 로드하면 문서 자체는 표시되지만 legacy request/response가 응답하지 않았다.

| 검증 | original v0.7.19 | 진단 예외 적용 | v0.7.18 최종 |
|------|------------------|----------------|--------------|
| quick visual readiness | 10/10 timeout | 10/10 성공 | 10/10 성공 |
| 문서 표시 | 성공 | 성공 | 성공 |
| `ready`, `pageCount` | timeout | 성공 | 성공 |
| `getPageSvg` | timeout | 성공 | 성공 |
| `exportHwp` / PDF 내보내기 | 완료되지 않음 | 성공 | 성공 |

### 원인

PR #2187의 feature commit `023041f5...`는 legacy handler 전에 모든 message의 source와 HTTP(S) origin을 검사한다. custom scheme 최상위 same-window message는 `event.source`가 올바르더라도 origin이 `alhangeul-studio:`이므로 폐기된다. 이 commit은 `v0.7.18`에는 없고 `v0.7.19`에 처음 포함된다.

same-window 최상위 호출에만 origin 예외를 적용한 진단 asset에서 iframe source/origin 검사는 유지되고 모든 RPC와 visual suite가 통과했다. 따라서 native core, RustBridge 또는 renderer 회귀가 아니라 upstream bundled studio의 legacy compatibility 회귀로 판정했다.

downstream에서 수정 자체는 가능하지만 vendor patch를 유지하면 native core와 bundled studio의 stable tag 동일 provenance 계약을 깨고 보안 검증 책임을 복제한다. 알한글이 MessageChannel v1로 전환하는 별도 작업도 이번 patch release 범위를 벗어난다. 수정 책임과 회귀 테스트는 upstream에 두고, 수정된 새 stable tag를 다음 core sync에서 반영하는 것이 적절하다.

## Automation candidate 처리

PR #421은 current `devel` `9ca9c488...`에서 생성된 exact `v0.7.19` full sync 후보다.

| 항목 | 값 |
|------|----|
| PR | [#421](https://github.com/postmelee/alhangeul-macos/pull/421) |
| state | OPEN |
| head | `ddcc0329ae1b6bef7c6dacb51ee8375de3b6d42c` |
| mergeability | MERGEABLE |
| CI | Classify, Script, Release helper, macOS validation 모두 SUCCESS |
| 최종 판단 | merge 금지, Task #422 반영 후 superseded close |

CI 성공은 compile, lock, asset integrity를 증명하지만 실제 custom scheme legacy Host RPC를 호출하지 않아 #2396 회귀를 잡지 못했다. 따라서 PR #421 자체를 merge할 필요가 없으며 merge하면 이번 release candidate가 다시 `v0.7.19`로 바뀐다.

Task #422 PR merge 확인 후 다음 순서로 정리한다.

1. PR #421에 Task #422 merge PR, 최종 반영 commit과 upstream #2396을 연결한 superseded 코멘트를 남긴다.
2. PR #421을 close한다.
3. 원격 `automation/rhwp-v0.7.19-full-sync` branch를 삭제한다.
4. Issue #422와 local/publish branch, 분리 worktree를 `pr-merge-cleanup` 절차로 정리한다.

## 검증 결과

### Core, ABI와 앱 target

| 검증 | 결과 |
|------|------|
| stable tag/commit check | `v0.7.18` / `93862a4e...` 일치 |
| Rust fmt/check | 통과 |
| Rust locked test | 4개 통과, 실패 0 |
| universal artifact/lock | arm64+x86_64, header, archive hash 통과 |
| C ABI | 15개 symbol, 추가·삭제 없음 |
| no-AppKit boundary | 통과 |
| core build info | lock과 일치 |
| bundled studio asset | tag/commit/entrypoint hash 통과 |
| HostApp Debug | BUILD SUCCEEDED |
| QLExtension Debug | BUILD SUCCEEDED |
| ThumbnailExtension Debug | BUILD SUCCEEDED |

### Renderer와 extension runtime

| 검증 | 결과 |
|------|------|
| representative visual | CoreGraphics/Skia 총 10/10 성공, size drift 0 |
| `KTX.hwp` sentinel | Skia-CG `+15.4293pp`, 기존 known risk 수준 |
| 복학원서 | known layout 차이, 신규 내용 소실 없음 |
| HWPX | 표·이미지·텍스트와 9-page 내용 보존 |
| Quick Look policy | HWP 2개 PNG, HWPX 9-page PDF, fallback 0 |
| Thumbnail policy/cache | 총 24 render 성공, exact/larger bucket hit 유지 |
| custom scheme direct RPC | `pageCount`, `getPageSvg`, `exportHwp` 성공 |
| 실제 HostApp PDF 내보내기 | `KTX.hwp` 1-page 479 KiB PDF, non-blank 확인 |
| development registration | Task Debug app/provider/Updater 잔여 0 |

검증 중 font 선택 modal을 오래 유지한 뒤 한 차례 load timeout overlay가 나타났지만 Retry 후 정상 로드됐고 직접 RPC harness와 PDF 내보내기가 모두 통과했다. original `v0.7.19`의 모든 요청에서 반복되는 timeout과는 구분한다.

## v0.1.7 이후 포함 PR 분석

`v0.1.7` peeled commit은 `876d2667c2bff60e8599af8bccb45c4cab19099f`다. 2026-07-19 최신 `origin/devel` `9ca9c488...`까지 first-parent merge PR은 13개다. Task #422 PR은 merge되면 14번째 항목이 된다.

| PR | Task | 분류 | public release 판단 |
|----|------|------|---------------------|
| #384 | #383 문의/제보 페이지 | Pages 사용자-facing | 웹사이트 문의 경로 변화, 앱 기능과 분리 가능 |
| #395 | #388 core metadata/signature | release integrity | Thumbnail cache provenance 보강 |
| #397 | #390 Skia readiness 재측정 | verification-only | 제품 source 변화 없음 |
| #399 | #398 visual harness automation | verification-only | 제품 renderer 변화 없음 |
| #400 | #396 baseline suite | verification-only | release visual gate 보강 |
| #401 | #389 Thumbnail Skia diagnostic | developer/internal | production default는 CoreGraphics |
| #402 | #392 Thumbnail maxDimension | developer/internal | DEBUG/internal opt-in |
| #403 | #393 Quick Look direct PNG | developer/internal | DEBUG/internal opt-in |
| #405 | #404 upstream render diff | verification-only | 제품 source 변화 없음 |
| #414 | #391 external image ABI 설계 | documentation/design | 사용자 기능 아님 |
| #416 | #408 external image C ABI | developer-facing bridge | #409 전 제품 지원 아님 |
| #417 | #406 HOP UTI 호환 | user-facing app fix | Finder 후보 호환 개선, signed gate 필요 |
| #420 | #418 rhwp v0.7.18 full sync | upstream sync/user-facing | core/studio 개선과 provenance 갱신 |
| Task #422 PR 예정 | #422 v0.7.19 회귀 판정 | release safety | `v0.7.19` 미반영 근거, 사용자 기능 추가 없음 |

자동 PR 분석과 delta checklist를 `v0.1.7..5796277` 범위로 재생성해 위 목록, HostApp/Quick Look/Thumbnail, core/studio provenance와 문서 변경을 확인했다. release Task에서는 Task #422 merge 후 최종 `devel` candidate로 다시 생성해 이후 merge를 포함해야 한다.

## Public release handoff

### 후보 identity

| 입력 | 후보값 | 상태 |
|------|--------|------|
| app version | `0.1.8` | 다음 patch release 후보 |
| build | `14` | `v0.1.7 (13)` 다음 후보 |
| Git tag | `v0.1.8` | release Task에서 최종 `main` candidate에 생성 |
| previous release ref | `v0.1.7` | 확정 입력 |
| previous release commit | `876d2667c2bff60e8599af8bccb45c4cab19099f` | 확정 입력 |
| expected rhwp tag | `v0.7.18` | 확정 입력 |
| expected rhwp commit | `93862a4e16df59834ebce46d91e948cd739208e9` | 확정 provenance |
| release title 후보 | `Alhangeul v0.1.8 (rhwp v0.7.18)` | upstream-centered patch release 후보 |
| 제외 tag | `rhwp v0.7.19` | upstream #2396 해결 tag 전까지 금지 |

현재 HostApp/QLExtension/ThumbnailExtension metadata는 `0.1.7 (13)`이다. release publish/rehearsal workflow 기본값도 `version=0.1.7`, `previous_release_ref=v0.1.6`, `expected_rhwp_tag=v0.7.17`이다. 별도 release Task에서 다음을 함께 갱신한다.

1. 앱과 두 extension의 version/build를 `0.1.8 (14)`로 정렬한다.
2. release publish/rehearsal default를 `0.1.8`, `v0.1.7`, `v0.7.18`로 정렬한다.
3. `mydocs/release/v0.1.8.md`, Pages update page/index와 README 최신 공개 release 요약을 작성한다.
4. Task #422 merge 후 final `devel`에서 포함 PR 분석과 delta checklist를 재생성·보정한다.
5. `devel -> main` release PR과 candidate commit을 확정한 뒤 별도 승인으로 tag, draft publish, official publish gate를 진행한다.

### 사용자 release note 후보

```text
알한글 v0.1.8은 upstream rhwp v0.7.18 core와 bundled 편집기를 반영해
복잡한 표·도형·페이지 배치의 문서 호환성, 큰 표 처리 성능,
편집기의 입력·실행취소·후반 페이지 조작을 보강합니다.

HOP이 등록한 HWP/HWPX 문서 형식도 알한글의 호환 형식으로 인식해
Finder의 다음으로 열기와 기본 앱 후보에서 알한글을 선택할 수 있는 경로를 보강했습니다.
```

`v0.7.19`는 실제 제품에 포함되지 않으므로 해당 release의 HML, MessageChannel, 저장 지오메트리, 표 페이지네이션, 글꼴·CanvasKit 변경을 `v0.1.8` 제공 기능으로 표현하면 안 된다. 사용자에게 회귀 미반영 사실을 별도 release note 항목으로 노출할 필요는 없지만 내부 release record에는 #2396을 blocker로 기록한다.

다음 표현도 제외한다.

- `external linked image 지원 완료`: #409 미완료
- `Skia가 기본 renderer로 전환됨`: production default는 CoreGraphics
- `모든 손상/암호화/DRM 문서를 열 수 있음`: upstream 개선을 지원 보장으로 확대하면 안 됨
- `HOP 문서의 기본 앱이 자동 변경됨`: 후보 호환 지원이며 사용자 선택을 강제하지 않음

## Release blocking manual gate

### Signed HOP exact UTI

Task #406의 unsigned/debug A/B는 선언 수정 성립을 확인했지만 public candidate에서 다음을 확인해야 한다.

1. HOP v0.3.1이 설치된 격리된 registration 환경에 signed/notarized `Alhangeul v0.1.8 (14)`를 설치한다.
2. HWP/HWPX exact `net.golbin.hop.hwp`, `net.golbin.hop.hwpx` handler에 알한글이 등록되는지 확인한다.
3. Finder `다음으로 열기`와 `정보 가져오기 > 다음으로 열기` 후보 표시를 확인한다.
4. 알한글 선택 후 실제 open handoff, Quick Look Preview와 Thumbnail provider를 확인한다.
5. `mdls`, `NSWorkspace.urlsForApplications(toOpen:)`, `pluginkit -mAvvv`, `lsregister` 결과와 active path를 기록한다.
6. `mdls`가 한컴 Viewer UTI cache를 우선하면 exact handler test와 Finder GUI 결과를 분리 기록한다.

HWP/HWPX 중 하나라도 후보, open 또는 provider routing에 실패하면 public publish를 중단한다.

### Bundled studio Host RPC

단순 문서 open은 #2396을 검출하지 못하므로 signed candidate에서 custom scheme 문서를 열고 다음을 확인한다.

1. readiness와 page count가 timeout 없이 응답한다.
2. 첫 페이지 SVG 또는 화면 렌더가 non-blank다.
3. PDF 내보내기 save panel과 payload 생성이 완료된다.
4. 가능한 범위에서 저장, 공유, 인쇄 command가 Host RPC timeout 없이 시작된다.

### 일반 release gate

- core lock/build info/studio manifest의 `v0.7.18` provenance 확인
- signed/notarized universal app과 extension의 arm64+x86_64 slice, Gatekeeper 확인
- 일반 HWP/HWPX HostApp open, Quick Look, Thumbnail와 embedded image smoke
- `KTX.hwp` visual sentinel, CoreGraphics production default 확인
- 공개 `v0.1.7 (13)`에서 Sparkle update 후 `v0.1.8 (14)` app/extension refresh smoke
- draft DMG layout, legal resources, signature, notarization, checksum 확인
- 작업지시자 별도 승인 후에만 official GitHub Release, Pages/Sparkle와 Homebrew 단계를 실행

## 본문 변경 정도 / 무손실 여부

- 최종 `RustBridge/Cargo.toml`, `Cargo.lock`, bundled studio asset과 `RhwpCoreBuildInfo.swift`는 current `origin/devel`의 `v0.7.18`과 동일하다.
- generated header와 15개 expected symbol은 무손실이다.
- #406 HOP UTI 선언과 #408 external image C ABI는 current source에 그대로 보존됐다.
- local WKWebView override, bundled font 설명과 production CoreGraphics default는 유지됐다.
- 진단용 `v0.7.19` same-window patch와 temporary Host RPC harness는 repository에 포함하지 않았다.
- build, visual, PDF와 release analysis output은 ignored 또는 `/private/tmp` 경로에만 생성했다.
- public version/build, release tag, workflow 실행, signing/notarization, appcast와 Homebrew는 변경하거나 실행하지 않았다.

## 잔여 위험과 후속

| 항목 | 상태 | 후속 |
|------|------|------|
| upstream #2396 | OPEN | 수정된 새 stable tag 확인 후 다음 core sync |
| PR #421 | OPEN, CI 성공 | Task #422 merge 후 superseded close와 branch 삭제 |
| HOP exact UTI signed install | 미실행 | `v0.1.8` public release blocking gate |
| signed Host RPC | 미실행 | draft DMG에서 PDF export 포함 smoke |
| external linked image | #408 C ABI만 완료 | open #409 이후 제품 지원 판단 |
| Skia KTX visual delta | known risk | CoreGraphics default 유지 |
| extended visual suite | 미실행 | Skia default 판단 전 별도 sweep |
| Intel 실기기 | 미실행 | universal slice 확인, 가능한 환경에서 smoke |

## 최종 결론

`rhwp v0.7.19`는 native compile과 renderer helper가 통과하더라도 bundled studio Host RPC가 custom scheme에서 차단되므로 알한글 public release에 포함할 수 없다. 문제는 upstream commit `023041f5...`에서 도입됐고 downstream 제품 기능이 아닌 upstream legacy compatibility 회귀다.

최종 Task branch는 native core와 bundled studio를 검증된 `v0.7.18` / `93862a4e...`로 유지한다. Rust/ABI, 앱 build, Quick Look/Thumbnail, representative visual과 실제 PDF export에 신규 blocker는 없다. 따라서 Task #422 merge 후 별도 `v0.1.8 (14)` release Task를 시작할 수 있으며 expected rhwp는 반드시 `v0.7.18`로 설정한다.

## 작업지시자 승인 요청

최종 보고서와 `v0.7.18` release handoff를 승인해 주시면 `task-final-report` 절차로 `publish/task422` branch를 push하고 `devel` 대상 PR을 게시한다. PR merge 후에는 PR #421과 automation branch, Issue #422와 local worktree를 순서대로 정리한다.
