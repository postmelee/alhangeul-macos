# Task M020 #439 Stage 4 완료보고서

## 단계 목적

Stage 2~3에서 구현한 build-info writer/verifier와 sync·PR CI·release gate의 운영 계약을 core dependency, CI, release 매뉴얼에 같은 기준으로 반영한다. 전체 helper/workflow 회귀를 다시 실행하고, Task #439 merge 뒤 이어질 Issue #375와 v0.8.4 sync PR #463 재생성의 handoff 조건을 확정한다.

## 산출물

- `mydocs/manual/core_dependency_operation_guide.md` — 146줄
  - current core pin을 실제 `v0.8.2`/resolved commit으로 바로잡았다.
  - complete lock 이후 writer/verifier 순서와 Stable/Demo mapping을 기록했다.
  - sync writer와 PR/release verifier 책임, 업데이트 후 확인·금지 항목을 갱신했다.
- `mydocs/manual/ci_workflow_guide.md` — 366줄
  - PR CI fixture/verifier와 path classification을 기록했다.
  - sync mutation, generated summary/body/stage, release blocking gate와 로컬 재현 명령을 기록했다.
- `mydocs/manual/release_distribution_guide.md` — 199줄
  - build-info 자동화 helper를 release 자산에 추가했다.
  - 자동 gate와 maintainer 확인 책임, public release 전 checklist를 갱신했다.
- `mydocs/working/task_m020_439_stage4.md`
  - Stage 4 문서 변경, 회귀 검증과 후속 handoff를 기록했다.
- `mydocs/orders/20260813.md`
  - #439 비고를 `Stage 4 완료 및 최종 보고/PR 승인 대기`로 갱신했다.

`mydocs/manual/build_run_guide.md`는 수정하지 않았다. Core identity 생성 순서는 core dependency 가이드, workflow gate와 로컬 재현은 CI 가이드, public release 승인/checklist는 release 가이드가 각각 진실 원천이므로 build 문서에 같은 내용을 중복하지 않았다.

## 문서 반영 결과

### Core dependency 계약

표준 update 순서를 Stable/Demo 모두 다음과 같이 기록했다.

1. `scripts/update-rhwp-core.sh`
2. `scripts/build-rust-macos.sh --update-lock`
3. `scripts/update-rhwp-core-build-info.sh`
4. `scripts/verify-rhwp-core-build-info.sh`
5. `scripts/build-rust-macos.sh --verify-lock`
6. shared boundary, Xcode build와 renderer smoke

writer는 enabled features와 artifact metadata가 채워진 complete lock 뒤에만 실행한다. Incomplete/malformed lock을 이전 값이나 빈 값으로 보정하지 않는다.

Stable은 `rhwp_release_tag`, 실제 commit/features를 Swift mirror로 사용한다. Demo/Preview는 `rhwp_latest_checked_release_tag`를 Stable baseline label로 사용하되 실제 commit/features를 기록한다. Demo의 `releaseTag`가 해당 commit의 tagged release를 의미하지 않으며 thumbnail cache identity는 실제 commit을 포함한다는 점도 명시했다.

### CI·sync 책임

- upstream sync candidate만 writer를 실행한다.
- complete lock 직후 writer/verifier를 실행하고 `RhwpCoreBuildInfo.swift`를 explicit stage한다.
- Actions summary와 generated PR body에 writer/verifier 결과를 기록한다.
- PR CI script-checks는 isolated fixture를 실행한다.
- 관련 source/helper 변경은 macOS와 Rust/core verify를 활성화하고, Swift build info는 render smoke도 활성화한다.
- PR CI macOS validation은 tracked source verifier를 실행하되 writer로 수정하지 않는다.

Generated PR checklist의 자동 gate와 maintainer 확인 책임도 분리했다. 자동 gate는 lock/build info 값 일치를 확인하고, maintainer는 target upstream release의 의도성, resolved commit과 bundled studio provenance, app-facing 영향과 smoke 범위를 확인한다.

### Release 책임

Release rehearsal/publish는 Rust/core lock verify 뒤 build-info verifier를 실행한다. Mismatch는 DMG build, signing/notarization과 public artifact 생성을 차단한다. Release workflow는 writer를 실행하지 않는다.

Public release checklist에는 다음 항목을 추가했다.

