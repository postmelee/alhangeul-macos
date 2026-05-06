# Task M050 #109 Stage 4 보고서

## 단계 목적

텍스트 저위험 style parity를 보강했다. Stage 4 범위는 `TextStyle`의 shadow, superscript/subscript, emphasis dot, tab leader 처리이며, 기존 Core Text 기반 글자 배치와 glyph cluster 보정 경로를 유지하는 선에서 구현했다.

## 산출물

| 파일 | line count | 변경 요약 |
| --- | ---: | --- |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | 3050 | text shadow, 위첨자/아래첨자, 강조점, 탭 리더 draw helper를 추가했다. |
| `mydocs/working/task_m050_109_stage4.md` | 신규 | Stage 4 구현, 검증, 직접 비교 방법을 기록했다. |

## 구현 내용

| 항목 | 처리 |
| --- | --- |
| text shadow | `TextStyle.shadowType > 0`이면 shadow color/offset으로 같은 text run을 먼저 그린 뒤 본문을 그린다. 기존 Core Text line/cluster/scaled-line 전략을 shadow pass에도 동일하게 적용한다. |
| superscript/subscript | style flag에 따라 font size를 70%로 줄이고 baseline을 위/아래로 이동한다. underline/strike 위치도 baseline shift를 반영해 보정했다. |
| emphasis dot | `emphasisDot` 값 1-6을 dot glyph로 매핑하고, glyph cluster 위치 기준으로 본문 위에 작은 강조점을 그린다. cluster fallback과 scaled-line 전략에서도 위치가 맞도록 UTF-16 offset을 보존했다. |
| tab leader | `tabLeaders`의 `fillType` 1-11을 solid/dash/dot/dash-dot/double/triple line 형태로 근사해 그린다. leader drawing state는 별도 save/restore 경계로 제한했다. |
| graphics state | text bbox 내부 Core Text 좌표계 변환 안에서 shadow, leader, main text, emphasis dot 순서로 그리며, outer state와 decoration state를 분리했다. |

## 보류 / fallback

- outline, emboss, engrave 등 장식형 text effect는 이번 Stage 4 범위에 포함하지 않았다.
- 위첨자/아래첨자는 render tree가 run 단위 style을 제공할 때만 적용된다. 한 run 내부 일부 글자만 다른 style인 경우는 upstream render tree 분할 결과에 의존한다.
- emphasis dot의 정확한 glyph, 크기, y 위치는 Core Text 기준 근사다. HWP/Canvas와 픽셀 단위로 완전히 같지 않을 수 있다.
- tab leader fill type은 문서 판독성을 우선한 CoreGraphics 근사다. HWP 원본의 선 간격과 굵기는 추가 fixture 확보 후 조정 여지가 있다.
- upstream/repo 공용 fixture 생성은 이번 #109 Stage 4 커밋에 포함하지 않고, 별도 GitHub Issue로 등록해 진행한다.

## 직접 비교 방법

저장소 후보 샘플에서는 Stage 4 대상 style을 모두 포함한 실제 문서를 확인하지 못해, renderer 경로만 검증할 수 있는 synthetic render tree before/after PNG를 생성했다.

| 구분 | 파일 |
| --- | --- |
| Stage 4 적용 전 | `/private/tmp/rhwp-task109-stage4-visual/stage4-before.png` |
| Stage 4 적용 후 | `/private/tmp/rhwp-task109-stage4-visual/stage4-after.png` |

작업지시자가 직접 확인할 때는 두 PNG를 나란히 열고 다음을 보면 된다.

- `Shadow`: after에서 회색 offset shadow가 글자 뒤에 보여야 한다.
- `H2O`: after에서 run 전체가 작아지고 baseline이 위로 이동해야 한다.
- `Dot`: after에서 각 글자 위에 강조점이 보여야 한다.
- `A B`: after에서 A와 B 사이에 dotted tab leader가 보여야 한다.

실제 HWP/HWPX 문서로 비교하려면 text shadow, 위첨자/아래첨자, 강조점, 탭 리더 중 하나 이상이 들어간 문서를 준비한 뒤, Stage 3 commit `3c99128` 기준 PNG와 현재 Stage 4 PNG를 각각 `render-debug-compare.sh`로 생성해 native PNG를 나란히 비교한다.

## 본문 변경 정도 / 본문 무손실 여부

소스 변경은 `CGTreeRenderer.swift`에 한정했다. `RenderTree.swift`, Rust bridge, Xcode project, resource는 변경하지 않았다. 기존 글자 fallback, cluster spacing, punctuation scaling, underline/strike drawing은 유지하고 Stage 4 style만 추가 pass/helper로 연결했다.

## 검증 결과

| 명령 | 결과 |
| --- | --- |
| `git status --short --branch` | `/private/tmp/rhwp-mac-task109`에서 `local/task109` 확인 |
| `git diff --check` | 통과 |
| `./scripts/check-no-appkit.sh` | 통과: shared Swift code AppKit/UIKit 직접 의존 없음 |
| `swiftc -parse-as-library ... CGTreeRenderer.swift ... synthetic_stage4_render.swift ...` | 통과: Stage 4 synthetic renderer 컴파일 성공 |
| `/private/tmp/rhwp-task109-stage4-visual/synthetic_stage4_render_after /private/tmp/rhwp-task109-stage4-visual/stage4-after.png` | 통과: after PNG 생성 성공 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage4-bokhak samples/복학원서.hwp` | 통과. render tree/core SVG/native PNG/summary 생성 성공 |
| `./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-stage4-hongbo samples/20250130-hongbo.hwp` | 통과. render tree/core SVG/native PNG/summary 생성 성공 |
| `./scripts/validate-stage3-render.sh /private/tmp/rhwp-task109-stage4-smoke samples/basic/BookReview.hwp samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp` | 통과. BookReview/KTX/request/exam_kor 모두 PNG 생성 성공 |

## 잔여 위험

- 실제 Stage 4 style 포함 문서 기반 before/after 비교가 아직 없다. 사용자가 해당 문서를 제공하거나 공용 fixture 이슈에서 샘플을 만들면 다시 검증해야 한다.
- shadow, emphasis dot, tab leader는 WebCanvas와 CoreGraphics의 rasterization 차이로 픽셀 단위 완전 일치는 기대하지 않는다.
- tab leader가 run bbox 밖까지 이어지는 복잡한 tab stop 조합은 실제 문서 fixture로 추가 확인이 필요하다.

## 다음 단계 영향

Stage 5에서는 text rotation/vertical 등 좌표계 영향이 큰 style을 다룬다. Stage 4에서 추가한 text pass helper는 bbox 내부 Core Text 좌표계를 공유하므로, Stage 5에서는 회전/세로쓰기 변환 순서와 decoration 위치를 함께 재점검해야 한다.

## 승인 요청

Stage 4 구현과 검증을 완료했다. 다음 단계로 `Stage 5. 텍스트 고위험 layout style 보강`을 진행하려면 작업지시자 승인이 필요하다.
