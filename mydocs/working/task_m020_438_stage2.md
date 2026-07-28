# Task M020 #438 Stage 2 보고서

## 단계 목적

Stage 2의 목적은 current `devel`과 PR #436을 결합한 격리 후보에서 native core와 bundled `rhwp-studio`가 같은 upstream stable `v0.8.2` provenance를 사용하는지 독립적으로 검증하는 것이다.

첫 검증에서 `rhwp-core.lock`과 bundled studio는 `v0.8.2`를 가리키지만 `RhwpCoreBuildInfo.swift`는 기존 `v0.7.18`에 남아 있는 blocking mismatch를 발견했다. 작업지시자가 승인한 최소 보정만 PR #436 head에 반영하고, 새 merge candidate에서 Stage 2 전체 gate와 GitHub PR CI를 다시 실행했다. 재발 방지 자동화는 제품 보정과 분리해 후속 Issue #439로 등록했다.

## 산출물

| 산출물 | 결과 |
|--------|------|
| PR #436 보정 commit | `e8d9b4acef5cc827207cc8fc676ccef7d4ce2041` `Task #438 [Stage 2.1]: v0.8.2 core build info 정합화` |
| 새 integration candidate | `/private/tmp/alhangeul-task438.7Mp2aG/integration-v2`, merge ref `2413549de446e63ab5605d5e3590841baea653fa` |
| upstream checkout | `/private/tmp/alhangeul-task438-upstream.nW7rLh/rhwp`, HEAD `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| 후속 자동화 이슈 | [#439 `rhwp Upstream Sync PR에 RhwpCoreBuildInfo 갱신과 검증 gate 추가`](https://github.com/postmelee/alhangeul-macos/issues/439) |
| `mydocs/plans/task_m020_438_impl.md` | 승인된 Stage 2 범위 보정과 후속 Issue #439 경계를 반영했다. |
| `mydocs/working/task_m020_438_stage2.md` | candidate, provenance, artifact, CI와 잔여 위험을 기록한다. |
| `mydocs/orders/20260728.md` | #438을 Stage 2 완료 및 Stage 3 승인 대기 상태로 갱신한다. |

`local/task438`에는 PR #436의 제품 변경이나 generated framework를 복제하지 않았다.

## 후보 identity와 최소 보정

### 최초 발견

첫 integration candidate에서 다음 mismatch를 확인했다.

| 항목 | 최초 PR #436 상태 | target |
|------|------------------|--------|
| `rhwp-core.lock` release tag | `v0.8.2` | `v0.8.2` |
| `rhwp-core.lock` commit | `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` | 동일 |
| bundled studio release tag | `v0.8.2` | `v0.8.2` |
| bundled studio commit | `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` | 동일 |
| `RhwpCoreBuildInfo.releaseTag` | `v0.7.18` | `v0.8.2` |
| `RhwpCoreBuildInfo.commit` | `93862a4e16df59834ebce46d91e948cd739208e9` | `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| `RhwpCoreBuildInfo.enabledFeatures` | `native-skia` | `native-skia` |

`RhwpCoreBuildInfo` 값은 Thumbnail render cache signature에 들어가므로 metadata-only 차이로 무시하지 않았다.

### PR #436 보정

PR head 전용 worktree `/private/tmp/alhangeul-task438-pr436.tTmyKH/head`에서 다음 두 상수만 고쳤다.

- `releaseTag = "v0.8.2"`
- `commit = "9b16aa9e23f476e2b335d7c029fc9f24a199d63c"`

`enabledFeatures`, renderer 동작, lock, bundled asset과 project 설정은 변경하지 않았다. 보정 전 remote head `c9e55c83aaeb9e8104b446e8c15c14f0da40c770`을 parent로 한 fast-forward commit `e8d9b4acef5cc827207cc8fc676ccef7d4ce2041`을 기존 `automation/rhwp-v0.8.2-full-sync` branch에 push했다.

보정 worktree에서 다음 검증을 통과했다.

```text
./scripts/verify-rhwp-core-build-info.sh
OK: RhwpCoreBuildInfo matches rhwp-core.lock

./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies

git diff --check
PASS
```

