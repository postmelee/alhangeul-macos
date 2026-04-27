# Task M020 #65 Stage 5 완료보고서

## 단계 목표

Stage 2~4에서 추가한 core/native 렌더 비교 도구와 문서가 최신 `devel` 반영 후에도 기존 smoke 경로와 함께 동작하는지 통합 검증한다.

## 검증 환경

- 작업 브랜치: `local/task65`
- 기준 브랜치: `origin/devel`
- 저장소 샘플: `samples/basic/KTX.hwp`
- 수동 재현 샘플: `/Users/melee/Documents/samples/table-in-tbox.hwp`

## 실행 결과

### 1. shell script 문법 확인

```bash
bash -n scripts/render-debug-compare.sh
```

결과: 통과.

### 2. shared Swift 경계 확인

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### 3. 기존 Stage 3 render smoke 확인

```bash
./scripts/validate-stage3-render.sh output/task65-stage5-smoke
```

결과:

- `KTX.hwp`: `1123x794`, `textRuns=435`, `hangulRuns=76`, `hangulScalars=209`, `nonWhitePixels=450455`
- `request.hwp`: `567x794`, `textRuns=104`, `hangulRuns=36`, `hangulScalars=309`, `nonWhitePixels=54724`
- `exam_kor.hwp`: `1123x1588`, `textRuns=69`, `hangulRuns=51`, `hangulScalars=940`, `nonWhitePixels=96464`

기존 smoke PNG 생성 경로는 유지된다.

### 4. 저장소 샘플 비교 산출물 확인

```bash
./scripts/render-debug-compare.sh output/task65-stage5-debug samples/basic/KTX.hwp
```

필수 산출물:

- `output/task65-stage5-debug/KTX-page1-render-tree.json`
- `output/task65-stage5-debug/KTX-page1-core.svg`
- `output/task65-stage5-debug/KTX-page1-native.png`
- `output/task65-stage5-debug/KTX-page1-summary.txt`

summary 주요 값:

- `PageCount=1`
- `PageSizePt=1122.5x793.7`
- `RenderTreeJSONBytes=982854`
- `CoreSVGBytes=474840`
- `NativePNGSize=1123x794`
- `NativeNonWhitePixels=450455`
- `TextRuns=435`
- `HangulRuns=76`
- `HangulScalars=209`
- `MissingHangulGlyphs=0`

일반 sandbox에서는 `qlmanage`가 다음 오류로 실패해 선택 산출물은 생성되지 않았다.

```text
sandbox initialization failed: invalid data type of path filter; expected pattern, got boolean
```

스크립트는 이 경우에도 필수 산출물 생성 성공 상태를 유지하고 summary에 `DiffReason`을 기록한다.

### 5. 수동 재현 샘플 비교 산출물 확인

```bash
./scripts/render-debug-compare.sh output/task65-stage5-table /Users/melee/Documents/samples/table-in-tbox.hwp
```

필수 산출물:

- `output/task65-stage5-table/table-in-tbox-page1-render-tree.json`
- `output/task65-stage5-table/table-in-tbox-page1-core.svg`
- `output/task65-stage5-table/table-in-tbox-page1-native.png`
- `output/task65-stage5-table/table-in-tbox-page1-summary.txt`

summary 주요 값:

- `PageCount=2`
- `PageSizePt=793.7x1122.5`
- `RenderTreeJSONBytes=826451`
- `CoreSVGBytes=434334`
- `NativePNGSize=794x1123`
- `NativeNonWhitePixels=11845`
- `TextRuns=472`
- `HangulRuns=187`
- `HangulScalars=779`
- `MissingHangulGlyphs=0`

일반 sandbox에서는 저장소 샘플과 같은 `qlmanage` 오류로 선택 산출물이 생성되지 않았고, summary에 fallback 사유가 기록됐다.

### 6. qlmanage 선택 산출물 확인

`qlmanage` 실행이 가능한 권한 상승 환경에서 같은 비교 스크립트를 다시 실행했다.

```bash
./scripts/render-debug-compare.sh output/task65-stage5-debug-escalated samples/basic/KTX.hwp
./scripts/render-debug-compare.sh output/task65-stage5-table-escalated /Users/melee/Documents/samples/table-in-tbox.hwp
```

`KTX.hwp` 선택 산출물:

- `output/task65-stage5-debug-escalated/KTX-page1-core.png`
- `output/task65-stage5-debug-escalated/KTX-page1-diff.png`
- `DiffCompareSize=1123x794`
- `DiffNativeSize=1123x794`
- `DiffCoreSize=1123x795`
- `DiffDifferentPixels=505176`
- `DiffDifferentPixelRatio=0.566555`
- `DiffMaxChannelDelta=255`

`table-in-tbox.hwp` 선택 산출물:

- `output/task65-stage5-table-escalated/table-in-tbox-page1-core.png`
- `output/task65-stage5-table-escalated/table-in-tbox-page1-diff.png`
- `DiffCompareSize=794x1123`
- `DiffNativeSize=794x1123`
- `DiffCoreSize=795x1123`
- `DiffDifferentPixels=179655`
- `DiffDifferentPixelRatio=0.201483`
- `DiffMaxChannelDelta=255`

두 샘플 모두 core PNG와 diff PNG 생성이 확인됐다. core rasterize PNG는 SVG rasterizer의 반올림 때문에 native PNG와 한 축에서 1px 차이가 발생할 수 있으며, diff는 공통 비교 크기로 정규화된다.

## 판단

- 기존 `validate-stage3-render.sh` smoke 동작은 유지된다.
- 신규 `render-debug-compare.sh`는 저장소 샘플과 수동 재현 샘플 모두에서 필수 산출물 4종을 생성한다.
- 일반 sandbox에서 `qlmanage`가 실패해도 필수 산출물 생성은 실패 처리되지 않고, summary에 fallback 사유가 남는다.
- `qlmanage` 실행 가능 환경에서는 core PNG와 diff PNG 선택 산출물이 생성된다.
- `Sources/RhwpCoreBridge`에 AppKit/UIKit 직접 의존은 추가되지 않았다.

## 변경 파일

- `mydocs/working/task_m020_65_stage5.md`

## 승인 요청

Stage 5 완료를 승인하면 최종 보고서 작성과 PR 게시 준비로 진행한다.
