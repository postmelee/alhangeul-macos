# Task M015 #107 구현 계획서

수행계획서: `mydocs/plans/task_m015_107.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #107 Swift 렌더 보강 샘플 smoke/diff 검증 세트 정리
- 마일스톤: M015 (`첫 출시 전 Swift 렌더 보강`)
- 브랜치: `local/task107`
- 작업 위치: `/private/tmp/rhwp-mac-task107`
- 주 대상: render smoke/diff 문서와 검증 스크립트 안내
- 필수 샘플: `samples/basic/BookReview.hwp`, `samples/복학원서.hwp`
- 목표: M015 renderer 보강 작업에서 공통으로 재현 가능한 샘플 smoke/diff 실행 기준, summary 기록 기준, 산출물 보관 규칙을 정리한다.

## 구현 원칙

- 새 렌더 엔진, PageLayerTree 전환, CI full diff 정책은 도입하지 않는다.
- 기존 `validate-stage3-render.sh`는 빠른 native smoke test, `render-debug-compare.sh`는 core SVG/native PNG 비교 진단 도구로 역할을 유지한다.
- PNG/SVG 같은 생성 산출물은 저장소에 커밋하지 않고, 단계 보고서와 최종 보고서에 출력 경로와 핵심 summary 값을 기록한다.
- `qlmanage` 기반 core raster PNG/diff PNG는 선택 산출물로 유지하고, 실패 시 필수 산출물 생성 실패로 취급하지 않는다.
- 샘플 세트는 `samples/` 저장소 경로를 우선 사용하고, 외부 개인 경로 샘플은 필수 기준으로 삼지 않는다.
- 문서 변경은 기존 manual/README의 역할을 유지하면서 중복을 줄이고, 상세 기준은 `render_core_native_compare_guide.md`에 모은다.
- 코드 변경이 있더라도 shell help와 검증 편의성 보강에 한정하며 Swift/Rust renderer 구현은 변경하지 않는다.

## Stage 1. 현행 도구와 샘플 사용 이력 조사

### 목표

- 현재 smoke/diff 도구가 생성하는 산출물과 보고서에 기록해야 할 값을 확정한다.
- M015 관련 작업에서 반복 사용된 샘플과 기능 범주별 후보 샘플을 정리한다.

### 작업

- `validate-stage3-render.sh`, `render-debug-compare.sh`, 관련 Swift helper의 출력 항목을 확인한다.
- 기존 manual, README, 단계 보고서에서 `BookReview.hwp`, `복학원서.hwp`, 이미지/도형/스타일/폼 샘플 사용 이력을 조사한다.
- 저장소 `samples/` 목록에서 기능 범주별 대표 후보를 분류한다.
- 필수 샘플과 후보 샘플을 분리하고, 후보가 실제 M015 세부 이슈의 직접 검증 대상인지 표시한다.
- Stage 1 보고서에 조사 결과와 이후 문서 보강 범위를 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m015_107_stage1.md`

### 검증

```bash
git status --short --branch
rg -n "BookReview|복학원서|render-debug-compare|validate-stage3-render|NativeNonWhitePixels|TextRuns|HangulRuns|MissingHangulGlyphs" README.md mydocs scripts
rg --files samples
test -f samples/basic/BookReview.hwp
test -f samples/복학원서.hwp
git diff --check -- mydocs/working/task_m015_107_stage1.md
```

### 완료 기준

- 필수 샘플 2개와 기능 범주별 후보 샘플 목록이 보고서에 정리된다.
- `render-debug-compare.sh` summary에서 기록해야 할 핵심 값이 확정된다.
- 다음 단계에서 수정할 문서와 스크립트 범위가 확정된다.

### 커밋 메시지

```text
Task #107 Stage 1: 렌더 smoke 샘플 기준 조사
```

## Stage 2. 필수 smoke 세트와 산출물 기록 기준 문서화

### 목표

- M015 필수 smoke 샘플과 기능별 대표 샘플 세트를 manual에 명시한다.
- 단계 보고서에 남길 core/native 비교 산출물 기록 기준을 정리한다.

### 작업

- `render_core_native_compare_guide.md`에 M015 샘플 smoke/diff 세트 섹션을 추가한다.
- `BookReview.hwp`, `복학원서.hwp`를 필수 smoke 대상으로 명시하고 각각 확인해야 할 대표 렌더 계층을 설명한다.
- 도형 children, 이미지 effect/crop, placeholder/form, 스타일 보강별 대표 후보 샘플 표를 추가한다.
- summary 필수 기록 항목을 `NativeNonWhitePixels`, `TextRuns`, `HangulRuns`, `MissingHangulGlyphs`, `CoreSVGBytes`, `Diff` 상태 중심으로 정리한다.
- 산출물 보관 규칙을 로컬 출력 경로, 보고서 메타데이터, PR 첨부 여부 기준으로 정리한다.
- `build_run_guide.md`의 렌더링 smoke test 섹션에서 M015 필수 샘플 검증으로 넘어가는 경로를 연결한다.
- Stage 2 보고서에 변경된 문서 위치와 문서화된 기준을 요약한다.

### 예상 변경 파일

- `mydocs/manual/render_core_native_compare_guide.md`
- `mydocs/manual/build_run_guide.md`
- `mydocs/working/task_m015_107_stage2.md`

### 검증

