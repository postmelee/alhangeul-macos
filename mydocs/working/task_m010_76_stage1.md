# Task #76 Stage 1 완료 보고서

## 단계 목적

현재 alhangeul-macos의 rhwp core pin, upstream PR #385 merge 상태, latest release compatibility, Swift/native bridge contract를 재확인한다. Stage 2에서 core pin을 갱신할 수 있는지와 Stable release tag 전환이 가능한지를 분리해 판단한다.

## 산출물

- `mydocs/working/task_m010_76_stage1.md`
  - Stage 1 조사 결과와 검증 출력 요약을 기록했다.

이번 단계는 조사 단계이므로 `RustBridge`, lock, generated framework, core compatibility 문서는 변경하지 않았다.

## 조사 결과

현재 앱 저장소의 core pin은 기존 Demo/Preview commit이다.

```text
RustBridge/Cargo.toml:
rhwp = { git = "https://github.com/edwardkim/rhwp.git", rev = "1e9d78a1d40c71779d81c6ec6870cd301d912626" }

RustBridge/Cargo.lock:
source = "git+https://github.com/edwardkim/rhwp.git?rev=1e9d78a1d40c71779d81c6ec6870cd301d912626#1e9d78a1d40c71779d81c6ec6870cd301d912626"

rhwp-core.lock:
rhwp_ref_kind = "commit"
rhwp_commit = "1e9d78a1d40c71779d81c6ec6870cd301d912626"
rhwp_release_transition_status = "demo-commit-pin"
rhwp_latest_checked_release_tag = "v0.7.6"
```

upstream 상태는 다음으로 확인했다.

- PR #385: `CLOSED`, base `devel`, head `feature/issue-363-native-render-tree-api`
- PR #385 처리: maintainer가 cherry-pick merge 완료와 alhangeul-macos use case 검증 결과 반영 요청을 남김
- Issue #363: `CLOSED`, `2026-04-27T21:21:34Z` close
- latest release: `v0.7.7`, target `main`, publishedAt `2026-04-27T04:21:36Z`
- `v0.7.7` resolved commit: `033617e23847982135c02091a62f55031a3817b5`

upstream merge commit `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`은 Demo/Preview target으로 사용할 수 있다.

```text
Checked rhwp core target:
  channel: demo
  rev:     e91ecea3174a0da0ad7a1ea495cacc4f8772c31d
  commit:  e91ecea3174a0da0ad7a1ea495cacc4f8772c31d
```

Stable release tag 전환은 여전히 blocked다. latest release `v0.7.7`에서 required API 확인은 다음 결과로 실패했다.

```text
ERROR: missing core API: build_page_render_tree
ERROR: missing core API: target 033617e23847982135c02091a62f55031a3817b5 does not satisfy RustBridge requirements
```

## Native Bridge Contract

`RustBridge/src/lib.rs` 기준으로 현재 C ABI contract는 다음과 같다.

- `rhwp_render_page_tree`
  - `DocumentCore::build_page_render_tree(page)` 호출
  - `tree.root`를 `serde_json::to_string`으로 JSON string 변환
  - Swift는 envelope 없이 top-level `RenderNode`로 decode
- `rhwp_image_data`
  - C ABI 입력 `bin_data_id`는 1-indexed
  - Rust bridge 내부에서 `(bin_data_id - 1) as usize`로 변환
  - `DocumentCore::get_bin_data(idx)` 결과를 borrowed byte pointer와 길이로 반환
  - Swift는 즉시 `Data(bytes:count:)`로 복사

Swift decoder contract는 `Sources/RhwpCoreBridge/RenderTree.swift`와 `RhwpDocument.swift`에서 확인했다.

- root object는 `RenderNode`
- 필수 공통 필드: `id`, `node_type`, `bbox`, `children`, `dirty`, `visible`
- `node_type`은 serde externally tagged enum 형식
- `ImageNode`는 `bin_data_id`를 `binDataId`로 decode
- `RhwpDocument.imageData(binDataId:)`는 1-indexed id를 그대로 `rhwp_image_data`에 전달

## 검증 결과

```bash
git status --short
```

결과: 출력 없음. Stage 1 시작 전 working tree는 clean.

```bash
gh pr view 385 --repo edwardkim/rhwp --json state,baseRefName,headRefName,comments,commits,url
```

결과: PR #385는 `CLOSED`, base `devel`, head `feature/issue-363-native-render-tree-api`. maintainer comment에서 cherry-pick merge 완료, 신규 테스트 2개 추가 통과, native bridge API release contract 노출, alhangeul-macos 검증 결과 반영 요청을 확인했다.

```bash
gh issue view 363 --repo edwardkim/rhwp --json state,closedAt,comments,url
```

결과: Issue #363은 `CLOSED`, closedAt `2026-04-27T21:21:34Z`. PR #385 merge로 처리 완료 comment 확인.

```bash
gh release view --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url
```

결과: latest release는 `v0.7.7`, target `main`, publishedAt `2026-04-27T04:21:36Z`.

```bash
git ls-remote --tags https://github.com/edwardkim/rhwp.git refs/tags/v0.7.7 refs/tags/v0.7.7^{}
```

결과:

```text
033617e23847982135c02091a62f55031a3817b5	refs/tags/v0.7.7
```

```bash
./scripts/update-rhwp-core.sh --check --channel demo --rev e91ecea3174a0da0ad7a1ea495cacc4f8772c31d
```

결과: 통과. target commit은 `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`.

```bash
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.7
```

결과: `missing core API: build_page_render_tree`로 실패. 이는 Stage 1에서 기대한 Stable blocked 확인 결과다.

```bash
rg -n "rhwp_render_page_tree|rhwp_image_data|bin_data_id|RenderNode|build_page_render_tree|get_bin_data" \
  RustBridge Sources/RhwpCoreBridge mydocs/tech mydocs/manual
```

결과: `RustBridge/src/lib.rs`, `Sources/RhwpCoreBridge/RhwpDocument.swift`, `Sources/RhwpCoreBridge/RenderTree.swift`, `mydocs/tech/core_release_compatibility.md`, `mydocs/tech/project_architecture.md`, `mydocs/manual/core_dependency_operation_guide.md`에서 관련 contract 확인.

## 잔여 위험

- `e91ecea`는 현재 pin보다 upstream 변경 범위가 더 넓으므로 Stage 2 이후 실제 build/render smoke에서 회귀 여부를 확인해야 한다.
- latest release `v0.7.7`은 `build_page_render_tree` 누락으로 Stable 전환이 불가능하다. Stage 5 문서 보정에서 기존 `v0.7.6` 기준 문구를 `v0.7.7` 기준으로 갱신해야 한다.
- render tree JSON에는 schema version field가 없으므로, Stage 4에서 Swift decoder smoke가 실제 호환성 판단 기준이다.

## 다음 단계 영향

Stage 2는 Demo/Preview core pin을 `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`로 갱신하는 방향으로 진행할 수 있다. Stable release tag 전환은 이번 작업 범위에서 제외하고, `missing core API` blocked 상태를 유지한다.

## 승인 요청

Stage 1 조사 결과를 승인하고 Stage 2: Demo/Preview core pin과 lock provenance 갱신으로 진행할지 승인 요청한다.
