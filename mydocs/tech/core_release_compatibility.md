# rhwp Core Release Compatibility 기준

## 목적

이 문서는 `RustBridge`를 `edwardkim/rhwp` release tag 기반 dependency로 전환하기 전에 확인해야 하는 core API contract와 compatibility gate를 정의한다.

후속 Issue #30은 이 문서의 gate를 통과한 release tag가 있을 때만 진행한다. `main`, `devel` 같은 branch나 floating ref는 필요한 API가 포함된 commit을 찾는 참고 출처일 뿐, 앱 core의 안정 기준으로 사용하지 않는다.

## 안정 기준

앱 저장소의 core 안정 기준은 다음 둘을 함께 고정하는 것이다.

- `release tag`: GitHub release tag 이름. 예: `v0.7.3`
- `resolved commit`: tag가 가리키는 실제 commit SHA. annotated tag인 경우 tag object가 아니라 `^{commit}`으로 해석한 commit이다.

release tag 전환 이후 `rhwp-core.lock`은 최소한 다음 의미를 가져야 한다.

```toml
lock_version = 2
rhwp_repo = "https://github.com/edwardkim/rhwp.git"
rhwp_ref_kind = "release-tag"
rhwp_release_tag = "<release tag>"
rhwp_commit = "<resolved commit>"
ffi_symbols_file = "rhwp-ffi-symbols.txt"

[[artifacts]]
path = "Frameworks/universal/librhwp.a"
sha256 = "<sha256>"
size = <bytes>

[[artifacts]]
path = "Frameworks/generated_rhwp.h"
sha256 = "<sha256>"
size = <bytes>
```

`Cargo.lock`은 `RustBridge/Cargo.toml`의 `rhwp` git dependency를 해석한 실제 source와 commit을 담는다. 후속 #30에서는 `Cargo.lock`의 `rhwp` package source가 `rhwp-core.lock`의 repo, release tag, resolved commit과 일치해야 한다.

## 현재 release 상태

2026-04-26 Stage 1 확인 기준 최신 release는 다음이다.

```text
release tag: v0.7.3
target branch: main
publishedAt: 2026-04-19T12:38:52Z
resolved commit: c2e8a3461de800a02f76127ff4797bade1d4e532
```

`v0.7.3`에는 다음 API가 있다.

- `DocumentCore::render_page_svg_native`
- `DocumentCore::get_page_info_native`
- `rhwp::parser::extract_thumbnail_only`

`v0.7.3`에는 다음 API가 없다.

- `DocumentCore::build_page_render_tree`
- `DocumentCore::get_bin_data`

따라서 현재 `v0.7.3`은 native render tree 경로를 유지하는 앱 기준을 충족하지 못한다. 실패 유형은 `missing core API`다.

## RustBridge core API contract

`RustBridge`는 앱 저장소가 소유하는 유일한 core adapter다. Swift/macOS 계층은 `DocumentCore` 내부 구조나 Rust crate 세부 type을 직접 알지 않고 C ABI만 사용한다.

| C ABI | core API | contract |
|------|------|------|
| `rhwp_open` | `DocumentCore::from_bytes` | HWP/HWPX bytes를 파싱해 opaque handle을 만든다. 실패 시 null을 반환한다. |
| `rhwp_page_count` | `DocumentCore::page_count` | 총 페이지 수를 `u32`로 반환한다. 실패 또는 null handle은 0으로 처리한다. |
| `rhwp_page_size` | `DocumentCore::get_page_info_native` | page info JSON에서 `width`, `height`를 point 단위 `f64`로 해석한다. 실패 시 0 크기를 반환한다. |
| `rhwp_render_page_tree` | `DocumentCore::build_page_render_tree` | page render tree root를 JSON string으로 반환한다. HostApp, Quick Look, Thumbnail의 기준 렌더 경로다. |
| `rhwp_image_data` | `DocumentCore::get_bin_data` | 1-indexed `bin_data_id`를 0-indexed core bin data index로 변환해 borrowed byte pointer와 길이를 반환한다. Swift는 즉시 `Data`로 복사한다. |
| `rhwp_render_page_svg` | `DocumentCore::render_page_svg_native` | SVG string을 반환한다. 현재 기준 경로가 아니라 진단/임시 표시 후보로만 취급한다. |
| `rhwp_extract_thumbnail` | `rhwp::parser::extract_thumbnail_only` | embedded thumbnail bytes, width, height, format을 Rust-owned buffer로 반환한다. Swift는 `rhwp_free_bytes`, `rhwp_free_string`으로 해제한다. |

필수 C ABI symbol set은 `rhwp-ffi-symbols.txt`로 고정한다. symbol 추가, 제거, 이름 변경은 `FFI symbol diff`로 분리해 검토한다.

## Render tree JSON contract

현재 C ABI는 `rhwp_render_page_tree`에서 envelope 없이 `tree.root`를 JSON string으로 반환한다. Swift 모델은 `Sources/RhwpCoreBridge/RenderTree.swift`의 `RenderNode` 구조를 기준으로 디코딩한다.

