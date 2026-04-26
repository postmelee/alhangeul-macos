# Task M020 #65 구현 계획서

수행계획서: `mydocs/plans/task_m020_65.md`

## 작업 개요

- 이슈: #65 rhwp core 대비 native renderer 디버깅 도구와 문서 정리
- 마일스톤: `v0.2.0`
- 브랜치: `local/task65`
- 작업 위치: `/private/tmp/rhwp-mac-task65`
- 목표: 같은 HWP/HWPX 입력에서 rhwp core SVG, render tree JSON, native renderer PNG, 선택적 rasterize/diff 산출물을 생성하는 표준 디버깅 절차를 만든다.

## 구현 원칙

- 제품 렌더링 경로는 바꾸지 않는다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 추가하지 않는다.
- core 기준 산출물은 `rhwp_render_page_svg`가 반환하는 `render_page_svg_native` SVG로 둔다.
- native 기준 산출물은 현재 HostApp/Quick Look/Thumbnail이 공유하는 `RenderNode` + `CGTreeRenderer` 경로로 그린 PNG로 둔다.
- SVG fallback을 제품 표시 경로로 도입하지 않는다. SVG는 진단 산출물로만 사용한다.
- 외부 도구 의존이 필요한 SVG rasterize와 pixel diff는 실패하더라도 필수 산출물 생성을 막지 않는 선택 단계로 둔다.
- `/Users/melee/Documents/samples/table-in-tbox.hwp`는 수동 재현 샘플로 사용하지만 저장소 fixture로 복사하지 않는다.

## Stage 1. 현행 렌더 경로와 산출물 규격 확정

대상:

- `scripts/validate-stage3-render.sh`
- `scripts/stage3_render_check.swift`
- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `Sources/RhwpCoreBridge/RenderTree.swift`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 관련 문서의 디버깅 프로토콜

작업:

1. 현재 native smoke renderer가 생성하는 PNG 이름, page index, scale, text stats를 확인한다.
2. `RhwpDocument.renderPageSVG(at:)`가 core SVG를 정상 추출할 수 있음을 `table-in-tbox.hwp` 수동 실험 결과와 함께 정리한다.
3. render tree raw JSON을 산출하기 위해 `RhwpDocument`에 원문 JSON 반환 API가 필요한지 확인한다.
4. 표준 산출물 이름을 확정한다.
   - `{basename}-page{N}-native.png`
   - `{basename}-page{N}-render-tree.json`
   - `{basename}-page{N}-core.svg`
   - `{basename}-page{N}-core.png` 또는 `{basename}-page{N}-core.svg.png`
   - `{basename}-page{N}-diff.png`
   - `{basename}-page{N}-summary.txt`
5. Stage 1 완료보고서를 작성한다.

산출물:

- `mydocs/working/task_m020_65_stage1.md`

검증:

```bash
./scripts/validate-stage3-render.sh output/task65-stage1 /Users/melee/Documents/samples/table-in-tbox.hwp
git diff --check -- mydocs/working/task_m020_65_stage1.md
```

완료 조건:

- 비교 기준 산출물과 선택 산출물이 구분되어 있다.
- render tree JSON dump를 위한 코드 변경 범위가 확정되어 있다.
- `table-in-tbox.hwp` 수동 재현 결과가 단계 보고서에 기록되어 있다.

커밋:

```text
Task #65 Stage 1: 렌더 비교 산출물 규격 확정
```

## Stage 2. core/native 산출물 생성 helper 구현

대상:

- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- 신규 후보: `scripts/render_debug_compare.swift`
- 신규 후보: `scripts/render-debug-compare.sh`

작업:

1. `RhwpDocument`에 render tree raw JSON을 반환하는 좁은 API를 추가한다.
2. 새 Swift helper가 입력 파일과 page index를 받아 다음 산출물을 생성하도록 구현한다.
   - render tree JSON
   - core SVG
   - native PNG
   - summary text
