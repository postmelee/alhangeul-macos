# Task M020 #404 Stage 1 완료보고서

## 단계 목적

upstream `edwardkim/rhwp` 최근 렌더 관련 PR과 이슈를 후보 축별로 묶고, 각 항목의 샘플/fixture 존재 여부와 알한글 저장소에서 즉시 측정 가능한 대체 샘플을 inventory한다.

이번 단계는 조사와 측정 후보 정리만 수행했다. 제품 renderer, RustBridge ABI, `rhwp-core.lock`, sample 파일은 변경하지 않았다.

## 조사 기준

| 항목 | 내용 |
|------|------|
| 이슈 | #404 `upstream 렌더 PR 대표 샘플 diff 측정` |
| 추적 이슈 | #387 Preview/Thumbnail Skia readiness 후속 개선 추적 |
| 기준 브랜치 | `devel` |
| 작업 브랜치 | `local/task404` |
| upstream repo | `edwardkim/rhwp` |
| local 기본 renderer | `PageRenderTree` JSON + Swift `CGTreeRenderer` CoreGraphics/CoreText |
| Skia 경로 | opt-in/diagnostic backend, release default 아님 |

Stage 1에서는 upstream 샘플을 이 저장소 `samples/`에 편입하지 않았다. binary fixture 편입은 Stage 3 측정 결과 또는 Stage 4 후속 이슈 분리 판단 이후 별도 승인 대상으로 둔다.

## downstream 보정 후보 재확인

Swift renderer 코드 대조 결과, 이슈 본문에 적은 downstream 보정 후보는 현재 코드 구조와 일치한다.

| 후보 | 현재 Swift 상태 | Stage 3에서 볼 신호 |
|------|-----------------|----------------------|
| RawSvg/차트 | `CGTreeRenderer.renderRawSvg`는 단일 image data URL만 decode하고, 일반 SVG vector는 `SVG` fallback 박스로 그린다. | core SVG/Skia에는 차트가 보이지만 native PNG가 fallback 박스인지 확인 |
| Group/transform | `GroupNode`에는 transform 필드가 없고 `renderGroup`은 자식만 순회한다. 개별 shape/image transform은 있다. | upstream render tree가 group matrix를 남기면 native가 대변위/무변환으로 보일 수 있음 |
| external/large image data | `ImageNode.bin_data_id`로 `RhwpDocument.imageData`/`rhwp_image_data`를 조회하고 nil이면 image draw가 생략된다. | image node는 있는데 byte data가 없어 blank가 되는지, placeholder가 필요한지 확인 |
| text/equation/font/clip/endnote | Swift는 CoreText, 자체 equation SVG parser, font fallback, table cell clip/body overflow replay를 별도로 구현한다. | glyph 누락, baseline, clipping, equation font, footnote/endnote separator/order 차이 확인 |
| page geometry baseline | page size/bbox/line 좌표가 기존 JSON shape로 내려오면 자동 반영될 가능성이 높다. | page count/size/content offset/blank regression 위주 확인 |

## upstream PR와 샘플 후보 inventory

### 1. RawSvg/차트

| upstream | 변경 성격 | upstream 샘플/fixture | 로컬 상태 | Stage 1 분류 |
|----------|-----------|----------------------|-----------|--------------|
| `edwardkim/rhwp#1890` `C1c: 차트 스타일 4갭 보정` | OOXML chart parser/renderer/style 보정, `tests/issue_1882_chart_style_gaps.rs` 추가 | PR files에는 test 중심으로 보이며 명시 binary sample 추가는 없음 | chart 전용 샘플 없음. `samples/draw-group.hwp`, `samples/eq-01.hwp`는 RawSvg/vector proxy일 뿐 chart 아님 | fixture 편입 후보 또는 upstream checkout 필요 |
| `edwardkim/rhwp#1453` issue `C1a: 3D막대·3D원형·ofPie 차트 라우팅` | `samples/chart` 7종 14파일(hwp+hwpx)을 완료 기준으로 둔 chart tracking issue | `samples/chart/세로막대형/...`, `samples/chart/원형/...` 계열로 기술됨 | 로컬 `samples/`에 chart fixture 없음 | upstream checkout 필요 |