현재 Swift가 기대하는 root node 형식:

- top-level object는 `RenderNode`다.
- 필수 공통 필드:
  - `id`
  - `node_type`
  - `bbox`
  - `children`
  - `dirty`
  - `visible`
- `node_type`은 serde externally tagged enum 형태다.
  - unit variant 예: `"MasterPage"`
  - newtype/struct variant 예: `{"TextRun": {...}}`
- image node는 `bin_data_id`를 제공해야 하며, Swift는 이를 `rhwp_image_data`에 넘긴다.

현재 render tree JSON에는 명시적 schema version field가 없다. 따라서 release tag compatibility gate는 다음 중 하나를 만족해야 한다.

1. 기존 JSON shape가 `RenderTree.swift`와 호환되어 render smoke가 통과한다.
2. core가 명시적 schema version을 도입했다면 `RustBridge` 또는 Swift decoder가 version을 확인하고, 비호환 schema를 조용히 렌더링하지 않는다.

후속 #30은 schema 변화가 있는 release를 단순 dependency 전환으로 처리하지 않는다. schema 변화가 render 결과나 decoder 안정성에 영향을 주면 별도 Swift/Rust bridge 적응 작업으로 분리한다.

## Compatibility gate

새 `edwardkim/rhwp` release가 나왔을 때 다음 순서로 확인한다. 전환 후보 release는 모든 gate를 통과해야 한다.

### 1. latest release 조회

```bash
gh release view --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url
```

기록할 항목:

- tag name
- target branch
- publishedAt
- release URL

네트워크 실패, 인증 실패, release 없음은 core API compatibility 실패와 구분해 `release lookup failure`로 기록한다.

### 2. tag resolved commit 확인

```bash
TAG="<release tag>"
git -C Vendor/rhwp fetch origin tag "$TAG"
git -C Vendor/rhwp show-ref --tags "$TAG"
git -C Vendor/rhwp rev-parse "$TAG^{commit}"
```

기록할 항목:

- tag object SHA, 있는 경우
- resolved commit SHA

resolved commit은 `rhwp-core.lock`의 `rhwp_commit` 후보가 된다.

### 3. required core API 확인

```bash
TAG="<release tag>"
git -C Vendor/rhwp grep -n \
  "build_page_render_tree\\|get_bin_data\\|render_page_svg_native\\|get_page_info_native" \
  "$TAG" -- src
git -C Vendor/rhwp grep -n "extract_thumbnail_only" "$TAG" -- src
```

필수 API:

- `DocumentCore::build_page_render_tree`
- `DocumentCore::get_bin_data`
- `DocumentCore::render_page_svg_native`
- `DocumentCore::get_page_info_native`
- `rhwp::parser::extract_thumbnail_only`

`build_page_render_tree` 또는 `get_bin_data`가 없으면 native render tree 기준 경로를 충족하지 못하므로 #30을 진행하지 않는다.

### 4. RustBridge build 확인

release tag 전환 전 submodule 단계에서는 분리 worktree에서 `Vendor/rhwp`만 target tag로 checkout해 확인한다. 메인 작업트리의 submodule pointer를 임시 변경하지 않는다.

```bash
TAG="<release tag>"
COMPAT_WORKTREE="../rhwp-mac-core-compat"
git worktree add "$COMPAT_WORKTREE" HEAD
git -C "$COMPAT_WORKTREE" submodule update --init --recursive Vendor/rhwp
git -C "$COMPAT_WORKTREE/Vendor/rhwp" fetch origin tag "$TAG"
git -C "$COMPAT_WORKTREE/Vendor/rhwp" checkout --detach "$TAG"
cargo build --release --manifest-path "$COMPAT_WORKTREE/RustBridge/Cargo.toml" --target aarch64-apple-darwin
cargo build --release --manifest-path "$COMPAT_WORKTREE/RustBridge/Cargo.toml" --target x86_64-apple-darwin
```

후속 #30의 git tag dependency 전환 후에는 `RustBridge/Cargo.toml`의 `rhwp` dependency가 release tag를 사용해야 한다.

```toml
rhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "<release tag>" }
```

이 단계에서 core API 누락, signature 변경, feature 누락으로 RustBridge가 빌드되지 않으면 `missing core API` 또는 별도 build failure로 기록한다.

### 5. FFI symbol diff 확인

```bash
./scripts/build-rust-macos.sh
diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
```

기대 결과:

- 기존 C ABI symbol set 유지
- `RhwpPageSize.width_pt`, `RhwpPageSize.height_pt` 유지
- symbol 추가/삭제가 있으면 Swift 영향 분석과 함께 별도 변경으로 다룸

### 6. lock 정합성 확인

release tag dependency 전환 후에는 다음 항목이 서로 일치해야 한다.

