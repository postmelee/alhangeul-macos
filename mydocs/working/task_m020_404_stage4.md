# Task M020 #404 Stage 4 완료보고서

## 단계 목적

Stage 3 측정 결과를 바탕으로 downstream 보정 후보를 `자동 반영`, `Skia 전환 후보`, `Swift CoreGraphics 보강 필요`, `upstream 대기/별도 조사`로 분류하고, 기존 이슈에 연결할 항목과 신규 이슈 후보를 분리한다.

이번 단계는 분류와 후속 작업안 작성만 수행했다. 제품 renderer, bridge ABI, `rhwp-core.lock`, sample fixture, 기술 문서는 변경하지 않았다.

## 입력 자료

| 자료 | 사용 내용 |
|------|----------|
| `mydocs/working/task_m020_404_stage1.md` | upstream PR와 후보 sample inventory |
| `mydocs/working/task_m020_404_stage2.md` | Stage 3 측정 명령과 hard fail 기준 |
| `mydocs/working/task_m020_404_stage3.md` | 대표 샘플 diff 측정 결과 |
| `Sources/RhwpCoreBridge/RenderTree.swift` | `GroupNode`, `ImageNode`, `EquationNode`, `RawSvgNode` 모델 확인 |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | group, equation, RawSvg, clip/render 경로 확인 |
| `Sources/RhwpCoreBridge/RhwpDocument.swift`, `RustBridge/src/lib.rs` | `bin_data_id -> rhwp_image_data` 이미지 데이터 계약 확인 |
| GitHub issue 조회 | #387, #390, #391 및 축별 열린 이슈 중복 확인 |

## GitHub 이슈 중복 확인

실행한 조회:

```bash
gh issue list --repo postmelee/alhangeul-macos --state open \
  --search "RawSvg chart transform external image equation clip Skia" \
  --limit 30 --json number,title,state,milestone,labels,url
gh issue view 387 --repo postmelee/alhangeul-macos --json number,title,state,milestone,labels,body,url
gh issue view 390 --repo postmelee/alhangeul-macos --json number,title,state,milestone,labels,body,url
gh issue view 391 --repo postmelee/alhangeul-macos --json number,title,state,milestone,labels,body,url
gh issue list --repo postmelee/alhangeul-macos --state open --search "RawSvg" --limit 20 --json number,title,state,milestone,labels,url
gh issue list --repo postmelee/alhangeul-macos --state open --search "chart" --limit 20 --json number,title,state,milestone,labels,url
gh issue list --repo postmelee/alhangeul-macos --state open --search "transform" --limit 20 --json number,title,state,milestone,labels,url
gh issue list --repo postmelee/alhangeul-macos --state open --search "external image" --limit 20 --json number,title,state,milestone,labels,url
gh issue list --repo postmelee/alhangeul-macos --state open --search "equation" --limit 20 --json number,title,state,milestone,labels,url
gh issue list --repo postmelee/alhangeul-macos --state open --search "clip" --limit 20 --json number,title,state,milestone,labels,url
gh issue list --repo postmelee/alhangeul-macos --state open --search "Skia" --limit 30 --json number,title,state,milestone,labels,url
gh issue list --repo postmelee/alhangeul-macos --state open --search "fixture" --limit 30 --json number,title,state,milestone,labels,url
```

확인 결과:

| 이슈 | 상태 | Stage 4 연결 판단 |
|------|------|-------------------|
| #387 `Preview/Thumbnail Skia readiness 후속 개선 추적` | open | `KTX.hwp` Skia visual regression, Quick Look multi-page Skia latency, Thumbnail underfill/scale 관찰은 #387 하위 판단으로 연결한다. |
| #390 `rhwp v0.7.17 기준 Skia readiness gate 재측정` | closed | Stage 3 수치가 #390의 KTX sentinel 수치와 같은 계열임을 확인하는 기준 이력으로만 사용한다. 재오픈 대상은 아니다. |
| #391 `filename/external image context ABI 조사 및 bridge 설계` | open | external/large image data, filename context, missing/injected image diagnostic은 #391에 연결한다. 별도 ABI 구현 이슈는 #391 설계 결과 이후로 둔다. |
| #404 `upstream 렌더 PR 대표 샘플 diff 측정` | open | 현재 측정/분류 이슈. 신규 구현 범위는 이 이슈에서 직접 수행하지 않는다. |

