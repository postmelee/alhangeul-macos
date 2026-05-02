# Task M015 #107 Stage 2 완료 보고서

## 단계 목적

M015 renderer 보강 작업에서 사용할 필수 smoke 샘플, 기능별 대표 후보 샘플, core/native 비교 summary 기록 기준, 산출물 보관 규칙을 manual에 문서화했다.

## 산출물

변경 파일:

| 파일 | 요약 |
|------|------|
| `mydocs/manual/render_core_native_compare_guide.md` | M015 샘플 smoke/diff 세트, 기능 범주별 후보 샘플, 보고서 기록 기준, 산출물 보관 규칙 추가 |
| `mydocs/manual/build_run_guide.md` | 기본 render smoke 이후 M015 필수 샘플 검증으로 넘어가는 연결 추가 |
| `mydocs/working/task_m015_107_stage2.md` | Stage 2 완료 보고서 |

변경 후 문서 라인 수:

```text
332 mydocs/manual/render_core_native_compare_guide.md
284 mydocs/manual/build_run_guide.md
```

## 본문 변경 정도 / 본문 무손실 여부

기존 core/native 비교 절차, 기존 기본 샘플, 기존 `validate-stage3-render.sh`/`render-debug-compare.sh` 사용법은 유지했다.

이번 단계는 문서 추가 보강이며 source code, script, fixture, build 설정은 변경하지 않았다.

## 변경 내용

`render_core_native_compare_guide.md`에 `M015 렌더 보강 샘플 smoke/diff 세트` 섹션을 추가했다.

필수 smoke 샘플은 다음 두 개로 명시했다.

| 샘플 | 기준 역할 |
|------|----------|
| `samples/basic/BookReview.hwp` | 도형 children 아래 텍스트가 native renderer에 반영되는지 확인 |
| `samples/복학원서.hwp` | page/body 경계, layout overflow diagnostic, 제품 공통 렌더 경로 회귀 확인 |

기능 범주별 후보 샘플은 다음 범주로 정리했다.

- 도형 children
- 도형/group/transform
- 이미지 기본 조회
- 이미지 crop/effect
- placeholder/form/field
- 텍스트 스타일/font

`복학원서.hwp`는 core layout 한계가 섞인 책임 경계 분리 샘플로 설명했다. 이 샘플에서 차이가 보일 때 Swift renderer 회귀로 바로 단정하지 않고 core SVG, render tree geometry, native PNG가 같은 방향으로 어긋나는지 확인하도록 했다.

보고서 기록 기준은 다음 항목을 필수로 정리했다.

- `PageCount`
- `PageSizePt`, `NativePNGSize`
- `RenderTreeJSONBytes`
- `CoreSVGBytes`
- `NativeNonWhitePixels`
- `TextRuns`, `HangulRuns`, `HangulScalars`
- `MissingHangulGlyphs`
- `Diff`, `DiffReason`

산출물 보관 규칙은 다음 방향으로 명시했다.

- 생성된 JSON/SVG/PNG/summary 산출물은 기본적으로 저장소에 커밋하지 않는다.
- 단계 보고서에는 출력 경로와 핵심 summary 값을 남긴다.
- PR 본문에는 샘플별 핵심 결과와 보고서 링크를 남긴다.
- 이미지 직접 리뷰가 필요할 때만 별도 첨부 또는 `mydocs/report/assets/` 추가 여부를 작업지시자와 확인한다.
- `qlmanage` 실패로 `DiffReason`만 기록돼도 필수 산출물 4종이 생성됐다면 core/native 비교 진단은 완료로 본다.

`build_run_guide.md`에는 렌더링 smoke test 설명 뒤에 M015 필수 샘플 검증 명령을 추가하고, 세부 기준은 `render_core_native_compare_guide.md`의 M015 섹션을 따르도록 연결했다.

## 검증 결과

검증 명령:

```bash
git status --short --branch
rg -n "M015|BookReview|복학원서|NativeNonWhitePixels|CoreSVGBytes|DiffReason|산출물 보관" mydocs/manual/render_core_native_compare_guide.md mydocs/manual/build_run_guide.md
git diff --check -- mydocs/manual/render_core_native_compare_guide.md mydocs/manual/build_run_guide.md mydocs/working/task_m015_107_stage2.md
```

