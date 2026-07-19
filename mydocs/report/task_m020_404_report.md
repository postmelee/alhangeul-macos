# Task #404 최종 보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | #404 `upstream 렌더 PR 대표 샘플 diff 측정` |
| 추적 이슈 | #387 Preview/Thumbnail Skia readiness 후속 개선 추적 |
| 마일스톤 | M020 `v0.2.x Skia Quick Look/Thumbnail Backend` |
| 단계 수 | 5 |
| 작업 브랜치 | `local/task404` |

최근 upstream `edwardkim/rhwp` 렌더 관련 PR을 RawSvg/차트, Group/transform, external image, text/equation/font/clip/endnote, page geometry 축으로 정리하고, 알한글 Quick Look/Thumbnail/native PNG 경로에서 local proxy sample diff를 측정했다.

최종 판단은 `CoreGraphics default + Skia opt-in diagnostic backend` 유지다. Stage 3 대표 샘플에서는 renderer hard fail이 0건이었고, page count/size/aspect, native non-white pixel, glyph sanity는 통과했다. 다만 `KTX.hwp`의 Skia visual diff 악화와 Quick Look multi-page Skia latency가 남아 Skia default 전환은 #387에서 계속 막는다.

제품 renderer, RustBridge ABI, `rhwp-core.lock`, sample fixture, 기술 정책 문서는 변경하지 않았다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `mydocs/plans/task_m020_404.md` | #404 수행계획서 |
| `mydocs/plans/task_m020_404_impl.md` | Stage 1-5 구현계획서 |
| `mydocs/working/task_m020_404_stage1.md` | upstream PR와 sample 후보 inventory |
| `mydocs/working/task_m020_404_stage2.md` | 측정 명령, output directory, summary 형식 확정 |
| `mydocs/working/task_m020_404_stage3.md` | 대표 sample render-debug, Quick Look, Thumbnail, visual diff 측정 |
| `mydocs/working/task_m020_404_stage4.md` | downstream 보정 후보와 후속 이슈 분리안 |
| `mydocs/report/task_m020_404_report.md` | 본 최종 보고서 |
| `mydocs/orders/20260705.md` | #404 오늘할일 완료 처리 |

`build.noindex/task404-*`와 `output/stage3-render/`에는 재생성 가능한 측정 산출물이 남아 있지만 커밋하지 않는다.

## 단계 요약

| Stage | 커밋 | 요약 |
|------|------|------|
| 계획 | `880215a` | 수행계획서 작성과 오늘할일 갱신 |
| 구현계획 | `378ef86` | 단계별 구현계획서 작성 |
| Stage 1 | `8cc8ece` | upstream 렌더 샘플 후보 inventory |
| Stage 2 | `e27d513` | 렌더 diff 측정 명령 확정 |
| Stage 3 | `dcca6c9` | 대표 샘플 렌더 diff 측정 |
| Stage 4 | `940ebd8` | downstream 보정 후보 분류 |
| Stage 5 | 이번 커밋 | 최종 보고서 작성과 PR 준비 상태 정리 |

## Stage 3 측정 결과 요약

### render-debug

11개 local proxy sample 모두 render tree JSON, core SVG, native PNG, summary가 생성됐다.

| 항목 | 결과 |
|------|------|
| 필수 산출물 | 모두 생성 |
| `NativeNonWhitePixels` | 모든 sample에서 0보다 충분히 큼 |
| page size/aspect | page point size와 native PNG size 정합 |
| `MissingHangulGlyphs` | 모든 sample 0 |
| renderer hard fail | 0 |
| optional `qlmanage` SVG raster diff | 11개 모두 실패, hard fail로 보지 않음 |

### Quick Look/Thumbnail

| surface | 결과 | 판단 |
|---------|------|------|
| Quick Look 단일 PNG | `request.hwp`, `KTX.hwp`, `복학원서.hwp` 모두 CG/Skia fallback 0 | Skia opt-in은 유효하지만 default 전환 근거로는 부족 |
| Quick Look multi-page PDF | `hwp-multi-001.hwp`, `hwpx-01.hwpx` 모두 fallback 0, Skia decode가 CG보다 느림 | Skia default blocker |
| Thumbnail | 5개 sample 모두 각 8회 request `failed=0`, cache signature separated | surface smoke는 통과, default 판단은 #387 유지 |

### visual diff