PR changed path는 기존 17개에 `Sources/RhwpCoreBridge/RhwpCoreBuildInfo.swift` 하나가 추가된 18개다.

### 새 merge candidate

| 구분 | SHA |
|------|-----|
| current `devel` / parent 1 | `c968c1a4a059f31f5e9973900b276bbb00e452cb` |
| corrected PR head / parent 2 | `e8d9b4acef5cc827207cc8fc676ccef7d4ce2041` |
| local fetched merge ref | `2413549de446e63ab5605d5e3590841baea653fa` |
| candidate tree | `cc12016b4feea0320449c6a7c749a400a603bca5` |
| PR CI checkout merge commit | `e2a6b0781f657da0ed8ef5a6e596b487d1a61f9f` |

GitHub이 `synchronize` event에서 새로 만든 CI merge commit은 local fetched merge ref와 commit SHA만 다르다. 두 commit의 parent 쌍과 tree `cc12016b4feea0320449c6a7c749a400a603bca5`는 정확히 같으므로 local Stage 2와 PR CI는 byte-identical source tree를 검증했다.

## Core provenance 검증

### source와 Cargo

| gate | 확인값 | 결과 |
|------|--------|------|
| stable release tag | `v0.8.2` | PASS |
| resolved commit | `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` | PASS |
| feature | `native-skia` | PASS |
| `RustBridge/Cargo.toml` | `tag = "v0.8.2"`, `features = ["native-skia"]` | PASS |
| `RustBridge/Cargo.lock` | `git+https://github.com/edwardkim/rhwp.git?tag=v0.8.2#9b16aa9…` | PASS |
| upstream checkout HEAD | `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` | PASS |
| upstream root `Cargo.lock` SHA-256 | `64ff4041c1874c01c7a901b28df2639082836ced44df392cd37b3227d4772279` | manifest와 일치 |

```bash
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.8.2
```

```text
Checked rhwp core target:
  channel: stable
  tag:     v0.8.2
  commit:  9b16aa9e23f476e2b335d7c029fc9f24a199d63c
```

upstream shallow checkout 중 다음 Git LFS warning이 있었지만 clone과 provenance 검증의 exit status는 0이었다.

```text
Encountered 1 file that should have been a pointer, but wasn't:
    pdf-large/hwpx/2026_oss_rst.pdf
```

경고 대상은 Stage 2~4에서 사용하는 fixture와 PR #436 changed path에 포함되지 않는다.

### external fixture 보존

upstream target checkout에서 Stage 4용 fixture 네 개가 모두 존재한다.

| fixture | bytes | SHA-256 |
|---------|------:|---------|
| `samples/hwp3-sample10-hwpx.hwpx` | 847,607 | `3395e19bebea8b6689f383df1f4ea1ddb253dee91c4320392cc40e90e2e4f191` |
| `samples/oracle.gif` | 1,813 | `464e863dd2c1650fc6997b03a5d96c9413e61bbabaf7337c783db27203cc2761` |
| `samples/rdb02.gif` | 6,098 | `bfadf4cdbbeeb5f3d8632cb54c8c3696977f405204b651f99a7a24c8f39532cf` |
| `samples/s1.jpg` | 16,744 | `77dea18ce7f8f93b0931e133dec222aec642eef0ed87b8f2031b94dcbea5c514` |

과거 `v0.7.18` fixture로 대체하지 않았다.

## Generated artifact 검증

검증 환경은 다음과 같다.

| 도구 | 값 |
|------|----|
| host architecture | `arm64` |
| Rust | `rustc 1.94.1`, `cargo 1.94.1` |
| cbindgen | `0.29.2` |
| Xcode | `26.6`, build `17F113` |

### strict reference

```bash
./scripts/build-rust-macos.sh --verify-lock
```

arm64와 x86_64 build, universal library, generated header, 15개 FFI symbol 및 XCFramework 생성은 완료됐다. strict gate는 `librhwp.a` byte reference 하나에서만 실패했다.

