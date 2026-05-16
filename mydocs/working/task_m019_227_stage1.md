# Task M019 #227 Stage 1 완료 보고서

## 단계 목적

Rust bridge staticlib artifact 검증 정책을 바꾸기 전에 현재 PR CI, release rehearsal, release publish, local build guide에서 `librhwp.a` hash 검증이 어떻게 동작하는지 inventory로 정리했다.

이번 단계에서는 제품 코드, workflow, script 동작을 수정하지 않고 현재 상태와 정책 결정을 기록했다.

## 현재 lock 기준

`rhwp-core.lock` 현재 값:

| 항목 | 값 |
|------|----|
| lock version | `2` |
| `rhwp` repository | `https://github.com/edwardkim/rhwp.git` |
| ref kind | `release-tag` |
| release tag | `v0.7.10` |
| resolved commit | `62a458aa317e962cd3d0eec6096728c172d57110` |
| FFI symbols file | `rhwp-ffi-symbols.txt` |
| staticlib artifact | `Frameworks/universal/librhwp.a` |
| staticlib sha256 | `fefa08d741cfdd6645081ca838601f677f6da064d95308555e29629f7609f7a2` |
| staticlib size | `107120120` |
| generated header artifact | `Frameworks/generated_rhwp.h` |
| generated header sha256 | `69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5` |
| generated header size | `1349` |

현재 lock은 source provenance와 두 artifact hash/size를 함께 담는다. Stage 1 정책 결정에서는 staticlib hash/size를 reference artifact 식별자로 유지하고, generated header hash/size는 ABI 표면 검증 gate로 계속 본다.

## 현황 조사 결과

### `build-rust-macos.sh --verify-lock`

현재 `scripts/build-rust-macos.sh`는 `LOCK_ARTIFACTS`로 다음 두 파일을 검증한다.

- `Frameworks/universal/librhwp.a`
- `Frameworks/generated_rhwp.h`

`--verify-lock`에서 항상 먼저 확인하는 항목:

- `rhwp-core.lock` 존재와 `lock_version = 2`
- `rhwp_repo`
- `rhwp_ref_kind`
- release tag일 때 `rhwp_release_tag`
- `rhwp_commit`