| File | CG ChangedPercent | Skia ChangedPercent | Skia-CG delta | 판단 |
|------|-------------------|---------------------|---------------|------|
| `KTX.hwp` | 30.8921% | 46.3795% | +15.4874pp | Skia default blocker |
| `group-drawing-02.hwp` | 4.1183% | 2.0477% | -2.0706pp | Skia 우세 신호 |
| `draw-group.hwp` | 0.8132% | 0.7367% | -0.0765pp | 유사, Skia 약간 우세 |
| `tac-img-02.hwp` | 4.0975% | 3.7309% | -0.3666pp | 유사, Skia 약간 우세 |
| `eq-01.hwp` | 6.4963% | 7.2690% | +0.7727pp | watch |
| `endnote-01.hwp` | 7.1197% | 8.1352% | +1.0155pp | watch |
| `pic-crop-01.hwp` | 2.0423% | 3.0393% | +0.9970pp | watch |
| `복학원서.hwp` | 7.2888% | 6.9406% | -0.3482pp | known layout risk, hard fail 아님 |

CoreGraphics visual diff 1차 sandbox 실행은 WebKit/AppKit readiness timeout으로 실패했지만, elevated rerun에서 통과했다. 이 실패는 renderer hard fail이 아니라 측정 환경 이슈로 분리한다.

## 후보 축별 최종 판단

| 축 | 최종 분류 | 근거 | 처리 |
|----|-----------|------|------|
| RawSvg/차트 | upstream 대기/별도 조사, 조건부 Swift CoreGraphics 보강 필요 | local RawSvg proxy는 blank/fallback 없음. chart exact와 일반 SVG vector RawSvg export는 미측정. Swift `RawSvg`는 단일 raster image data URL만 성공 처리 | exact fixture 확보 후 신규 이슈 후보 |
| Group/shape/transform | upstream 대기/별도 조사, 조건부 Swift CoreGraphics 보강 필요 | local group proxy는 hard fail 없음. `GroupNode`에는 transform 필드가 없고 `renderGroup`은 group-level transform을 적용하지 않음 | HWP3 exact fixture에서 group matrix 확인 후 신규 이슈 후보 |
| external/large image data | upstream 대기/별도 조사, #391 연결 | local image/crop sample은 정상. external BinData Link, large BinData, placeholder exact는 미측정. 현재 계약은 `bin_data_id -> rhwp_image_data` | #391로 연결, ABI 구현은 설계 후 분리 |
| text/equation/font/clip/endnote | 자동 반영 후보 + visual watch | glyph 누락 없음. CoreText, equation SVG parser, table clip, footnote/endnote ordering은 Swift 자체 구현이라 exact fixture 필요 | 신규 watch 이슈 후보 |
| page geometry | 자동 반영 후보 + Skia default blocker | page count/size/aspect hard fail 없음. `KTX.hwp` Skia visual diff와 multi-page latency blocker 유지 | CoreGraphics default 유지, #387 연결 |

## 기존 이슈 연결

| 이슈 | 연결 내용 |
|------|-----------|
| #387 | `KTX.hwp` Skia visual regression, Quick Look multi-page Skia latency, Thumbnail `request.hwp` underfill/scale 관찰을 Preview/Thumbnail Skia readiness 판단으로 넘긴다. |
| #391 | external BinData Link, large BinData, placeholder, filename context, missing/injected diagnostic을 filename/external image context ABI 설계로 넘긴다. |
| #390 | `KTX.hwp` sentinel 수치가 같은 방향으로 유지됐다는 측정 이력으로만 참조한다. closed 상태를 유지한다. |

## 후속 이슈 초안

아래 항목은 즉시 등록하지 않고 작업지시자 승인 대상으로 남긴다.

### 1. upstream 렌더 exact fixture 편입과 #404 재측정 suite 확장

목적:

- Stage 3에서 미측정으로 남은 chart, HWP3 group, external/large BinData, TAC/endnote exact fixture를 확보한다.
- local proxy 측정과 upstream exact regression 판정을 분리한다.

범위:

- upstream 샘플 임시 checkout
- fixture 편입 후보 선정
- render-debug, visual diff, Quick Look, Thumbnail smoke 재측정
- 라이선스/크기/개인정보/재현성 기준 정리

제외:

- Swift renderer 구현
- RustBridge ABI 구현

### 2. RawSvg chart/vector payload 처리 정책 결정

목적:

- chart exact fixture에서 일반 SVG vector payload가 확인될 경우 Swift RawSvg 보강 또는 Skia PNG 경로 우선 정책을 결정한다.

범위:

- RawSvg JSON shape inventory
- fallback/blank 여부 확인
- Swift raster/vector 처리 범위 설계

제외:

- chart fixture 확보 전 구현
- full SVG engine 도입

### 3. HWP3 group transform render tree 호환 보강

목적:

- upstream group matrix가 Swift render tree에 남는 경우 `GroupNode` 모델과 `renderGroup` transform 적용을 보강한다.

범위:

- exact fixture JSON shape 확인
- transform decode 설계
- nested group render smoke

제외:

