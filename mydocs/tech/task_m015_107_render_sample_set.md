# Task M015 #107 렌더 샘플 smoke/diff 세트

## 목적

M015(`첫 출시 전 Swift 렌더 보강`) renderer 작업에서 사용할 대표 샘플 smoke/diff 세트를 task 범위로 정리한다.

이 문서는 장기 일반 매뉴얼이 아니라 Task #107의 기술 기준 문서다. M015 이후 샘플 세트가 바뀌면 새 task 문서나 최종 보고서에서 갱신한다.

## 필수 smoke 샘플

M015 renderer 작업은 기본 `validate-stage3-render.sh` smoke test와 별도로 다음 두 샘플을 필수 smoke 대상으로 확인한다.

| 샘플 | 확인 목적 | 주요 확인 계층 |
|------|----------|----------------|
| `samples/basic/BookReview.hwp` | 도형 children 아래 텍스트가 native renderer에 반영되는지 확인 | render tree children 순회, core SVG text, native PNG text |
| `samples/복학원서.hwp` | page/body 경계, layout overflow diagnostic, 제품 공통 렌더 경로 회귀 확인 | render tree geometry, core SVG/native PNG 책임 경계, HostApp/Quick Look/Thumbnail 공통 renderer |

기본 명령:

```bash
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task107-smoke samples/basic/BookReview.hwp samples/복학원서.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task107-bookreview samples/basic/BookReview.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task107-bokhak samples/복학원서.hwp
```

`복학원서.hwp`는 core layout 한계가 섞인 책임 경계 분리 샘플이다. 이 샘플에서 차이가 보이면 바로 Swift renderer 회귀로 단정하지 말고 core SVG, render tree geometry, native PNG가 같은 방향으로 어긋나는지 먼저 확인한다.

## 기능 범주별 후보 샘플

후보 샘플은 작업 범위와 직접 관련 있을 때만 추가 실행한다. 모든 후보를 매번 full diff하지 않는다.

| 범주 | 후보 샘플 | 사용 기준 |
|------|----------|----------|
| 도형 children | `samples/basic/BookReview.hwp` | 도형 아래 텍스트 순회 회귀 확인 |
| 도형/group/transform | `samples/group-drawing-02.hwp`, `samples/group-box.hwp`, `samples/draw-group.hwp`, `samples/shape-group-02.hwp` | group, line transform, nested shape 처리 변경 시 |
| 이미지 기본 조회 | `samples/hwp-img-001.hwp`, `samples/pic-in-head-02.hwp`, `samples/pic-in-table-01.hwp`, `samples/tac-img-02.hwp` | `bin_data_id` 이미지 조회나 image cache 변경 시 |
| 이미지 crop/effect | `samples/pic-crop-01.hwp`, `samples/복학원서.hwp`, `samples/20250130-hongbo.hwp`, `samples/aift.hwp` | crop, transparency, brightness, contrast, watermark/effect 변경 시 |
| placeholder/form/field | `samples/form-01.hwp`, `samples/hwpx/form-002.hwpx`, `samples/field-01.hwp`, `samples/field-01-memo.hwp` | FormObject, placeholder, field, memo 정적 프리뷰 변경 시. 실제 render tree node 존재를 먼저 확인한다. |
| 텍스트 스타일/font | `samples/re-font-*.hwp`, `samples/re-align-*.hwp`, `samples/lseg-02-mixed.hwp`, `samples/lseg-03-spacing.hwp`, `samples/lseg-04-indent.hwp`, `samples/lseg-05-tab.hwp`, `samples/lseg-06-multisize.hwp` | font, align, spacing, indent, tab, multisize style 변경 시 |

## 보고서 기록 기준

샘플별 `render-debug-compare.sh` 결과는 `mydocs/manual/render_core_native_compare_guide.md`의 보고서 기록 기준을 따른다.

Task #107 Stage 3에서는 최소한 다음 값을 필수 샘플별 표로 기록한다.

- `PageCount`
- `PageSizePt`, `NativePNGSize`
- `RenderTreeJSONBytes`
- `CoreSVGBytes`
- `NativeNonWhitePixels`
- `TextRuns`, `HangulRuns`, `HangulScalars`
- `MissingHangulGlyphs`
- `Diff`, `DiffReason`

`qlmanage` 실패로 diff PNG가 생성되지 않더라도 render tree JSON, core SVG, native PNG, summary가 생성되면 필수 산출물 검증은 통과로 본다.
