# rhwp Core Release Compatibility 기준

## 목적

이 문서는 `RustBridge`의 `edwardkim/rhwp` git dependency를 갱신할 때 확인해야 하는 core API contract와 compatibility gate를 정의한다.

정식 릴리즈의 안정 기준은 release tag + resolved commit이다. 다만 Demo/Preview 배포는 필요한 API가 이미 포함된 resolved commit을 `rev`로 고정하는 commit-pinned git dependency를 허용한다. `main`, `devel` 같은 branch나 floating ref는 필요한 API가 포함된 commit을 찾는 참고 출처일 뿐, 배포 기준으로 사용하지 않는다.

## 안정 기준

앱 저장소의 Stable core 안정 기준은 다음 둘을 함께 고정하는 것이다.

- `release tag`: GitHub release tag 이름. 예: `v0.7.6`
- `resolved commit`: tag가 가리키는 실제 commit SHA. annotated tag인 경우 tag object가 아니라 `^{commit}`으로 해석한 commit이다.

Stable release tag 전환 이후 `rhwp-core.lock`은 최소한 다음 의미를 가져야 한다.

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

Demo/Preview 배포에서 아직 필요한 API가 upstream release tag에 포함되지 않았으면 다음처럼 commit-pinned 기준을 사용한다.

```toml
lock_version = 2
rhwp_repo = "https://github.com/edwardkim/rhwp.git"
rhwp_ref_kind = "commit"
rhwp_commit = "<resolved commit>"
rhwp_release_transition_status = "demo-commit-pin"
rhwp_latest_checked_release_tag = "<latest checked release tag>"
rhwp_latest_checked_release_commit = "<latest checked release resolved commit>"
ffi_symbols_file = "rhwp-ffi-symbols.txt"
```

`Cargo.lock`은 `RustBridge/Cargo.toml`의 `rhwp` git dependency를 해석한 실제 source와 commit을 담는다. 현재 기준에서는 `Cargo.lock`의 `rhwp` package source가 `rhwp-core.lock`의 repo, ref kind, commit과 일치해야 한다. Stable 전환에서는 release tag와 resolved commit도 함께 일치해야 한다.

## 배포 채널 기준

| 채널 | core 기준 | 허용 dependency | 배포 의미 |
|------|------|------|------|
| Demo/Preview | API가 포함된 resolved commit | `git` + `rev` | 기능 검증용 공개 배포. GitHub Release는 prerelease로 게시하고 정식 안정 기준으로 표시하지 않는다. |
| Stable | API가 포함된 release tag + resolved commit | `git` + `tag` | 일반 사용자 대상 정식 배포. compatibility gate 전체를 통과해야 한다. |

Demo/Preview도 branch dependency는 사용하지 않는다. 반드시 commit SHA를 `rev`로 고정하고, `Cargo.lock`, `rhwp-core.lock`, 산출물 hash/size를 함께 남긴다.

현재 Demo/Preview 후보 dependency 형식:

```toml
rhwp = { git = "https://github.com/edwardkim/rhwp.git", rev = "1e9d78a1d40c71779d81c6ec6870cd301d912626" }
```

## 현재 release 상태

2026-04-27 확인 기준 최신 release는 다음이다.

```text
release tag: v0.7.6
target branch: main
publishedAt: 2026-04-26T09:35:00Z
resolved commit: 92c5b6b79d22f6c784b3b317551c66466b3b63a5
```

`v0.7.6`에는 다음 API가 있다.

- `DocumentCore::render_page_svg_native`
- `DocumentCore::get_page_info_native`
- `rhwp::parser::extract_thumbnail_only`

`v0.7.6`에는 다음 API가 없다.

- `DocumentCore::build_page_render_tree`
- `DocumentCore::get_bin_data`

따라서 현재 `v0.7.6`은 native render tree 경로를 유지하는 앱 기준을 충족하지 못한다. 실패 유형은 `missing core API`다.

현재 lock commit `1e9d78a1d40c71779d81c6ec6870cd301d912626`에는 `DocumentCore::build_page_render_tree`와 `DocumentCore::get_bin_data`가 포함되어 있으므로 Demo/Preview용 commit-pinned git dependency 후보가 될 수 있다. 이 commit은 release tag 안정 기준이 아니므로 Stable 배포 기준으로 승격하지 않는다.

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

schema 변화가 있는 release는 단순 dependency 갱신으로 처리하지 않는다. schema 변화가 render 결과나 decoder 안정성에 영향을 주면 별도 Swift/Rust bridge 적응 작업으로 분리한다.

