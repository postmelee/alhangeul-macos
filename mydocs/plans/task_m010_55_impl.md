# Issue #55 구현 계획서

## 작업명

release tag dependency 전환을 위한 core API compatibility와 update architecture 정리

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_55.md`를 기준으로 진행한다.
- 이번 작업은 release tag dependency 전환 가능 여부를 판단하는 기준과 운영 구조를 문서화하는 작업이다.
- `Vendor/rhwp` submodule 제거, `RustBridge/Cargo.toml` dependency 전환, `Cargo.lock` source 전환은 후속 Issue #30 범위로 남긴다.
- 최신 release tag 정보는 구현 단계에서 다시 확인하고, 확인 일자와 resolved commit을 문서에 남긴다.
- native render tree 경로를 기준 경로로 둔다. SVG fallback은 진단 또는 임시 표시 후보로만 설명한다.
- Swift 계층은 Rust core 내부 API가 아니라 `RustBridge`의 C ABI contract만 의존한다는 경계를 유지한다.
- 스크립트 변경은 문서화만으로 후속 작업자가 gate를 실행할 수 없는 경우에 한해 최소 보강한다.

## Stage 1: 현재 core API 사용 지점과 운영 기준 조사

대상:

- `RustBridge/src/lib.rs`
- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `Sources/RhwpCoreBridge/`
- `Sources/Shared/`
- `scripts/build-rust-macos.sh`
- `scripts/update-rhwp-core.sh`
- `rhwp-core.lock`
- `mydocs/manual/core_submodule_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/tech/project_architecture.md`
- GitHub Issue #30, #54, #55 본문

작업:

- `RustBridge`가 직접 호출하는 `DocumentCore`와 parser API 목록을 조사한다.
- Swift bridge가 실제로 의존하는 C ABI surface를 API contract 후보로 분리한다.
- `rhwp-core.lock`, `Cargo.lock`, update/build script가 현재 어떤 provenance와 검증 기준을 사용하는지 확인한다.
- 최신 release tag와 resolved commit 확인 방법을 정리한다.
- Stage 2 이후 문서에 넣을 compatibility gate 항목과 실패 유형을 확정한다.

산출물:

- `mydocs/working/task_m010_55_stage1.md`

검증:

```bash
rg -n "build_page_render_tree|get_bin_data|render_page_svg_native|get_page_info_native|extract_thumbnail_only|DocumentCore|rhwp_" \
  RustBridge Sources scripts mydocs/manual mydocs/tech
rg -n "release tag|resolved commit|Cargo.lock|rhwp-core.lock|compatibility gate|render smoke|v0\\.7\\.3" \
  rhwp-core.lock RustBridge scripts mydocs
git diff --check -- mydocs/plans/task_m010_55_impl.md
```

완료 조건:

- core API 사용 목록과 C ABI contract 후보가 단계 보고서에 정리되어 있다.
- 현재 release tag 전환 실패 원인이 API 단위로 분리되어 있다.
- Stage 2~4에서 수정할 문서와 스크립트 보강 필요 여부가 확정되어 있다.

## Stage 2: core release compatibility 문서 작성

대상:

- `mydocs/tech/core_release_compatibility.md`

작업:

- release tag dependency 전환의 안정 기준을 `release tag + resolved commit`으로 정의한다.
- 현재 `RustBridge`가 요구하는 core API contract를 문서화한다.
- `v0.7.3` resolved commit에서 불충분한 API와 실패 증상을 기록한다.
- release tag compatibility gate를 절차형 체크리스트로 작성한다.
- 실패 유형을 다음 기준으로 분리한다.
  - `missing core API`
  - `Cargo.lock mismatch`
  - `artifact hash mismatch`
  - `FFI symbol diff`
  - `render smoke failure`
- #30 unblock checklist를 문서 하단에 둔다.

산출물:

- `mydocs/tech/core_release_compatibility.md`
- `mydocs/working/task_m010_55_stage2.md`

검증:

```bash
git diff --check -- mydocs/tech/core_release_compatibility.md mydocs/working/task_m010_55_stage2.md
rg -n "build_page_render_tree|get_bin_data|render_page_svg_native|get_page_info_native|extract_thumbnail_only|release tag|resolved commit|unblock" \
  mydocs/tech/core_release_compatibility.md
```

완료 조건:

- 후속 #30 수행자가 target release를 선택하기 전에 확인할 gate가 독립 문서로 존재한다.
- branch나 floating ref를 안정 기준으로 쓰지 않는다는 원칙이 명확하다.
- native render tree 기준 경로와 fallback 후보 경계가 구분되어 있다.

## Stage 3: core 운영 매뉴얼과 build/run 문서 보강

대상:

- `mydocs/manual/core_submodule_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
- 필요 시 `mydocs/tech/project_architecture.md`

작업:

- core 운영 매뉴얼에 release tag compatibility gate 문서 링크와 적용 시점을 추가한다.
- release tag 전환 전 submodule 임시 운용 절차와 release tag 전환 후 기준을 구분한다.
- build/run 문서의 최소 검증 기준에 lock verify, no-AppKit check, render smoke와 compatibility 문서 참조를 맞춘다.
- architecture 문서가 `RustBridge`를 유일한 core adapter로 설명하는지 확인하고 부족한 경우 보강한다.

산출물:

- `mydocs/working/task_m010_55_stage3.md`

검증:

```bash
git diff --check -- mydocs/manual/core_submodule_operation_guide.md mydocs/manual/build_run_guide.md mydocs/tech/project_architecture.md mydocs/working/task_m010_55_stage3.md
rg -n "core_release_compatibility|release tag|resolved commit|RustBridge|C ABI|render smoke" \
  mydocs/manual/core_submodule_operation_guide.md mydocs/manual/build_run_guide.md mydocs/tech/project_architecture.md
```

완료 조건:

- 기존 운영 매뉴얼에서 release tag 전환 가능 여부 판단 문서로 자연스럽게 연결된다.
- 현재 submodule 운용과 후속 release tag dependency 전환 기준이 혼동되지 않는다.
- Swift/macOS 계층의 core 의존 경계가 RustBridge C ABI 중심으로 유지된다.

## Stage 4: update architecture와 #30 unblock 기준 정리

대상:

- `scripts/update-rhwp-core.sh`
- `scripts/build-rust-macos.sh`
- `mydocs/tech/core_release_compatibility.md`
- `mydocs/manual/core_submodule_operation_guide.md`
- 필요 시 GitHub Issue #30 본문

작업:

- update script가 후속 #30에서 가져야 할 입력, 검증 순서, 실패 메시지 구조를 정리한다.
- `rhwp-core.lock`에 release tag, resolved commit, artifact hash/size를 기록해야 하는 기준을 명확히 한다.
- `Cargo.lock`과 `rhwp-core.lock` resolved commit 정합성 검증 기준을 문서화한다.
- 문서만으로 부족한 최소 안내 메시지 또는 dry-run 검증 옵션이 필요하면 script에 좁게 반영한다.
- 필요 시 Issue #30 본문에 #55 산출 문서와 unblock checklist를 참조하도록 보정한다.

산출물:

- `mydocs/working/task_m010_55_stage4.md`

검증:

```bash
git diff --check
bash -n scripts/update-rhwp-core.sh
bash -n scripts/build-rust-macos.sh
rg -n "missing core API|Cargo.lock mismatch|artifact hash mismatch|FFI symbol diff|render smoke failure|release tag|resolved commit" \
  scripts mydocs/tech/core_release_compatibility.md mydocs/manual/core_submodule_operation_guide.md
```

완료 조건:

- update architecture가 후속 구현 가능한 수준으로 정리되어 있다.
- 이번 작업에서 실제 dependency source 전환이 발생하지 않는다.
- #30 시작 가능 조건과 blocked 조건이 checklist로 확인 가능하다.

## Stage 5: 전체 검증과 최종 보고

대상:

- 전체 변경 파일
- `mydocs/orders/20260426.md`
- `mydocs/report/task_m010_55_report.md`

작업:

- 전체 문서와 스크립트 diff check를 수행한다.
- lock verify, no-AppKit check 등 현재 변경 범위에서 의미 있는 검증을 수행한다.
- script 변경이 있었다면 `bash -n`과 가능한 경우 `shellcheck`를 수행한다.
- release tag, resolved commit, API contract, #30 unblock checklist 검색 게이트를 수행한다.
- 오늘할일 상태를 완료로 갱신한다.
- 최종 결과 보고서를 작성한다.

산출물:

- `mydocs/working/task_m010_55_stage5.md`
- `mydocs/report/task_m010_55_report.md`

검증:

```bash
git diff --check
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
bash -n scripts/update-rhwp-core.sh
bash -n scripts/build-rust-macos.sh
if command -v shellcheck >/dev/null; then shellcheck scripts/update-rhwp-core.sh scripts/build-rust-macos.sh; else echo "shellcheck not installed"; fi
rg -n "build_page_render_tree|get_bin_data|render_page_svg_native|get_page_info_native|extract_thumbnail_only" \
  RustBridge Sources scripts mydocs
rg -n "release tag|resolved commit|Cargo.lock|rhwp-core.lock|compatibility gate|render smoke|unblock" \
  mydocs scripts rhwp-core.lock RustBridge
git status --short
```

완료 조건:

- #55 산출 문서가 #30의 release tag dependency 전환 판단 기준으로 사용 가능하다.
- 검증 결과와 미실행 사유가 최종 보고서에 기록되어 있다.
- 오늘할일이 완료 상태로 갱신되어 있다.
- PR 게시 전 브랜치에 미커밋 변경이 없다.

## 승인 요청 사항

이 구현 계획서 기준으로 Stage 1 조사를 진행할지 승인 요청한다. 승인 전에는 `RustBridge`, 기술 문서, 매뉴얼, 스크립트 변경을 진행하지 않는다.
