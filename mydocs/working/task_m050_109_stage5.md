# Task M050 #109 Stage 5 보고서

## 단계 목적

텍스트 rotation/vertical text style을 보강했다. Stage 5 범위는 `TextRunNode.rotation`과 `isVertical`이며, 기존 수평 text baseline/cluster drawing 경로를 건드리지 않고 transform이 필요한 run만 별도 중심 정렬 경로로 분기했다.

## 산출물

| 파일 | line count | 변경 요약 |
| --- | ---: | --- |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | 3192 | rotation/isVertical text run 전용 중심 정렬 draw helper와 bbox 중심 회전 helper를 추가했다. |
| `mydocs/working/task_m050_109_stage5.md` | 신규 | Stage 5 구현, 검증, 직접 비교 방법을 기록했다. |

## 구현 내용

| 항목 | 처리 |
| --- | --- |
| text rotation | `TextRunNode.rotation`이 0이 아니면 bbox 중심으로 CGContext를 회전한 뒤 text run을 bbox 중앙에 그린다. rhwp-studio/WebCanvas의 중심 기준 회전 모델을 따른다. |
| vertical text | `isVertical == true`이면 rotation이 없더라도 run bbox 중앙 기준으로 그린다. upstream layout은 세로쓰기 문자를 문자 단위 `TextRun`으로 분리하고, 회전이 필요한 영문/기호는 `rotation=90`, `is_vertical=true`로 내려준다. |
| 기존 수평 text 보호 | rotation이 0이고 `isVertical == false`인 일반 run은 Stage 4까지의 기존 경로를 그대로 사용한다. |
| shadow/emphasis dot | 중심 정렬 경로에서도 Stage 4의 text shadow와 emphasis dot pass를 적용한다. |
| width 계산 | Core Text typographic width와 cluster/scaled-line 전략을 고려해 centered text x 좌표를 계산한다. |

## 보류 / fallback

- rotated/vertical run의 underline, strike, tab leader는 이번 단계에서 별도 회전 drawing으로 옮기지 않았다. 실제 fixture를 확보한 뒤 draw order와 좌표를 따로 조정해야 한다.
- 여러 글자가 한 `isVertical` run에 들어오는 경우는 vertical stack을 Swift에서 새로 만들지 않는다. 현재 upstream render tree 계약은 문자 단위 분리이므로, Swift가 layout을 재해석하지 않는다.
- vertical form substitute, CJK/영문 text direction 판단은 upstream layout의 결과를 소비한다. Swift native renderer가 독자적으로 대체 문자를 만들지 않는다.
- 저장소 후보 샘플에서 non-zero text rotation 또는 `is_vertical: true`를 포함한 실제 render tree를 확인하지 못했다. 공용 fixture 생성은 이번 #109 커밋에 포함하지 않고 별도 GitHub Issue로 등록한다.

## 직접 비교 방법

저장소 후보 샘플에서는 Stage 5 대상 style이 실제로 들어간 문서를 확인하지 못해, renderer 경로만 검증할 수 있는 synthetic render tree before/after PNG를 생성했다.

| 구분 | 파일 |
| --- | --- |
| Stage 5 적용 전 | `/private/tmp/rhwp-task109-stage5-visual/stage5-before.png` |
| Stage 5 적용 후 | `/private/tmp/rhwp-task109-stage5-visual/stage5-after.png` |

작업지시자가 직접 확인할 때는 두 PNG를 나란히 열고 다음을 보면 된다.

- `Rotate`: before에서는 수평으로 그려지고, after에서는 bbox 중심 기준으로 회전해야 한다.
- 세로 칸의 `한`: after에서 glyph가 bbox 중앙에 맞아야 한다.
- 세로 칸의 `A`와 `.`: before에서는 수평이고, after에서는 `rotation=90`에 따라 회전해야 한다.
- `Base`: rotation/isVertical이 없는 일반 수평 text는 before/after 위치가 유지되어야 한다.

실제 HWP/HWPX 문서로 비교하려면 text rotation 또는 세로쓰기 셀/글상자가 들어간 문서를 준비한 뒤, Stage 4 commit `d568dd7` 기준 PNG와 현재 Stage 5 PNG를 각각 `render-debug-compare.sh`로 생성해 native PNG를 나란히 비교한다.

## 본문 변경 정도 / 본문 무손실 여부

소스 변경은 `CGTreeRenderer.swift`에 한정했다. `RenderTree.swift`, Rust bridge, Xcode project, resource는 변경하지 않았다. 일반 수평 text run은 기존 코드 경로를 그대로 타며, rotation 또는 `isVertical`이 있는 run만 `renderCenteredTextRun`으로 분기한다.

## 검증 결과

| 명령 | 결과 |
| --- | --- |
| `git status --short --branch` | `/private/tmp/rhwp-mac-task109`에서 `local/task109` 확인 |
| `git diff --check` | 통과 |
| `./scripts/check-no-appkit.sh` | 통과: shared Swift code AppKit/UIKit 직접 의존 없음 |
| `swiftc -parse-as-library ... CGTreeRenderer.swift ... synthetic_stage5_render.swift ...` | 통과: Stage 5 synthetic renderer 컴파일 성공 |
| `/private/tmp/rhwp-task109-stage5-visual/synthetic_stage5_render_before .../stage5-before.png` | 통과: before PNG 생성 성공 |
| `/private/tmp/rhwp-task109-stage5-visual/synthetic_stage5_render_after .../stage5-after.png` | 통과: after PNG 생성 성공 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage5-bokhak samples/복학원서.hwp` | 통과. render tree/core SVG/native PNG/summary 생성 성공 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage5-hongbo samples/20250130-hongbo.hwp` | 통과. render tree/core SVG/native PNG/summary 생성 성공 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage5-tablevpos samples/table-vpos-01.hwp` | 통과. render tree/core SVG/native PNG/summary 생성 성공 |
| `./scripts/validate-stage3-render.sh /private/tmp/rhwp-task109-stage5-smoke samples/basic/BookReview.hwp samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp` | 통과. BookReview/KTX/request/exam_kor 모두 PNG 생성 성공 |
| `rg -n '"is_vertical": true' ...stage5-* -g '*render-tree.json'` | 확인한 실제 샘플 render tree에서는 대상 항목 미검출 |
| `rg -n --pcre2 '"rotation":\s*(?!0\.0|null)[0-9-]' ...stage5-* -g '*render-tree.json'` | 확인한 실제 샘플 render tree에서는 대상 항목 미검출 |

## 잔여 위험

- 실제 rotation/vertical 문서 기반 시각 비교가 아직 없다. fixture 확보 후 before/after PNG로 다시 확인해야 한다.
- rotated/vertical decoration은 제한 구현이다. underline/strike/tab leader가 포함된 회전 텍스트는 후속 fixture로 판단해야 한다.
- CoreGraphics 회전/폰트 rasterization은 WebCanvas/SVG와 픽셀 단위로 완전히 같지 않을 수 있다.

## 다음 단계 영향

Stage 6에서는 전체 renderer style 변경을 통합 검증한다. 특히 HostApp Debug build와 대표 render smoke를 다시 돌리고, Stage 1-5의 지원/fallback 항목과 `devel-webview` 백포트 영향 여부를 최종 보고서에 넘길 형태로 정리해야 한다.

## 승인 요청

Stage 5 구현과 검증을 완료했다. 다음 단계로 `Stage 6. 통합 검증과 결과 정리`를 진행하려면 작업지시자 승인이 필요하다.
