# Task M019 #227 Stage 4 완료 보고서

## 단계 목적

Stage 1~3에서 정한 Rust bridge staticlib 검증 정책을 README와 manual에 장기 운영 기준으로 문서화했다.

이번 단계는 문서 변경만 수행했다. script와 workflow 동작은 Stage 2~3 상태에서 변경하지 않았다.

## 변경 내용

### README

변경 파일: `README.md`

변경 사항:

- Core Bridge 설명에 `rhwp-core.lock`이 core source provenance와 Rust bridge reference artifact metadata를 기록한다는 항목을 추가했다.
- Project Structure의 `rhwp-core.lock` 설명을 `core provenance + Rust bridge reference artifact metadata`로 바꿨다.
- License/provenance 문구를 나눠 core/version provenance와 Rust bridge reference artifact metadata는 `rhwp-core.lock`, bundled `rhwp-studio` provenance는 studio manifest에 기록된다고 명확히 했다.

### Build/Run Guide

변경 파일: `mydocs/manual/build_run_guide.md`

변경 사항:

- `rhwp-core.lock` 설명을 산출물 hash/size 기록에서 Rust bridge reference artifact metadata 기록으로 조정했다.
- `--verify-lock` 설명 아래에 staticlib hash policy를 추가했다.
- 로컬 strict 검증은 `librhwp.a`와 generated header hash/size를 모두 비교하지만, GitHub-hosted CI/release workflow에서는 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`로 `librhwp.a` byte hash/size 비교만 제외할 수 있다고 설명했다.
- skip이 켜져도 source provenance, `RustBridge/Cargo.lock`, generated header, `rhwp-ffi-symbols.txt` 검증은 유지된다고 명시했다.
- strict staticlib byte hash를 release gate로 되돌리는 조건을 toolchain/runner/build path 또는 CI 기준 lock 생성 환경 고정으로 정리했다.

### Core Dependency Guide

변경 파일: `mydocs/manual/core_dependency_operation_guide.md`

변경 사항:

- 소유 경계의 `rhwp-core.lock` 설명을 reference artifact metadata 기준으로 바꿨다.
- `Artifact 검증 정책` 섹션을 추가했다.
- `rhwp-core.lock` source provenance 필드와 generated header/FFI symbol 검증을 핵심 gate로 분리했다.
- `Frameworks/universal/librhwp.a` hash/size는 reference artifact metadata로 유지하되, GitHub-hosted CI/release에서 byte hash/size 비교만 제외할 수 있다고 정리했다.
- 업데이트 후 확인 항목에서 staticlib은 reference metadata, generated header는 hash/size 검증 대상으로 구분했다.

### CI Workflow Guide

변경 파일: `mydocs/manual/ci_workflow_guide.md`

변경 사항:

- `run_rust_verify` 의미를 Rust bridge/core source/header/ABI lock 검증으로 좁혀 표현했다.
- PR CI macOS validation이 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`을 설정하며, 이 값은 `librhwp.a` byte hash/size 비교만 제외한다고 설명했다.
- `RustBridge/examples/*` helper 변경은 macOS build는 요구할 수 있지만 lock-level `run_rust_verify`는 켜지 않는다고 명시했다.

### Release Policy / Packaging / Distribution

변경 파일:

- `mydocs/manual/release_policy_guide.md`
- `mydocs/manual/release_packaging_dmg_guide.md`
- `mydocs/manual/release_distribution_guide.md`

변경 사항:

- release provenance 표에서 staticlib reference metadata와 generated header hash/size를 분리했다.
- `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`의 허용 조건과 남는 검증을 release policy에 명시했다.
- release packaging 확인 기준에서 GitHub-hosted workflow의 staticlib byte hash/size skip 허용, generated header hash/size 일치, FFI symbol set 일치를 분리했다.
- package/release script 설명을 source/header/ABI 기준 `rhwp-core.lock` 검증으로 조정했다.
- release distribution 최종 체크리스트에 `librhwp.a` byte hash skip 여부와 남는 source/header/ABI 검증 확인을 추가했다.

## #220 연결 근거

#220의 핵심 완료 기준은 release/rehearsal workflow의 staticlib hash skip 예외를 숨은 우회로로 남기지 않고, 허용 조건과 제거 조건을 문서화하는 것이었다.

Stage 4에서 다음 기준을 문서화했으므로 #220 범위는 #227 안에서 함께 해결 가능하다.

- skip env는 `Frameworks/universal/librhwp.a` byte hash/size 비교만 제외한다.
- source provenance, `RustBridge/Cargo.lock`, generated header, FFI symbol 검증은 유지한다.
- GitHub-hosted CI/release runner/toolchain 차이를 skip 허용 조건으로 둔다.
- strict staticlib byte hash gate 복귀 조건은 Rust toolchain, Xcode, macOS runner image, archive tool, build path 또는 CI 기준 lock 생성 환경 고정이다.

## 변경하지 않은 범위

- `scripts/build-rust-macos.sh`
- `scripts/ci/classify-pr-changes.sh`
- `.github/workflows/*`
- `rhwp-core.lock`
- `rhwp-ffi-symbols.txt`
- `Frameworks/*`
- release 실행, signing, notarization, GitHub Release 게시, Pages deployment, Homebrew Cask 반영

## 검증

실행한 명령:

```bash
rg -n "staticlib|librhwp\\.a|rhwp-core.lock|--verify-lock|ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY|run_rust_verify|reference artifact|source/header/ABI" \
  README.md mydocs/manual
git diff --check -- README.md mydocs/manual mydocs/working/task_m019_227_stage4.md
```

결과:

- `rg`: README와 manual의 staticlib/hash/skip 관련 문구가 새 정책 기준으로 노출되는 것을 확인
- `git diff --check`: 통과

## 잔여 위험

- Stage 4는 문서화 단계라 실제 `--verify-lock` 실행과 HostApp build는 수행하지 않았다.
- release workflow 실제 GitHub Actions 실행은 아직 수행하지 않았다.
- 최종 통합 검증에서 script syntax, PR 분류, staticlib skip lock verify, Swift boundary, HostApp build를 다시 실행해야 한다.

## 다음 단계 영향

Stage 5에서는 통합 검증을 실행하고 최종 보고서에 #227과 #220 close 근거를 함께 정리한다. 특히 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/build-rust-macos.sh --verify-lock`가 실제로 source/header/ABI 검증을 유지하는지 확인한다.

## 승인 요청

Stage 4 완료를 승인하면 Stage 5 통합 검증과 최종 보고로 진행한다.
