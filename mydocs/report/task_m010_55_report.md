# Issue #55 최종 결과 보고서

## 작업 요약

- GitHub Issue: #55
- 마일스톤: M010
- 작업 브랜치: `local/task55`
- 작업명: release tag dependency 전환을 위한 core API compatibility와 update architecture 정리

`RustBridge`를 `edwardkim/rhwp` git dependency로 전환하기 전에 필요한 core API contract, release compatibility gate, Demo/Preview와 Stable 배포 채널 기준, 후속 #30 update architecture를 문서화했다.

## 최종 변경 요약

- `mydocs/tech/core_release_compatibility.md`를 추가해 `release tag + resolved commit` 안정 기준과 Demo/Preview commit pin 예외 기준을 정리했다.
- `RustBridge` C ABI가 요구하는 core API contract를 `DocumentCore`/parser API 단위로 기록했다.
- 최신 확인 release `v0.7.3`이 `DocumentCore::build_page_render_tree`, `DocumentCore::get_bin_data`를 포함하지 않아 Stable release tag 전환 기준을 충족하지 못함을 문서화했다.
- 현재 lock commit `1e9d78a1d40c71779d81c6ec6870cd301d912626`은 필요한 API를 포함하므로 Demo/Preview용 `git` + `rev` 후보로 분리했다.
- `mydocs/manual/core_submodule_operation_guide.md`, `mydocs/manual/build_run_guide.md`, `mydocs/tech/project_architecture.md`에 compatibility gate, 배포 채널, RustBridge C ABI 경계를 반영했다.
- 후속 #30에서 `scripts/update-rhwp-core.sh`가 가져야 할 `--channel demo --rev`, `--channel stable --tag`, `--check` 구조와 실패 prefix를 정리했다.
- GitHub Issue #30 본문을 갱신해 `Vendor/rhwp` 제거 + git rev dependency 전환을 Demo/Preview 경로로 진행하고, release tag dependency 승격은 후속 Stable 작업으로 분리하도록 보정했다.
- GitHub Issue #30 본문에 #55 참고 문서 목록을 추가했다.

## 단계별 결과

| 단계 | 결과 |
|------|------|
| Stage 1 | 현재 core API 사용 지점, C ABI surface, latest release 상태 조사 |
| Stage 2 | `core_release_compatibility.md` 작성 |
| Stage 3 | core 운영 매뉴얼, build/run 문서, architecture 문서 보강 |
| Stage 4 | update architecture와 #30 unblock 기준 정리, Issue #30 본문 갱신 |
| Stage 5 | 전체 검증, Issue #30 참고 문서 추가, 최종 보고서와 오늘할일 완료 처리 |

## core release 판단

2026-04-26 확인 기준 `edwardkim/rhwp` 최신 release:

```text
release tag: v0.7.3
publishedAt: 2026-04-19T12:38:52Z
resolved commit: c2e8a3461de800a02f76127ff4797bade1d4e532
```

`v0.7.3` 포함 API:

- `DocumentCore::render_page_svg_native`
- `DocumentCore::get_page_info_native`
- `rhwp::parser::extract_thumbnail_only`

`v0.7.3` 누락 API:

- `DocumentCore::build_page_render_tree`
- `DocumentCore::get_bin_data`

따라서 현재 최신 release tag는 Stable 전환 기준을 충족하지 않는다. 후속 #30은 정식 Stable 전환을 기다리지 않고 Demo/Preview 경로로 `git` + `rev` 전환을 진행할 수 있다.

## 후속 #30 진행 기준

Demo/Preview:

```toml
rhwp = { git = "https://github.com/edwardkim/rhwp.git", rev = "1e9d78a1d40c71779d81c6ec6870cd301d912626" }
```

- `Vendor/rhwp` 제거와 git dependency 전환을 진행한다.
- `Cargo.lock`, `rhwp-core.lock`, artifact hash/size, FFI symbol을 함께 고정한다.
- GitHub Release는 prerelease로 게시하고 latest/stable로 취급하지 않는다.