축별 검색에서 `RawSvg`, `chart`, `transform`, `equation`, `clip`의 열린 전용 구현 이슈는 #404 외에 확인되지 않았다. 따라서 이 항목들은 Stage 5 최종 보고서에서 신규 이슈 후보로 제시하되, exact fixture 확인 전에는 구현 이슈로 바로 등록하지 않는 쪽이 안전하다.

## 후보 축별 분류

| 축 | Stage 3 근거 | 분류 | downstream 판단 |
|----|--------------|------|-----------------|
| RawSvg/차트 | `draw-group.hwp`, `eq-01.hwp` local proxy에서 blank/fallback 없음. chart exact와 일반 SVG vector RawSvg export는 미측정 | upstream 대기/별도 조사, 조건부 Swift CoreGraphics 보강 필요 | Swift `RawSvg`는 단일 raster image data URL만 성공 처리하고 일반 SVG vector는 fallback으로 간다. chart가 일반 SVG vector로 export되는 exact fixture가 확인되면 Swift RawSvg 확장 또는 Skia PNG 경로 우선 정책을 별도 구현 이슈로 분리한다. |
| Group/shape/transform | `group-drawing-02.hwp`, `draw-group.hwp` local proxy에서 hard fail 없음. Skia visual diff는 CG보다 낮음 | upstream 대기/별도 조사, 조건부 Swift CoreGraphics 보강 필요 | 현재 `GroupNode`에는 transform 필드가 없고 `renderGroup`도 group-level transform을 적용하지 않는다. upstream이 자식 bbox/transform을 평탄화하면 자동 반영, group matrix를 render tree에 남기면 Swift 모델/renderer 확장이 필요하다. |
| external/large image data | `pic-crop-01.hwp`, `복학원서.hwp` local image/crop sample은 정상. external BinData Link, large BinData, placeholder exact는 미측정 | upstream 대기/별도 조사, #391 연결 | 현재 Swift는 `ImageNode.bin_data_id`로 `rhwp_image_data`를 조회한다. image node가 있으나 bytes가 없는 경우의 placeholder/fallback, filename/external image context ABI는 #391 설계 범위로 넘긴다. |
| text/equation/font/clip/endnote | `MissingHangulGlyphs=0`. `eq-01.hwp`, `endnote-01.hwp`는 Skia diff가 CG보다 약간 높고 `tac-img-02.hwp`는 Skia가 약간 우세 | 자동 반영 후보 + visual watch | core가 Line/TextRun 좌표와 page layout을 기존 ABI/JSON shape로 개선하면 자동 반영된다. 다만 CoreText shaping/clip, equation SVG parser, table cell slack, footnote/endnote ordering은 exact fixture와 visual smoke가 필요하다. |
| page geometry baseline | page count/size/native PNG aspect 정상. Quick Look/Thumbnail fallback 0. `KTX.hwp` Skia visual diff 악화, multi-page Skia decode latency | 자동 반영 후보 + Skia default blocker | page geometry 자체는 upstream 자동 반영 후보지만, Skia default 전환은 #387에서 계속 막는다. CoreGraphics default 유지가 Stage 4 결론이다. |

## Swift renderer 보강 필요성

Stage 3 local proxy만으로 즉시 Swift renderer를 수정해야 하는 hard fail은 없다. 다만 다음 구조적 위험은 유지한다.

| 영역 | 현재 코드 신호 | 보강 트리거 |
|------|----------------|-------------|
| RawSvg 일반 SVG vector | `renderRawSvg`는 `decodeRawSvgSingleImageData` 성공 시에만 그리며 `image/svg+xml` data URL도 제외한다 | chart exact fixture에서 일반 SVG vector payload가 내려오고 Swift native PNG가 fallback 박스로 보이면 보강 |
| Group transform | `GroupNode`는 `sectionIndex`, `paraIndex`, `controlIndex`만 디코딩하고 `renderGroup`은 자식만 렌더한다 | upstream HWP3 exact fixture에서 group-level matrix가 render tree JSON에 남으면 모델/renderer 확장 |
| external image | `RhwpDocument.imageData(binDataId:)`와 `rhwp_image_data`는 내부 BinData index 조회만 제공한다 | external link 또는 missing bytes 상태를 deterministic하게 구분해야 하면 #391 ABI 설계 후 구현 |
| Equation/font/clip | equation SVG fragment parser와 CoreText/table clip은 Swift 자체 구현이다 | exact fixture에서 native PNG만 glyph/clip/baseline/order 차이가 남으면 targeted renderer 보강 |

