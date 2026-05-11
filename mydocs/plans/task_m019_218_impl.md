# Task M019 #218 구현계획서

수행계획서: `mydocs/plans/task_m019_218.md`

각 단계 완료 후 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #218 v0.1.1 release workflow 실패 사례 troubleshooting 문서화
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task218`
- 작업 위치: `/private/tmp/rhwp-mac-task218`
- 기준 브랜치: `devel-webview`
- 목표: `#188` public release 실행 중 발생한 workflow/signing/notarization/staticlib 실패 사례를 장기 운영용 troubleshooting 문서로 정리하고 release manual에서 연결한다.

## 현재 전제와 제약

- `#188` Stage 4 보고서에는 run별 실패와 보정이 이미 기록되어 있다.
- 본 작업은 그 기록을 운영자가 재사용 가능한 troubleshooting 문서로 승격한다.
- release script, workflow, signing 설정, notarization submit, GitHub Release 게시, Pages deployment는 변경하거나 실행하지 않는다.
- `#220`과 `#227`에서 Rust staticlib artifact 검증 정책이 병렬로 정리되고 있으므로, 본 작업은 `#188` 당시 판단과 제한적 예외를 기록하고 장기 정책 결론은 해당 이슈로 연결한다.
- secret 값, certificate payload, app-specific password, token 값, Sparkle private key는 문서에 기록하지 않는다.

## 구현 원칙

- troubleshooting 문서는 stage report 복제가 아니라 진단 절차 문서로 작성한다.
- 각 실패 사례는 `증상`, `재현 조건`, `원인`, `수정`, `예방책` 구조를 유지한다.
- 문서 상단에는 run별 실패 흐름 요약 표를 두어 `#188` Stage 4와 대조할 수 있게 한다.
- release manual에는 긴 사례를 복제하지 않고 troubleshooting 문서로 연결하는 진입점만 추가한다.
- staticlib hash skip은 숨은 우회가 아니라 CI runner/toolchain 차이에서 `librhwp.a` byte hash만 제한적으로 건너뛰고 source lock, Cargo lock, generated header, FFI symbol 검증은 유지한 운영 판단으로 설명한다.

## Stage 1. 실패 사례 inventory와 구조 확정

### 목표

`#188` 기록과 현재 release manual을 대조해 troubleshooting 문서에 들어갈 실패 사례, 민감 정보 제외 기준, 문서 구조를 확정한다.

### 작업

- `mydocs/working/task_m018_188_stage4.md`의 release workflow 실패 표와 보정 내용을 확인한다.
- `mydocs/report/task_m018_188_report.md`의 최종 public release 결과와 잔여 위험을 확인한다.
- `release_distribution_guide.md`와 `release_signing_notarization_guide.md`에서 troubleshooting 연결 위치를 정한다.
- `scripts/release.sh`, `scripts/build-rust-macos.sh`, `scripts/ci/import-developer-id-certificate.sh`의 관련 함수/환경 변수 이름을 확인한다.
- Stage 1 보고서에 문서 구조, 포함 항목, 제외 항목, 후속 이슈 연결을 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m019_218_stage1.md`

### 검증

```bash
rg -n "25632437884|25632495693|25632545387|25632598126|25632780594|25633064531|25633267598|GH_TOKEN|cbindgen|staticlib|Sparkle nested|get-task-allow" \
  mydocs/working/task_m018_188_stage4.md mydocs/report/task_m018_188_report.md
rg -n "troubleshooting|문제|notarization|Developer ID|Sparkle|staticlib" \
  mydocs/manual/release_distribution_guide.md mydocs/manual/release_signing_notarization_guide.md
git diff --check -- mydocs/working/task_m019_218_stage1.md
```

### 완료 기준

- Stage 1 보고서에 troubleshooting 문서의 항목 목록과 구조가 확정된다.
- secret/credential 기록 금지 기준이 명시된다.
- Stage 1에서는 신규 troubleshooting 본문과 release manual을 아직 변경하지 않는다.

### 커밋 메시지

```text
Task #218 Stage 1: release 실패 사례 inventory 정리
```

## Stage 2. troubleshooting 문서 작성

### 목표

`mydocs/troubleshootings/release_v0_1_1_workflow_failures.md`를 추가해 `v0.1.1` release workflow 실패 사례를 운영 문서로 정리한다.

### 작업

- 문서 상단에 대상 release, 관련 이슈, 참조 stage report, 공개 release 결과를 기록한다.
- run별 실패 흐름 요약 표를 추가한다.
- 다음 사례를 각각 `증상`, `재현 조건`, `원인`, `수정`, `예방책` 구조로 작성한다.
  - upstream latest rhwp release 확인 단계의 `GH_TOKEN`/`gh` 인증 실패
  - Developer ID certificate import helper stdout 오염과 `$GITHUB_OUTPUT` format 오류
  - runner의 `cbindgen` 누락으로 인한 rhwp lock 검증 실패
  - `librhwp.a` staticlib byte hash mismatch와 제한적 skip 예외
  - notarization invalid 상태에서 log 없이 진단이 어려웠던 문제
  - Sparkle nested XPC/Autoupdate ad-hoc signature와 timestamp 누락
  - Quick Look/Thumbnail extension `get-task-allow`와 timestamp 누락
- 문서 하단에 다음 release 전 확인 checklist와 후속 이슈(`#219`, `#220`, `#227`) 연결을 둔다.
- Stage 2 보고서에 작성된 troubleshooting 범위와 의도적으로 제외한 변경을 기록한다.

### 예상 변경 파일

- `mydocs/troubleshootings/release_v0_1_1_workflow_failures.md`
- `mydocs/working/task_m019_218_stage2.md`