판정: chart는 로컬 즉시 측정 샘플이 없다. Stage 2 최소 세트에는 RawSvg fallback proxy로 `samples/draw-group.hwp`와 `samples/eq-01.hwp`를 넣고, chart 직접 판정은 upstream `samples/chart` fixture 확보 후 측정하는 확장 세트로 분리한다.

### 2. Group/shape/transform

| upstream | 변경 성격 | upstream 샘플/fixture | 로컬 상태 | Stage 1 분류 |
|----------|-----------|----------------------|-----------|--------------|
| `edwardkim/rhwp#1905` `Task #1892: 대법원 서식(HWP3) HWP5 라운드트립 렌더 대변위 수정` | HWP3 group/container/shape/tab roundtrip과 대변위 수정 | `samples/issue1892_hwp3_drawing_group_roundtrip.hwp`, `samples/issue1892_hwp3_tab_roundtrip.hwp` | exact fixture 없음. 유사 샘플은 `samples/group-box.hwp`, `samples/draw-group.hwp`, `samples/group-drawing-02.hwp`, `samples/shape-group-02.hwp` | local proxy 즉시 측정 가능, exact fixture는 upstream checkout 필요 |

판정: group-level transform이 render tree에 남는 경우 Swift 모델/renderer 확장이 필요하다. 반대로 upstream이 child bbox/shape transform으로 평탄화해 내려보내면 CoreGraphics 경로도 자동 반영 가능성이 있다. Stage 3에서는 로컬 group proxy로 현재 Swift 한계를 먼저 측정하고, exact HWP3 대법원 fixture는 checkout/fixture 편입 후보로 둔다.

### 3. external/large image data

| upstream | 변경 성격 | upstream 샘플/fixture | 로컬 상태 | Stage 1 분류 |
|----------|-----------|----------------------|-----------|--------------|
| `edwardkim/rhwp#1913` `Task #1891: 외부 참조(BinData Link) 그림 HWPX 왕복 소실 수정` | external BinData Link 보존, serializer context/package check 보정 | `samples/issue1891_external_bindata_link.hwpx` | exact fixture 없음. image proxy는 `samples/hwp-img-001.hwp`, `samples/img-start-001.hwp`, `samples/pic-crop-01.hwp`, `samples/tac-img-02.hwp`, `samples/tac-img-02.hwpx`, `samples/복학원서.hwp` | exact fixture upstream checkout 필요, local image proxy 즉시 측정 가능 |
| `edwardkim/rhwp#1924` `Task #1916+#1917: 표 CTRL_HEADER 빈 데이터 방출 + BinData 64MB 상한` | HWP5 table `flowWithText`, HWPX BinData 64MB 상한/대형 이미지 소실 계열 | PR에는 `tests/issue_1916.rs`, `tests/issue_1917.rs` 중심. issue #1917 표본은 hwpdocs/poc 경로로 기술 | 대형 64MB+ image fixture 없음 | 측정 제외 또는 별도 fixture 확보 필요 |
| `edwardkim/rhwp#1917` issue `HWPX BinData 64MB 엔트리 상한` | 대형 BMP/TIF/JPG 로드 거부와 pic 컨트롤 소실 | 공개 PR binary fixture 확인 안 됨. hwpdocs survey 표본 기반 | 로컬 대형 fixture 없음 | fixture 편입 후보 아님, 별도 권한/샘플 필요 |
| `edwardkim/rhwp#1930` `Task #1929: HWP5 그림 imgDim 왕복 소실 수정` | HWP5 picture original dimension 보존 | test 중심, binary sample 없음 | image proxy는 있음 | local proxy 측정 가능, exact upstream fixture 없음 |

