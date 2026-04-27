# Issue #29 Stage 1 완료 보고서

## 단계 목적

현재 Rust bridge 산출물 생성 흐름과 `rhwp-core.lock` 구조를 확인하고, v2 lock update/verify 구현에 필요한 artifact 기준을 확정한다.

## 확인한 내용

### 현재 lock 구조

`rhwp-core.lock`은 현재 다음 정보만 기록한다.

- `rhwp_repo`
- `rhwp_branch`
- `rhwp_commit`
- `ffi_symbols_file`
- `generated_artifacts`

현재 형식에는 `Frameworks/universal/librhwp.a`와 generated header의 `sha256`, `size`, `built_at`이 없다. 따라서 산출물이 lock에 기록된 core commit에서 생성된 것인지 파일 단위로 검증할 수 없다.

### submodule 상태

확인 명령:

```bash
git -C Vendor/rhwp rev-parse HEAD
git ls-files -s Vendor/rhwp
git submodule status --recursive
```

확인 결과:

- `git ls-files -s Vendor/rhwp`: `1e9d78a1d40c71779d81c6ec6870cd301d912626`
- `rhwp-core.lock`의 `rhwp_commit`: `1e9d78a1d40c71779d81c6ec6870cd301d912626`
- `git -C Vendor/rhwp rev-parse HEAD`: `1f6d22b158cae0b0bd32bdd4fda506610fbb995c`
- `git submodule status --recursive`: `-1e9d78a1d40c71779d81c6ec6870cd301d912626 Vendor/rhwp`

즉, gitlink와 lock은 서로 일치하지만, 현재 `/tmp/rhwp-mac-task29/Vendor/rhwp` 작업트리에서 직접 조회되는 HEAD는 다르다. Stage 3에서 lock verify를 구현할 때는 이 상태를 그대로 방치하면 검증 결과가 혼란스러울 수 있다.

다음 단계 구현 전 또는 Stage 3 검증 전에 `git submodule update --init --recursive`로 작업트리의 submodule 상태를 gitlink 기준으로 맞추는 것이 필요하다.

### 산출물 생성 지점

`scripts/build-rust-macos.sh` 기준:

- `Frameworks/universal/librhwp.a`
  - arm64/x86_64 staticlib 빌드 후 `xcrun lipo -create`로 생성한다.
  - 생성 위치: `scripts/build-rust-macos.sh` 57-63행
- `Frameworks/generated_rhwp.h`
  - `cbindgen`으로 생성한다.
  - 생성 위치: `scripts/build-rust-macos.sh` 65-67행
- `Frameworks/modulemap/rhwp.h`
  - generated header를 복사해 만든다.
  - 생성 위치: `scripts/build-rust-macos.sh` 85-89행
- `Frameworks/Rhwp.xcframework`
  - `xcodebuild -create-xcframework`로 생성한다.
  - 생성 위치: `scripts/build-rust-macos.sh` 96-98행

이번 작업의 1차 검증 대상은 다음 두 파일로 확정한다.

- `Frameworks/universal/librhwp.a`
- `Frameworks/generated_rhwp.h`

`Frameworks/modulemap/rhwp.h`는 `generated_rhwp.h`의 복사본이므로 중복 검증 대상에서 제외한다. `Frameworks/Rhwp.xcframework`는 directory artifact라 파일 순서와 metadata 제외 정책을 별도 설계해야 하므로 이번 범위에서는 제외한다.

### 현재 산출물 존재 여부

현재 작업트리에는 `Frameworks/` 디렉터리가 없다. `.gitignore`에서도 `/Frameworks/`가 제외되어 있으므로 이는 저장소 정책과 일치한다.

따라서 Stage 2/3 구현은 산출물이 없을 때 명확한 오류를 출력해야 하고, 실제 update/verify 검증은 `./scripts/build-rust-macos.sh --update-lock` 또는 `--verify-lock` 실행 중 산출물을 생성한 뒤 수행해야 한다.

### package-release 현재 흐름

`scripts/package-release.sh`는 현재 다음 순서로 동작한다.

1. `build/release` 생성
2. `./scripts/build-rust-macos.sh` 실행
3. `xcodegen generate`
4. Release app build
5. zip 생성과 sha256 출력

현재는 Rust bridge 산출물 lock verify가 없고, 빌드 출력 경로도 repository 강제 규칙의 `build.noindex/` 정책과 다르다. Stage 4에서는 package 전 lock verify를 넣고, 빌드 산출물 경로는 범위 내에서 `build.noindex/release`로 조정하는 것이 타당하다.

## 확정한 구현 기준

- lock v2 artifact 대상은 `Frameworks/universal/librhwp.a`, `Frameworks/generated_rhwp.h` 두 파일로 시작한다.
- sha256은 macOS 기본 도구인 `shasum -a 256`으로 계산한다.
- size는 macOS 기본 도구인 `stat -f%z`로 계산한다.
- `built_at`은 `--update-lock` 실행 시 UTC ISO-8601 문자열로 기록한다.
- `--verify-lock`은 artifact sha256/size와 `Vendor/rhwp` commit 정합성을 함께 확인한다.
- 일반 `./scripts/build-rust-macos.sh`는 lock을 수정하지 않는다.

## 리스크와 후속 조치

- 현재 submodule 작업트리 HEAD가 gitlink/lock과 다르므로, 실제 빌드 검증 전에 submodule 정합성을 맞춰야 한다.
- `scripts/update-rhwp-core.sh`가 기존 lock 형식을 직접 overwrite하므로, Stage 2 이후 이 스크립트도 v2 lock 형식에 맞춰 갱신 대상에 포함하는 것이 안전하다.
- `package-release.sh`의 `build/release` 경로는 현재 repository 운영 규칙과 맞지 않으므로 Stage 4에서 `build.noindex/release` 전환 여부를 함께 반영한다.

## 검증

```bash
git diff --check -- mydocs/plans/task_m050_29_impl.md
```

결과: 통과.

## 다음 단계

Stage 2에서 `rhwp-core.lock` v2 형식과 `scripts/build-rust-macos.sh`의 lock helper/옵션 parsing 구조를 구현한다.

## 승인 요청

이 Stage 1 완료 보고서 기준으로 Stage 2를 진행할지 승인 요청한다.
