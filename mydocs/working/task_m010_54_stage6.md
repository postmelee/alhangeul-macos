# Issue #54 Stage 6 완료 보고서

## 단계 목적

core 안정 기준을 release tag + resolved commit으로 정렬하고, 현재 최신 release tag로 즉시 전환 가능한지 검증한다.

## hwpql 확인 결과

`hulryung/hwpql` 최신 release는 `v0.4.0`이며 release target은 `main`이다.

확인한 core 관리 방식:

- `rhwp-ffi/Cargo.toml`에서 `rhwp`를 git dependency `rev`로 고정한다.
- FFI wrapper crate는 앱 저장소가 소유한다.
- `libs/rhwp.lock`에 repo, commit, built_at, artifact, sha256, size를 기록한다.
- `scripts/build-rust.sh`가 Rust static library를 빌드하고 lock을 갱신한다.
- `scripts/release.sh`는 release build 시작 전에 `libs/libhwp_ffi.a` sha256과 `libs/rhwp.lock`을 비교하고 불일치 시 중단한다.

참고한 hwpql release `v0.4.0`의 `rhwp` pin:

```text
repo: https://github.com/edwardkim/rhwp.git
commit: b3ca2589aa0c389787ddedd6585bf4f532ef18c6
artifact: libhwp_ffi.a
```

우리 앱은 이 방향을 더 엄격하게 적용해 release tag와 resolved commit을 함께 기록하는 쪽이 맞다.

## edwardkim/rhwp 최신 release 확인

확인 시점의 최신 release:

- release tag: `v0.7.3`
- release target branch: `main`
- resolved commit: `c2e8a3461de800a02f76127ff4797bade1d4e532`
- published_at: `2026-04-19T12:38:52Z`

`main`과 `devel`은 현재 모두 protected branch지만, 앱 dependency의 재현성 기준은 branch가 아니라 release tag와 resolved commit이다.

## release tag 빌드 검증

검증 절차:

```bash
git -C Vendor/rhwp fetch origin tag v0.7.3
git -C Vendor/rhwp checkout --detach v0.7.3
cargo build --release --manifest-path RustBridge/Cargo.toml --target aarch64-apple-darwin
git -C Vendor/rhwp checkout devel
cargo build --release --manifest-path RustBridge/Cargo.toml --target aarch64-apple-darwin
```

`v0.7.3` 검증 결과: 실패.

```text
error[E0599]: no method named `build_page_render_tree` found for struct `DocumentCore`
error[E0599]: no method named `get_bin_data` found for struct `DocumentCore`
```

원인:

- 현재 macOS native renderer는 `rhwp_render_page_tree`를 통해 `DocumentCore::build_page_render_tree`를 호출한다.
- 이미지 렌더링 경로는 `rhwp_image_data`를 통해 `DocumentCore::get_bin_data`를 호출한다.
- 두 API는 최신 release `v0.7.3`에 없고, 현재 lock commit `1e9d78a1d40c71779d81c6ec6870cd301d912626`에 포함되어 있다.

검증 후 `Vendor/rhwp`는 기존 고정 commit으로 복귀했다.

## 보정 내용

- `rhwp-core.lock`
  - `rhwp_ref_kind = "branch"` 추가
  - `rhwp_release_transition_status = "blocked-missing-bridge-apis"` 추가
  - 최신 확인 release tag와 resolved commit 기록
- `scripts/build-rust-macos.sh`
  - lock 갱신 시 release transition metadata를 보존하도록 수정
- `scripts/update-rhwp-core.sh`
  - 현재 submodule lock에도 release transition metadata를 기록하도록 수정
- `rhwp-core.lock`
  - Stage 6 검증 중 재생성된 현재 산출물 기준으로 `librhwp.a` sha256/size를 갱신했다.
- `README.md`, `AGENTS.md`, `mydocs/tech/project_architecture.md`, `mydocs/manual/core_submodule_operation_guide.md`
  - `devel`을 안정 기준처럼 설명하는 문구를 제거
  - 안정 기준은 release tag + resolved commit임을 명시
  - 현재 상태는 release tag 전환 대기임을 명시
- GitHub Issue #30
  - release tag 전환 조건과 API compatibility gate를 보강

## 검증

통과:

```bash
git diff --check
bash -n scripts/build-rust-macos.sh
bash -n scripts/update-rhwp-core.sh
./scripts/build-rust-macos.sh --update-lock
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
```

검색:

```bash
rg -n "edwardkim/rhwp.*devel|devel.*edwardkim/rhwp" README.md AGENTS.md mydocs/tech mydocs/manual
```

결과: 출력 없음.

## 완료 판단

최신 release tag로 즉시 전환할 수 없음을 확인했고, lock과 운영 문서는 release tag 전환 대기 상태로 보정했다. 후속 Issue #30은 release tag가 필요한 bridge API를 포함하는지 먼저 검증한 뒤 진행해야 한다.
