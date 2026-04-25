# Task #55 Stage 3 완료 보고서

## 단계 목적

core 운영 매뉴얼, build/run 문서, architecture 문서가 Stage 2 compatibility 문서와 같은 기준을 사용하도록 보강한다. 작업지시자 검토 의견에 따라 Demo/Preview 채널의 commit-pinned git dependency 경로와 Stable release tag 경로를 분리해 문서화한다.

## 산출물

- `mydocs/tech/core_release_compatibility.md`: Demo/Preview commit gate, Stable compatibility gate, #30 진행 기준 보강
- `mydocs/manual/core_submodule_operation_guide.md`: submodule 임시 운용, Demo/Preview, Stable 기준 연결
- `mydocs/manual/build_run_guide.md`: core dependency 모드와 git dependency 전환 후 검증 기준 추가
- `mydocs/tech/project_architecture.md`: core 소유 경계와 FFI surface 보정
- `mydocs/working/task_m010_55_stage3.md`: Stage 3 완료 보고서

변경 규모:

```text
mydocs/manual/build_run_guide.md                | 17 ++++-
mydocs/manual/core_submodule_operation_guide.md | 15 +++--
mydocs/tech/core_release_compatibility.md       | 82 +++++++++++++++++++++----
mydocs/tech/project_architecture.md             | 12 +++-
```

## 본문 변경 정도 / 본문 무손실 여부

기존 문서의 release tag 중심 설명을 Stable 기준으로 좁히고, Demo/Preview 기준을 추가했다. 기존 “branch/floating ref 금지”, “native render tree 기준 경로 유지”, “release tag 전환 대기 상태” 원칙은 유지했다.

`project_architecture.md`에서는 실제 FFI symbol surface에 맞춰 `rhwp_extract_thumbnail`과 `rhwp_free_bytes`를 추가했다. 이는 기존 구현과 generated header 기준을 반영한 보정이다.

## 주요 변경

### Demo/Preview와 Stable 기준 분리

`core_release_compatibility.md`에 배포 채널 기준을 추가했다.

- Demo/Preview: `git` + `rev`, `rhwp_ref_kind = "commit"`
- Stable: `git` + `tag`, `rhwp_ref_kind = "release-tag"`

Demo/Preview는 `1e9d78a1d40c71779d81c6ec6870cd301d912626`처럼 필요한 bridge API가 포함된 resolved commit을 `rev`로 고정하는 경우에만 허용한다. branch dependency는 여전히 배포 기준으로 금지한다.

### #30 진행 기준 보정

Issue #30은 두 경로 중 하나로 진행할 수 있게 정리했다.

- Demo/Preview commit-pinned 전환: `Vendor/rhwp` 제거와 `git` + `rev` dependency 전환
- Stable release tag 전환: release tag가 필요한 API를 포함하고 compatibility gate를 통과한 뒤 `git` + `tag` dependency 전환

현재 `v0.7.3`은 `build_page_render_tree`, `get_bin_data`가 없으므로 Stable 전환은 blocked 상태다. 하지만 현재 lock commit은 두 API를 포함하므로 Demo/Preview 후보가 될 수 있다.

### 운영 문서 연결

`core_submodule_operation_guide.md`와 `build_run_guide.md`에서 `core_release_compatibility.md`를 참조하도록 했다. git dependency 전환 후에는 `.gitmodules`가 아니라 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`의 repo/ref/commit 정합성을 함께 확인해야 한다고 정리했다.

## 검증 결과

diff check:

```text
$ git diff --check -- mydocs/tech/core_release_compatibility.md mydocs/manual/core_submodule_operation_guide.md mydocs/manual/build_run_guide.md mydocs/tech/project_architecture.md mydocs/working/task_m010_55_stage3.md
결과: 통과.
```

검색 게이트:

```text
$ rg -n "core_release_compatibility|Demo/Preview|release tag|resolved commit|RustBridge|C ABI|render smoke|rhwp_ref_kind|git dependency|rev|Stable" mydocs/tech/core_release_compatibility.md mydocs/manual/core_submodule_operation_guide.md mydocs/manual/build_run_guide.md mydocs/tech/project_architecture.md
결과: 네 문서에서 Demo/Preview, Stable, release tag, resolved commit, git dependency, RustBridge/C ABI 기준 확인.
```

기존 차단 문구 검색:

```text
$ rg -n "후속 Issue #30은 이 문서의 gate를 통과한 release tag가 있을 때만|#30은 blocked 상태|릴리즈 기반 git dependency 전환|release tag 전환 전까지의 submodule|#30 진행 금지" mydocs/tech/core_release_compatibility.md mydocs/manual/core_submodule_operation_guide.md mydocs/manual/build_run_guide.md mydocs/tech/project_architecture.md
결과: 해당 문구 없음.
```

라인 수 확인:

```text
$ wc -l mydocs/tech/core_release_compatibility.md mydocs/manual/core_submodule_operation_guide.md mydocs/manual/build_run_guide.md mydocs/tech/project_architecture.md
334 mydocs/tech/core_release_compatibility.md
 71 mydocs/manual/core_submodule_operation_guide.md
213 mydocs/manual/build_run_guide.md
148 mydocs/tech/project_architecture.md
766 total
```

## 잔여 위험

- Stage 3은 문서 기준 보정이며 실제 `RustBridge/Cargo.toml`, `Cargo.lock`, `rhwp-core.lock`, submodule 제거는 수행하지 않았다.
- #30을 Demo/Preview commit-pinned 전환으로 진행하려면 Issue #30 본문과 구현 계획을 새 기준으로 보정해야 한다.
- git dependency 전환 후 첫 build는 네트워크 fetch가 필요하므로 fetch 실패와 compatibility 실패를 분리해 보고해야 한다.

## 다음 단계 영향

Stage 4에서는 update architecture와 #30 unblock 기준을 더 구체화한다. 특히 `scripts/update-rhwp-core.sh`, `scripts/build-rust-macos.sh`가 Demo/Preview commit pin과 Stable release tag 기준을 어떻게 구분해 보고할지 검토해야 한다.

## 승인 요청

Stage 3 문서 보강을 완료했다. Stage 4 update architecture와 #30 기준 정리로 진행할지 승인 요청한다.
