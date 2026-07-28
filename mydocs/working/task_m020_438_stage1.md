# Task M020 #438 Stage 1 보고서

## 단계 목적

Stage 1의 목적은 upstream `rhwp v0.8.2`, PR #436, current `devel`의 identity와 변경 범위를 고정하고, PR #437의 Task #409 변경을 포함한 충돌 없는 격리 통합 후보를 만드는 것이다.

이 단계에서는 PR branch refresh, PR close/reopen, workflow rerun, PR merge를 실행하지 않는다. GitHub mutation 없이 기존 CI가 검증한 merge tree와 current merge tree를 분리하고, 후속 검증과 새 PR CI가 필요한지 판정한다.

## 산출물

| 산출물 | 결과 |
|--------|------|
| integration candidate | 후보 모드 A인 current GitHub merge ref를 `/private/tmp/alhangeul-task438.7Mp2aG/integration`에 detached worktree로 고정했다. |
| `mydocs/working/task_m020_438_stage1.md` | PR/upstream identity, changed path, candidate, CI refresh 판정과 Stage 2 handoff를 기록한다. |
| `mydocs/orders/20260728.md` | #438을 Stage 1 완료 및 Stage 2 승인 대기 상태로 갱신한다. |

`local/task438`에는 제품 source나 PR #436 generated asset을 복제하지 않았다. candidate worktree는 Stage 2~4에서 같은 결합 상태를 검증하기 위해 유지한다.

## 통합 기준

### 고정 identity

| 구분 | 값 |
|------|----|
| PR | `postmelee/alhangeul-macos#436` |
| PR state | `OPEN` |
| PR mergeability | `MERGEABLE`, `CLEAN` |
| PR base branch | `devel` |
| PR base snapshot | `09953414276c0f31e20193cd9c2f6aa4662df209` |
| current `origin/devel` | `c968c1a4a059f31f5e9973900b276bbb00e452cb` |
| PR head branch | `automation/rhwp-v0.8.2-full-sync` |
| PR head | `c9e55c83aaeb9e8104b446e8c15c14f0da40c770` |
| current merge ref | `e84338cb122e31c1f4b754c4f1ccf5126c9286d9` |
| merge ref parent 1 | `c968c1a4a059f31f5e9973900b276bbb00e452cb` |
| merge ref parent 2 | `c9e55c83aaeb9e8104b446e8c15c14f0da40c770` |
| base/head merge-base | `09953414276c0f31e20193cd9c2f6aa4662df209` |
| upstream release | `v0.8.2` |
| upstream resolved commit | `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` |
| upstream release published | `2026-07-26T15:57:18Z` |

PR head는 구현계획 승인 당시의 `c9e55c8`에서 바뀌지 않았다. current merge ref의 두 parent가 current `origin/devel`과 PR head에 정확히 일치하므로 후보 모드 A를 적용했다.

### upstream 누적 계보

GitHub compare API로 다음 release ancestry를 다시 확인했다.

| 비교 | base | head | ahead | behind | 판정 |
|------|------|------|------:|-------:|------|
| `v0.7.18..v0.7.19` | `93862a4e16df59834ebce46d91e948cd739208e9` | `f137b4c9468eaff5bb43e25108e9c9d39a2ed15b` | 578 | 0 | 순방향 |
| `v0.7.19..v0.8.0` | `f137b4c9468eaff5bb43e25108e9c9d39a2ed15b` | `60911e822b0d0bd4c86e7e98d31e1b13f195c99c` | 1,164 | 0 | 순방향 |
| `v0.8.0..v0.8.2` | `60911e822b0d0bd4c86e7e98d31e1b13f195c99c` | `9b16aa9e23f476e2b335d7c029fc9f24a199d63c` | 112 | 0 | 순방향 |

따라서 닫은 PR #429와 PR #435의 upstream 범위는 PR #436의 target release에 누적돼 있다. 중간 generated asset을 순서대로 반영할 필요가 없다.

### upstream v0.8.2 영향

release note에서 확인한 주요 변화는 다음과 같다.

- v0.8.0부터 빠졌던 브라우저 확장용 `print.html`을 build output에 다시 포함했다.
- 필수 runtime asset 누락 시 build를 실패시키는 gate를 추가했다.
- TAC inline table의 x-origin에 좌우 `outMargin`을 반영했다.
- 알려진 upstream 이슈로 PDF 안내 modal 관련 studio E2E #3450과 page-local repaint 계약 #3412가 남아 있다.

