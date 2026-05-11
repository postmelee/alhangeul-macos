# Task M020 #221 구현 계획서

수행계획서: `mydocs/plans/task_m020_221.md`

## 작업 개요

- 이슈: #221 rhwp core SVG 기반 Quick Look PDF 생성 성능/안정성 spike
- 마일스톤: `v0.2`
- 브랜치: `local/task221`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac-task221`
- 목표: 현재 Swift native bitmap PDF 경로와 rhwp core SVG 기반 PDF 후보를 비교해 Quick Look PDF reply 유지, 성능, 안정성, thumbnail 영향 기준의 전환 판단 근거를 만든다.

## 구현 원칙

- 본 작업은 spike이며 제품 기본 렌더러를 즉시 교체하지 않는다.
- Quick Look의 우측 페이지 정보와 페이지 썸네일 UI를 유지하려면 최종 preview reply는 `.pdf`를 전제로 비교한다.
- WKWebView/WebView를 Quick Look extension 내부 PDF 생성 경로로 채택하지 않는다.
- 현재 제품 기준선은 `HwpPreviewPDFRenderer` + `HwpPageImageRenderer`의 native bitmap PDF 경로로 둔다.
- SVG 기준선은 기존 FFI 표면인 `RhwpDocument.renderPageSVG(at:)`와 hwpql의 `render_page_svg_native` 활용 구조를 참고한다.
- Thumbnail은 빠른 응답이 중요하므로 preview와 같은 경로로 묶지 않고 별도 fast path 유지 여부를 판단한다.
- 측정 산출물은 재현 가능한 명령, 샘플, wall-clock 시간, 출력 크기, 실패 양상을 함께 남긴다.

## Stage 1. 현행 경로와 비교 기준 확정

대상:

- `Sources/Shared/HwpPreviewPDFRenderer.swift`
- `Sources/Shared/HwpPageImageRenderer.swift`
- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `scripts/render-debug-compare.sh`
- `scripts/render_debug_compare.swift`
- hwpql 참고 파일

작업:

1. 현재 native bitmap PDF 생성 경로를 코드 기준으로 정리한다.
2. 현재 rhwp SVG 산출 경로와 hwpql의 HTML reply 구조를 비교한다.
3. Quick Look PDF UI를 유지하려면 HTML reply가 아니라 PDF reply가 필요하다는 비교 기준을 확정한다.
4. Stage 2 측정 helper에 필요한 입력, 출력, 샘플, metrics를 확정한다.
5. Stage 1 완료보고서를 작성한다.

산출물:

- `mydocs/working/task_m020_221_stage1.md`

검증:

```bash
test -f /private/tmp/hwpql/HWPPreviewer/PreviewProvider.swift
test -f /private/tmp/hwpql/rhwp-ffi/src/lib.rs
git diff --check -- mydocs/plans/task_m020_221_impl.md mydocs/working/task_m020_221_stage1.md
```

완료 조건:

- 현재 경로와 hwpql 경로의 차이가 명확히 문서화되어 있다.
- Stage 2에서 측정할 metrics와 샘플 기준이 정해져 있다.
- 제품 코드 변경 없이 완료된다.

커밋:

```text
Task #221 Stage 1: Quick Look SVG PDF 비교 기준 확정
```

## Stage 2. native bitmap PDF와 core SVG 생성 측정 helper 작성

대상:

- 신규 후보: `scripts/quicklook_pdf_renderer_compare.swift`
- 신규 후보: `scripts/compare-quicklook-pdf-renderers.sh`

작업:

1. 입력 문서의 page count, page size, file size를 기록한다.
2. 현재 native bitmap PDF 경로의 inspect 시간, render 시간, PDF bytes, page count를 측정한다.
3. rhwp core SVG 경로의 open 시간, page별 SVG 생성 시간, 전체 SVG bytes를 측정한다.
4. 단일 페이지와 다중 페이지를 같은 helper에서 처리한다.
5. summary JSON 또는 text를 생성해 반복 비교가 가능하게 한다.
6. Stage 2 완료보고서를 작성한다.

산출물:

- `scripts/quicklook_pdf_renderer_compare.swift`
- `scripts/compare-quicklook-pdf-renderers.sh`
- `mydocs/working/task_m020_221_stage2.md`

검증:

```bash
bash -n scripts/compare-quicklook-pdf-renderers.sh
./scripts/compare-quicklook-pdf-renderers.sh output/task221-stage2 /Users/melee/Desktop/files/group-drawing-02.hwp /Users/melee/Desktop/files/footnote-01.hwp
test -s output/task221-stage2/summary.txt
git diff --check -- scripts/quicklook_pdf_renderer_compare.swift scripts/compare-quicklook-pdf-renderers.sh mydocs/working/task_m020_221_stage2.md
```

완료 조건:

- native bitmap PDF와 core SVG 생성 시간이 한 명령으로 측정된다.
- 출력 크기와 page count가 기록된다.
- 실패 시 어떤 경로가 실패했는지 구분된다.

커밋:

```text
Task #221 Stage 2: Quick Look PDF 렌더 경로 측정 helper 추가
```

## Stage 3. SVG 기반 PDF 후보 가능성 검증

대상:

- `scripts/quicklook_pdf_renderer_compare.swift`
- `scripts/compare-quicklook-pdf-renderers.sh`
- 필요 시 별도 spike helper

작업:

1. macOS 기본 환경에서 SVG를 PDF page로 넣을 수 있는 후보를 조사한다.
2. Swift/Quartz/CoreGraphics만으로 가능한지, 추가 라이브러리나 Rust FFI가 필요한지 나눈다.
3. 가능한 최소 후보가 있으면 샘플 1~2개로 PDF bytes를 생성해 page count와 크기를 확인한다.
4. 후보가 제품에 부적합하면 부적합 근거를 명확히 남긴다.
5. Stage 3 완료보고서를 작성한다.

산출물:

- `mydocs/working/task_m020_221_stage3.md`
- 필요 시 spike helper 파일

검증:

```bash
git diff --check -- mydocs/working/task_m020_221_stage3.md scripts
```

완료 조건:

- SVG -> PDF를 Swift extension 안에서 직접 처리할 수 있는지 판단 근거가 있다.
- Rust FFI에서 PDF bytes를 직접 생성하는 후보의 필요 여부가 정리되어 있다.
- WebView 후보를 제외하는 성능/안정성 근거가 문서화되어 있다.

커밋:

```text
Task #221 Stage 3: SVG 기반 PDF 후보 가능성 검증
```

## Stage 4. 대표 샘플 성능과 안정성 비교

대상:

- Stage 2/3 helper
- 저장소 sample 또는 Desktop sample

작업:

1. 단일 페이지 샘플과 다중 페이지 샘플을 최소 2개 이상 선정한다.
2. native bitmap PDF, core SVG, 가능하면 SVG PDF 후보를 반복 측정한다.
3. 생성 시간, 출력 크기, page count, 실패 양상, visual risk를 표로 정리한다.
4. Thumbnail에는 어떤 경로가 적합한지 별도로 판단한다.
5. Stage 4 완료보고서를 작성한다.

산출물:

- `mydocs/working/task_m020_221_stage4.md`
- 필요 시 `output/task221-*` ignored 측정 산출물

검증:

```bash
./scripts/compare-quicklook-pdf-renderers.sh output/task221-stage4 /Users/melee/Desktop/files/group-drawing-02.hwp /Users/melee/Desktop/files/footnote-01.hwp
git diff --check -- mydocs/working/task_m020_221_stage4.md
```

완료 조건:

- 전환 판단에 필요한 성능/안정성 표가 있다.
- Quick Look preview와 Thumbnail을 같은 결론으로 묶지 않는다.
- PDF reply 유지 가능성 판단이 포함된다.

커밋:

```text
Task #221 Stage 4: SVG PDF 후보 성능과 안정성 비교
```

## Stage 5. 판단 문서와 후속 범위 정리

대상:

- 신규 후보: `mydocs/troubleshootings/quicklook_svg_pdf_spike.md`
- `mydocs/plans/task_m020_221_impl.md`
- 최종 결과보고서

작업:

1. 현재 native bitmap PDF 유지, SVG 기반 PDF 전환, Rust FFI PDF 직접 생성 중 권장안을 정리한다.
2. 실제 전환이 필요하면 후속 구현 이슈 범위를 제안한다.
3. 전환하지 않는다면 보류 이유와 재검토 조건을 남긴다.
4. 최종 보고서를 작성한다.

산출물:

- `mydocs/troubleshootings/quicklook_svg_pdf_spike.md`
- `mydocs/report/task_m020_221_report.md`

검증:

```bash
git diff --check
```

완료 조건:

- 작업지시자가 Quick Look/Thumbnail 렌더링 경로 전환 여부를 판단할 수 있는 결론이 있다.
- 후속 이슈가 필요하면 범위와 선행 조건이 명확하다.

커밋:

```text
Task #221 Stage 5 + 최종 보고서: SVG PDF spike 결과 정리
```
