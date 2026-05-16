# Task M020 #221 최종 결과보고서

## 작업 요약

- 이슈: #221 rhwp core SVG 기반 Quick Look PDF 생성 성능/안정성 spike
- 마일스톤: M020 / v0.2
- 브랜치: `local/task221`
- 단계 수: 6단계
- 결론: Quick Look preview를 지금 즉시 core SVG PDF 경로로 전환하지 않고, 단기에는 현재 Swift native bitmap PDF/PNG fast path를 유지한다. 다만 host app과 Quick Look의 장기 시각 일치성을 위해 core SVG/WebKit 기준 visual regression과 renderer parity follow-up을 이어간다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
| --- | --- |
| `RustBridge/examples/svg_pdf_benchmark.rs` | `rhwp` core SVG 생성 후 `svg2pdf` 기반 PDF bytes 생성 시간을 반복 측정하는 Rust example helper 추가 |
| `scripts/compare-quicklook-pdf-renderers.sh` | 현재 native bitmap PDF 경로와 core SVG 생성 시간을 한 번에 측정하는 wrapper 추가 |
| `scripts/quicklook_pdf_renderer_compare.swift` | Quick Look preview와 같은 shared renderer 경로를 사용해 page count, page size, PDF bytes, 렌더 시간을 기록하는 Swift helper 추가 |
| `scripts/benchmark-quicklook-svg-pdf.sh` | Rust SVG PDF benchmark example 실행 wrapper 추가 |
| `scripts/visual-compare-quicklook-renderers.sh` | native bitmap renderer와 core SVG PDF 후보를 PNG 기준으로 비교하는 wrapper 추가 |
| `scripts/visual_compare_quicklook_renderers.swift` | PDF page rasterize, PNG 정규화, pixel diff, summary 작성 helper 추가 |
| `scripts/visual-compare-core-svg-webkit.sh` | native bitmap renderer와 core SVG WebKit snapshot을 비교하는 wrapper 추가 |
| `scripts/visual_compare_core_svg_webkit.swift` | WKWebView snapshot 기반 core SVG golden PNG 생성과 pixel diff helper 추가 |
| `scripts/ci/classify-pr-changes.sh` | PR CI follow-up: `RustBridge/examples/*` 변경이 제품 staticlib lock byte 검증을 불필요하게 트리거하지 않도록 분류 보정 |
| `mydocs/plans/task_m020_221.md` | SVG PDF spike 수행계획서 작성 |
| `mydocs/plans/task_m020_221_impl.md` | 단계별 구현 계획과 검증 기준 작성 |
| `mydocs/working/task_m020_221_stage1.md` | 현행 native bitmap PDF 경로, hwpql SVG/HTML 경로, PDF reply 유지 기준 정리 |
| `mydocs/working/task_m020_221_stage2.md` | native PDF와 core SVG 생성 측정 helper 결과 정리 |
| `mydocs/working/task_m020_221_stage3.md` | SVG 기반 PDF 후보 가능성과 Swift/WebView/Rust FFI 선택지 검토 |
| `mydocs/working/task_m020_221_stage4.md` | 대표 샘플 성능/안정성 반복 측정 결과 정리 |
| `mydocs/working/task_m020_221_stage5.md` | native bitmap renderer와 core SVG PDF 후보의 시각 비교 결과 정리 |
| `mydocs/working/task_m020_221_stage6.md` | native bitmap renderer와 core SVG WebKit 기준 golden 비교 결과 정리 |
| `mydocs/orders/20260511.md` | #221 오늘할일 상태를 완료로 갱신 |

## 변경 전·후 정량 비교

| 항목 | 결과 |
| --- | --- |
| 커밋 수 | `origin/devel-webview` 대비 8개 stage/계획 커밋 |
| 변경 규모 | 17개 파일, 2,666 insertions |
| 성능 샘플 수 | 4개 문서, native/core SVG/SVG PDF 반복 측정 |
| SVG PDF 성공률 | 4개 샘플 x 3회, PDF 생성과 page count 검증 모두 성공 |
| Stage 4 성능 결론 | `group-drawing-02.hwp`는 SVG PDF가 빠름. `eq-01.hwp`, `footnote-01.hwp`, `hwp-img-001.hwp`는 native bitmap PDF가 더 빠름 |
| Stage 5 SVG PDF 후보 diff | page 1 기준 4.2595%~8.1387%, `footnote-01.hwp` page 6은 0.0085% |
| Stage 6 core SVG WebKit golden diff | page 1 기준 4.3279%~6.7736%, `footnote-01.hwp` page 6은 0.0073% |
| PR CI follow-up | `RustBridge/examples/svg_pdf_benchmark.rs` 추가가 `run_rust_verify=true`를 트리거해 `librhwp.a` byte hash mismatch가 발생한 것을 분류 규칙 보정으로 해결 |

## 검증 결과

| 수용 기준 | 결과 |
| --- | --- |
| 현재 native bitmap PDF와 core SVG 생성 시간이 한 명령으로 측정된다 | OK |
| SVG 기반 PDF 후보가 page count와 파일 크기를 기록한다 | OK |
| Quick Look preview와 Thumbnail 결론을 분리한다 | OK |
| WebView/WKWebView를 Quick Look extension 내부 PDF 생성 후보로 채택하지 않는다 | OK |
| native renderer와 core SVG WebKit 기준 시각 비교가 별도 helper로 재현 가능하다 | OK |
| `git diff --check` | OK |
| 신규 shell script syntax 검사 | OK |
| `scripts/ci/classify-pr-changes.sh origin/devel-webview HEAD` | OK, `run_macos_build=true`, `run_rust_verify=false` |
| 단계별 완료보고서 6개 존재 확인 | OK |

## 최종 판단

`rhwp` core SVG 생성 자체는 매우 빠르다. 병목은 SVG 생성이 아니라 SVG를 PDF로 변환하는 단계다. SVG PDF 후보는 기능적으로 가능하고 모든 대표 샘플에서 PDF 생성과 page count 검증을 통과했지만, 문서 유형별 성능 편차가 컸다.

현재 native bitmap renderer는 core SVG WebKit 기준과 pixel-level로 동일하지는 않지만, 구조적 배치와 주요 객체 표시에서는 상당히 따라잡은 상태다. 차이는 주로 WebKit/CoreGraphics text antialias, font weight/glyph metric, 수식 edge, 이미지 interpolation edge에 집중된다.

따라서 단기 v0.1.x 재배포 범위에서는 Quick Look extension 등록/업데이트 문제와 현재 native fast path 안정화를 우선하고, SVG PDF 전환은 v0.2 이후 후속 검증과 함께 진행하는 것이 맞다.

## 잔여 위험과 후속 작업

- #222: `rhwp v0.7.11` 기준 Swift native renderer parity gap 정리와 따라잡기
- #121: RawSvg/OLE·차트 리소스 렌더링 보강
- #122: 이미지 fill mode·타일·배치 렌더링 parity 보강
- #110: Placeholder/FormObject 정적 프리뷰 보강
- core SVG PDF 전환을 재검토하려면 실제 Quick Look UI screenshot 기준 visual regression과 더 많은 문서 샘플이 필요하다.
- Thumbnail은 preview PDF 전환과 묶지 않고 별도 fast path 유지 또는 전용 raster 후보를 검토해야 한다.

## 작업지시자 승인 요청

본 보고서와 PR 게시 후 리뷰 및 merge 승인 여부를 확인한다. Merge 후에는 #221 close와 `publish/task221`, `local/task221` 부산물 정리를 별도 cleanup 절차로 진행한다.
