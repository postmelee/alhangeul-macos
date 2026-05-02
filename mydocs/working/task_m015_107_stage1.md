# Task M015 #107 Stage 1 완료 보고서

## 단계 목적

현행 render smoke/diff 도구가 생성하는 산출물과 보고서 기록값을 확인하고, M015 렌더 보강 작업에서 반복 사용할 필수 샘플과 기능 범주별 후보 샘플을 조사했다.

이번 단계는 조사와 기준 정리만 수행했으며 source, script, manual 본문은 변경하지 않았다.

## 산출물

변경 파일:

- `mydocs/working/task_m015_107_stage1.md`

조사 대상:

- `scripts/validate-stage3-render.sh`
- `scripts/stage3_render_check.swift`
- `scripts/render-debug-compare.sh`
- `scripts/render_debug_compare.swift`
- `README.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/manual/render_core_native_compare_guide.md`
- 기존 단계 보고서와 최종 보고서
- `samples/` 저장소 샘플 목록

## 본문 변경 정도 / 본문 무손실 여부

제품 source, script, manual, README 본문은 변경하지 않았다.

이번 단계의 tracked 변경 대상은 단계 보고서 추가뿐이다.

## 조사 결과

### 현행 도구 출력 항목

`validate-stage3-render.sh`는 `stage3_render_check.swift`를 빌드해 첫 페이지 native PNG를 생성하고 다음 조건을 smoke로 확인한다.

- document open, page count, render tree 생성
- text run 존재
- Hangul text run과 Hangul scalar 존재
- Hangul glyph lookup 누락 없음
- page size 유효성
- native PNG non-white pixel 존재

성공 출력은 한 줄 summary 형태다.

```text
OK {file}: page=1 size={width}x{height} textRuns={N} hangulRuns={N} hangulScalars={N} nonWhitePixels={N} png={path}
```

`render-debug-compare.sh`는 `render_debug_compare.swift`를 빌드해 필수 산출물 4종을 생성한다.

- `{sample}-page{N}-render-tree.json`
- `{sample}-page{N}-core.svg`
- `{sample}-page{N}-native.png`
- `{sample}-page{N}-summary.txt`

summary에서 Stage 보고서에 기본 기록할 값은 다음으로 확정한다.

| 항목 | 용도 |
|------|------|
| `PageCount` | page 범위와 다중 page 샘플 여부 확인 |
| `PageSizePt` / `NativePNGSize` | page size와 bitmap 반올림 확인 |
| `RenderTreeJSONBytes` | render tree 규모와 nil/축소 회귀 확인 |
| `CoreSVGBytes` | core SVG 생성과 규모 확인 |
| `NativeNonWhitePixels` | native PNG blank 회귀 확인 |
| `TextRuns` / `HangulRuns` / `HangulScalars` | 텍스트와 한글 run 존재 확인 |
| `MissingHangulGlyphs` | font fallback/glyph lookup 문제 분리 |
| `Diff` / `DiffReason` | 선택 산출물 생성 여부와 실패 사유 기록 |

`CoreRasterPNG`, `DiffPNG`, `DiffDifferentPixels`, `DiffDifferentPixelRatio`는 `qlmanage` rasterize가 성공한 경우에만 추가 기록한다. 기존 보고서들에서 `qlmanage` sandbox 오류가 반복 확인되므로, 이 값은 필수 성공 기준으로 두지 않는 것이 맞다.

### 필수 샘플

| 샘플 | 기준 역할 | 근거 |
|------|----------|------|
| `samples/basic/BookReview.hwp` | 도형 children 아래 텍스트가 native renderer에 반영되는지 확인 | Task #108에서 `Rectangle` children 아래 `TextLine`/`TextRun` 누락을 재현하고 보강 기준으로 사용 |
| `samples/복학원서.hwp` | page/body 경계, layout overflow diagnostic, 제품 경로 회귀 확인 | Task #90에서 page bbox 밖 layout overflow와 core/native 산출물 기준으로 사용, Task #84에서 Viewer bounds/image cache 회귀 확인에 반복 사용 |