- `RhwpCoreBuildInfo.swift` release baseline/commit/features와 lock 일치
- `verify-rhwp-core-build-info.sh` 통과
- release workflow가 writer로 drift를 자동 보정하지 않았는지 확인

## Issue #375 handoff

2026년 8월 13일 GitHub 최신 상태 기준 Issue #375 `source_cargo_lock_sha256 upstream Cargo.lock 자동 비교 검증 추가`는 open이다. 현재 `scripts/verify-rhwp-studio-assets.sh`는 manifest의 `source_cargo_lock_sha256`가 lowercase 64자 sha256인지 확인하지만 실제 target upstream checkout root `Cargo.lock` hash와 비교하지 않는다.

#375의 유지 범위:

- verifier에 optional upstream checkout 입력 또는 별도 helper 추가
- fingerprint field가 있는 manifest에서 실제 upstream root `Cargo.lock` hash 비교
- field 형식 오류와 실제 fingerprint mismatch 오류 구분
- full/studio sync 경로의 verification result와 PR body/checklist 갱신
- 과거 manifest의 field 누락 호환 유지

Task #439와 예상 겹침이 있는 파일:

- `.github/workflows/rhwp-upstream-sync-pr.yml`
- `scripts/ci/write-rhwp-full-sync-pr-body.sh`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/manual/ci_workflow_guide.md`
- 구현 선택에 따라 `.github/workflows/pr-ci.yml`, release/운영 문서

Task #439가 변경하지 않아 #375의 주 구현 출발점으로 유지되는 파일:

- `scripts/verify-rhwp-studio-assets.sh`
- `scripts/sync-rhwp-studio.sh`
- `scripts/ci/write-rhwp-studio-sync-pr-body.sh`
- bundled `rhwp-studio/manifest.json`과 asset

따라서 #375는 Task #439 PR이 `devel`에 merge된 뒤 최신 `devel`에서 `task-start` 절차로 시작해야 한다. Task #439 branch 위에서 병렬 구현하거나 오래된 `devel` 기준 patch를 적용하지 않는다. #375는 core build-info writer/verifier 계약을 바꾸지 않고 upstream Cargo.lock fingerprint 비교 책임만 추가하는 것을 기본 경계로 한다.

## PR #463 handoff

2026년 8월 13일 조회 기준 PR #463 `Sync rhwp upstream v0.8.4`는 다음 상태다.

- state: OPEN
- base/head: `devel` ← `automation/rhwp-v0.8.4-full-sync`
- head commit: `11e86bc48ddb97dcd4ea522a1084845570e33a90`
- mergeable: MERGEABLE
- 기존 PR CI 4개 job: SUCCESS

그러나 이 성공 결과는 Task #439의 build-info gate와 #375의 fingerprint actual comparison이 반영되기 전 workflow에서 생성됐다. 현재 #463은 lock이 `v0.8.4`이지만 build info가 `v0.8.2`인 재현 후보이므로 merge하지 않는다.

권장 후속 순서:

1. Task #439 최종 보고서/PR을 게시하고 PR CI 통과 후 `devel`에 merge한다.
2. 최신 `devel`에서 Issue #375를 별도 task/PR로 완료하고 merge한다.
3. 별도 승인 후 기존 PR #463을 close하고 `automation/rhwp-v0.8.4-full-sync` 원격 branch를 정리한다. Open PR이나 branch-only 상태가 남으면 sync workflow가 같은 target 재생성을 blocker로 처리한다.
4. `rhwp Upstream Sync PR` workflow를 v0.8.4 대상으로 다시 실행한다.
5. 새 candidate에서 `RhwpCoreBuildInfo.swift` v0.8.4 갱신, build-info verification summary/body, `source_cargo_lock_sha256` actual comparison, bundled studio provenance를 확인한다.
6. 새 PR CI가 통과한 뒤에만 sync PR merge를 승인한다.
7. Public release rehearsal/publish는 sync merge 뒤 별도 release 승인 절차로 진행한다.

PR close, remote branch 삭제, workflow dispatch와 public release는 Task #439 범위에서 실행하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

기존 매뉴얼의 관련 section만 필요한 만큼 갱신했다. 새 독립 매뉴얼이나 task-specific 사례 문서를 추가하지 않았고 `build_run_guide.md`에는 중복 내용을 넣지 않았다.

제품 Swift/Rust source, helper/workflow, `rhwp-core.lock`, `RhwpCoreBuildInfo.swift`, bundled studio asset은 Stage 4에서 변경하지 않았다. Production writer 실행 결과 `already up to date`였으며 다음 명령으로 source/lock no-diff를 확인했다.

```bash
git diff --exit-code -- Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift rhwp-core.lock
```

## 검증 결과

구현계획서의 Stage 4 검증 명령을 fail-fast shell에서 그대로 실행했다.

```text
bash -n scripts/update-rhwp-core.sh \
  scripts/update-rhwp-core-build-info.sh \
  scripts/verify-rhwp-core-build-info.sh \
  scripts/ci/test-rhwp-core-build-info.sh \
  scripts/ci/classify-pr-changes.sh \
  scripts/ci/write-rhwp-full-sync-pr-body.sh