Stable:

```toml
rhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "<release tag>" }
```

- upstream release tag가 `build_page_render_tree`와 `get_bin_data`를 포함할 때만 승격한다.
- release tag와 resolved commit을 함께 기록한다.
- compatibility gate와 render smoke를 통과해야 한다.

branch dependency나 floating ref는 어느 배포 채널에서도 사용하지 않는다.

## 검증 결과

통과:

```bash
git diff --check
bash -n scripts/update-rhwp-core.sh
bash -n scripts/build-rust-macos.sh
./scripts/check-no-appkit.sh
./scripts/build-rust-macos.sh --verify-lock
shellcheck scripts/update-rhwp-core.sh scripts/build-rust-macos.sh
rg -n "build_page_render_tree|get_bin_data|render_page_svg_native|get_page_info_native|extract_thumbnail_only" RustBridge Sources scripts mydocs
rg -n "release tag|resolved commit|Cargo.lock|rhwp-core.lock|compatibility gate|render smoke|unblock|Demo/Preview|Stable|demo-commit-pin|--channel demo|--channel stable" mydocs scripts rhwp-core.lock RustBridge
```

`./scripts/check-no-appkit.sh` 결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

`./scripts/build-rust-macos.sh --verify-lock`는 FFI symbol 생성과 `rhwp-core.lock` 검증을 통과했다. `xcodebuild -create-xcframework` 실행 중 CoreSimulator/DVT cache 관련 경고가 있었지만 명령은 exit code 0으로 완료했다.

```text
$ shellcheck --version
ShellCheck - shell script analysis tool
version: 0.11.0

$ shellcheck scripts/update-rhwp-core.sh scripts/build-rust-macos.sh
결과: 통과.
```

## GitHub Issue #30 반영

Issue #30 본문은 다음 기준으로 보정했다.

- #30 현재 진행: `Vendor/rhwp` 제거 + Demo/Preview `git` + `rev` dependency 전환
- 후속 작업: upstream release tag가 필수 API를 포함할 때 Stable `git` + `tag` dependency로 승격
- Demo/Preview 후보 commit: `1e9d78a1d40c71779d81c6ec6870cd301d912626`
- 참고 문서: `core_release_compatibility.md`, core operation guide, build/run guide, Stage 4 보고서

GitHub Issue 본문 변경은 원격 상태이므로 로컬 커밋 diff에는 포함되지 않는다.

## 변경 파일

- `mydocs/tech/core_release_compatibility.md`
- `mydocs/manual/core_submodule_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/tech/project_architecture.md`
- `mydocs/plans/task_m010_55.md`
- `mydocs/plans/task_m010_55_impl.md`
- `mydocs/working/task_m010_55_stage1.md`
- `mydocs/working/task_m010_55_stage2.md`
- `mydocs/working/task_m010_55_stage3.md`
- `mydocs/working/task_m010_55_stage4.md`
- `mydocs/working/task_m010_55_stage5.md`
- `mydocs/report/task_m010_55_report.md`
- `mydocs/orders/20260426.md`

## 잔여 위험

- #30의 실제 코드/스크립트 변경은 아직 수행하지 않았다.
- Demo/Preview commit pin은 정식 안정 기준이 아니므로 release 표시와 문서에서 prerelease 성격을 유지해야 한다.
- Stable 승격 시점에는 최신 upstream release tag를 다시 조회하고 resolved commit과 API 포함 여부를 다시 확인해야 한다.
- git dependency 전환 이후 fresh checkout 첫 빌드는 network dependency fetch가 필요하다.

## 완료 판단

Issue #55의 목표인 release tag dependency 전환 판단 기준, Demo/Preview commit-pinned 경로, Stable release tag 승격 기준, 후속 #30 update architecture 정리는 완료되었다.

## 승인 요청 사항

본 최종 결과 보고서 기준으로 `publish/task55` 원격 게시와 `devel` 대상 draft PR 생성을 승인 요청한다.