`BookReview.hwp`는 M015 도형 children 보강의 직접 기준이다. Task #108 Stage 1에서 render tree에는 `TextRun=66`, `HangulRuns=28`, `MissingHangulGlyphs=0`이 있었고, core SVG에도 `<text>`가 존재했지만 기존 native PNG에서는 텍스트가 누락됐다. Task #108 Stage 4에서는 native PNG non-white pixel이 `377463`에서 `390859`로 증가했고 텍스트 표시가 회복됐다.

`복학원서.hwp`는 core layout 한계가 섞일 수 있으므로 "native renderer가 모두 해결해야 하는 샘플"이 아니라 책임 경계 분리 샘플로 다뤄야 한다. Task #90 Stage 1에서 `RenderTreeJSONBytes=189402`, `CoreSVGBytes=341594`, `NativeNonWhitePixels=163193`, `TextRuns=102`, `HangulRuns=25`, `MissingHangulGlyphs=0`으로 필수 산출물은 생성됐고, `LAYOUT_OVERFLOW` diagnostic이 재현됐다.

### 기능 범주별 후보 샘플

| 범주 | 후보 샘플 | 후보 이유 | Stage 2 문서화 판단 |
|------|----------|-----------|--------------------|
| 도형 children | `samples/basic/BookReview.hwp` | `Rectangle` children 아래 텍스트 누락/회복의 직접 샘플 | 필수 |
| 도형/group/transform | `samples/group-drawing-02.hwp`, `samples/group-box.hwp`, `samples/draw-group.hwp`, `samples/shape-group-02.hwp` | group drawing, line transform, shape/group 구조 확인에 쓰인 이력 또는 파일명 근거 | 후보 |
| 이미지 기본 조회 | `samples/hwp-img-001.hwp`, `samples/pic-in-head-02.hwp`, `samples/pic-in-table-01.hwp`, `samples/tac-img-02.hwp` | Task #76에서 image node와 `bin_data_id` 조회 smoke에 사용 | 후보 |
| 이미지 crop/effect | `samples/pic-crop-01.hwp`, `samples/복학원서.hwp`, `samples/20250130-hongbo.hwp`, `samples/aift.hwp` | crop 전용 샘플명, watermark/effect 관련 이력, 문서 전환 image cache 검증 이력 | 후보 |
| placeholder/form/field | `samples/form-01.hwp`, `samples/hwpx/form-002.hwpx`, `samples/field-01.hwp`, `samples/field-01-memo.hwp` | form/field/memo 샘플명과 M015 placeholder/form 범위 | 후보, 실제 노드 존재 검증 필요 |
| 텍스트 스타일/font | `samples/re-font-*.hwp`, `samples/re-align-*.hwp`, `samples/lseg-06-multisize.hwp`, `samples/lseg-02-mixed.hwp`, `samples/lseg-03-spacing.hwp`, `samples/lseg-04-indent.hwp`, `samples/lseg-05-tab.hwp` | font, align, line segment, spacing/indent/tab 스타일 후보 | 후보 |
| 기본 native smoke | `samples/basic/KTX.hwp`, `samples/basic/request.hwp`, `samples/exam_kor.hwp` | `validate-stage3-render.sh` 기본 샘플 | 기존 기본 smoke 유지 |

### Stage 2 보강 범위

Stage 2에서는 `render_core_native_compare_guide.md`에 M015 샘플 smoke/diff 세트를 추가하는 것이 적절하다.

필수로 문서화할 내용:

- `BookReview.hwp`, `복학원서.hwp`를 M015 필수 smoke 대상으로 명시
- 기능 범주별 후보 샘플 표 추가
- summary 필수 기록값 표 추가
- 생성 산출물은 저장소에 커밋하지 않고 로컬 출력 경로와 핵심 summary 값을 단계 보고서에 남기는 규칙 추가
- `qlmanage` diff 실패는 선택 산출물 실패로 분리

`build_run_guide.md`에는 기존 기본 smoke 설명을 유지하되, renderer 보강 작업에서는 M015 필수 샘플 smoke/diff 세트로 넘어가라는 연결만 추가하는 것이 적절하다.