작업 브랜치와 변경 상태:

```text
## local/task107
 M mydocs/manual/build_run_guide.md
 M mydocs/manual/render_core_native_compare_guide.md
?? mydocs/working/task_m015_107_stage2.md
```

키워드 검색 핵심 출력:

```text
mydocs/manual/render_core_native_compare_guide.md:69:## M015 렌더 보강 샘플 smoke/diff 세트
mydocs/manual/render_core_native_compare_guide.md:75:| `samples/basic/BookReview.hwp` | 도형 children 아래 텍스트가 native renderer에 반영되는지 확인 | render tree children 순회, core SVG text, native PNG text |
mydocs/manual/render_core_native_compare_guide.md:76:| `samples/복학원서.hwp` | page/body 경계, layout overflow diagnostic, 제품 공통 렌더 경로 회귀 확인 | render tree geometry, core SVG/native PNG 책임 경계, HostApp/Quick Look/Thumbnail 공통 renderer |
mydocs/manual/render_core_native_compare_guide.md:162:## 보고서 기록 기준과 산출물 보관
mydocs/manual/render_core_native_compare_guide.md:171:| `CoreSVGBytes` | 필수 | core SVG 생성과 규모 변화 확인 |
mydocs/manual/render_core_native_compare_guide.md:172:| `NativeNonWhitePixels` | 필수 | native PNG blank 회귀 확인 |
mydocs/manual/render_core_native_compare_guide.md:175:| `Diff`, `DiffReason` | 필수 | 선택 산출물 생성 여부와 실패 사유 기록 |
mydocs/manual/render_core_native_compare_guide.md:178:산출물 보관 규칙:
mydocs/manual/build_run_guide.md:170:M015 renderer 보강 작업에서는 기본 smoke test에 더해 `samples/basic/BookReview.hwp`와 `samples/복학원서.hwp`를 필수 smoke 대상으로 확인한다.
mydocs/manual/build_run_guide.md:176:기능별 대표 샘플, `NativeNonWhitePixels`, `CoreSVGBytes`, `DiffReason` 같은 summary 기록 기준, 산출물 보관 규칙은 [`render_core_native_compare_guide.md`](render_core_native_compare_guide.md)의 "M015 렌더 보강 샘플 smoke/diff 세트"를 따른다.
```

`git diff --check`는 출력 없이 통과했다.

## 잔여 위험

- 기능 범주별 후보 샘플 중 placeholder/form/field 후보는 실제 render tree node 존재를 아직 직접 확인하지 않았다. Stage 3 또는 관련 세부 이슈에서 실제 산출물 기준으로 좁혀야 한다.
- `복학원서.hwp`는 core layout 한계가 섞인 책임 경계 분리 샘플이므로, native renderer 단독 회귀 기준으로 과잉 해석하지 않아야 한다.
- 이번 단계는 문서화 단계라 실제 `BookReview.hwp`, `복학원서.hwp` render smoke/diff 실행은 Stage 3에서 수행한다.

## 다음 단계 영향

Stage 3에서는 문서화한 기준이 실제 명령으로 재현되는지 확인한다.

검증 대상:

- `./scripts/validate-stage3-render.sh --help`
- `./scripts/render-debug-compare.sh --help`
- `./scripts/validate-stage3-render.sh /private/tmp/rhwp-task107-smoke samples/basic/BookReview.hwp samples/복학원서.hwp`
- `./scripts/render-debug-compare.sh /private/tmp/rhwp-task107-bookreview samples/basic/BookReview.hwp`
- `./scripts/render-debug-compare.sh /private/tmp/rhwp-task107-bokhak samples/복학원서.hwp`

Stage 3에서 script help나 README의 진입 안내가 manual 설명과 충돌하면 그때 제한적으로 보강한다.

## 승인 요청

Stage 2 문서화 결과를 승인 요청한다.

승인 후 Stage 3 `smoke/diff 실행 안내와 필수 샘플 검증`으로 진행한다.