- `RustBridge/Cargo.toml`의 repo + tag
- `RustBridge/Cargo.lock`의 `rhwp` source repo + tag + commit hash
- `rhwp-core.lock`의 `rhwp_repo`
- `rhwp-core.lock`의 `rhwp_release_tag`
- `rhwp-core.lock`의 `rhwp_commit`

불일치하면 `Cargo.lock mismatch`로 기록한다.

### 7. artifact hash/size 확인

```bash
./scripts/build-rust-macos.sh --verify-lock
```

불일치하면 `artifact hash mismatch`로 기록한다. 의도한 core 또는 ABI 변경이라면 `--update-lock`으로 lock을 갱신하되, 그 전후의 tag, commit, generated header, universal staticlib 변경 이유를 단계 보고서에 남긴다.

### 8. render smoke 확인

```bash
./scripts/validate-stage3-render.sh
```

기본 샘플은 앱 저장소 루트의 `samples/`를 사용한다. render smoke는 최소한 다음을 확인해야 한다.

- 첫 페이지 render tree decode 성공
- page size가 0이 아님
- image node가 있는 문서에서 `rhwp_image_data` 조회가 실패하지 않음
- HostApp/Quick Look/Thumbnail의 기준 경로인 native render tree 렌더가 유지됨

실패하면 `render smoke failure`로 기록한다.

## 실패 유형

| 실패 유형 | 의미 | 대표 증상 | 처리 |
|------|------|------|------|
| `missing core API` | RustBridge가 요구하는 core API가 target release에 없다. | `no method named build_page_render_tree`, `no method named get_bin_data` | #30 진행 금지. API가 포함된 upstream release를 기다리거나 core release를 먼저 준비한다. |
| `Cargo.lock mismatch` | Cargo가 해석한 git dependency commit과 `rhwp-core.lock` 기준이 다르다. | `Cargo.lock` source hash와 `rhwp-core.lock.rhwp_commit` 불일치 | Cargo.lock/rhwp-core.lock 갱신 순서를 보정한다. |
| `artifact hash mismatch` | 현재 빌드 산출물과 `rhwp-core.lock` artifact hash/size가 다르다. | `./scripts/build-rust-macos.sh --verify-lock` 실패 | 의도한 변경이면 `--update-lock`, 아니면 산출물 재생성/rollback을 검토한다. |
| `FFI symbol diff` | generated C ABI symbol set이 기대값과 다르다. | `diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt` 실패 | Swift 영향 분석과 ABI 의도성 확인 전 merge 금지. |
| `render smoke failure` | build는 되지만 native render tree 렌더 결과가 깨진다. | decode 실패, page size 0, 이미지 조회 실패, smoke script 실패 | render tree schema/Swift renderer/core output을 분리 조사한다. |

`release lookup failure`는 네트워크나 GitHub release 조회 문제로, target release 자체의 compatibility 실패와 구분한다.

## #30 unblock checklist

Issue #30은 다음 조건을 모두 만족할 때만 진행한다.

- [ ] `edwardkim/rhwp` target release tag와 release URL을 확인했다.
- [ ] target release tag의 resolved commit을 `^{commit}` 기준으로 확인했다.
- [ ] target release가 `DocumentCore::build_page_render_tree`를 포함한다.
- [ ] target release가 `DocumentCore::get_bin_data`를 포함한다.
- [ ] target release가 `DocumentCore::render_page_svg_native`를 포함한다.
- [ ] target release가 `DocumentCore::get_page_info_native`를 포함한다.
- [ ] target release가 `rhwp::parser::extract_thumbnail_only`를 포함한다.
- [ ] `RustBridge` arm64 build가 통과한다.
- [ ] `RustBridge` x86_64 build가 통과한다.
- [ ] generated FFI symbol set이 `rhwp-ffi-symbols.txt`와 일치하거나, ABI 변경 계획이 별도로 승인되었다.
- [ ] render smoke가 앱 저장소 루트 `samples/` 기준으로 통과한다.
- [ ] `Cargo.lock`과 `rhwp-core.lock`의 repo, release tag, resolved commit 정합성 검증 방법이 준비되어 있다.
- [ ] `rhwp-core.lock`에 release tag, resolved commit, artifact hash/size를 기록할 수 있다.
- [ ] native render tree 경로가 HostApp, Quick Look, Thumbnail의 기준 경로로 유지된다.

위 조건 중 하나라도 실패하면 #30은 blocked 상태를 유지한다.

## fallback 경계

`rhwp_render_page_svg`는 ABI에 남아 있지만 제품 기준 경로가 아니다. SVG fallback은 진단 또는 임시 표시 후보로만 사용할 수 있다.

다음 상황은 #30 unblock 조건을 만족한 것으로 보지 않는다.

- native render tree가 실패하지만 SVG가 렌더링되는 경우
- image data API가 없어서 image node를 누락시키는 경우
- render tree schema가 바뀌었지만 Swift decoder 실패를 무시하는 경우

release tag dependency 전환의 목표는 앱 품질을 낮추지 않고 core source를 release tag 기준으로 재현 가능하게 고정하는 것이다.