결과: 통과

scripts/ci/test-rhwp-core-build-info.sh
OK: RhwpCoreBuildInfo writer and verifier fixtures passed

./scripts/update-rhwp-core-build-info.sh
OK: RhwpCoreBuildInfo is already up to date: .../RhwpCoreBuildInfo.swift

./scripts/verify-rhwp-core-build-info.sh
OK: RhwpCoreBuildInfo matches rhwp-core.lock

ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'
결과: 모든 workflow YAML parse 통과

git diff --exit-code -- Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift rhwp-core.lock
결과: 통과, production source/lock diff 없음

git diff --check
결과: 통과
```

추가 전체 회귀:

```text
shellcheck -e SC2129 <Stage 2~3 관련 helper 6개>
결과: 통과

update/writer/verifier/reader/classifier/PR body helper --help
결과: 모두 usage 출력 후 정상 종료

수정된 workflow run block의 GitHub expression을 placeholder로 치환 후 bash -n
embedded workflow bash: OK

generated v0.8.2 → v0.8.4 sync PR body 생성 후 validate-github-body.sh
결과: 통과, scope/verification/maintainer checklist의 build-info 항목 확인

Stage 2 helper diff와 기존 Swift build-info diff classification assertion
결과: macOS/Rust/core 및 필요한 render/release flag 확인

manual 3개에서 writer/verifier/build-info 계약 검색
extended Stage 4 regression: OK
```

`SC2129`는 PR body helper의 기존 개별 append redirect style warning이라 제외했으며 기능 오류나 이번 변경에 따른 신규 warning은 아니다.

## 잔여 위험

- 실제 GitHub-hosted PR CI와 upstream sync workflow는 Task #439 PR 게시·merge 뒤 최종 확인해야 한다. Local YAML/embedded bash 검증은 token, runner image, upstream build와 PR 생성까지 보장하지 않는다.
- Stage 4에서는 고비용 Rust rebuild, HostApp Debug build와 renderer smoke를 재실행하지 않았다. Source/helper 회귀는 통과했으며 실제 macOS/Rust/render gate는 Task #439 PR CI에서 실행한다.
- #375의 actual Cargo.lock fingerprint comparison은 아직 구현되지 않았다. 현재 #463을 먼저 merge하면 이 자동 gate도 적용되지 않는다.
- #463 close와 remote automation branch 삭제는 외부 상태 변경이므로 별도 승인 후 수행해야 한다.
- Public release version, signing/notarization, GitHub Release, Pages/Sparkle, Homebrew 작업은 별도 release 승인 범위다.

## 다음 단계 영향

네 구현 Stage가 모두 완료됐다. 다음 단계는 `task-final-report` 절차에 따른 최종 보고서 작성, 오늘할일 완료 처리, 최종 커밋, `publish/task439` push와 `devel` 대상 PR 게시다.

Task #439 PR merge와 cleanup이 끝난 뒤에만 Issue #375를 시작한다. #375 merge 전에는 기존 PR #463을 close/삭제/재생성하지 않고, merge하지도 않는다.

## 승인 요청

Stage 4 결과를 승인하고 Task #439 최종 보고서와 PR 게시 단계로 진행해도 되는지 승인 요청한다.

승인 전에는 최종 보고서 작성, publish branch push, PR 생성, Issue #375 시작, PR #463 변경 또는 release 작업을 수행하지 않는다.
