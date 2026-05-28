# Task M020 #278 Stage 1 완료 보고서

## 단계 목적

`edwardkim/rhwp` `v0.7.13` stable release를 앱 core 기준으로 올리기 전에 release provenance, 현재 lock 상태, bundled `rhwp-studio` 동기화 필요성, #282 후속 작업 영향을 확정했다.

## 확인한 release 기준

`v0.7.13`은 GitHub Release 기준 최신 release이며 draft나 prerelease가 아니다.

```text
v0.7.13 — HWPX 렌더링/저장 호환성 + 시험지/공공기관 문서 회귀 정정
publishedAt: 2026-05-26T13:57:15Z
tag: v0.7.13
targetCommitish: main
url: https://github.com/edwardkim/rhwp/releases/tag/v0.7.13
```

태그 resolved commit은 다음 값으로 확인했다.

```text
b3e16ef212af81ef37d973ddb86d6816d3804642 refs/tags/v0.7.13
```

`scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13`도 같은 commit을 반환했다.

```text
Checked rhwp core target:
  channel: stable
  tag:     v0.7.13
  commit:  b3e16ef212af81ef37d973ddb86d6816d3804642
```

## 현재 앱 기준

현재 앱 저장소는 core와 bundled viewer 모두 `v0.7.12` 기준이다.

| 항목 | 현재 값 |
| --- | --- |
| `rhwp-core.lock` release tag | `v0.7.12` |
| `rhwp-core.lock` commit | `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` |
| `RustBridge/Cargo.toml` dependency | `tag = "v0.7.12"`, `features = ["native-skia"]` |
| `RustBridge/Cargo.lock` rhwp source | `git+https://github.com/edwardkim/rhwp.git?tag=v0.7.12#1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` |
| bundled `rhwp-studio` manifest tag | `v0.7.12` |
| bundled `rhwp-studio` manifest commit | `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` |

## upstream impact 결과

`v0.7.12..v0.7.13` 사이 변경을 `scripts/ci/detect-rhwp-studio-impact.sh`로 계산했다.

```text
changed paths: 1347
impact paths: 427
has viewer impact: true
```

impact path 분류는 다음과 같다.

| 분류 | 파일 수 |
| --- | ---: |
| Rust/core source or build input | 395 |
| rhwp-studio source or build input | 32 |

특히 다음 범위가 Quick Look/Thumbnail과 #282에 직접 영향을 준다.

- `src/document_core/queries/rendering.rs`: `get_page_overlay_images_native`가 `ResolvedImagePayload`를 사용하고 `bakedWatermark`를 JSON에 낸다.
- `src/paint/paint_op.rs`, `src/paint/json.rs`: `PaintOp::Image`에 `resolved` payload가 추가되고 PageLayerTree image JSON도 resolved payload와 `bakedWatermark`를 반영한다.
- `src/renderer/image_resolver.rs`: BMP/PCX PNG 변환, watermark JPEG bake, effect suppress 정책이 추가됐다.
- `src/renderer/skia/renderer.rs`: Skia image replay가 resolved payload와 suppress effect 경로를 사용한다.
- `src/paint/json.rs`, `src/renderer/pua_oldhangul.rs`: PageLayerTree `text.displayText`와 PUA 옛한글 표시 문자열 관련 변경이 포함되어 있다.
- `rhwp-studio/src/view/canvaskit-renderer.ts`, `rhwp-studio/src/view/canvaskit/image-replay.ts`, `rhwp-studio/src/core/wasm-bridge.ts`: WebView reference renderer와 WASM bridge도 변경됐다.

## 판단

core update는 #282 Stage 3 전에 먼저 적용하는 것이 맞다. #282 Stage 3가 `v0.7.12` 기준 overlay/image payload를 대상으로 Swift compositor를 확장하면 `v0.7.13`의 `resolved`, `bakedWatermark`, PUA `displayText` 경로를 다시 맞춰야 한다.

bundled `rhwp-studio` sync도 #278 범위에 포함하는 것이 맞다. `has viewer impact=true`이고 `rhwp-studio` 및 WASM bridge 변경이 포함되어 있으므로, core만 `v0.7.13`으로 올리고 visual diff reference를 `v0.7.12`에 남기면 Stage 4 수치가 서로 다른 renderer 기준을 비교하게 된다.

#282에 대한 handoff는 다음과 같다.

- #278 PR merge 후 #282 branch는 최신 `devel`에 재정렬해야 한다.
- #282 Stage 3의 native compositor는 overlay metadata뿐 아니라 PageLayerTree image node의 `resolved`/`bakedWatermark` 상태를 같이 고려해야 한다.
- PUA 표시 문자열은 PageLayerTree `displayText`를 소비하는 방향으로 이어가는 것이 맞다. Swift 쪽에서 별도 PUA mapping을 복제하는 방식은 core update마다 유지보수 비용이 커진다.
- 이번 Stage 1 기준으로 upstream 추가 기여가 #278 진행의 선행 조건은 아니다. 다만 external linked image 주입 API류는 별도 upstream 개선 과제로 남는다.

## 검증 결과

실행한 검증:

```bash
git ls-remote --tags https://github.com/edwardkim/rhwp.git 'refs/tags/v0.7.13*'
gh release view v0.7.13 --repo edwardkim/rhwp --json tagName,targetCommitish,publishedAt,url,isDraft,isPrerelease,name
gh release list --repo edwardkim/rhwp --limit 5
./scripts/update-rhwp-core.sh --check --channel stable --tag v0.7.13
./scripts/ci/detect-rhwp-studio-impact.sh --upstream-dir /private/tmp/rhwp-upstream-v0713 \
  --current-tag v0.7.12 \
  --current-commit 1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5 \
  --target-tag v0.7.13 \
  --target-commit b3e16ef212af81ef37d973ddb86d6816d3804642 \
  --output-dir /private/tmp/task278-stage1-impact
```

결과:

- `v0.7.13` release/tag/resolved commit 확인 성공
- update script check 성공
- viewer impact 감지 성공: `changed=1347`, `impact=427`, `has_viewer_impact=true`

## 잔여 위험

- Stage 2의 실제 RustBridge build에서 macOS universal static archive 생성 시간과 산출물 크기가 늘 수 있다.
- `librhwp.a` byte hash는 toolchain과 build path에 민감하므로 Stage 2에서는 source provenance, generated header, FFI symbol set을 별도로 해석해야 한다.
- Stage 3에서 upstream `pkg/`와 `rhwp-studio/dist`가 준비되지 않은 checkout을 사용하면 sync script가 실패한다. 필요하면 upstream build 절차를 먼저 수행해야 한다.
- Stage 4 visual diff 값은 #280 harness readiness에 영향을 받는다. readiness 문제가 재발하면 smoke 성공 여부와 visual diff 수치를 분리해 기록한다.

## 다음 단계 영향

Stage 2에서는 core dependency와 RustBridge 산출물을 먼저 `v0.7.13`으로 갱신한다. Stage 3에서는 bundled `rhwp-studio`를 같은 release 기준으로 맞춘다. Stage 4에서야 Quick Look/Thumbnail smoke와 visual diff를 실행한다.

## 승인 요청

Stage 2로 진행하려면 `scripts/update-rhwp-core.sh --channel stable --tag v0.7.13`와 `scripts/build-rust-macos.sh --update-lock` 실행 승인이 필요하다.