판정: external link와 대형 BinData는 Swift renderer가 `bin_data_id` bytes를 받을 수 있는지와 직접 연결된다. Stage 3 최소 세트에서는 로컬 image proxy의 일반 image/effect/crop을 측정하고, external link exact fixture는 upstream checkout 후 별도 샘플로 확장한다. 64MB+ 대형 이미지는 현재 저장소에 넣지 않고 별도 fixture 정책 이슈로 남긴다.

### 4. text/equation/font/clip/endnote

| upstream | 변경 성격 | upstream 샘플/fixture | 로컬 상태 | Stage 1 분류 |
|----------|-----------|----------------------|-----------|--------------|
| `edwardkim/rhwp#1881` `렌더 결함 3건: Square-wrap/TAC stale height/글리프 보존 가드` | picture wrap, TAC stale height, glyph 보존 | `samples/issue1835_tac_stale_height.hwp`, `pdf/issue1835_tac_stale_height-2022.pdf` | exact fixture 없음. local proxy는 `samples/tac-case-001.hwp`~`005`, `samples/tac-img-02.hwp`, `samples/tac-img-02.hwpx` | local proxy 즉시 측정 가능, exact fixture upstream checkout 필요 |
| `edwardkim/rhwp#1875` `fix(endnote): 미주 배치·구분선·번호 렌더링` | endnote layout/separator/numbering, render query 보정 | binary sample 없음 | `samples/endnote-01.hwp`, `samples/footnote-01.hwp` 있음 | 즉시 측정 가능 |
| `edwardkim/rhwp#1911` `task 1655: HWPX 수식 flowWithText 보존` | HWPX equation flowWithText serialization 보존 | binary sample 없음 | `samples/eq-01.hwp`, `samples/exam_math.hwp` 있음. HWPX 수식 exact sample은 없음 | HWP 수식은 즉시 측정, HWPX exact는 fixture 필요 |
| `edwardkim/rhwp#1926` `Task #1842: 셀 내부 tac 묶음 전용 문단 라인높이 퇴화 수정` | table cell TAC group line height | `samples/issue1842_cell_tac_group_lineheight.hwp` | exact fixture 없음. local proxy는 `samples/table-complex.hwp`, `samples/table-vpos-01.hwp`, `samples/tac-case-*` | local proxy 즉시 측정 가능, exact fixture upstream checkout 필요 |
| `edwardkim/rhwp#1919`, `#1912` `Task/Issue #1898: tac 인라인 그림 문단 vpos/line advance` | TAC inline image 문단 줄 전진, lazy vpos 재역산 | tests 중심, binary sample 없음 | `samples/tac-img-02.hwp`, `samples/tac-img-02.hwpx`, `samples/table-vpos-01.hwp` | 즉시 측정 가능 |
| `edwardkim/rhwp#1895` `export-pdf 폰트 fallback 및 수식 폰트 옵션 추가` | CLI/PDF font option, equation SVG font option | PDF assets 중심. Quick Look 직접 경로 아님 | `samples/eq-01.hwp`, `samples/exam_math.hwp`, `samples/re-font-batang-hancom.hwp`, `samples/lseg-02-mixed.hwp` | font/equation proxy 즉시 측정 가능 |

판정: layout 좌표가 core render tree로 내려오는 변경은 자동 반영 후보지만, Swift는 CoreText와 자체 equation/parser/fallback을 쓰므로 native PNG diff가 남을 수 있다. Stage 3 최소 세트에는 TAC, equation, endnote/footnote, font/line segment를 모두 포함한다.

### 5. page geometry baseline