## Stable compatibility gate

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
git ls-remote --tags https://github.com/edwardkim/rhwp.git "refs/tags/$TAG" "refs/tags/$TAG^{}"
```

기록할 항목:

- tag object SHA, 있는 경우
- resolved commit SHA

resolved commit은 `rhwp-core.lock`의 `rhwp_commit` 후보가 된다.

### 3. required core API 확인

```bash
TAG="<release tag>"
./scripts/update-rhwp-core.sh --check --channel stable --tag "$TAG"
```

필수 API:

- `DocumentCore::build_page_render_tree`
- `DocumentCore::get_bin_data`
- `DocumentCore::render_page_svg_native`
- `DocumentCore::get_page_info_native`
- `rhwp::parser::extract_thumbnail_only`

`build_page_render_tree` 또는 `get_bin_data`가 없으면 native render tree 기준 경로를 충족하지 못하므로 Stable 전환을 진행하지 않는다.

`--check`는 파일을 바꾸지 않고 upstream ref 조회와 필수 API 확인만 수행한다. 네트워크 실패는 `release lookup failure` 또는 `dependency fetch failure`로 분리한다.

### 4. RustBridge build 확인

release tag 전환은 작업 브랜치 또는 분리 worktree에서 수행한다. build 확인 전 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock` skeleton을 같은 기준으로 갱신해야 한다.

```bash
TAG="<release tag>"
./scripts/update-rhwp-core.sh --channel stable --tag "$TAG"
./scripts/build-rust-macos.sh
```

Stable 기준에서는 `RustBridge/Cargo.toml`의 `rhwp` dependency가 release tag를 사용해야 한다.

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

## Demo/Preview commit gate

Demo/Preview 채널은 release tag를 기다리지 않고 필요한 API가 포함된 resolved commit을 사용할 수 있는 경로다. 단, 다음 조건을 모두 만족해야 한다.

- commit SHA를 `rev`로 명시한다.
- `Cargo.lock`의 `rhwp` source가 해당 commit으로 고정되어 있다.
- `rhwp-core.lock`의 `rhwp_ref_kind`는 `commit`으로 기록한다.
- `rhwp-core.lock`에 latest checked release tag와 해당 release의 resolved commit을 함께 남겨 Stable 전환 대기 상태를 보존한다.
- `build_page_render_tree`, `get_bin_data`, `render_page_svg_native`, `get_page_info_native`, `extract_thumbnail_only` 존재를 확인한다.
- arm64/x86_64 RustBridge build가 통과한다.
- FFI symbol diff, artifact hash/size verify, render smoke가 통과한다.
- GitHub Release는 prerelease로 게시하고 release note에 `unreleased rhwp commit` 기반임을 명시한다.

Demo/Preview를 이유로 `main` 또는 `devel` branch dependency를 사용하지 않는다. commit-pinned Demo/Preview는 재현 가능한 빌드 경로이고, branch dependency는 재현 가능한 배포 경로가 아니다.

## Update script architecture

`scripts/update-rhwp-core.sh`는 core dependency update gate다.

현재 interface:

```bash
# Demo/Preview: 특정 commit으로 고정
./scripts/update-rhwp-core.sh --channel demo --rev <commit-sha>

# Stable: 특정 release tag로 고정
./scripts/update-rhwp-core.sh --channel stable --tag <release-tag>

# 조회/검증만 수행하고 파일을 바꾸지 않음
./scripts/update-rhwp-core.sh --check --channel stable --tag <release-tag>
```

처리 순서:

1. 입력 검증
   - `--channel demo`는 `--rev`만 허용한다.
   - `--channel stable`은 `--tag`만 허용한다.
   - branch 이름, `HEAD`, `origin/devel` 같은 floating ref는 거부한다.
2. upstream ref 확인
   - demo: commit이 `https://github.com/edwardkim/rhwp.git`에서 조회되는지 확인한다.
   - stable: tag와 `tag^{commit}` resolved commit을 확인한다.
3. required core API 확인
   - `build_page_render_tree`
   - `get_bin_data`
   - `render_page_svg_native`
   - `get_page_info_native`
   - `extract_thumbnail_only`
4. `RustBridge/Cargo.toml` dependency 갱신
   - demo: `git` + `rev`
   - stable: `git` + `tag`
5. `Cargo.lock` 갱신
   - `cargo generate-lockfile`
   - 갱신 후 `Cargo.lock`의 source commit을 추출한다.
6. `rhwp-core.lock` skeleton 갱신
   - demo: `rhwp_ref_kind = "commit"`
   - stable: `rhwp_ref_kind = "release-tag"`
   - latest checked release tag/commit은 두 채널 모두 기록한다.
   - artifact hash/size는 빈 값 또는 0으로 두고 `build-rust-macos.sh --update-lock`에서 채운다.
7. RustBridge build와 FFI symbol diff 실행
8. `build-rust-macos.sh --update-lock` 또는 `--verify-lock` 안내

`scripts/build-rust-macos.sh`는 현재 git dependency 기준에서 다음 항목으로 lock을 검증한다.