| artifact | lock expected | local actual | 판정 |
|----------|---------------|--------------|------|
| `librhwp.a` SHA-256 | `b35e935283f97c20d41f634f559e623ccd510f54f1341ca83d0f2108345a58eb` | `427e4b88300cb732c0c8986889f4ee45859a5a3e1c9a9f06569ac655d980e26f` | byte mismatch |
| `librhwp.a` bytes | 212,505,600 | 212,514,296 | byte mismatch |
| generated header SHA-256 | `c4cba0728b7e443ba78541dc1184d6aa286b91b72006e423e9283d998c31d8e5` | 동일 | PASS |
| generated header bytes | 3,310 | 3,310 | PASS |
| generated symbol count | 15 | 15 | PASS |
| generated symbols SHA-256 | `91e21eb4203318fb8e22f8645ed7172d3514a7125429d2b5ae2b8013bf42ca4c` | 동일 | PASS |
| generated symbols bytes | 301 | 301 | PASS |

같은 actual static archive hash와 size가 최초 후보와 보정 후 새 후보에서 반복 재현됐다. source commit, Cargo resolution, header와 symbol에는 drift가 없다.

### portable reference

strict 실패가 static archive byte reference 하나로 제한됐으므로 구현계획의 판정 규칙에 따라 portable gate를 실행했다.

```bash
ALHANGEUL_SKIP_RHWP_STATICLIB_HASH_VERIFY=1 \
  ./scripts/build-rust-macos.sh --verify-lock
```

결과: PASS. source provenance, Cargo resolved commit, generated header, 15개 expected/generated FFI symbol과 XCFramework 생성이 모두 통과했다. 따라서 Stage 2 판정은 `portable provenance 통과, strict static archive byte reference 차이 유지`다.

## Bundled studio 검증

```bash
./scripts/verify-rhwp-studio-assets.sh \
  --tag v0.8.2 \
  --commit 9b16aa9e23f476e2b335d7c029fc9f24a199d63c
```

```text
OK: rhwp-studio assets verified at
/private/tmp/alhangeul-task438.7Mp2aG/integration-v2/Sources/HostApp/Resources/rhwp-studio
```