| upstream | 변경 성격 | upstream 샘플/fixture | 로컬 상태 | Stage 1 분류 |
|----------|-----------|----------------------|-----------|--------------|
| `edwardkim/rhwp#1936` `Task #1891: HWP5-origin HWPX 쪽수 보정` | 규제영향분석서 계열 page count/spacing/typeset 보정 | `samples/76076_regulatory_analysis.hwp`, `80168`, `80250`, `86712`, `samples/issue1891/*.hwpx`, `*.pdf` | exact fixture 없음. local page baseline은 `samples/hwp-multi-001.hwp`, `samples/hwpx/hwpx-01.hwpx`, `samples/basic/KTX.hwp` | exact fixture upstream checkout 필요, local baseline 즉시 측정 가능 |
| `edwardkim/rhwp#1935` `Task #1880 v2: HWP3-origin 휴리스틱 HWPX-변환본 게이트` | parser heuristic gate | binary sample 없음 | HWPX local baseline 있음 | local baseline 측정 가능 |
| `edwardkim/rhwp#1928` `Task #1880: 빈-앵커 스택 spacing_before` | anchor stack spacing/page transition | `samples/issue1880_anchor_stack_sb_convert.hwpx` | exact fixture 없음 | upstream checkout 필요 |
| `edwardkim/rhwp#1927` `Task #1880: 자리차지 표 host_before + placeholder pic 보존` | HWPX table host_before, BinData placeholder pic 보존 | `samples/issue1880_takeplace_host_before.hwpx`, `samples/issue1880_takeplace_oracle_p13.hwpx` | exact fixture 없음 | upstream checkout 필요 |
| `edwardkim/rhwp#1886` `Issue #1770: HWPX-origin 마커 pagination 자기정합` | HWPX-origin marker, rowsplit tolerance | `samples/issue1770_rowsplit_tolerance.hwpx` | exact fixture 없음 | upstream checkout 필요 |
| `edwardkim/rhwp#1894` `Issue #1858: vert=쪽/용지 valign=Bottom 표` | bottom anchor/table actual height | test 중심 | `samples/table-vpos-01.hwp`, `samples/table-complex.hwp` | local proxy 즉시 측정 가능 |
| `edwardkim/rhwp#1887` `task 1811: HWPX saved bounds RowBreak` | row break/page split/typeset | test/assets 중심 | `samples/hwpx/hwpx-01.hwpx`, `samples/table-complex.hwp` | local proxy 즉시 측정 가능 |
| `edwardkim/rhwp#1878` `Task #1860: split budget/co-anchored float` | table split budget, node-child containment | binary sample 없음 | `samples/table-complex.hwp`, `samples/multi-table-001.hwp`, `samples/multi-table-002.hwp` | local proxy 즉시 측정 가능 |
| `edwardkim/rhwp#1873` `HWP3 LINE_SEG rewind 페이지 경계 반영` | HWP3 line segment page boundary | review assets/test 중심 | `samples/hwp-3.0-HWPML.hwp`, `samples/basic/KTX.hwp` proxy | local proxy 측정 가능 |
| `edwardkim/rhwp#1867` `task 1733: 국제고속선기준 잔여 over-pagination 완화` | over-pagination 완화 | review assets/test 중심 | `samples/basic/KTX.hwp`, `samples/basic/KTX-003.hwp` | local proxy 즉시 측정 가능 |

판정: page geometry 축은 core가 page count/size/bbox를 기존 ABI와 JSON shape로 내보내면 자동 반영될 가능성이 가장 크다. Stage 3에서는 기존 #396 quick 세트를 baseline으로 두고, table/vpos/multi-page proxy를 확장한다. exact regulatory-analysis 계열은 upstream checkout 후 장기 fixture 편입 후보로 둔다.

## 로컬 즉시 측정 후보

Stage 2에서 그대로 명령화할 수 있는 로컬 후보는 다음과 같다.

