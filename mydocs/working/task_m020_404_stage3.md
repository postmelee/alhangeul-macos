# Task M020 #404 Stage 3 완료보고서

## 단계 목적

Stage 2에서 확정한 대표 샘플군에 대해 core SVG, render tree JSON, Swift native PNG, Quick Look/Thumbnail policy smoke, rhwp-studio 기준 visual diff를 실행하고 downstream 보정 후보를 1차 분류한다.

이번 단계는 측정과 판단 기록만 수행했다. 제품 renderer, RustBridge ABI, `rhwp-core.lock`, sample fixture, Skia default 정책은 변경하지 않았다.

## 산출물

| 파일 또는 디렉터리 | 내용 |
|-------------------|------|
| `build.noindex/task404-render-debug/` | 11개 local proxy sample의 render tree JSON, core SVG, native PNG, summary |
| `build.noindex/task404-quicklook-policy/` | 5개 Quick Look 대표 sample의 CoreGraphics, Skia decode, Skia direct policy smoke |
| `build.noindex/task404-thumbnail-policy/` | 5개 Thumbnail 대표 sample의 CoreGraphics/Skia policy, cache, signature smoke |
| `build.noindex/task404-visual-cg/` | 8개 visual feature sample의 CoreGraphics native-vs-rhwp-studio diff |
| `build.noindex/task404-visual-skia/` | 8개 visual feature sample의 Skia native-vs-rhwp-studio diff |
| `mydocs/working/task_m020_404_stage3.md` | Stage 3 측정 결과와 1차 분류 |
| `mydocs/orders/20260705.md` | #404 상태를 Stage 3 완료 및 Stage 4 승인 대기 상태로 갱신 |

`build.noindex/` 아래 산출물은 재생성 가능한 측정 output이므로 커밋하지 않는다.

## 실행 요약

| 명령 | 결과 | 비고 |
|------|------|------|
| `./scripts/validate-stage3-render.sh` | 통과 | `KTX.hwp`, `request.hwp`, `exam_kor.hwp`의 page size, text run, Hangul glyph, non-white pixel sanity 확인 |
| `./scripts/render-debug-compare.sh build.noindex/task404-render-debug ...` | 통과 | 11개 sample 모두 필수 산출물 생성. `복학원서.hwp`에서 known `LAYOUT_OVERFLOW` warning 2건 발생, exit 0 |
| `./scripts/smoke-quicklook-skia-policy.sh build.noindex/task404-quicklook-policy ...` | 통과 | 5개 sample 모두 load/render 통과, fallback 0. `복학원서.hwp` known layout warning 발생 |
| `./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task404-thumbnail-policy ...` | 통과 | 5개 sample, 각 8회 request 모두 `failed=0`, cache signature 분리 OK |
| `./scripts/preview-visual-diff-harness.sh build.noindex/task404-visual-cg --policy coreGraphicsOnly ...` | sandbox 1차 실패 후 재실행 통과 | 1차 sandbox 실행은 WebKit/AppKit sandbox extension 문제로 readiness timeout. 동일 명령을 elevated rerun해 8개 모두 OK |
| `./scripts/preview-visual-diff-harness.sh build.noindex/task404-visual-skia --policy skiaOptIn ...` | 통과 | elevated 실행. 8개 모두 OK, native backend `skia` |
| `rg -n "NativeNonWhitePixels\|CoreSVGBytes\|RenderTreeJSONBytes\|Diff:\|DiffReason" ...` | 통과 | render-debug summary key 확인 |
| `rg -n "failed=0\|ResolverContract: OK\|Fallback\|fallback\|OK\|skia\|coreGraphics" ...` | 통과 | Quick Look/Thumbnail summary key 확인 |
| `rg -n "ChangedPercent\|NativeBackend\|coreGraphics\|skia\|KTX\|group-drawing\|eq-01\|endnote\|pic-crop\|복학원서" ...` | 통과 | visual summary와 Stage 3 보고서 key 확인 |
| `git diff --check` | 통과 | 문서 변경 whitespace 확인 |

renderer hard fail은 0건이다. 단, visual harness는 이 환경에서 sandboxed 실행 시 readiness timeout이 재현되어, AppKit/WebKit 기반 visual 측정은 elevated 실행 또는 별도 UI 권한 환경을 요구하는 것으로 기록한다.

## render-debug 결과

