# Task M014 #293 Stage 3 보고서 - overlay snapshot smoke 재측정

## 단계 목적

보정 후 `rhwp-studio` overlay-positive sample과 v0.1.4 image sample set의 capture metadata와 visual diff metric을 다시 생성했다.

Stage 3 중 `WKWebView.takeSnapshot` 결과가 실제 page content가 아니라 단색 `#f0f0f0` PNG로 나오는 것을 확인해, overlay-positive reference는 WebKit bitmap snapshot 대신 WebView DOM의 same-origin canvas/image drawable을 JavaScript에서 합성하는 `domComposite` 경로로 회복했다.

## 산출물

| 구분 | 경로 | 요약 |
|------|------|------|
| source | `scripts/preview_visual_diff_harness.swift` | overlay-positive 문서에서 DOM composite PNG export 경로 추가 |
| Stage 보고서 | `mydocs/working/task_m014_293_stage3.md` | visual check, sample metric, 잔여 위험 정리 |
| overlay summary | `build.noindex/task293-stage3-overlay/summary.md` | `복학원서.hwp` 최종 overlay-positive smoke |
| sample summary | `build.noindex/task293-stage3-samples/summary.md` | v0.1.4 sample set 최종 smoke |

`build.noindex/`, `Frameworks/`, `RustBridge/target/`는 로컬 검증 산출물이며 커밋하지 않는다.

## 본문 변경 정도 / 본문 무손실 여부

- `StudioReferenceRenderer.capture`에서 overlay-positive 문서는 `exportCompositePNG`를 사용하도록 변경했다.
- `exportCanvasPNG`와 composite export가 같은 PNG decode helper를 공유하도록 정리했다.
- `compositeDataURLScript`를 추가해 같은 page rect 안의 canvas와 image overlay를 DOM order/z-index 기준으로 offscreen canvas에 그린다.
- renderer/compositor production path, wrapper script, bundled `rhwp-studio` asset은 수정하지 않았다.

최종 capture decision:

```swift
let hasOverlayDOM = pageState.overlayCount > 0 || pageState.usedOverlayUnion
if hasOverlayDOM {
    png = try exportCompositePNG(pageNumber: pageNumber)
    captureMode = "domComposite"
    overlayIncluded = true
} else if pageState.canvasSampleNonWhitePixels <= 0 {
    png = try captureSnapshotPNG(rect: snapshotRectMetadata.cgRect)
    captureMode = "webViewSnapshot"
} else {
    png = try exportCanvasPNG(pageNumber: pageNumber)
}
```

## 검증 결과

### 중간 실패와 회복

Stage 2의 `webViewSnapshot` 경로로 Stage 3 visual check를 수행했을 때 `복학원서.hwp` studio PNG는 문서 내용 없이 전체가 단색 `#f0f0f0`이었다. window를 화면 안쪽으로 옮겨도 동일했다.

#280 Stage 2에서도 `WKWebView.takeSnapshot`이 page canvas 영역의 배경만 캡처하고 canvas backing store를 누락한다는 관찰이 있었으므로, 이번 Stage 3에서는 overlay-positive reference를 `domComposite`로 회복했다.

### Swift compile

명령:

```bash
swiftc -parse-as-library \
  -module-cache-path build.noindex/task293-stage3-swift-module-cache \
  -Xcc -fmodules-cache-path=build.noindex/task293-stage3-clang-module-cache \
  -I Frameworks/modulemap \
  Sources/RhwpCoreBridge/RhwpDocument.swift \
  Sources/RhwpCoreBridge/RenderTree.swift \
  Sources/RhwpCoreBridge/FontFallback.swift \
  Sources/RhwpCoreBridge/FontResourceRegistry.swift \
  Sources/RhwpCoreBridge/CGTreeRenderer.swift \
  Sources/Shared/HwpPageImageRenderer.swift \
  scripts/preview_visual_diff_harness.swift \
  Frameworks/universal/librhwp.a \
  -framework AppKit -framework CoreGraphics -framework CoreText \
  -framework Foundation -framework ImageIO -framework UniformTypeIdentifiers \
  -framework Security -framework CoreFoundation -framework WebKit \
  -lc++ -liconv -lz \
  -o build.noindex/task293-stage3-syntax-check
```

결과: 성공.

