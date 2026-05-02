# Task M015 #106 구현 계획서

수행계획서: `mydocs/plans/task_m015_106.md`

각 단계 완료 후 `task-stage-report` 절차로 단계 보고서를 작성하고 작업지시자 승인을 받은 뒤 다음 단계로 넘어간다.

## 작업 개요

- 이슈: #106 Swift native renderer 이미지 crop/effect/brightness/contrast 보강
- 마일스톤: M015 (`첫 출시 전 Swift 렌더 보강`)
- 브랜치: `local/task106`
- 작업 위치: `/Users/melee/Documents/projects/rhwp-mac-task106`
- 주 대상: `Sources/RhwpCoreBridge/RenderTree.swift`, `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 기준 샘플: `samples/복학원서.hwp`
- 목표: PageRenderTree 이미지 노드의 crop/effect/brightness/contrast를 Swift native renderer에 반영해 core SVG와 native PNG의 워터마크 이미지 차이를 줄인다.

## 구현 원칙

- 제품 기준 경로는 기존 `rhwp_render_page_tree` + Swift `RenderTree` + `CGTreeRenderer` 경로를 유지한다.
- PageLayerTree ABI 추가 또는 기본 렌더 경로 전환은 하지 않는다.
- `Sources/RhwpCoreBridge`에는 AppKit/UIKit 직접 의존을 추가하지 않는다.
- HostApp, Quick Look, Thumbnail 상위 호출부는 변경하지 않고 공통 renderer 내부에서 처리한다.
- render tree JSON의 실제 필드명과 단위를 Stage 1에서 먼저 확인한 뒤 코드 변경에 반영한다.
- 지원하지 못하는 effect/fill mode는 crash 없이 기존 전체 이미지 bbox draw로 fallback한다.
- 이미지 캐시는 원본 `binDataId` 기준 캐시와 노드별 crop/effect 결과를 혼동하지 않는다.
- CoreImage를 쓰는 경우 `render-debug-compare.sh`와 `validate-stage3-render.sh`의 `swiftc` 링크 옵션도 함께 갱신한다.

## Stage 1. 기준 재현과 이미지 필드 의미 확정

### 목표

- `복학원서.hwp`에서 core SVG와 native PNG의 워터마크 이미지 차이를 현재 브랜치에서 재현한다.
- render tree JSON과 core SVG가 제공하는 `crop`, `effect`, `brightness`, `contrast`, `fill_mode`, 원본 크기 필드명을 확정한다.
- crop 값의 단위와 source rect 변환 규칙을 코드 변경 전에 고정한다.

### 작업

- `samples/복학원서.hwp`의 sample hash를 기록한다.
- `render-debug-compare.sh`로 변경 전 기준 산출물을 생성한다.
- summary의 page size, native non-white pixel, diff 생성 여부를 기록한다.
- render tree JSON에서 `Image` 노드와 관련 필드를 추출한다.
- core SVG에서 이미지 filter, crop/clip, transform 표현을 확인한다.
- 기존 `ImageNode` 모델과 `renderImage` 구현이 어떤 필드를 놓치는지 정리한다.
- crop source rect 계산에 필요한 원본 이미지 픽셀 크기와 HU 단위 변환 근거를 보고서에 기록한다.

### 예상 변경 파일

- `mydocs/working/task_m015_106_stage1.md`

### 검증

```bash
git status --short --branch
shasum -a 256 samples/복학원서.hwp
./scripts/render-debug-compare.sh /private/tmp/rhwp-task106-stage1 --page 1 samples/복학원서.hwp
test -s /private/tmp/rhwp-task106-stage1/복학원서-page1-render-tree.json
test -s /private/tmp/rhwp-task106-stage1/복학원서-page1-core.svg
test -s /private/tmp/rhwp-task106-stage1/복학원서-page1-native.png
test -s /private/tmp/rhwp-task106-stage1/복학원서-page1-summary.txt
sed -n '1,140p' /private/tmp/rhwp-task106-stage1/복학원서-page1-summary.txt
rg -n "\"Image\"|\"crop\"|\"effect\"|\"brightness\"|\"contrast\"|\"fill_mode\"|\"original\"" /private/tmp/rhwp-task106-stage1/복학원서-page1-render-tree.json
rg -n "filter|feColorMatrix|feComponentTransfer|brightness|contrast|clipPath|<image" /private/tmp/rhwp-task106-stage1/복학원서-page1-core.svg
git diff --check
```

### 완료 기준

- 기준 산출물 위치와 핵심 summary 값이 보고서에 기록된다.
- Swift renderer가 빠뜨린 이미지 필드와 적용 순서가 확인된다.
- crop source rect 계산식의 입력 값과 남은 불확실성이 정리된다.

### 커밋 메시지

```text
Task #106 Stage 1: 이미지 렌더 기준과 필드 의미 확정
```

## Stage 2. ImageNode 디코딩과 crop source rect 적용

### 목표

- `RenderTree.swift`가 Stage 1에서 확인한 이미지 필드를 디코딩한다.
- `CGTreeRenderer`가 crop source rect를 계산해 원본 이미지의 해당 영역만 bbox에 그린다.

### 작업

- `ImageNode`에 `effect`, `brightness`, `contrast`, `originalSizeHU` 또는 Stage 1에서 확인한 원본 크기 필드를 추가한다.
- 기존 `fillMode`, `originalSize`, `crop` 디코딩과 새 필드가 누락 값에 안전하도록 optional로 둔다.
- `renderImage`에서 원본 `CGImage` 로딩과 draw 대상 이미지 생성을 분리한다.
- crop 값이 유효하면 source rect를 원본 이미지 픽셀 좌표로 변환하고 `cgImage.cropping(to:)`를 적용한다.
- crop 값이 없거나 rect가 비정상이면 기존 전체 이미지 draw fallback을 유지한다.
- Stage 2에서는 색상 effect를 적용하지 않고 crop과 draw 좌표 안정성만 검증한다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/RenderTree.swift`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `mydocs/working/task_m015_106_stage2.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/RenderTree.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task106-stage2 --page 1 samples/복학원서.hwp
test -s /private/tmp/rhwp-task106-stage2/복학원서-page1-native.png
sed -n '1,140p' /private/tmp/rhwp-task106-stage2/복학원서-page1-summary.txt
git diff --check -- Sources/RhwpCoreBridge/RenderTree.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift mydocs/working/task_m015_106_stage2.md
```