| 목적 | 샘플 | 관련 축 |
|------|------|---------|
| 건강한 단일 page 기준 | `samples/basic/request.hwp` | baseline/control |
| Skia visual regression sentinel | `samples/basic/KTX.hwp` | page geometry baseline |
| multi-page HWP | `samples/hwp-multi-001.hwp` | page count/page loop |
| HWPX path | `samples/hwpx/hwpx-01.hwpx` | page geometry/HWPX |
| group/vector | `samples/group-drawing-02.hwp`, `samples/draw-group.hwp` | group/shape/RawSvg proxy |
| image/crop/effect | `samples/pic-crop-01.hwp`, `samples/hwp-img-001.hwp`, `samples/복학원서.hwp` | image/effect/fill |
| TAC/image wrap | `samples/tac-img-02.hwp`, `samples/tac-img-02.hwpx`, `samples/tac-case-001.hwp` | text/clip/TAC |
| equation/font | `samples/eq-01.hwp`, `samples/exam_math.hwp`, `samples/re-font-batang-hancom.hwp`, `samples/lseg-02-mixed.hwp` | equation/font/text shaping |
| endnote/footnote | `samples/endnote-01.hwp`, `samples/footnote-01.hwp` | endnote/footnote ordering/marker |
| table/vpos | `samples/table-vpos-01.hwp`, `samples/table-complex.hwp`, `samples/multi-table-001.hwp` | page geometry/table split |

Stage 2 최소 실행 세트 후보:

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

이 세트는 chart external-link 대형 이미지 exact regression을 직접 닫지는 못한다. 대신 현재 로컬 surface의 CoreGraphics/Skia 차이를 빠르게 분류하고, upstream exact fixture가 필요한 후보를 명확히 드러내는 1차 측정 세트로 쓴다.

## upstream checkout 또는 fixture 편입 후보

Stage 3 확장 또는 Stage 4 후속 이슈에서 다룰 exact fixture 후보:

| 후보 | 경로 | 이유 |
|------|------|------|
| HWP3 group exact | `samples/issue1892_hwp3_drawing_group_roundtrip.hwp`, `samples/issue1892_hwp3_tab_roundtrip.hwp` | `GroupNode` transform/flattening 판정에 직접적 |
| external BinData exact | `samples/issue1891_external_bindata_link.hwpx` | `rhwp_image_data` nil/placeholder/ABI 필요성 판정에 직접적 |
| TAC stale height exact | `samples/issue1835_tac_stale_height.hwp`, `pdf/issue1835_tac_stale_height-2022.pdf` | TAC stale height와 PDF oracle 존재 |
| table cell TAC lineheight exact | `samples/issue1842_cell_tac_group_lineheight.hwp` | table clip/slack/line height 비교에 직접적 |
| HWPX anchor/placeholder exact | `samples/issue1880_anchor_stack_sb_convert.hwpx`, `samples/issue1880_takeplace_host_before.hwpx`, `samples/issue1880_takeplace_oracle_p13.hwpx` | page transition, placeholder pic 보존 판정 |
| HWPX-origin marker exact | `samples/issue1770_rowsplit_tolerance.hwpx` | HWPX-origin marker/page count baseline |
| regulatory-analysis exact | `samples/76076_regulatory_analysis.hwp`, `80168`, `80250`, `86712`, `samples/issue1891/*.hwpx`, `*.pdf` | page count/page geometry 대형 baseline |
| chart exact | upstream `samples/chart/*` | RawSvg/chart fallback 직접 판정 |

현재 저장소에 없는 upstream binary를 무조건 추가하지 않는다. Stage 3에서 checkout 산출물로 측정할지, 장기 fixture로 편입할지는 파일 크기, 라이선스/출처, 재현 가치 기준으로 Stage 4에서 따로 결정한다.

## Stage 2 실행 설계 입력

Stage 2에서는 다음을 확정한다.

1. `render-debug-compare.sh`로 생성할 필수 산출물: core SVG, render tree JSON, native PNG, summary.
2. Quick Look/Thumbnail policy smoke를 적용할 subset: 최소 세트 중 `request`, `KTX`, `복학원서`, `hwp-multi-001`, `hwpx-01`은 기존 #390/#396과 비교 가능하다.
3. visual diff harness를 적용할 subset: #396 manifest와 겹치는 항목을 우선 사용하고, `group-drawing-02`, `draw-group`, `tac-img-02`, `eq-01`, `endnote-01`, `pic-crop-01`을 feature probe로 추가한다.
4. output directory: `build.noindex/task404-stage3-*` 또는 구현계획서의 `build.noindex/task404-render-debug`, `task404-quicklook-policy`, `task404-thumbnail-policy`.
5. hard fail 판정: blank/fallback, missing image bytes, page size mismatch, glyph/clip, transform 대변위, RawSvg fallback을 metric보다 우선한다.

