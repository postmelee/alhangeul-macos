# Task M014 #281 Stage 1 보고서 - overlay metadata API inventory 정리

## 단계 개요

- 이슈: #281 PageLayerTree overlay image metadata를 Swift preview 입력으로 연결
- 단계: Stage 1. API inventory와 구현 경로 확정
- 목표: 현재 앱 lock `v0.7.12`와 upstream release `v0.7.13`의 overlay/PageLayerTree API와 JSON schema를 비교하고, #281에서 사용할 구현 경로를 확정한다.

이번 단계는 조사와 문서화만 수행했다. `RustBridge`, Swift source, bundled `rhwp-studio` asset, `rhwp-core.lock`은 수정하지 않았다.

## 기준 버전과 입력

| 항목 | 값 |
|------|----|
| 현재 앱 core lock | `v0.7.12` |
| 현재 앱 resolved commit | `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5` |
| 현재 앱 enabled feature | `native-skia` |
| 비교 대상 upstream release | `v0.7.13` |
| 비교 대상 resolved commit | `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| release 성격 | 정식 release, draft/pre-release 아님 |

`v0.7.13` release note 기준 주요 범위는 HWPX 렌더링/저장 호환성, 조판 회귀 정정, rhwp-studio/extension UX 보강이다. #281에서 직접 필요한지 확인한 항목은 overlay image metadata, PageLayerTree image paint op, Studio overlay render path다.

## upstream API inventory

| 영역 | `v0.7.12` | `v0.7.13` | #281 영향 |
|------|-----------|-----------|-----------|
| `build_page_layer_tree` | 존재 | 존재 | PageLayerTree 기반 metadata 소스는 두 버전 모두 가능하다. |
| `get_page_layer_tree_native` | 존재 | 존재 | RustBridge C ABI로 문자열 JSON을 노출할 수 있는 upstream 진입점이 이미 있다. |
| `get_page_overlay_images_native` | 존재 | 존재 | Studio overlay path와 가장 가까운 compact JSON 진입점이다. |
| `LayerFilter` | `All`, `FlowOnly`, `WrapOnly` | 동일 | behind/front overlay 분리 의미는 유지된다. |
| PageLayerTree schema minor | `11` | `14` | minor schema가 증가했으므로 Swift decoder는 unknown field를 허용해야 한다. |
| `PaintOp::Image` | `bbox`, `image` | `bbox`, `image`, optional `resolved` | `v0.7.13`은 resolved image payload를 통해 변환/워터마크 bake 결과를 전달한다. |
| compact overlay top-level | `behind`, `front`, `imageCount` | 동일 | Swift 입력 contract는 top-level shape를 안정적으로 둘 수 있다. |
| compact overlay image fields | `bbox`, `mime`, `base64`, `effect`, `brightness`, `contrast`, `wrap`, optional `watermark`, `transform` | 동일 + optional `bakedWatermark` | `bakedWatermark`는 forward-compatible optional field로 모델에 포함할 필요가 있다. |
| compact overlay의 resource id | 없음 | 없음 | `binDataId`, bytes availability, crop/fill/original size는 compact overlay JSON만으로는 부족하다. |
| PageLayerTree image JSON | image payload, fill/crop/effect/transform 계열 포함 | resolved payload와 `bakedWatermark` 추가 | 전체 PageLayerTree를 쓰면 더 많은 속성을 얻지만, Swift에서 파싱할 범위가 커진다. |

핵심은 `v0.7.13`이 overlay API를 교체하지 않고 같은 public surface 위에 image payload semantics를 보강했다는 점이다. 따라서 #281에서 입력 contract를 만들 때 `v0.7.12`만 보고 좁게 설계하면 `v0.7.13` update 직후 다시 모델을 고쳐야 한다.

## Studio render path 비교

| 항목 | `v0.7.12` | `v0.7.13` | 판단 |
|------|-----------|-----------|------|
| Studio overlay source | `wasm.getPageOverlayImages(pageIdx)` 우선, 실패 시 PageLayerTree fallback | 동일 | native preview도 같은 compact overlay JSON을 우선 입력으로 쓰는 편이 Studio parity에 맞다. |
| `OverlayImageInfo` | `bbox`, `mime`, `base64`, `effect`, `brightness`, `contrast`, optional `watermark`, `wrap`, `transform` | 동일 + `bakedWatermark?: boolean` | Swift model에 `bakedWatermark` optional을 넣어야 다음 core update를 흡수할 수 있다. |
| CSS filter/watermark 처리 | effect/brightness/contrast, watermark를 overlay layer에서 적용 | `bakedWatermark`이면 CSS filter와 watermark blend를 건너뜀 | #282 compositor가 `bakedWatermark`를 모르면 v0.7.13 전환 후 워터마크를 이중 처리할 위험이 있다. |
| CanvasKit/Skia Studio backend | 제한적 | backend/profile 선택 경로 추가 | #281은 backend 전환보다 overlay metadata contract를 먼저 고정한다. |

현재 앱에 bundled된 `Sources/HostApp/Resources/rhwp-studio/rhwp.js`에는 `getPageOverlayImages` wrapper가 있지만, `rhwp.d.ts`에서는 `getPageLayerTree` 선언만 확인되고 `getPageOverlayImages` 선언은 보이지 않는다. 이는 bundled Studio type declaration의 불완전성으로 보이며, Swift bridge 구현 판단에는 직접 blocker가 아니다.

## 앱 bridge inventory

| 영역 | 현재 상태 | 판단 |
|------|-----------|------|
| `RustBridge/src/lib.rs` | `rhwp_render_page_tree`, `rhwp_render_page_png`, `rhwp_image_data` 중심 | dedicated overlay/PageLayerTree C ABI는 아직 없다. |
| `rhwp-ffi-symbols.txt` | `rhwp_image_data`, `rhwp_render_page_png`, `rhwp_render_page_tree` 등만 기록 | 새 ABI를 추가하면 symbol manifest도 함께 갱신해야 한다. |
| `Sources/RhwpCoreBridge/RhwpDocument.swift` | render tree JSON, page PNG, image data wrapper 보유 | overlay JSON wrapper를 붙일 Swift entry point가 있다. |
| `Sources/RhwpCoreBridge/RenderTree.swift` `ImageNode` | `binDataId`, `fillMode`, `originalSize`, `originalSizeHU`, `effect`, `brightness`, `contrast`, `textWrap`, `transform`, `crop` decode | compact overlay JSON이 부족한 resource/crop/fill metadata는 render tree fallback/merge로 보충할 수 있다. |

현재 Swift render tree traversal만으로도 overlay 후보와 `binDataId` 기반 bytes availability는 만들 수 있다. 다만 Studio가 실제로 쓰는 overlay bytes와 `v0.7.13`의 resolved/baked payload 의미는 render tree JSON만으로는 얻기 어렵다.

## 구현 경로 결정

Stage 2 구현 경로는 hybrid provider로 고정한다.

1. 1차 입력은 RustBridge C ABI를 새로 추가해 upstream `get_page_overlay_images_native` JSON을 Swift로 전달한다.
2. Swift model은 compact overlay JSON shape를 기준으로 `behind`, `front`, `imageCount`, image별 `bbox`, `mime`, `base64`, `effect`, `brightness`, `contrast`, `watermark`, `wrap`, `transform`, optional `bakedWatermark`를 decode한다.
3. `binDataId`, bytes availability, `fillMode`, `originalSize`, `crop`처럼 compact overlay JSON에 없는 정보는 기존 `renderPageTree(at:)` traversal 결과와 병합하거나 보조 provider로 제공한다.
4. PageLayerTree 전체 JSON C ABI는 Stage 2의 1차 구현 대상에서 제외한다. compact overlay + render tree 보충으로 #282 입력 contract를 만들고, 전체 PageLayerTree parser는 필요한 필드가 더 늘어날 때 별도 판단한다.
5. #281 안에서는 core pin을 `v0.7.13`으로 올리지 않는다. `v0.7.13`은 `bakedWatermark`/resolved image payload 때문에 preview 정확도에 의미가 있지만, dependency update와 metadata contract 구현을 한 PR에 섞으면 검증 원인이 흐려진다.

## `v0.7.13` 반영 판단

`v0.7.13`은 #281의 구현 방향을 바꿀 만큼 중요하지만, 지금 즉시 pin update를 섞을 필요는 없다.

| 판단 | 이유 |
|------|------|
| Stage 2 model에는 `bakedWatermark`를 포함 | `v0.7.13` compact overlay JSON과 Studio path가 이미 이 field를 사용한다. |
| Stage 2 ABI는 현재 lock `v0.7.12` 기준으로 추가 가능 | `get_page_overlay_images_native`가 `v0.7.12`에도 존재한다. |
| core update는 별도 작업으로 분리 | `v0.7.13`은 PageLayerTree schema minor와 renderer semantics를 바꾸므로 #281 검증과 dependency update 검증을 분리하는 편이 추적 가능하다. |
| #282 전 또는 #282 초기에 update 여부 재판단 | `bakedWatermark`가 실제 visual diff에 영향을 줄 수 있으므로 compositor 구현 전후에 별도 core update smoke를 두는 것이 좋다. |

## 관찰된 한계

- `/private/tmp/rhwp-v0.7.13` source 확인 중 Git LFS smudge가 quota 오류로 실패했다. 필요한 Rust/TypeScript source file은 checkout되어 static inventory에는 충분했지만, 해당 임시 clone을 완전한 working tree로 취급하지 않았다.
- 이번 단계는 source inventory라서 sample별 overlay count나 visual diff 수치는 만들지 않았다. metadata smoke와 수치 비교는 Stage 3-4에서 수행한다.
- compact overlay JSON은 Studio parity에는 좋지만 `binDataId`, `crop`, `fillMode`, `originalSize`가 없다. 따라서 #282가 resource identity나 crop/fill-aware CGContext 합성을 요구하면 render tree 보충이 필요하다.
- `v0.7.13`의 resolved payload는 preview 정확도에 유리하지만 현재 앱 lock은 `v0.7.12`다. Stage 2 구현은 optional field 중심으로 forward-compatible하게 두고, 실제 resolved payload 관찰은 core update 이후 가능하다.

## Stage 1 검증

실행:

```bash
rg -n "rhwp_release_tag|rhwp_commit|rhwp_ref_kind|rhwp_enabled_features" rhwp-core.lock
rg -n "rhwp =|source = .*rhwp|name = \"rhwp\"" RustBridge/Cargo.toml RustBridge/Cargo.lock
git ls-remote --tags https://github.com/edwardkim/rhwp.git 'refs/tags/v0.7.13'
gh release view v0.7.13 --repo edwardkim/rhwp --json tagName,targetCommitish,name,publishedAt,body,isDraft,isPrerelease
rg -n "get_page_overlay_images_native|get_page_layer_tree_native|build_page_layer_tree|schema_minor_version|ResolvedImagePayload|bakedWatermark|PaintOp::Image|enum LayerFilter" \
  /Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/1899ef9/src \
  /private/tmp/rhwp-v0.7.13/src
