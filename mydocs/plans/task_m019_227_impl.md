# Task M019 #227 구현계획서

## 목적

수행계획서에서 승인된 방향에 따라 Rust bridge staticlib artifact 검증 정책을 hybrid 기준으로 구현한다.

본 구현은 `librhwp.a` byte hash를 모든 GitHub-hosted CI/release gate의 필수 조건으로 보지 않고, `rhwp` source provenance, `Cargo.lock`, generated header, FFI symbol, 앱 build/smoke를 핵심 검증으로 유지한다. `rhwp-core.lock`의 staticlib hash/size는 reference artifact 식별자와 strict local 검증 입력으로 남기며, #220의 release workflow skip 예외도 공식 정책으로 정리한다.

## 승인된 정책 기준

- PR CI, release rehearsal, release publish는 GitHub-hosted macOS runner/toolchain 차이를 고려해 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`을 사용할 수 있다.
- 이 skip은 `Frameworks/universal/librhwp.a` byte hash/size에만 적용한다.
- `rhwp` repo/ref/tag/commit, `RustBridge/Cargo.lock`, `Frameworks/generated_rhwp.h`, `rhwp-ffi-symbols.txt` 검증은 계속 필수 gate로 유지한다.
- strict staticlib byte hash를 release gate로 되돌리려면 Rust toolchain, Xcode, macOS runner image, archive tool, build path 또는 lock 생성 환경을 별도로 고정해야 한다.
- #227 PR은 #220의 release/rehearsal staticlib hash 예외 정책 완료 기준을 함께 충족해야 한다.

## 전체 단계

### Stage 1: 현황 inventory와 정책 결정 기록

목표:

- 현재 PR CI, release rehearsal, release publish, local build guide에서 staticlib hash 검증이 어떻게 실행되는지 inventory로 정리한다.
- hybrid 정책을 단계 산출물에 명시하고, #220이 #227 범위에 포함되는 근거를 남긴다.

예상 변경 파일:

- `mydocs/working/task_m019_227_stage1.md`

검증:

```bash
rg -n "ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY|--verify-lock|librhwp.a|run_rust_verify" \
  scripts .github/workflows mydocs/manual README.md
