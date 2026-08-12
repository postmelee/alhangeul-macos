# Task M020 #439 Stage 3 완료보고서

## 단계 목적

upstream full sync가 완성된 `rhwp-core.lock`에서 `RhwpCoreBuildInfo.swift`를 자동 갱신·검증·stage하게 하고, 일반 PR과 release candidate source에서는 같은 정합성 drift를 자동 수정하지 않고 blocking failure로 처리한다. 관련 helper와 Swift build info 변경이 필요한 CI gate를 건너뛰지 않도록 path classification과 generated PR body도 함께 보강한다.

## 산출물

- `.github/workflows/rhwp-upstream-sync-pr.yml` — 678줄
  - helper syntax/interface/fixture 검증을 추가했다.
  - complete lock 직후 writer와 verifier를 실행한다.
  - build info를 명시 stage하고 결과를 Actions summary와 generated PR body에 전달한다.
- `.github/workflows/pr-ci.yml` — 321줄
  - script-checks에서 helper interface와 isolated fixture를 실행한다.
  - macOS validation에서 tracked build info verifier를 실행한다.
- `.github/workflows/release-rehearsal.yml` — 263줄
  - lock verify 직후 build info verifier를 실행하고 summary에 policy를 기록한다.
- `.github/workflows/release-publish.yml` — 641줄
  - lock verify 직후 build info verifier를 실행하고 summary에 policy를 기록한다.
- `scripts/ci/classify-pr-changes.sh` — 280줄
  - build info source/helper/reader/test 변경에 macOS와 Rust/core verify를 활성화한다.
- `scripts/ci/write-rhwp-full-sync-pr-body.sh` — 336줄
  - build info 자동 생성 범위와 maintainer 정합성 checklist를 추가했다.
- `scripts/update-rhwp-core.sh` — 521줄
  - complete lock 생성 후 writer→verifier→shared boundary 검증 순서를 안내한다.
- `mydocs/working/task_m020_439_stage3.md`
  - Stage 3 구현 및 검증 결과를 기록했다.
- `mydocs/orders/20260813.md`
  - #439 비고를 `Stage 3 완료 및 Stage 4 승인 대기`로 갱신했다.

## 구현 결과

### Upstream full sync 갱신 경로

`rhwp-upstream-sync-pr.yml`의 candidate 생성 순서를 다음과 같이 고정했다.

1. `scripts/update-rhwp-core.sh --channel stable --tag <tag>`
2. `scripts/build-rust-macos.sh --update-lock`
3. `scripts/update-rhwp-core-build-info.sh`
4. `scripts/verify-rhwp-core-build-info.sh`
5. `scripts/check-no-appkit.sh`
6. bundled `rhwp-studio` sync/verify
7. `git diff --check`
8. generated source 명시 stage

`Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`를 explicit `git add` 목록에 추가했다. 따라서 writer가 값을 바꾸면 candidate diff와 repository changed paths에 자동 포함되고, 값이 이미 같으면 불필요한 diff 없이 기존 no-change 판정을 유지한다.

workflow의 helper preflight에는 writer/verifier/test의 `bash -n`, writer/verifier `--help`, isolated fixture 실행을 추가했다.

### Verification summary와 generated PR body

sync workflow의 verification file에 다음 결과를 추가했다.

- `scripts/update-rhwp-core-build-info.sh`: OK
- `scripts/verify-rhwp-core-build-info.sh`: OK

같은 file을 generated PR body의 `Verification`에 전달하고 Actions step summary에도 별도 `rhwp full sync verification` 섹션으로 기록한다.

generated PR body에는 다음 운영 정보를 추가했다.

- completed lock에서 `RhwpCoreBuildInfo.swift`가 재생성된다는 full sync scope
- release tag, commit, enabled features가 lock과 일치하는지 확인하는 maintainer checklist

### PR CI blocking 경로

PR CI의 `script-checks` job은 모든 PR에서 다음을 확인한다.

- writer와 verifier interface
- stable/demo, stale, malformed, no-diff, production 무손실 isolated fixture

관련 변경은 path classification에 의해 `run_macos_build=true`, `run_rust_verify=true`가 된다. macOS validation은 Rust/core lock build 또는 verify 뒤 `./scripts/verify-rhwp-core-build-info.sh`를 실행한다. PR CI에서는 writer를 실행하지 않으므로 drift를 수정하지 않고 실패한다.

분류 대상:

- `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift`
- `scripts/update-rhwp-core-build-info.sh`
- `scripts/verify-rhwp-core-build-info.sh`
- `scripts/ci/read-rhwp-core-lock.sh`
- `scripts/ci/test-rhwp-core-build-info.sh`

과거 commit pair를 사용한 classification assertion 결과:

| 변경 유형 | macOS | Rust/core | Render smoke | Release checks |
|------|------|------|------|------|
| Stage 2 helper diff | true | true | false | true |
| Swift build info diff | true | true | true | false |

Swift source는 기존 renderer path 규칙도 계속 적용되므로 render smoke가 유지된다. `scripts/ci/*` helper는 기존 release automation 규칙도 계속 적용된다.

### Release blocking 경로

`release-rehearsal.yml`과 `release-publish.yml` 모두 기존 `build-rust-macos.sh --verify-lock` 직후 `verify-rhwp-core-build-info.sh`를 실행한다. lock과 Swift source가 다르면 DMG build, signing, notarization보다 먼저 실패한다.