- upstream이 transform을 평탄화하는 경우의 불필요한 구현

### 4. text/equation/clip/endnote exact visual watch

목적:

- TAC/endnote/equation exact fixture에서 CoreText, equation SVG parser, clip/order 차이를 분리한다.

범위:

- visual diff
- render-debug glyph/clip/order 판정
- smoke 기준 추가

제외:

- blanket font fallback 교체
- PDF option 포팅

## 지금 하지 않을 작업

| 항목 | 이유 |
|------|------|
| Skia default 전환 | `KTX.hwp` visual regression과 multi-page latency blocker가 남아 있다. #387에서 계속 추적한다. |
| external image ABI 구현 | #391 설계 완료 전 구현 범위를 확정할 수 없다. |
| page geometry Swift 보강 | Stage 3에서 page count/size/aspect hard fail이 없다. 기존 ABI/JSON shape가 유지되면 upstream 개선 자동 반영 후보다. |
| 기술 문서 정책 변경 | 이번 작업은 측정/분류이며 `CoreGraphics default + Skia opt-in` 기존 정책을 바꾸지 않는다. |
| upstream exact fixture 편입 | 라이선스, 크기, 개인정보, 재현성 확인과 작업지시자 승인이 먼저 필요하다. |

## residual risk

| 항목 | 상태 | 처리 |
|------|------|------|
| chart exact 미측정 | 잔여 | upstream chart fixture 확보 후 재측정 |
| HWP3 group matrix 미측정 | 잔여 | `issue1892_*` exact fixture 확보 후 판단 |
| external/large BinData 미측정 | 잔여 | #391에서 ABI 설계와 fixture 정책 확인 |
| `qlmanage` SVG raster diff 실패 | 잔여 | optional 경로 실패로 기록. visual harness와 render-debug 필수 산출물로 대체 |
| visual harness sandbox readiness timeout | 잔여 | elevated 실행으로 측정 가능. 반복 운영 문제가 되면 harness/environment 이슈 분리 |
| `복학원서.hwp` `LAYOUT_OVERFLOW` warning | 잔여 | known layout/displayText risk로 유지 |

## 검증 결과

| 명령 | 결과 |
|------|------|
| `gh pr view ... --repo edwardkim/rhwp` 계열 Stage 1 조회 | 통과. upstream PR/sample 후보 inventory 완료 |
| Stage 2 script help와 framework 존재 확인 | 통과. 측정 명령과 산출물 형식 확정 |
| `./scripts/validate-stage3-render.sh` | 통과 |
| `./scripts/render-debug-compare.sh build.noindex/task404-render-debug ...` | 통과. 11개 sample 필수 산출물 생성 |
| `./scripts/smoke-quicklook-skia-policy.sh build.noindex/task404-quicklook-policy ...` | 통과 |
| `./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task404-thumbnail-policy ...` | 통과 |
| `./scripts/preview-visual-diff-harness.sh ... --policy coreGraphicsOnly` | sandbox 1차 실패 후 elevated rerun 통과 |
| `./scripts/preview-visual-diff-harness.sh ... --policy skiaOptIn` | elevated 실행 통과 |
| `gh issue list/view` Stage 4 중복 확인 | 통과. #387/#391 연결, #390 closed 이력 확인 |
| `rg -n "#404\|RawSvg\|Group\|external\|text/equation\|page geometry\|후속\|residual" mydocs/report/task_m020_404_report.md mydocs/orders` | 통과 |
| `git diff --check` | 통과 |

## PR 게시 준비 메모

권장 PR 제목:

```text
Task #404: upstream 렌더 PR 대표 샘플 diff 측정
```

권장 리뷰 포인트:

- 제품 코드 변경 없이 측정/판단 문서만 추가한 범위가 맞는지
- Stage 3 local proxy 기준 hard fail 0건이라는 해석이 적절한지
- `KTX.hwp` Skia visual regression과 multi-page latency를 #387 default blocker로 유지하는 판단이 타당한지
- RawSvg/chart, HWP3 group transform, external image ABI, text/equation/clip/endnote를 exact fixture 확인 후 후속 이슈로 분리하는 정렬이 적절한지
- upstream exact fixture를 바로 `samples/`에 편입하지 않고 별도 승인 대상으로 둔 정책이 맞는지

PR 게시 전 상태:

- 최종 보고서 작성 완료
- 오늘할일 완료 처리
- final diff는 문서 변경만 포함
- PR 게시에는 작업지시자 승인 후 `publish/task404` 브랜치와 PR 생성 단계가 필요

## 작업지시자 승인 요청

Task #404의 측정, downstream 보정 후보 분류, 최종 보고서 작성을 완료했다. PR 게시 단계 진입 여부를 승인해 달라.
