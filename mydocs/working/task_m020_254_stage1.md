# Task M020 #254 Stage 1 보고서

## 단계 목적

Stage 1의 목적은 Skia를 Quick Look/Thumbnail의 optional backend로 검토하기 전에 현재 앱의 실제 렌더링 경로와 upstream `rhwp`의 사용 가능 표면을 분리해 확정하는 것이다. 이 단계에서는 제품 코드와 bridge ABI를 변경하지 않고 inventory만 남긴다.

## 산출물

| 파일 | 요약 |
|---|---|
| `mydocs/working/task_m020_254_stage1.md` | 현재 Quick Look/Thumbnail 경로, FFI 표면, upstream Skia 적용 후보, 관련 이슈 책임 경계 정리. 142 lines |
| `mydocs/orders/20260518.md` | #254 상태를 Stage 1 완료 및 Stage 2 승인 대기 상태로 갱신. 7 lines |

## 현재 Quick Look/Thumbnail 렌더 흐름

현재 앱의 Quick Look/Thumbnail 경로는 upstream Skia PNG가 아니라 `PageRenderTree` JSON을 Swift에서 해석하는 CoreGraphics/CoreText 경로다.

1. `RustBridge/src/lib.rs`는 `rhwp_render_page_tree`를 C ABI로 노출하고, 내부에서 `h.doc.build_page_render_tree(page)` 결과의 `tree.root`를 JSON으로 직렬화한다.
2. `Sources/RhwpCoreBridge/RhwpDocument.swift`는 `renderPageTree(at:)`, `renderPageTreeJSON(at:)`, `pageSize(at:)`, `imageData(binDataId:)`만 Swift API로 제공한다. PNG raster API는 없다.
3. `Sources/Shared/HwpPageImageRenderer.swift`는 `RhwpDocument.renderPageTree(at:)`와 `pageSize(at:)`를 읽어 `CGContext`에 `CGTreeRenderer`로 그린 뒤 `CGImage`를 반환한다.
4. `Sources/QLExtension/HwpPreviewProvider.swift`는 단일 페이지 문서에서는 해당 `CGImage`를 PNG로 인코딩해 Quick Look reply를 만들고, 다중 페이지 문서에서는 `HwpPreviewPDFRenderer`가 각 페이지 bitmap을 PDF page에 그린다.
5. `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`는 `HwpThumbnailRenderCache`를 통해 첫 페이지 `CGImage`를 얻고, Finder thumbnail context에 aspect-fit으로 그린다.
6. `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`는 요청 pixel 크기를 bucket화하고, cache miss에서 `HwpPageImageRenderer.renderFirstPage(..., embeddedThumbnailPolicy: .never)`를 호출한다.

따라서 Quick Look preview와 Finder thumbnail의 공통 병목은 `HwpPageImageRenderer.renderPage`이며, Skia backend를 붙인다면 이 공통 지점 위 또는 바로 아래에 backend 선택 정책을 둬야 한다.

## 현재 RustBridge/lock 상태

현재 lock은 `rhwp-core.lock` 기준 stable release tag `v0.7.11`, resolved commit `a9dcdee32b17a7f9a20c609a5ed547e62fb8ebae`다. `RustBridge/Cargo.toml`도 `rhwp = { git = "https://github.com/edwardkim/rhwp.git", tag = "v0.7.11" }`를 사용한다.

현재 앱이 노출하는 FFI symbol set은 `rhwp-ffi-symbols.txt` 기준 다음 10개로 제한된다.

- `rhwp_extract_thumbnail`
- `rhwp_open`
- `rhwp_page_count`
- `rhwp_page_size`
- `rhwp_render_page_svg`
- `rhwp_render_page_tree`
- `rhwp_image_data`
- `rhwp_free_string`
- `rhwp_free_bytes`
- `rhwp_close`

즉 현재 앱 ABI에는 `rhwp_render_page_png` 또는 native Skia 관련 symbol이 없다. 또한 현재 `RustBridge/Cargo.toml`의 `rhwp` dependency에는 `features = ["native-skia"]`가 지정되어 있지 않아 upstream의 Skia code path가 앱 산출물에 들어오지 않는다.

## upstream v0.7.11 Skia 적용 후보

