# Task M015 #107 최종 보고서

## 작업 개요

- 이슈: #107 Swift 렌더 보강 샘플 smoke/diff 검증 세트 정리
- 마일스톤: M015 `첫 출시 전 Swift 렌더 보강`
- 브랜치: `local/task107`
- 작업 위치: `/private/tmp/rhwp-mac-task107`

이번 작업은 M015 renderer 보강 작업에서 반복 사용할 샘플 smoke/diff 기준을 정리하고, 실제 필수 샘플 2개가 현재 도구로 재현되는지 확인했다.

사용자 리뷰에 따라 특정 마일스톤 샘플 표는 장기 manual 문서에 고정하지 않고, task 범위 기술 문서인 `mydocs/tech/task_m015_107_render_sample_set.md`로 이동했다. manual 문서는 작업별 샘플 세트를 task 문서에 둔다는 일반 원칙만 유지한다.

## 결과 요약

- M015 필수 샘플을 `samples/basic/BookReview.hwp`, `samples/복학원서.hwp`로 정리했다.
- 기능별 후보 샘플을 도형 children, 이미지 crop/effect, placeholder/form, 스타일 보강 범주로 나눠 task-scoped tech 문서에 기록했다.
- core/native 비교 manual에는 summary 기록 항목과 산출물 보관 규칙을 일반화해 남겼다.
- build/run guide에는 renderer 변경 시 관련 task 문서의 대표 샘플 smoke/diff를 추가 수행한다는 일반 관문만 남겼다.
- `render-debug-compare.sh --help`가 사용법 출력 후 exit code 0으로 종료되도록 보강했다.
- 필수 샘플 2개에 대해 native smoke와 core/native debug compare를 실행하고 핵심 summary 값을 기록했다.

## 단계별 결과

| 단계 | 커밋 | 결과 |
|------|------|------|
| 시작 | `2c0ae4c` | 수행 계획서와 오늘할일 작성 |
| 구현 계획 | `db9dd9f` | 4단계 구현 계획 수립 |
| Stage 1 | `761d8ea` | 현행 도구, 샘플 사용 이력, summary 기록 항목 조사 |
| Stage 2 | `272e33c` | 최초 문서화 |
| Stage 2.1 | `b57afd4` | M015 전용 샘플 세트를 task-scoped tech 문서로 이동 |
| Stage 3 | `aa6f6c2` | 필수 샘플 native smoke/core-native compare 실행 |
| Stage 4 | `88078b4` | 통합 검증, 최종 보고서, 오늘할일 완료 처리 |
| PR 리뷰 반영 | 본 커밋 | Copilot 리뷰 지적에 따라 구현계획서 문서 범위와 최종 보고서 표준 컬럼 보정 |

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|----------|
| `mydocs/plans/task_m015_107.md` | Task #107 수행 계획서 |
| `mydocs/plans/task_m015_107_impl.md` | 단계별 구현 계획서 |
| `mydocs/working/task_m015_107_stage1.md` | Stage 1 조사 결과 |
| `mydocs/working/task_m015_107_stage2.md` | Stage 2 문서화 및 Stage 2.1 범위 보정 기록 |
| `mydocs/working/task_m015_107_stage3.md` | 필수 샘플 실행 결과와 summary 값 기록 |
| `mydocs/working/task_m015_107_stage4.md` | 최종 정합성 검증 기록 |
| `mydocs/report/task_m015_107_report.md` | 최종 보고서 |
| `mydocs/tech/task_m015_107_render_sample_set.md` | M015 Task #107 범위의 필수/후보 샘플 세트 |
| `mydocs/manual/render_core_native_compare_guide.md` | 작업별 샘플 세트 선정 원칙, summary 기록 항목, 산출물 보관 규칙 일반화 |
| `mydocs/manual/build_run_guide.md` | renderer 변경 시 task 범위 대표 샘플 smoke/diff 추가 수행 규칙 |
| `scripts/render-debug-compare.sh` | `--help`/`-h` 호출 exit code 0 보장 |
| `mydocs/orders/20260502.md` | #107 완료 상태 기록 |

## 검증 결과

| 명령 | 결과 |
|------|------|
| `./scripts/build-rust-macos.sh` | 성공. 분리 worktree에 필요한 `Frameworks/Rhwp.xcframework` 생성 |
| `./scripts/validate-stage3-render.sh --help` | 성공 |
| `./scripts/render-debug-compare.sh --help` | 성공. 보강 후 exit code 0 |
| `./scripts/validate-stage3-render.sh /private/tmp/rhwp-task107-smoke samples/basic/BookReview.hwp samples/복학원서.hwp` | 성공 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task107-bookreview samples/basic/BookReview.hwp` | 성공 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task107-bokhak samples/복학원서.hwp` | 성공 |
| `test -s /private/tmp/rhwp-task107-bookreview/BookReview-page1-summary.txt` | 성공 |
| `test -s /private/tmp/rhwp-task107-bokhak/복학원서-page1-summary.txt` | 성공 |
| `bash -n scripts/validate-stage3-render.sh scripts/render-debug-compare.sh` | 성공 |
| `./scripts/check-no-appkit.sh` | 성공 |
| `rg -n "M015|BookReview|복학원서|render-debug-compare|validate-stage3-render|NativeNonWhitePixels|산출물 보관" README.md mydocs scripts` | 성공 |
| `git diff --check` | 성공 |

### 필수 샘플 summary

| 샘플 | NativeNonWhitePixels | TextRuns | HangulRuns | HangulScalars | MissingHangulGlyphs | Diff |
|------|----------------------|----------|------------|---------------|----------------------|------|
| `samples/basic/BookReview.hwp` | 390859 | 66 | 28 | 209 | 0 | `qlmanage rasterize failed`로 미생성 |
| `samples/복학원서.hwp` | 154266 | 102 | 25 | 143 | 0 | `qlmanage rasterize failed`로 미생성 |

## 산출물 보관

생성된 PNG/SVG/JSON/summary 산출물은 `/private/tmp/rhwp-task107-*` 아래에 두었고 저장소에는 커밋하지 않았다. 장기 추적이 필요한 값은 Stage 3 보고서와 본 최종 보고서의 summary 표에 기록했다.

## 잔여 위험

- `qlmanage` sandbox 오류로 core raster PNG와 pixel diff PNG는 생성되지 않았다. 이번 기준에서 diff PNG는 선택 산출물이며, 필수 산출물인 render tree JSON, core SVG, native PNG, summary는 생성됐다.
- `samples/복학원서.hwp`는 layout overflow diagnostic이 남아 있다. core/native 책임 경계를 확인하는 샘플로 기록했으며, 단독 Swift renderer 회귀로 단정하지 않는다.
- 기능별 후보 샘플 전체 실행은 이번 task 범위에 포함하지 않았다. 이후 renderer 세부 작업에서 변경 범위에 맞는 후보 샘플을 선택해 실행한다.

## PR 전 상태

최종 보고서 검토 후 작업지시자 승인 시 `publish/task107` 원격 브랜치 push와 `devel` 대상 draft PR 생성을 진행한다.
