# Task M019 #227 최종 결과보고서

## 작업 요약

- 이슈: #227 Rust bridge staticlib artifact 검증 정책 재정의
- 관련 이슈: #220 Rust staticlib hash 재현성 검증 정책 정리
- 마일스톤: M019 (`v0.1.2`)
- 브랜치: `local/task227`
- 기준 브랜치: `devel-webview`
- 결론: `librhwp.a` byte hash/size를 GitHub-hosted CI/release gate의 필수 조건에서 분리하고, `rhwp` source provenance, `Cargo.lock`, generated header, FFI symbol 검증은 유지하는 hybrid 정책으로 정리했다.

## 최종 정책

`rhwp-core.lock`은 계속 source provenance와 Rust bridge reference artifact metadata를 담는다. 다만 GitHub-hosted macOS runner에서는 `Frameworks/universal/librhwp.a` byte hash/size 비교가 Rust compiler, Xcode, macOS runner image, archive tool, build path 차이에 민감하므로 필수 gate로 보지 않는다.

유지하는 gate:

- `rhwp` repo/ref/tag/commit
- `RustBridge/Cargo.lock` resolved commit
- `Frameworks/generated_rhwp.h` hash/size
- `rhwp-ffi-symbols.txt`와 generated FFI symbol set
- HostApp Debug build와 관련 CI/release helper 검증

완화한 gate:

- GitHub-hosted CI/release workflow의 `Frameworks/universal/librhwp.a` byte hash/size 비교

복귀 조건:

- strict staticlib byte hash를 public release gate로 복귀하려면 Rust toolchain, Xcode, macOS runner image, archive tool, build path 또는 CI 기준 lock 생성 환경을 먼저 고정한다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `scripts/build-rust-macos.sh` | staticlib hash skip env 설명, skip warning, staticlib mismatch note 보강 |
| `scripts/ci/classify-pr-changes.sh` | `run_rust_verify` 의미와 staticlib hash skip policy를 help/summary에 출력 |
| `.github/workflows/pr-ci.yml` | macOS validation summary에 Rust bridge lock policy 추가 |
| `.github/workflows/release-rehearsal.yml` | release rehearsal summary와 lock 검증 step 명칭 정렬 |
| `.github/workflows/release-publish.yml` | release publish summary와 lock 검증 step 명칭 정렬 |
| `README.md` | `rhwp-core.lock`을 core provenance + reference artifact metadata로 설명 |
| `mydocs/manual/build_run_guide.md` | `--verify-lock` 검증 대상과 staticlib skip 정책 문서화 |
| `mydocs/manual/core_dependency_operation_guide.md` | artifact 검증 정책 섹션 추가 |
| `mydocs/manual/ci_workflow_guide.md` | `run_rust_verify`와 PR CI staticlib skip 정책 정리 |
| `mydocs/manual/release_policy_guide.md` | release provenance 기준에서 staticlib reference metadata와 generated header 검증 분리 |
| `mydocs/manual/release_packaging_dmg_guide.md` | release 전 확인 기준을 source/header/ABI 중심으로 보정 |
| `mydocs/manual/release_distribution_guide.md` | 최종 체크리스트에 staticlib skip 여부와 남는 검증 확인 추가 |
| `mydocs/plans/task_m019_227.md` | 수행계획서 |
| `mydocs/plans/task_m019_227_impl.md` | 구현계획서 |
| `mydocs/working/task_m019_227_stage1.md` | 현황 inventory와 정책 결정 기록 |
| `mydocs/working/task_m019_227_stage2.md` | build script와 PR 분류 보강 보고 |
| `mydocs/working/task_m019_227_stage3.md` | workflow release gate 정렬 보고 |
| `mydocs/working/task_m019_227_stage4.md` | README/manual 정책 문서화 보고 |
| `mydocs/orders/20260511.md` | #227 완료 처리 |

## 단계별 커밋

| 단계 | 커밋 | 내용 |
|------|------|------|
| 수행계획 | `5c27cfc` | 수행 계획서 작성과 오늘할일 갱신 |
| 구현계획 | `93ca149` | 구현 계획서 작성 |
| Stage 1 | `92156f4` | staticlib 검증 정책 inventory 정리 |
| Stage 2 | `aad60d1` | Rust lock verify 출력과 PR 분류 보강 |
| Stage 3 | `a0d9adb` | CI와 release staticlib 검증 gate 정렬 |
| Stage 4 | `204ffb8` | staticlib 검증 정책 문서화 |

## 수용 기준별 결과

