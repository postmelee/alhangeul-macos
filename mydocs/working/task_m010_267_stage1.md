# Task M010 #267 Stage 1 완료 보고서

## 단계 목적

`rhwp v0.7.12` release의 실제 tag/commit, upstream 변경 범위, 앱 저장소의 현재 core/studio provenance, release workflow precondition을 확인하고 Stage 2에서 갱신할 파일 범위를 고정한다.

이번 단계에서는 조사 보고서와 오늘할일 상태만 변경했다. `RustBridge`, `rhwp-core.lock`, bundled `rhwp-studio`, 앱 source/resource는 수정하지 않았다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m010_267_stage1.md` | Stage 1 조사 결과와 Stage 2 영향 범위 기록 |
| `mydocs/orders/20260518.md` | #267 상태를 Stage 2 승인 대기로 갱신 |

## 본문 변경 정도 / 본문 무손실 여부

소스 본문 변경은 없다. upstream 조회와 release workflow 확인 결과만 새 stage report에 기록했다.

## 확인 결과

### upstream release와 tag

`gh release view v0.7.12 --repo edwardkim/rhwp --json tagName,name,publishedAt,isDraft,isPrerelease,url,body`

| 항목 | 결과 |
|------|------|
| tagName | `v0.7.12` |
| name | `v0.7.12` |
| publishedAt | `2026-05-17T18:09:16Z` |
| draft / prerelease | `false` / `false` |
| release body | 빈 문자열 |
| URL | `https://github.com/edwardkim/rhwp/releases/tag/v0.7.12` |

`refs/tags/v0.7.12`는 annotated tag object `8c24aadd4942abef6c22918c91a0925c53a92706`을 가리킨다. annotated tag payload는 다음 commit을 가리킨다.

| 항목 | 값 |
|------|----|
| target commit | `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` |
| tagger date | `2026-05-17T18:00:52Z` |
| tag message | `v0.7.12 — @jangster77 7-PR 시리즈 (#956~#968) + Issue #952 5-결함 완결 + WMF #966 + HWP3 #968 + LTO #818` |

`git ls-remote --tags https://github.com/edwardkim/rhwp.git 'refs/tags/v0.7.12'`는 annotated tag object SHA `8c24aadd4942abef6c22918c91a0925c53a92706`을 반환했다. resolved commit은 annotated tag dereference 기준 `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5`다.

### 공식 compatibility check

`./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.12`

결과:

```text
Checked rhwp core target:
  channel: stable
  tag:     v0.7.12
  commit:  1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5
```

이 check는 tag fetch와 checkout에 약 5분이 걸렸다. 원인은 upstream repository의 큰 작업트리와 tag checkout 비용으로 보인다. 최종적으로 script의 필수 API grep check는 통과했다.

추가로 임시 upstream clone에서 확인한 필수 API symbol 위치:

| API | 확인 위치 |
|-----|-----------|
| `build_page_render_tree` | `src/document_core/queries/rendering.rs` |
| `get_bin_data` | `src/document_core/queries/rendering.rs` |
| `render_page_svg_native` | `src/document_core/queries/rendering.rs` |
| `get_page_info_native` | `src/document_core/queries/rendering.rs` |
| `extract_thumbnail_only` | `src/main.rs` 경유 확인, parser API 존재 확인 대상 |

### upstream diff 영향 범위

GitHub compare API 기준 `v0.7.11..v0.7.12`는 `ahead_by=193`, `behind_by=0`, `total_commits=193`이다. GitHub compare API의 file list는 큰 diff에서 상위 300개 파일 제한이 있으므로, 정확한 주요 path 확인은 임시 clone의 `git diff --name-status v0.7.11 v0.7.12 -- ...` 결과를 함께 사용했다.

주요 변경군:

| 영역 | 판단 |
|------|------|
| Rust core/package | `Cargo.toml`, `src/document_core/**`, `src/parser/**`, `src/paint/**`, `src/renderer/**`, `src/serializer/**`, `src/wasm_api.rs`, `src/wmf/**`, `src/emf/**` 변경. Stage 2에서 RustBridge build와 render smoke 필수 |
| Native/Swift bindings | `bindings/Native/**` 수정, `bindings/swift/**` 신규 추가. 앱 저장소의 `RustBridge` C ABI와 직접 동일하지는 않지만 upstream binding 변화는 ABI/API 영향 검토 신호로 기록 |
| bundled viewer | `rhwp-studio` 46개 파일 변경. `package.json` version은 `0.7.12`, unsaved guard, compare/history UI, command, WASM bridge, canvas/page renderer 계열 변경 포함. Stage 2에서 bundled asset sync 필요 |
| samples/PDF/tests | `samples/**`, `pdf/**`, golden SVG와 issue tests 추가/수정. 앱 저장소 기본 검증 sample을 바꾸지는 않되, release note의 rhwp 변화 판단 참고 대상 |
| docs/changelog | `CHANGELOG.md`, `CHANGELOG_EN.md`, `README.md`, `docs/text-ir-v2.md` 변경. upstream release body가 비어 있으므로 changelog/diff 기반으로 사용자-facing 요약을 직접 작성해야 함 |

