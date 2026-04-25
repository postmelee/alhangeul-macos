# Issue #29 Stage 2 완료 보고서

## 단계 목적

`rhwp-core.lock` v2 형식을 도입하고, `scripts/build-rust-macos.sh`에 lock update/verify를 위한 옵션 parsing과 공통 helper 구조를 추가한다.

## 변경 내용

### `rhwp-core.lock` v2 형식 도입

기존 `generated_artifacts` 배열을 제거하고 다음 형식으로 변경했다.

- `lock_version = 2`
- `built_at`
- `[[artifacts]]`
  - `path`
  - `sha256`
  - `size`

Stage 2에서는 형식 도입 단계이므로 `sha256`은 빈 문자열, `size`는 `0`으로 둔다. 실제 artifact metadata 기록은 Stage 3의 `--update-lock` 검증에서 수행한다.

현재 artifact 대상:

- `Frameworks/universal/librhwp.a`
- `Frameworks/generated_rhwp.h`

### `build-rust-macos.sh` 옵션 구조 추가

추가한 옵션:

- `--update-lock`
- `--verify-lock`
- `--help`

동시 지정 방지:

- `--update-lock`과 `--verify-lock`을 같이 지정하면 사용 오류로 실패한다.

기본 실행:

- 기존과 같이 Rust staticlib build, universal library 생성, cbindgen header 검증, XCFramework 생성을 수행한다.
- 기본 실행에서는 `rhwp-core.lock`을 수정하지 않는다.

### lock helper 추가

추가한 helper:

- `artifact_sha256`
- `artifact_size`
- `artifact_abs_path`
- `require_artifact`
- `current_rhwp_commit`
- `write_lock_file`

`write_lock_file`은 Stage 3의 update 동작 기반으로 사용할 수 있게 추가했다. Stage 2에서는 helper 구조만 마련했으며, verify 비교 로직은 Stage 3에서 완성한다.

### `update-rhwp-core.sh` v2 형식 반영

`scripts/update-rhwp-core.sh`가 기존 v1 lock 형식을 덮어쓰지 않도록 v2 형식으로 갱신했다.

또한 후속 안내 문구를 다음 흐름으로 변경했다.

```bash
./scripts/build-rust-macos.sh --update-lock && ./scripts/check-no-appkit.sh
```

## 추가 확인 사항

Stage 1에서 `git -C Vendor/rhwp rev-parse HEAD` 결과를 submodule HEAD로 해석했으나, 실제로는 `Vendor/rhwp`가 초기화되지 않아 상위 저장소를 조회한 결과였다.

Stage 2 검증 전에 다음 명령으로 submodule을 gitlink 기준으로 초기화했다.

```bash
git submodule update --init --recursive
```

결과:

```text
Submodule path 'Vendor/rhwp': checked out '1e9d78a1d40c71779d81c6ec6870cd301d912626'
```

따라서 현재 `Vendor/rhwp`, gitlink, `rhwp-core.lock` commit은 같은 기준으로 정렬되어 있다.

## 검증

### shell 문법 검사

```bash
bash -n scripts/build-rust-macos.sh
bash -n scripts/update-rhwp-core.sh
```

결과: 통과.

### 옵션 help 확인

```bash
./scripts/build-rust-macos.sh --help
```

결과: `--update-lock`, `--verify-lock` 사용법 출력 확인.

### 기본 build 확인

```bash
./scripts/build-rust-macos.sh
```

결과: 통과.

확인된 출력:

- arm64/x86_64 Rust staticlib build 통과
- `Frameworks/universal/librhwp.a` universal binary 생성
- FFI symbol set 검증 통과
- `Frameworks/Rhwp.xcframework` 생성 통과

참고: sandbox 환경에서 `xcodebuild -create-xcframework` 실행 중 CoreSimulator 관련 경고가 출력되었으나, XCFramework 생성은 성공했다.

### diff whitespace 검사

```bash
git diff --check -- rhwp-core.lock scripts/build-rust-macos.sh scripts/update-rhwp-core.sh
```

결과: 통과.

## 생성된 로컬 산출물

다음 경로는 빌드 검증 중 생성되었으며 `.gitignore` 대상이다.

- `Frameworks/`
- `RustBridge/target/`

커밋 대상에 포함하지 않는다.

## 다음 단계

Stage 3에서 다음 동작을 완성한다.

- `./scripts/build-rust-macos.sh --update-lock`
- `./scripts/build-rust-macos.sh --verify-lock`
- lock 불일치 시 expected/actual 출력
- `Vendor/rhwp` commit과 `rhwp-core.lock`의 `rhwp_commit` 비교

## 승인 요청

이 Stage 2 완료 보고서 기준으로 Stage 3를 진행할지 승인 요청한다.