로컬 Cargo checkout의 upstream `v0.7.11` 소스에는 `native-skia` feature와 native PNG export API가 이미 존재한다.

- `Cargo.toml`의 `native-skia = ["dep:resvg", "dep:skia-safe"]`
- `skia-safe = { version = "0.93.1", optional = true, default-features = false, features = ["binary-cache", "embed-icudtl", "pdf", "textlayout"] }`
- `DocumentCore::render_page_png_native(page_num)`
- `DocumentCore::render_page_png_native_with_fonts(page_num, font_paths)`
- `DocumentCore::render_page_png_native_with_export_options(page_num, options)`
- `PngExportOptions`의 `scale`, `max_dimension`, `vlm_target`, `dpi`, `font_paths`

이 API는 `PageLayerTree`를 만든 뒤 `SkiaLayerRenderer`가 PNG bytes를 생성하는 native-only 경로다. Quick Look/Thumbnail 관점에서 가장 직접적인 후보는 `render_page_png_native_with_export_options`이며, thumbnail pixel cap에는 `max_dimension`, Quick Look preview에는 `scale` 또는 page target size 정책을 매핑할 수 있다.

단, 이 후보는 현재 앱에 바로 사용 가능한 ABI가 아니다. 앱 측에서 최소한 다음 작업이 별도 이슈로 필요하다.

- `RustBridge/Cargo.toml`에서 `rhwp/native-skia` feature 활성화 검토
- `RustBridge/src/lib.rs`에 C ABI wrapper 추가
- `rhwp-ffi-symbols.txt` 갱신
- `Sources/RhwpCoreBridge`에 PNG bytes Swift API 추가
- `HwpPageImageRenderer` 또는 새 backend abstraction에서 CoreGraphics renderer와 Skia renderer 선택
- Quick Look/Thumbnail extension sandbox, binary size, first-call latency, font fallback 검증

## upstream #536 진행상태 반영 범위

`edwardkim/rhwp` #536은 2026-05-17 기준 open tracking issue다. 현재 확인된 진행 상황 중 Quick Look/Thumbnail에 직접 연결되는 부분은 P4-P9다.

- P4 #599: `native-skia` feature와 native PNG raster backend 추가
- P5 #626: native Skia equation replay 추가
- P6 #720: native Skia raw SVG fragment replay 추가
- P7 #740: native Skia form control static replay 추가
- P8 #761: Layer IR schema/resource key hardening
- P9 #769: native Skia text replay parity와 module split

반대로 P15/P16의 CanvasKit direct renderer 계열은 browser Studio backend 방향이며, Quick Look/Thumbnail의 macOS native extension path에 바로 들어갈 표면이 아니다. 특히 P16은 아직 #536의 다음 후보로 남아 있으며 public native PNG API를 바꾸지 않는 범위로 설명되어 있다. 따라서 #254는 CanvasKit 도입이 아니라 v0.7.11에 이미 들어온 native Skia PNG path의 optional backend 적용 가능성을 다루는 것으로 범위를 고정한다.

## 관련 이슈 책임 경계

| 이슈 | 상태 | 책임 경계 |
|---|---:|---|
| #96 `PageLayerTree native bridge 탐색과 FFI 공존 경로 추가` | Closed | PageLayerTree JSON 추출과 bridge 공존 실험 범위다. Quick Look/Thumbnail 기본 렌더 경로 전환과 Swift PageLayerTree renderer 완성은 제외했다. |
| #222 `rhwp v0.7.11 기준 Swift native renderer parity gap 정리와 따라잡기` | Closed | Swift CoreGraphics renderer의 parity gap과 구현 우선순위 정리 범위다. native-skia를 앱에 내장하는 구조 변경과 Quick Look/Thumbnail 배포 재릴리즈는 제외했다. |
| #254 `Skia Quick Look/Thumbnail optional backend 설계와 rollout gate 정리` | Open | Quick Look/Thumbnail에 Skia PNG를 optional backend로 넣을 때의 설계, fallback, rollout gate, 후속 이슈 분할을 정리한다. 이 단계에서는 제품 코드 구현을 하지 않는다. |

