# Task M015 #106 Stage 2 완료 보고서

## 단계 목적

`ImageNode`가 Stage 1에서 확인한 이미지 효과 관련 필드를 디코딩하도록 보강하고, `CGTreeRenderer`가 이미지 `crop` 값을 source pixel rect로 변환해 draw에 적용하도록 구현했다.

이번 단계는 색상 effect 적용 전 단계다. `GrayScale`, `brightness`, `contrast`, `fill_mode` 렌더 보정은 Stage 3 범위로 남겼다.

## 산출물

| 파일 | 요약 |
|------|------|
| `Sources/RhwpCoreBridge/RenderTree.swift` | `ImageNode`에 `originalSizeHU`, `effect`, `brightness`, `contrast` optional 디코딩 필드 추가 |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | `crop` HU 값을 75 HU/px 기준 source pixel rect로 변환하고 `CGImage.cropping(to:)` 적용 |
| `mydocs/working/task_m015_106_stage2.md` | Stage 2 구현과 검증 결과 |

변경량:

```text
Sources/RhwpCoreBridge/CGTreeRenderer.swift | 23 ++++++++++++++++++++++-
Sources/RhwpCoreBridge/RenderTree.swift     |  7 ++++++-
2 files changed, 28 insertions(+), 2 deletions(-)
```

## 본문 변경 정도 / 본문 무손실 여부

Swift renderer 공통 계층 2개 파일만 변경했다. HostApp, Quick Look, Thumbnail 호출부는 변경하지 않았다.

기존 이미지 로딩 캐시는 원본 `binDataId` 기준으로 유지했고, crop 결과는 draw 호출 안에서만 계산한다. crop이 없거나 길이가 4가 아니거나 source rect가 비정상이면 기존 전체 이미지 draw로 fallback한다.

## 구현 내용

`ImageNode` 디코딩:

- `original_size_hu` -> `originalSizeHU`
- `effect`
- `brightness`
- `contrast`

모든 새 필드는 optional로 두어 기존 render tree와 필드 누락 문서를 안전하게 처리한다.

`CGTreeRenderer` crop 처리:

- `imageCropUnitsPerPixel = 75.0` 상수를 추가했다.
- `crop[0...3]`을 각각 left/top/right/bottom HU 값으로 보고 pixel 단위로 변환한다.
- left/top은 `floor`, right/bottom은 `ceil`을 사용해 Stage 1에서 확인한 `54660 / 75 = 728.8 -> 729px` 케이스를 보존한다.
- 변환 rect는 실제 `CGImage` width/height로 clamp한다.
- `CGImage.cropping(to:)`가 실패하면 원본 image를 그대로 그린다.

주요 코드 위치:

- `Sources/RhwpCoreBridge/RenderTree.swift:297`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:11`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:251`
- `Sources/RhwpCoreBridge/CGTreeRenderer.swift:281`

## 검증 결과

작업 브랜치 상태:

```text
## local/task106...origin/devel [ahead 3]
 M Sources/RhwpCoreBridge/CGTreeRenderer.swift
 M Sources/RhwpCoreBridge/RenderTree.swift
```

변경 diff 확인:

```text
git diff -- Sources/RhwpCoreBridge/RenderTree.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift
```

결과: `ImageNode` optional 필드와 `croppedImage(for:crop:)` helper 변경만 확인했다.

AppKit/UIKit 의존 금지 검증:

```text
OK: shared Swift code has no AppKit/UIKit dependencies
```

render debug 실행:

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task106-stage2 --page 1 samples/복학원서.hwp
```

결과:

```text
OK 복학원서.hwp: page=1 renderTreeJSON=/private/tmp/rhwp-task106-stage2/...-render-tree.json coreSVG=/private/tmp/rhwp-task106-stage2/...-core.svg nativePNG=/private/tmp/rhwp-task106-stage2/...-native.png summary=/private/tmp/rhwp-task106-stage2/...-summary.txt
```

summary 핵심값:

| 항목 | 값 |
|------|----|
| PageCount | 1 |
| PageSizePt | `793.7x1122.5` |
| RenderTreeJSONBytes | 189498 |
| CoreSVGBytes | 380803 |
| NativePNGSize | `794x1123` |
| NativeNonWhitePixels | 154266 |
| TextRuns / HangulRuns | `102 / 25` |
| MissingHangulGlyphs | 0 |
| Diff | `not generated` |
| DiffReason | `qlmanage rasterize failed; see ...core.svg.qlmanage.log` |

필수 산출물 확인:

```text
test -s render-tree.json: 통과
test -s core.svg: 통과
test -s native.png: 통과
test -s summary.txt: 통과
```

PNG 크기 확인:

```text
pixelWidth: 794
pixelHeight: 1123
```

whitespace 검증:

```text
git diff --check -- Sources/RhwpCoreBridge/RenderTree.swift Sources/RhwpCoreBridge/CGTreeRenderer.swift
```

결과: 통과.

## 잔여 위험

- `복학원서.hwp` 워터마크 crop은 실제 원본 전체 범위와 거의 일치하므로, Stage 2 native non-white 값은 Stage 1과 동일하다. crop helper의 실제 non-zero offset 케이스는 대표 샘플이나 후속 fixture에서 추가 확인이 필요하다.
- 색상 effect를 아직 적용하지 않았으므로 워터마크는 여전히 풀컬러에 가깝게 보인다. 이는 Stage 3 범위다.
- `qlmanage` sandbox 오류로 pixel diff는 생성되지 않았다. 필수 산출물은 모두 생성됐다.

## 다음 단계 영향

Stage 3에서는 이미 디코딩된 `effect`, `brightness`, `contrast` 값을 사용해 grayscale 및 brightness/contrast 보정을 적용한다. CoreImage를 선택할 경우 render-debug/validate 스크립트의 framework 링크 옵션도 함께 갱신해야 한다.

## 승인 요청

Stage 2 완료를 승인하고 Stage 3 `이미지 effect와 fill mode fallback 보강`으로 진행해도 되는지 승인 요청한다.