3. helper 내부 native PNG 렌더링은 `stage3_render_check.swift`와 같은 CoreGraphics/CoreText 경로를 사용한다.
4. shell wrapper는 `Frameworks/universal/librhwp.a`와 `Frameworks/modulemap` 존재를 확인한 뒤 helper를 빌드하고 실행한다.
5. 기본 호출 예시는 다음으로 둔다.

```bash
./scripts/render-debug-compare.sh output/render-debug /Users/melee/Documents/samples/table-in-tbox.hwp
```

6. Stage 2 완료보고서를 작성한다.

산출물:

- `Sources/RhwpCoreBridge/RhwpDocument.swift`
- `scripts/render_debug_compare.swift`
- `scripts/render-debug-compare.sh`
- `mydocs/working/task_m020_65_stage2.md`

검증:

```bash
bash -n scripts/render-debug-compare.sh
./scripts/render-debug-compare.sh output/task65-stage2 /Users/melee/Documents/samples/table-in-tbox.hwp
test -s output/task65-stage2/table-in-tbox-page1-render-tree.json
test -s output/task65-stage2/table-in-tbox-page1-core.svg
test -s output/task65-stage2/table-in-tbox-page1-native.png
test -s output/task65-stage2/table-in-tbox-page1-summary.txt
git diff --check -- Sources/RhwpCoreBridge/RhwpDocument.swift scripts/render_debug_compare.swift scripts/render-debug-compare.sh mydocs/working/task_m020_65_stage2.md
```

완료 조건:

- 필수 산출물 4종이 한 명령으로 생성된다.
- 기존 `validate-stage3-render.sh` 경로를 깨지 않는다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존이 없다.

커밋:

```text
Task #65 Stage 2: core와 native 렌더 산출물 생성 스크립트 추가
```

## Stage 3. SVG rasterize와 pixel diff 선택 산출물 구현

대상:

- `scripts/render-debug-compare.sh`
- `scripts/render_debug_compare.swift`

작업:

1. 로컬에서 사용 가능한 SVG rasterizer 후보를 확인한다.
   - `qlmanage`
   - `rsvg-convert`
   - `magick`
2. 기본은 macOS 기본 `qlmanage -t -x`를 사용하되, 실패 시 core SVG 원본 생성 성공 상태를 유지한다.
3. core PNG가 생성되면 native PNG와 크기 차이를 정규화해 pixel diff를 생성한다.
4. diff summary에는 비교 크기, 다른 픽셀 수, 비율, max channel delta를 기록한다.
5. 1px 내외 크기 차이가 발생할 수 있음을 summary에 명시한다.
6. Stage 3 완료보고서를 작성한다.

산출물:

- `scripts/render-debug-compare.sh`
- `scripts/render_debug_compare.swift`
- `mydocs/working/task_m020_65_stage3.md`

검증:

```bash
bash -n scripts/render-debug-compare.sh
./scripts/render-debug-compare.sh output/task65-stage3 /Users/melee/Documents/samples/table-in-tbox.hwp
test -s output/task65-stage3/table-in-tbox-page1-core.svg
test -s output/task65-stage3/table-in-tbox-page1-native.png
test -s output/task65-stage3/table-in-tbox-page1-summary.txt
git diff --check -- scripts/render-debug-compare.sh scripts/render_debug_compare.swift mydocs/working/task_m020_65_stage3.md
```

완료 조건:

- SVG rasterize 가능 환경에서는 core PNG가 생성된다.
- core PNG가 있으면 diff PNG와 diff summary가 생성된다.
- rasterize 실패가 필수 산출물 생성을 실패 처리하지 않는다.

커밋:

```text
Task #65 Stage 3: 렌더 비교 diff 선택 산출물 추가
```

## Stage 4. 디버깅 문서 작성

대상:

- 신규 후보: `mydocs/troubleshootings/render_core_native_compare.md`
- 필요 시 `README.md`의 디버깅 프로토콜 짧은 링크
- 필요 시 `mydocs/manual/build_run_guide.md`의 검증 절차 링크

작업:

