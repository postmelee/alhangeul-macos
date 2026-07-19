# Task M020 #404 Stage 2 완료보고서

## 단계 목적

Stage 1에서 정리한 로컬 즉시 측정 후보를 실제 알한글 비교 도구에 연결하고, Stage 3에서 그대로 실행할 명령, output directory, summary table 형식을 확정한다.

이번 단계는 측정 명령과 산출물 형식 확정만 수행했다. 대표 샘플 렌더 diff 실행은 Stage 3 범위로 남겼고, 제품 renderer, RustBridge ABI, `rhwp-core.lock`, fixture 파일은 변경하지 않았다.

## 산출물

| 파일 | 내용 |
|------|------|
| `mydocs/working/task_m020_404_stage2.md` | Stage 3 실행 명령, output directory, 필수/선택 산출물, summary table template 정리 |
| `mydocs/orders/20260705.md` | #404 상태를 Stage 2 완료 및 Stage 3 승인 대기 상태로 갱신 |

## 도구별 역할

| 도구 | 필수 여부 | Stage 3 역할 | 주요 산출물 |
|------|----------|--------------|-------------|
| `scripts/render-debug-compare.sh` | 필수 | core SVG, render tree JSON, Swift native PNG를 같은 page 기준으로 생성 | `<stem>-pageN-render-tree.json`, `<stem>-pageN-core.svg`, `<stem>-pageN-native.png`, `<stem>-pageN-summary.txt` |
| `scripts/smoke-quicklook-skia-policy.sh` | 필수 subset | Quick Look reply shape에서 CoreGraphics, Skia decode, Skia direct를 같은 입력으로 비교 | `summary.txt`, per-file detail |
| `scripts/smoke-thumbnail-skia-policy.sh` | 필수 subset | Finder Thumbnail policy/cache/signature/size/fallback을 CoreGraphics와 Skia opt-in으로 비교 | `summary.txt`, per-file detail, cache signature table |
| `scripts/preview-visual-diff-harness.sh` | 선택+권장 | rhwp-studio reference PNG와 native PNG의 pixel diff를 policy별로 생성 | `summary.md`, `studio/`, `native/`, `diff/` |
| `scripts/preview-renderer-baseline.sh` | 선택 | #396 manifest 기반 visual pair summary가 필요할 때 보조 실행 | `summary.md`, `runs/<policy>/page-N/` |

`render-debug-compare.sh`의 `CoreRasterPNG`/`DiffPNG`는 optional이다. 이 스크립트는 core SVG를 `qlmanage`로 rasterize할 수 있을 때만 core raster PNG와 native-vs-core diff PNG를 추가한다. `qlmanage` 실패, sandbox/WebKit 문제, SVG rasterize 실패는 `DiffReason`으로 기록하고 hard fail로 세지 않는다. hard fail은 필수 산출물인 render tree JSON, core SVG, native PNG, summary 누락 또는 blank/fallback 구조 신호를 기준으로 판정한다.

## output directory 규칙

Stage 3 산출물 위치는 다음으로 고정한다.

| 용도 | directory |
|------|-----------|
| render debug 필수 산출물 | `build.noindex/task404-render-debug/` |
| Quick Look policy smoke | `build.noindex/task404-quicklook-policy/` |
| Thumbnail policy smoke | `build.noindex/task404-thumbnail-policy/` |
| visual diff CoreGraphics | `build.noindex/task404-visual-cg/` |
| visual diff Skia opt-in | `build.noindex/task404-visual-skia/` |
| optional #396 baseline wrapper | `build.noindex/task404-visual-baseline/` |
| upstream checkout fixture 임시 측정 | `build.noindex/task404-upstream-fixtures/` |

`build.noindex/` 아래 산출물은 재생성 가능한 측정 output으로 취급하며 커밋하지 않는다. Stage 3 보고서에는 summary table, 핵심 수치, failure phase, 필요 시 대표 artifact path만 기록한다.

## Stage 3 sample set

### 필수 render-debug set

Stage 3의 1차 render-debug set은 Stage 1 최소 세트 11개로 고정한다.

