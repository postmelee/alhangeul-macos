# Task M014 #122 Stage 4 완료보고서

## 개요

Stage 4에서는 Stage 3 구현 이후 preview visual diff, render-debug sanity, overlay metadata smoke, extension registration hygiene를 재실행해 회귀 여부를 확인했다. Stage 4에서 추가 소스 변경은 없고, 검증 결과와 fixture 한계를 문서화한다.

## 기준

| 항목 | 값 |
|------|----|
| 이슈 | #122 Swift native renderer 이미지 fill mode·타일·배치 렌더링 parity 보강 |
| 브랜치 | `local/task122` |
| 구현 커밋 | `81afc8c Task #122 Stage 3: 이미지 fill 렌더 helper 구현` |
| Stage 4 산출물 | `build.noindex/task122-stage4-*` |
| 기준 baseline | `mydocs/working/task_m014_122_stage1.md` |

## Preview Visual Diff

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task122-stage4-visual --page 1 \
  samples/pic-crop-01.hwp samples/tac-img-02.hwp samples/tac-img-02.hwpx
```

sandbox 내부 실행은 Stage 1과 같은 WebKit readiness timeout으로 실패했다.

```text
rhwp-studio page 1 readiness timed out: navigation=pending; events=[]; scheme={resourceRequests=0, documentRequests=0}
```

동일 명령을 sandbox 밖에서 재실행했다.

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task122-stage4-visual-escalated --page 1 \
  samples/pic-crop-01.hwp samples/tac-img-02.hwp samples/tac-img-02.hwpx
```

결과: 세 sample 모두 OK.

| 파일 | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | DiffBounds | StudioCapture | NativeBackend | Stage 1 NativeMs | Stage 4 NativeMs |
|------|--------------:|---------------:|-------------:|------------:|------------|---------------|---------------|-----------------:|-----------------:|
| `pic-crop-01.hwp` | `72763/3562815` | `2.0423%` | `0.8092` | `186` | `121,234 1345x1814` | `domComposite` | `coreGraphics` | `1021.7` | `1077.5` |
| `tac-img-02.hwp` | `146377/3562815` | `4.1085%` | `3.6656` | `255` | `121,159 1345x1965` | `canvasDataURL` | `coreGraphics` | `23.7` | `23.4` |
| `tac-img-02.hwpx` | `146377/3562815` | `4.1085%` | `3.6656` | `255` | `121,159 1345x1965` | `domComposite` | `coreGraphics` | `4.2` | `3.9` |

해석:

- ChangedPixels, ChangedPercent, MeanRGBDelta, MaxRGBDelta, DiffBounds가 Stage 1 baseline과 동일하다.
- Stage 3의 fill helper 구현은 현재 세 sample의 기존 bbox draw 결과를 바꾸지 않았다.
- NativeMs는 실행 시점 변동이 있으나 regression 신호로 보이지 않는다.

산출물:

```text
build.noindex/task122-stage4-visual/
build.noindex/task122-stage4-visual-escalated/
```

## Render Debug Sanity

처음에는 세 sample을 같은 output directory로 실행했으나 `tac-img-02.hwp`와 `tac-img-02.hwpx`가 같은 basename이라 summary 파일이 덮이는 것을 확인했다. 기록을 명확히 하기 위해 HWP/HWPX output directory를 분리했다.

명령:

```bash
./scripts/render-debug-compare.sh build.noindex/task122-stage4-render-debug-hwp --page 1 \
  samples/pic-crop-01.hwp samples/tac-img-02.hwp

./scripts/render-debug-compare.sh build.noindex/task122-stage4-render-debug-hwpx --page 1 \
  samples/tac-img-02.hwpx
```

결과: 세 sample 모두 OK.

| 파일 | NativePNGSize | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|------|---------------|---------------------:|---------:|-----------:|--------------------:|
| `pic-crop-01.hwp` | `794x1123` | `39870` | `2` | `0` | `0` |
| `tac-img-02.hwp` | `794x1123` | `38410` | `18` | `6` | `0` |
| `tac-img-02.hwpx` | `794x1123` | `38410` | `18` | `6` | `0` |

`render-debug-compare`의 optional core SVG raster diff는 `qlmanage rasterize failed`로 생성되지 않았다. native PNG와 summary는 정상 생성됐다.

산출물:

```text
build.noindex/task122-stage4-render-debug-hwp/
build.noindex/task122-stage4-render-debug-hwpx/
```

## Fill Mode Fixture 확인

Stage 4 render tree 산출물에서 `fill_mode`를 다시 확인했다.

```bash
rg -o '"fill_mode":null' build.noindex/task122-stage4-render-debug-hwp \
  build.noindex/task122-stage4-render-debug-hwpx | wc -l

rg -o '"fill_mode":"[^"]+"' build.noindex/task122-stage4-render-debug-hwp \
  build.noindex/task122-stage4-render-debug-hwpx | wc -l
```

결과:

| 항목 | Count |
|------|------:|
| `fill_mode == null` | `4` |
| non-null `fill_mode` | `0` |

