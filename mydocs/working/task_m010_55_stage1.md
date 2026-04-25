# Task #55 Stage 1 완료 보고서

## 단계 목적

현재 `RustBridge`가 사용하는 `edwardkim/rhwp` core API, Swift C ABI 의존 표면, lock/update/build script의 provenance 기준을 조사해 release tag compatibility 문서의 입력을 확정한다.

## 산출물

- `mydocs/working/task_m010_55_stage1.md`: Stage 1 조사 결과 보고서

소스, 매뉴얼, 스크립트 본문은 변경하지 않았다.

## core API 사용 지점

`RustBridge/src/lib.rs`가 직접 호출하는 core API는 다음이다.

| RustBridge C ABI | core API | 용도 |
|------|------|------|
| `rhwp_open` | `DocumentCore::from_bytes` | 문서 바이트 파싱과 핸들 생성 |
| `rhwp_page_count` | `DocumentCore::page_count` | 총 페이지 수 조회 |
| `rhwp_page_size` | `DocumentCore::get_page_info_native` | page info JSON에서 width/height 추출 |
| `rhwp_render_page_svg` | `DocumentCore::render_page_svg_native` | SVG 진단/호환 렌더링 |
| `rhwp_render_page_tree` | `DocumentCore::build_page_render_tree` | native render tree JSON 반환 |
| `rhwp_image_data` | `DocumentCore::get_bin_data` | `bin_data_id` 이미지 바이트 조회 |
| `rhwp_extract_thumbnail` | `rhwp::parser::extract_thumbnail_only` | embedded thumbnail 추출 |

Swift 계층의 실제 의존 표면은 `Frameworks/generated_rhwp.h`와 `rhwp-ffi-symbols.txt`의 C ABI다.

- `rhwp_open`
- `rhwp_close`
- `rhwp_page_count`
- `rhwp_page_size`
- `rhwp_render_page_svg`
- `rhwp_render_page_tree`
- `rhwp_image_data`
- `rhwp_extract_thumbnail`
- `rhwp_free_string`
- `rhwp_free_bytes`

`Sources/RhwpCoreBridge/RhwpDocument.swift`는 Rust core 내부 type을 직접 보지 않는다. 문자열 반환값은 `rhwp_free_string`으로 해제하고, `rhwp_image_data`의 borrowed pointer는 즉시 Swift `Data`로 복사한다. embedded thumbnail은 Rust에서 소유권을 넘긴 byte buffer를 `rhwp_free_bytes`로 해제한다.

## release tag 확인 결과

2026-04-26 Stage 1에서 GitHub release를 다시 확인했다.

```text
$ gh release view --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url
{"publishedAt":"2026-04-19T12:38:52Z","tagName":"v0.7.3","targetCommitish":"main","url":"https://github.com/edwardkim/rhwp/releases/tag/v0.7.3"}
```

로컬 tag object와 resolved commit 확인 결과:

```text
$ git -C Vendor/rhwp show-ref --tags v0.7.3
71492bca7ad719dd4b5ce4f58405e1f297772adf refs/tags/v0.7.3

$ git -C Vendor/rhwp rev-parse v0.7.3^{commit}
c2e8a3461de800a02f76127ff4797bade1d4e532
```

`v0.7.3`에는 다음 API가 있다.

- `DocumentCore::render_page_svg_native`
- `DocumentCore::get_page_info_native`
- `rhwp::parser::extract_thumbnail_only`

`v0.7.3`에는 다음 API가 없다.

- `DocumentCore::build_page_render_tree`
- `DocumentCore::get_bin_data`

현재 lock commit `1e9d78a1d40c71779d81c6ec6870cd301d912626`에는 위 두 API가 포함되어 있다. 따라서 현재 release tag 전환 실패 유형은 `missing core API`로 분류한다.

## 현재 provenance와 script 기준

현재 `RustBridge/Cargo.toml`은 path dependency를 사용한다.

```toml
rhwp = { path = "../Vendor/rhwp" }
```

`RustBridge/Cargo.lock`의 `rhwp` package에는 git `source`가 없으므로, 현재는 `Cargo.lock`만으로 resolved commit을 검증할 수 없다. core 재현성 기준은 `Vendor/rhwp` gitlink와 `rhwp-core.lock`의 `rhwp_commit` 비교에 의존한다.

현재 `rhwp-core.lock` 요약:

- `lock_version = 2`
- `rhwp_repo = "https://github.com/edwardkim/rhwp.git"`
- `rhwp_ref_kind = "branch"`
- `rhwp_branch = "devel"`
- `rhwp_commit = "1e9d78a1d40c71779d81c6ec6870cd301d912626"`
- `rhwp_release_transition_status = "blocked-missing-bridge-apis"`
- `rhwp_latest_checked_release_tag = "v0.7.3"`
- `rhwp_latest_checked_release_commit = "c2e8a3461de800a02f76127ff4797bade1d4e532"`

