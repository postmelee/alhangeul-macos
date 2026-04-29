# Task #95 Stage 1 완료 보고서

## 단계 목적

`rhwp v0.7.8` release tag가 alhangeul-macos의 Stable 기준인 `release tag + resolved commit`으로 사용할 수 있는지 확인하고, 현재 Demo/Preview pin과 문서 stale 표현 보정 대상을 확정한다.

## 산출물

- `mydocs/working/task_m010_95_stage1.md`
  - Stage 1 조사 결과와 Stage 2 진입 조건 정리

이번 단계에서는 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`, generated artifact를 변경하지 않았다.

## 본문 변경 정도 / 본문 무손실 여부

- 신규 단계 보고서 1개만 추가했다.
- 기존 소스, lock, 매뉴얼, 기술 문서 본문은 수정하지 않았다.
- upstream tag 확인을 위해 `/private/tmp/rhwp-task95-v078`에 `v0.7.8` tag를 read-only clone으로 확인했다.

## 조사 결과

현재 앱 저장소 기준:

- `RustBridge/Cargo.toml`은 `edwardkim/rhwp` commit `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d`를 `rev`로 사용한다.
- `rhwp-core.lock`은 `rhwp_ref_kind = "commit"`, `rhwp_release_transition_status = "demo-commit-pin"`, latest checked release `v0.7.7` 상태다.
- `Cargo.lock`의 `rhwp` source도 같은 `e91ecea3174a0da0ad7a1ea495cacc4f8772c31d` commit을 가리킨다.

`v0.7.8` release 기준:

- GitHub release `v0.7.8`는 존재하며 publishedAt은 `2026-04-29T03:09:48Z`다.
- release targetCommitish는 `main`이다.
- `git ls-remote` 기준 annotated tag object는 `6813f3ebc70a9476c4f9dc919ffda63f2a5c467d`다.
- `v0.7.8^{}` resolved commit은 `42cf91b6ba7b50fa1c853c01158a52ef68b45442`다.
- `./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.8`가 이 commit을 stable target으로 확인했다.

Required API 확인:

- `DocumentCore::build_page_render_tree` 존재: `/private/tmp/rhwp-task95-v078/src/document_core/queries/rendering.rs:27`
- `DocumentCore::build_page_layer_tree` 존재: 같은 파일 `:34`
- `DocumentCore::get_bin_data` 존재: 같은 파일 `:50`
- `DocumentCore::render_page_svg_native` 존재: 같은 파일 `:57`
- `DocumentCore::get_page_info_native` 존재: 같은 파일 `:148`
- `rhwp::parser::extract_thumbnail_only` 존재: `/private/tmp/rhwp-task95-v078/src/parser/mod.rs:566`
- `PageLayerTree` 타입과 schema constant 존재: `/private/tmp/rhwp-task95-v078/src/paint/layer_tree.rs:8`
- wasm-facing `getPageLayerTree`도 존재: `/private/tmp/rhwp-task95-v078/src/wasm_api.rs:255`

앱 ABI 범위:

- 현재 `RustBridge/src/lib.rs`는 `rhwp_render_page_tree`에서 `build_page_render_tree(page)` 결과의 `tree.root`를 JSON으로 반환한다.
- `rhwp_image_data`는 1-indexed `bin_data_id`를 0-indexed core `get_bin_data` index로 변환한다.
- 이번 작업은 이 기존 PageRenderTree ABI와 Swift `RenderNode` decoder contract를 유지한다.
- `PageLayerTree`는 `v0.7.8`에 포함되어 있지만, 신규 `rhwp_render_page_layer_tree` ABI 추가와 Swift renderer 전환은 #95 범위 밖이다.

문서 stale 표현 보정 대상:

- `mydocs/tech/project_architecture.md`
  - 현재 lock을 Demo/Preview commit pin이라고 설명하고 `v0.7.7` 기준 Stable blocked라고 말하는 현재 상태 문장
- `mydocs/tech/core_release_compatibility.md`
  - `v0.7.7` missing API와 `e91ecea...` Demo/Preview pin을 현재 기준처럼 설명하는 섹션
  - Stable 전환 후에는 `v0.7.8` tag와 resolved commit 기준으로 보정 필요
- `mydocs/manual/core_dependency_operation_guide.md`
  - 현재 core 기준 문장의 `v0.7.7` Stable blocked 설명

보존 대상:

- `mydocs/plans/task_m010_76.md`
  - #76 수행 시점의 계획 기록이므로 Stage 5에서 현재 상태 문서처럼 갱신하지 않는다.
- `mydocs/working/`, `mydocs/report/`의 #76 단계/최종 보고서
  - 당시 검증 이력으로 보존한다.

## 검증 결과

```bash
$ git status --short
```

결과: 출력 없음. Stage 1 시작 시 working tree는 clean 상태였다.

```bash
$ gh issue view 95 --repo postmelee/alhangeul-macos --json number,title,state,body,labels,milestone,url
```

결과: Issue #95는 `OPEN`, title은 `rhwp v0.7.8 stable tag 승격`, milestone은 `v0.1`로 확인했다.

```bash
$ gh release view v0.7.8 --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url
```

결과:

```text
tagName: v0.7.8
targetCommitish: main
publishedAt: 2026-04-29T03:09:48Z
url: https://github.com/edwardkim/rhwp/releases/tag/v0.7.8
```

```bash
$ gh release view --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url
```

결과: 현재 latest release도 `v0.7.8`로 확인했다.

```bash
$ git ls-remote --tags https://github.com/edwardkim/rhwp.git refs/tags/v0.7.8 refs/tags/v0.7.8^{}
```

결과:

```text
6813f3ebc70a9476c4f9dc919ffda63f2a5c467d refs/tags/v0.7.8
42cf91b6ba7b50fa1c853c01158a52ef68b45442 refs/tags/v0.7.8^{}
```

```bash
$ ./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.8
```

결과:

```text
Checked rhwp core target:
  channel: stable
  tag:     v0.7.8
  commit:  42cf91b6ba7b50fa1c853c01158a52ef68b45442
