# Task M030 #35 Stage 4 완료보고서

## 단계 목표

`group-drawing-02.hwp`의 직접 렌더링 경로에서 render tree와 Swift renderer의 도형 처리 차이를 확인하고, Finder icon view와 Quick Look preview에 영향을 줄 수 있는 누락을 보정한다.

## 조사 내용

### 1. core render tree 변환 정보

`Vendor/rhwp/src/renderer/render_tree.rs`의 `ShapeTransform`은 다음 정보만 직렬화한다.

- `rotation`
- `horz_flip`
- `vert_flip`

즉, 현재 Swift bridge가 받는 도형 변환 정보는 core의 SVG/WebCanvas 렌더러가 사용하는 변환 정보와 동일한 회전/대칭 범위다.

### 2. core renderer 기준 동작

core의 SVG/WebCanvas 렌더러는 `Line` 노드에도 `open_shape_transform(&line.transform, &node.bbox)`를 적용한다.

반면 Swift `CGTreeRenderer`는 사각형, 타원, 패스, 이미지에는 `applyTransform`을 적용하지만 직선에는 적용하지 않고 있었다. 따라서 회전/대칭이 있는 직선 도형은 core SVG 결과와 Swift 직접 렌더 결과가 달라질 수 있다.

### 3. group drawing 샘플 관찰

`Vendor/rhwp/samples/group-drawing-02.hwp`는 top-level group과 nested group을 포함하며, child shape에 직선과 사각형이 섞여 있다. 이 샘플에서 embedded preview를 쓰지 않는 정책으로 전환한 뒤에도 직접 렌더 경로의 도형 정합성을 맞추려면 line transform 누락을 먼저 제거하는 것이 맞다.

## 변경 내용

`Sources/RhwpCoreBridge/CGTreeRenderer.swift`에서 직선 렌더링도 bbox와 함께 호출하도록 바꾸고, 그리기 전에 `applyTransform(line.transform, bbox: bbox, in: ctx)`를 적용했다.

변경 후 직선, 사각형, 타원, 패스, 이미지 도형이 동일한 `ShapeTransform` 처리 규칙을 따른다.

## 검증

### Shared bridge 경계

```bash
./scripts/check-no-appkit.sh
```

결과:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

### 렌더링 smoke test

```bash
./scripts/validate-stage3-render.sh output/task35-stage4-render
```

결과:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=435 hangulRuns=76 hangulScalars=209 nonWhitePixels=450455
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=54724
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=69 hangulRuns=51 hangulScalars=940 nonWhitePixels=96464
```

### HostApp Debug build

```bash
xcodebuild -project AlhangeulMac.xcodeproj \
  -scheme HostApp \
  -configuration Debug \
  -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

결과:

```text
** BUILD SUCCEEDED **
```

## 판단

- Finder icon view와 Quick Look preview는 Stage 3 정책에 따라 embedded preview 대신 직접 렌더링을 사용한다.
- 직접 렌더링 경로에서 core SVG/WebCanvas와 달랐던 line transform 누락을 보정했다.
- 남은 위험은 실제 Finder/Quick Look extension 환경에서 macOS thumbnail 캐시가 개입하는 수동 smoke test다. Stage 5에서 extension 산출물 기준 검증과 최종 보고로 정리한다.

## 변경 파일

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `mydocs/orders/20260425.md`
- `mydocs/working/task_m030_35_stage4.md`

## 승인 요청

Stage 4 완료를 승인하면 Stage 5 최종 검증과 보고서 작성으로 진행한다.
