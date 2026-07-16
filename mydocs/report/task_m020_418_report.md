# Task M020 #418 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#418 `rhwp v0.7.18 full sync 재생성과 current devel 통합 검증`](https://github.com/postmelee/alhangeul-macos/issues/418) |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 기준 브랜치 | `devel` |
| 작업 브랜치 | `local/task418` |
| upstream release | [edwardkim/rhwp v0.7.18](https://github.com/edwardkim/rhwp/releases/tag/v0.7.18) |
| upstream resolved commit | `93862a4e16df59834ebce46d91e948cd739208e9` |
| fresh automation candidate | [PR #419](https://github.com/postmelee/alhangeul-macos/pull/419), `bdea7f557d8de3ca5e11913cd691f06052076d0d` |
| 이전 stale candidate | [PR #415](https://github.com/postmelee/alhangeul-macos/pull/415), superseded closed |

stale `rhwp v0.7.18` automation PR #415를 그대로 병합하지 않고 최신 `devel`에서 full sync workflow를 다시 실행했다. fresh PR #419의 core/studio 결과를 Task #418 branch에 통합한 뒤 current #408 RustBridge source로 native artifact를 재생성하고, 15개 C ABI와 앱 세 target, representative HWP/HWPX 렌더를 검증했다.

최종 결과는 다음과 같다.

- native core와 bundled `rhwp-studio`를 모두 `v0.7.18` / `93862a4e...`에 고정했다.
- #408의 `HwpDocument` 기반 external image context C ABI 15개 symbol을 보존했다.
- HostApp, Quick Look Preview, Finder Thumbnail compile/link와 대표 runtime smoke가 통과했다.
- `KTX.hwp`의 Skia visual delta는 기존 알려진 sentinel 수준이며 신규 악화는 확인되지 않았다.
- #406 HOP UTI 호환 변경은 current source와 함께 빌드됐지만 signed 설치본 exact UTI smoke는 다음 public release의 blocking manual gate로 넘긴다.
- #409가 미완료이므로 external linked image 제품 지원을 release note에서 주장하지 않는다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행계획 | `82c6b60` | 별도 worktree와 Task #418 추적 문서 생성 |
| 구현계획 | `45ac0d6` | 5단계 재생성, 통합, 검증, release handoff 계약 확정 |
| Stage 1 | `de58452` | stale #415, upstream 영향, #408 API, fresh 재생성 조건 분석 |
| Stage 2 | `cf0eb6a` | #415 superseded close, stale branch 삭제, workflow 재실행, PR #419 생성 및 CI 성공 |
| Stage 3 | `e99b9e7` | fresh sync diff 통합, local artifact 재생성, core/studio provenance 고정 |
| Stage 4 | `328d0f7` | Rust/Xcode/renderer/visual 회귀 검증과 build info 보정 |
| Stage 5 | 이번 커밋 | 최종 보고서, 포함 PR 분석, public release handoff 정리 |

## 최종 변경 범위

### Core와 bundled studio

| 항목 | 이전 | 최종 |
|------|------|------|
| core release | `v0.7.17` | `v0.7.18` |
| resolved commit | `03351190ec35436e58cbfee0aa9278a8fdc04a59` | `93862a4e16df59834ebce46d91e948cd739208e9` |
| enabled feature | `native-skia` | `native-skia` |
| FFI symbol | 15개 | 15개, 추가/삭제 없음 |
| bundled studio | `v0.7.17` hashed JS/CSS/WASM | `v0.7.18` full sync asset |

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

Stage 4에서 `RhwpCoreBuildInfo.swift`가 `v0.7.17`을 유지한 것을 검증기가 발견해 `v0.7.18` provenance로 맞췄다. 이 변경은 Thumbnail render signature와 앱 표시 metadata가 lock보다 뒤처지는 것을 막으며 ABI나 renderer 정책을 바꾸지 않는다.

### 제품 동작 경계

- HostApp은 새 bundled editor/viewer asset을 사용한다.
- Quick Look/Thumbnail의 production default는 계속 CoreGraphics다.
- Skia Thumbnail maxDimension과 Quick Look direct PNG는 DEBUG/internal opt-in 진단 경로다.
- #408 C ABI는 포함되지만 Swift resolver는 #409가 구현하므로 external linked image를 자동 탐색하거나 주입하지 않는다.
- #406에서 추가한 `net.golbin.hop.hwp`, `net.golbin.hop.hwpx` handler 선언은 유지된다.

## Automation candidate 처리

### Stale 후보 #415

#415는 base `477447f...`, head `bd81382...`로 #408과 #406 merge 전에 생성됐다. current `devel`과 `rhwp-core.lock` conflict가 있었고 기존 녹색 CI도 current RustBridge ABI를 검증하지 않았으므로 다음 순서로 superseded 처리했다.

1. stale SHA, CI 보존, #418 재생성 사유를 공개 코멘트로 기록했다.
2. PR #415를 close했다.
3. stale `automation/rhwp-v0.7.18-full-sync` branch를 삭제했다.
4. current `devel`에서 `target_tag=v0.7.18`로 full sync workflow를 다시 실행했다.

### Fresh 후보 #419

| 항목 | 값 |
|------|----|
| workflow run | [29511003883](https://github.com/postmelee/alhangeul-macos/actions/runs/29511003883), SUCCESS |
| PR | [#419](https://github.com/postmelee/alhangeul-macos/pull/419), OPEN |
| base | `dda97c7000fe12e7ed925e4e8a8d2b71f44fc46f` |
| head | `bdea7f557d8de3ca5e11913cd691f06052076d0d` |
| mergeability | `MERGEABLE`, `CLEAN` |
| changed repository paths | 11개 |
| PR CI | Classify, Script, Release helper, macOS validation 모두 SUCCESS |

#419는 생성 증거와 CI를 제공하는 automation candidate이며 Task #418의 최종 PR이 아니다. sync diff는 Task #418 branch에 이미 포함됐고 local artifact metadata와 build info 보정이 추가됐으므로 #419를 별도로 merge하면 중복된다.

Task #418 PR merge가 확인된 뒤 다음 순서로 정리한다.

1. #419에 Task #418 merge PR과 최종 반영 commit을 연결한 superseded 코멘트를 남긴다.
2. #419를 close한다.
3. `automation/rhwp-v0.7.18-full-sync` 원격 branch를 삭제한다.
4. Task #418 issue/branch/worktree는 `pr-merge-cleanup` 절차로 정리한다.

## 검증 결과

### Artifact와 ABI

| 검증 | 결과 |
|------|------|
| Rust fmt/check | 통과 |
| Rust locked test | 4개 통과, 실패 0 |
| `build-rust-macos.sh --verify-lock` | universal archive, header, lock, 15개 symbol 통과 |
| no-AppKit boundary | 통과 |
| core build info | `v0.7.18` 보정 후 통과 |
| bundled studio asset | tag/commit/entrypoint hash 통과 |

15개 symbol에는 기존 open/page/render/image/free 함수와 #408의 `rhwp_set_file_name_utf8`, `rhwp_external_image_refs_json`, `rhwp_inject_external_image_by_key`가 모두 포함된다.

### 앱 target

| scheme | 결과 |
|--------|------|
| HostApp Debug, unsigned | `BUILD SUCCEEDED` |
| QLExtension Debug, unsigned | `BUILD SUCCEEDED` |
| ThumbnailExtension Debug, unsigned | `BUILD SUCCEEDED` |

### Native render와 extension policy

| 검증 | 결과 |
|------|------|
| 기본 native render | `KTX.hwp`, `request.hwp`, `exam_kor.hwp` 통과 |
| embedded image | `hwp-img-001.hwp` 통과, 상·하단 로고 직접 확인 |
| Quick Look policy | HWP 2개 PNG, HWPX 9-page PDF, fallback 0 |
| Thumbnail policy | 3개 문서, 총 24 render, 실패 0, cache hit/miss 계약 유지 |
| development registration hygiene | 개발 등록 없음, `/Applications/Alhangeul.app` provider만 유지 |

### Visual baseline

CoreGraphics/Skia quick suite의 두 policy run은 모두 5/5 성공했고 native size drift는 0px였다.

| sample | CG changed | Skia changed | Skia-CG | 판정 |
|--------|------------|--------------|---------|------|
| `request.hwp` | 17.6976% | 11.6340% | -6.0636pp | Skia 개선 방향 |
| `KTX.hwp` | 30.7744% | 46.2037% | +15.4293pp | 기존 `warn:skia-delta` sentinel |
| `복학원서.hwp` | 7.5013% | 7.0360% | -0.4653pp | known-risk, clean capture |
| `hwp-multi-001.hwp` | 14.0349% | 13.9063% | -0.1286pp | Skia 개선 방향 |
| `hwpx-01.hwpx` | 14.0861% | 13.8750% | -0.2111pp | Skia 개선 방향 |

`KTX.hwp` 값은 Task #396 기준 `+15.4874pp`와 같은 수준이다. v0.7.18 sync blocker는 아니지만 Skia default 전환 blocker는 계속 유지한다.

## Upstream v0.7.18 사용자 영향 분류

upstream 공식 release는 `v0.7.17` 이후 대규모 patch cycle로 다음 영역을 강조한다. 알한글 release communication에서는 실제 포함 surface에 맞춰 표현해야 한다.

| upstream 영역 | 알한글 반영 surface | release note 표현 경계 |
|---------------|--------------------|------------------------|
| 부동/전면 개체 페이지네이션, RowBreak 표 분할, saved bounds, 글꼴 폭, WMF/도형 | native core와 bundled studio | 복잡한 표·도형·페이지 배치의 호환성과 렌더 안정성 개선 |
| 초대형 표와 거대 셀 성능 | native core와 bundled studio | 큰 표 문서의 처리 성능 개선 |
| 후반 페이지 caret, undo routing, OLE, 표 셀 Enter/IME | bundled editor/viewer | 편집기 입력·실행취소·후반 페이지 조작 성능 개선 |
| 부분 손상 문서, 암호화/DRM 분류, HWPX 원본 보존 | parser/core와 studio | 일부 손상·보호 문서의 판별과 HWPX 보존 처리 개선 |
| internal complexity refactor | 내부 구현 | 사용자 release note의 독립 기능으로 나열하지 않음 |
| external image context API | #408 C ABI까지 연결 | #409 전에는 제품 지원으로 표현하지 않음 |

release note는 upstream 개별 PR 전체를 알한글 기능처럼 열거하지 않고, 위 범주와 Task #418 runtime 검증 범위 안에서 요약한다.

## v0.1.7 이후 포함 PR 분석

`v0.1.7` peeled commit은 `876d2667c2bff60e8599af8bccb45c4cab19099f`다. Task #418 시작 시점 `devel`에는 이후 12개 merge PR이 있다. Task #418 PR은 이 표에 추가될 다음 merge 대상이다.

| PR | Task | 분류 | public release 판단 |
|----|------|------|---------------------|
| #384 | #383 문의/제보 페이지 | Pages 사용자-facing | 웹사이트 문의 경로 변화. 앱 기능 release note와 분리 가능 |
| #395 | #388 core metadata/signature | release integrity | Thumbnail cache provenance 보강, 사용자 기능으로 과장하지 않음 |
| #397 | #390 Skia readiness 재측정 | verification-only | 제품 source 변화 없음 |
| #399 | #398 visual harness automation | verification-only | 제품 source 변화 없음 |
| #400 | #396 baseline suite | verification-only | 제품 renderer 변화 없음 |
| #401 | #389 Thumbnail Skia diagnostic | developer/internal | Release default는 CoreGraphics |
| #402 | #392 Thumbnail maxDimension | developer/internal | DEBUG/internal opt-in, underfill risk 유지 |
| #403 | #393 Quick Look direct PNG | developer/internal | DEBUG/internal opt-in, default 품질 gate 대체 안 함 |
| #405 | #404 upstream render diff | verification-only | 제품 source 변화 없음 |
| #414 | #391 external image ABI 설계 | documentation/design | 사용자 기능 아님 |
| #416 | #408 external image C ABI | developer-facing bridge | #409 전에는 external image 제품 지원 아님 |
| #417 | #406 HOP UTI 호환 | user-facing app fix | HOP 등록 문서의 Finder `다음으로 열기` 후보 호환 개선 |
| Task #418 PR 예정 | #418 v0.7.18 full sync | upstream sync/user-facing | core/studio 개선과 provenance 갱신 |

자동 delta checklist는 `v0.1.7..Task #418 HEAD` 범위를 HostApp, Quick Look, Thumbnail, core/studio provenance로 분류했다. release task에서는 최종 `devel` candidate commit으로 다시 생성해 Task #418 이후 merge가 포함됐는지 확인해야 한다.

## Public release handoff

### 후보 identity

| 입력 | 후보값 | 상태 |
|------|--------|------|
| app version | `0.1.8` | 다음 patch release 후보, 이 Task에서 확정하지 않음 |
| build | `14` | `v0.1.7 (13)` 다음 후보, 이 Task에서 확정하지 않음 |
| Git tag | `v0.1.8` | release task에서 최종 `main` candidate에 생성 |
| previous release ref | `v0.1.7` | 확정 입력 |
| previous release commit | `876d2667c2bff60e8599af8bccb45c4cab19099f` | 확정 입력 |
| expected rhwp tag | `v0.7.18` | Task #418 merge 후 candidate 기준 |
| expected rhwp commit | `93862a4e16df59834ebce46d91e948cd739208e9` | 확정 provenance |
| release title 후보 | `Alhangeul v0.1.8 (rhwp v0.7.18)` | upstream-centered patch release 후보 |

현재 repository metadata는 의도적으로 계속 `0.1.7 (13)`이다. `release-publish.yml`과 `release-rehearsal.yml` 기본값도 `version=0.1.7`, `previous_release_ref=v0.1.6`, `expected_rhwp_tag=v0.7.17`이다. 새 release 이슈에서 다음을 함께 갱신해야 한다.

1. HostApp/QLExtension/ThumbnailExtension의 version/build를 `0.1.8 (14)` 후보로 정렬한다.
2. release publish/rehearsal workflow default를 `0.1.8`, `v0.1.7`, `v0.7.18`로 정렬한다.
3. `mydocs/release/v0.1.8.md`, Pages update page/index, README 최신 release 요약을 작성한다.
4. final `devel` candidate에서 `v0.1.7..candidate` PR 분석과 delta checklist를 다시 생성한다.
5. `devel -> main` release PR과 최종 candidate commit을 확정한 뒤 별도 승인으로 tag/publish gate를 진행한다.

### 사용자 release note 후보

```text
알한글 v0.1.8은 upstream rhwp v0.7.18 core와 bundled 편집기를 반영해
복잡한 표·도형·페이지 배치의 문서 호환성, 큰 표 처리 성능,
편집기의 입력·실행취소·후반 페이지 조작을 보강합니다.

HOP이 등록한 HWP/HWPX 문서 형식도 알한글의 호환 형식으로 인식해
Finder의 다음으로 열기와 기본 앱 후보에서 알한글을 선택할 수 있는 경로를 보강했습니다.
```

다음 표현은 제외한다.

- `external linked image 지원 완료`: #409 미완료
- `Skia가 기본 renderer로 전환됨`: production default는 CoreGraphics
- `모든 손상/암호화/DRM 문서를 열 수 있음`: upstream 분류·관용 처리 개선을 지원 보장으로 확대하면 안 됨
- `HOP 문서의 기본 앱이 자동으로 알한글로 변경됨`: 후보 호환 지원이며 사용자의 기본 앱 선택을 강제하지 않음

## Release blocking manual gate

### Signed HOP UTI smoke

Task #406의 unsigned/debug A/B는 HostApp 후보 수정 성립을 확인했지만 public release candidate에서는 signed/sealed 설치본으로 다음을 모두 확인해야 한다.

1. HOP v0.3.1이 설치된 깨끗한 사용자 계정 또는 격리된 registration 환경을 준비한다.
2. signed/notarized `Alhangeul v0.1.8 (14)` candidate를 표준 위치에 설치한다.
3. HWP와 HWPX 각각에서 exact `net.golbin.hop.hwp`, `net.golbin.hop.hwpx` handler에 알한글이 등록되는지 확인한다.
4. Finder `다음으로 열기`와 `정보 가져오기 > 다음으로 열기` 후보에 알한글이 표시되는지 확인한다.
5. 알한글 선택 후 실제 document open handoff가 성공하는지 확인한다.
6. 같은 exact UTI에서 signed Quick Look Preview와 Thumbnail provider가 정상 출력되는지 확인한다.
7. `mdls`, `NSWorkspace.urlsForApplications(toOpen:)`, `pluginkit -mAvvv`, `lsregister` diagnostics에 실제 active path를 기록한다.
8. 기존 공개 앱이나 Debug artifact가 결과에 섞이지 않도록 registration hygiene를 먼저 확인하고 전역 reset은 사용하지 않는다.

실제 파일의 `mdls net.golbin.hop.*` 분류가 한컴 Viewer cache 때문에 재현되지 않으면 이를 숨기지 않고 exact UTI handler test와 Finder GUI 결과를 분리 기록한다. HWP와 HWPX 중 하나라도 candidate가 후보에 나타나지 않거나 open/provider routing이 실패하면 public publish 전에 원인을 해결한다.

### 일반 release gate

- `build-rust-macos.sh --verify-lock`, core build info, studio asset 검증
- signed/notarized universal app과 두 extension의 `arm64 + x86_64` slice, Gatekeeper 검증
- 일반 Hancom 계열 UTI의 HWP/HWPX HostApp open, Quick Look, Thumbnail smoke
- embedded image fixture와 representative native render smoke
- `KTX.hwp` visual sentinel 확인, CoreGraphics production default 유지
- 공개 `v0.1.7 (13)` 설치본에서 Sparkle update 후 `v0.1.8 (14)` app/extension refresh smoke
- draft DMG layout, legal resource, signature, notarization, appcast/Pages checksum 검증

## 본문 변경 정도 / 무손실 여부

- fresh automation candidate의 generated core/studio asset은 수동 편집하지 않았다.
- candidate 대비 의도적 제품 차이는 local artifact metadata와 `RhwpCoreBuildInfo` provenance 보정이다.
- #408 RustBridge source, cbindgen 설정, 15개 expected symbol은 무손실이다.
- #406 HOP UTI HostApp/extension declaration과 open panel 변경은 무손실이다.
- local WKWebView override와 bundled font 설명 파일은 유지됐다.
- generated framework/Xcode build/visual output과 release delta 초안은 ignored 경로에만 생성했고 commit하지 않는다.
- public release version/build, tag, workflow 실행, signing/notarization, appcast, Homebrew는 변경하거나 실행하지 않았다.

## 잔여 위험과 후속

| 항목 | 상태 | 후속 |
|------|------|------|
| HOP exact UTI signed install | 미실행 | 다음 public release blocking manual gate |
| external linked image | C ABI만 완료 | open #409 Swift wrapper/resolver 이후 제품 지원 판단 |
| Skia KTX visual delta | 기존 blocker 유지 | CoreGraphics default 유지, #387 계열 후속 |
| visual extended suite | 이번 Task에서 미실행 | Skia default 판단 전 별도 sweep |
| Intel 실기기 | 미실행 | release owner가 가능한 환경에서 추가 smoke, 최소 universal slice 검증 필수 |
| registration helper nested `Updater.app` | path 추출 한계 | 별도 운영 helper 개선 후보 |
| automation PR #419 | OPEN | Task #418 PR merge 확인 후 superseded close와 branch 삭제 |
| latest upstream release | 2026-07-17 기준 `v0.7.18` | release task 시작 시 `require_latest_rhwp`로 재확인 |

## 최종 결론

`rhwp v0.7.18` core/studio full sync는 current `devel`의 #408 ABI와 #406 HOP UTI 변경을 보존한 상태에서 통합됐다. artifact, ABI, compile/link, native render, Quick Look/Thumbnail policy, visual baseline에 Task #418을 막는 신규 회귀는 확인되지 않았다.

따라서 Task #418 결과는 별도 public release task의 입력으로 사용할 수 있다. release task는 `v0.1.8 (14)`를 후보 identity로 시작하되 version/build는 그 Task에서 확정하고, signed HOP exact UTI smoke를 public publish 전 blocking gate로 수행해야 한다.

Task #418 최종 보고서 승인을 받은 뒤 `task-final-report` 절차로 `publish/task418` PR을 게시한다.
