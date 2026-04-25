# Issue #29 구현 계획서

## 목적

`rhwp-core.lock`을 v2 형식으로 확장하고, Rust bridge 산출물의 sha256/size를 명시적으로 갱신하거나 검증할 수 있게 한다.

이번 구현은 `Frameworks/` 산출물이 git 추적 대상이 아니라는 현재 저장소 정책을 유지하면서, release/package 전에 lock과 산출물 불일치를 조기에 발견하는 흐름을 만든다.

## 전제와 결정 사항

- 기존 수행 계획서 `mydocs/plans/task_m050_29.md`를 기준으로 진행한다.
- 기존 문서명이 `task_m050_29`로 작성되어 있으므로 이번 작업 문서도 같은 prefix를 유지한다.
- GitHub Issue #29의 GitHub milestone은 `v0.1.0`이지만, 작업 인계 문서와 오늘 할일은 `M050` 흐름으로 작성되어 있다. 이번 구현에서는 기존 문서 흐름을 깨지 않고, 최종 보고서에 이 불일치를 확인 사항으로 남긴다.
- `Rhwp.xcframework` 디렉터리 전체 해시는 이번 범위에서 제외한다. 첫 구현 대상은 deterministic policy가 명확한 파일 산출물이다.
- 일반 `./scripts/build-rust-macos.sh` 실행은 lock 파일을 수정하지 않는다.

## 구현 단계

### Stage 1. 현재 산출물과 lock 구조 분석

대상:

- `rhwp-core.lock`
- `scripts/build-rust-macos.sh`
- `scripts/package-release.sh`
- `Frameworks/universal/librhwp.a`
- `Frameworks/generated_rhwp.h`

작업:

- 현재 `rhwp-core.lock` 필드와 `Vendor/rhwp` submodule commit 비교 방식을 확인한다.
- `Frameworks/universal/librhwp.a`와 `Frameworks/generated_rhwp.h`가 생성되는 정확한 시점을 확인한다.
- macOS 기본 도구로 sha256/size 산출 명령을 확정한다.
- lock v2에서 기록할 artifact 목록을 최종 확정한다.

산출물:

- `mydocs/working/task_m050_29_stage1.md`

검증:

```bash
git diff --check -- mydocs/plans/task_m050_29_impl.md
```

### Stage 2. lock v2 형식과 shell helper 구현

대상:

- `rhwp-core.lock`
- `scripts/build-rust-macos.sh`

작업:

- `rhwp-core.lock`에 다음 필드를 포함하는 v2 형식을 도입한다.
  - `lock_version`
  - `rhwp_repo`
  - `rhwp_branch`
  - `rhwp_commit`
  - `built_at`
  - `ffi_symbols_file`
  - `[[artifacts]]`
    - `path`
    - `sha256`
    - `size`
- `scripts/build-rust-macos.sh`에 artifact sha256/size 계산 helper를 추가한다.
- `--update-lock`, `--verify-lock` 옵션 parsing 구조를 추가하되, 기존 기본 실행 경로는 유지한다.
- shell에서 과도한 TOML parser를 만들지 않도록, 이번 lock 형식에 필요한 최소 범위만 처리한다.

산출물:

- `mydocs/working/task_m050_29_stage2.md`

검증:

```bash
./scripts/build-rust-macos.sh
git diff --check -- rhwp-core.lock scripts/build-rust-macos.sh
```

### Stage 3. update/verify 동작 완성

대상:

- `scripts/build-rust-macos.sh`
- `rhwp-core.lock`

작업:

- `--update-lock` 실행 시 빌드 후 현재 산출물 기준으로 `rhwp-core.lock`을 갱신한다.
- `--verify-lock` 실행 시 빌드 후 현재 산출물과 lock 기록을 비교한다.
- 불일치 시 artifact path, expected sha256/size, actual sha256/size를 출력하고 실패한다.
- `Vendor/rhwp` submodule HEAD와 `rhwp-core.lock`의 `rhwp_commit` 불일치도 검증 대상에 포함한다.
- `--update-lock`과 `--verify-lock`을 동시에 지정한 경우는 사용 오류로 실패시킨다.

산출물:

- `mydocs/working/task_m050_29_stage3.md`

검증:

```bash
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/build-rust-macos.sh
git diff --check -- rhwp-core.lock scripts/build-rust-macos.sh
```

### Stage 4. package-release lock 검증 연동

대상:

- `scripts/package-release.sh`

작업:

- package 생성 전에 Rust bridge build와 lock verify가 반드시 수행되도록 연결한다.
- lock verify 실패 시 app build와 zip 생성을 시작하지 않는다.
- 기존 version argument 사용법은 유지한다.
- build 산출물 경로는 현 repository 정책에 맞게 `build.noindex/` 사용 필요 여부를 확인하고, 범위 내에서 필요한 최소 변경만 반영한다.

산출물:

- `mydocs/working/task_m050_29_stage4.md`

검증:

```bash
./scripts/package-release.sh 0.0.0-test
git diff --check -- scripts/package-release.sh
```

### Stage 5. 문서 갱신과 전체 검증

대상:

- `README.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- 필요 시 `mydocs/manual/core_submodule_operation_guide.md`
- 필요 시 `mydocs/tech/rhwp_artifact_provenance.md`
- `mydocs/orders/20260425.md`

작업:

- lock update/verify 사용법을 README와 빌드 가이드에 반영한다.
- release/package 전 lock 검증 정책을 릴리스 가이드에 반영한다.
- `Frameworks/`가 git 추적 대상이 아니며 lock은 산출물 provenance 검증 기준이라는 점을 문서화한다.
- 최종 검증 결과를 정리하고 오늘 할일 상태를 갱신한다.

산출물:

- `mydocs/working/task_m050_29_stage5.md`
- `mydocs/report/task_m050_29_report.md`

검증:

```bash
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/build-rust-macos.sh
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
./scripts/package-release.sh 0.0.0-test
git diff --check
git status --short
```

## 구현 시 주의사항

- `AlhangeulMac.xcodeproj`를 직접 수정하지 않는다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 의존을 추가하지 않는다.
- `Frameworks/` 산출물은 gitignore 대상이므로 산출물 자체를 커밋 대상으로 추가하지 않는다.
- lock update는 명시 옵션에서만 수행한다.
- `built_at`은 lock update 시점 기록용이며 verify 비교에서 artifact sha256/size와 commit 검증을 방해하지 않도록 처리한다.
- 실패 메시지는 작업지시자와 후속 작업자가 원인을 바로 파악할 수 있게 expected/actual을 함께 출력한다.

## 승인 요청 사항

이 구현 계획서 기준으로 Stage 1을 시작할지 승인 요청한다.