| File | PageCount | PageSizePt | RenderTreeJSONBytes | CoreSVGBytes | NativePNGSize | NativeNonWhitePixels | TextRuns | MissingHangulGlyphs | Diff | DiffReason |
|------|-----------|------------|---------------------|--------------|---------------|----------------------|----------|----------------------|------|------------|
| `request.hwp` | 1 | 566.9x793.7 | 208690 | 260845 | 567x794 | 70189 | 102 | 0 | not generated | `qlmanage` rasterize failed |
| `KTX.hwp` | 1 | 1122.5x793.7 | 1017219 | 807925 | 1123x794 | 455062 | 410 | 0 | not generated | `qlmanage` rasterize failed |
| `hwp-multi-001.hwp` | 9 | 793.7x1122.5 | 494260 | 562685 | 794x1123 | 143331 | 279 | 0 | not generated | `qlmanage` rasterize failed |
| `hwpx-01.hwpx` | 9 | 793.7x1122.5 | 466068 | 560049 | 794x1123 | 134246 | 269 | 0 | not generated | `qlmanage` rasterize failed |
| `group-drawing-02.hwp` | 1 | 793.7x1122.5 | 84953 | 116659 | 794x1123 | 68842 | 36 | 0 | not generated | `qlmanage` rasterize failed |
| `draw-group.hwp` | 1 | 793.7x1122.5 | 14891 | 19630 | 794x1123 | 7324 | 2 | 0 | not generated | `qlmanage` rasterize failed |
| `tac-img-02.hwp` | 66 | 793.7x1122.5 | 37515 | 127659 | 794x1123 | 38421 | 20 | 0 | not generated | `qlmanage` rasterize failed |
| `eq-01.hwp` | 1 | 793.7x1122.5 | 234749 | 262632 | 794x1123 | 43875 | 72 | 0 | not generated | `qlmanage` rasterize failed |
| `endnote-01.hwp` | 5 | 793.7x1122.5 | 66954 | 180240 | 794x1123 | 103220 | 42 | 0 | not generated | `qlmanage` rasterize failed |
| `pic-crop-01.hwp` | 1 | 793.7x1122.5 | 3834 | 128462 | 794x1123 | 39870 | 0 | 0 | not generated | `qlmanage` rasterize failed |
| `복학원서.hwp` | 1 | 793.7x1122.5 | 193772 | 791519 | 794x1123 | 277216 | 101 | 0 | not generated | `qlmanage` rasterize failed |

해석:

- 모든 sample에서 render tree JSON, core SVG, native PNG, summary가 생성됐다.
- 모든 sample에서 `NativeNonWhitePixels`가 0보다 충분히 크고 page size/aspect ratio가 page point size와 맞는다.
- `MissingHangulGlyphs=0`으로 한글 glyph 누락 hard fail은 없다.
- `qlmanage` SVG rasterize 실패는 모든 sample에서 동일하게 발생했지만 optional `CoreRasterPNG`/`DiffPNG` 경로 실패로 분류한다. core SVG, render tree, native PNG 판정에는 영향을 주지 않는다.

## Quick Look 결과

| File | Reply | Pages | CGBackend | CGFallback | CGSeconds | SkiaDecodeBackend | SkiaDecodeFallback | SkiaDecodeSeconds | SkiaDirectStatus | SkiaDirectFallback | SkiaDirectSeconds |
|------|-------|-------|-----------|------------|-----------|-------------------|--------------------|-------------------|------------------|--------------------|-------------------|
| `request.hwp` | png | 1 | skia:0,cg:1,embedded:0 | 0 | 1.117184 | skia:1,cg:0,embedded:0 | 0 | 0.091880 | OK | 0 | 0.026352 |
| `KTX.hwp` | png | 1 | skia:0,cg:1,embedded:0 | 0 | 0.076180 | skia:1,cg:0,embedded:0 | 0 | 0.056787 | OK | 0 | 0.044879 |
| `복학원서.hwp` | png | 1 | skia:0,cg:1,embedded:0 | 0 | 0.051256 | skia:1,cg:0,embedded:0 | 0 | 0.067682 | OK | 0 | 0.053187 |
| `hwp-multi-001.hwp` | pdf | 9 | skia:0,cg:9,embedded:0 | 0 | 0.417066 | skia:9,cg:0,embedded:0 | 0 | 0.564238 | N/A | - | - |
| `hwpx-01.hwpx` | pdf | 9 | skia:0,cg:9,embedded:0 | 0 | 0.356036 | skia:9,cg:0,embedded:0 | 0 | 0.469601 | N/A | - | - |