artifact loop에서는 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`인 경우 `Frameworks/universal/librhwp.a`의 byte-for-byte hash/size 비교만 건너뛴다. 현재 경고 문구는 source lock, Cargo lock, generated header, FFI symbols가 계속 검증된다고 설명한다.

부족한 점:

- `--help` 문구는 skip 정책을 설명하지 않는다.
- skip 경고는 짧고, `librhwp.a` hash/size만 제외된다는 점과 reference artifact 의미가 충분히 드러나지 않는다.
- mismatch 오류의 안내는 모든 artifact에 `--update-lock`을 제안하므로 GitHub-hosted runner/toolchain 차이와 의도된 source/ABI 변경을 구분하는 데 부족하다.

### PR CI

`.github/workflows/pr-ci.yml`의 `macos-validation` job은 현재 다음 env를 갖는다.

```yaml
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY: "1"
```

`scripts/ci/classify-pr-changes.sh` 결과 `run_rust_verify=true`이면 `./scripts/build-rust-macos.sh --verify-lock`을 실행하고, 아니면 일반 `./scripts/build-rust-macos.sh`를 실행한다.

현재 분류 기준:

| 변경 경로 | 현재 flag |
|-----------|-----------|
| `RustBridge/examples/*` | `run_macos_build=true`, `run_rust_verify=false` |
| `RustBridge/*` | `run_macos_build=true`, `run_rust_verify=true` |
| `rhwp-core.lock` | `run_macos_build=true`, `run_rust_verify=true` |
| `Frameworks/*` | `run_macos_build=true`, `run_rust_verify=true` |
| `Vendor/rhwp/*` | `run_macos_build=true`, `run_rust_verify=true` |
| `rust-toolchain.toml` | `run_macos_build=true`, `run_rust_verify=true` |
| `scripts/build-rust-macos.sh` | `run_macos_build=true`, `run_rust_verify=true` |
| `scripts/update-rhwp-core.sh` | `run_macos_build=true`, `run_rust_verify=true` |
| `scripts/sync-rhwp-studio.sh` | `run_macos_build=true`, `run_rust_verify=true` |
| `scripts/verify-rhwp-studio-assets.sh` | `run_macos_build=true`, `run_rust_verify=true` |

부족한 점:

- PR CI summary는 `run_rust_verify` 값만 보여주고, staticlib hash skip 정책이 적용된다는 사실은 별도 summary로 설명하지 않는다.
- `classify-pr-changes.sh`의 분류는 현재 단기 보정 상태로 맞지만, helper 변경과 lock-level verify 변경의 의도 차이를 문서와 summary에 더 명확히 드러낼 필요가 있다.

### Release rehearsal workflow

`.github/workflows/release-rehearsal.yml`은 job env에 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY: "1"`을 둔다.

검증 흐름:

1. `Read core lock`에서 `rhwp_release_tag`, `rhwp_commit`을 읽고, 선택 입력 `expected_rhwp_tag`와 비교한다.
2. `Install build dependencies`에서 Rust target과 build dependency를 준비한다.
3. `Verify rhwp lock`에서 `./scripts/build-rust-macos.sh --verify-lock`을 실행한다.
4. `Build rehearsal DMG`에서 `./scripts/release.sh --skip-notarize "$VERSION"`을 실행한다.

부족한 점:

- workflow summary에 staticlib byte hash skip이 의도된 정책이라는 설명이 없다.
- release rehearsal의 `Verify rhwp lock` 단계명만 보면 `rhwp-core.lock`의 모든 artifact byte hash가 strict하게 검증되는 것으로 오해할 수 있다.

### Release publish workflow

`.github/workflows/release-publish.yml`도 `publish-dmg` job env에 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY: "1"`을 둔다.

검증 흐름:

1. tag ref와 app version 입력을 확인한다.
2. `Read and validate core lock`에서 `rhwp_release_tag`, `rhwp_commit`을 읽고 필수 입력 `expected_rhwp_tag`와 비교한다.
3. 필요 시 upstream latest release tag와 lock tag를 비교한다.
4. `Verify rhwp lock`에서 `./scripts/build-rust-macos.sh --verify-lock`을 실행한다.
5. 이후 signed/notarized DMG build와 release asset 검증으로 진행한다.

부족한 점:

- public release workflow도 staticlib byte hash를 건너뛰지만, release policy 문서의 "release 전 `--verify-lock`으로 Rust bridge artifact hash/size 검증" 문구와 맞지 않는다.
- #220에서 요구한 skip 예외의 허용 조건과 제거 조건이 workflow 또는 manual에 명시되어 있지 않다.

### Local release/package scripts

`scripts/release.sh`와 `scripts/package-release.sh`는 내부에서 `./scripts/build-rust-macos.sh --verify-lock`을 실행한다.

이 스크립트들은 workflow job env를 상속받으면 staticlib byte hash skip 상태로 실행된다. 반대로 로컬에서 env 없이 실행하면 `librhwp.a`와 generated header hash/size를 모두 strict 비교한다.

정책상 이 차이는 허용할 수 있다. 로컬 strict 검증은 기준 환경에서 reference artifact를 확인하는 수단으로 남기고, GitHub-hosted CI/release workflow는 toolchain 차이에 취약한 staticlib byte hash만 제외한다.

### Manual과 README

현재 문서의 공통 문제는 `--verify-lock`을 "artifact hash/size strict 검증"처럼 설명한다는 점이다.

확인된 문서 상태:

- `README.md`: `rhwp-core.lock`을 `core provenance + Rust bridge artifact hash/size`로 설명한다.
- `build_run_guide.md`: `--verify-lock` 검증 대상에 `Frameworks/universal/librhwp.a` sha256/size와 generated header sha256/size를 함께 둔다.
- `core_dependency_operation_guide.md`: 업데이트 절차에서 `--update-lock` 후 `--verify-lock`을 실행하고, 확인 항목에 두 artifact hash/size 갱신 여부를 둔다.
- `ci_workflow_guide.md`: `run_rust_verify`를 Rust bridge/core lock 검증 필요 flag로 설명하지만 staticlib skip 정책은 없다.
- `release_policy_guide.md`: Rust bridge artifact hash/size를 release 전 `--verify-lock`으로 검증한다고 설명한다.
- `release_packaging_dmg_guide.md`: release 후보 확인 기준에서 `Frameworks/universal/librhwp.a`, `Frameworks/generated_rhwp.h`의 hash/size가 lock과 일치해야 한다고 설명한다.
- `release_distribution_guide.md`: 최종 체크리스트에 `./scripts/build-rust-macos.sh --verify-lock` 통과를 둔다.

Stage 4에서 문서가 구분해야 할 기준:

- local strict mode: env 없이 `--verify-lock` 실행 시 두 artifact hash/size를 모두 비교한다.
- GitHub-hosted CI/release mode: env가 켜진 상태에서 staticlib byte hash/size만 skip한다.
- skip 상태에서도 source lock, Cargo lock, generated header, FFI symbol 검증은 유지한다.
- staticlib hash/size는 reference artifact/provenance record로 남는다.

## 정책 결정

Stage 1에서 확정한 정책은 다음과 같다.

1. #227은 hybrid 정책으로 진행한다.
2. `rhwp-core.lock`은 `rhwp` source provenance와 artifact reference metadata를 계속 담는다.
3. `Frameworks/generated_rhwp.h` hash/size는 Swift/Rust ABI 표면 검증에 직접 연결되므로 skip하지 않는다.
4. `Frameworks/universal/librhwp.a` hash/size는 GitHub-hosted macOS runner에서 필수 gate로 보지 않는다.
5. `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`은 `librhwp.a` byte hash/size 비교만 제외하는 공식 정책 env로 둔다.
6. PR CI, release rehearsal, release publish는 현재처럼 이 env를 사용할 수 있다.
7. strict staticlib byte hash 검증을 release gate로 되돌리려면 Rust toolchain, Xcode, macOS runner image, archive tool, build path 또는 CI 기준 lock 생성 환경을 먼저 고정해야 한다.
8. #220은 #227 안에서 release/rehearsal skip 예외의 허용 조건과 제거 조건을 문서화하고 workflow summary를 정렬하면 함께 완료할 수 있다.

## 다음 단계 변경 대상

Stage 2:

- `scripts/build-rust-macos.sh`
- `scripts/ci/classify-pr-changes.sh`
- `mydocs/working/task_m019_227_stage2.md`

Stage 3:

- `.github/workflows/pr-ci.yml`
- `.github/workflows/release-rehearsal.yml`
- `.github/workflows/release-publish.yml`
- `mydocs/working/task_m019_227_stage3.md`

Stage 4:

- `README.md`
- `mydocs/manual/core_dependency_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/ci_workflow_guide.md`
- `mydocs/manual/release_policy_guide.md`
- `mydocs/manual/release_packaging_dmg_guide.md`
- 필요 시 `mydocs/manual/release_distribution_guide.md`
- `mydocs/working/task_m019_227_stage4.md`

이번 작업에서 계속 제외:

- `rhwp-core.lock` 실제 hash/size 값 재생성
- `rhwp-ffi-symbols.txt` 변경
- `Frameworks/*` generated artifact 갱신
- upstream `edwardkim/rhwp` 변경
- public release 실행, signing, notarization, GitHub Release 게시, Pages deployment, Homebrew Cask 반영

## 검증

실행한 명령:

```bash
rg -n "ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY|--verify-lock|librhwp.a|run_rust_verify|staticlib|artifact hash|rhwp-core.lock|generated header|rhwp-ffi-symbols" \
  scripts .github/workflows mydocs/manual README.md rhwp-core.lock
sed -n '1,180p' .github/workflows/pr-ci.yml
sed -n '1,180p' .github/workflows/release-rehearsal.yml
sed -n '1,280p' .github/workflows/release-publish.yml
sed -n '420,535p' scripts/build-rust-macos.sh
sed -n '60,155p' scripts/ci/classify-pr-changes.sh
sed -n '55,115p' mydocs/manual/ci_workflow_guide.md
sed -n '140,155p' mydocs/manual/release_policy_guide.md
sed -n '15,38p' mydocs/manual/release_packaging_dmg_guide.md
sed -n '70,90p' mydocs/manual/release_distribution_guide.md
sed -n '1,80p' rhwp-core.lock
```

결과:

- PR CI, release rehearsal, release publish 모두 `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1`을 이미 사용 중이다.
- `build-rust-macos.sh --verify-lock`은 skip env가 켜졌을 때 `Frameworks/universal/librhwp.a`만 건너뛰고, generated header는 계속 hash/size 비교 대상이다.
- `RustBridge/examples/*`는 현재 `run_macos_build=true`, `run_rust_verify=false`로 분류되어 #224의 단기 보정 방향과 맞다.
- release 관련 manual은 아직 staticlib skip 예외를 공식 정책으로 설명하지 않는다.

## 잔여 위험

- Stage 1은 조사/정책 기록 단계이므로 script와 workflow의 실제 출력은 아직 개선되지 않았다.
- `--verify-lock`이라는 이름과 현재 release 문서 문구는 여전히 strict artifact byte hash 검증처럼 읽힐 수 있다.
- #220 완료 기준인 skip env 허용/제거 조건은 Stage 4 문서화 전까지 아직 완전히 충족되지 않는다.

## 승인 요청

Stage 1 완료를 승인하면 Stage 2 build script와 PR 분류 보강으로 진행한다.
