# Task #30 Stage 1 완료 보고서

## 단계 목적

현재 `Vendor/rhwp` submodule, `RustBridge` dependency, `Cargo.lock`, `rhwp-core.lock`, build/update script, 문서 참조 상태를 조사해 git dependency 전환 범위와 Stable/Demo 기준을 확정한다.

## 산출물

- `mydocs/working/task_m010_30_stage1.md`: Stage 1 조사 결과 보고서
- `mydocs/orders/20260426.md`: #30 비고를 Stage 2 승인 대기 상태로 갱신

소스 코드, build script, lock, README, 매뉴얼 본문은 Stage 1에서 변경하지 않았다.

## 조사 결과

현재 submodule과 lock 상태:

- `.gitmodules`는 `Vendor/rhwp` path, `https://github.com/edwardkim/rhwp.git`, `devel` branch를 가리킨다.
- git index에는 `Vendor/rhwp`가 gitlink mode `160000`, commit `1e9d78a1d40c71779d81c6ec6870cd301d912626`로 등록되어 있다.
- `Vendor/rhwp` worktree HEAD도 `1e9d78a1d40c71779d81c6ec6870cd301d912626`이다.
- `git submodule status`는 `Vendor/rhwp (v0.5.0-768-g1e9d78a)`를 표시한다.
- `rhwp-core.lock`도 `rhwp_commit = "1e9d78a1d40c71779d81c6ec6870cd301d912626"`로 같은 commit을 기록한다.

현재 Cargo dependency 상태:

- `RustBridge/Cargo.toml`은 `rhwp = { path = "../Vendor/rhwp" }`를 사용한다.
- `RustBridge/Cargo.lock`의 `rhwp` package는 `version = "0.7.3"`만 기록되고 `source = ...`가 없다. 이는 path dependency라서 Cargo.lock에 remote source와 resolved commit이 남지 않는 현재 상태다.
- git dependency 전환 후에는 `Cargo.lock`의 `rhwp` package source에서 repo, rev/tag query, resolved commit을 추출해 `rhwp-core.lock`과 대조해야 한다.

upstream release 상태:

```text
latest release tag: v0.7.3
target branch: main
publishedAt: 2026-04-19T12:38:52Z
url: https://github.com/edwardkim/rhwp/releases/tag/v0.7.3
tag object: 71492bca7ad719dd4b5ce4f58405e1f297772adf
resolved commit: c2e8a3461de800a02f76127ff4797bade1d4e532
```

required core API 상태:

| 대상 | build_page_render_tree | get_bin_data | render_page_svg_native | get_page_info_native | extract_thumbnail_only | 판단 |
|------|------|------|------|------|------|------|
| latest release `v0.7.3` / `c2e8a3461de800a02f76127ff4797bade1d4e532` | 없음 | 없음 | 있음 | 있음 | 있음 | Stable blocked, `missing core API` |
| Demo 후보 `1e9d78a1d40c71779d81c6ec6870cd301d912626` | 있음 | 있음 | 있음 | 있음 | 있음 | Demo/Preview commit pin 후보 가능 |

active submodule 전제 분류:

- 즉시 제거 또는 재정의 대상:
  - `.gitmodules`
  - `Vendor/rhwp` gitlink
  - `RustBridge/Cargo.toml` path dependency
  - `scripts/build-rust-macos.sh`의 `RHWP_ROOT`, submodule 존재 검사, `current_rhwp_commit`, `git submodule update` 안내
  - `scripts/update-rhwp-core.sh` 전체 구조
- Stage 5 문서 보정 대상:
  - `README.md`의 setup, project structure, core update, troubleshooting, Mermaid architecture
  - `AGENTS.md`의 `rhwp-core.lock` 설명과 core 운영 매뉴얼 링크 문구
  - `mydocs/tech/project_architecture.md`의 `Vendor/rhwp` 소유 경계 설명
  - `mydocs/manual/core_submodule_operation_guide.md`의 문서 목적과 업데이트 절차
  - `mydocs/manual/build_run_guide.md`의 초기 setup과 새 worktree 준비 절차
  - `mydocs/manual/release_distribution_guide.md`의 release 전 `git submodule status Vendor/rhwp` 확인
- 유지 가능한 역사/전환 문맥:
  - `mydocs/tech/task_m010_28_sample_provenance.md`의 샘플 출처 기록
  - 이전 `mydocs/report/`, `mydocs/working/`, 과거 계획서의 완료 이력
  - `mydocs/tech/core_release_compatibility.md`의 전환 전 compatibility 절차는 Stage 5에서 git dependency 기준으로 일부 보정하되, #55 당시 submodule 조사 문맥은 역사로 남길 수 있다.

## 본문 변경 정도 / 본문 무손실 여부

Stage 1은 조사 단계라 제품 소스와 기존 운영 문서 본문을 변경하지 않았다. 새 단계 보고서를 추가하고 오늘할일 비고만 현재 상태에 맞게 갱신했다.

## 검증 결과

작업트리 확인:

```text
$ git status --short --branch
## local/task30
```

submodule과 lock 기준 확인:

```text
$ git ls-files -s Vendor/rhwp .gitmodules
100644 255885c7fec602d5138e33e12fcc0ce667e9d835 0	.gitmodules
160000 1e9d78a1d40c71779d81c6ec6870cd301d912626 0	Vendor/rhwp

$ git -C Vendor/rhwp rev-parse HEAD
1e9d78a1d40c71779d81c6ec6870cd301d912626

$ git submodule status
 1e9d78a1d40c71779d81c6ec6870cd301d912626 Vendor/rhwp (v0.5.0-768-g1e9d78a)
```

upstream release 확인:

```text
$ gh release view --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url
{"publishedAt":"2026-04-19T12:38:52Z","tagName":"v0.7.3","targetCommitish":"main","url":"https://github.com/edwardkim/rhwp/releases/tag/v0.7.3"}

$ git ls-remote https://github.com/edwardkim/rhwp.git refs/tags/v0.7.3 'refs/tags/v0.7.3^{}'
71492bca7ad719dd4b5ce4f58405e1f297772adf	refs/tags/v0.7.3
c2e8a3461de800a02f76127ff4797bade1d4e532	refs/tags/v0.7.3^{}
```

required API 확인:

```text
$ git -C Vendor/rhwp grep -n "build_page_render_tree\\|get_bin_data\\|render_page_svg_native\\|get_page_info_native" v0.7.3 -- src
v0.7.3:src/document_core/queries/rendering.rs:23:    pub fn render_page_svg_native(...)
v0.7.3:src/document_core/queries/rendering.rs:90:    pub fn get_page_info_native(...)

$ git -C Vendor/rhwp grep -n "extract_thumbnail_only" v0.7.3 -- src
v0.7.3:src/parser/mod.rs:534:pub fn extract_thumbnail_only(...)

$ git -C Vendor/rhwp grep -n "build_page_render_tree\\|get_bin_data\\|render_page_svg_native\\|get_page_info_native" 1e9d78a1d40c71779d81c6ec6870cd301d912626 -- src
1e9d78a...:src/document_core/queries/rendering.rs:24:    pub fn build_page_render_tree(...)
1e9d78a...:src/document_core/queries/rendering.rs:31:    pub fn get_bin_data(...)
1e9d78a...:src/document_core/queries/rendering.rs:35:    pub fn render_page_svg_native(...)
1e9d78a...:src/document_core/queries/rendering.rs:102:    pub fn get_page_info_native(...)

$ git -C Vendor/rhwp grep -n "extract_thumbnail_only" 1e9d78a1d40c71779d81c6ec6870cd301d912626 -- src
1e9d78a...:src/parser/mod.rs:549:pub fn extract_thumbnail_only(...)
```

문서와 script 참조 검색:

```text
$ rg -n --glob '!RustBridge/target/**' "Vendor/rhwp|git submodule|submodule" README.md AGENTS.md scripts RustBridge project.yml mydocs/manual mydocs/tech mydocs/plans/task_m010_30.md mydocs/plans/task_m010_30_impl.md
결과: active runtime 전제는 scripts, RustBridge/Cargo.toml, README, AGENTS, project_architecture, build/run, release, core operation 문서에 남아 있음. 과거 provenance와 전환 설명 문맥도 함께 확인됨.
```

Stage 1 보고서 작성 후 검증:

```text
$ git diff --check -- mydocs/orders/20260426.md mydocs/working/task_m010_30_stage1.md
결과: 통과
```

## 잔여 위험

- `edwardkim/rhwp` 최신 release는 Stage 2 또는 Stage 3 진행 시점에 바뀔 수 있다. Stable 판단 직전에는 release 조회와 resolved commit 확인을 다시 수행해야 한다.
- `Cargo.lock`의 git dependency source 문자열 parsing은 `rev`와 `tag` 모두를 다뤄야 한다. Stage 2에서 실제 Cargo.lock 예시를 만든 뒤 parser를 검증해야 한다.
- submodule 제거 뒤 required API 확인은 더 이상 `git -C Vendor/rhwp grep`를 사용할 수 없다. Stage 2 update gate에서 remote ref를 임시 clone/fetch하거나 Cargo checkout 위치를 활용하는 방식을 정해야 한다.
- `README.md`와 매뉴얼의 submodule 문구가 여러 위치에 분산되어 있다. Stage 5에서 active guide와 역사 기록을 구분하지 않으면 과거 보고서까지 불필요하게 수정할 위험이 있다.

## 다음 단계 영향

Stage 2는 script 중심으로 진행한다. 핵심은 `scripts/update-rhwp-core.sh`를 dependency update gate로 재정의하고, `scripts/build-rust-macos.sh`의 commit 검증을 `Vendor/rhwp` HEAD가 아니라 `Cargo.lock` source와 `rhwp-core.lock` 대조로 바꾸는 것이다.

Stage 3에서는 Stage 2에서 만든 gate 또는 그 설계 기준을 사용해 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `.gitmodules`, `Vendor/rhwp` gitlink, `rhwp-core.lock`을 함께 전환한다.

## 승인 요청

Stage 1 조사를 완료했다. 이 보고서 기준으로 Stage 2 `git dependency update gate와 lock 정합성 설계 구현`을 진행할지 승인 요청한다.