`scripts/update-rhwp-core.sh`는 `Vendor/rhwp` submodule에서 `origin/devel`을 fetch/fast-forward한 뒤 lock skeleton을 다시 쓴다. `scripts/build-rust-macos.sh --verify-lock`는 다음을 검증한다.

- lock version
- `Vendor/rhwp` 현재 commit과 `rhwp-core.lock`의 `rhwp_commit` 일치
- `Frameworks/universal/librhwp.a` sha256/size
- `Frameworks/generated_rhwp.h` sha256/size
- generated FFI symbol set과 `rhwp-ffi-symbols.txt` diff

## Stage 2 이후 변경 대상

확정 변경 대상:

- `mydocs/tech/core_release_compatibility.md`
  - core API contract
  - `v0.7.3` 불충분 사유
  - release tag compatibility gate
  - #30 unblock checklist

Stage 3 보강 후보:

- `mydocs/manual/core_submodule_operation_guide.md`
- `mydocs/manual/build_run_guide.md`
- 필요 시 `mydocs/tech/project_architecture.md`

Stage 4 검토 후보:

- `scripts/update-rhwp-core.sh`
- `scripts/build-rust-macos.sh`
- 필요 시 GitHub Issue #30 본문

현재 조사 기준으로는 Stage 2에서 스크립트 변경 없이 독립 기술 문서를 먼저 작성하는 것이 맞다. script 변경 여부는 Stage 4에서 compatibility 문서와 운영 매뉴얼을 작성한 뒤 최소 필요성만 다시 판단한다.

## 본문 변경 정도 / 본문 무손실 여부

Stage 1은 조사와 보고서 작성만 수행했다. 기존 소스, lock, 매뉴얼, 스크립트 본문은 변경하지 않았다.

## 검증 결과

API 사용 지점 검색:

```text
$ rg -n "build_page_render_tree|get_bin_data|render_page_svg_native|get_page_info_native|extract_thumbnail_only|DocumentCore|rhwp_" RustBridge Sources scripts mydocs/manual mydocs/tech
결과: RustBridge/src/lib.rs, Sources/RhwpCoreBridge/RhwpDocument.swift, project_architecture/core_submodule_operation_guide에서 관련 사용 지점을 확인.
```

release/lock 기준 검색:

```text
$ rg -n "release tag|resolved commit|Cargo.lock|rhwp-core.lock|compatibility gate|render smoke|v0\\.7\\.3" rhwp-core.lock RustBridge scripts mydocs
결과: rhwp-core.lock, build/update scripts, project_architecture, core_submodule_operation_guide, #54 보고서, #55 계획서에서 현재 release 전환 대기 기준 확인.
```

latest release 확인:

```text
$ gh release view --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url
결과: v0.7.3, target main, publishedAt 2026-04-19T12:38:52Z
```

tag resolved commit 확인:

```text
$ git -C Vendor/rhwp rev-parse v0.7.3^{commit}
c2e8a3461de800a02f76127ff4797bade1d4e532
```

release tag API 확인:

```text
$ git -C Vendor/rhwp grep -n "build_page_render_tree\\|get_bin_data\\|render_page_svg_native\\|get_page_info_native" v0.7.3 -- src
결과: render_page_svg_native, get_page_info_native만 확인. build_page_render_tree, get_bin_data 결과 없음.
```

현재 lock commit API 확인:

```text
$ git -C Vendor/rhwp grep -n "build_page_render_tree\\|get_bin_data\\|render_page_svg_native\\|get_page_info_native" HEAD -- src
결과: build_page_render_tree, get_bin_data, render_page_svg_native, get_page_info_native 모두 확인.
```

계획서 diff check:

```text
$ git diff --check -- mydocs/plans/task_m010_55_impl.md
결과: 통과.
```

## 잔여 위험

- `gh release view`는 네트워크 접근이 필요하다. Stage 1에서는 escalated 실행으로 확인했지만, 후속 자동 gate에서는 네트워크 실패와 release 없음 상태를 별도 실패 유형으로 분리해야 한다.
- `v0.7.3`의 API 누락은 확인했지만, 다음 release가 같은 실패 유형을 반복할지 또는 다른 schema/ABI 문제가 생길지는 Stage 2 compatibility gate에 열어 둔다.
- `Cargo.lock` resolved commit 정합성은 path dependency 상태에서는 검증할 수 없다. 후속 #30의 git tag dependency 전환 이후 검증 기준을 문서화해야 한다.

## 다음 단계 영향

Stage 2에서는 `mydocs/tech/core_release_compatibility.md`를 작성한다. 이 문서는 `RustBridge` core API contract, release tag + resolved commit 안정 기준, `v0.7.3` 불충분 사유, compatibility gate, #30 unblock checklist를 포함해야 한다.

## 승인 요청

Stage 1 조사를 완료했다. Stage 2 `core_release_compatibility.md` 작성으로 진행할지 승인 요청한다.