### overlay-positive smoke

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task293-stage3-overlay --page 1 \
  samples/복학원서.hwp
```

summary 결과:

| File | Status | StudioSize | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | StudioCapture |
|------|--------|------------|---------------|----------------|--------------|-------------|---------------|
| `복학원서.hwp` | OK | `1587x2245` | `1140387/3562815` | `32.0080%` | `37.8073` | `255` | `domComposite` |

metadata:

| 항목 | Stage 1 | Stage 3 최종 |
|------|---------|--------------|
| `captureMode` | `canvasDataURL` | `domComposite` |
| `overlayIncluded` | `false` | `true` |
| `overlayCount` | `5` | `5` |
| `usedOverlayUnion` | `true` | `true` |
| PNG size | `1587x2245` | `1587x2245` |

시각 확인:

- 좌상단 고려대학교 로고가 포함됨.
- 중앙 BehindText 워터마크가 포함됨.
- 하단 우측 붉은 도장 overlay가 포함됨.

### v0.1.4 sample set smoke

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task293-stage3-samples --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx samples/hwp-img-001.hwp
```

summary 결과:

| File | Status | StudioSize | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | StudioCapture |
|------|--------|------------|---------------|----------------|--------------|-------------|---------------|
| `request.hwp` | OK | `1133x1587` | `321031/1798071` | `17.8542%` | `11.0716` | `255` | `domComposite` |
| `hwpx-01.hwpx` | OK | `1587x2245` | `535436/3562815` | `15.0285%` | `15.2088` | `255` | `domComposite` |
| `tac-img-02.hwp` | OK | `1587x2245` | `146622/3562815` | `4.1153%` | `3.6698` | `255` | `canvasDataURL` |
| `tac-img-02.hwpx` | OK | `1587x2245` | `146622/3562815` | `4.1153%` | `3.6698` | `255` | `domComposite` |
| `hwp-img-001.hwp` | OK | `1587x2245` | `278887/3562815` | `7.8277%` | `8.1872` | `255` | `domComposite` |

metadata 확인:

- `복학원서.hwp`: `captureMode=domComposite`, `overlayIncluded=true`, `overlayCount=5`, `usedOverlayUnion=true`
- `tac-img-02.hwp`: `captureMode=canvasDataURL`, `overlayIncluded=false`, `overlayCount=0`, `usedOverlayUnion=false`
- 나머지 sample은 현행 detector 기준 `overlayCount=1`이라 `domComposite`로 전환됨.

### PNG 속성 확인

```text
복학원서.hwp stage3 studio PNG: 1587x2245, hasAlpha=yes, bitsPerSample=8
```

### diff check

```text
git diff --check
```

통과했다.

## 잔여 위험

- `domComposite`는 canvas와 `img` element를 DOM order/z-index 기준으로 합성한다. CSS transform, background-image, SVG element, blend mode 같은 더 복잡한 DOM paint feature는 아직 일반화하지 않았다.
- `request.hwp`처럼 일반 sample도 detector 기준 `overlayCount=1`로 잡힌다. 이번 이슈 목표상 overlay 후보가 있으면 composite를 선택하지만, 향후 detector 과검출을 줄이는 후속 작업이 필요할 수 있다.
- `captureMode`는 최종적으로 `webViewSnapshot`이 아니라 `domComposite`다. WebKit snapshot은 이 harness 환경에서 blank capture가 재현되어 실제 캡처 방식과 metadata 일치를 위해 별도 mode로 기록했다.
- 이번 작업은 reference capture를 보정한 것이며 native renderer/compositor 자체의 watermark opacity, image effect, z-order는 수정하지 않았다.

## 다음 단계 영향

Stage 4에서는 다음을 최종 보고서에 정리한다.

1. #282/#116 handoff: `복학원서.hwp` reference capture는 `domComposite`, overlay included 기준으로 사용한다.
2. sample set metric: `tac-img-02.hwp`만 canvas-only path 유지, 나머지 overlay-detected sample은 composite path로 해석한다.
3. WebKit snapshot blank 한계: 향후 WebKit snapshot 재시도보다 DOM drawable composite 보강이 현실적인 후속 방향이다.

## 승인 요청

Stage 3은 overlay 포함 reference PNG와 sample set 재측정을 완료했다. Stage 4 #282/#116 handoff와 최종 보고 정리로 진행해도 되는지 승인 요청한다.
