# Task M020 #418 Stage 2 보고서

## 단계 목적

stale PR #415와 기존 automation branch를 superseded 처리하고, 최신 `devel`에서 `rhwp v0.7.18` full sync workflow를 다시 실행해 fresh automation candidate와 PR CI를 생성·검증한다.

이 단계에서는 자동 후보의 product/core diff를 `local/task418`에 적용하거나 자동 PR을 merge하지 않는다. 원격 후보 생성과 CI 완료까지만 수행한다.

## 산출물

| 산출물 | 결과 |
|--------|------|
| PR #415 보존 코멘트 | [issuecomment-4993627733](https://github.com/postmelee/alhangeul-macos/pull/415#issuecomment-4993627733) |
| stale PR | [#415](https://github.com/postmelee/alhangeul-macos/pull/415) closed |
| stale automation branch | 삭제 후 부재 확인, fresh workflow가 같은 이름으로 재생성 |
| full sync workflow | [run 29511003883](https://github.com/postmelee/alhangeul-macos/actions/runs/29511003883) SUCCESS |
| fresh candidate PR | [#419 Sync rhwp upstream v0.7.18](https://github.com/postmelee/alhangeul-macos/pull/419) |
| `mydocs/working/task_m020_418_stage2.md` | Stage 2 원격 변경, workflow/CI, provenance 결과 기록 |
| `mydocs/orders/20260717.md` | #418을 Stage 2 완료 및 Stage 3 승인 대기로 갱신 |

## 원격 변경 결과

### 실행 전 재확인

원격 변경 직전에 Stage 1 보존값이 유지되는지 다시 확인했다.

| 항목 | 확인값 |
|------|--------|
| #415 state | `OPEN` |
| #415 base | `477447f2a06f6b28f6ed17c804ea994a5b693dd7` |
| #415 head | `bd813821db9ea1e6a6d30bf3c540ecb915bccbf6` |
| current `origin/devel` | `dda97c7000fe12e7ed925e4e8a8d2b71f44fc46f` |
| `v0.7.18` resolved commit | `93862a4e16df59834ebce46d91e948cd739208e9` |

모든 값이 Stage 1 계약과 일치해 원격 mutation을 진행했다.

### #415 superseded 처리

저장소의 `scripts/validate-github-body.sh`를 통과한 body-file로 다음 내용을 공개 기록했다.

- stale base/head/current devel SHA
- target release와 resolved commit
- 기존 CI 성공은 보존하지만 #408/#406 merge 전 후보라는 점
- `rhwp-core.lock` artifact metadata를 수동 선택하지 않는 이유
- 최신 `devel`에서 workflow를 다시 실행한다는 처리 방향

코멘트 등록 후 #415를 close했다. 이어서 `automation/rhwp-v0.7.18-full-sync` 원격 branch를 삭제했고, `git ls-remote --exit-code --heads`가 exit 2와 빈 출력을 반환해 부재를 확인했다.

### workflow dispatch

다음 입력으로 workflow를 실행했다.

```text
workflow: rhwp Upstream Sync PR
ref: devel
target_tag: v0.7.18
force_pr: false
dry_run: false
```

workflow head SHA는 dispatch 시점의 current `devel`인 `dda97c7000fe12e7ed925e4e8a8d2b71f44fc46f`다.

| job | 결과 | 소요 |
|-----|------|------|
| Resolve rhwp full sync target | SUCCESS | 29초 |
| Build upstream rhwp-studio assets | SUCCESS | 6분 46초 |
| Create rhwp full sync PR candidate | SUCCESS | 9분 34초 |

candidate job의 `Apply full sync and create PR` step은 성공했다. Homebrew가 기존 `aws/tap`을 trusted tap으로 보지 않는다는 annotation이 한 건 있었지만 설치와 build는 성공했고 workflow conclusion은 `success`다.

## Fresh candidate 검증

### PR metadata

| 항목 | 값 |
|------|----|
| PR | [#419](https://github.com/postmelee/alhangeul-macos/pull/419) |
| state | `OPEN`, `isDraft=false` |
| base | `devel` / `dda97c7000fe12e7ed925e4e8a8d2b71f44fc46f` |
| head | `automation/rhwp-v0.7.18-full-sync` / `bdea7f557d8de3ca5e11913cd691f06052076d0d` |
| mergeability | `MERGEABLE`, `mergeStateStatus=CLEAN` |
| repository changed paths | 11개 |
| upstream changed paths | 2,301개 |
| viewer/WASM/core impact paths | 206개 |

fresh head는 stale #415 head와 다른 commit이며 base는 Stage 2 dispatch 시점의 exact current `devel`이다. 같은 branch 이름의 새 PR이 정상 생성됐으므로 Stage 1의 reopen fallback은 사용하지 않았다.

### 실제 changed paths

`git diff --name-status origin/devel...origin/automation/rhwp-v0.7.18-full-sync` 결과는 PR body의 11개 repository path와 일치한다.

```text
M    RustBridge/Cargo.lock
M    RustBridge/Cargo.toml
R    CanvasKit renderer hashed JS
D    previous main hashed JS
R    main hashed CSS
A    new main hashed JS
R    WASM hashed asset
M    rhwp-studio/index.html
M    rhwp-studio/manifest.json
M    rhwp-studio/sw.js
M    rhwp-core.lock
```

실제 rename 대상의 full path와 score는 PR diff에 보존돼 있다. `Frameworks/**`, `Alhangeul.xcodeproj`, source ABI 파일은 candidate commit에 포함되지 않았다.

### Core provenance

fresh `rhwp-core.lock`:

| 필드 | 값 |
|------|----|
| release tag | `v0.7.18` |
| resolved commit | `93862a4e16df59834ebce46d91e948cd739208e9` |
| feature | `native-skia` |
| built_at | `2026-07-16T15:41:16Z` |
| `librhwp.a` SHA-256 | `f9adfd52bbc4fc058fa289210ed693ca6c939efd28f39106118c6840b21bf62f` |
| `librhwp.a` size | `208697904` bytes |
| generated header SHA-256 | `c4cba0728b7e443ba78541dc1184d6aa286b91b72006e423e9283d998c31d8e5` |
| generated header size | `3310` bytes |

`RustBridge/Cargo.lock`의 `rhwp` package도 version `0.7.18`과 같은 tag/resolved commit을 기록한다.

```text
git+https://github.com/edwardkim/rhwp.git?tag=v0.7.18#93862a4e16df59834ebce46d91e948cd739208e9
```

`rhwp-ffi-symbols.txt`, `RustBridge/src/lib.rs`, `RustBridge/cbindgen.toml`은 current `devel`과 candidate 사이에 diff가 없다. 따라서 #408의 15개 expected symbol/source 계약을 그대로 둔 current RustBridge에서 새 core build가 성공했다.

### Studio provenance

fresh bundled manifest:

| 필드 | 값 |
|------|----|
| release tag | `v0.7.18` |
| resolved commit | `93862a4e16df59834ebce46d91e948cd739208e9` |
| upstream `Cargo.lock` SHA-256 | `5cf25bdd98a070906ff6c78126f8384bb3122db974143dcd8e39cd3099359045` |
| copied files | 60개 / 39,392,653 bytes |
| main JS | `assets/index-D5QjYkw5.js` / `bdee757d...` |
| main CSS | `assets/index-BKc-ZB2H.css` / `b9b38979...` |
| WASM | `assets/rhwp_bg-CfVwz6LI.wasm` / `84334029...` |

local overlay인 `alhangeul-wkwebview-overrides.css`와 `fonts/FONTS.md`도 manifest에 유지됐다.

### PR CI

[PR CI run 29512295376](https://github.com/postmelee/alhangeul-macos/actions/runs/29512295376)의 네 check가 모두 성공했다.

| check | 결과 | 소요 |
|-------|------|------|
| Classify changed files | SUCCESS | 10초 |
| Script syntax checks | SUCCESS | 10초 |
| Release helper checks | SUCCESS | 3분 21초 |
| macOS validation | SUCCESS | 6분 31초 |

## 본문 변경 정도 / 본문 무손실 여부

- `local/task418`에는 자동 candidate의 product/core/studio diff를 아직 적용하지 않았다.
- tracked source 변경은 Stage 2 보고서와 오늘할일 상태 갱신뿐이다.
- #415의 기존 commit과 CI URL은 Stage 1 보고서 및 공개 코멘트에 보존했다.
- 원격 branch 이름은 fresh workflow가 재사용했지만 head commit은 stale `bd81382...`에서 fresh `bdea7f5...`로 교체됐다.
- 임시 GitHub comment body-file은 공개 등록과 검증 후 삭제했다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| `scripts/validate-github-body.sh <comment-body>` | 통과 |
| `gh pr close 415 ...` | #415 closed |
| `git push origin --delete automation/rhwp-v0.7.18-full-sync` | stale branch 삭제 성공 |
| `git ls-remote --exit-code --heads ...` | exit 2, 삭제 직후 부재 확인 |
| `gh workflow run ...` | run `29511003883` 생성 |
| `gh run watch 29511003883 --exit-status` | 세 job SUCCESS |
| `gh pr checks 419 --watch` | 네 check SUCCESS |
| `gh pr view 419 ...` | OPEN, MERGEABLE/CLEAN, base/head/provenance 확인 |
| 실제 remote diff | PR body와 같은 11개 path |
| current ABI source diff | `rhwp-ffi-symbols.txt`, `RustBridge/src/lib.rs`, `cbindgen.toml` 무변경 |

Stage 2 문서 편집 뒤 `git diff --check`를 최종 실행한다.

## 잔여 위험

- #419는 automation candidate이며 merge 대상 결정을 하지 않았다. Task #418의 최종 PR로 사용하지 않는다.
- candidate runner에서 생성한 static library hash/size는 fresh current source 기준이지만, Stage 3에서 `local/task418`에 적용한 뒤 로컬 toolchain으로 다시 생성·검증해야 한다.
- PR CI 성공은 compile/build/provenance gate다. 2,301개 upstream path의 visual/performance 영향은 Stage 4 smoke와 baseline 비교에 남아 있다.
- Homebrew tap trust annotation은 이번 run을 막지 않았지만 runner 정책이 바뀌면 dependency 설치 경로에 영향을 줄 수 있다.
- #415는 closed 상태이고 같은 remote branch 이름은 #419가 사용한다. Stage 3 이후 #419 처리와 branch cleanup은 별도 승인과 최종 정리 절차에서 다룬다.

## 다음 단계 영향

Stage 3에서는 fresh automation commit `bdea7f557d8de3ca5e11913cd691f06052076d0d`의 sync diff를 `local/task418`에 무커밋으로 적용한다. 이후 current task source에서 Rust static library/header를 다시 생성하고, 15개 symbol, `rhwp-core.lock`, bundled manifest, upstream `Cargo.lock` fingerprint를 직접 검증한 뒤 source와 Stage 3 보고서를 한 커밋으로 묶는다.

## 승인 요청

Stage 2 `#415 superseded 처리와 최신 자동 full sync 후보 생성`은 완료됐다. Stage 3 `자동 후보를 task branch에 통합하고 provenance 고정`으로 진행하려면 작업지시자 승인이 필요하다.