## Skia 전환 후보와 blocker

| 항목 | Stage 3 관찰 | 판단 |
|------|--------------|------|
| Quick Look 단일 page PNG | `request.hwp`, `KTX.hwp`는 Skia direct/decode가 빠르거나 유사. `복학원서.hwp`는 CG가 조금 빠름 | opt-in diagnostic/fast path 유지. default 전환 근거로는 부족 |
| Quick Look multi-page PDF | `hwp-multi-001.hwp`, `hwpx-01.hwpx`에서 Skia decode가 CG보다 느림 | Skia default blocker |
| Thumbnail | 5개 sample 모두 fallback 0, signature separated. `KTX.hwp`는 Skia가 빠르고 나머지 일부는 CG가 빠름 | surface별 판단 필요. default 전환은 #387로 유지 |
| visual diff | `KTX.hwp` Skia changed percent가 CG 대비 +15.4874pp | Skia default blocker |
| group/tac local proxy | group sample과 `tac-img-02.hwp`는 Skia visual diff가 CG보다 낮음 | feature별 Skia 전환 후보 신호지만 global default 판단을 뒤집지는 않음 |

결론: Skia는 계속 opt-in diagnostic backend로 유지한다. Stage 4에서 default 전환 이슈를 새로 열 근거는 없고, #387에 KTX/latency/underfill 관찰을 연결하는 것이 맞다.

## 후속 이슈 분리안

### 기존 이슈에 연결

| 연결 대상 | 반영할 내용 | 이유 |
|----------|-------------|------|
| #387 | `KTX.hwp` Skia visual regression, Quick Look multi-page Skia latency, Thumbnail `request.hwp` underfill/scale 관찰 | 이미 Preview/Thumbnail Skia readiness 후속 개선 추적 이슈이며 default 전환 판단을 소유한다. |
| #391 | external BinData Link, large BinData, placeholder, filename context, missing/injected diagnostic | 이미 filename/external image context ABI 조사와 bridge 설계를 소유한다. |
| #390 | Stage 3 수치가 v0.7.17 readiness gate의 KTX sentinel과 같은 방향임을 최종 보고서에서 참조 | closed 측정 이력으로만 사용한다. |

### 신규 이슈 후보

아래 후보는 Stage 5 최종 보고서에서 초안으로 남기고, 작업지시자 승인 후 별도 등록한다.

| 후보 제목 | 목적 | 포함 범위 | 제외 |
|-----------|------|----------|------|
| upstream 렌더 exact fixture 편입과 #404 재측정 suite 확장 | Stage 3에서 미측정으로 남은 chart, HWP3 group, external/large BinData, TAC/endnote exact fixture를 확보하고 local proxy 측정과 구분한다 | upstream 샘플 임시 checkout, fixture 편입 후보 선정, render-debug/visual/Quick Look/Thumbnail smoke 재측정 | Swift renderer 구현, RustBridge ABI 구현 |
| RawSvg chart/vector payload 처리 정책 결정 | chart exact fixture에서 일반 SVG vector payload가 확인될 경우 Swift RawSvg 보강 또는 Skia PNG 경로 우선 정책을 결정한다 | RawSvg JSON shape inventory, fallback/blank 확인, Swift raster/vector 처리 범위 설계 | chart fixture 확보 전 구현, full SVG engine 도입 |
| HWP3 group transform render tree 호환 보강 | upstream group matrix가 Swift render tree에 남는 경우 `GroupNode` 모델과 `renderGroup` transform 적용을 보강한다 | exact fixture JSON shape 확인, transform decode, nested group render smoke | upstream이 transform을 평탄화하는 경우의 불필요한 구현 |
| text/equation/clip/endnote exact visual watch | TAC/endnote/equation exact fixture에서 CoreText, equation SVG parser, clip/order 차이를 분리한다 | visual diff, render-debug glyph/clip/order 판정, smoke 기준 추가 | blanket font fallback 교체, PDF option 포팅 |