해석:

- `ResolverContract: OK`.
- CoreGraphics, Skia decode 모두 fallback 0이다.
- 단일 page PNG reply에서는 `request.hwp`, `KTX.hwp`가 Skia direct/decode에서 빠르거나 유사했고, `복학원서.hwp`는 CoreGraphics가 조금 빠르다.
- multi-page PDF reply에서는 Skia decode가 CoreGraphics보다 느렸다. 이 수치는 Skia default 전환 판단에서 surface별로 계속 분리해야 한다.

## Thumbnail 결과

모든 sample에서 CoreGraphics 4회 request와 Skia 4회 request가 `failed=0`으로 끝났다. cache pattern은 모두 `miss`, `exactHit`, `largerBucketHit(1024x1024)`, `largerBucketHit(1024x1024)` 순서였고, CoreGraphics와 Skia cache signature는 분리됐다.

| File | CG large Pixel | CG RenderMs | Skia large Pixel | Skia RenderMs | Fallback | Signature |
|------|----------------|-------------|------------------|---------------|----------|-----------|
| `request.hwp` | 732x1024 | 1637.593 | 567x794 | 58.251 | - | separated |
| `KTX.hwp` | 1024x725 | 60.617 | 1024x725 | 44.100 | - | separated |
| `복학원서.hwp` | 725x1024 | 44.231 | 725x1024 | 50.127 | - | separated |
| `hwp-multi-001.hwp` | 725x1024 | 35.309 | 725x1024 | 45.072 | - | separated |
| `hwpx-01.hwpx` | 725x1024 | 28.926 | 725x1024 | 41.655 | - | separated |

해석:

- Thumbnail renderer/backend failure는 없다.
- `request.hwp`의 CoreGraphics 첫 render가 매우 느리고 pixel size도 732x1024로 기록됐다. Skia는 567x794 원본 page pixel로 기록되어 정책 차이가 보인다.
- 나머지 sample은 Skia가 `KTX.hwp`에서 빠르고, `복학원서.hwp`, `hwp-multi-001.hwp`, `hwpx-01.hwpx`에서는 CoreGraphics가 빠르다.

## visual diff 결과

| File | CG ChangedPercent | Skia ChangedPercent | Skia-CG delta | CG MeanRGBDelta | Skia MeanRGBDelta | CG Backend | Skia Backend |
|------|-------------------|---------------------|---------------|-----------------|-------------------|------------|--------------|
| `KTX.hwp` | 30.8921% | 46.3795% | +15.4874pp | 13.4569 | 20.9833 | coreGraphics | skia |
| `group-drawing-02.hwp` | 4.1183% | 2.0477% | -2.0706pp | 1.9668 | 1.3353 | coreGraphics | skia |
| `draw-group.hwp` | 0.8132% | 0.7367% | -0.0765pp | 0.4881 | 0.4143 | coreGraphics | skia |
| `tac-img-02.hwp` | 4.0975% | 3.7309% | -0.3666pp | 3.6366 | 3.5992 | coreGraphics | skia |
| `eq-01.hwp` | 6.4963% | 7.2690% | +0.7727pp | 6.3696 | 7.5473 | coreGraphics | skia |
| `endnote-01.hwp` | 7.1197% | 8.1352% | +1.0155pp | 6.4043 | 8.9531 | coreGraphics | skia |
| `pic-crop-01.hwp` | 2.0423% | 3.0393% | +0.9970pp | 0.8092 | 1.9914 | coreGraphics | skia |
| `복학원서.hwp` | 7.2888% | 6.9406% | -0.3482pp | 6.8387 | 5.9229 | coreGraphics | skia |

해석:

- visual harness output 기준으로 native backend는 의도한 policy와 일치했다. fallback 표시는 없다.
- `KTX.hwp`는 Skia에서 changed percent가 CoreGraphics 대비 +15.4874pp 커졌다. M020 default 전환 판단의 주요 blocker로 계속 유지한다.
- group proxy sample 2개는 Skia가 CoreGraphics보다 rhwp-studio reference에 가깝다.
- `eq-01.hwp`, `endnote-01.hwp`, `pic-crop-01.hwp`는 Skia 쪽 diff가 0.77pp에서 1.02pp 정도 커졌지만 hard fail로 볼 수준의 blank/fallback/glyph 누락 신호는 없다.

