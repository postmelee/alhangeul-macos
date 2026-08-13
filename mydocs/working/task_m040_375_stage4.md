# Task #375 Stage 4 완료보고서

## 단계 목적

`source_cargo_lock_sha256` 자동 비교의 resource-only 하위 호환과 upstream sync strict gate 경계를 운영 문서에 반영하고, 실제 upstream `v0.8.2` checkout을 포함한 shell·fixture·workflow·본문 통합 검증으로 Issue #375 수용 기준을 확인했다.

## 산출물

| 파일 | 변경 | 요약 |
|------|------|------|
| `mydocs/manual/build_run_guide.md` | 수정 | Resource-only/strict verifier 명령과 오류 진단 문서화 |
| `mydocs/manual/core_dependency_operation_guide.md` | 수정 | Full sync 자동 fingerprint gate와 점검 항목 반영 |
| `mydocs/manual/ci_workflow_guide.md` | 수정 | PR CI fixture, upstream sync 차단 조건, 로컬 재현과 실패 해석 반영 |
| `mydocs/tech/core_release_compatibility.md` | 수정 | RustBridge lock과 upstream studio provenance 실패 책임 분리 |
| `mydocs/working/task_m040_375_stage4.md` | 신규 | 운영 문서 변경과 통합 검증 기록 |
| `mydocs/orders/20260813.md` | 수정 | #375를 Stage 4 완료, 최종 보고 진행 상태로 갱신 |

## 변경 내용

### Resource-only와 strict 검증 경계

일반 앱 build·PR CI·release 검증은 upstream checkout이 없으므로 기존 resource-only verifier를 유지한다. 이 경로에서는 legacy manifest의 `source_cargo_lock_sha256` 누락을 허용하고, field가 있으면 lowercase SHA-256 형식을 확인한다.

Upstream sync candidate는 target checkout을 함께 넘겨 다음 명령을 blocking gate로 사용한다.

```bash
scripts/verify-rhwp-studio-assets.sh \
  --upstream-dir /absolute/path/to/target-rhwp-checkout \
  --tag <release-tag> \
  --commit <resolved-commit>
```

Strict mode에서는 manifest field, upstream root `Cargo.lock`과 실제 hash 일치가 모두 필수다. Field 누락, malformed SHA-256, upstream directory/file 누락, 값 mismatch를 서로 다른 오류로 진단한다.

### 자동 gate와 maintainer 검토 책임

Full sync workflow는 bundled studio sync 직후 writer self-check와 explicit verifier에서 같은 target checkout을 사용한다. Fingerprint 오류가 있으면 candidate stage·commit·push·PR 생성 전에 중단된다.

Generated PR body와 Actions summary는 `Cargo.lock fingerprint match OK` 결과를 기록한다. Maintainer는 SHA-256을 수동 재계산하는 대신 target tag/commit, 자동 verifier 결과와 app-facing impact를 검토한다.

### Lock 실패 유형 분리

`RustBridge/Cargo.lock`과 `rhwp-core.lock` resolved commit 불일치는 기존 `Cargo.lock mismatch`다. Bundled studio manifest와 target upstream root `Cargo.lock` 실제 hash 불일치는 `upstream Cargo.lock provenance mismatch`로 별도 분류한다. 후자는 manifest 값을 수동 보정하지 않고 target checkout과 asset 생성 시점을 확인한 뒤 candidate를 재생성한다.

## 실제 upstream 검증

Production manifest가 가리키는 upstream release를 shallow checkout해 tracked file과 worktree file을 독립 확인했다.

```text
release tag: v0.8.2
resolved commit: 9b16aa9e23f476e2b335d7c029fc9f24a199d63c
manifest source_cargo_lock_sha256:
64ff4041c1874c01c7a901b28df2639082836ced44df392cd37b3227d4772279

$ shasum -a 256 <upstream>/Cargo.lock
64ff4041c1874c01c7a901b28df2639082836ced44df392cd37b3227d4772279

$ git -C <upstream> show HEAD:Cargo.lock | shasum -a 256
64ff4041c1874c01c7a901b28df2639082836ced44df392cd37b3227d4772279

$ scripts/verify-rhwp-studio-assets.sh \
    --upstream-dir <upstream> \
    --tag v0.8.2 \
    --commit 9b16aa9e23f476e2b335d7c029fc9f24a199d63c
OK: manifest source_cargo_lock_sha256 matches <upstream>/Cargo.lock
OK: rhwp-studio assets verified
```

