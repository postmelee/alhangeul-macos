# Issue #65 최종 결과 보고서

## 작업 요약

- GitHub Issue: [#65](https://github.com/postmelee/alhangeul-macos/issues/65)
- Milestone: v0.2.0
- 문서 prefix: `task_m020_65`
- 작업명: rhwp core 대비 native renderer 디버깅 도구와 문서 정리
- 작업 브랜치: `local/task65`
- 단계 수: 5단계

같은 HWP/HWPX 입력에서 rhwp core 기준 SVG, render tree JSON, macOS native renderer PNG, 선택적 core PNG와 pixel diff를 한 명령으로 생성하는 디버깅 절차를 추가했다. 제품 렌더링 경로는 바꾸지 않고, `rhwp_render_page_svg` 결과는 진단 기준 산출물로만 사용한다.

## 단계별 결과

| Stage | 결과 | 산출물 |
|-------|------|--------|
| Stage 1 | 현행 native/core 렌더 경로와 산출물 규격 확정 | `mydocs/working/task_m020_65_stage1.md` |
| Stage 2 | render tree JSON, core SVG, native PNG 필수 산출물 생성 helper 구현 | `scripts/render-debug-compare.sh`, `scripts/render_debug_compare.swift`, `RhwpDocument.renderPageTreeJSON(at:)` |
| Stage 3 | SVG rasterize와 pixel diff 선택 산출물 구현 | `core.png`, `diff.png`, diff summary 필드 |
| Stage 4 | 디버깅 절차와 판정 흐름 문서화 | `mydocs/troubleshootings/render_core_native_compare.md`, README, build/run guide |
| Stage 5 | 저장소 샘플과 수동 재현 샘플 통합 검증 | `mydocs/working/task_m020_65_stage5.md` |

## 변경 파일과 영향 범위

| 파일 | 영향 |
|------|------|
| `Sources/RhwpCoreBridge/RhwpDocument.swift` | render tree raw JSON 반환 API 추가 |
| `scripts/render-debug-compare.sh` | 비교 디버깅용 shell entrypoint 추가 |
| `scripts/render_debug_compare.swift` | render tree JSON, core SVG, native PNG, summary, optional diff 생성 helper 추가 |
| `README.md` | Render Smoke Test와 디버깅 프로토콜 진입점 보강 |
| `mydocs/manual/build_run_guide.md` | core/native 렌더 비교 디버깅 안내 추가 |
| `mydocs/troubleshootings/render_core_native_compare.md` | 상세 디버깅 절차와 산출물 해석 문서 추가 |
| `mydocs/orders/20260426.md` | #65 오늘할일 등록 및 완료 처리 |
| `mydocs/plans/task_m020_65.md` | 수행계획서 |
| `mydocs/plans/task_m020_65_impl.md` | 구현계획서 |
| `mydocs/working/task_m020_65_stage1.md` | Stage 1 완료 보고 |
| `mydocs/working/task_m020_65_stage2.md` | Stage 2 완료 보고 |
| `mydocs/working/task_m020_65_stage3.md` | Stage 3 완료 보고 |
| `mydocs/working/task_m020_65_stage4.md` | Stage 4 완료 보고 |
| `mydocs/working/task_m020_65_stage5.md` | Stage 5 완료 보고 |
| `mydocs/report/task_m020_65_report.md` | 최종 결과 보고 |

HostApp viewer UI, Quick Look/Thumbnail UI, Rust core source, `project.yml`, `AlhangeulMac.xcodeproj`, `rhwp-core.lock`은 변경하지 않았다.

## 변경 전·후 정량 비교

`origin/devel..local/task65` 기준:

```text
14 files changed, 2099 insertions(+), 3 deletions(-)
```

변경 유형:

- Swift bridge API 1개 추가
- 신규 디버깅 스크립트 2개 추가
- 사용자-facing 문서 3개 보강 또는 추가
- 수행계획서와 구현계획서 작성
- 단계 보고서 5개 작성
- 오늘할일 갱신

## 최종 산출물 규격

기본 명령:

```bash
./scripts/render-debug-compare.sh output/render-debug path/to/sample.hwp
```

필수 산출물:

- `{basename}-page{N}-render-tree.json`
- `{basename}-page{N}-core.svg`
- `{basename}-page{N}-native.png`
- `{basename}-page{N}-summary.txt`

선택 산출물:

- `{basename}-page{N}-core.png`
- `{basename}-page{N}-diff.png`

선택 산출물은 macOS `qlmanage` 기반 SVG rasterize가 가능한 환경에서 생성된다. 실패하더라도 필수 산출물 생성은 성공으로 유지하고 summary에 `DiffReason`을 남긴다.

## 검증 결과

실행한 검증:

```bash
bash -n scripts/render-debug-compare.sh
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh output/task65-stage5-smoke
./scripts/render-debug-compare.sh output/task65-stage5-debug samples/basic/KTX.hwp
./scripts/render-debug-compare.sh output/task65-stage5-table /Users/melee/Documents/samples/table-in-tbox.hwp
./scripts/render-debug-compare.sh output/task65-stage5-debug-escalated samples/basic/KTX.hwp
./scripts/render-debug-compare.sh output/task65-stage5-table-escalated /Users/melee/Documents/samples/table-in-tbox.hwp
git diff --check
```

결과:

- shell script 문법 검사 통과
- `Sources/RhwpCoreBridge` AppKit/UIKit 직접 의존 없음 확인
- 기존 `validate-stage3-render.sh` smoke 통과
- `samples/basic/KTX.hwp` 필수 산출물 4종 생성 확인
- `/Users/melee/Documents/samples/table-in-tbox.hwp` 필수 산출물 4종 생성 확인
- 일반 sandbox에서 `qlmanage` 실패 시 summary에 fallback 사유 기록 확인
- 권한 상승 환경에서 `core.png`와 `diff.png` 선택 산출물 생성 확인
- whitespace diff 검사 통과

## 주요 검증 수치

| 샘플 | 필수 산출물 | 선택 산출물 | 주요 수치 |
|------|------------|------------|----------|
| `samples/basic/KTX.hwp` | 생성 | 생성 가능 환경에서 생성 | `RenderTreeJSONBytes=982854`, `CoreSVGBytes=474840`, `NativePNGSize=1123x794`, `DiffDifferentPixelRatio=0.566555` |
| `/Users/melee/Documents/samples/table-in-tbox.hwp` | 생성 | 생성 가능 환경에서 생성 | `RenderTreeJSONBytes=826451`, `CoreSVGBytes=434334`, `NativePNGSize=794x1123`, `DiffDifferentPixelRatio=0.201483` |

## 수용 기준 충족 여부

| 기준 | 결과 |
|------|------|
| render tree JSON, core SVG, native PNG 필수 산출물을 한 명령으로 생성 | OK |
| pixel diff를 선택 산출물로 생성하고 실패 시 필수 산출물 성공 유지 | OK |
| 기존 `validate-stage3-render.sh` 기본 smoke 동작 유지 | OK |
| `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존 없음 | OK |
| core SVG가 제품 fallback이 아니라 진단 산출물임을 문서화 | OK |
| `table-in-tbox.hwp` 수동 재현 절차와 해석 기준 문서화 | OK |
| 한컴 viewer 자동 비교는 범위 밖임을 명확히 기록 | OK |

## 잔여 위험과 후속 작업

- `qlmanage` 기반 SVG rasterize는 macOS sandbox, OS 버전, Quick Look 캐시 상태에 따라 실패하거나 1px 내외 크기 차이를 만들 수 있다.
- pixel diff는 core SVG rasterize 결과와 native PNG의 정량 차이를 보여 주지만, 차이의 원인을 자동 분류하지는 않는다.
- render tree JSON은 문서가 커질수록 산출물 크기가 커질 수 있다.
- 이번 작업은 디버깅 기반 정리이며, 실제 native renderer 품질 개선은 후속 이슈에서 진행해야 한다.

## 커밋 목록

```text
87bcc9e Task #65: 수행 계획서 작성과 오늘할일 갱신
bb2c35e Task #65: 구현 계획서 작성
fe900df Task #65 Stage 1: 렌더 비교 산출물 규격 확정
b0df5af Task #65 Stage 2: core와 native 렌더 산출물 생성 스크립트 추가
10fd545 Task #65 Stage 3: 렌더 비교 diff 선택 산출물 추가
43c16af Task #65 Stage 4: core/native 렌더 비교 문서 작성
25994db Task #65 Stage 5: 렌더 비교 도구 통합 검증
```

## 승인 요청 사항

본 최종 결과 보고서 기준으로 `publish/task65` 원격 게시와 `devel` 대상 draft PR 리뷰 및 merge 승인을 요청한다.