### 검증

```bash
test -f mydocs/troubleshootings/release_v0_1_1_workflow_failures.md
rg -n "GH_TOKEN|Developer ID|GITHUB_OUTPUT|cbindgen|librhwp.a|ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY|notarization|Sparkle|get-task-allow|entitlement|#219|#220|#227" \
  mydocs/troubleshootings/release_v0_1_1_workflow_failures.md
git diff --check -- mydocs/troubleshootings/release_v0_1_1_workflow_failures.md mydocs/working/task_m019_218_stage2.md
```

### 완료 기준

- troubleshooting 문서가 실제 실패 사례를 항목별 진단 구조로 설명한다.
- staticlib hash skip이 제한적 운영 판단으로 설명되고, 장기 정책은 후속 이슈로 연결된다.
- release script/workflow 변경 없이 문서만 추가된다.

### 커밋 메시지

```text
Task #218 Stage 2: v0.1.1 release 실패 사례 문서화
```

## Stage 3. release manual 연결과 문서 검증

### 목표

release manual에서 troubleshooting 문서로 진입할 수 있게 연결하고, 문서 간 중복과 정책 충돌을 점검한다.

### 작업

- `release_distribution_guide.md`에 `v0.1.1` release workflow 실패 사례 troubleshooting 문서 링크를 추가한다.
- 필요하면 `release_signing_notarization_guide.md`에 signing/notarization 실패 진단 참고 링크를 추가한다.
- release manual에는 사례 세부 내용을 복제하지 않고, 언제 troubleshooting 문서를 참고해야 하는지만 기록한다.
- staticlib hash 항목이 `#220`/`#227` 정책 결정을 대체하지 않도록 문구를 재확인한다.
- Stage 3 보고서에 연결 위치와 검증 결과를 기록한다.

### 예상 변경 파일

- `mydocs/manual/release_distribution_guide.md`
- 필요 시 `mydocs/manual/release_signing_notarization_guide.md`
- `mydocs/working/task_m019_218_stage3.md`

### 검증

```bash
rg -n "release_v0_1_1_workflow_failures|v0.1.1 release workflow|troubleshooting|실패 사례|문제 해결" \
  mydocs/manual/release_distribution_guide.md mydocs/manual/release_signing_notarization_guide.md mydocs/troubleshootings/release_v0_1_1_workflow_failures.md
rg -n "#220|#227|staticlib|ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY" \
  mydocs/troubleshootings/release_v0_1_1_workflow_failures.md
git diff --check -- mydocs/manual/release_distribution_guide.md mydocs/manual/release_signing_notarization_guide.md mydocs/working/task_m019_218_stage3.md
```

### 완료 기준

- release distribution guide에서 troubleshooting 문서로 접근할 수 있다.
- signing/notarization guide는 필요 시 관련 실패 진단 문서로 연결된다.
- manual 본문과 troubleshooting 문서 사이에 정책 충돌이나 과도한 중복이 없다.

### 커밋 메시지

```text
Task #218 Stage 3: release troubleshooting 연결 보강
```

## Stage 4. 최종 정리와 보고

### 목표

전체 문서 변경을 최종 검증하고 오늘할일과 최종 보고서를 정리한다.

### 작업

- troubleshooting 문서와 release manual 링크를 전체 keyword scan으로 확인한다.
- `mydocs/orders/20260511.md`의 `#218` 상태를 완료로 갱신한다.
- 최종 보고서 `mydocs/report/task_m019_218_report.md`를 작성한다.
- Stage 4 보고서를 작성한다.
- 최종 보고서에 검증 결과, 변경 파일, 후속 이슈 의존성, 실행하지 않은 release 작업을 기록한다.

### 예상 변경 파일

- `mydocs/orders/20260511.md`
- `mydocs/working/task_m019_218_stage4.md`
- `mydocs/report/task_m019_218_report.md`

### 검증

```bash
test -f mydocs/troubleshootings/release_v0_1_1_workflow_failures.md
test -f mydocs/report/task_m019_218_report.md
rg -n "GH_TOKEN|Developer ID|GITHUB_OUTPUT|cbindgen|librhwp.a|ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY|notarization|Sparkle|get-task-allow|#219|#220|#227" \
  mydocs/troubleshootings/release_v0_1_1_workflow_failures.md mydocs/report/task_m019_218_report.md
rg -n "release_v0_1_1_workflow_failures|v0.1.1 release workflow|실패 사례" \
  mydocs/manual/release_distribution_guide.md mydocs/manual/release_signing_notarization_guide.md
git diff --check
git status --short
```

### 완료 기준

- `#188` Stage 4 보고서를 보지 않아도 주요 release workflow 실패를 진단할 수 있다.
- release manual에서 troubleshooting 문서로 연결된다.
- staticlib hash 예외는 제한적 운영 판단과 후속 정책 의존성으로 설명된다.
- release workflow 실행, notarization submit, public release 게시, Homebrew tap 배포는 수행하지 않았음이 보고서에 명시된다.

### 커밋 메시지

```text
Task #218 Stage 4: release troubleshooting 최종 정리
```

## 전체 검증 요약

최종 단계에서는 다음 범위를 모두 확인한다.

```bash
git diff --check
rg -n "release_v0_1_1_workflow_failures|GH_TOKEN|Developer ID|cbindgen|librhwp.a|notarization|Sparkle|get-task-allow|#219|#220|#227" \
  mydocs/troubleshootings/release_v0_1_1_workflow_failures.md \
  mydocs/manual/release_distribution_guide.md \
  mydocs/manual/release_signing_notarization_guide.md \
  mydocs/report/task_m019_218_report.md
git status --short
```