### 완료 기준

- 새 이미지 필드가 디코딩 실패 없이 optional로 수용된다.
- crop이 있는 이미지가 source rect 기반으로 그려진다.
- crop이 없는 기존 이미지 샘플의 전체 bbox draw fallback이 유지된다.
- AppKit/UIKit 직접 의존 금지 검증이 통과한다.

### 커밋 메시지

```text
Task #106 Stage 2: 이미지 crop source rect 적용
```

## Stage 3. 이미지 effect와 fill mode fallback 보강

### 목표

- grayscale/black-white 계열 effect와 brightness/contrast를 native PNG에 반영한다.
- `fill_mode`와 원본 크기 정보는 안전한 최소 지원 및 fallback 정책으로 정리한다.

### 작업

- Stage 1에서 확인한 effect 문자열 또는 enum 값을 Swift 모델과 renderer helper에서 처리한다.
- grayscale은 우선 구현하고, black-white 계열 값이 확인되면 threshold 기반 또는 명시 fallback으로 처리한다.
- brightness/contrast는 core SVG의 필터 방향과 같은 방향으로 보정하되, 완전 수치 parity가 어려우면 1차 근사로 문서화한다.
- CoreImage를 사용하면 `CGTreeRenderer.swift`에 `import CoreImage`를 추가하고, `scripts/render-debug-compare.sh`와 `scripts/validate-stage3-render.sh`에 `-framework CoreImage`를 추가한다.
- CoreImage를 쓰지 않는 경우에는 CoreGraphics bitmap context 기반 픽셀 보정 helper를 추가한다.
- `fill_mode`는 `FitToSize` 또는 Stage 1에서 확인한 기본 모드를 우선 지원하고, 미지원 값은 기존 bbox draw fallback으로 남긴다.
- 원본 이미지 캐시와 crop/effect 결과 캐시를 섞지 않도록 노드별 처리 결과는 현재 draw 호출 안에서만 사용하거나 별도 key 정책을 둔다.

### 예상 변경 파일

- `Sources/RhwpCoreBridge/RenderTree.swift`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- 필요 시 `scripts/render-debug-compare.sh`
- 필요 시 `scripts/validate-stage3-render.sh`
- `mydocs/working/task_m015_106_stage3.md`

### 검증

```bash
git status --short --branch
git diff -- Sources/RhwpCoreBridge/RenderTree.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift scripts/render-debug-compare.sh scripts/validate-stage3-render.sh
./scripts/check-no-appkit.sh
./scripts/render-debug-compare.sh /private/tmp/rhwp-task106-stage3 --page 1 samples/복학원서.hwp
test -s /private/tmp/rhwp-task106-stage3/복학원서-page1-native.png
sed -n '1,160p' /private/tmp/rhwp-task106-stage3/복학원서-page1-summary.txt
git diff --check -- Sources/RhwpCoreBridge/RenderTree.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift scripts/render-debug-compare.sh scripts/validate-stage3-render.sh mydocs/working/task_m015_106_stage3.md
```

### 완료 기준

