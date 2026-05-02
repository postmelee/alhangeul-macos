# Task M015 #106 최종 보고서

## 작업 개요

- 이슈: #106 Swift native renderer 이미지 crop/effect/brightness/contrast 보강
- 마일스톤: M015 (`첫 출시 전 Swift 렌더 보강`)
- 브랜치: `local/task106`
- 핵심 변경: Swift native renderer가 이미지 crop source rect, effect, brightness, contrast 필드를 반영하도록 보강
- 기준 샘플: `samples/복학원서.hwp`

## 완료 내용

`복학원서.hwp`에서 워터마크 이미지가 core SVG와 다르게 풀컬러로 표시되던 원인을 추적했다.

render tree의 watermark image node에는 `crop`, `original_size_hu`, `effect`, `brightness`, `contrast` 값이 있었지만, 기존 Swift native renderer는 `crop`을 destination fit 계산에만 일부 사용하고 `effect`, `brightness`, `contrast`를 decode하지 않았다. 그 결과 core SVG가 적용하던 grayscale 및 brightness/contrast 필터가 native PNG에는 적용되지 않았다.

이번 작업에서 `RenderTree.ImageNode`가 이미지 렌더 관련 필드를 decode하도록 확장했고, `CGTreeRenderer`의 이미지 준비 pipeline을 다음 순서로 정리했다.

1. `crop` 값을 source pixel rect로 변환해 `CGImage.cropping(to:)` 적용
2. bitmap context에 RGBA로 복사
3. grayscale effect 적용
4. brightness/contrast 보정 적용
5. fill mode가 명확하지 않은 경우 bbox 전체 draw fallback 유지

`복학원서.hwp`의 watermark는 Stage 3 이후 native PNG에서도 grayscale 및 brightness/contrast 적용 상태로 렌더된다.

## 변경 파일

