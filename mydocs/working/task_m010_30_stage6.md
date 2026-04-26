# Task #30 Stage 6 완료 보고서

## 단계 목적

`Vendor/rhwp` worktree와 submodule gitlink가 없는 현재 상태에서 Rust bridge, lock verify, Xcode project generation, HostApp build, render smoke가 통과하는지 통합 검증한다. 검증 결과를 최종 보고서와 PR 준비 상태로 정리한다.

## 산출물

- `mydocs/working/task_m010_30_stage6.md`
  - Stage 6 통합 검증 보고서
- `mydocs/report/task_m010_30_report.md`
  - Issue #30 최종 결과 보고서
- `mydocs/orders/20260426.md`
  - #30 완료 상태 갱신

## 전제 상태

submodule 제거 확인:

```text
$ git submodule status
결과: 출력 없음

$ test -e Vendor/rhwp
결과: exit code 1, 경로 없음

$ git ls-files -s .gitmodules Vendor/rhwp
결과: 출력 없음
```

현재 dependency 기준:

```toml
rhwp = { git = "https://github.com/edwardkim/rhwp.git", rev = "1e9d78a1d40c71779d81c6ec6870cd301d912626" }
```

`rhwp-core.lock` 기준:

```text
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

## 검증 결과

통과:

```bash
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

`./scripts/build-rust-macos.sh --verify-lock`는 artifact hash/size와 FFI symbol set 검증을 통과했다.

`./scripts/check-no-appkit.sh`:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

`xcodegen generate`:

```text
Created project at /Users/melee/Documents/projects/rhwp-mac/AlhangeulMac.xcodeproj
```

`xcodegen generate` 후 tracked diff는 발생하지 않았다.

HostApp Debug build:

```text
** BUILD SUCCEEDED ** [5.801 sec]
```

`xcodebuild`와 `xcodebuild -create-xcframework` 실행 중 CoreSimulatorService, DVT cache, provisioning profile 관련 경고가 출력되었다. 이번 검증은 macOS build와 XCFramework 생성 경로이며, 각 명령은 exit code 0으로 완료했다.

render smoke:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464
```

검색 gate:

```bash
rg --line-number 'Vendor/rhwp|git submodule|submodule' README.md scripts mydocs AGENTS.md RustBridge project.yml
```

남은 항목 분류:

- `AGENTS.md`, `mydocs/tech/project_architecture.md`: 기존 파일명 `core_submodule_operation_guide.md` 링크
- `mydocs/manual/core_submodule_operation_guide.md`: 파일명을 호환 유지한다는 설명
- `scripts/build-rust-macos.sh`: legacy path dependency mode의 방어 코드와 에러 메시지
- `mydocs/report`, `mydocs/working`, `mydocs/plans`, `mydocs/troubleshootings`, 과거 `mydocs/orders`: 이전 작업의 역사 기록
- `mydocs/tech/task_m010_28_sample_provenance.md`: 샘플 fixture 출처 증빙 기록

active setup/build/update 문서에는 `git submodule update --init --recursive`를 요구하는 현재 절차가 남아 있지 않다.

## 본문 변경 정도 / 본문 무손실 여부

이번 단계에서 source와 build script는 수정하지 않았다. 변경은 Stage 6 보고서, 최종 결과 보고서, 오늘할일 완료 표시뿐이다.

## 잔여 위험

- 현재 core 기준은 Demo/Preview commit pin이다. 최신 확인 release `v0.7.3`은 `build_page_render_tree`, `get_bin_data`가 없어 Stable 전환은 blocked 상태다.
- `scripts/build-rust-macos.sh`의 legacy path dependency mode는 비활성 호환 경로로 남아 있다.
- Release package, 서명, 공증, Finder 등록 smoke는 이번 Issue #30의 Stage 6 검증 범위가 아니다.

## 완료 판단

fresh checkout 기준에서 별도 `Vendor/rhwp` checkout 없이 Rust bridge build, lock verify, HostApp Debug build, render smoke가 통과했다. Issue #30 구현 단계는 완료 상태로 판단한다.

## 승인 요청

이 보고서와 최종 결과 보고서 기준으로 PR 게시 절차를 진행할지 승인 요청한다.