| 항목 | 확인값 |
|------|--------|
| release tag / commit | `v0.8.2` / `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| copied files | 61 |
| copied bytes | 40,176,448 |
| entrypoint | `index.html` |
| main JavaScript | `assets/index-DZp2UYI6.js` |
| stylesheet | `assets/index-CX93BaKm.css` |
| WASM | `assets/rhwp_bg-ftaI0hCm.wasm` |
| additional runtime entry | `print.html` |

manifest file hash, entrypoint, WASM, font, web manifest와 service worker precache graph를 실제 asset과 대조했다. service worker에는 `print.html`과 현재 hashed JS/CSS/WASM asset이 포함돼 있다.

## PR CI 검증

보정 commit push의 `synchronize` event로 생성된 [PR CI run 30348348728](https://github.com/postmelee/alhangeul-macos/actions/runs/30348348728)을 확인했다.

| job | 시작 UTC | 완료 UTC | 결과 |
|-----|----------|----------|------|
| Classify changed files | `2026-07-28T09:51:31Z` | `2026-07-28T09:51:42Z` | SUCCESS |
| Script syntax checks | `2026-07-28T09:51:44Z` | `2026-07-28T09:51:53Z` | SUCCESS |
| Release helper checks | `2026-07-28T09:51:45Z` | `2026-07-28T09:55:48Z` | SUCCESS |
| macOS validation | `2026-07-28T09:51:46Z` | `2026-07-28T10:02:15Z` | SUCCESS |

macOS validation checkout log는 merge commit `e2a6b0781f657da0ed8ef5a6e596b487d1a61f9f`과 parent `c968c1a...`, `e8d9b4a...`를 사용했다. 모든 필수 job이 성공했고 PR은 `OPEN`, `MERGEABLE`, `CLEAN`이다.

Homebrew의 untrusted `aws/tap` 경고가 annotation으로 남았지만 모든 job은 성공했다. source, build 또는 test 실패가 아닌 runner 환경 경고로 분리한다.

## 후속 이슈 분리

full sync workflow가 `RhwpCoreBuildInfo.swift`를 갱신·stage하지 않고 PR CI도 `verify-rhwp-core-build-info.sh`를 실행하지 않는 재발 원인을 제품 보정과 분리했다.

- 이슈: [#439](https://github.com/postmelee/alhangeul-macos/issues/439)
- 상태: `OPEN`
- milestone: `v0.2.x Skia Quick Look/Thumbnail Backend`
- labels: `bug`, `area:core`, `area:ci-cd`, `kind:automation`
- 범위: sync helper/workflow의 build-info 자동 갱신, CI/release 검증 gate와 helper test

Task #438에서는 Issue #439 등록까지만 수행했다. 별도 branch, 오늘할일, 구현계획 또는 `task-start`는 만들지 않았다.

## 본문 변경 정도와 무손실 여부

- PR #436 제품 변경은 `RhwpCoreBuildInfo.swift`의 release tag와 commit 상수 두 줄로 제한했다.
- `local/task438`에는 구현계획 보정, Stage 2 보고서와 오늘할일 상태만 반영했다.
- integration candidate와 upstream checkout의 `git status --short` 출력은 비어 있다.
- candidate에서 `git diff --check`와 `git diff --cached --check`가 모두 통과했다.
- `Alhangeul.xcodeproj`, `project.yml`, renderer, Rust source와 bundled studio asset은 Stage 2 보정으로 수정하지 않았다.

## 검증 결과

| 검증 | 결과 |
|------|------|
| upstream stable target check | PASS |
| upstream target HEAD | PASS |
| Stage 4 fixture 4개 존재 | PASS |
| upstream root Cargo.lock와 studio manifest fingerprint | PASS |
| strict core build/reference | static archive byte reference만 mismatch |
| portable core provenance/reference | PASS |
| generated header | PASS |
| expected/generated FFI symbol 15개 | PASS |
| `RhwpCoreBuildInfo`와 lock 정합성 | PASS |
| bundled studio manifest/files/runtime entry | PASS |
| `RhwpCoreBridge` AppKit/UIKit dependency boundary | PASS |
| 새 candidate PR CI 4개 job | PASS |
| candidate/upstream tracked drift | 없음 |
| 후속 자동화 이슈 등록 | #439 OPEN |

Stage 2 완료 조건을 모두 충족한다. strict static archive byte mismatch는 구현계획에서 허용한 non-blocking 조건에 정확히 한정되며 portable source/header/symbol gate가 통과했다.

## 잔여 위험

- `librhwp.a` lock reference와 현재 Xcode/Rust toolchain의 byte 차이는 해소되지 않았다. Stage 4 release handoff에 expected/actual hash와 size를 그대로 전달해야 한다.
- upstream checkout의 Git LFS warning은 현재 검증 fixture와 무관하지만 upstream repository checkout hygiene 이슈로 남아 있다.
- Stage 2는 provenance와 generated artifact를 검증했다. RustBridge test, ExternalImageTests, app/extension compile·link는 Stage 3에서 확인해야 한다.
- bundled studio runtime, renderer output, Quick Look/Thumbnail surface와 actual Finder 등록은 Stage 4 전까지 미검증 상태다.
- PR #436은 아직 merge하지 않았다.
- 자동 sync/CI 재발 방지는 Issue #439가 구현·merge되기 전까지 수동 검증에 의존한다.

## 다음 단계 영향

Stage 3은 동일 candidate `/private/tmp/alhangeul-task438.7Mp2aG/integration-v2`와 generated `Rhwp.xcframework`를 사용해 다음 항목을 검증한다.

- Rust formatting과 locked RustBridge test
- generated C ABI와 Swift wrapper/lock 정합성
- ExternalImageTests
- `project.yml` 기반 Xcode project 생성 무손실
- HostApp, Quick Look와 Thumbnail extension compile·link

Stage 3 시작 시 current `origin/devel`, PR head, candidate parent/tree와 tracked status를 다시 확인한다. identity가 바뀌면 기존 Stage 2 결과를 새 후보 결과로 간주하지 않는다.

## 승인 요청

Stage 2 `Core·bundled studio provenance와 artifact 검증`은 완료됐다.

다음 단계인 Stage 3 `ABI·external image·앱 target 통합 검증` 진입 승인을 요청한다.