현재 검증 sample은 Stage 3 구현의 fallback 보존과 기존 image path 회귀 방지에는 유효하지만, 실제 tile/placement mode를 시각 fixture로 직접 증명하지는 못한다.

## PR Review Follow-up: Placement Positive Fixture

Copilot review에서 Stage 4 검증 sample이 `fill_mode == null`만 포함해 placement/tile branch positive 검증이 부족하다는 지적이 있었다. 이후 repository sample과 Downloads의 HWP/HWPX를 추가 스캔했고, repository sample인 `samples/basic/BookReview.hwp` page 2에서 placement 계열 non-null `fill_mode`를 확인했다.

첨부 확인 요청을 받았던 `/Users/melee/Downloads/143E433F503322BD33.hwp`는 image node 1개가 있었지만 `fill_mode == null`이라 positive fixture가 아니었다.

추가 검증 명령:

```bash
./scripts/render-debug-compare.sh build.noindex/task122-review-bookreview-placement --page 2 \
  samples/basic/BookReview.hwp

rg -o '"fill_mode":"[^"]+"' \
  build.noindex/task122-review-bookreview-placement/BookReview-page2-render-tree.json

rg -o '"node_type":\{"Image"' \
  build.noindex/task122-review-bookreview-placement/BookReview-page2-render-tree.json | wc -l

rg -o '"fill_mode":null' \
  build.noindex/task122-review-bookreview-placement/BookReview-page2-render-tree.json | wc -l
```

결과:

| 파일 | Page | ImageCount | `fill_mode == null` | NonNullFillModeCount | FillModeHistogram | NativePNGSize | NativeNonWhitePixels | TextRuns | MissingHangulGlyphs |
|------|-----:|-----------:|--------------------:|---------------------:|-------------------|---------------|---------------------:|---------:|--------------------:|
| `samples/basic/BookReview.hwp` | `2` | `3` | `0` | `3` | `LeftBottom=1`, `RightBottom=2` | `794x1123` | `296408` | `117` | `0` |

render-debug 산출물:

```text
build.noindex/task122-review-bookreview-placement/BookReview-page2-render-tree.json
build.noindex/task122-review-bookreview-placement/BookReview-page2-core.svg
build.noindex/task122-review-bookreview-placement/BookReview-page2-native.png
build.noindex/task122-review-bookreview-placement/BookReview-page2-summary.txt
```

추가 스캔에서 확인한 전체 non-null mode는 `FitToSize`, `None`, `LeftBottom`, `RightBottom`이었다. 로컬 repository sample과 Downloads에서는 `TileAll`, `TileHorz*`, `TileVert*`, `LeftTop`, `Center*`, `RightTop` fixture를 찾지 못했다. 따라서 이번 follow-up은 placement branch positive 검증을 보강하고, tile branch visual positive fixture 부재는 남은 한계로 명시한다.

## Overlay Metadata Smoke

명령:

```bash
./scripts/overlay-metadata-smoke.sh build.noindex/task122-stage4-overlay --page 1 \
  samples/pic-crop-01.hwp samples/tac-img-02.hwp samples/tac-img-02.hwpx
```

결과: 세 sample 모두 OK.

| 파일 | UpstreamImages | Overlay | Behind | Front | Renderable | BinLinked | TreeImages | TreeEmbeddedAvailable | Wraps |
|------|---------------:|--------:|-------:|------:|-----------:|----------:|-----------:|----------------------:|-------|
| `pic-crop-01.hwp` | `2` | `0` | `0` | `0` | `0` | `0` | `2` | `2/2` | `Square:2` |
| `tac-img-02.hwp` | `1` | `0` | `0` | `0` | `0` | `0` | `1` | `1/1` | `TopAndBottom:1` |
| `tac-img-02.hwpx` | `1` | `0` | `0` | `0` | `0` | `0` | `1` | `1/1` | `TopAndBottom:1` |

산출물:

```text
build.noindex/task122-stage4-overlay/
```

## Extension Registration Hygiene

명령:

```bash
./scripts/check-extension-registration-hygiene.sh --check-only
```

결과: Issues 없음.

비고:

- development registration 없음.
- build.noindex/DerivedData 아래 개발용 `Alhangeul.app` bundle 존재 경고는 등록되어 있지 않으므로 문제 없음.
- PlugInKit provider path 미보고 경고는 기존 smoke와 동일하다.

## Diff Check

명령:

```bash
git diff --check
```

결과: 통과.

## 결론

Stage 3 구현 이후 기존 image/crop sample의 visual diff 수치는 Stage 1 baseline과 동일했다. render-debug, overlay metadata, extension registration hygiene도 실패 없이 통과했다. PR review follow-up으로 `BookReview.hwp` page 2에서 `LeftBottom`/`RightBottom` placement positive fixture를 추가 확인했다. 남은 한계는 tile 계열 positive fixture 부재이며, 실제 tile visual proof 확보는 후속 보강 후보로 남긴다.

## 다음 단계 요청

Stage 5에서는 최종 정리 단계로 넘어가 Task #122 최종 보고서 작성, today order 갱신, 최종 검증 결과 정리, PR 준비 여부 확인을 진행한다.
