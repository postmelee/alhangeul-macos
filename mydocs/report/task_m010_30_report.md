# Issue #30 최종 결과 보고서

## 작업 요약

- GitHub Issue: #30
- 마일스톤: M010
- 작업 브랜치: `local/task30`
- 작업명: RustBridge git-rev dependency 전환과 Vendor/rhwp submodule 제거

`RustBridge`의 `rhwp` 의존성을 `Vendor/rhwp` path dependency에서 `edwardkim/rhwp` git `rev` dependency로 전환했다. `.gitmodules`와 `Vendor/rhwp` gitlink를 제거하고, `Cargo.lock`과 `rhwp-core.lock`이 같은 resolved commit과 artifact provenance를 검증하도록 정리했다.

## 최종 변경 요약

- `RustBridge/Cargo.toml`의 `rhwp` dependency를 git `rev = "1e9d78a1d40c71779d81c6ec6870cd301d912626"` 기준으로 전환했다.
- `RustBridge/Cargo.lock`에 `rhwp` git source와 resolved commit을 고정했다.
- `.gitmodules`와 `Vendor/rhwp` gitlink를 제거했다.
- `scripts/update-rhwp-core.sh`를 `--channel demo --rev`, `--channel stable --tag`, `--check`를 지원하는 dependency update gate로 재정의했다.
- `scripts/build-rust-macos.sh`가 git dependency 기준의 `Cargo.lock`/`rhwp-core.lock` 정합성, artifact hash/size, FFI symbol set을 검증하도록 보강했다.
- `rhwp-core.lock` v2를 Demo/Preview commit pin 상태로 갱신하고 Rust bridge 산출물 hash/size를 기록했다.
- README, AGENTS, architecture, build/run, release, core dependency 운영 문서를 git dependency 기준으로 보정했다.
- fresh checkout 기준 통합 검증과 render smoke를 완료했다.

## 단계별 결과

| 단계 | 결과 |
|------|------|
| Stage 1 | 현재 submodule/path dependency 상태, latest release `v0.7.3`, target commit API 보유 여부 조사 |
| Stage 2 | update gate와 build lock 검증 script 구현 |
| Stage 3 | `RustBridge` git `rev` dependency 전환, `.gitmodules`/`Vendor/rhwp` 제거, lock skeleton 갱신 |
| Stage 4 | Rust bridge/XCFramework 재빌드, artifact hash/size lock 갱신 |
| Stage 5 | README와 운영 문서를 git dependency 기준으로 보정 |
| Stage 6 | submodule 없는 상태에서 build, lock verify, HostApp Debug build, render smoke 통과 |

## 최종 lock 상태

```text
rhwp_repo = "https://github.com/edwardkim/rhwp.git"
rhwp_ref_kind = "commit"
rhwp_commit = "1e9d78a1d40c71779d81c6ec6870cd301d912626"
rhwp_release_transition_status = "demo-commit-pin"
rhwp_latest_checked_release_tag = "v0.7.3"
rhwp_latest_checked_release_commit = "c2e8a3461de800a02f76127ff4797bade1d4e532"
Frameworks/universal/librhwp.a sha256 = 4548f87fdf93eef196a85d6f553869c78478075df4c6e4496f66e20ebb125ed5
Frameworks/universal/librhwp.a size = 102635296
Frameworks/generated_rhwp.h sha256 = 69aeca5047bf743286d1b2260f8fc9a091ce4f1d7fd61c80084fab81c3a95ac5
Frameworks/generated_rhwp.h size = 1349
```

최신 확인 release `v0.7.3`의 resolved commit은 `c2e8a3461de800a02f76127ff4797bade1d4e532`다. 이 release에는 `DocumentCore::build_page_render_tree`, `DocumentCore::get_bin_data`가 없어 Stable release tag 전환 기준을 충족하지 못한다. 따라서 이번 작업은 Demo/Preview commit-pinned git dependency로 완료했다.