PR #436에는 새 `print.html`, service worker precache 변경, bundled studio entrypoint·WASM·font 변경이 포함된다. Stage 2에서 manifest와 asset provenance를, Stage 4에서 representative runtime smoke를 확인해야 한다.

## 변경 범위와 본문 무손실 여부

### PR #436 changed paths

PR metadata와 `merge-base..head`, `current devel..current merge ref`를 각각 비교했으며 세 경로 집합이 동일한 17개 파일로 확인됐다.

```text
M	RustBridge/Cargo.lock
M	RustBridge/Cargo.toml
D	Sources/HostApp/Resources/rhwp-studio/assets/canvaskit-renderer-C7EpdTSD.js
A	Sources/HostApp/Resources/rhwp-studio/assets/canvaskit-renderer-DZgCuk1Z.js
D	Sources/HostApp/Resources/rhwp-studio/assets/index-BKc-ZB2H.css
A	Sources/HostApp/Resources/rhwp-studio/assets/index-CX93BaKm.css
D	Sources/HostApp/Resources/rhwp-studio/assets/index-D5QjYkw5.js
A	Sources/HostApp/Resources/rhwp-studio/assets/index-DZp2UYI6.js
R054	Sources/HostApp/Resources/rhwp-studio/assets/rhwp_bg-CfVwz6LI.wasm	Sources/HostApp/Resources/rhwp-studio/assets/rhwp_bg-ftaI0hCm.wasm
M	Sources/HostApp/Resources/rhwp-studio/fonts/NotoSansKR-Regular.woff2
M	Sources/HostApp/Resources/rhwp-studio/index.html
M	Sources/HostApp/Resources/rhwp-studio/manifest.json
M	Sources/HostApp/Resources/rhwp-studio/manifest.webmanifest
A	Sources/HostApp/Resources/rhwp-studio/print.html
M	Sources/HostApp/Resources/rhwp-studio/rhwp.d.ts
M	Sources/HostApp/Resources/rhwp-studio/sw.js
M	rhwp-core.lock
```

### current devel advance

PR base snapshot `0995341` 이후 current `devel`에는 PR #437의 source, test, project, script, 운영 문서 19개 경로가 추가·변경됐다.

PR #436의 17개 경로와 이 19개 경로의 교집합은 `0`개다. merge ref도 conflict 없이 생성됐다.

Task #409의 핵심 11개 source·test·project·script blob을 current `devel`과 candidate에서 직접 비교했다.

```text
0cafab7dbc429bf337e9fc2296405424a0207a59 Sources/QLExtension/HwpPreviewProvider.swift
cf0c2fca3634fb94f2a92f9ee2d2335969b2c1b7 Sources/RhwpCoreBridge/RhwpDocument.swift
198721c687d16ee642a53e79fdb776a90239ee4e Sources/Shared/HwpExternalImageResolver.swift
9db5726bd13bb18cd91e5e32a67eb677b1d3ca8f Sources/Shared/HwpPreviewPDFRenderer.swift
a465dccc8994470db447092778cd4d903ba7457a Tests/ExternalImageTests/ExternalImageTestSupport.swift
4dac682f1723d94c36d6a904fba732c4e9796f8a Tests/ExternalImageTests/HwpExternalImageResolverTests.swift
b5048cf7cc4dfadfbf6826e75c2bc3217c17ab55 Tests/ExternalImageTests/RhwpDocumentExternalImageBridgeTests.swift
20a6c017d4fdfae4a1116d0eef6ec29b6b2954e3 project.yml
6ee199667ecf435312d0101a9cf210c94a2c925d scripts/compare-quicklook-pdf-renderers.sh
97adcaaea27bd7ba55e45663b003b6949240a909 scripts/quicklook_skia_policy_smoke.swift
14b06019d0b4c4381fb739feed26d9a392482273 scripts/smoke-quicklook-skia-policy.sh
```

각 행은 base blob SHA와 candidate blob SHA가 같은 경우에만 출력했다. 따라서 candidate에서 Task #409 본문은 byte-identical하게 보존됐다.

`local/task438` 본문에는 Stage 1 보고서와 오늘할일 외 변경이 없고, candidate의 tracked working tree도 clean이다.