## 후보 축별 1차 판정

| 축 | 관련 upstream PR | 대표 sample | Stage 3 관찰 | hard fail | 1차 판정 | Stage 4 후속 판단 |
|----|------------------|-------------|--------------|-----------|----------|-------------------|
| RawSvg/차트 | `edwardkim/rhwp#1890`, `#1453` 계열 | `draw-group.hwp`, `eq-01.hwp`, chart exact 후보 | local proxy에서는 native PNG blank/fallback 없음. `draw-group.hwp` visual diff는 낮고 Skia가 약간 우세. 다만 chart exact와 일반 SVG vector RawSvg export는 미측정 | 없음 | upstream 대기/별도 조사 | Swift `RawSvg`가 단일 image data URL만 처리하는 기존 보정 후보는 유지한다. chart가 일반 SVG vector로 export되는 fixture를 확보한 뒤 Swift RawSvg 확장 또는 Skia PNG 경로 전환 여부를 판단한다. |
| Group/shape/transform | `edwardkim/rhwp#1905` | `group-drawing-02.hwp`, `draw-group.hwp`, HWP3 exact 후보 | local group proxy는 page/aspect/non-white 정상. visual diff는 Skia가 CG보다 낮다 | 없음 | upstream exact fixture 확인 필요 | upstream이 자식 bbox/transform을 평탄화하면 자동 반영 후보이고, group matrix를 render tree에 남기면 Swift `GroupNode` 모델/renderer 확장이 필요하다. Stage 3만으로는 HWP3 group matrix path를 닫지 않는다. |
| external/large image data | `edwardkim/rhwp#1913`, `#1924`, `#1917`, `#1930` | `pic-crop-01.hwp`, `복학원서.hwp`, external exact 후보 | local image/crop sample은 native PNG non-white 정상, Thumbnail/Quick Look fallback 0. `pic-crop-01.hwp`는 Skia visual diff가 +0.9970pp 높음 | 없음 | upstream 대기/별도 조사 | external BinData Link, large BinData, placeholder 보존 fixture가 필요하다. image node는 있지만 byte data가 없는 경우 placeholder/fallback을 Swift에서 그릴지, filename/external image context ABI가 필요한지 별도 판단한다. |
| text/equation/font/clip/endnote | `edwardkim/rhwp#1881`, `#1911`, `#1875`, `#1926`, `#1919`, `#1912`, `#1895` | `tac-img-02.hwp`, `eq-01.hwp`, `endnote-01.hwp`, `복학원서.hwp` | 모든 render-debug sample에서 `MissingHangulGlyphs=0`. `eq-01.hwp`, `endnote-01.hwp`는 Skia diff가 CG보다 각각 +0.7727pp, +1.0155pp. `tac-img-02.hwp`는 Skia가 약간 우세 | 없음 | 자동 반영 후보 + visual watch | core가 Line/TextRun 좌표를 더 잘 내보내는 변경은 자동 반영 후보지만, CoreText shaping/clip, equation SVG parser, table cell slack, footnote/endnote ordering 차이는 Stage 4에서 후속 smoke 기준을 남긴다. |
| page geometry baseline | `edwardkim/rhwp#1936`, `#1935`, `#1928`, `#1927`, `#1894`, `#1887`, `#1886`, `#1878`, `#1873`, `#1867` | `KTX.hwp`, `hwp-multi-001.hwp`, `hwpx-01.hwpx`, `request.hwp` | page count/size/native PNG aspect는 정상. Quick Look/Thumbnail fallback 0. multi-page Quick Look Skia decode는 CG보다 느리고, `KTX.hwp` visual diff는 Skia가 크게 악화 | 없음 | CoreGraphics default 유지, Skia default blocker 유지 | upstream parser/layout 개선은 ABI/JSON shape가 유지되면 자동 반영 후보지만, Skia default 전환은 `KTX.hwp` visual diff와 multi-page latency를 먼저 줄여야 한다. |

## 다운스트림 보정 후보 상태

Stage 1, Stage 2에서 남긴 보정 후보는 이번 측정으로 다음처럼 조정한다.