rg -n "getPageOverlayImages|getPageLayerTree|bakedWatermark|OverlayImageInfo|createOverlayLayer|CanvasKitLayerRenderer|backend" \
  /Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/1899ef9/rhwp-studio/src \
  /private/tmp/rhwp-v0.7.13/rhwp-studio/src \
  Sources/HostApp/Resources/rhwp-studio/rhwp.d.ts \
  Sources/HostApp/Resources/rhwp-studio/rhwp.js
rg -n "rhwp_render_page_tree|rhwp_image_data|rhwp_render_page_png|overlay|layer_tree" \
  RustBridge/src/lib.rs rhwp-ffi-symbols.txt Sources/RhwpCoreBridge
git diff --check
```

결과:

- 현재 lock은 `v0.7.12` release tag와 resolved commit `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5`로 확인했다.
- `v0.7.13` release tag는 `b3e16ef212af81ef37d973ddb86d6816d3804642`로 확인했다.
- `v0.7.12`와 `v0.7.13` 모두 `get_page_overlay_images_native`, `get_page_layer_tree_native`, `build_page_layer_tree`를 제공한다.
- `v0.7.13`은 `PaintOp::Image`에 resolved image payload와 `bakedWatermark` JSON semantics를 추가한다.
- 현재 앱 RustBridge에는 overlay/PageLayerTree 전용 C ABI가 없다.
- 문서 작성 전 production source diff는 없었고, `git diff --check`는 통과했다.

## 다음 단계

Stage 2에서는 위 결정에 따라 RustBridge compact overlay JSON C ABI와 Swift overlay metadata model/provider를 추가한다. 구현은 현재 lock `v0.7.12`에서 동작하게 만들고, model은 `v0.7.13`의 `bakedWatermark`를 optional field로 수용한다. Stage 2 진행은 작업지시자 승인 후 시작한다.
