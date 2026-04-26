# Issue #30 구현 계획서

## 작업명

hwpql 장점 반영 3: RustBridge를 git-rev dependency로 전환하고 Vendor/rhwp submodule 제거

## 구현 원칙

- 승인된 수행계획서 `mydocs/plans/task_m010_30.md`를 기준으로 진행한다.
- 이번 작업의 기본 전환 경로는 Demo/Preview commit pin이다. Stable release tag 전환은 required core API가 포함된 release tag가 compatibility gate를 통과한 경우에만 완료로 표시한다.
- `main`, `devel` 같은 branch나 floating ref는 배포 기준으로 사용하지 않는다. Demo/Preview는 `rev`, Stable은 `tag + resolved commit`을 기준으로 한다.
- native render tree 경로와 현행 C ABI symbol set을 유지한다. Swift renderer 구조 변경은 이번 범위에 포함하지 않는다.
- `Cargo.lock`은 Cargo가 해석한 dependency source의 진실 원천이고, `rhwp-core.lock`은 앱 저장소 관점의 core provenance와 산출물 hash/size 기록으로 유지한다.
- `Cargo.lock`과 `rhwp-core.lock`의 repo, ref kind, resolved commit 불일치는 명확한 오류로 중단한다.
- `Vendor/rhwp` 제거 뒤에도 fresh checkout에서 `./scripts/build-rust-macos.sh`가 core dependency를 fetch해 build할 수 있어야 한다.
- 네트워크 fetch 실패는 `dependency fetch failure` 또는 `release lookup failure`로 분리해 보고하고, core API compatibility 실패로 섞지 않는다.

## Stage 1: 현재 submodule, dependency, lock, release 기준 조사

대상:

- `.gitmodules`
- `Vendor/rhwp` gitlink
- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `rhwp-core.lock`
- `scripts/build-rust-macos.sh`
- `scripts/update-rhwp-core.sh`
- `mydocs/tech/core_release_compatibility.md`
- `README.md`, `mydocs/manual/`, `mydocs/tech/project_architecture.md`, `AGENTS.md`

작업:

- 현재 submodule pointer와 `rhwp-core.lock.rhwp_commit`의 일치 여부를 기록한다.
- 구현 시점의 `edwardkim/rhwp` 최신 release tag, target branch, publishedAt, resolved commit을 다시 확인한다.
- Demo/Preview 후보 commit `1e9d78a1d40c71779d81c6ec6870cd301d912626`이 required core API를 포함하는지 확인한다.
- 현재 `Cargo.lock`의 `rhwp` package source 형식과 git dependency 전환 후 예상 source 형식을 비교한다.
- `Vendor/rhwp`, `git submodule`, `submodule` 참조를 active runtime 전제, 역사 기록, legacy 설명으로 분류한다.
- Stage 2 이후 script와 문서에서 제거해야 할 submodule 전제를 확정한다.

산출물:

- `mydocs/working/task_m010_30_stage1.md`

검증:

```bash
git status --short
git ls-files -s Vendor/rhwp .gitmodules
git -C Vendor/rhwp rev-parse HEAD
gh release view --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url
rg -n "build_page_render_tree|get_bin_data|render_page_svg_native|get_page_info_native|extract_thumbnail_only" \
  RustBridge Vendor/rhwp/src mydocs/tech/core_release_compatibility.md
rg -n "Vendor/rhwp|git submodule|submodule" README.md scripts mydocs AGENTS.md RustBridge project.yml
git diff --check -- mydocs/working/task_m010_30_stage1.md
```

완료 조건:

- target commit, latest checked release, required API 상태가 단계 보고서에 기록되어 있다.
- submodule 제거에 영향을 받는 script와 문서 참조가 분류되어 있다.
- Stage 2~5에서 변경할 파일과 제외할 역사 기록 기준이 확정되어 있다.

## Stage 2: git dependency update gate와 lock 정합성 설계 구현

대상:

- `scripts/update-rhwp-core.sh`
- `scripts/build-rust-macos.sh`
- `rhwp-core.lock`
- 필요 시 script 보조 함수 문서화

작업:

- `scripts/update-rhwp-core.sh`를 submodule update script에서 git dependency update gate로 재정의한다.
- 지원 interface를 다음으로 고정한다.

```bash
./scripts/update-rhwp-core.sh --channel demo --rev <commit-sha>
./scripts/update-rhwp-core.sh --channel stable --tag <release-tag>
./scripts/update-rhwp-core.sh --check --channel stable --tag <release-tag>
```

