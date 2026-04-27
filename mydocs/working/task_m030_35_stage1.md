# Task M030 #35 Stage 1 완료보고서

## 단계 목표

`group-drawing-02.hwp`의 재현 샘플 위치를 확인하고, Quick Look preview와 Finder thumbnail이 어떤 렌더링 경로를 공유하거나 분기하는지 확인한다.

## 확인한 파일

- 샘플: `Vendor/rhwp/samples/group-drawing-02.hwp`
- Quick Look preview: `Sources/QLExtension/HwpPreviewProvider.swift`
- Thumbnail extension: `Sources/ThumbnailExtension/HwpThumbnailProvider.swift`
- Thumbnail render cache: `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`
- 공통 첫 페이지 렌더러: `Sources/Shared/HwpPageImageRenderer.swift`
- Swift render tree 모델: `Sources/RhwpCoreBridge/RenderTree.swift`
- Swift CoreGraphics renderer: `Sources/RhwpCoreBridge/CGTreeRenderer.swift`

## 확인 결과

### 1. 샘플과 embedded preview

`group-drawing-02.hwp`는 저장소의 core submodule 샘플에 존재한다.

```text
Vendor/rhwp/samples/group-drawing-02.hwp
```

`Vendor/rhwp/target/debug/rhwp thumbnail Vendor/rhwp/samples/group-drawing-02.hwp --info` 실행 결과 embedded preview는 다음과 같다.

```text
output/group-drawing-02_thumb.gif (177x250, 2220 bytes, gif)
```

따라서 이 샘플에는 낮은 해상도의 embedded GIF preview가 실제로 포함되어 있다.

### 2. Quick Look preview 경로

`HwpPreviewProvider`는 다음 경로를 사용한다.

```text
HwpPreviewProvider.createPreview
→ HwpPageImageRenderer.renderFirstPage(fileURL:)
→ HwpPageImageRenderer.encodePNG
```

이 호출은 `maximumPixelSize`를 전달하지 않는다. 현재 `HwpPageImageRenderer.decodeEmbeddedThumbnail`은 `maximumPixelSize == nil`이면 embedded thumbnail을 항상 사용할 수 있으므로, Quick Look preview는 `group-drawing-02.hwp`에서 177x250 embedded GIF를 우선 사용할 가능성이 높다.

### 3. Finder thumbnail 경로

`HwpThumbnailProvider`는 다음 경로를 사용한다.

```text
HwpThumbnailProvider.provideThumbnail
→ HwpThumbnailRenderRequest(maximumSize, scale)
→ HwpThumbnailRenderCache.renderedPage
→ HwpPageImageRenderer.renderFirstPage(fileURL:maximumPixelSize:)
```

`HwpThumbnailRenderRequest`는 Finder 요청 크기와 scale을 픽셀 bucket으로 변환해 `maximumPixelSize`를 전달한다. `HwpPageImageRenderer.shouldUseEmbeddedThumbnail`은 요청 최대 길이가 128px를 초과하면 embedded image의 최대 길이가 요청 길이의 75% 이상일 때만 embedded preview를 사용한다.

예를 들어 512px thumbnail 요청에서는 embedded 최대 길이 250px가 `512 * 0.75`보다 작으므로 full render fallback으로 전환된다.

### 4. full render 경로

embedded preview를 사용하지 않는 경우 `HwpPageImageRenderer`는 다음 순서로 full render를 수행한다.

```text
RhwpDocument(data:)
→ rhwp_open
→ rhwp_render_page_tree
→ RenderNode decode
→ rhwp_page_size
→ CGContext bitmap 생성
→ CGTreeRenderer.render(tree:in:pageHeight:document:)
```

이 경로는 Quick Look preview와 Finder thumbnail이 공유하는 첫 페이지 bitmap 생성 경로다.

### 5. core SVG export 기준값

`Vendor/rhwp/target/debug/rhwp export-svg Vendor/rhwp/samples/group-drawing-02.hwp -o output/task35-stage1-svg -p 0`를 실행했다.

결과:

```text
문서 로드 완료: Vendor/rhwp/samples/group-drawing-02.hwp (1페이지)
→ output/task35-stage1-svg/group-drawing-02.svg
```

생성된 SVG는 `width="793.7066666666667" height="1122.5066666666667"` 페이지와 다수의 `<rect>`, `<text>` 요소를 포함한다. 즉 core의 SVG export는 177x250 embedded GIF만 반환하는 것이 아니라 페이지 크기 기준의 벡터/텍스트 구조를 생성할 수 있다.

## 검증 결과

### 실행

```bash
./scripts/validate-stage3-render.sh output/task35-stage1-render Vendor/rhwp/samples/group-drawing-02.hwp
```

### 결과

```text
FAIL Vendor/rhwp/samples/group-drawing-02.hwp: render tree has no Hangul text runs
FAIL: one or more render checks failed
```

이 실패는 bitmap 렌더링 자체의 실패라기보다 `scripts/stage3_render_check.swift`가 한글 text run 존재를 필수 조건으로 검사하기 때문에 발생했다. `group-drawing-02.hwp`는 영문 `item`, `value` 중심의 group drawing 샘플이므로 해당 smoke test 조건과 맞지 않는다. Stage 2에서 이 샘플 전용 render tree 구조 확인이 필요하다.

## 1차 판단

- Quick Look preview는 현재 호출 방식상 embedded preview를 우선 사용할 수 있으므로, 저해상도 표시의 한 원인이 Quick Look 경로에도 남아 있다.
- Finder thumbnail은 큰 요청에서 full render fallback으로 전환되지만, 여전히 낮은 품질처럼 보인다면 Swift render tree 해석 또는 `CGTreeRenderer`의 group/shape/text 처리 차이를 확인해야 한다.
- core SVG export는 페이지 크기 기준의 벡터/텍스트 산출물을 만들 수 있으므로, Stage 2에서는 `rhwp_render_page_tree` JSON과 Swift `RenderTree`/`CGTreeRenderer` 사이의 차이를 우선 분석한다.

## 변경 파일

- `mydocs/orders/20260425.md`
- `mydocs/plans/task_m030_35.md`
- `mydocs/plans/task_m030_35_impl.md`
- `mydocs/working/task_m030_35_stage1.md`

## 다음 단계

Stage 2에서 render tree의 group/image/shape/text node 구조와 Swift renderer 처리 누락 여부를 분석한다.

## 승인 요청

Stage 1 완료를 승인하면 Stage 2 render tree와 Swift renderer 분석으로 진행한다.
