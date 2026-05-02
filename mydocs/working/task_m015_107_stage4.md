# Task M015 #107 Stage 4 완료 보고서

## 단계 목적

Stage 1-3과 Stage 2.1 보정 결과를 통합해 문서와 스크립트 변경의 최종 정합성을 확인했다.

특히 특정 마일스톤 검증 세트가 장기 manual 문서에 고정되지 않도록, M015 전용 샘플 표는 `mydocs/tech/task_m015_107_render_sample_set.md`에만 남기고 manual에는 일반 규칙만 남는지 다시 확인했다.

## 산출물

| 파일 | 요약 |
|------|------|
| `mydocs/working/task_m015_107_stage4.md` | Stage 4 완료 보고서 |
| `mydocs/report/task_m015_107_report.md` | Task #107 최종 보고서 |
| `mydocs/orders/20260502.md` | #107 완료 상태와 완료 시각 기록 |

## 문서 범위 정합성

최종 문서 구조는 다음 기준으로 정리했다.

| 문서 | 역할 |
|------|------|
| `mydocs/manual/render_core_native_compare_guide.md` | core/native 비교 절차, 작업별 샘플 세트 선정 원칙, summary 기록 항목, 산출물 보관 규칙 |
| `mydocs/manual/build_run_guide.md` | renderer 변경 시 task 문서의 대표 샘플 smoke/diff를 추가 수행한다는 일반 검증 관문 |
| `mydocs/tech/task_m015_107_render_sample_set.md` | M015 Task #107 범위의 필수 샘플과 기능별 후보 샘플 |

이 구조에 따라 manual 문서는 특정 마일스톤 샘플 표를 직접 소유하지 않는다. 장기 유지되는 manual에는 "작업별 대표 샘플 세트는 해당 task 문서에 둔다"는 일반 원칙만 남겼다.

## 최종 검증

작업 브랜치 시작 상태:

```text
## local/task107
```

문서/스크립트 검색:

```bash
rg -n "M015|BookReview|복학원서|render-debug-compare|validate-stage3-render|NativeNonWhitePixels|산출물 보관" README.md mydocs scripts
```

확인 결과:

- `mydocs/tech/task_m015_107_render_sample_set.md`에서 M015 필수 샘플과 기능별 후보 샘플이 검색된다.
- `mydocs/manual/render_core_native_compare_guide.md`에서 작업별 대표 샘플 세트, summary 기록 항목, 산출물 보관 규칙이 검색된다.
- `mydocs/manual/build_run_guide.md`에서 renderer 변경 시 task 범위 대표 샘플 smoke/diff를 추가 수행한다는 일반 문장이 검색된다.
- Stage 보고서와 구현 계획서에는 작업 이력으로 M015, `BookReview.hwp`, `복학원서.hwp`가 남아 있다.

script syntax:

```bash
bash -n scripts/validate-stage3-render.sh scripts/render-debug-compare.sh
```

결과: 출력 없이 통과.

shared Swift boundary:

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

diff whitespace:

```bash
git diff --check
```

결과: 출력 없이 통과.

## 잔여 위험

- Stage 3에서 `qlmanage` sandbox 오류로 core raster PNG와 pixel diff PNG는 생성되지 않았다. render tree JSON, core SVG, native PNG, summary는 필수 산출물로 생성됐다.
- `samples/복학원서.hwp`는 layout overflow diagnostic이 남아 있다. 이 샘플은 task-scoped tech 문서 기준대로 core/native 책임 경계 분리 샘플로 취급한다.
- 기능 범주별 후보 샘플 전체 full diff는 이번 작업 범위가 아니다. 이후 renderer 세부 이슈에서 변경 대상 기능에 맞춰 선택 실행한다.

## 다음 단계

본 Stage 4와 최종 보고서 검토 후, 작업지시자 승인 시 `publish/task107` push와 `devel` 대상 draft PR 생성 절차로 진행한다.
