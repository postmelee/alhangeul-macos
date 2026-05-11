# Task M019 #227 Stage 2 완료 보고서

## 단계 목적

`build-rust-macos.sh --verify-lock`와 PR 변경 분류 helper가 Stage 1에서 확정한 hybrid staticlib 검증 정책을 더 명확히 설명하도록 보강했다.

이번 단계는 script 출력과 PR summary 개선만 다뤘다. GitHub Actions workflow의 step summary 정렬과 manual/README 문서화는 각각 Stage 3, Stage 4 범위로 남겼다.

## 변경 내용

### `scripts/build-rust-macos.sh`

변경 사항:

- `STATICLIB_ARTIFACT="Frameworks/universal/librhwp.a"` 상수를 추가해 staticlib artifact path 비교를 한 곳으로 모았다.
- `--help` 출력에 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1` 환경 변수를 설명했다.
- staticlib hash skip 경고를 `print_staticlib_hash_skip_warning` 함수로 분리했다.
- staticlib hash mismatch가 발생했을 때 `print_staticlib_hash_mismatch_note`로 환경 차이에 민감한 byte-for-byte archive 검증이라는 점을 설명하도록 했다.

정책 반영:

- skip env가 켜져도 `Frameworks/universal/librhwp.a` byte hash/size 비교만 제외한다.
- source provenance, `Cargo.lock`, generated header, FFI symbol 검증은 계속 실행된다고 출력에서 명시한다.
- strict mismatch 발생 시 `rhwp-core.lock`을 runner/toolchain 차이만으로 갱신하지 말라는 안내를 추가했다.

### `scripts/ci/classify-pr-changes.sh`

변경 사항:

- `--help`의 `Notes`에 `run_rust_verify=true`의 의미를 추가했다.
- PR classification summary에 `Rust verify policy` 섹션을 추가했다.
- `run_rust_verify=true`일 때는 `--verify-lock` 실행과 staticlib byte hash skip policy를 설명한다.
- `run_rust_verify=false`일 때는 lock 비교 없이 Rust bridge artifact를 재빌드한다는 점과 `RustBridge/examples/*` helper 변경이 lock-level verify를 켜지 않는다는 점을 설명한다.

정책 반영:

- `run_rust_verify`는 "source/core/header/ABI 검증 필요" 신호로 남긴다.
- `librhwp.a` byte hash/size skip은 PR macOS validation workflow의 env 정책으로 분리해 설명한다.
- `RustBridge/examples/*`의 단기 보정 방향은 유지했다.

## 변경하지 않은 범위

- `.github/workflows/pr-ci.yml`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- `README.md`
- `mydocs/manual/*`
- `rhwp-core.lock`
- `rhwp-ffi-symbols.txt`
- `Frameworks/*`

workflow summary와 release gate 문구 정렬은 Stage 3에서 처리한다. manual/README 정책 문서화와 #220 완료 기준 연결은 Stage 4에서 처리한다.

## 검증

실행한 명령:

```bash
bash -n scripts/build-rust-macos.sh
bash -n scripts/ci/classify-pr-changes.sh
scripts/build-rust-macos.sh --help
scripts/ci/classify-pr-changes.sh --help
scripts/ci/classify-pr-changes.sh origin/devel-webview <stage2-temp-commit>
git diff --check -- scripts/build-rust-macos.sh scripts/ci/classify-pr-changes.sh mydocs/working/task_m019_227_stage2.md
```

결과:

- `bash -n scripts/build-rust-macos.sh`: 통과
- `bash -n scripts/ci/classify-pr-changes.sh`: 통과
- `scripts/build-rust-macos.sh --help`: `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1` 설명 출력 확인
- `scripts/ci/classify-pr-changes.sh --help`: `run_rust_verify`와 staticlib byte hash skip note 출력 확인
- `scripts/ci/classify-pr-changes.sh origin/devel-webview <stage2-temp-commit>`: Stage 2 변경 포함 분류 확인
  - `docs_only=false`
  - `run_macos_build=true`
  - `run_rust_verify=true`
  - `run_render_smoke=false`
  - `run_release_checks=true`
- `git diff --check`: 통과

## 잔여 위험

- 실제 GitHub Actions step summary는 Stage 3에서 workflow 문구를 정렬해야 완전히 명확해진다.
- release/rehearsal workflow에서 staticlib skip이 의도된 정책이라는 설명은 아직 workflow summary에 직접 남지 않는다.
- manual에는 아직 `rhwp-core.lock` staticlib hash/size의 reference artifact 의미와 skip 허용/제거 조건이 반영되지 않았다.

## 다음 단계 영향

Stage 3에서는 PR CI, release rehearsal, release publish workflow가 staticlib skip 정책을 step summary와 단계명에서 명확히 설명하도록 정렬한다. Stage 2에서 script 출력이 보강되었으므로 workflow는 이 정책을 숨은 env가 아니라 명시된 release gate로 보여주면 된다.

## 승인 요청

Stage 2 완료를 승인하면 Stage 3 workflow release gate 정렬로 진행한다.
