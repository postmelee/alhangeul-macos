# Task M050 #109 Stage 3 보고서

## 단계 목적

도형 fill 계열 parity를 보강했다. Stage 3 범위는 `ShapeStyle.shadow`, `LineStyle.shadow`, `ShapeStyle.pattern` 처리이며, 기존 solid fill, gradient, stroke, transform 경로를 유지하는 선에서 구현했다.

## 산출물

| 파일 | line count | 변경 요약 |
| --- | ---: | --- |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | 2828 | shape/line shadow, pattern fill, shadow-safe graphics state helper를 추가했다. |
| `mydocs/working/task_m050_109_stage3.md` | 신규 | Stage 3 구현, 검증, 직접 비교 방법을 기록했다. |

## 구현 내용

| 항목 | 처리 |
| --- | --- |
| shape shadow | `ShapeStyle.shadow`를 solid fill, pattern background fill, gradient silhouette, stroke-only shape에 적용했다. alpha는 rhwp-studio WebCanvas와 같이 `1 - alpha/255`로 해석하고 blur는 2.0으로 맞췄다. |
| line shadow | `LineStyle.shadow`를 line stroke와 Stage 2에서 추가한 arrow head draw에 함께 적용했다. |
| path line shadow | `PathNode.lineStyle.shadow`가 있으면 path stroke와 connector arrow에 같은 shadow state를 적용했다. |
| pattern fill | pattern type 0-5를 6pt tile 기준으로 구현했다. 0=horizontal, 1=vertical, 2=diagonal, 3=reverse diagonal, 4=cross, 5=diagonal cross로 처리한다. |
| graphics state | fill/stroke/pattern/shadow helper마다 `saveGState`/`restoreGState` 경계를 둬 alpha, dash, shadow, clip이 밖으로 새지 않게 했다. |

## 보류 / fallback

- 알 수 없는 pattern type은 background fill만 남기고 pattern line은 그리지 않는다.
- gradient shadow는 gradient 자체가 아니라 같은 path silhouette에 shadow를 먼저 적용한 뒤 gradient를 그리는 근사다.
- pattern/shadow를 직접 포함한 실제 HWP 샘플이 저장소 후보군에서 확인되지 않아, 실제 문서 시각 parity는 추가 샘플 확보 후 재확인이 필요하다.
- advanced fill, image fill, transparency blend mode 세부 parity는 이번 단계 범위 밖이다.

## 직접 비교 방법

저장소 후보 샘플 21개에서는 `pattern` 또는 `shadow`가 non-null인 render tree를 찾지 못했다. 대신 renderer 경로만 검증할 수 있도록 synthetic render tree before/after PNG를 생성했다.

| 구분 | 파일 |
| --- | --- |
| Stage 3 적용 전 | `/private/tmp/rhwp-task109-stage3-visual/stage3-before.png` |
| Stage 3 적용 후 | `/private/tmp/rhwp-task109-stage3-visual/stage3-after.png` |

작업지시자가 직접 확인할 때는 두 PNG를 나란히 열고 다음을 보면 된다.

- 좌상단 ellipse: after에서 파란 diagonal cross pattern과 우하단 shadow가 보여야 한다.
- 좌하단 rectangle: after에서 오른쪽/아래쪽 shadow가 보여야 한다.
- 우하단 rounded rectangle: after에서 빨간 cross pattern이 보여야 한다.
- 우측 line/arrow: after에서 점선 화살표 뒤로 옅은 shadow가 보여야 한다.

실제 HWP/HWPX 문서로 비교하려면 pattern fill 또는 shape shadow가 들어간 문서를 준비한 뒤, Stage 2 commit `29a8c57` 기준 PNG와 현재 Stage 3 PNG를 각각 `render-debug-compare.sh`로 생성해 native PNG를 나란히 비교한다.

## 본문 변경 정도 / 본문 무손실 여부

소스 변경은 `CGTreeRenderer.swift`에 한정했다. `RenderTree.swift`, Rust bridge, Xcode project, resource는 변경하지 않았다. 기존 gradient/solid/stroke 함수 호출 순서는 유지하되, shadow/pattern helper를 통해 drawing state 경계를 세분화했다.

## 검증 결과

| 명령 | 결과 |
| --- | --- |
| `git status --short --branch` | `/private/tmp/rhwp-mac-task109`에서 `local/task109` 확인 |
| `git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift` | `CGTreeRenderer.swift`만 변경, `RenderTree.swift` 변경 없음 |
| `./scripts/check-no-appkit.sh` | 통과: shared Swift code AppKit/UIKit 직접 의존 없음 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage3-bokhak samples/복학원서.hwp` | 통과. native PNG 794x1123, non-white pixels 261878. qlmanage rasterize 문제로 diff PNG는 생성되지 않음 |
| `./scripts/validate-stage3-render.sh /private/tmp/rhwp-task109-stage3-smoke samples/basic/BookReview.hwp samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp` | 통과. BookReview/KTX/request/exam_kor 모두 PNG 생성 성공 |
| 후보 샘플 coverage 확인 | `h-pen-01`, `draw-group`, `group-drawing-02`, `group-box`, `shape-group-02`, `task-001`, `form-01`, `hwp_table_test`, `form-002.hwpx`, `2010-01-06`, `aift`, `biz_plan`, `k-water-rfp`, `kps-ai`, `20250130-hongbo`, `honbo-save`, `pr-149`, `hwpctl_*`, `hwpers_test4_complex_table`에서 `pattern`/`shadow` non-null 항목 미확인 |
| synthetic before/after render | `/private/tmp/rhwp-task109-stage3-visual/stage3-before.png`, `/private/tmp/rhwp-task109-stage3-visual/stage3-after.png` 생성 완료 |
| `git diff --check` | 통과 |

## 잔여 위험

- 실제 pattern/shadow 문서 기반 시각 비교가 아직 없다. 사용자가 해당 문서를 제공하거나 추가 샘플을 만들면 before/after PNG로 재검증해야 한다.
- pattern line spacing은 rhwp-studio의 6px tile 기준을 CoreGraphics point 단위로 옮긴 근사다.
- shadow blur/alpha는 WebCanvas 기준을 따랐지만 CoreGraphics shadow rasterization과 Canvas shadow rasterization은 픽셀 단위로 완전히 같지 않을 수 있다.

## 다음 단계 영향

Stage 4에서는 텍스트 저위험 style을 보강한다. 이번 Stage 3의 shadow helper는 shape/line 전용이므로 text shadow에는 별도 text pass helper를 써야 한다.

## 승인 요청

Stage 3 구현과 검증을 완료했다. 다음 단계로 `Stage 4. 텍스트 저위험 style 보강`을 진행하려면 작업지시자 승인이 필요하다.