- `rhwp-core.lock.lock_version = 2`
- `rhwp_ref_kind`가 `commit` 또는 `release-tag` 중 하나
- `RustBridge/Cargo.lock`의 `rhwp` source commit과 `rhwp-core.lock.rhwp_commit` 일치
- Stable이면 `rhwp_release_tag`가 존재하고 `Cargo.toml`의 tag와 일치
- Demo/Preview이면 `rhwp_release_transition_status = "demo-commit-pin"` 또는 이에 준하는 상태값 존재
- `Frameworks/universal/librhwp.a` sha256/size 일치
- `Frameworks/generated_rhwp.h` sha256/size 일치
- generated FFI symbol set과 `rhwp-ffi-symbols.txt` 일치

실패 메시지는 다음 prefix를 사용해 원인을 분리한다.

- `ERROR: release lookup failure`
- `ERROR: missing core API`
- `ERROR: dependency fetch failure`
- `ERROR: Cargo.lock mismatch`
- `ERROR: artifact hash mismatch`
- `ERROR: FFI symbol diff`
- `ERROR: render smoke failure`

이 architecture는 현재 script의 기준이며, 실패 원인은 compatibility failure와 network/dependency fetch failure로 분리해 보고한다.

## 실패 유형

| 실패 유형 | 의미 | 대표 증상 | 처리 |
|------|------|------|------|
| `missing core API` | RustBridge가 요구하는 core API가 target release에 없다. | `no method named build_page_render_tree`, `no method named get_bin_data` | Stable 전환 금지. Demo/Preview는 API가 포함된 별도 commit을 `rev`로 고정할 때만 진행한다. |
| `Cargo.lock mismatch` | Cargo가 해석한 git dependency commit과 `rhwp-core.lock` 기준이 다르다. | `Cargo.lock` source hash와 `rhwp-core.lock.rhwp_commit` 불일치 | Cargo.lock/rhwp-core.lock 갱신 순서를 보정한다. |
| `artifact hash mismatch` | 현재 빌드 산출물과 `rhwp-core.lock` artifact hash/size가 다르다. | `./scripts/build-rust-macos.sh --verify-lock` 실패 | 의도한 변경이면 `--update-lock`, 아니면 산출물 재생성/rollback을 검토한다. |
| `FFI symbol diff` | generated C ABI symbol set이 기대값과 다르다. | `diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt` 실패 | Swift 영향 분석과 ABI 의도성 확인 전 merge 금지. |
| `render smoke failure` | build는 되지만 native render tree 렌더 결과가 깨진다. | decode 실패, page size 0, 이미지 조회 실패, smoke script 실패 | render tree schema/Swift renderer/core output을 분리 조사한다. |

`release lookup failure`는 네트워크나 GitHub release 조회 문제로, target release 자체의 compatibility 실패와 구분한다.

## Core 전환/업데이트 진행 기준

core dependency 전환 또는 업데이트는 두 경로 중 하나로 진행할 수 있다.

Demo/Preview commit-pinned 전환:

- [ ] `edwardkim/rhwp` target commit SHA를 확인했다.
- [ ] target commit이 `DocumentCore::build_page_render_tree`를 포함한다.
- [ ] target commit이 `DocumentCore::get_bin_data`를 포함한다.
- [ ] target commit이 `DocumentCore::render_page_svg_native`를 포함한다.
- [ ] target commit이 `DocumentCore::get_page_info_native`를 포함한다.
- [ ] target commit이 `rhwp::parser::extract_thumbnail_only`를 포함한다.
- [ ] `RustBridge/Cargo.toml`이 `git` + `rev` dependency로 전환된다.
- [ ] fresh checkout에서 별도 core source checkout 없이 build가 통과한다.
- [ ] `Cargo.lock`과 `rhwp-core.lock`의 repo, ref kind, commit 정합성 검증 방법이 준비되어 있다.
- [ ] GitHub Release는 prerelease로 게시하고 Stable release로 표시하지 않는다.

Stable release tag 전환:

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

Stable 조건 중 하나라도 실패하면 Stable 전환은 blocked 상태를 유지한다. Demo/Preview 조건을 만족하면 commit-pinned git dependency 전환으로 진행할 수 있다.

## fallback 경계

`rhwp_render_page_svg`는 ABI에 남아 있지만 제품 기준 경로가 아니다. SVG fallback은 진단 또는 임시 표시 후보로만 사용할 수 있다.

다음 상황은 core dependency 전환 unblock 조건을 만족한 것으로 보지 않는다.

- native render tree가 실패하지만 SVG가 렌더링되는 경우
- image data API가 없어서 image node를 누락시키는 경우
- render tree schema가 바뀌었지만 Swift decoder 실패를 무시하는 경우

git dependency 전환의 목표는 앱 품질을 낮추지 않고 core source를 재현 가능하게 고정하는 것이다. Demo/Preview는 commit 기준, Stable은 release tag + resolved commit 기준을 사용한다.
