# Task #375 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#375 source_cargo_lock_sha256 upstream Cargo.lock 자동 비교 검증 추가](https://github.com/postmelee/alhangeul-macos/issues/375) |
| 마일스톤 | M040 `v0.4` |
| 기준 통합 브랜치 | `devel` |
| 작업 브랜치 | `local/task375` |
| 게시 브랜치 | `publish/task375` |
| 단계 | Stage 1~4 |
| Production studio identity | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |

Bundled `rhwp-studio` manifest의 resolved commit과 `source_cargo_lock_sha256`을 target upstream Git checkout HEAD와 root `Cargo.lock` 실제 SHA-256에 결합하는 strict 검증 경로를 추가했다. 일반 앱·PR·release의 checkout 없는 resource-only 검증은 기존 field 누락 호환을 유지하고, upstream sync candidate 생성 경로만 checkout identity, fingerprint 존재와 actual match를 blocking gate로 강제한다.

핵심 결과:

- `scripts/verify-rhwp-studio-assets.sh`에 optional `--upstream-dir` checkout commit binding과 실제 hash 비교를 추가했다.
- Resource-only legacy 호환과 strict candidate 필수 조건을 분리했다.
- Malformed SHA-256과 실제 provenance mismatch를 구분하고 mismatch에 manifest 값·actual 값·비교 경로를 출력한다.
- `scripts/sync-rhwp-studio.sh`가 manifest 기록 직후 같은 target checkout으로 self-check한다.
- Full sync workflow가 target checkout을 explicit verifier에 전달하고 PR 생성 전 strict gate로 사용한다.
- Ubuntu PR CI와 upstream sync preflight에서 isolated fixture를 실행한다.
- Generated full PR body와 Actions summary를 automatic 비교 결과 기준으로, 활성 workflow가 없는 studio helper는 전달된 verification 결과 기준으로 갱신했다.
- Production `v0.8.2` upstream tracked `Cargo.lock` blob과 checkout file을 독립 계산해 manifest fingerprint 일치를 확인했다.
- Core dependency, build, CI와 compatibility 운영 문서를 같은 책임 계약으로 정렬했다.

## 변경 파일과 영향 범위

| 영역 | 파일 | 영향 |
|------|------|------|
| Verifier | `scripts/verify-rhwp-studio-assets.sh` | `--upstream-dir`, checkout HEAD/expected commit과 field/file actual hash 비교, 구분된 오류 진단 |
| Manifest writer | `scripts/sync-rhwp-studio.sh` | 생성 결과 verifier에 같은 upstream directory 전달 |
| Fixture | `scripts/ci/test-rhwp-studio-cargo-lock-verification.sh` | Compatibility, strict commit/hash match, stale/non-Git/mismatch/누락/malformed/interface/sync/no-mutation 검증 |
| PR CI | `.github/workflows/pr-ci.yml` | Ubuntu script-checks에 신규 fixture gate 추가 |
| Upstream sync | `.github/workflows/rhwp-upstream-sync-pr.yml` | Preflight fixture, candidate strict verifier, verification summary 연결 |
| 분류 | `scripts/ci/classify-pr-changes.sh` | 신규 provenance fixture에 macOS/Rust/release gate 활성화 |
| Generated body | `scripts/ci/write-rhwp-full-sync-pr-body.sh`, `scripts/ci/write-rhwp-studio-sync-pr-body.sh` | 수동 hash 재계산 대신 full automatic/studio verification result checklist |
| 운영 문서 | `mydocs/manual/build_run_guide.md`, `mydocs/manual/core_dependency_operation_guide.md`, `mydocs/manual/ci_workflow_guide.md`, `mydocs/tech/core_release_compatibility.md` | Resource-only/strict 경계, 자동 gate, 실패 taxonomy와 재현 명령 |
| 작업 기록 | 수행·구현 계획서, Stage 1~4 보고서, 최종 보고서, 오늘할일 | 조사·구현·검증·후속 순서 기록 |

Task #375는 `Sources/HostApp/Resources/rhwp-studio/**`, `RustBridge/**`, `Frameworks/**`, `rhwp-core.lock`, `RhwpCoreBuildInfo.swift`를 변경하지 않았다. Upstream 저장소, PR #463, automation branch, workflow run과 public release 상태도 변경하지 않았다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 수행 계획 | `4b4abf9` | Issue scope, 변경 금지 경계, 4단계 계획과 오늘할일 등록 |
| 구현 계획 | `48b7545` | Compatibility/strict mode, mutation boundary와 failure taxonomy 확정 |
| Stage 1 | `e9b95f8` | Full sync checkout lifecycle, helper/workflow/body/classification 호출 경로 조사 |
| Stage 2 | `fd989f5` | Actual hash verifier, sync self-check와 isolated fixture 구현 |
| Stage 3 | `1b529c0` | PR CI/upstream sync gate, classification과 generated body 연결 |
| Stage 4 | `e5378ba` | 운영 문서 정렬, 실제 upstream과 전체 통합 검증 완료 |
| PR 리뷰 반영 | 후속 커밋 | Strict checkout commit binding, stale fixture, studio body 문구와 self-check 설명 보정 |