### 지금 등록하지 않을 항목

| 항목 | 사유 |
|------|------|
| Skia default 전환 이슈 | `KTX.hwp` visual regression과 multi-page latency blocker가 남아 있다. #387에서 계속 추적한다. |
| external image ABI 구현 이슈 | #391의 설계 완료 전 구현 범위를 확정할 수 없다. |
| page geometry Swift 보강 이슈 | Stage 3에서 page count/size/aspect hard fail이 없다. ABI/JSON shape가 유지되면 upstream 개선은 자동 반영 후보다. |
| `qlmanage` SVG raster diff 실패 이슈 | optional 측정 경로 실패이며 renderer hard fail이 아니다. visual harness와 render-debug 필수 산출물로 대체 가능하다. |
| visual harness sandbox failure 이슈 | elevated rerun으로 측정 가능했다. 반복 운영에 문제가 되면 harness/environment 이슈로 별도 분리한다. |

## fixture 편입 후보와 보관 정책

| 후보군 | 필요성 | 우선순위 |
|--------|--------|----------|
| chart 일반 SVG vector sample | RawSvg/chart Swift fallback 여부 확인 | P0 |
| HWP3 group matrix sample | `GroupNode` transform 필요 여부 확인 | P0 |
| external BinData Link sample | #391 ABI 설계 검증 | P0 |
| large BinData/placeholder sample | missing bytes, placeholder/fallback 정책 확인 | P1 |
| TAC/endnote/equation exact sample | CoreText clip, equation parser, footnote/endnote ordering watch | P1 |

정책:

- upstream에서 가져온 샘플은 먼저 `build.noindex/task404-upstream-fixtures/` 또는 후속 이슈의 임시 output 아래에서 측정한다.
- 장기 fixture 편입은 라이선스, 크기, 개인정보, 재현성을 확인한 뒤 `samples/` 편입 후보로 별도 승인한다.
- 재생성 가능한 render output은 커밋하지 않는다.

## 기술 문서 업데이트 판단

`mydocs/tech/skia_quicklook_thumbnail_backend.md`는 이번 단계에서 수정하지 않는다. Stage 4는 정책 변경이 아니라 측정 결과 분류이며, Skia default 유지와 opt-in diagnostic 유지라는 기존 방향을 바꾸지 않는다.

최종 보고서 Stage 5에서 #404 결과 요약을 남긴 뒤, #387 또는 후속 이슈에서 default 전환 정책이 바뀔 때 기술 문서 업데이트를 수행한다.

## 검증 결과

| 명령 | 결과 |
|------|------|
| `gh issue list ... --search "RawSvg chart transform external image equation clip Skia"` | 통과. 통합 검색은 #404만 반환 |
| `gh issue view 387`, `gh issue view 390`, `gh issue view 391` | 통과. #387/#391 open, #390 closed 확인 |
| 축별 `gh issue list` 검색 | 통과. `external image`, `Skia`는 #387/#391/#404를 반환, `fixture`는 열린 이슈 없음 |
| `rg -n "자동 반영\|Skia 전환 후보\|Swift CoreGraphics 보강 필요\|upstream 대기\|후속 이슈\|#387\|#390\|#391" mydocs/working/task_m020_404_stage4.md` | 통과 |
| `git diff --check` | 통과 |

## 다음 단계 영향

Stage 5 최종 보고서에서는 다음을 확정한다.

- #404 자체는 측정/분류 이슈로 닫을 수 있다.
- Skia default 전환은 #387로 넘기고 CoreGraphics default 유지 결론을 명시한다.
- external image ABI는 #391로 넘긴다.
- 신규 이슈 후보는 exact fixture suite, RawSvg chart/vector, HWP3 group transform, text/equation/clip/endnote watch로 초안을 남긴다.

## 승인 요청

Stage 4는 downstream 보정 후보와 후속 이슈 분리안 작성으로 마무리한다. Stage 5 `최종 보고서와 PR 준비`로 진행하려면 작업지시자 승인이 필요하다.