- `복학원서.hwp` native PNG 워터마크가 기존 풀컬러 표시보다 core SVG와 같은 방향으로 흐리게 보인다.
- crop과 effect가 함께 적용돼도 이미지가 상하 반전되거나 bbox 밖으로 밀리지 않는다.
- 미지원 effect/fill mode는 crash 없이 fallback한다.
- script 기반 render smoke가 새 framework 의존성 때문에 깨지지 않는다.

### 커밋 메시지

```text
Task #106 Stage 3: 이미지 효과와 fill mode fallback 보강
```

## Stage 4. 대표 이미지 샘플 render smoke 검증

### 목표

- `복학원서.hwp` 외 대표 이미지 포함 샘플에서 기존 이미지 렌더링이 회귀하지 않았는지 확인한다.
- core SVG/native PNG 비교 산출물과 summary 값을 보고서에 남긴다.

### 작업

- `복학원서.hwp`, `samples/20250130-hongbo.hwp`, `samples/aift.hwp`를 render-debug 대상으로 실행한다.
- 각 summary에서 `NativePNGSize`, `NativeNonWhitePixels`, `TextRuns`, `MissingHangulGlyphs`, diff 상태를 기록한다.
- 가능하면 core raster PNG와 diff PNG를 확인하되, `qlmanage` 실패는 필수 실패로 보지 않고 summary의 `DiffReason`으로 기록한다.
- Stage 2/3 전후 산출물을 비교해 워터마크 개선과 기존 이미지 회귀 여부를 정리한다.

### 예상 변경 파일

- `mydocs/working/task_m015_106_stage4.md`

### 검증

```bash
git status --short --branch
./scripts/render-debug-compare.sh /private/tmp/rhwp-task106-stage4 --page 1 samples/복학원서.hwp samples/20250130-hongbo.hwp samples/aift.hwp
test -s /private/tmp/rhwp-task106-stage4/복학원서-page1-summary.txt
test -s /private/tmp/rhwp-task106-stage4/20250130-hongbo-page1-summary.txt
test -s /private/tmp/rhwp-task106-stage4/aift-page1-summary.txt
sed -n '1,160p' /private/tmp/rhwp-task106-stage4/복학원서-page1-summary.txt
sed -n '1,160p' /private/tmp/rhwp-task106-stage4/20250130-hongbo-page1-summary.txt
sed -n '1,160p' /private/tmp/rhwp-task106-stage4/aift-page1-summary.txt
git diff --check -- mydocs/working/task_m015_106_stage4.md
```

### 완료 기준

- 기준 샘플 3개 모두 필수 산출물(render tree JSON, core SVG, native PNG, summary)이 생성된다.
- `복학원서.hwp` 워터마크 개선 결과가 보고서에 기록된다.
- 대표 이미지 샘플에서 native PNG가 blank가 아니고 기존 이미지가 사라지지 않는다.

### 커밋 메시지

```text
Task #106 Stage 4: 이미지 샘플 렌더 smoke 검증
```

## Stage 5. 통합 검증과 최종 보고

### 목표

- HostApp, Quick Look, Thumbnail 공통 renderer 변경으로서 기본 build/smoke를 확인한다.
- 최종 보고서와 오늘할일을 정리하고 PR 전 상태를 만든다.

### 작업

- `Sources/RhwpCoreBridge` 경계 검증을 다시 실행한다.
- `validate-stage3-render.sh`로 기본 native render pipeline 회귀를 확인한다.
- `xcodegen generate` 후 HostApp Debug build를 실행한다.
- Stage 1-4 결과, 변경 파일, 검증 명령, 잔여 리스크를 최종 보고서에 정리한다.
- 오늘할일 #106 행을 완료 상태로 갱신한다.

### 예상 변경 파일

- `mydocs/working/task_m015_106_stage5.md`
- `mydocs/report/task_m015_106_report.md`
- `mydocs/orders/20260501.md`

### 검증

```bash
git status --short --branch
./scripts/check-no-appkit.sh
./scripts/validate-stage3-render.sh
xcodegen generate
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
```

### 완료 기준

- AppKit/UIKit 직접 의존 금지 검증이 통과한다.
- 기본 render smoke와 HostApp Debug build가 통과한다.
- 최종 보고서에 구현 내용, 검증 결과, 남은 parity 차이가 정리된다.
- 오늘할일 #106 행이 완료 상태로 갱신된다.

### 커밋 메시지

```text
Task #106 Stage 5 + 최종 보고서: 이미지 렌더 보강 검증
```

## 승인 요청 사항

1. 위 5단계 구현계획으로 Stage 1 기준 재현과 이미지 필드 의미 확정에 착수해도 되는지 승인 요청한다.
2. Stage 1은 source code 변경 없이 조사와 단계 보고서 작성으로 진행한다.
3. Stage 2부터 `Sources/RhwpCoreBridge/RenderTree.swift`와 `Sources/RhwpCoreBridge/CGTreeRenderer.swift` 코드 변경이 포함된다.