## 핵심 동작 계약

### Verifier mode

| 입력 | Manifest fingerprint | 결과 |
|------|----------------------|------|
| `--upstream-dir` 없음 | 없음 | Legacy resource-only 호환 성공 |
| `--upstream-dir` 없음 | 있음 | Lowercase 64자 SHA-256 형식과 asset integrity 검증 |
| `--upstream-dir DIR` | 없음 | Strict candidate field 누락 실패 |
| `--upstream-dir DIR` | malformed | Manifest 형식 오류 실패 |
| `--upstream-dir DIR` | valid, hash match but HEAD mismatch | Stale/wrong checkout provenance 실패 |
| `--upstream-dir DIR` | valid, match | `DIR/Cargo.lock` actual SHA-256 일치 성공 |
| `--upstream-dir DIR` | valid, mismatch | Provenance mismatch와 manifest/actual/path 진단 실패 |

Strict verifier는 Git checkout HEAD가 expected resolved commit과 같은지 확인한 뒤 Cargo.lock hash를 비교하고 파일을 수정하지 않는다. Manifest writer는 `sync-rhwp-studio.sh` 하나로 유지하며 생성 직후 strict verifier를 실행한다. 이 self-check는 writer의 quoting/copy drift를 잡고 commit/hash 결합을 독립적으로 재확인한다.

### Workflow 책임

| 경로 | Target checkout | 검증 | 실패 영향 |
|------|-----------------|------|-----------|
| PR CI script-checks | 없음 | Isolated fixture | Verifier contract 회귀를 조기 차단 |
| 일반 app/release verifier | 없음 | Resource-only | Existing asset integrity와 optional field format 확인 |
| Upstream sync preflight | 없음 | Isolated fixture | Target build 전 helper contract 회귀 차단 |
| Upstream sync candidate | 있음 | Writer self-check + explicit strict verifier | Stage·commit·push·PR 생성 전 중단 |

## 요구사항 완료 감사

| Issue 요구사항 | 판정 | 권위 있는 증거 |
|------|------|------|
| Fingerprint와 target root `Cargo.lock` 자동 비교 | 완료 | Checkout HEAD/expected commit 결합, verifier actual `shasum` 비교, match/stale/mismatch fixture, actual `v0.8.2` strict 검증 |
| Existing missing-field asset 호환 | 완료 | Resource-only legacy fixture 성공, production default verifier 성공 |
| Full/studio sync target checkout 비교 | 완료 | Sync writer self-check와 full sync restored checkout explicit verifier가 commit/hash identity를 함께 확인 |
| Workflow verification 결과 포함 | 완료 | `Cargo.lock fingerprint match OK` verification file/Actions summary와 generated body |
| Mismatch와 malformed field 오류 구분 | 완료 | 별도 오류 메시지와 isolated failure fixture |
| 운영 문서와 PR checklist 갱신 | 완료 | 운영 문서 4종, full automatic gate와 studio verification-result body 문구 |
| Upstream/core/asset/reproducibility 제외 범위 유지 | 완료 | 해당 source/lock/asset diff와 외부 상태 변경 없음 |

## 실제 upstream 검증

Production manifest와 upstream `v0.8.2`를 다음 세 경로로 대조했다.

```text
Manifest source_cargo_lock_sha256:
64ff4041c1874c01c7a901b28df2639082836ced44df392cd37b3227d4772279

shasum -a 256 <v0.8.2-checkout>/Cargo.lock:
64ff4041c1874c01c7a901b28df2639082836ced44df392cd37b3227d4772279

git show 9b16aa9e...:Cargo.lock | shasum -a 256:
64ff4041c1874c01c7a901b28df2639082836ced44df392cd37b3227d4772279

Strict verifier:
OK: upstream checkout HEAD matches 9b16aa9e23f476e2b335d7c029fc9f24a199d63c
OK: manifest source_cargo_lock_sha256 matches <v0.8.2-checkout>/Cargo.lock
OK: rhwp-studio assets verified
```

Actual checkout은 ignored `build.noindex/`에만 두었고 tracked production resource는 수정하지 않았다.

## 통합 검증 결과