Checkout은 ignored `build.noindex/`에만 두었고 production manifest와 asset을 수정하지 않았다.

## 요구사항별 완료 증거

| Issue #375 요구사항 | 완료 증거 |
|------|------|
| Manifest fingerprint와 target upstream root `Cargo.lock` 실제 SHA-256 비교 | Verifier `--upstream-dir` 구현, isolated match/mismatch fixture, 실제 `v0.8.2` strict 통과 |
| Field 누락 하위 호환 | Resource-only legacy fixture 성공, strict mode field 누락 fixture 실패 |
| Full/studio sync target checkout 사용 | `sync-rhwp-studio.sh` writer self-check와 full sync workflow explicit verifier에 `upstream_dir` 전달 |
| Malformed field와 실제 mismatch 구분 | Format 오류와 manifest/actual/path mismatch 진단을 fixture로 고정 |
| 운영 문서와 PR body/checklist 갱신 | Build/core/CI/compatibility 문서 4종과 full/studio generated PR body helper 반영 |

## 본문 변경 정도 / 본문 무손실 여부

Stage 4는 문서와 보고서만 변경했다. Task 전체 기준으로 `Sources/HostApp/Resources/rhwp-studio/**`, `RustBridge/**`, `Frameworks/**`, `rhwp-core.lock`, `RhwpCoreBuildInfo.swift`를 변경하지 않았다. Existing PR #463, automation branch, workflow run과 release 상태도 변경하지 않았다.

## 통합 검증 결과

```text
$ for script in scripts/*.sh scripts/ci/*.sh; do bash -n "$script"; done
통과

$ shellcheck -e SC2129 <Task #375 관련 6개 helper>
통과
SC2129는 기존 body writer의 반복 append style에 대한 기존 제외다.

$ scripts/ci/test-rhwp-core-build-info.sh
OK: RhwpCoreBuildInfo writer and verifier fixtures passed

$ scripts/ci/test-rhwp-studio-cargo-lock-verification.sh
OK: rhwp-studio Cargo.lock fingerprint verification fixtures passed

$ ./scripts/verify-rhwp-core-build-info.sh
OK

$ ./scripts/verify-rhwp-studio-assets.sh
OK: rhwp-studio assets verified

$ ./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies

$ ruby Psych.parse_file <전체 workflow>
전체 6개 workflow parse 통과

$ actionlint .github/workflows/pr-ci.yml .github/workflows/rhwp-upstream-sync-pr.yml
통과

$ scripts/ci/classify-pr-changes.sh origin/devel HEAD
docs_only=false
run_macos_build=true
run_rust_verify=true
run_render_smoke=false
run_release_checks=true

$ scripts/validate-github-body.sh <generated full/studio body>
두 본문 통과, automatic verifier checklist와 verification 문구 확인

$ git diff --check
통과
```

## 잔여 위험

- GitHub-hosted PR CI의 macOS build와 Rust lock verify는 PR 생성 뒤 원격 check에서 최종 확인한다.
- 실제 automation workflow의 candidate 차단 동작은 Task #375가 `devel`에 merge된 뒤 기존 #463을 정리하고 workflow를 재실행할 때 확인한다.
- Task #375는 기존 #463 또는 bundled studio/core version을 갱신하지 않는다.

## 다음 단계 영향

`task-final-report` 절차로 Task 전체 통합 검증과 최종 보고서를 작성하고, 오늘할일을 완료 처리한 뒤 `publish/task375` push와 `devel` 대상 Open PR을 생성한다.

## 승인 근거

작업지시자가 Issue #375 작업과 PR 생성까지 명시했으므로 최종 보고와 PR 게시까지 진행한다.