- `Sources/RhwpCoreBridge/RenderTree.swift`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift`
- `mydocs/plans/task_m015_106.md`
- `mydocs/plans/task_m015_106_impl.md`
- `mydocs/working/task_m015_106_stage1.md`
- `mydocs/working/task_m015_106_stage2.md`
- `mydocs/working/task_m015_106_stage3.md`
- `mydocs/working/task_m015_106_stage4.md`
- `mydocs/working/task_m015_106_stage5.md`
- `mydocs/report/task_m015_106_report.md`
- `mydocs/orders/20260501.md`

## 단계별 결과

### Stage 1 기준 확정

`samples/복학원서.hwp` SHA-256:

```text
da81b4010331bcac290f900c7cf224c97ee8355399614725ce46c197ff1a22a4
```

watermark image node 핵심값:

```text
node id: 84
crop: [0, 0, 54600, 54660]
original_size_hu: [37128, 37180]
effect: GrayScale
brightness: -50
contrast: 70
source JPEG: 728x729
```

`crop` 값은 HU 기준이며 75로 나누면 source pixel 기준 `728x728.8`에 해당한다. core SVG 필터는 grayscale matrix와 brightness/contrast component transfer를 사용했다.

### Stage 2 crop 적용

`RenderTree.ImageNode`에 다음 필드를 추가했다.

- `originalSizeHU`
- `effect`
- `brightness`
- `contrast`

`CGTreeRenderer`는 `crop[0...3]`을 left/top/right/bottom HU로 해석하고, `75.0`으로 나눠 source pixel rect를 계산한다. left/top은 floor, right/bottom은 ceil로 변환한 뒤 source image bounds에 clamp한다. invalid crop은 원본 이미지 draw로 fallback한다.

### Stage 3 effect와 fallback 보강

CoreImage 의존 없이 CoreGraphics bitmap context에서 image adjustment를 수행하도록 구현했다.

- `GrayScale` effect는 luminance 계수 `0.299`, `0.587`, `0.114`를 적용한다.
- brightness/contrast는 `slope = max(0, 1 + contrast / 100)`, `intercept = brightness / 100 * slope`로 계산한다.
- `RealPic`, `none`, 빈 effect는 no-op 처리한다.
- black/white 계열 effect는 전용 샘플이 없어 grayscale fallback으로 처리한다.
- fit-to-size/stretch 계열과 알 수 없는 fill mode는 bbox 전체 draw fallback을 유지한다.

Stage 2와 Stage 3의 `복학원서.hwp` native PNG hash는 다음처럼 달라졌다.

```text
Stage 2: d66500abc3f52a2be4744ad54d62cb5a13852a8ac8b7ab93080ad2881967e8ae
Stage 3: d164965a236b38d28ea79d03de17f0c289aeed91c80768ad6c59dff6339f4e9c
```

Stage 3 이후 watermark가 풀컬러 표시에서 grayscale 및 brightness/contrast 적용 상태로 바뀌었다.

### Stage 4 대표 샘플 smoke

```bash
./scripts/render-debug-compare.sh /private/tmp/rhwp-task106-stage4 --page 1 samples/복학원서.hwp samples/20250130-hongbo.hwp samples/aift.hwp
```

summary 핵심값:

| 샘플 | PageCount | NativePNGSize | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|------|-----------|---------------|----------------------|----------|------------|----------------------|
| `복학원서.hwp` | 1 | `794x1123` | 261727 | 102 | 25 | 0 |
| `20250130-hongbo.hwp` | 4 | `794x1123` | 84406 | 60 | 35 | 0 |
| `aift.hwp` | 77 | `794x1123` | 132970 | 25 | 15 | 0 |

Stage 3/Stage 4의 `복학원서.hwp` native PNG hash는 동일했다.

```text
d164965a236b38d28ea79d03de17f0c289aeed91c80768ad6c59dff6339f4e9c
```

### Stage 5 통합 검증

bridge 경계 검증:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

기본 native render smoke:

```text
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452058
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=67872
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=176212
```

Xcode project 재생성과 HostApp Debug build도 통과했다.

```text
Created project at /Users/melee/Documents/projects/rhwp-mac-task106/AlhangeulMac.xcodeproj
** BUILD SUCCEEDED ** [11.031 sec]
```

## 검증 요약

```text
./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

```text
./scripts/validate-stage3-render.sh
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452058
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=67872
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=176212
```

```text
xcodegen generate
Created project at /Users/melee/Documents/projects/rhwp-mac-task106/AlhangeulMac.xcodeproj
```

```text
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [11.031 sec]
```

`git diff --check`도 통과했다.

## 제한 사항

- `render-debug-compare.sh`의 optional core SVG rasterize/pixel diff는 로컬 `qlmanage` sandbox 오류로 생성되지 않았다.
- black/white 계열 effect는 전용 샘플이 없어 grayscale fallback으로 남겼다.
- fill mode 전체 parity는 이번 #106 범위가 아니며, 미지원 mode는 bbox draw fallback을 유지한다.
- WMF/BMP/PCX 변환 정책은 이번 #106 범위가 아니다.

## 잔여 위험

- grayscale과 brightness/contrast는 core SVG 동작을 기준으로 근사했지만, 모든 색공간/알파 조합의 pixel parity를 보장하는 수준의 diff 검증은 하지 못했다.
- crop 단위는 이번 기준 샘플과 core SVG 출력을 근거로 HU/75 source pixel 변환으로 확정했다. 다른 이미지 유형에서 core와 다른 unit을 내보내는 사례가 있으면 별도 보정이 필요하다.

## 결론

Issue #106의 목표인 Swift native renderer 이미지 `crop`, `effect`, `brightness`, `contrast` 보강은 완료됐다.

`복학원서.hwp` watermark는 더 이상 풀컬러 원본으로만 렌더되지 않고, render tree의 crop source rect와 grayscale/brightness/contrast 값이 native renderer에 반영된다. HostApp Debug build와 bridge 경계 검증도 통과했다.