```

```bash
$ rg -n "build_page_render_tree|get_bin_data|render_page_svg_native|get_page_info_native|extract_thumbnail_only|PageLayerTree|page_layer_tree|build_page_layer_tree" /private/tmp/rhwp-task95-v078 -g '*.rs'
```

결과: required API와 PageLayerTree 관련 symbol이 `v0.7.8` tag source에 존재함을 확인했다.

```bash
$ rg -n "rhwp_render_page_tree|rhwp_image_data|bin_data_id|RenderNode|build_page_render_tree|get_bin_data|PageLayerTree" RustBridge Sources/RhwpCoreBridge Sources/Shared Sources/HostApp Sources/QLExtension Sources/ThumbnailExtension mydocs/tech mydocs/manual
```

결과: 앱의 실제 native rendering path는 `rhwp_render_page_tree`, `rhwp_image_data`, Swift `RenderNode`, `CGTreeRenderer` 기반으로 유지됨을 확인했다.

```bash
$ rg -n "v0\\.7\\.7|v0\\.7\\.8|e91ecea3174a0da0ad7a1ea495cacc4f8772c31d|demo-commit-pin|Stable 전환|Stable.*blocked|latest release" README.md rhwp-core.lock RustBridge mydocs/tech mydocs/manual mydocs/plans/task_m010_76.md
```

결과: 현재 기준 문서의 stale 보정 대상은 `project_architecture.md`, `core_release_compatibility.md`, `core_dependency_operation_guide.md`로 확정했다. #76 계획서는 당시 기록으로 보존한다.

## 잔여 위험

- `v0.7.8` tag compatibility check는 통과했지만, Stage 2에서 실제 `Cargo.toml`/`Cargo.lock`/`rhwp-core.lock` 갱신 후 세 lock 기준이 함께 일치하는지 다시 확인해야 한다.
- Stage 3에서 artifact hash/size가 크게 바뀔 수 있다. 이는 release tag 전환의 정상 결과일 수 있으나 `--verify-lock`으로 반드시 고정해야 한다.
- PageLayerTree API는 tag에 존재하지만 이번 작업에서는 사용하지 않는다. 문서에서 후속 범위를 분리하지 않으면 ABI 확장 작업으로 오해될 수 있다.
- `gh pr view 385`, `gh pr view 419`는 GitHub PR state를 `CLOSED`로 반환하고 mergeCommit은 `null`이었다. 따라서 PR merge 여부 자체보다 `v0.7.8` tag source의 API 존재를 기준 근거로 삼는다.

## 다음 단계 영향

Stage 2는 계획대로 진행 가능하다.

- `./scripts/update-rhwp-core.sh --channel stable --tag v0.7.8` 실행
- `RustBridge/Cargo.toml`을 `tag = "v0.7.8"` 기준으로 갱신
- `RustBridge/Cargo.lock`의 `rhwp` source가 `tag=v0.7.8#42cf91b6ba7b50fa1c853c01158a52ef68b45442` 형태로 resolved 되는지 확인
- `rhwp-core.lock`을 `rhwp_ref_kind = "release-tag"`, `rhwp_release_tag = "v0.7.8"`, `rhwp_commit = "42cf91b6ba7b50fa1c853c01158a52ef68b45442"` 기준으로 갱신
- `demo-commit-pin` 상태값 제거 여부 확인

## 승인 요청

Stage 1 완료를 승인하고 Stage 2 stable tag dependency와 lock provenance skeleton 갱신으로 진행할지 승인 요청한다. 승인 전에는 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`을 변경하지 않는다.
