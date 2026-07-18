# Task M020 #422 Stage 1 완료보고서

## 단계 목적

upstream `rhwp v0.7.19` release provenance와 변경 영향을 확인하고, automation PR #421 후보가 Task #422 시작점에 안전하게 적용 가능한지 read-only로 검증한다. current RustBridge의 15개 C ABI, bundled studio manifest/font, Task #418 visual baseline을 기준으로 Stage 2 통합·재생성 계약과 중단 조건을 확정한다.

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/working/task_m020_422_stage1.md` | upstream/automation/ABI/studio/visual 조사와 Stage 2 계약 기록 |
| `mydocs/orders/20260719.md` | Task #422 진행 상태와 Stage 2 승인 대기 기록 |

제품 source, dependency, lock, bundled studio asset에는 변경을 만들지 않았다. upstream impact detector의 세 출력은 `/private/tmp/task422-upstream-impact/`에만 생성했으며 commit 대상이 아니다.

## 조사 결과

### Upstream release provenance

| 항목 | 결과 |
|------|------|
| release | `v0.7.19`, draft 아님, prerelease 아님 |
| published | `2026-07-17T10:20:00Z` |
| tag resolved commit | `f137b4c9468eaff5bb43e25108e9c9d39a2ed15b` |
| compare | `v0.7.18..v0.7.19`, `ahead_by=578`, `total_commits=578` |
| 공식 범위 | 기여자 8명, PR 55건의 patch release |
| URL | https://github.com/edwardkim/rhwp/releases/tag/v0.7.19 |

release tag는 예상 commit에 그대로 고정돼 있으며 stable dependency 기준을 충족한다. GitHub compare API는 file 목록을 300개까지만 반환하지만 local tag diff는 전체 `1007 files changed, 118819 insertions, 20306 deletions`를 확인했다.

알한글 영향권의 local shortstat은 다음과 같다.

| 영역 | 변경량 | 주요 영향 |
|------|--------|-----------|
| `src/**` | 104 files, +16,697 / -1,222 | 저장 지오메트리, 표 페이지네이션, BinData, parser/serializer, render/layout |
| `rhwp-studio/**` | 101 files, +16,227 / -850 | CanvasKit/page renderer, font, recent/open/save, HML, embed transport |
| `assets`, root Cargo | 40 files, +225 / -5 | canonical font asset와 dependency graph |
| 합계 영향 표면 | 245 files, +33,149 / -2,077 | native core와 bundled studio 모두 재검증 필요 |

저장 지오메트리와 표 페이지네이션은 native core와 bundled studio 양쪽의 사용자-visible 배치에 영향을 준다. BinData 지연 로딩은 메모리 개선 후보지만 downstream image lifetime을 대표 embedded image fixture에서 다시 확인해야 한다. HML과 MessageChannel은 upstream 기능이며 현재 macOS document type/open handoff가 없으므로 알한글 공개 지원 완료로 분류하지 않는다.

### Impact detector

current `v0.7.18`과 target `v0.7.19`를 repository detector에 입력한 결과는 다음과 같다.

```text
changed paths: 1007
impact paths: 208
has viewer impact: true
current commit: 93862a4e16df59834ebce46d91e948cd739208e9
target commit: f137b4c9468eaff5bb43e25108e9c9d39a2ed15b
```

208개 impact path에는 root Cargo files, `THIRD_PARTY_LICENSES.md`, studio 101개 file과 core `src/**` 104개 file이 포함된다. 따라서 PR CI 성공만으로 public release 입력을 확정하지 않고 artifact, 앱 target과 visual gate를 모두 유지한다.

### Automation PR #421 freshness

| 항목 | 결과 |
|------|------|
| state | `OPEN` |
| base | `devel` / `9ca9c488937bdda00fb045eb82b1ab2ecb31aa83` |
| head | `automation/rhwp-v0.7.19-full-sync` / `ddcc0329ae1b6bef7c6dacb51ee8375de3b6d42c` |
| commits | 단일 `Sync rhwp upstream to v0.7.19` commit |
| ancestry | fixed base 대비 `0 1` |
| mergeability | `MERGEABLE`, `CLEAN` |
| repository paths | 15개 logical path, PR API/file diff 일치 |
| URL | https://github.com/postmelee/alhangeul-macos/pull/421 |

CI 네 check는 모두 성공했다.

| Check | 결과 | Run |
|-------|------|-----|
| Classify changed files | SUCCESS | `29629819079 / 88041161735` |
| Script syntax checks | SUCCESS | `29629819079 / 88041184149` |
| Release helper checks | SUCCESS | `29629819079 / 88041184136` |
| macOS validation | SUCCESS | `29629819079 / 88041184154` |

Task branch 시작점과 PR base가 같고 automation branch는 정확히 1커밋 앞선다. Task #418 당시 stale 후보와 달리 automation 재실행이나 conflict 해결은 필요하지 않다. Stage 2에서는 `ddcc0329...`을 exact input으로 사용하되 PR 자체를 merge하지 않고 `cherry-pick -n`으로 source diff만 적용한다.

PR #421 changed path 계약:

- `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`
- studio entrypoint `index.html`, `manifest.json`, `manifest.webmanifest`, `sw.js`
- main JS/CSS와 CanvasKit chunk의 old delete/new add
- WASM hashed asset rename
- `fonts/NotoSansKR-Regular.woff2` 교체

이 목록 밖의 tracked path가 Stage 2 적용 시 나타나면 즉시 중단한다.

### Native core와 ABI 계약

현재 `rhwp-ffi-symbols.txt`는 15개 symbol을 포함한다.

```text
rhwp_close
rhwp_external_image_refs_json
rhwp_extract_thumbnail
rhwp_free_bytes
rhwp_free_string
rhwp_image_data
rhwp_inject_external_image_by_key
rhwp_open
rhwp_page_count
rhwp_page_overlay_images
rhwp_page_size
rhwp_render_page_png
rhwp_render_page_svg
rhwp_render_page_tree
rhwp_set_file_name_utf8
```

target `v0.7.19` source에서 current RustBridge가 사용하는 API를 확인했다.

| API | target signature |
|-----|------------------|
| file name context | `set_file_name(&mut self, name: &str)` |
| external refs | `get_external_image_references(&self) -> String` |
| external injection | `inject_external_image_by_key(&mut self, key: &str, data: &[u8], display_path: &str) -> u32` |

`update-rhwp-core.sh --check --channel stable --tag v0.7.19`는 exit 0으로 target dependency와 resolved commit을 재현했다. source-level blocking API 변화는 발견되지 않았다. 실제 compile/test/generated symbol 보존은 Stage 2 artifact 재생성과 Stage 3 locked test에서 확정한다.

automation reference lock의 archive는 `208,707,280` bytes에서 `210,212,160` bytes로 `1,504,880` bytes 증가한다. 이 값은 workflow 환경 reference일 뿐이므로 Stage 2에서 current RustBridge와 local toolchain으로 다시 생성한 hash/size를 final lock에 기록한다. generated header metadata는 automation diff에서 바뀌지 않았다.

### Bundled studio 계약

| 항목 | current v0.7.18 | candidate v0.7.19 |
|------|----------------|-------------------|
| copied files | 60 | 60 |
| copied bytes | 39,392,653 | 39,842,290 |
| source Cargo.lock SHA-256 | `5cf25bdd...9045` | `401c179d...abd6` |
| main JS | `index-D5QjYkw5.js` | `index-D5SCeB-f.js` |
| main JS bytes | 1,086,032 | 1,129,310 |
| main CSS | `index-BKc-ZB2H.css` | `index-DXdWbUsL.css` |
| CanvasKit chunk | `canvaskit-renderer-C7EpdTSD.js` | `canvaskit-renderer-B7Bik_78.js` |
| WASM | `rhwp_bg-CfVwz6LI.wasm` | `rhwp_bg-chWFkZon.wasm` |
| WASM bytes | 6,640,972 | 6,963,971 |
| NotoSansKR regular bytes | 541,864 | 562,220 |

candidate manifest는 local overlay `alhangeul-wkwebview-overrides.css`, `fonts/FONTS.md`를 계속 기록한다. `index.html`에도 overlay link가 남아 있다. Stage 2에서는 tag/commit, source Cargo.lock fingerprint, entrypoint SHA-256, font bytes와 overlay 보존을 모두 검증한다.

candidate studio file input과 webmanifest는 `.hml`을 추가한다. 그러나 `Sources/HostApp/Info.plist`, QL/Thumbnail declaration에는 HML UTI/document type이 없고 Issue #422 범위에서도 추가하지 않는다. 따라서 bundled asset에 upstream HML UI가 포함되는 것과 알한글이 macOS HML handler가 되는 것은 분리한다.

### Visual baseline 계약

current manifest의 quick suite는 CoreGraphics/Skia 두 policy, first page, 5개 sample을 사용한다.

| Sample | Task #418 CG | Task #418 Skia | Skia-CG | Stage 4 기준 |
|--------|--------------|----------------|---------|--------------|
| `request.hwp` | 17.6976% | 11.6340% | -6.0636pp | 일반 단일 페이지 |
| `KTX.hwp` | 30.7744% | 46.2037% | +15.4293pp | known `warn:skia-delta` sentinel |
| `복학원서.hwp` | 7.5013% | 7.0360% | -0.4653pp | clean capture와 layout overflow watch |
| `hwp-multi-001.hwp` | 14.0349% | 13.9063% | -0.1286pp | 다중 페이지 대표 |
| `hwpx-01.hwpx` | 14.0861% | 13.8750% | -0.2111pp | HWPX 대표 |

manifest의 hard-fail은 crash, timeout, empty output, decode failure, major structure missing, aspect-ratio mismatch와 Skia 실패 뒤 CoreGraphics recovery 부재다. 기본 size drift는 0px이고 quick sample은 개별적으로 최대 1px triage 범위를 갖는다. changed-percent 10% 이상은 구조 검토 대상이며 자동 합격 기준이 아니다.

`KTX.hwp`의 Task #418 `+15.4293pp`는 Task #396 `+15.4874pp`와 같은 수준이다. 이번 sync blocker는 아니지만 Skia production default 전환 blocker는 유지한다. `preview-renderer-baseline.sh --suite quick --validate-only`는 exit 0으로 현재 manifest와 sample 존재를 확인했다.

## Stage 2 통합 계약

Stage 2는 다음 순서와 조건으로 수행한다.

1. `origin/automation/rhwp-v0.7.19-full-sync`를 fetch하고 base/head가 각각 `9ca9c48...`, `ddcc032...`인지 다시 확인한다.
2. `git cherry-pick -n ddcc0329ae1b6bef7c6dacb51ee8375de3b6d42c`으로 tracked sync diff만 적용한다.
3. changed path가 위 15개 logical path 계약과 일치하는지 확인한다.
4. current RustBridge source에서 `build-rust-macos.sh --update-lock`을 실행한다.
5. generated symbol list와 expected 15개 symbol을 대조하고 header/lock을 검증한다.
6. studio tag/commit/Cargo.lock fingerprint/entrypoint/font/overlay를 검증한다.
7. `RhwpCoreBuildInfo.swift`와 final lock을 `v0.7.19` provenance로 정렬한다.
8. core compatibility, dependency operation, architecture 문서의 current 기준만 최소 갱신한다.
9. generated `Frameworks/**`, Xcode project와 `build.noindex/**`를 commit에서 제외한다.

다음 중 하나가 발생하면 Stage 2를 완료 처리하지 않는다.

- automation base/head 또는 changed path 계약 불일치
- native artifact 재생성 실패
- expected/generated 15개 ABI 차이
- core/studio tag, commit 또는 source Cargo.lock fingerprint 불일치
- local overlay 소실
- 계획 범위를 넘는 product source 수정 필요

## 본문 변경 정도 / 본문 무손실 여부

- product source 변경: 없음
- dependency/lock 변경: 없음
- bundled studio asset 변경: 없음
- GitHub remote mutation: 없음
- 임시 조사 출력: `/private/tmp/task422-upstream-impact/`만 생성
- 기존 문서 본문 삭제 또는 재구성: 없음

Stage 1은 read-only 조사 계약을 지켰다. 현재 worktree는 Stage 보고서와 오늘할일 파일을 추가하기 전까지 clean 상태였으며 기존 Task #422 계획 commit 외 변경이 없었다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| `gh release view v0.7.19` | stable, expected release metadata 확인 |
| tag commit API | `f137b4c9468eaff5bb43e25108e9c9d39a2ed15b` 일치 |
| compare API | ahead/total 578, head commit 일치 |
| local full diff | 1007 changed paths 확인 |
| impact detector | 208 impact paths, `has_viewer_impact=true` |
| `gh pr view 421` | OPEN, CLEAN, expected base/head, CI 4개 성공 |
| automation ancestry | `0 1`, 단일 sync commit |
| automation changed paths | PR API와 local diff 일치 |
| stable update check | exit 0 |
| current core build info verify | `OK: RhwpCoreBuildInfo matches rhwp-core.lock` |
| current studio verify | `OK: rhwp-studio assets verified` |
| current FFI inventory | 15개 symbol |
| target external image API | 세 API signature 유지 |
| baseline manifest validate | exit 0, quick 5 sample 존재 |

## 잔여 위험

- source-level API는 유지되지만 actual `v0.7.19` static archive compile, generated symbol과 locked test는 아직 실행하지 않았다.
- automation lock의 archive hash/size는 workflow reference이며 local final metadata와 다를 수 있다.
- studio WASM과 main JS가 커지고 NotoSansKR asset이 교체됐다. hash 검증만으로 실제 WKWebView font/render 성공을 보장하지 않는다.
- HML UI가 bundled studio에 포함되지만 macOS integration은 없다. release note에서 공개 지원으로 잘못 확대할 위험이 있다.
- 저장 지오메트리, 표 페이지네이션과 BinData 변경은 compile 성공만으로 회귀를 배제할 수 없다.
- `KTX.hwp` known Skia delta는 그대로 default 전환 blocker다.
- Stage 2 직전 automation branch가 재작성되거나 base가 바뀌면 freshness를 다시 판정해야 한다.

## 다음 단계 영향

Stage 2는 새 automation workflow를 실행하거나 PR #421 후보를 직접 merge하지 않는다. fixed commit `ddcc0329...`을 Task branch에 무커밋 적용하고, current RustBridge artifact와 lock을 재생성한 뒤 15개 ABI와 core/studio 동일 provenance를 고정한다.

제품 compile/runtime와 visual 결과는 각각 Stage 3, Stage 4에서 판정한다. PR #421 close와 automation branch 삭제는 Task PR merge 확인 후 정리 단계까지 보류한다.

## 승인 요청

Stage 1 조사와 위 통합 계약을 승인해 주시면 Stage 2에서 PR #421 exact automation candidate를 `local/task422`에 적용하고 `v0.7.19` core/studio provenance를 재생성·고정한다.