## 검증 결과

주요 통과 명령:

```bash
cargo metadata --manifest-path RustBridge/Cargo.toml --locked --format-version 1
bash -n scripts/update-rhwp-core.sh
bash -n scripts/build-rust-macos.sh
shellcheck scripts/update-rhwp-core.sh scripts/build-rust-macos.sh
./scripts/update-rhwp-core.sh --check --channel demo --rev 1e9d78a1d40c71779d81c6ec6870cd301d912626
./scripts/build-rust-macos.sh
./scripts/build-rust-macos.sh --verify-lock
./scripts/check-no-appkit.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
./scripts/validate-stage3-render.sh
git submodule status
git diff --check
git status --short
```

Stable gate 확인:

```bash
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.3
```

이 명령은 `missing core API`로 실패하는 것이 기대 결과였고, Stage 2에서 Stable blocked 상태를 확인했다.

Stage 6 render smoke:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464
```

`xcodebuild`와 `xcodebuild -create-xcframework` 실행 중 CoreSimulatorService, DVT cache, provisioning profile 관련 경고가 출력되었다. macOS Debug build와 XCFramework 생성은 exit code 0으로 완료했다.

## 검색 gate

`git submodule status`는 출력이 없고, `git ls-files -s .gitmodules Vendor/rhwp`도 출력이 없다.

```bash
rg --line-number 'Vendor/rhwp|git submodule|submodule' README.md scripts mydocs AGENTS.md RustBridge project.yml
```

남은 항목은 다음으로 분류했다.

- 파일명 호환 링크: `core_submodule_operation_guide.md`
- 비활성 호환 코드: `scripts/build-rust-macos.sh`의 legacy path dependency mode
- 역사 기록: 이전 report/working/plan/troubleshooting/order 문서
- provenance 기록: `mydocs/tech/task_m010_28_sample_provenance.md`

active setup/build/update 문서에는 submodule checkout을 요구하는 현재 절차가 남아 있지 않다.

## 변경 파일

- `.gitmodules` 삭제
- `Vendor/rhwp` gitlink 삭제
- `RustBridge/Cargo.toml`
- `RustBridge/Cargo.lock`
- `scripts/update-rhwp-core.sh`
- `scripts/build-rust-macos.sh`
- `rhwp-core.lock`
- `README.md`
- `AGENTS.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/tech/core_release_compatibility.md`
- `mydocs/manual/core_submodule_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/release_distribution_guide.md`
- `mydocs/plans/task_m010_30.md`
- `mydocs/plans/task_m010_30_impl.md`
- `mydocs/working/task_m010_30_stage1.md`
- `mydocs/working/task_m010_30_stage2.md`
- `mydocs/working/task_m010_30_stage3.md`
- `mydocs/working/task_m010_30_stage4.md`
- `mydocs/working/task_m010_30_stage5.md`
- `mydocs/working/task_m010_30_stage6.md`
- `mydocs/report/task_m010_30_report.md`
- `mydocs/orders/20260426.md`

## 잔여 위험

- 이번 결과는 Demo/Preview commit pin 기준이다. upstream release tag가 필수 API를 포함하면 별도 Stable 전환 작업에서 `git` + `tag` dependency로 승격해야 한다.
- `Frameworks/` 산출물은 생성물이라 커밋하지 않는다. fresh checkout에서는 `./scripts/build-rust-macos.sh`로 재생성해야 한다.
- 릴리스 패키징, 서명, 공증, Finder 등록 smoke는 이번 Issue #30 범위가 아니다.

## 완료 판단

Issue #30의 목표인 `Vendor/rhwp` submodule 제거, `RustBridge` git `rev` dependency 전환, `Cargo.lock`/`rhwp-core.lock` provenance 검증, fresh checkout 기준 build/render 검증을 완료했다.

## 승인 요청

이 최종 결과 보고서 기준으로 PR 게시 절차를 진행할지 승인 요청한다.