## 검증 결과

### PR metadata와 visible checks

```bash
gh pr view 436 --repo postmelee/alhangeul-macos \
  --json state,mergeable,mergeStateStatus,baseRefName,baseRefOid,headRefName,headRefOid,statusCheckRollup,files
```

결과: PR은 `OPEN`, `MERGEABLE`, `CLEAN`이며 changed files는 17개다. visible check 네 개는 모두 성공했다.

| check | 시작 UTC | 완료 UTC | conclusion |
|-------|----------|----------|------------|
| Classify changed files | `2026-07-27T04:39:16Z` | `2026-07-27T04:39:25Z` | SUCCESS |
| Script syntax checks | `2026-07-27T04:39:27Z` | `2026-07-27T04:39:40Z` | SUCCESS |
| macOS validation | `2026-07-27T04:39:27Z` | `2026-07-27T04:48:26Z` | SUCCESS |
| Release helper checks | `2026-07-27T04:39:27Z` | `2026-07-27T04:43:02Z` | SUCCESS |

### 기존 CI와 current merge tree 분리

기존 PR CI run `30237684919`의 macOS job checkout log는 다음 merge ref를 검증했다.

```text
f1ef24c3e4b88439d8f1a1283cb4fd6598cb7ccf
Merge c9e55c83aaeb9e8104b446e8c15c14f0da40c770 into 09953414276c0f31e20193cd9c2f6aa4662df209
```

current `devel`의 PR #437 merge commit `c968c1a`는 기존 run 이후인 `2026-07-28T06:52:45Z`에 생성됐다. current merge ref `e84338c`에는 check run이 `0`개다.

GitHub 문서에 따르면 기존 run의 재실행은 원래 event의 같은 `GITHUB_SHA`와 `GITHUB_REF`를 사용한다. 따라서 run `30237684919`의 단순 rerun은 current merge tree 검증으로 인정할 수 없다.

- [Re-running workflows and jobs](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs)
- [Events that trigger workflows: pull_request](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request)

`.github/workflows/pr-ci.yml`은 `pull_request` activity `types`를 별도로 제한하지 않는다. 새 current merge tree CI에는 기본 activity인 `synchronize` 또는 `reopened` 같은 새 PR event가 필요하다.

### upstream release와 ancestry

```bash
gh release view v0.8.2 --repo edwardkim/rhwp \
  --json tagName,targetCommitish,publishedAt,url,body
```

결과: `v0.8.2`, target branch `main`, published `2026-07-26T15:57:18Z`를 확인했다. tag commit 조회와 compare API는 resolved commit `9b16aa9e23f476e2b335d7c029fc9f24a199d63c`, 각 release 구간 `behind 0`을 반환했다.

### merge-base와 current devel 변경

```bash
git merge-base \
  refs/remotes/origin/devel \
  refs/remotes/origin/pr-436-head
```

```text
09953414276c0f31e20193cd9c2f6aa4662df209
```

```bash
git diff --name-status \
  09953414276c0f31e20193cd9c2f6aa4662df209..origin/devel
```

결과: PR #437의 19개 경로를 확인했다. PR #436 changed path와의 교집합은 0개다.

### integration candidate

```bash
git worktree list --porcelain
git -C /private/tmp/alhangeul-task438.7Mp2aG/integration status --short
```

```text
worktree /private/tmp/alhangeul-task438.7Mp2aG/integration
HEAD e84338cb122e31c1f4b754c4f1ccf5126c9286d9
detached
```

candidate status 출력은 비어 있다. base와 head는 모두 candidate의 ancestor이며, candidate의 두 parent와 계획된 base/head가 정확히 일치한다.

### stable core target

```bash
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.8.2
```

결과: 네트워크 권한이 있는 동일 명령에서 통과했다.

```text
Checked rhwp core target:
  channel: stable
  tag:     v0.8.2
  commit:  9b16aa9e23f476e2b335d7c029fc9f24a199d63c
```

첫 sandbox 실행은 GitHub DNS 제한으로 release tag fetch에 실패했다. 이는 source 또는 provenance 실패가 아니다.

upstream fetch 중 다음 Git LFS warning이 있었지만 명령 exit status는 0이고 stable tag/commit 판정은 성공했다.

```text
Encountered 1 file that should have been a pointer, but wasn't:
	pdf-large/hwpx/2026_oss_rst.pdf
```

