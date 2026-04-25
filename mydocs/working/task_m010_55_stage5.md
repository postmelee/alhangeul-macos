# Task #55 Stage 5 완료 보고서

## 단계 목적

#55 전체 산출물을 검증하고, 후속 #30 작업자가 Demo/Preview commit pin과 Stable release tag 전환 기준을 바로 이해할 수 있도록 최종 보고서와 GitHub Issue #30 참고 문서를 정리한다.

## 산출물

- `mydocs/working/task_m010_55_stage5.md`: Stage 5 완료 보고서
- `mydocs/report/task_m010_55_report.md`: 최종 결과 보고서
- `mydocs/orders/20260426.md`: #55 완료 처리
- GitHub Issue #30 본문 갱신: 참고 문서 섹션 추가

## #30 참고 문서 반영

GitHub Issue #30 본문에 다음 참고 문서를 추가했다.

- `mydocs/tech/core_release_compatibility.md`
- `mydocs/manual/core_submodule_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/working/task_m010_55_stage4.md`

확인 결과:

```text
$ gh issue view 30 --json body --jq '.body' | rg -n "참고 문서|core_release_compatibility|task_m010_55_stage4"
38:- [ ] `mydocs/tech/core_release_compatibility.md`의 Demo/Preview gate 통과
136:## 참고 문서
140:- `mydocs/tech/core_release_compatibility.md`
146:- `mydocs/working/task_m010_55_stage4.md`
```

`gh issue edit`과 `gh issue view`는 GitHub 네트워크 접근이 필요해 escalation으로 실행했다.

## 검증 결과

diff check:

```text
$ git diff --check
결과: 통과.
```

script syntax:

```text
$ bash -n scripts/update-rhwp-core.sh
결과: 통과.

$ bash -n scripts/build-rust-macos.sh
결과: 통과.
```

shared Swift dependency check:

```text
$ ./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

shellcheck:

```text
$ if command -v shellcheck >/dev/null; then shellcheck scripts/update-rhwp-core.sh scripts/build-rust-macos.sh; else echo "shellcheck not installed"; fi
shellcheck not installed
```

core API 검색 게이트:

```text
$ rg -n "build_page_render_tree|get_bin_data|render_page_svg_native|get_page_info_native|extract_thumbnail_only" RustBridge Sources scripts mydocs
결과: RustBridge 호출 지점, compatibility 문서, 단계 보고서에서 기대 항목 확인.
```

release/update 기준 검색 게이트:

```text
$ rg -n "release tag|resolved commit|Cargo.lock|rhwp-core.lock|compatibility gate|render smoke|unblock|Demo/Preview|Stable|demo-commit-pin|--channel demo|--channel stable" mydocs scripts rhwp-core.lock RustBridge
결과: release tag + resolved commit, Demo/Preview commit pin, Stable release tag, update script 기준 확인.
```

lock verify:

```text
$ ./scripts/build-rust-macos.sh --verify-lock
결과: 통과.
```

확인된 FFI symbol:

```text
rhwp_close
rhwp_extract_thumbnail
rhwp_free_bytes
rhwp_free_string
rhwp_image_data
rhwp_open
rhwp_page_count
rhwp_page_size
rhwp_render_page_svg
rhwp_render_page_tree
```

`xcodebuild -create-xcframework` 중 CoreSimulator/DVT cache 관련 경고가 출력되었지만 명령은 exit code 0으로 완료했고 `rhwp-core.lock` 검증도 통과했다.

최종 워크트리 확인:

```text
$ git status --short --branch
## local/task55
```

## 잔여 위험

- #30의 실제 `Vendor/rhwp` 제거, `RustBridge/Cargo.toml` git dependency 전환, `Cargo.lock` 갱신, script 재정의는 아직 수행하지 않았다.
- Demo/Preview 배포는 `git` + `rev` commit pin으로만 허용하며, GitHub Release는 prerelease로 게시해야 한다.
- Stable 배포는 upstream release tag가 `DocumentCore::build_page_render_tree`와 `DocumentCore::get_bin_data`를 포함할 때만 전환 가능하다.
- git dependency 전환 이후 fresh checkout의 첫 빌드는 dependency fetch 때문에 네트워크 접근이 필요하다.

## 완료 판단

Stage 5 완료 조건을 충족했다. #55 산출 문서는 후속 #30 작업자가 Demo/Preview commit-pinned dependency 전환과 Stable release tag dependency 승격을 분리해 진행할 수 있는 기준으로 사용할 수 있다.

## 승인 요청

최종 보고서 기준으로 PR 게시 절차를 진행할지 승인 요청한다.