1. 디버깅 절차의 목적과 기준을 문서화한다.
2. 산출물 파일명과 해석 방법을 표로 정리한다.
3. 다음 판정 흐름을 문서화한다.
   - core SVG와 native PNG가 모두 다르면 core 구현 한계 또는 입력 처리 문제 후보
   - core SVG는 맞고 native PNG가 다르면 Swift decoder/renderer 문제 후보
   - render tree JSON에 필요한 정보가 없으면 core render tree export 문제 후보
   - 디버그 산출물은 맞고 HostApp만 다르면 HostApp 표시/scale/clipping 문제 후보
4. `table-in-tbox.hwp` 재현 방법과 수동 비교 방법을 기록한다.
5. Stage 4 완료보고서를 작성한다.

산출물:

- `mydocs/troubleshootings/render_core_native_compare.md`
- 필요 시 `README.md`
- 필요 시 `mydocs/manual/build_run_guide.md`
- `mydocs/working/task_m020_65_stage4.md`

검증:

```bash
rg -n "render-debug-compare|render tree JSON|core SVG|native PNG|pixel diff|table-in-tbox" \
  README.md mydocs/manual/build_run_guide.md mydocs/troubleshootings/render_core_native_compare.md
git diff --check -- README.md mydocs/manual/build_run_guide.md mydocs/troubleshootings/render_core_native_compare.md mydocs/working/task_m020_65_stage4.md
```

완료 조건:

- 새 디버깅 절차를 문서만 보고 재현할 수 있다.
- SVG가 제품 fallback이 아니라 진단 산출물임이 명확하다.
- 한컴 viewer 비교는 이번 자동화 범위 밖임이 명확하다.

커밋:

```text
Task #65 Stage 4: core/native 렌더 비교 문서 작성
```

## Stage 5. 통합 검증과 회귀 확인

대상:

- 전체 변경 파일
- `samples/basic/KTX.hwp`
- `/Users/melee/Documents/samples/table-in-tbox.hwp`

작업:

1. shell script syntax를 확인한다.
2. `check-no-appkit.sh`로 bridge 경계 규칙을 확인한다.
3. 기존 `validate-stage3-render.sh` smoke test를 실행한다.
4. 새 `render-debug-compare.sh`를 저장소 샘플과 `table-in-tbox.hwp`에 대해 실행한다.
5. 생성 산출물 목록과 summary를 단계 보고서에 기록한다.
6. Stage 5 완료보고서를 작성한다.

산출물:

- `mydocs/working/task_m020_65_stage5.md`

검증:

```bash
bash -n scripts/render-debug-compare.sh
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh output/task65-stage5-smoke
./scripts/render-debug-compare.sh output/task65-stage5-debug samples/basic/KTX.hwp
./scripts/render-debug-compare.sh output/task65-stage5-table /Users/melee/Documents/samples/table-in-tbox.hwp
git diff --check
```

완료 조건:

- 기존 render smoke가 통과한다.
- 새 디버깅 스크립트가 저장소 샘플과 수동 재현 샘플에서 필수 산출물을 만든다.
- 선택 산출물이 생성되지 못한 환경이면 이유와 fallback이 보고서에 남아 있다.

커밋:

```text
Task #65 Stage 5: 렌더 비교 도구 통합 검증
```

## 전체 검증 기준

- `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존이 없어야 한다.
- `validate-stage3-render.sh`의 기존 사용법과 기본 샘플 smoke test가 유지되어야 한다.
- 새 스크립트는 `Frameworks/universal/librhwp.a`와 `Frameworks/modulemap` 누락 시 기존 스크립트처럼 명확한 오류를 출력해야 한다.
- 필수 산출물은 외부 rasterizer 없이도 생성되어야 한다.
- 선택 산출물 실패가 native/core 필수 산출물 생성 실패로 이어지지 않아야 한다.
- 모든 신규 문서는 한국어로 작성되어야 한다.

## 승인 요청

이 구현계획서 승인 후 Stage 1 현행 렌더 경로와 산출물 규격 확정부터 진행한다.
