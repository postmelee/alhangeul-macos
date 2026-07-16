# Task M020 #418 Stage 1 보고서

## 단계 목적

PR #415와 current `devel`의 차이, upstream `rhwp v0.7.18`의 API/dependency/studio 영향, `rhwp Upstream Sync PR` workflow의 재생성 조건을 read-only로 확정한다.

이 단계에서는 PR close, 원격 branch 삭제, workflow dispatch를 수행하지 않는다. 제품/core/studio tracked 파일도 변경하지 않고, Stage 2 원격 변경 전에 보존해야 할 증거와 실행 계약만 고정한다.

## 산출물

| 파일 | 변경 요약 |
|------|-----------|
| `mydocs/working/task_m020_418_stage1.md` | #415 stale 근거, upstream 영향, source-level API 호환성, 자동 후보 재생성 계약을 기록한다. |
| `mydocs/orders/20260717.md` | #418을 Stage 1 완료 및 Stage 2 승인 대기 상태로 기록한다. |

## 조사 결과

### PR #415 보존 증거

2026-07-17 조회 기준:

| 항목 | 값 |
|------|----|
| PR | [#415 Sync rhwp upstream v0.7.18](https://github.com/postmelee/alhangeul-macos/pull/415) |
| 상태 | `OPEN`, `isDraft=false` |
| base | `devel` / `477447f2a06f6b28f6ed17c804ea994a5b693dd7` |
| head | `automation/rhwp-v0.7.18-full-sync` / `bd813821db9ea1e6a6d30bf3c540ecb915bccbf6` |
| mergeability | `CONFLICTING`, `mergeStateStatus=DIRTY` |
| repository changed paths | 11개 |
| upstream changed paths | 2,301개 |
| viewer/WASM/core impact paths | 206개 |

PR CI 네 개는 모두 2026-07-11 성공했다.

| check | 결과 | run |
|-------|------|-----|
| Classify changed files | SUCCESS | `29139216945` |
| Script syntax checks | SUCCESS | `29139216945` |
| macOS validation | SUCCESS | `29139216945` |
| Release helper checks | SUCCESS | `29139216945` |

이 성공 결과는 #415 head 자체의 생성 당시 검증으로 보존한다. #415 base 이후 #408 RustBridge ABI와 #406 Finder/UTI 변경이 `devel`에 들어왔으므로 current source와의 통합 성공 근거로 재사용하지 않는다.

### current devel과의 거리 및 충돌

`git fetch origin` 뒤 current `devel`은 `dda97c7`이며 #415 merge-base는 PR base와 같은 `477447f`다.

```text
git rev-list --left-right --count devel...origin/automation/rhwp-v0.7.18-full-sync
17    1
```

즉 current `devel`에만 17개 commit, 자동화 branch에만 full sync commit 1개가 있다. 17개에는 #408 external image C ABI와 #406 HOP UTI 호환 변경이 포함된다.

`git merge-tree`에서 conflict section은 `rhwp-core.lock` 한 파일에만 나타났다. 충돌 내용은 다음과 같다.

- current `devel`: `v0.7.17`, #408 이후 15개 FFI symbol을 반영해 2026-07-11 13:10 UTC에 재생성한 static library hash/size
- #415: `v0.7.18`, #408 merge 전 source에서 2026-07-11 04:11 UTC에 재생성한 static library hash/size
- 공통 변경: `rhwp_release_tag`, `rhwp_commit`, `built_at`, `Frameworks/universal/librhwp.a` hash/size

따라서 한쪽 lock 값을 선택하는 수동 conflict resolution은 새 target core와 current RustBridge source의 실제 산출물을 나타내지 못한다. 최신 `devel`에서 full sync와 artifact provenance를 다시 생성해야 한다.

### upstream release와 commit 고정

| 항목 | 값 |
|------|----|
| release | [edwardkim/rhwp v0.7.18](https://github.com/edwardkim/rhwp/releases/tag/v0.7.18) |
| publishedAt | `2026-07-10T16:49:08Z` |
| release target | `93862a4e16df59834ebce46d91e948cd739208e9` |
| tag resolved commit | `93862a4e16df59834ebce46d91e948cd739208e9` |
| current upstream `main` | `93862a4e16df59834ebce46d91e948cd739208e9` |

stable 기준인 release tag, resolved commit, 현재 upstream main이 같은 commit을 가리킨다. Stage 2에서도 floating `main`이 아니라 `target_tag=v0.7.18`을 명시한다.

GitHub compare API는 `v0.7.17...v0.7.18`을 `ahead_by=1388`, `total_commits=1388`로 반환했다. API의 file 목록은 300개로 제한되므로 path 총계와 impact 총계는 upstream 전체 checkout에서 생성된 #415 body의 2,301개/206개를 기준으로 보존한다. 릴리스 본문의 1,376 commit 표기는 설명용 집계이며 sync 계약에는 tag SHA를 사용한다.

### upstream 영향 분류

| 분류 | 확인 근거 | 앱 통합 영향 |
|------|-----------|--------------|
| core/rendering | 렌더 정합, RowBreak 표 분할, saved bounds, WMF/도형, 관용 파싱과 HWPX 보존 변경 | native core와 Quick Look/Thumbnail 회귀 검증 필요 |
| WASM/API | `Cargo.toml`, core source, `rhwp-studio/src/core/wasm-bridge.ts`, 새 WASM bundle | bundled studio와 native core를 동일 tag/commit에서 생성해야 함 |
| studio/editor | command, caret, input handler, table, autosave, UI, tests 등 다수 경로 | minified asset을 수동 선택하지 않고 workflow로 전체 재생성 |
| dependency | root/RustBridge Cargo lock 갱신, `image`의 TIFF 경로와 `tiff`, `fax`, `half`, `crunchy`, `zerocopy` 추가, regex/wasm-bindgen 등 버전 갱신 | `Cargo.lock` 재해석과 current RustBridge compile/test 필요 |
| font/license | `THIRD_PARTY_LICENSES.md`, font loader 및 font metric 변경 | bundled font/license provenance와 시각 회귀 확인 필요 |
| performance | 거대 표와 후반 페이지 caret 개선 | 기존 benchmark/visual baseline 변화 원인 분류 필요 |

#415가 생성한 repository candidate 11개 경로는 `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`, `rhwp-core.lock`과 bundled `rhwp-studio` entrypoint/manifest/service worker/hashed asset이다. `Frameworks/**`는 repository candidate에 포함되지 않는다.

### #408 API source-level 호환성

`v0.7.18` tag의 `src/wasm_api.rs`에서 current RustBridge가 사용하는 세 API를 확인했다.

```rust
pub fn set_file_name(&mut self, name: &str)
pub fn get_external_image_references(&self) -> String
pub fn inject_external_image_by_key(
    &mut self,
    key: &str,
    data: &[u8],
    display_path: &str,
) -> u32
```

세 API가 target source에 있으므로 #408 구현을 유지한 채 dependency를 올릴 source-level 근거는 확보됐다. 다만 #415 CI는 #408 이전 source를 빌드했으므로 실제 current RustBridge compile, 15개 FFI symbol, generated header/static library 검증은 fresh candidate를 task branch에 적용한 Stage 3에서 수행한다.

### check-only 결과

```bash
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.18
```

결과: 성공.

```text
Checked rhwp core target:
  channel: stable
  tag:     v0.7.18
  commit:  93862a4e16df59834ebce46d91e948cd739208e9
```

upstream checkout 과정에서 `pdf-large/hwpx/2026_oss_rst.pdf`가 LFS pointer여야 한다는 경고가 한 건 있었지만 command는 exit 0으로 target 검증을 완료했다. tracked file 변경은 없었다. Stage 2 workflow가 같은 upstream checkout/build 경로에서 실패하면 이 경고와 실제 실패 phase를 구분한다.

## Stage 2 재생성 계약

workflow source에서 다음 조건을 재확인했다.

- base branch는 `devel`이다.
- manual input은 `target_tag`, `force_pr`, `dry_run`이다.
- branch 이름은 `automation/rhwp-<tag>-full-sync`다.
- 같은 base/head의 open PR이 있으면 `blocker_reason=open_pr`, `decision=existing_automation_pr`로 build가 중단된다.
- PR 없는 미병합 branch만 남아도 `branch_without_pr` blocker가 된다.
- 따라서 #415 close와 기존 원격 branch 삭제가 모두 완료돼야 fresh build가 시작된다.

Stage 2 실행 순서는 다음으로 고정한다.

1. 실행 직전 #415 state/head SHA, current `origin/devel`, tag resolved commit을 다시 확인한다.
2. #415에 #418 링크, stale base, 보존 head SHA, current source 재생성 사유를 body-file 코멘트로 남긴다.
3. #415를 superseded close한다.
4. `automation/rhwp-v0.7.18-full-sync` 원격 branch를 삭제하고 부재를 확인한다.
5. `devel` ref에서 `target_tag=v0.7.18`, `force_pr=false`, `dry_run=false`로 `rhwp Upstream Sync PR`을 dispatch한다.
6. workflow run과 새 PR CI를 완료까지 추적하고 새 base/head SHA, changed paths, provenance를 수집한다.

중단 조건:

- #415 head 또는 target tag resolved commit이 본 보고서 값과 다르면 원격 변경 전에 중단한다.
- branch 삭제가 확인되지 않으면 workflow를 dispatch하지 않는다.
- workflow/build/CI가 실패하면 기존 #415 diff를 대신 채택하지 않는다.
- 새 candidate base가 dispatch 시점의 current `devel`이 아니면 Stage 3으로 진행하지 않는다.

복구 조건:

- workflow가 fresh branch push 후 `gh pr create`에서 기존 closed head/base 이력 때문에 실패하면 fresh branch commit을 먼저 검증한다.
- fresh branch가 최신 `devel` 기준으로 정상 생성된 경우 #415를 reopen하면 같은 head branch의 새 commit을 가리키므로, body/provenance를 fresh run 기준으로 갱신하고 새 후보로 취급할 수 있다.
- branch 생성 전 실패했거나 provenance가 불완전하면 #415를 reopen하지 않고 실패 원인을 보정한 뒤 workflow를 재실행한다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 source, RustBridge dependency/lock, `rhwp-core.lock`, bundled studio asset은 변경하지 않았다.
- `.github/workflows/rhwp-upstream-sync-pr.yml`과 helper script는 read-only로 조사했다.
- `update-rhwp-core.sh --check`는 tracked 변경을 남기지 않았다.
- 이번 단계의 tracked 변경은 Stage 1 보고서와 2026-07-17 오늘할일 문서뿐이다.
- 기존 수행계획서와 구현계획서 본문은 수정하지 않았다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| `gh pr view 415 ...` | OPEN, head/base SHA 보존, 11개 file, CI 4개 SUCCESS, CONFLICTING/DIRTY 확인 |
| `gh release view v0.7.18 ...` | release metadata와 영향 요약 확인 |
| upstream `main`/tag commit API | 둘 다 `93862a4e...` 확인 |
| `git rev-list --left-right --count ...` | `17 1` 확인 |
| `git merge-tree ...` | conflict file이 `rhwp-core.lock`임을 확인 |
| `v0.7.18` `src/wasm_api.rs` | #408 API 세 개 signature 확인 |
| `update-rhwp-core.sh --check` | exit 0, stable tag/commit 확인 |
| workflow source inspection | open PR/branch-only blocker와 dispatch input 확인 |
| tracked worktree 상태 | 조사 후 clean 확인 |

Stage 1 문서 편집 뒤 `git diff --check`를 최종 실행한다.

## 잔여 위험

- 세 API의 존재는 source-level 확인이다. current RustBridge compile/runtime/ABI 검증은 Stage 3에 남아 있다.
- v0.7.18은 2,301개 upstream path와 206개 viewer 영향 path를 포함해 변경 폭이 크다. fresh automation CI 성공만으로 visual/performance 회귀 검증을 대체할 수 없다.
- GitHub가 closed #415와 같은 base/head 조합의 새 PR 생성을 거부할 가능성은 workflow 실행 전 완전히 제거할 수 없다. fresh branch push 이후 실패하는 경우에만 위 reopen 복구 경로를 적용한다.
- upstream checkout의 LFS pointer 경고가 현재 check-only 결과를 막지는 않았지만, workflow 환경에서 다른 phase 실패로 이어지는지는 Stage 2 run으로 확인해야 한다.
- Stage 2는 PR comment/close, 원격 branch delete, workflow dispatch를 포함하는 GitHub mutation 단계다. 중간 실패 시 현재 상태를 그대로 보존하고 다음 mutation 전에 재확인해야 한다.

## 다음 단계 영향

Stage 2에서는 본 보고서에 고정한 증거와 순서에 따라 #415를 superseded 처리하고 최신 `devel` 기준의 fresh `v0.7.18` full sync 후보를 생성한다. 새 후보의 workflow와 PR CI가 완료되기 전에는 product/core diff를 `local/task418`에 적용하지 않는다.

## 승인 요청

Stage 1 `v0.7.18 영향과 자동 후보 재생성 계약 확정`은 완료됐다. Stage 2 `#415 superseded 처리와 최신 자동 full sync 후보 생성`은 원격 PR close, branch 삭제, workflow dispatch를 포함하므로 작업지시자 승인이 필요하다.
