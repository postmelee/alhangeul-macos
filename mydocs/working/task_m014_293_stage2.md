# Task M014 #293 Stage 2 보고서 - overlay snapshot capture 선택 보강

## 단계 목적

overlay DOM 또는 overlay union이 있는 `rhwp-studio` page에서 canvas-only export 대신 WebView snapshot을 선택하도록 `preview visual diff harness`의 capture decision을 보강했다.

## 산출물

| 구분 | 경로 | 요약 |
|------|------|------|
| source | `scripts/preview_visual_diff_harness.swift` | overlay 감지 시 `captureSnapshotPNG`를 우선 선택하도록 decision 순서 변경 |
| Stage 보고서 | `mydocs/working/task_m014_293_stage2.md` | 구현 내용, smoke 결과, 잔여 위험 정리 |
| smoke summary | `build.noindex/task293-stage2-smoke/summary.md` | `복학원서.hwp`, `request.hwp` 보정 후 capture 결과 |
| canvas 기준 summary | `build.noindex/task293-stage2-canvas-baseline/summary.md` | `tac-img-02.hwp` canvas-only path 유지 확인 |

`build.noindex/`, `Frameworks/`, `RustBridge/target/`는 로컬 검증 산출물이며 커밋하지 않는다.

## 본문 변경 정도 / 본문 무손실 여부

- `StudioReferenceRenderer.capture` 내부 decision만 수정했다.
- JavaScript probe, wrapper script, renderer/compositor production path는 수정하지 않았다.
- 기존 canvas export path는 overlay가 없고 canvas가 non-empty인 경우 그대로 유지한다.

변경 전 decision:

```swift
if pageState.canvasSampleNonWhitePixels > 0 {
    png = try exportCanvasPNG(pageNumber: pageNumber)
    ...
} else {
    png = try captureSnapshotPNG(rect: snapshotRectMetadata.cgRect)
    captureMode = "webViewSnapshot"
    overlayIncluded = true
    ...
}
```

변경 후 decision:

```swift
let hasOverlayDOM = pageState.overlayCount > 0 || pageState.usedOverlayUnion
let shouldCaptureSnapshot = hasOverlayDOM || pageState.canvasSampleNonWhitePixels <= 0
if shouldCaptureSnapshot {
    png = try captureSnapshotPNG(rect: snapshotRectMetadata.cgRect)
    captureMode = "webViewSnapshot"
    overlayIncluded = hasOverlayDOM
    ...
} else {
    png = try exportCanvasPNG(pageNumber: pageNumber)
    ...
}
```

이제 overlay-positive 문서에서 snapshot 실패가 발생하면 canvas fallback으로 조용히 숨지 않고 Stage 2 smoke가 실패한다.

## 검증 결과

### Swift compile

명령:

```bash
swiftc -parse-as-library \
  -module-cache-path build.noindex/task293-stage2-swift-module-cache \
  -Xcc -fmodules-cache-path=build.noindex/task293-stage2-clang-module-cache \
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
  -o build.noindex/task293-stage2-syntax-check
```

결과: 성공.

### Stage 2 smoke

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task293-stage2-smoke --page 1 \
  samples/복학원서.hwp samples/basic/request.hwp
```

summary 결과:

| File | Status | StudioSize | ChangedPixels | ChangedPercent | MeanRGBDelta | StudioCapture |
|------|--------|------------|---------------|----------------|--------------|---------------|
| `복학원서.hwp` | OK | `1588x2246` | `3504631/3566648` | `98.2612%` | `48.7462` | `webViewSnapshot` |
| `request.hwp` | OK | `1134x1588` | `1723444/1800792` | `95.7048%` | `21.2012` | `webViewSnapshot` |

`복학원서.hwp` metadata:

| 항목 | Stage 1 | Stage 2 |
|------|---------|---------|
| `captureMode` | `canvasDataURL` | `webViewSnapshot` |
| `overlayIncluded` | `false` | `true` |
| `overlayCount` | `5` | `5` |
| `usedOverlayUnion` | `true` | `true` |
| PNG size | `1587x2245` | `1588x2246` |
| PNG bytes | `327525` | `67706` |

`request.hwp`도 Stage 1에서 `overlayCount=1`, `usedOverlayUnion=true`로 감지됐기 때문에 이번 policy에서는 snapshot으로 바뀌었다. Stage 1 결론대로 `request.hwp`는 overlay 없는 canvas-only 회귀 기준으로 보지 않는다.

### canvas-only 기준 smoke

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task293-stage2-canvas-baseline --page 1 \
  samples/tac-img-02.hwp
```

summary 결과:

| File | Status | StudioSize | ChangedPixels | ChangedPercent | MeanRGBDelta | StudioCapture |
|------|--------|------------|---------------|----------------|--------------|---------------|
| `tac-img-02.hwp` | OK | `1587x2245` | `146622/3562815` | `4.1153%` | `3.6698` | `canvasDataURL` |

`tac-img-02.hwp` metadata:

| 항목 | 값 |
|------|----|
| `captureMode` | `canvasDataURL` |
| `overlayIncluded` | `false` |
| `overlayCount` | `0` |
| `usedOverlayUnion` | `false` |
| `canvasSampleNonWhitePixels` | `2017 / 44250` |
| `snapshotSampleNonWhitePixels` | `44250 / 44250` |

### PNG 속성 확인

```text
복학원서.hwp stage2 studio PNG: 1588x2246, hasAlpha=yes, bitsPerSample=8
request.hwp stage2 studio PNG: 1134x1588, hasAlpha=yes, bitsPerSample=8
tac-img-02.hwp canvas baseline PNG: 1587x2245, hasAlpha=yes, bitsPerSample=8
```

### diff check

```text
git diff --check
```

통과했다.

## 잔여 위험

- Snapshot path의 visual diff 수치가 Stage 1보다 크게 증가했다. 이는 reference capture mode가 실제 WebView snapshot으로 바뀐 결과이지만, Stage 3에서 overlay 포함 여부와 snapshot PNG 해석을 다시 확인해야 한다.
- `request.hwp`처럼 일반 sample도 `overlayCount=1`로 잡히는 경우가 있다. 이번 Stage 2는 이슈 목표에 맞춰 detector가 overlay를 감지하면 snapshot을 선택하지만, detector 과검출 여부는 Stage 3 sample set smoke에서 계속 관찰해야 한다.
- `snapshotSampleNonWhitePixels`가 전체 sample pixel과 같은 값으로 나오는 경향이 있다. 현재는 기존 metadata를 유지했지만, 이 값은 snapshot path에서 page background/alpha 해석 영향을 받을 수 있다.
- `복학원서.hwp`의 PNG가 실제로 좌상단 로고와 중앙 워터마크를 포함하는지의 시각 확인과 최종 sample set 재측정은 Stage 3 범위로 남긴다.

## 다음 단계 영향

Stage 3에서는 다음을 확인한다.

1. `복학원서.hwp` studio reference PNG의 좌상단 로고와 중앙 BehindText 워터마크 포함 여부.
2. overlay-positive sample의 `captureMode=webViewSnapshot`, `overlayIncluded=true` 유지 여부.
3. `tac-img-02.hwp` 같은 `overlayCount=0` sample의 `canvasDataURL` 유지 여부.
4. 기존 v0.1.4 image sample set에서 snapshot path 전환이 visual diff summary 해석에 미치는 영향.

## 승인 요청

Stage 2는 overlay-aware snapshot 선택 보강과 smoke 검증을 완료했다. Stage 3 sample set smoke와 visual diff 재측정으로 진행해도 되는지 승인 요청한다.