Stage 2에서 실제 앱 저장소에 반영할 기본 변경 파일은 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`, `Frameworks/generated_rhwp.h`, `Frameworks/universal/librhwp.a`, `Sources/HostApp/Resources/rhwp-studio/**`다. `rhwp-ffi-symbols.txt`, `Sources/RhwpCoreBridge/**`, `Sources/Shared/**`는 build/verify 결과에 따라 변경 여부가 결정된다.

### 현재 앱 저장소 provenance

| 대상 | 현재 값 |
|------|---------|
| `rhwp-core.lock` | `rhwp_release_tag = "v0.7.11"`, `rhwp_commit = "a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae"` |
| `RustBridge/Cargo.toml` | `tag = "v0.7.11"`, `features = ["native-skia"]` |
| `RustBridge/Cargo.lock` | `git+https://github.com/edwardkim/rhwp.git?tag=v0.7.11#a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae` |
| bundled `rhwp-studio` manifest | `source_release_tag = "v0.7.11"`, `source_resolved_commit = "a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae"`, 54 files, 28,543,821 bytes |
| app source version/build | HostApp `0.1.2` / `8` |
| release workflow defaults | `version=0.1.2`, `previous_release_ref=v0.1.1`, `expected_rhwp_tag=v0.7.11` |

### upstream sync PR와 workflow 상태

`gh pr list --repo postmelee/alhangeul-macos --state all --search "v0.7.12 rhwp"` 결과는 빈 배열이다. 아래 automation branch head 후보도 PR이 없다.

- `automation/rhwp-v0.7.12-studio-sync`
- `automation/rhwp-0.7.12-studio-sync`

로컬 `devel`에는 `.github/workflows/rhwp-upstream-sync-pr.yml`이 있고 base branch는 `devel`이다. 다만 `gh workflow list --repo postmelee/alhangeul-macos --all`에는 `rhwp Upstream Sync PR`이 보이지 않았다. 이는 해당 workflow가 아직 default branch 기준으로 노출되지 않은 상태일 가능성이 있다. 최근 `rhwp Upstream Release Check` schedule은 `2026-05-17T04:34:51Z`에 성공했지만, `rhwp v0.7.12` release publishedAt은 `2026-05-17T18:09:16Z`라 그날 schedule보다 늦다.

따라서 Stage 2는 자동 sync PR을 기다리지 않고 수동 sync 절차를 기준으로 진행하는 것이 맞다.

### release workflow precondition

현재 GitHub Pages 설정:

| 항목 | 값 |
|------|----|
| Pages URL | `https://postmelee.github.io/alhangeul-macos/` |
| build_type | `workflow` |
| source | `main` / `/docs` |
| public | `true` |
| https_enforced | `true` |

`github-pages` environment deployment branch policy:

| name | type |
|------|------|
| `devel-webview` | branch |
| `gh-pages` | branch |
| `main` | branch |
| `publish/task135` | branch |
| `v*` | tag |

`Release Publish DMG`와 `Release Rehearsal DMG` workflow는 모두 `expected_rhwp_tag` default가 아직 `v0.7.11`이다. Stage 3에서 `v0.1.3` / `v0.7.12` 기준으로 source default를 보정해야 한다. `Release Publish DMG`는 `require_latest_rhwp=true` default를 갖고 있으므로, Stage 5 public publish 전에 lock이 upstream latest `v0.7.12`와 일치해야 한다.

## 검증 결과

| 명령 | 결과 | 비고 |
|------|------|------|
| `gh release view v0.7.12 --repo edwardkim/rhwp ...` | OK | release metadata 확인, body는 비어 있음 |
| `gh api repos/edwardkim/rhwp/git/ref/tags/v0.7.12` | OK | annotated tag object 확인 |
| `gh api repos/edwardkim/rhwp/git/tags/8c24aadd...` | OK | resolved commit `1899ef9...` 확인 |
| `git ls-remote --tags https://github.com/edwardkim/rhwp.git 'refs/tags/v0.7.12'` | OK | tag ref 확인 |
| `./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.12` | OK | target commit과 필수 API check 통과 |
| `gh api repos/edwardkim/rhwp/compare/a9dcdee...1899ef9...` | OK | `ahead_by=193`, compare file list는 300 file cap 주의 |
| `git -C /private/tmp/rhwp-release-diff-task267 diff --name-status ...` | OK | 주요 path diff 확인 후 임시 clone 삭제 |
| `gh pr list ... "v0.7.12 rhwp"` | OK | 관련 PR 없음 |
| `gh api repos/postmelee/alhangeul-macos/pages` | OK | Pages source는 workflow |
| `gh api repos/postmelee/alhangeul-macos/environments/github-pages/deployment-branch-policies` | OK | `v*` tag policy 존재 |
| `git diff --check -- mydocs/orders/20260518.md mydocs/working/task_m010_267_stage1.md` | OK | 공백 오류 없음 |

## 잔여 위험

- upstream release body가 비어 있어 `포함된 rhwp 변화`는 changelog, tag message, diff path, 앱 smoke 결과를 종합해 수동 작성해야 한다.
- `rhwp-studio` 변화가 크므로 asset sync 후 HostApp WKWebView smoke와 `scripts/verify-rhwp-studio-assets.sh`가 중요하다.
- Rust core는 renderer/parser/paint/wmf/hwp3/hwpx 계열 변경이 많아 `validate-stage3-render.sh`, Quick Look/Thumbnail smoke, PDF/export 관련 release note 한계 기록이 필요하다.
- `update-rhwp-core --check`는 통과했지만 fetch/checkout이 오래 걸렸다. Stage 2의 `--update-lock`와 Rust bridge build도 시간이 길어질 수 있다.
- `gh workflow list`에 upstream sync workflow가 노출되지 않아 자동 sync PR 경로는 현재 신뢰하지 않는다. Stage 2에서는 수동 sync 절차를 우선한다.

## 다음 단계 영향

Stage 2에서는 다음 순서로 진행한다.

1. `scripts/update-rhwp-core.sh --channel stable --tag v0.7.12`
2. `scripts/build-rust-macos.sh --update-lock`
3. `scripts/build-rust-macos.sh --verify-lock`
4. `scripts/sync-rhwp-studio.sh` 또는 동등한 bundled asset sync
5. `scripts/verify-rhwp-studio-assets.sh`
6. ABI/render tree 변화가 있으면 Swift bridge와 renderer 적응
7. Stage 2 보고서에 core/studio provenance matrix와 FFI 변화 여부 기록

## 승인 요청

Stage 1 결과를 승인하면 Stage 2 `rhwp v0.7.12 core와 studio provenance 갱신`으로 진행한다.