```text
samples/basic/request.hwp
samples/basic/KTX.hwp
samples/hwp-multi-001.hwp
samples/hwpx/hwpx-01.hwpx
samples/group-drawing-02.hwp
samples/draw-group.hwp
samples/tac-img-02.hwp
samples/eq-01.hwp
samples/endnote-01.hwp
samples/pic-crop-01.hwp
samples/복학원서.hwp
```

이 set은 다섯 후보 축을 빠르게 지나가는 local proxy set이다. chart exact, external BinData exact, HWP3 group exact, 대형 BinData exact는 아직 포함하지 않는다.

### Quick Look/Thumbnail policy smoke subset

Quick Look과 Thumbnail은 #390/#396 비교 가능성을 우선해 기존 M020 대표 5개로 고정한다.

```text
samples/basic/request.hwp
samples/basic/KTX.hwp
samples/복학원서.hwp
samples/hwp-multi-001.hwp
samples/hwpx/hwpx-01.hwpx
```

이 subset은 surface별 backend/fallback/latency/size drift를 보는 용도다. group/vector/equation/TAC 개별 feature는 render-debug와 visual diff에서 먼저 본다.

### visual diff feature subset

rhwp-studio reference와 native PNG 차이를 볼 feature subset은 다음으로 둔다.

```text
samples/basic/KTX.hwp
samples/group-drawing-02.hwp
samples/draw-group.hwp
samples/tac-img-02.hwp
samples/eq-01.hwp
samples/endnote-01.hwp
samples/pic-crop-01.hwp
samples/복학원서.hwp
```

`preview-visual-diff-harness.sh`는 한 번에 한 policy만 실행하므로 CoreGraphics와 Skia opt-in을 별도 directory에 실행한다. #396 quick suite와 동일한 pair summary가 필요하면 `preview-renderer-baseline.sh`를 선택 실행한다.

## Stage 3 실행 명령

아래 명령을 Stage 3의 기본 실행 명령으로 사용한다.

```bash
./scripts/render-debug-compare.sh build.noindex/task404-render-debug --page 1 \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx \
  samples/group-drawing-02.hwp \
  samples/draw-group.hwp \
  samples/tac-img-02.hwp \
  samples/eq-01.hwp \
  samples/endnote-01.hwp \
  samples/pic-crop-01.hwp \
  samples/복학원서.hwp
```

```bash
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task404-quicklook-policy \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
```

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task404-thumbnail-policy \
  samples/basic/request.hwp \
  samples/basic/KTX.hwp \
  samples/복학원서.hwp \
  samples/hwp-multi-001.hwp \
  samples/hwpx/hwpx-01.hwpx
```

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task404-visual-cg --page 1 \
  --policy coreGraphicsOnly \
  samples/basic/KTX.hwp \
  samples/group-drawing-02.hwp \
  samples/draw-group.hwp \
  samples/tac-img-02.hwp \
  samples/eq-01.hwp \
  samples/endnote-01.hwp \
  samples/pic-crop-01.hwp \
  samples/복학원서.hwp
```

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task404-visual-skia --page 1 \
  --policy skiaOptIn \
  samples/basic/KTX.hwp \
  samples/group-drawing-02.hwp \
  samples/draw-group.hwp \
  samples/tac-img-02.hwp \
  samples/eq-01.hwp \
  samples/endnote-01.hwp \
  samples/pic-crop-01.hwp \
  samples/복학원서.hwp
```

선택 실행:

```bash
./scripts/preview-renderer-baseline.sh build.noindex/task404-visual-baseline \
  --suite quick \
  --page-mode first