따라서 #254의 Stage 2 이후 산출물은 #96의 bridge 탐색이나 #222의 parity gap 분석을 반복하지 않고, Quick Look/Thumbnail product path에서 backend 선택과 fallback contract를 결정하는 문서가 되어야 한다.

## 본문 변경 정도 / 본문 무손실 여부

- 제품 코드, RustBridge ABI, project 설정은 변경하지 않았다.
- 문서 변경은 신규 Stage 1 보고서와 오늘할일 상태 갱신뿐이다.
- 기존 문서 본문을 재작성하거나 삭제하지 않았으므로 기존 내용 손실은 없다.
- `mydocs/tech/project_architecture.md`에는 아직 `v0.7.10` lock 설명이 남아 있다. 실제 lock은 이미 `v0.7.11`이므로 별도 문서 정합성 작업에서 정리할 필요가 있다.

## 검증 결과

검증 명령은 Stage 1 보고서 작성 후 실행했다.

```bash
rg -n "rhwp_render_page_tree|renderPageTree|HwpPageImageRenderer|HwpPreviewPDFRenderer|HwpThumbnailProvider|native-skia|render_page_png" \
  rhwp-core.lock RustBridge Sources mydocs/tech/project_architecture.md mydocs/working/task_m020_254_stage1.md
```

결과: 통과. 현재 앱 경로가 `rhwp_render_page_tree`/`renderPageTree`/`HwpPageImageRenderer` 중심이고, `native-skia`/`render_page_png`는 Stage 1 보고서와 RustBridge dependency 설정 검토 대상으로만 나타남을 확인했다.

```bash
git diff --check -- mydocs/plans/task_m020_254_impl.md mydocs/working/task_m020_254_stage1.md
```

결과: 통과.

추가 확인:

- `gh issue view 536 --repo edwardkim/rhwp`: #536은 open이며 P4-P15까지 완료, P16은 다음 후보로 남아 있음을 확인했다.
- `gh issue view 96 --repo postmelee/alhangeul-macos`: #96은 closed이며 PageLayerTree bridge 탐색 범위임을 확인했다.
- `gh issue view 222 --repo postmelee/alhangeul-macos`: #222는 closed이며 native-skia 내장 구조 변경을 제외한 Swift renderer parity gap 정리 범위임을 확인했다.
- 로컬 Cargo checkout `/Users/melee/.cargo/git/checkouts/rhwp-6f8f299952213fc0/a9dcdee`에서 `native-skia`, `render_page_png_native*`, `PngExportOptions` 존재를 확인했다.

## 잔여 위험

- `native-skia` feature를 켰을 때 `Rhwp.xcframework` 크기와 빌드 시간, extension load time 영향은 아직 측정하지 않았다.
- Skia가 반환하는 PNG bytes를 Quick Look/Thumbnail에서 다시 decode해 `CGImage`로 그릴 경우, Swift renderer 대비 CPU/메모리 이득이 실제로 줄어들 수 있다.
- font fallback과 text shaping 결과가 현재 CoreText renderer 및 upstream Skia renderer 사이에서 달라질 수 있다.
- multi-page Quick Look PDF는 현재 bitmap PDF이므로 Skia backend를 붙여도 vector PDF 품질 개선은 별도 범위다.
- current architecture 문서의 `v0.7.10` 설명은 stale 상태이며, #254 후속 문서화 단계에서 정합성 보정이 필요하다.

## 다음 단계 영향

Stage 2에서는 이 inventory를 기준으로 Quick Look/Thumbnail backend contract를 정해야 한다.

- backend enum: 현재 CoreGraphics render-tree backend와 Skia PNG backend의 이름과 기본값
- fallback 기준: Skia 실패, PNG decode 실패, oversize, timeout, unsupported feature, memory pressure
- option mapping: Quick Look target size, Thumbnail `maximumPixelSize`, upstream `PngExportOptions.scale/max_dimension`
- observability: extension-safe logging, error classification, cache key에 backend 포함 여부
- rollout gate: default off, debug flag, sample corpus, visual diff, performance smoke

## 승인 요청

Stage 1은 구현 변경 없이 inventory 정리로 마무리한다. Stage 2 `Backend 선택 계약과 fallback 정책 설계`로 진행하려면 작업지시자 승인이 필요하다.