- `#1890` 차트 스타일 보정: local proxy만으로는 Swift 보강 필요를 확정할 수 없다. Swift `RawSvg`가 단일 image data URL만 처리하고 일반 SVG vector를 fallback 박스로 보낼 수 있다는 위험은 유지한다. chart exact fixture가 필요하다.
- `#1905` HWP3 group/shape/transform: local group sample은 hard fail이 없지만 Swift `GroupNode`에 transform 필드가 없다는 구조 위험은 유지한다. upstream render tree가 group matrix를 보존하는 exact sample이 필요하다.
- `#1875` 미주 배치/구분선: local `endnote-01.hwp`는 hard fail이 없다. separator line, FootnoteArea clipping/order가 render tree에 어떻게 표현되는지는 exact fixture 또는 Stage 4 후속 smoke로 분리한다.
- `#1881` 그림 wrap/TAC 높이/글리프 가드: local `tac-img-02.hwp`와 `복학원서.hwp`에서 blank/glyph 누락은 없다. 다만 CoreText clip/table cell slack 차이는 native PNG 기준 visual watch로 남긴다.
- `#1895` PDF font option: Quick Look/Thumbnail 직접 영향은 확인되지 않았다. 수식 SVG font/fallback은 `eq-01.hwp`에서 hard fail이 없지만 equation SVG parser와 font fallback 회귀 smoke는 유지한다.
- `#1913`, `#1924`, `#1917`, `#1930` external/large image data: local image sample은 정상이나 external/placeholder ABI 판단은 미측정이다. Stage 4에서 fixture 확보 또는 별도 이슈 분리 후보로 다룬다.

## 환경 실패와 optional 실패

| 항목 | 발생 | 분류 | Stage 4 영향 |
|------|------|------|--------------|
| visual harness sandbox readiness timeout | CoreGraphics visual diff 1차 sandbox 실행에서 발생 | AppKit/WebKit 실행 환경 실패 | renderer hard fail로 세지 않는다. visual 측정 절차에는 elevated 실행 또는 UI 권한 환경 요구를 명시한다. |
| `qlmanage` SVG rasterize 실패 | render-debug 11개 summary 모두에서 발생 | optional core raster diff 실패 | 필수 산출물은 모두 존재하므로 hard fail로 세지 않는다. qlmanage 기반 PNG diff는 신뢰 판정에서 제외한다. |
| `복학원서.hwp` `LAYOUT_OVERFLOW` warning | render-debug, Quick Look, Thumbnail에서 발생 | known layout warning | exit 0, native output 생성. visual diff 해석 시 residual risk로 유지한다. |

## 잔여 위험

- upstream exact fixture를 직접 가져오지 않았으므로 chart, HWP3 group matrix, external BinData Link, large BinData, placeholder, TAC exact 회귀는 아직 닫히지 않았다.
- visual diff의 `ChangedPercent`는 reference capture scale과 renderer 구현 차이를 함께 포함한다. Stage 4에서는 숫자 단독이 아니라 blank/fallback/glyph/clip/ordering 신호와 함께 후속 이슈를 나눈다.
- Quick Look multi-page PDF reply에서 Skia decode가 CoreGraphics보다 느린 경향이 있어, Skia default 전환은 단일 page Thumbnail/PNG 결과만으로 결정하면 안 된다.
- `request.hwp` Thumbnail에서 CoreGraphics와 Skia pixel size가 다르게 기록된다. 정책 차이인지 scaling contract 차이인지 Stage 4에서 기존 #392/#396 결과와 대조한다.

## 다음 단계 영향

Stage 4에서는 이번 결과를 다음 기준으로 정리한다.

- 즉시 Swift 보강 확정: Stage 3 local proxy만으로는 없음.
- Skia default blocker: `KTX.hwp` visual diff 악화, multi-page Quick Look Skia decode latency.
- upstream exact fixture 필요: chart RawSvg vector, HWP3 group matrix, external/large BinData, placeholder, TAC/endnote exact.
- 자동 반영 후보: page count/size/layout 좌표, text run/glyph export가 기존 ABI와 JSON shape를 유지하는 변경.

## 승인 요청

Stage 3는 대표 샘플 diff 측정으로 마무리한다. Stage 4 `downstream 보정 후보와 후속 이슈 분리안`으로 진행하려면 작업지시자 승인이 필요하다.