## 본문 변경 정도 / 본문 무손실 여부

- 신규 Stage 1 보고서와 오늘할일 비고만 수정했다.
- 제품 Swift/Rust source, `project.yml`, `rhwp-core.lock`, sample fixture는 변경하지 않았다.
- 기존 문서 본문을 삭제하거나 재작성하지 않았다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `gh pr view 1890 --repo edwardkim/rhwp --json number,title,body,files,url` | 통과. chart parser/renderer/test 변경 확인 |
| `gh pr view 1905 --repo edwardkim/rhwp --json number,title,body,files,url` | 통과. `issue1892_*` HWP3 fixture 확인 |
| `gh pr view 1913 --repo edwardkim/rhwp --json number,title,body,files,url` | 통과. `issue1891_external_bindata_link.hwpx` fixture 확인 |
| `gh pr view 1924 --repo edwardkim/rhwp --json number,title,body,files,url` | 통과. #1916/#1917 batch와 tests 중심 변경 확인 |
| `gh pr view 1881 --repo edwardkim/rhwp --json number,title,body,files,url` | 통과. `issue1835_tac_stale_height.hwp`와 PDF oracle 확인 |
| `gh pr view 1875 --repo edwardkim/rhwp --json number,title,body,files,url` | 통과. endnote layout 변경과 binary sample 부재 확인 |
| 보강 PR/issue 조회 | 통과. #1453/#1917은 PR이 아니라 issue로 확인했고, #1911/#1912/#1919/#1926/#1930/#1936/#1935/#1928/#1927/#1894/#1887/#1886/#1878/#1873/#1867를 축별로 분류 |
| local sample 검색 | 통과. `rg --files samples`와 glob 검색으로 즉시 측정 가능한 로컬 proxy 확인 |
| Swift renderer 대조 | 통과. `RawSvg`, `GroupNode`, `ImageNode.bin_data_id`, equation/font/CoreText 처리 지점 확인 |
| `git diff --check` | 통과 |

## 잔여 위험

- upstream exact fixture는 아직 로컬 저장소에 없으므로 Stage 3이 로컬 proxy만으로 끝나면 chart/external-link/HWP3 exact regression 판정은 보류된다.
- chart fixture는 upstream issue #1453에서 `samples/chart`로 설명되지만 #1890 PR files에는 binary sample이 보이지 않았다. checkout 후 실제 경로를 확인해야 한다.
- 64MB+ 대형 BinData 표본은 공개 fixture가 아니거나 저장소 편입에 부적합할 수 있다. 이 축은 placeholder/ABI 설계 후보로만 남을 가능성이 있다.
- local proxy는 downstream renderer 한계를 드러내는 데 유용하지만 upstream regression exact oracle은 아니다.
- upstream PR들이 2026-07-05 기준 매우 최근 merge이므로, release tag pin 전까지는 관찰 대상이지 제품 기본 반영 기준이 아니다.

## 다음 단계 영향

Stage 2에서는 이 보고서의 최소 세트를 바탕으로 실제 실행 명령과 산출물 표 형식을 확정한다. 특히 chart/external-link/HWP3 exact fixture를 Stage 3에 바로 포함할지, 로컬 proxy 측정 후 Stage 4에서 fixture 편입 이슈로 넘길지 결정해야 한다.

## 승인 요청

Stage 1은 upstream PR와 샘플 후보 inventory로 마무리한다. Stage 2 `측정 명령과 산출물 형식 확정`으로 진행하려면 작업지시자 승인이 필요하다.