- demo channel은 full SHA `rev`만 허용하고, `rhwp_ref_kind = "commit"`과 `rhwp_release_transition_status = "demo-commit-pin"`을 기록하게 한다.
- stable channel은 release tag와 resolved commit을 함께 확인하고, required core API가 없으면 `missing core API`로 중단하게 한다.
- `Cargo.lock`의 `rhwp` package source에서 repo, query ref, resolved commit을 추출하는 검증 기준을 구현한다.
- `rhwp-core.lock` v2에서 branch 기준 필드를 제거하거나 legacy로 남기지 않는 방향을 확정한다.
- `build-rust-macos.sh`의 `current_rhwp_commit`류 submodule 의존 함수는 Cargo.lock 기반 검증으로 대체할 수 있게 준비한다.

산출물:

- `mydocs/working/task_m010_30_stage2.md`

검증:

```bash
bash -n scripts/update-rhwp-core.sh
bash -n scripts/build-rust-macos.sh
if command -v shellcheck >/dev/null; then shellcheck scripts/update-rhwp-core.sh scripts/build-rust-macos.sh; else echo "shellcheck not installed"; fi
rg -n "channel demo|channel stable|demo-commit-pin|missing core API|Cargo.lock mismatch|artifact hash mismatch|FFI symbol diff|dependency fetch failure|release lookup failure" \
  scripts rhwp-core.lock
git diff --check
```

완료 조건:

- update script가 submodule checkout 없이 upstream ref와 required API를 판단할 수 있다.
- lock 정합성 실패가 `Cargo.lock mismatch`로 분리된다.
- script 변경만으로 현재 build 경로가 불필요하게 깨지지 않는지 문법과 검색 gate로 확인되어 있다.

## Stage 3: RustBridge git-rev dependency 전환과 Vendor/rhwp 제거

대상:

- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `.gitmodules`
- `Vendor/rhwp` gitlink
- `rhwp-core.lock`

작업:

- `RustBridge/Cargo.toml`의 dependency를 다음 Demo/Preview 기준으로 전환한다.

```toml
rhwp = { git = "https://github.com/edwardkim/rhwp.git", rev = "1e9d78a1d40c71779d81c6ec6870cd301d912626" }
```

- `cargo update` 또는 update script를 통해 `RustBridge/Cargo.lock`을 git source 기준으로 갱신한다.
- `Cargo.lock`의 resolved commit이 target commit과 일치하는지 확인한다.
- `.gitmodules`에서 `Vendor/rhwp` 항목을 제거하고, git index에서 `Vendor/rhwp` gitlink를 제거한다.
- `rhwp-core.lock`을 commit-pinned Demo/Preview 기준으로 갱신한다.
- Stable release tag가 여전히 required core API를 충족하지 못하면 blocked 상태를 latest checked release 필드로 남긴다.

산출물:

- `mydocs/working/task_m010_30_stage3.md`

검증:

```bash
cargo metadata --manifest-path RustBridge/Cargo.toml --locked --format-version 1 >/tmp/rhwp-mac-cargo-metadata.json
rg -n "name = \"rhwp\"|source = \"git\\+https://github.com/edwardkim/rhwp.git" RustBridge/Cargo.lock
rg -n "rhwp_ref_kind|rhwp_commit|rhwp_release_transition_status|rhwp_latest_checked_release" rhwp-core.lock
git ls-files -s Vendor/rhwp .gitmodules
git submodule status
git diff --check
```

완료 조건:

- `Vendor/rhwp` gitlink가 git index에서 제거되어 있다.
- `.gitmodules`에 `Vendor/rhwp` submodule 항목이 남지 않는다.
- `Cargo.lock`과 `rhwp-core.lock`의 resolved commit이 target commit으로 일치한다.
- Stable 전환이 blocked이면 그 이유가 `missing core API`로 단계 보고서에 기록되어 있다.

## Stage 4: build script, artifact lock, FFI symbol 검증 보강

대상:

- `scripts/build-rust-macos.sh`
- `rhwp-core.lock`
- `Frameworks/universal/librhwp.a`
- `Frameworks/generated_rhwp.h`
- `Frameworks/Rhwp.xcframework`
- `rhwp-ffi-symbols.txt`

작업:

- `scripts/build-rust-macos.sh`에서 `Vendor/rhwp` 존재 검사를 제거한다.
- `--verify-lock`이 Cargo.lock 기반 resolved commit과 `rhwp-core.lock` commit을 비교하게 한다.
- `--update-lock`이 Cargo.lock 기반 commit, ref kind, release tag 또는 demo transition status를 보존하면서 artifact hash/size를 갱신하게 한다.
- arm64/x86_64 Rust staticlib build, universal library 생성, cbindgen header, FFI symbol diff, XCFramework 생성을 git dependency 기준으로 확인한다.
- generated header와 static library 산출물 변경이 의도된 core source 전환에 따른 것인지 단계 보고서에 기록한다.

산출물:

- `mydocs/working/task_m010_30_stage4.md`

검증:

```bash
./scripts/build-rust-macos.sh
./scripts/build-rust-macos.sh --verify-lock
bash -n scripts/build-rust-macos.sh
if command -v shellcheck >/dev/null; then shellcheck scripts/build-rust-macos.sh; else echo "shellcheck not installed"; fi
diff -u rhwp-ffi-symbols.txt Frameworks/generated_rhwp_symbols.txt
grep -n "width_pt\\|height_pt" Frameworks/generated_rhwp.h
git diff --check
```

완료 조건:

- `Vendor/rhwp` 없이 RustBridge arm64/x86_64 build가 통과한다.
- artifact hash/size와 FFI symbol set 검증이 통과한다.
- `rhwp-core.lock`의 artifact metadata가 현재 산출물과 일치한다.

## Stage 5: 사용자 문서와 운영 매뉴얼을 git dependency 기준으로 보정

대상:

- `README.md`
- `AGENTS.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/tech/core_release_compatibility.md`
- `mydocs/manual/core_submodule_operation_guide.md` 또는 신규 대체 문서
- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- 필요 시 `mydocs/manual/document_structure_guide.md`

작업:

- README의 setup, build, core update, project structure, troubleshooting 설명을 git dependency 기준으로 갱신한다.
- architecture 문서에서 `Vendor/rhwp`를 runtime 소유 경계로 설명하는 문구를 제거하고, `RustBridge` git dependency와 C ABI 경계를 설명한다.
- core 운영 매뉴얼은 submodule 운영 문서에서 git dependency 운영 문서로 보정하거나, legacy 문맥을 분리한다.
- build/run 매뉴얼에서 `git submodule update`를 필수 setup으로 요구하지 않게 한다.
- release/distribution 문서에서 배포 전 submodule 상태 확인을 Cargo.lock/rhwp-core.lock 정합성 확인으로 대체한다.
- AGENTS 핵심 규칙과 필수 참조 문서 설명을 전환 후 기준에 맞춘다.
- 역사 보고서와 과거 작업 기록의 `Vendor/rhwp` 문맥은 수정하지 않고 검색 결과에서 제외 근거를 기록한다.

산출물:

- `mydocs/working/task_m010_30_stage5.md`

검증:

```bash
git diff --check
rg -n "Vendor/rhwp|git submodule|submodule" README.md scripts mydocs AGENTS.md RustBridge project.yml
rg -n "git dependency|rev|release tag|resolved commit|Cargo.lock|rhwp-core.lock|demo-commit-pin" \
  README.md AGENTS.md mydocs/tech mydocs/manual scripts rhwp-core.lock RustBridge
```

완료 조건:

- active setup/build/update 문서가 `Vendor/rhwp` submodule을 요구하지 않는다.
- 남은 submodule 언급은 역사 기록, legacy 설명, 또는 전환 전 compatibility 설명으로 분류되어 있다.
- Demo/Preview commit pin과 Stable release tag 기준이 문서에서 구분되어 있다.

## Stage 6: fresh checkout 기준 통합 검증과 최종 보고 준비

대상:

- 전체 변경 파일
- `mydocs/orders/20260426.md`
- `mydocs/report/task_m010_30_report.md`

작업:

- `Vendor/rhwp`가 없는 상태를 기준으로 build, lock verify, no-AppKit, Xcode project generation, HostApp build, render smoke를 수행한다.
- `git submodule status`에서 `Vendor/rhwp`가 나오지 않는지 확인한다.
- 문서 검색 gate에서 남은 `Vendor/rhwp`/submodule 항목의 허용 사유를 단계 보고서와 최종 보고서에 기록한다.
- 오늘할일을 완료 상태로 갱신한다.
- 최종 결과 보고서를 작성하고 PR 게시 전 커밋 상태를 정리한다.

산출물:

- `mydocs/working/task_m010_30_stage6.md`
- `mydocs/report/task_m010_30_report.md`

검증:

```bash
./scripts/build-rust-macos.sh
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh
rg -n "Vendor/rhwp|git submodule|submodule" README.md scripts mydocs AGENTS.md RustBridge project.yml
git submodule status
git diff --check
git status --short
```

완료 조건:

- fresh checkout에 `Vendor/rhwp` worktree가 없어도 build와 render smoke가 통과한다.
- `Cargo.lock`, `rhwp-core.lock`, artifact hash/size, FFI symbol set이 모두 일치한다.
- 최종 보고서에 실행한 검증, 실패 후 회복 내역, 미실행 사유가 기록되어 있다.
- PR 게시 전 브랜치에 미커밋 변경이 없다.

## 승인 요청 사항

이 구현 계획서 기준으로 Stage 1 조사를 진행할지 승인 요청한다. 승인 전에는 `RustBridge`, script, lock, README, 매뉴얼, submodule 제거 변경을 진행하지 않는다.