해당 upstream sample은 PR #436의 17개 repository changed path에는 없으며, Stage 2의 upstream checkout과 root lock fingerprint 검증에서 source provenance 영향 여부를 다시 구분한다.

### diff와 worktree hygiene

```bash
git diff --check \
  c968c1a4a059f31f5e9973900b276bbb00e452cb..e84338cb122e31c1f4b754c4f1ccf5126c9286d9
git -C /private/tmp/alhangeul-task438.7Mp2aG/integration diff --check
git -C /private/tmp/alhangeul-task438.7Mp2aG/integration diff --cached --check
```

결과: 모두 통과했다. candidate와 `local/task438` working tree에 예상하지 않은 tracked drift가 없다.

## PR refresh와 CI 권고

| 선택지 | 판정 | 근거 |
|--------|------|------|
| PR branch refresh/update | 불필요 | current merge ref가 최신 base/head를 정확히 결합하고 conflict와 changed path 교집합이 없다. |
| 기존 run `30237684919` rerun | 불충분 | 원래 merge ref `f1ef24c`의 SHA/ref를 재사용하므로 current base `c968c1a`를 포함하지 않는다. |
| PR #436 close 후 reopen | 권고 | 제품 commit을 바꾸지 않고 `reopened` event로 current merge ref 대상 PR CI를 새로 생성할 수 있다. |
| PR #436 즉시 merge | 보류 | Stage 2~4 local integration validation과 새 current merge tree CI가 아직 남아 있다. |

close/reopen은 GitHub mutation이므로 이 단계에서 실행하지 않았다. 권고 실행 시 다음 조건을 다시 확인해야 한다.

1. close 직전 `origin/devel`, PR head, merge ref parent가 이 보고서와 동일하다.
2. reopen 후 생성된 PR CI가 current merge ref를 checkout했는지 log에서 확인한다.
3. 네 check가 모두 성공한 뒤에도 Stage 2~4 결과와 함께 merge 승인 여부를 별도로 보고한다.

## 잔여 위험

- current merge candidate는 충돌과 경로 중첩이 없지만 아직 core/studio provenance와 generated artifact를 재생성하지 않았다.
- visible green checks는 old merge tree 결과다. current merge ref에는 GitHub check가 없으므로 merge gate로 충분하지 않다.
- PR #436의 JS/CSS/WASM/font/service worker 변경은 asset graph와 WKWebView runtime 검증 전까지 사용자-facing 무회귀로 판정할 수 없다.
- `v0.8.2` upstream에는 #3450, #3412의 알려진 studio E2E 문제가 남아 있다. 앱의 실제 영향은 Stage 4 smoke 전까지 미확정이다.
- upstream fetch의 Git LFS warning은 stable target 판정을 막지 않았지만 Stage 2 provenance 결과에 함께 기록해야 한다.
- Stage 2 시작 전 `origin/devel`, PR head 또는 merge ref parent가 바뀌면 현재 candidate를 최신 결합 상태로 간주할 수 없다.

## 다음 단계 영향

Stage 2는 `/private/tmp/alhangeul-task438.7Mp2aG/integration`의 exact candidate identity를 먼저 재검사한 뒤 다음 provenance와 artifact gate를 수행한다.

- `rhwp-core.lock`, `RustBridge/Cargo.toml`, `RustBridge/Cargo.lock`의 tag/commit 정합성
- upstream root `Cargo.lock` SHA-256과 bundled studio manifest fingerprint
- generated header, FFI symbols, XCFramework/static library reference metadata
- bundled `rhwp-studio` entrypoint, WASM, service worker, 필수 asset
- RustBridge format/test와 shared Swift dependency boundary

PR close/reopen은 Stage 2 source 검증과 독립적으로 지금 실행할 수 있지만, GitHub mutation 승인과 새 CI 확인을 별도로 기록해야 한다. PR merge는 Stage 2~4 및 새 current merge tree CI가 모두 완료될 때까지 실행하지 않는다.

## 승인 요청

Stage 1 `PR·upstream 영향과 current 통합 후보 고정`은 완료됐다.

다음 작업을 진행하려면 작업지시자 승인이 필요하다.

1. Stage 2 `core/studio provenance와 artifact gate` 실행
2. PR #436을 close 후 reopen해 current merge ref 대상 새 PR CI 실행
