# Task M015 #106 Stage 3 완료 보고서

## 단계 목적

Stage 2에서 디코딩한 이미지 `effect`, `brightness`, `contrast`를 Swift native renderer에 반영했다. `fill_mode`는 현재 샘플과 기존 동작을 기준으로 `FitToSize`/stretch 계열만 명시 지원하고, 미지원 값은 기존 bbox 전체 draw로 fallback하도록 정리했다.

## 산출물

| 파일 | 요약 |
|------|------|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | crop 이후 이미지 effect/brightness/contrast 보정 helper 추가, fill mode fallback 명시 |
| `mydocs/working/task_m015_106_stage3.md` | Stage 3 구현과 검증 결과 |

변경량:

```text
Sources/RhwpCoreBridge/CGTreeRenderer.swift | 142 +++++++++++++++++++++++++++-
1 file changed, 140 insertions(+), 2 deletions(-)
```

## 본문 변경 정도 / 본문 무손실 여부

Swift 공통 renderer의 이미지 draw 경로만 변경했다. `RenderTree.swift` 모델은 Stage 2에서 이미 확장했으므로 이번 단계에서 추가 변경하지 않았다.

CoreImage 사용을 검토했으나 현재 로컬 실행 환경에서 `CIContext.createCGImage`가 `nil`을 반환해 결과가 원본 이미지로 fallback되는 문제가 있었다. 최종 구현은 추가 framework 링크 없이 CoreGraphics bitmap context에서 RGB 값을 직접 보정하는 방식으로 정리했다.

## 구현 내용

이미지 처리 순서는 다음과 같다.

1. 원본 `CGImage`를 `binDataId` 기준 캐시에서 가져온다.
2. Stage 2의 crop source rect를 적용한다.
3. `effect`, `brightness`, `contrast`가 있으면 RGBA bitmap context에 그린 뒤 pixel 단위로 보정한다.
4. 기존 y-flip draw 보정을 유지해 bbox 안에 그린다.

보정 정책:

- `GrayScale`/`gray`/`greyscale` 계열은 core SVG와 같은 luminance 계수 `0.299, 0.587, 0.114`로 grayscale 처리한다.
- `brightness`/`contrast`는 Stage 1에서 확인한 core SVG `feComponentTransfer` 방향에 맞춰 `slope = 1 + contrast / 100`, `intercept = brightness / 100 * slope`로 적용한다.
- `RealPic`, `none`, 빈 effect는 원본 색상을 유지한다.
- black-white 계열 문자열은 현재 dedicated sample이 없으므로 crash 없이 grayscale로 fallback한다.
- `fill_mode`의 `FitToSize`, `stretch`, `stretch_to_fit` 계열은 기존처럼 bbox 전체 draw로 처리하고, 미지원 값도 bbox draw fallback으로 둔다.

주요 코드 위치:

- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:268` 이미지 준비 후 draw
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:305` 이미지 보정 진입점
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:351` pixel 보정 loop
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:401` effect 문자열 정규화
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:422` fill mode fallback

## 검증 결과

작업 브랜치 상태:

```text
## local/task106...origin/devel [ahead 4]
 M Sources/RhwpCoreBridge/CGTreeRenderer.swift
```

AppKit/UIKit 의존 금지 검증:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

render debug 실행:

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task106-stage3 --page 1 samples/복학원서.hwp
```

결과:

```text
OK 복학원서.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task106-stage3/...-render-tree.json coreSVG=/private/tmp/rhwp-task106-stage3/...-core.svg nativePNG=/private/tmp/rhwp-task106-stage3/...-native.png summary=/private/tmp/rhwp-task106-stage3/...-summary.txt
```

summary 핵심값:

| 항목 | Stage 2 | Stage 3 |
|------|---------|---------|
| NativePNGSize | `794x1123` | `794x1123` |
| NativeNonWhitePixels | 154266 | 261727 |
| TextRuns / HangulRuns | `102 / 25` | `102 / 25` |
| MissingHangulGlyphs | 0 | 0 |
| Diff | `not generated` | `not generated` |

PNG hash:

| 단계 | SHA-256 |
|------|---------|
| Stage 2 native PNG | `d66500abc3f52a2be4744ad54d62cb5a13852a8ac8b7ab93080ad2881967e8ae` |
| Stage 3 native PNG | `d164965a236b38d28ea79d03de17f0c289aeed91c80768ad6c59dff6339f4e9c` |

필수 산출물 확인:

```text
test -s render-tree.json: 통과
test -s core.svg: 통과
test -s native.png: 통과
test -s summary.txt: 통과
```

시각 확인:

- Stage 2 native PNG의 워터마크는 풀컬러 붉은 seal로 표시됐다.
- Stage 3 native PNG의 워터마크는 grayscale 및 brightness/contrast 보정이 적용된 흑백 계열 seal로 표시됐다.
- 이미지가 상하 반전되거나 bbox 밖으로 밀리는 문제는 관찰되지 않았다.

whitespace 검증:

```text
git diff --check -- Sources/RhwpCoreBridge/RenderTree.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift scripts/render-debug-compare.sh scripts/validate-stage3-render.sh
```

결과: 통과.

## 잔여 위험

- `qlmanage` sandbox 오류로 core SVG rasterize와 pixel diff는 생성되지 않았다. 필수 산출물인 render tree JSON, core SVG, native PNG, summary는 생성됐다.
- black-white effect는 dedicated sample이 없어 grayscale fallback으로 처리했다. threshold parity는 별도 샘플 확인 후 보강하는 편이 안전하다.
- Stage 3 검증은 `복학원서.hwp` 중심이다. 다른 이미지 포함 샘플의 회귀 확인은 Stage 4에서 수행한다.

## 다음 단계 영향

Stage 4에서는 `복학원서.hwp`, `samples/20250130-hongbo.hwp`, `samples/aift.hwp`를 render-debug 대상으로 실행해 대표 이미지 샘플의 non-blank와 기존 이미지 회귀 여부를 확인한다.

## 승인 요청

Stage 3 완료를 승인하고 Stage 4 `대표 이미지 샘플 render smoke 검증`으로 진행해도 되는지 승인 요청한다.
