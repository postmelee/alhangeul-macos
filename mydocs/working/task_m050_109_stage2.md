# Task M050 #109 Stage 2 보고서

## 단계 목적

도형 stroke/path 계열의 1차 parity를 보강했다. Stage 2 범위는 dash 이름 정규화, line arrow 렌더링, path `ArcTo`의 직선 fallback 제거, connector path arrow 처리로 제한했다.

## 산출물

| 파일 | line count | 변경 요약 |
| --- | ---: | --- |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | 2700 | line/path stroke helper, arrow helper, SVG arc-to-cubic 변환 helper를 추가했다. |
| `mydocs/working/task_m050_109_stage2.md` | 신규 | Stage 2 구현, 검증, 잔여 위험을 기록했다. |

작업은 메인 worktree의 브랜치 표시가 `devel-webview`/`local/task147`로 흔들리는 문제가 있어 `/private/tmp/rhwp-mac-task109` 별도 worktree에서 `local/task109`를 고정해 진행했다.

## 구현 내용

| 항목 | 처리 |
| --- | --- |
| dash | `applyDash(_:)` 앞에 dash 이름 정규화를 추가했다. `Dash`, `Dot`, `DashDot`, `DashDotDot` 외에 소문자/하이픈/언더스코어/일부 별칭도 같은 dash로 처리한다. 알 수 없는 값은 기존처럼 solid fallback이다. |
| line arrow | `LineStyle.startArrow/endArrow`와 size를 사용해 직선 시작/끝 화살표를 그린다. WebCanvas/SVG와 같은 size 규칙을 사용하고, 화살표 길이만큼 stroke endpoint를 줄여 선이 화살표 내부로 침범하지 않게 했다. |
| arrow style | `Arrow`, `ConcaveArrow`, `Diamond/OpenDiamond`, `Circle/OpenCircle`, `Square/OpenSquare`를 지원한다. 알 수 없는 arrow style은 그리지 않는 fallback이다. |
| connector path arrow | `PathNode.lineStyle`에 arrow가 있고 `connectorEndpoints`가 있을 때만 path 끝점 화살표를 그린다. 일반 closed path에 오탐으로 arrow가 붙는 것을 피하기 위해 connector endpoint가 없는 path에는 arrow를 적용하지 않았다. |
| path `ArcTo` | 기존 endpoint 직선 fallback을 SVG arc-to-cubic 변환으로 교체했다. 반지름 0은 line fallback, 시작점과 끝점이 같으면 no-op으로 처리한다. |
| path tangent metadata | `buildCGPath`가 path와 함께 first/last point, first/last tangent를 반환하게 해 connector arrow 방향 계산에 사용한다. |

## 보류 / fallback

- `LineStyle.lineType`의 double/triple 계열 stroke는 Stage 2 범위에 포함하지 않았다.
- path arrow는 connector endpoint가 있는 path에만 적용한다.
- line/path shadow는 Stage 3의 fill/shadow 작업으로 남겼다.
- pattern fill, text style 항목은 Stage 3 이후 범위로 유지했다.

## 본문 변경 정도 / 본문 무손실 여부

소스 본문 변경은 `CGTreeRenderer.swift` 1개 파일에 한정했다. `RenderTree.swift`의 ABI/decoding 구조는 변경하지 않았다. 기존 fill/stroke/transform 호출 순서는 유지했고, stroke/path helper 주변에만 보강을 추가했다.

## 검증 결과

| 명령 | 결과 |
| --- | --- |
| `git status --short --branch` | `/private/tmp/rhwp-mac-task109`에서 `local/task109` 확인 |
| `git diff -- Sources/RhwpCoreBridge/CGTreeRenderer.swift Sources/RhwpCoreBridge/RenderTree.swift` | `CGTreeRenderer.swift`만 변경, `RenderTree.swift` 변경 없음 |
| `./scripts/check-no-appkit.sh` | 통과: shared Swift code AppKit/UIKit 직접 의존 없음 |
| `./scripts/build-rust-macos.sh` | 통과. tmp worktree에 `Frameworks/universal/librhwp.a`가 없어 render smoke 전 1회 생성했다. xcodebuild simulator 관련 warning은 있었지만 XCFramework 생성은 성공했다. |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage2-bokhak samples/복학원서.hwp` | 통과. native PNG 794x1123, non-white pixels 261878. qlmanage rasterize 문제로 diff PNG는 생성되지 않음 |
| `./scripts/validate-stage3-render.sh /private/tmp/rhwp-task109-stage2-smoke samples/basic/BookReview.hwp samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp` | 통과. BookReview/KTX/request/exam_kor 모두 PNG 생성 성공 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage2-shape samples/shape-group-02.hwp` | 추가 smoke 통과. 해당 샘플 render tree에는 arrow/ArcTo 직접 항목 없음 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage2-draw samples/draw-group.hwp` | 추가 smoke 통과. 해당 샘플 render tree에는 arrow/ArcTo 직접 항목 없음 |
| `git diff --check` | 통과 |

## 잔여 위험

- 현재 저장소 샘플에서 arrow/ArcTo를 직접 포함한 render tree를 찾지 못해, 해당 기능은 reference 구현 대조와 compile/render smoke로 검증했다. 실제 arrow/arc 문서를 확보하면 시각 비교가 필요하다.
- open arrow 계열은 rhwp-studio/SVG 기준처럼 흰색 fill을 사용한다. 배경이 흰색이 아닌 문서에서는 reference와 같은 방식이지만 native 배경과 겹치는 시각 차이가 있을 수 있다.
- `ArcTo` 변환은 SVG spec 방식으로 보강했지만, 복잡한 path bbox/clip이 걸린 문서는 Stage 3 이후 smoke 확장이 필요하다.
- tmp worktree에서 생성한 `Frameworks/` 산출물은 검증용 생성물이며 커밋 대상이 아니다.

## 다음 단계 영향

Stage 3에서는 shape fill/shadow/pattern으로 넘어간다. 이번 Stage 2가 `ShapeStyle.shadow`를 건드리지 않았으므로, 다음 단계에서 fill/stroke 전후 shadow pass를 추가할 때 arrow/path stroke와 graphics state 경계를 다시 확인해야 한다.

## 승인 요청

Stage 2 구현과 검증을 완료했다. 다음 단계로 `Stage 3. 도형 fill/shadow/pattern style 보강`을 진행하려면 작업지시자 승인이 필요하다.