```bash
git status --short --branch
rg -n "M015|BookReview|복학원서|NativeNonWhitePixels|CoreSVGBytes|DiffReason|산출물 보관" mydocs/manual/render_core_native_compare_guide.md mydocs/manual/build_run_guide.md
git diff --check -- mydocs/manual/render_core_native_compare_guide.md mydocs/manual/build_run_guide.md mydocs/working/task_m015_107_stage2.md
```

### 완료 기준

- M015 필수 smoke 샘플 2개가 manual에서 명확히 검색된다.
- 기능 범주별 대표 샘플 후보와 제외 기준이 문서화된다.
- 생성 산출물은 커밋하지 않고 summary 핵심값을 보고서에 남기는 규칙이 문서화된다.

### 커밋 메시지

```text
Task #107 Stage 2: M015 렌더 검증 세트 문서화
```

## Stage 3. smoke/diff 실행 안내와 필수 샘플 검증

### 목표

- 문서화한 필수 샘플 기준이 실제 명령으로 재현되는지 확인한다.
- 필요하면 shell script help 또는 README의 진입 안내를 보강한다.

### 작업

- `validate-stage3-render.sh --help`와 `render-debug-compare.sh --help`가 manual의 기본 설명과 충돌하지 않는지 확인한다.
- 필요 시 `validate-stage3-render.sh` help에 기본 smoke와 M015 필수 smoke의 차이를 짧게 보강한다.
- 필요 시 `README.md` 디버깅 프로토콜에서 M015 샘플 세트 manual로 연결한다.
- `BookReview.hwp`, `복학원서.hwp`에 대해 native smoke와 core/native debug compare를 실행한다.
- summary 값을 보고서 표로 기록하고, `qlmanage` diff 실패 여부를 선택 산출물 상태로 분리해 기록한다.
- Stage 3 보고서에 실제 출력 경로와 핵심 값을 남긴다.

### 예상 변경 파일

- 필요 시 `scripts/validate-stage3-render.sh`
- 필요 시 `README.md`
- `mydocs/working/task_m015_107_stage3.md`

### 검증

```bash
git status --short --branch
./scripts/validate-stage3-render.sh --help
./scripts/render-debug-compare.sh --help
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task107-smoke samples/basic/BookReview.hwp samples/복학원서.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task107-bookreview samples/basic/BookReview.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task107-bokhak samples/복학원서.hwp
test -s /private/tmp/rhwp-task107-bookreview/BookReview-page1-summary.txt
test -s /private/tmp/rhwp-task107-bokhak/복학원서-page1-summary.txt
sed -n '1,140p' /private/tmp/rhwp-task107-bookreview/BookReview-page1-summary.txt
sed -n '1,140p' /private/tmp/rhwp-task107-bokhak/복학원서-page1-summary.txt
bash -n scripts/validate-stage3-render.sh scripts/render-debug-compare.sh
git diff --check
```

### 완료 기준

- 필수 샘플 2개에서 native smoke와 core/native debug 산출물이 재현된다.
- 보고서에 각 샘플의 핵심 summary 값과 산출물 경로가 기록된다.
- script help 또는 README를 보강한 경우 manual과 설명이 일치한다.

### 커밋 메시지

```text
Task #107 Stage 3: 필수 렌더 smoke 세트 검증
```

## Stage 4. 통합 검증과 최종 보고

### 목표

- 문서와 스크립트 변경의 일관성을 확인하고 최종 보고서를 작성한다.
- 오늘할일을 완료 상태로 갱신하고 PR 전 상태를 만든다.

### 작업

- 관련 문서에서 M015 필수 smoke, core/native 비교, 산출물 보관 규칙이 일관되게 검색되는지 확인한다.
- shell script syntax와 `Sources/RhwpCoreBridge` 경계 검증을 실행한다.
- Stage 1-3 결과, 변경 파일, 검증 명령, 잔여 리스크를 최종 보고서에 정리한다.
- `mydocs/orders/20260502.md`의 #107 행을 완료 상태로 갱신한다.

### 예상 변경 파일

- `mydocs/working/task_m015_107_stage4.md`
- `mydocs/report/task_m015_107_report.md`
- `mydocs/orders/20260502.md`

### 검증

```bash
git status --short --branch
rg -n "M015|BookReview|복학원서|render-debug-compare|validate-stage3-render|NativeNonWhitePixels|산출물 보관" README.md mydocs scripts
bash -n scripts/validate-stage3-render.sh scripts/render-debug-compare.sh
./scripts/check-no-appkit.sh
git diff --check
```

### 완료 기준

- 최종 보고서에 필수 샘플 세트, 기능별 후보 샘플, 검증 결과, 산출물 보관 규칙이 정리된다.
- 오늘할일 #107 행이 완료 상태로 갱신된다.
- PR 작성 전 미커밋 변경이 없는 상태로 정리할 수 있다.

### 커밋 메시지

```text
Task #107 Stage 4 + 최종 보고서: 렌더 smoke 검증 세트 정리
```

## 승인 요청 사항

1. 위 4단계 구현계획으로 Stage 1 현행 도구와 샘플 사용 이력 조사에 착수해도 되는지 승인 요청한다.
2. Stage 1은 source/script/manual 변경 없이 조사와 단계 보고서 작성으로 진행한다.
3. Stage 2부터 manual 변경이 포함되고, Stage 3에서 필요하다고 확인될 때만 script help 또는 README를 보강한다.
