# Task M019 #227 Stage 3 완료 보고서

## 단계 목적

PR CI, release rehearsal, release publish workflow에서 staticlib byte hash skip 정책을 숨은 환경 변수로만 두지 않고 GitHub Actions summary와 단계명에 드러나도록 정렬했다.

이번 단계는 workflow 표현과 summary 보강만 다뤘다. manual/README 정책 문서화와 #220 완료 기준 설명은 Stage 4 범위로 남겼다.

## 변경 내용

### PR CI

변경 파일: `.github/workflows/pr-ci.yml`

`macos-validation` job에 `Record Rust bridge lock policy` step을 추가했다.

summary에 기록하는 항목:

- `run_rust_verify` 값
- `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY` 값
- lock verification 실행 시 `Frameworks/universal/librhwp.a` byte hash/size 비교만 skip된다는 설명
- source provenance, Cargo lock, generated header, FFI symbol checks는 계속 실행된다는 설명

동작 변경:

- 기존 `Prepare Rust bridge artifacts`의 조건 분기와 build 명령은 변경하지 않았다.
- `run_rust_verify=true`이면 여전히 `./scripts/build-rust-macos.sh --verify-lock`을 실행한다.
- `run_rust_verify=false`이면 여전히 일반 `./scripts/build-rust-macos.sh`를 실행한다.

### Release Rehearsal DMG

변경 파일: `.github/workflows/release-rehearsal.yml`

`Verify rhwp lock` step 앞에 `Record Rust bridge lock policy` step을 추가했다.

기존 `Verify rhwp lock` 단계명은 다음으로 바꿨다.

```text
Verify rhwp source, header, and ABI lock
```

summary에 기록하는 항목:

- lock command: `./scripts/build-rust-macos.sh --verify-lock`
- `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY` 값
- release workflow 설정에서는 `Frameworks/universal/librhwp.a` byte hash/size 비교만 skip된다는 설명
- source provenance, Cargo lock, generated header, FFI symbol checks는 계속 실행된다는 설명

동작 변경:

- 실행 명령은 기존과 같은 `./scripts/build-rust-macos.sh --verify-lock`이다.
- env도 기존과 같은 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY: "1"`이다.

### Release Publish DMG

변경 파일: `.github/workflows/release-publish.yml`

release rehearsal과 같은 구조로 `Record Rust bridge lock policy` step을 추가하고, `Verify rhwp lock` 단계명을 `Verify rhwp source, header, and ABI lock`으로 바꿨다.

동작 변경:

- public release workflow의 tag 검증, expected `rhwp` tag 검증, upstream latest 검증, signing/notarization 흐름은 변경하지 않았다.
- `./scripts/build-rust-macos.sh --verify-lock` 실행은 유지했다.
- staticlib byte hash skip env는 기존처럼 유지했다.

## 검증

실행한 명령:

```bash
rg -n "ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY|Verify rhwp lock|Verify rhwp source|Record Rust bridge lock policy|run_rust_verify" \
  .github/workflows
ruby -e 'require "yaml"; ARGV.each { |f| YAML.load_file(f); puts f }' \
  .github/workflows/pr-ci.yml \
  .github/workflows/release-rehearsal.yml \
  .github/workflows/release-publish.yml
git diff --check -- \
  .github/workflows/pr-ci.yml \
  .github/workflows/release-rehearsal.yml \
  .github/workflows/release-publish.yml \
  mydocs/working/task_m019_227_stage3.md
```

결과:

- `rg`: 세 workflow 모두 policy summary step과 skip env 위치 확인
- Ruby YAML parse: 세 workflow 파일 load 성공
- Ruby 실행 중 `Ignoring ffi-1.13.1 because its extensions are not built` 경고가 출력되었으나 YAML load 자체는 성공
- `git diff --check`: 통과

## 변경하지 않은 범위

- `scripts/build-rust-macos.sh`
- `scripts/ci/classify-pr-changes.sh`
- `README.md`
- `mydocs/manual/*`
- `rhwp-core.lock`
- `rhwp-ffi-symbols.txt`
- `Frameworks/*`
- signing/notarization/release publish 실행

Stage 2에서 script 출력은 이미 보강했고, Stage 3에서는 workflow가 그 정책을 summary로 보여주게만 했다.

## 잔여 위험

- release manual과 build guide에는 아직 `--verify-lock`이 strict artifact hash 검증처럼 읽히는 문구가 남아 있다.
- #220의 skip env 허용 조건과 제거 조건은 Stage 4 문서화 전까지 완전히 충족되지 않는다.
- GitHub Actions 실제 실행은 이번 단계에서 수행하지 않았으므로, summary 표현은 정적 검증 기준으로만 확인했다.

## 다음 단계 영향

Stage 4에서는 README와 manual 문서를 갱신해 다음 기준을 장기 정책으로 고정한다.

- `rhwp-core.lock` staticlib hash/size는 reference artifact/provenance record다.
- GitHub-hosted CI/release workflow에서는 staticlib byte hash/size 비교만 skip할 수 있다.
- source provenance, Cargo lock, generated header, FFI symbol checks는 계속 필수 gate다.
- strict staticlib byte hash를 다시 release gate로 올리는 제거 조건은 toolchain/runner/build path 고정 또는 CI 기준 lock 생성 환경 확정이다.

## 승인 요청

Stage 3 완료를 승인하면 Stage 4 manual과 README 정책 문서화로 진행한다.
