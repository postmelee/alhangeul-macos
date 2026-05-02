# Task M015 #107 Stage 2 완료 보고서

## 단계 목적

renderer 변경 작업에서 사용할 대표 샘플 지정 방식, core/native 비교 summary 기록 기준, 산출물 보관 규칙을 문서화했다.

작업지시자 피드백에 따라 특정 마일스톤의 샘플 목록은 일반 manual에 고정하지 않고 task-scoped tech 문서로 분리했다.

## 산출물

변경 파일:

| 파일 | 요약 |
|------|------|
| `mydocs/manual/render_core_native_compare_guide.md` | 작업별 대표 샘플 세트 일반 원칙, 보고서 기록 기준, 산출물 보관 규칙 추가 |
| `mydocs/manual/build_run_guide.md` | 기본 render smoke 이후 task별 대표 샘플 smoke/diff를 추가 수행하라는 일반 연결 추가 |
| `mydocs/tech/task_m015_107_render_sample_set.md` | M015 전용 필수 샘플과 기능별 후보 샘플 세트 정리 |
| `mydocs/working/task_m015_107_stage2.md` | Stage 2 완료 보고서 |

## 본문 변경 정도 / 본문 무손실 여부

기존 core/native 비교 절차, 기존 기본 샘플, 기존 `validate-stage3-render.sh`/`render-debug-compare.sh` 사용법은 유지했다.

이번 단계는 문서 보강이며 source code, script, fixture, build 설정은 변경하지 않았다.

## 변경 내용

`render_core_native_compare_guide.md`에는 특정 마일스톤명이나 특정 샘플명을 누적하지 않고 다음 일반 규칙만 남겼다.

- renderer 변경은 기본 smoke test만으로 충분하지 않을 수 있다.
- 시각 결과를 바꾸는 작업은 해당 task 문서에 대표 샘플 세트를 명시한다.
- 대표 샘플은 저장소 `samples/` 파일을 우선 사용한다.
- 마일스톤 또는 특정 이슈에만 해당하는 샘플 목록은 manual이 아니라 task-scoped 문서에 둔다.
- 모든 후보를 매번 full diff하지 않고 변경 범위와 직접 관련 있는 샘플만 추가 실행한다.

보고서 기록 기준은 일반 규칙으로 manual에 남겼다.

- `PageCount`
- `PageSizePt`, `NativePNGSize`
- `RenderTreeJSONBytes`
- `CoreSVGBytes`
- `NativeNonWhitePixels`
- `TextRuns`, `HangulRuns`, `HangulScalars`
- `MissingHangulGlyphs`
- `Diff`, `DiffReason`

산출물 보관 규칙도 일반 규칙으로 manual에 남겼다.

- 생성된 JSON/SVG/PNG/summary 산출물은 기본적으로 저장소에 커밋하지 않는다.
- 단계 보고서에는 출력 경로와 핵심 summary 값을 남긴다.
- PR 본문에는 샘플별 핵심 결과와 보고서 링크를 남긴다.
- 이미지 직접 리뷰가 필요할 때만 별도 첨부 또는 `mydocs/report/assets/` 추가 여부를 작업지시자와 확인한다.
- `qlmanage` 실패로 `DiffReason`만 기록돼도 필수 산출물 4종이 생성됐다면 core/native 비교 진단은 완료로 본다.

`build_run_guide.md`에는 기본 render smoke 이후 "해당 task 문서에서 정한 대표 샘플 smoke/diff"를 추가 수행하라는 일반 안내만 남겼다.

`mydocs/tech/task_m015_107_render_sample_set.md`에는 M015 전용 내용을 분리했다.

필수 smoke 샘플:

| 샘플 | 기준 역할 |
|------|----------|
| `samples/basic/BookReview.hwp` | 도형 children 아래 텍스트가 native renderer에 반영되는지 확인 |
| `samples/복학원서.hwp` | page/body 경계, layout overflow diagnostic, 제품 공통 렌더 경로 회귀 확인 |

기능 범주별 후보:

- 도형 children
- 도형/group/transform
- 이미지 기본 조회
- 이미지 crop/effect
- placeholder/form/field
- 텍스트 스타일/font

## 검증 결과

검증 명령:

```bash
git status --short --branch
rg -n "대표 샘플|summary|산출물 보관|renderer 변경" mydocs/manual/render_core_native_compare_guide.md mydocs/manual/build_run_guide.md
rg -n "M015|BookReview|복학원서|pic-crop|form-01|re-font" mydocs/tech/task_m015_107_render_sample_set.md
rg -n "M015|BookReview|복학원서" mydocs/manual/render_core_native_compare_guide.md mydocs/manual/build_run_guide.md
git diff --check -- mydocs/manual/render_core_native_compare_guide.md mydocs/manual/build_run_guide.md mydocs/tech/task_m015_107_render_sample_set.md mydocs/working/task_m015_107_stage2.md
```

작업 브랜치와 변경 상태:

```text
## local/task107
 M mydocs/manual/build_run_guide.md
 M mydocs/manual/render_core_native_compare_guide.md
 M mydocs/working/task_m015_107_stage2.md
?? mydocs/tech/task_m015_107_render_sample_set.md
```

manual 일반 규칙 검색 핵심 출력:

```text
mydocs/manual/render_core_native_compare_guide.md:69:## 작업별 대표 샘플 세트
mydocs/manual/render_core_native_compare_guide.md:71:renderer 변경은 기본 smoke test만으로 충분하지 않을 수 있다.
mydocs/manual/render_core_native_compare_guide.md:75:대표 샘플은 작업 범위와 직접 관련 있는 저장소 `samples/` 파일을 우선 사용한다.
mydocs/manual/render_core_native_compare_guide.md:151:## 보고서 기록 기준과 산출물 보관
mydocs/manual/render_core_native_compare_guide.md:167:산출물 보관 규칙:
mydocs/manual/build_run_guide.md:170:renderer 변경 작업에서는 기본 smoke test에 더해 해당 task 문서에서 정한 대표 샘플 smoke/diff를 추가 수행한다.
```

task-scoped tech 문서 검색 핵심 출력:

```text
mydocs/tech/task_m015_107_render_sample_set.md:1:# Task M015 #107 렌더 샘플 smoke/diff 세트
mydocs/tech/task_m015_107_render_sample_set.md:13:| `samples/basic/BookReview.hwp` | 도형 children 아래 텍스트가 native renderer에 반영되는지 확인 | render tree children 순회, core SVG text, native PNG text |
mydocs/tech/task_m015_107_render_sample_set.md:14:| `samples/복학원서.hwp` | page/body 경계, layout overflow diagnostic, 제품 공통 렌더 경로 회귀 확인 | render tree geometry, core SVG/native PNG 책임 경계, HostApp/Quick Look/Thumbnail 공통 renderer |
```

manual에 특정 M015 샘플명이 남아 있지 않은지 확인하는 검색은 출력 없이 종료됐다.

`git diff --check`는 출력 없이 통과했다.

## 잔여 위험

- 기능 범주별 후보 샘플 중 placeholder/form/field 후보는 실제 render tree node 존재를 아직 직접 확인하지 않았다. Stage 3 또는 관련 세부 이슈에서 실제 산출물 기준으로 좁혀야 한다.
- `복학원서.hwp`는 core layout 한계가 섞인 책임 경계 분리 샘플이므로, native renderer 단독 회귀 기준으로 과잉 해석하지 않아야 한다.
- 이번 단계는 문서화 단계라 실제 `BookReview.hwp`, `복학원서.hwp` render smoke/diff 실행은 Stage 3에서 수행한다.

## 다음 단계 영향

Stage 3에서는 task-scoped tech 문서의 기준이 실제 명령으로 재현되는지 확인한다.

검증 대상:

- `./scripts/validate-stage3-render.sh --help`
- `./scripts/render-debug-compare.sh --help`
- `./scripts/validate-stage3-render.sh /private/tmp/rhwp-task107-smoke samples/basic/BookReview.hwp samples/복학원서.hwp`
- `./scripts/render-debug-compare.sh /private/tmp/rhwp-task107-bookreview samples/basic/BookReview.hwp`
- `./scripts/render-debug-compare.sh /private/tmp/rhwp-task107-bokhak samples/복학원서.hwp`

Stage 3에서 script help나 README의 진입 안내가 manual 설명과 충돌하면 그때 제한적으로 보강한다.

## 승인 요청

Stage 2 문서화와 피드백 보정을 완료했다.

승인 후 Stage 3 `smoke/diff 실행 안내와 필수 샘플 검증`으로 진행한다.