| 검증 | 결과 |
|------|------|
| 전체 `scripts/*.sh`, `scripts/ci/*.sh` `bash -n` | OK |
| Task 관련 6개 helper `shellcheck -e SC2129` | OK |
| Core build-info fixture | `OK: RhwpCoreBuildInfo writer and verifier fixtures passed` |
| Studio Cargo.lock fixture | Commit/hash match, stale checkout, non-Git directory와 fingerprint 오류 case 포함해 OK |
| Production core build-info verifier | OK |
| Production studio resource verifier | OK |
| Shared Swift AppKit/UIKit boundary | OK |
| 전체 workflow 6개 Psych parse | OK |
| 수정 workflow 2개 actionlint | OK |
| Generated full/studio PR body validator | OK |
| Change classification | macOS=true, Rust=true, render=false, release=true |
| 실제 upstream strict verifier | OK |
| `git diff --check` | OK |
| 원격 base 관계 | Review-fix commit 기준 `origin/devel` 대비 behind 0, ahead 8 |

`SC2129`는 기존 body writer의 반복 append style에 대한 기존 제외다. GitHub-hosted macOS build와 `build-rust-macos.sh --verify-lock`은 PR에서 분류된 원격 gate로 확인한다.

## 변경 규모

Stage 4 커밋 기준 `origin/devel...HEAD` diff는 19 files, `+1,146 / -20`이다. 이 중 신규 isolated fixture는 216줄이고 verifier는 30줄 증가했다. 나머지 큰 증가는 수행·구현·단계 보고 문서다. 제품 Swift/Rust source, bundled asset과 lock diff는 0이다.

## PR 리뷰 반영

[PR #465 리뷰 코멘트](https://github.com/postmelee/alhangeul-macos/pull/465#issuecomment-5275363459)의 merge 전 권고와 함께 요청된 소규모 보완을 반영했다.

| 리뷰 항목 | 반영 결과 |
|----------|-----------|
| Strict verifier가 `--upstream-dir`와 expected commit을 결합하지 않음 | Git checkout HEAD와 manifest/`--commit` resolved commit을 먼저 비교하고, 일치할 때만 root `Cargo.lock` hash를 확인한다. |
| Cargo.lock이 같은 stale checkout이 통과 | Cargo.lock을 변경하지 않고 fixture HEAD만 전진시켜 expected/actual/path 진단과 실패를 고정했다. Non-Git directory도 strict mode에서 실패한다. |
| Studio-only body가 존재하지 않는 자동 workflow를 전제 | 활성 workflow를 주장하지 않고 전달된 Verification 결과에 fingerprint 일치가 기록됐는지 확인하도록 문구를 바꿨다. |
| Sync self-check가 구조상 동일 값을 재비교 | Generated manifest를 다시 읽어 writer quoting/copy drift를 방어하고 upstream HEAD를 독립 재확인한다는 주석을 추가했다. |

Full sync workflow의 독립 verifier 호출은 명시적 candidate 사후 gate와 verification summary 근거이므로 유지했다. 구체적 classification 진단, 현재 control flow에서 참인 summary 고정 문구와 기존 option compatibility도 유지했다.

리뷰 보정 후 전체 shell syntax, 관련 helper `shellcheck -e SC2129`, core/studio isolated fixture, production verifier, 실제 upstream `v0.8.2` commit/hash strict 검증, shared Swift boundary, 전체 workflow Psych parse, 수정 workflow actionlint, full/studio generated body validator, change classification과 `git diff --check`가 통과했다. Initial PR head의 GitHub-hosted PR CI 4개도 모두 성공했으며 review-fix push 뒤 같은 gate를 다시 확인한다.

## 잔여 위험과 후속 작업

### Task #375 PR

- PR 생성 후 GitHub-hosted macOS/Rust/release checks를 확인한다.
- PR CI가 모두 통과한 뒤에만 `devel` merge를 승인한다.
- Merge 후 Issue close와 branch cleanup은 `pr-merge-cleanup` 절차로 수행한다.

### 기존 PR #463과 upstream sync

Task #375는 기존 [PR #463](https://github.com/postmelee/alhangeul-macos/pull/463)을 수정하거나 merge하지 않았다. 권장 후속 순서는 다음과 같다.

1. Task #375 PR merge
2. 별도 승인 후 기존 #463 close와 `automation/rhwp-v0.8.4-full-sync` branch 정리
3. 최신 `devel`의 upstream sync workflow 재실행
4. 새 candidate에서 build info와 Cargo.lock fingerprint automatic gate 확인
5. 새 sync PR merge 후 release 작업 진행

### Public release

Task #375는 signing/notarization, GitHub Release, Pages/Sparkle, Homebrew Cask 작업을 실행하지 않았다. 새 upstream sync PR merge 뒤 별도 release 승인과 runbook을 따른다.

## 작업지시자 검토 요청

Task #375 PR에서 다음을 중점 확인해 달라.

1. Resource-only legacy 호환과 sync candidate strict gate의 책임 분리
2. Manifest 형식 오류와 actual provenance mismatch의 구분된 진단
3. Upstream sync가 target checkout으로 PR 생성 전 자동 차단하는 경계
4. #463을 재사용하지 않고 Task #375 merge 뒤 cleanup·workflow 재실행하는 후속 순서