script help와 README는 Stage 3에서 실제 실행 안내와 충돌하는지 확인한 뒤 필요할 때만 보강한다.

## 검증 결과

검증 명령:

```bash
git status --short --branch
rg -n "BookReview|복학원서|render-debug-compare|validate-stage3-render|NativeNonWhitePixels|TextRuns|HangulRuns|MissingHangulGlyphs" README.md mydocs scripts
rg --files samples
test -f samples/basic/BookReview.hwp
test -f samples/복학원서.hwp
git diff --check -- mydocs/working/task_m015_107_stage1.md
```

핵심 출력:

```text
## local/task107
```

`rg` 결과에서 다음 근거가 확인됐다.

```text
README.md:373:1. `validate-stage3-render.sh` → 기본 샘플의 native render pipeline smoke 확인
README.md:374:2. `render-debug-compare.sh` → 특정 파일의 render tree JSON, core SVG, native PNG, pixel diff 산출
scripts/render_debug_compare.swift:259:        NativeNonWhitePixels: \(nativeResult.nonWhitePixels)
scripts/render_debug_compare.swift:261:        TextRuns: \(stats.textRunCount)
scripts/render_debug_compare.swift:262:        HangulRuns: \(stats.hangulRunCount)
scripts/render_debug_compare.swift:264:        MissingHangulGlyphs: \(stats.missingGlyphCount)
mydocs/working/task_m015_108_stage1.md:108:NativeNonWhitePixels: 377463
mydocs/working/task_m015_108_stage1.md:109:TextRuns: 66
mydocs/working/task_m015_108_stage1.md:110:HangulRuns: 28
mydocs/working/task_m010_90_stage1.md:72:TextRuns: 102
mydocs/working/task_m010_90_stage1.md:73:HangulRuns: 25
```

`rg --files samples` 결과에서 필수 샘플과 후보 샘플이 모두 저장소 샘플 경로에 존재함을 확인했다.

```text
samples/basic/BookReview.hwp
samples/복학원서.hwp
samples/pic-crop-01.hwp
samples/hwp-img-001.hwp
samples/pic-in-head-02.hwp
samples/pic-in-table-01.hwp
samples/tac-img-02.hwp
samples/group-drawing-02.hwp
samples/form-01.hwp
samples/hwpx/form-002.hwpx
samples/field-01.hwp
samples/field-01-memo.hwp
samples/lseg-06-multisize.hwp
```

필수 샘플 파일 존재 확인:

```text
test -f samples/basic/BookReview.hwp: 통과
test -f samples/복학원서.hwp: 통과
```

`git diff --check -- mydocs/working/task_m015_107_stage1.md`는 출력 없이 통과했다.

## 잔여 위험

- Stage 1은 샘플 후보를 파일명과 기존 작업 이력으로 분류했다. 일부 후보는 Stage 2 문서화 전 실제 render tree node 존재 여부를 더 좁혀야 할 수 있다.
- `복학원서.hwp`는 core layout overflow가 섞인 샘플이므로 Swift native renderer 단독 회귀 판단 기준으로 쓰면 과잉 해석 위험이 있다.
- form/field/placeholder 후보는 기존 보고서 근거가 적으므로 Stage 2에서 "후보, 실제 노드 확인 필요"로 명시해야 한다.
- `rg` 결과에는 과거 작업 보고서의 예전 경로와 외부 개인 경로가 섞여 있다. Stage 2 문서화 기준은 저장소 `samples/` 경로로 제한해야 한다.

## 다음 단계 영향

Stage 2에서는 `render_core_native_compare_guide.md`와 `build_run_guide.md`를 보강한다.

구체적으로 다음을 반영한다.

- M015 필수 smoke 샘플 2개
- 기능 범주별 후보 샘플 표
- summary 핵심 기록값 표
- 로컬 산출물 보관 규칙
- `qlmanage` diff 실패 처리 기준

## 승인 요청

Stage 1 조사 결과를 승인 요청한다.

승인 후 Stage 2 `필수 smoke 세트와 산출물 기록 기준 문서화`로 진행한다.