git diff --check -- mydocs/working/task_m019_227_stage1.md
```

커밋:

```text
Task #227 Stage 1: staticlib 검증 정책 inventory 정리
```

승인 게이트:

- Stage 1 완료보고서 승인 후 Stage 2 진행

### Stage 2: build script와 PR 분류 보강

목표:

- `scripts/build-rust-macos.sh --verify-lock`의 skip warning과 mismatch 안내가 실제 보장 범위를 명확히 설명하도록 보강한다.
- 필요 시 staticlib byte hash strict 검증을 명시적으로 재활성화할 수 있는 안내를 추가한다.
- `scripts/ci/classify-pr-changes.sh`의 `run_rust_verify` 사유 출력과 `RustBridge/examples/*` 분류를 점검해 helper 변경이 lock-level verify를 불필요하게 켜지 않도록 유지한다.

예상 변경 파일:

- `scripts/build-rust-macos.sh`
- `scripts/ci/classify-pr-changes.sh`
- `mydocs/working/task_m019_227_stage2.md`

검증:

```bash
bash -n scripts/build-rust-macos.sh
bash -n scripts/ci/classify-pr-changes.sh
scripts/ci/classify-pr-changes.sh --help
scripts/ci/classify-pr-changes.sh origin/devel-webview HEAD
git diff --check -- scripts/build-rust-macos.sh scripts/ci/classify-pr-changes.sh mydocs/working/task_m019_227_stage2.md
```

커밋:

```text
Task #227 Stage 2: Rust lock verify 출력과 PR 분류 보강
```

승인 게이트:

- Stage 2 완료보고서 승인 후 Stage 3 진행

### Stage 3: workflow release gate 정렬

목표:

- `.github/workflows/pr-ci.yml`, `release-rehearsal.yml`, `release-publish.yml`의 staticlib skip 환경 변수 사용을 같은 정책 문구와 summary로 정렬한다.
- workflow에서 source lock/header/ABI 검증이 낮아지지 않았는지 확인한다.
- release workflow의 `Verify rhwp lock` 단계가 staticlib byte hash skip을 명시적으로 설명하도록 조정한다.

예상 변경 파일:

- `.github/workflows/pr-ci.yml`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- `mydocs/working/task_m019_227_stage3.md`

검증:

```bash
rg -n "ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY|Verify rhwp lock|Prepare Rust bridge artifacts|run_rust_verify" \
  .github/workflows
git diff --check -- .github/workflows/pr-ci.yml .github/workflows/release-rehearsal.yml .github/workflows/release-publish.yml mydocs/working/task_m019_227_stage3.md
```

커밋:

```text
Task #227 Stage 3: CI와 release staticlib 검증 gate 정렬
```

승인 게이트:

- Stage 3 완료보고서 승인 후 Stage 4 진행

### Stage 4: manual과 README 정책 문서화

목표:

- `rhwp-core.lock` artifact hash/size 의미를 reference artifact/provenance record로 문서화한다.
- `--verify-lock`의 기본 검증 대상과 staticlib skip 시 남는 검증 대상을 build/core/CI/release 문서에서 일관되게 설명한다.
- #220의 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1` 허용 조건과 제거 조건을 release 문서에 남긴다.

예상 변경 파일:

- `README.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/manual/release_policy_guide.md`
- `mydocs/manual/release_packaging_dmg_guide.md`
- `mydocs/working/task_m019_227_stage4.md`

검증:

```bash
rg -n "staticlib|librhwp.a|rhwp-core.lock|--verify-lock|ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY|run_rust_verify" \
  README.md mydocs/manual
git diff --check -- README.md mydocs/manual mydocs/working/task_m019_227_stage4.md
```

커밋:

```text
Task #227 Stage 4: staticlib 검증 정책 문서화
```

승인 게이트:

- Stage 4 완료보고서 승인 후 Stage 5 진행

### Stage 5: 통합 검증과 최종 보고

목표:

- shell syntax, PR 분류 helper, staticlib skip lock verify, Swift boundary, HostApp build를 실행한다.
- 검증 결과와 남은 deterministic build 조건, #220/#227 close 근거를 최종 보고서에 정리한다.
- 오늘할일 상태를 완료로 갱신한다.

예상 변경 파일:

- `mydocs/report/task_m019_227_report.md`
- `mydocs/orders/20260511.md`

검증:

```bash
bash -n scripts/build-rust-macos.sh
bash -n scripts/ci/classify-pr-changes.sh
bash -n scripts/ci/*.sh
scripts/ci/classify-pr-changes.sh --help
scripts/ci/classify-pr-changes.sh origin/devel-webview HEAD
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project Alhangeul.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
rg -n "ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY|staticlib|librhwp.a|rhwp-core.lock|run_rust_verify|--verify-lock" \
  README.md mydocs/manual scripts .github/workflows
git diff --check
```

커밋:

```text
Task #227 Stage 5 + 최종 보고서: staticlib 검증 정책 정리
```

승인 게이트:

- 최종 보고서 승인 후 `task-final-report` 절차로 PR 게시 진행

## PR close 전략

PR 본문에는 다음을 명시한다.

- `Closes #227`
- `Closes #220`
- #220은 release/rehearsal workflow의 staticlib hash skip 예외 허용 조건과 제거 조건이 #227의 정책 문서화 및 workflow 정렬로 해결됨

이슈 close는 PR merge 전 별도로 수행하지 않는다. merge 전에는 PR closing keyword 또는 최종 보고서 승인 흐름으로만 연결한다.

## 리스크와 보정 기준

- Stage 2나 Stage 3에서 workflow 변경이 과해지면 `script output/message only`와 `behavior change`를 분리해 단계 범위를 축소한다.
- `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/build-rust-macos.sh --verify-lock`가 dependency fetch나 local toolchain 문제로 실패하면 staticlib 정책 실패와 분리해 기록한다.
- HostApp build가 generated artifact 준비 외 사유로 실패하면 같은 Stage 5 안에서 원인을 확인하고, 범위가 커지면 구현계획서 보정 승인을 요청한다.
- `rhwp-core.lock`의 실제 hash/size 값은 이번 작업에서 재생성하지 않는다. 값 변경이 필요하다고 확인되면 별도 승인 후 처리한다.

## 승인 요청 사항

이 구현계획서 승인 후 Stage 1 inventory와 정책 결정 기록을 시작한다.