```

upstream exact fixture는 Stage 3에서 바로 확보하지 않고, 위 local proxy 측정 결과를 먼저 본 뒤 필요 시 다음 후보만 `build.noindex/task404-upstream-fixtures/` 아래에 임시 checkout/copy해서 재측정한다.

- `samples/issue1892_hwp3_drawing_group_roundtrip.hwp`
- `samples/issue1892_hwp3_tab_roundtrip.hwp`
- `samples/issue1891_external_bindata_link.hwpx`
- `samples/issue1835_tac_stale_height.hwp`
- `samples/issue1842_cell_tac_group_lineheight.hwp`
- `samples/issue1880_anchor_stack_sb_convert.hwpx`
- `samples/issue1770_rowsplit_tolerance.hwpx`
- upstream `samples/chart/*`

## Stage 3 보고서 summary template

### 후보 축별 판정표

| 축 | 대표 샘플 | core SVG/render tree | native CG | Skia/visual | hard fail | 1차 판정 | 후속 후보 |
|----|-----------|----------------------|-----------|-------------|-----------|----------|-----------|
| RawSvg/차트 | `draw-group`, `eq-01`, chart exact 후보 |  |  |  |  |  |  |
| Group/transform | `group-drawing-02`, `draw-group`, HWP3 exact 후보 |  |  |  |  |  |  |
| external/large image | `pic-crop-01`, `복학원서`, external exact 후보 |  |  |  |  |  |  |
| text/equation/font/clip/endnote | `tac-img-02`, `eq-01`, `endnote-01` |  |  |  |  |  |  |
| page geometry baseline | `KTX`, `hwp-multi-001`, `hwpx-01` |  |  |  |  |  |  |

### render-debug extraction table

| File | PageCount | PageSizePt | RenderTreeJSONBytes | CoreSVGBytes | NativePNGSize | NativeNonWhitePixels | TextRuns | MissingHangulGlyphs | Diff | DiffReason |
|------|-----------|------------|---------------------|--------------|---------------|----------------------|----------|----------------------|------|------------|
|  |  |  |  |  |  |  |  |  |  |  |

필수 key:

- `PageCount`
- `PageSizePt`
- `RenderTreeJSONBytes`
- `CoreSVGBytes`
- `NativePNGSize`
- `NativeNonWhitePixels`
- `TextRuns`
- `MissingHangulGlyphs`
- `Diff`
- `DiffReason`

### Quick Look policy table

| File | Reply | Pages | CGBackend | CGFallback | CGSeconds | SkiaDecodeBackend | SkiaDecodeFallback | SkiaDecodeSeconds | SkiaDirectStatus | SkiaDirectFallback | SkiaDirectSeconds |
|------|-------|-------|-----------|------------|-----------|-------------------|--------------------|-------------------|------------------|--------------------|-------------------|
|  |  |  |  |  |  |  |  |  |  |  |  |

hard fail 후보:

- `Load=FAIL`
- `CGStatus=FAIL`
- `SkiaDecodeStatus=FAIL`이면서 CoreGraphics fallback 해석 불가
- `SkiaDirectStatus=FAIL`은 direct fast path failure로 기록하되 `SkiaDecode`와 `CG`가 통과하면 default blocker로 세지 않는다.

### Thumbnail policy table

| File | Policy | Request | Status | Cache | RequestedBucket | MatchedBucket | Backend | Fallback | Pixel | OutputBytes | PNGBytes | RenderMs | Seconds |
|------|--------|---------|--------|-------|-----------------|---------------|---------|----------|-------|-------------|----------|----------|---------|
|  |  |  |  |  |  |  |  |  |  |  |  |  |  |

추가 확인:

- cache signature separation table에서 CoreGraphics와 Skia signature가 분리되는지 확인한다.
- Thumbnail `Pixel`은 #392 이후 긴 변 `maxDimension` mapping과 맞는지 확인한다.
- `Fallback`이 `-`가 아니면 후보 축과 별도로 renderer/backend failure로 분류한다.

### visual diff table

| File | Policy | Status | Phase | StudioSize | NativeSize | ChangedPercent | MeanRGBDelta | DiffBounds | StudioCapture | NativeBackend | NativeMs |
|------|--------|--------|-------|------------|------------|----------------|--------------|------------|---------------|---------------|----------|
|  |  |  |  |  |  |  |  |  |  |  |  |

해석 기준:

- `Status=FAIL`은 `Phase`로 `navigation`, `readiness`, `snapshot`, `native`, `diff`를 구분한다.
- `readiness`/`navigation`은 harness/environment failure 후보로 별도 기록하고 renderer hard fail로 바로 세지 않는다.
- `NativeBackend`에 `fallback=` suffix가 있으면 backend fallback으로 기록한다.
- `ChangedPercent`는 단독 결론이 아니라 `DiffBounds`, PNG artifact, candidate axis와 함께 해석한다.

## Stage 3 hard fail 기준

Stage 3에서 hard fail로 우선 분류할 신호:

- render tree JSON, core SVG, native PNG, summary 중 필수 산출물이 누락된다.
- `NativeNonWhitePixels`가 0 또는 비정상적으로 낮아 blank/fallback으로 보인다.
- `PageSizePt`와 `NativePNGSize` aspect ratio가 크게 어긋난다.
- render tree에는 `Image`/`RawSvg`/`Equation`/group proxy가 있는데 native PNG에서 해당 영역이 blank/fallback으로 보인다.
- Quick Look/Thumbnail에서 CoreGraphics fallback도 실패한다.
- Thumbnail policy에서 backend별 cache signature가 분리되지 않는다.
- visual diff가 `native` phase에서 실패하거나 `NativeBackend`가 의도와 다르게 fallback한다.

hard fail로 바로 세지 않을 신호:

- `render-debug-compare.sh` optional `qlmanage` SVG rasterize 실패
- visual harness `readiness`/`navigation` failure
- `SkiaDirectStatus=FAIL`이지만 `SkiaDecode`와 `CoreGraphics`가 정상인 경우
- `ChangedPercent` 단독 증가
- `복학원서.hwp`의 known-risk layout/displayText 차이

## 본문 변경 정도 / 본문 무손실 여부

- 신규 Stage 2 보고서와 오늘할일 비고만 수정했다.
- 제품 Swift/Rust source, `project.yml`, `rhwp-core.lock`, sample fixture, script 동작은 변경하지 않았다.
- 기존 문서 본문을 삭제하거나 재작성하지 않았다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `./scripts/render-debug-compare.sh --help` | 통과. output dir, `--page`, multi input, optional raster diff 설명 확인 |
| `./scripts/smoke-quicklook-skia-policy.sh --help` | 통과. Quick Look CoreGraphics/Skia policy smoke summary 설명 확인 |
| `./scripts/smoke-thumbnail-skia-policy.sh --help` | 통과. Thumbnail request option, cache detail 설명 확인 |
| `./scripts/preview-visual-diff-harness.sh --help` | 통과. page/policy/viewport/resource-dir 옵션 확인 |
| `test -f Frameworks/universal/librhwp.a` | 통과. `194M` static library 존재 |
| `test -f Frameworks/modulemap/module.modulemap` | 통과. modulemap 존재 |
| `./scripts/preview-renderer-baseline.sh --validate-only --suite quick --page-mode first` | 통과. `samples=5`, `samplePages=5` |
| `git diff --check` | 통과 |

## 잔여 위험

- Stage 2는 명령 확정 단계라 실제 renderer failure는 아직 검증하지 않았다.
- visual harness는 AppKit/WebKit과 bundled `rhwp-studio`를 사용하므로 sandbox/readiness failure가 날 수 있다. Stage 3에서는 renderer hard fail과 environment failure를 분리해야 한다.
- chart exact와 external BinData exact fixture는 아직 로컬에 없으므로, Stage 3 local proxy 측정만으로 upstream exact regression을 닫을 수 없다.
- `render-debug-compare.sh`의 optional core SVG raster diff는 `qlmanage` 결과에 의존한다. 실패해도 core SVG/render tree/native PNG 판정은 계속 진행해야 한다.
- Korean filename이 포함된 `samples/복학원서.hwp`는 명령을 복사할 때 shell 인코딩/locale이 깨지지 않는 환경에서 실행해야 한다.

## 다음 단계 영향

Stage 3에서는 이 보고서의 명령을 실행하고, summary key를 추출해 후보 축별로 hard fail과 자동 반영 후보를 분류한다. 측정 중 upstream exact fixture가 반드시 필요하다고 확인되면, local proxy 결과와 분리해 checkout/fixture 편입 여부를 Stage 3 보고서의 잔여 위험 또는 Stage 4 후속 이슈 후보로 남긴다.

## 승인 요청

Stage 2는 측정 명령과 산출물 형식 확정으로 마무리한다. Stage 3 `대표 샘플 diff 실행`으로 진행하려면 작업지시자 승인이 필요하다.