| 수용 기준 | 결과 |
|-----------|------|
| `rhwp-core.lock` artifact hash/size의 의미 문서화 | OK. staticlib은 reference artifact metadata, generated header는 ABI 검증 metadata로 분리 |
| PR CI와 release workflow에서 수행하는 검증 명확화 | OK. help, summary, workflow step, manual에 반영 |
| `RustBridge/examples/*` helper 변경이 lock-level verify를 불필요하게 깨뜨리지 않음 | OK. 기존 분류 유지 및 summary에 의도 설명 |
| core/FFI/ABI 변경은 충분한 검증 유지 | OK. source provenance, `Cargo.lock`, generated header, FFI symbols 유지 |
| #220 release/rehearsal skip env 허용 조건 문서화 | OK. GitHub-hosted runner/toolchain 차이와 staticlib byte hash 한정 skip으로 명시 |
| #220 skip env 제거/복귀 조건 문서화 | OK. Rust/Xcode/runner/archive tool/build path 또는 CI 기준 lock 생성 환경 고정 필요로 명시 |

## 검증 결과

실행한 명령과 결과:

| 명령 | 결과 |
|------|------|
| `bash -n scripts/build-rust-macos.sh` | 통과 |
| `bash -n scripts/ci/classify-pr-changes.sh` | 통과 |
| `bash -n scripts/ci/*.sh` | 통과 |
| `scripts/ci/classify-pr-changes.sh --help` | 통과, staticlib skip note 확인 |
| `scripts/ci/classify-pr-changes.sh origin/devel-webview HEAD` | 통과, `run_macos_build=true`, `run_rust_verify=true`, `run_release_checks=true` |
| `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/build-rust-macos.sh --verify-lock` | 통과, `librhwp.a` byte hash skip warning과 `Verified: rhwp-core.lock` 확인 |
| `./scripts/check-no-appkit.sh` | 통과 |
| `xcodegen generate` | 통과 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build` | 통과, `BUILD SUCCEEDED` |
| `rg -n "ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY\|staticlib\|librhwp.a\|rhwp-core.lock\|run_rust_verify\|--verify-lock" README.md mydocs/manual scripts .github/workflows` | 통과 |
| `git diff --check` | 통과 |

참고:

- 첫 `xcodebuild` 실행은 sandbox가 `~/Library/Caches`와 `~/.cache/clang` 쓰기를 막아 SwiftPM dependency resolve 단계에서 실패했다.
- 같은 명령을 권한 상승으로 재실행해 Sparkle package resolve와 HostApp Debug build가 통과했다.
- `ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 ./scripts/build-rust-macos.sh --verify-lock` 실행 중 Xcode/CoreSimulator 관련 경고가 출력됐지만 `Rhwp.xcframework` 생성과 lock 검증은 성공했다.

## 변경 전후 비교

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| staticlib hash skip | workflow env로만 존재해 숨은 예외처럼 보임 | script help/warning, workflow summary, manual에 정책으로 명시 |
| `--verify-lock` 설명 | artifact hash strict 검증처럼 읽힘 | source/header/ABI 유지 + staticlib byte hash 한정 skip으로 구분 |
| `run_rust_verify` 의미 | Rust bridge/core lock 검증 | Rust bridge/core source/header/ABI lock 검증 |
| release workflow step | `Verify rhwp lock` | `Verify rhwp source, header, and ABI lock` |
| `rhwp-core.lock` artifact 의미 | core provenance + artifact hash/size | core provenance + Rust bridge reference artifact metadata |

## 미수행 범위

- `rhwp-core.lock` hash/size 값 재생성
- `rhwp-ffi-symbols.txt` 변경
- `Frameworks/*` generated artifact 커밋
- upstream `edwardkim/rhwp` 변경
- public release 실행
- signing/notarization
- GitHub Release 게시
- Pages deployment
- Homebrew Cask 반영
- 원격 push/PR 생성

## PR close 전략

PR 본문에는 다음을 함께 명시한다.

- `Closes #227`
- `Closes #220`

#220은 #227 범위 안에서 release/rehearsal staticlib hash skip 예외의 허용 조건과 제거 조건을 문서화하고, workflow summary로 드러나게 했으므로 같은 PR에서 함께 close할 수 있다. 단, 이슈 close는 PR merge 전 별도로 수행하지 않는다.

## 잔여 관리 항목

- GitHub Actions 실제 실행 결과는 PR 생성 후 확인해야 한다.
- PR 게시 전 원격 `devel-webview`가 갱신되면 rebase/merge 충돌 여부를 다시 확인해야 한다.
- strict staticlib byte reproducibility를 다시 목표로 삼는 경우 별도 이슈로 toolchain/runner/build path 고정 전략을 설계해야 한다.

## 작업지시자 승인 요청

최종 보고와 검증은 완료됐다. 다음 절차는 `task-final-report` 절차로 `publish/task227` 원격 브랜치 push와 `devel-webview` 대상 Open PR 생성이다.