두 workflow summary의 Rust bridge lock policy에도 build info 검증 명령과 검증 대상인 release baseline/commit/enabled features를 기록한다. Release workflow에서는 writer를 호출하지 않는다.

### Writer mutation 경계

옵션 없는 `scripts/update-rhwp-core-build-info.sh` 실행은 `rhwp-upstream-sync-pr.yml`의 candidate 생성 경로 한 곳에만 존재한다. PR CI에는 비변경성 `--help` 확인만 있고, release rehearsal/publish에는 writer 호출이 없다.

`scripts/update-rhwp-core.sh`의 완료 안내도 다음 순서로 갱신했다.

```text
Next: ./scripts/build-rust-macos.sh --update-lock
Then: ./scripts/update-rhwp-core-build-info.sh && ./scripts/verify-rhwp-core-build-info.sh
Then: ./scripts/check-no-appkit.sh
```

## 본문 변경 정도 / 본문 무손실 여부

CI/helper workflow 7개와 단계 문서만 변경했다. 제품 Swift/Rust source, `rhwp-core.lock`, `RhwpCoreBuildInfo.swift`, bundled assets, `project.yml`은 변경하지 않았다.

실제 GitHub Actions dispatch, PR #463 갱신·폐기·재생성, branch push, release rehearsal/publish는 실행하지 않았다. 이번 단계는 local/static 검증으로만 workflow contract를 확인했다.

Generated PR body 검증용 `/private/tmp/task439-generated-pr-body.md`와 verification fixture는 tracked file이 아니며 단계 종료 전에 삭제한다.

## 검증 결과

구현계획서의 Stage 3 검증 명령을 fail-fast shell에서 실행했다.

```text
bash -n scripts/ci/classify-pr-changes.sh \
  scripts/ci/write-rhwp-full-sync-pr-body.sh
결과: 통과

bash -n scripts/update-rhwp-core.sh
결과: 통과

scripts/ci/test-rhwp-core-build-info.sh
OK: RhwpCoreBuildInfo writer and verifier fixtures passed

./scripts/verify-rhwp-core-build-info.sh
OK: RhwpCoreBuildInfo matches rhwp-core.lock

ruby -e 'require "psych"; Dir[".github/workflows/*.yml"].sort.each { |path| Psych.parse_file(path) }'
결과: 모든 workflow YAML parse 통과

bash scripts/ci/classify-pr-changes.sh --help
bash scripts/ci/write-rhwp-full-sync-pr-body.sh --help
결과: usage 출력 후 정상 종료

scripts/validate-github-body.sh /private/tmp/task439-generated-pr-body.md
결과: 통과

rg -n "update-rhwp-core-build-info|verify-rhwp-core-build-info|RhwpCoreBuildInfo.swift" \
  .github/workflows scripts/ci
결과: sync writer/verifier/stage, PR CI verifier, release verifier, classification과 PR body 항목 확인

git diff --check
결과: 통과
```

추가 검증:

```text
수정된 네 workflow의 모든 run block에서 GitHub expression을 placeholder로 치환 후 bash -n
embedded workflow bash: OK

shellcheck -e SC2129 scripts/ci/classify-pr-changes.sh \
  scripts/ci/write-rhwp-full-sync-pr-body.sh scripts/update-rhwp-core.sh
결과: 통과

Stage 2 helper diff와 기존 Swift build info diff에 대한 classification flag assertion
classification assertions: OK

PR CI/release workflow에서 옵션 없는 writer 실행 검색
결과: 없음

upstream sync workflow에서 옵션 없는 writer 실행 검색
결과: candidate 생성 경로 1건
```

`SC2129`는 `write-rhwp-full-sync-pr-body.sh`의 기존 개별 append redirect 스타일에 대한 style warning이며 이번 단계가 변경한 동작과 무관해 제외했다.

## 잔여 위험

- 실제 Actions runner에서 full sync를 dispatch하지 않았으므로 token, upstream build artifact, branch push, PR create까지의 end-to-end 결과는 #439 merge 후 workflow 재실행에서 확인해야 한다.
- PR CI macOS job의 full Rust build/verify와 release workflow의 DMG build는 이번 단계에서 로컬 재실행하지 않았다. 기존 고비용 gate 본문은 유지하고 verifier 호출만 추가했다.
- Generated PR body validation은 representative v0.8.2→v0.8.4 fixture를 사용했다. 실제 changed paths와 impact details는 workflow 실행 시 기존 helper가 채운다.
- Demo/Preview baseline 의미와 maintainer 수동 실행 절차는 아직 운영 문서에 반영되지 않았다. Stage 4에서 문서화한다.
- #375와 PR #463 상태는 변경하지 않았다.

## 다음 단계 영향

Stage 4에서는 운영 문서와 전체 회귀 검증을 수행한다.

1. core dependency 운영 문서에 complete lock 이후 writer/verifier 순서와 stable/demo mapping을 기록한다.
2. CI workflow 문서에 sync mutation과 PR CI blocking 책임을 기록한다.
3. release 문서에 rehearsal/publish verifier gate를 기록한다.
4. 구현계획서의 Stage 4 전체 회귀 명령을 실행한다.
5. 최종 보고서와 PR 게시 준비 전 단계 결과를 정리한다.

## 승인 요청

Stage 3 결과에 따라 Stage 4로 진행해도 되는지 승인 요청한다.

Stage 4에서는 운영 문서와 전체 회귀 검증만 수행하고, 실제 workflow dispatch, PR #463 mutation, release 작업은 계속 범위 밖으로 유지한다.
