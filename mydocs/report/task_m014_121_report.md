# Task M014 #121 최종 보고서

## 작업 요약

| 항목 | 값 |
|------|----|
| 이슈 | [#121 Swift native renderer RawSvg/OLE·차트 리소스 렌더링 보강](https://github.com/postmelee/alhangeul-macos/issues/121) |
| 마일스톤 | M014 |
| 브랜치 | `local/task121` |
| 기준 브랜치 | `devel` |
| core/studio 기준 | `edwardkim/rhwp v0.7.13`, `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| 단계 | Stage 1 조사, Stage 2 정책 설계, Stage 3 구현, Stage 4 검증, Stage 5 최종 보고 |

이번 작업은 Swift/CoreGraphics native renderer가 upstream render tree의 `RawSvg`와 `Placeholder` node를 `.unknown`으로 흡수하지 않고, 지원 가능한 payload는 표시하며 지원 불가 payload는 명확한 fallback으로 남기도록 보강했다.

실제 repository sample에서는 RawSvg positive fixture를 찾지 못했으므로 RawSvg는 upstream contract와 synthetic JSON으로 검증했다. 작업 중 제공받은 `143E433F503322BD33.hwp`는 RawSvg가 아니라 OLE/chart-like object가 `Placeholder`로 내려오는 fixture로 확인되어 Placeholder 렌더링까지 포함했다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/RenderTree.swift` | `RawSvg`와 `Placeholder` render node case 및 payload model decode 추가 |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | RawSvg 단일 data image draw, 복합 SVG fallback, Placeholder dashed box/label 렌더링 추가 |
| `mydocs/plans/task_m014_121.md` | 수행계획서 작성 |
| `mydocs/plans/task_m014_121_impl.md` | 구현계획서 작성 |
| `mydocs/working/task_m014_121_stage1.md` | RawSvg current path, sample baseline, visual diff readiness timeout 기록 |
| `mydocs/working/task_m014_121_stage2.md` | upstream RawSvg contract와 Swift fallback 정책 정리 |
| `mydocs/working/task_m014_121_stage3.md` | 구현 내용, synthetic smoke, Placeholder fixture 분석, build/policy check 기록 |
| `mydocs/working/task_m014_121_stage4.md` | target/regression visual diff metric, render-debug 재측정, 수용 기준 점검 기록 |
| `mydocs/orders/20260602.md` | #121 오늘할일 상태를 완료로 갱신 |

## 변경 전·후 정량 비교

최종 보고서 작성 직전 `devel..local/task121` 기준:

| 항목 | 값 |
|------|---:|
| 변경 파일 | `9` |
| 추가 라인 | `1569` |
| Swift 소스 변경 파일 | `2` |
| 작업/계획 보고 문서 | `6` |
| Stage 4 visual diff target OK | `2/2` |
| Stage 4 visual diff regression OK | `6/6` |
| Stage 4 render-debug OK | `3/3` |

Stage 3 전후 제공 fixture native non-white pixel:

| 파일 | Stage 3 전 | Stage 3 후 |
|------|-----------:|-----------:|
| `143E433F503322BD33.hwp` page 1 | `105571` | `136906` |

증가분은 OLE Placeholder box와 `OLE 개체 (BinData #2)` label이 표시되면서 생긴 사용자-facing non-blank 개선이다.

## Visual Diff 결과

Stage 4에서 visual diff harness를 sandbox 내부와 sandbox 밖에서 각각 실행했다.

- sandbox 내부: Stage 1과 같은 readiness timeout 재현
- sandbox 밖: target set과 regression set 모두 OK

Target set:

| 파일 | Status | ChangedPixels | ChangedPercent | MeanRGBDelta |
|------|--------|--------------:|---------------:|-------------:|
| `draw-group.hwp` | OK | `28960/3561228` | `0.8132%` | `0.4881` |
| `eq-01.hwp` | OK | `230538/3562815` | `6.4707%` | `5.9354` |

Regression set:

| 파일 | Status | ChangedPixels | ChangedPercent | MeanRGBDelta |
|------|--------|--------------:|---------------:|-------------:|
| `request.hwp` | OK | `321284/1798071` | `17.8683%` | `10.9606` |
| `복학원서.hwp` | OK | `257941/3562815` | `7.2398%` | `6.7272` |
| `pic-crop-01.hwp` | OK | `72763/3562815` | `2.0423%` | `0.8092` |
| `form-01.hwp` | OK | `28739/3562815` | `0.8066%` | `0.4843` |
| `form-002.hwpx` | OK | `543087/3561228` | `15.2500%` | `17.3362` |
| `hwpx-01.hwpx` | OK | `505312/3562815` | `14.1829%` | `15.1348` |

## 검증 결과

| 수용 기준 / 명령 | 결과 | 비고 |
|------------------|------|------|
| RawSvg node가 Swift model에서 식별된다 | OK | synthetic RenderTree JSON decode/render smoke |
| 지원 가능한 RawSvg data image가 bbox 안에 표시된다 | OK | synthetic red PNG data image smoke |
| 표시 불가 RawSvg payload가 fallback으로 보인다 | OK | synthetic complex SVG fallback smoke |
| OLE Placeholder가 표시된다 | OK | `143E433F503322BD33.hwp` page 1 native PNG |
| `./scripts/render-debug-compare.sh ... samples/draw-group.hwp samples/eq-01.hwp` | OK | native PNG와 summary 생성 |
| `./scripts/render-debug-compare.sh ... 143E433F503322BD33.hwp` | OK | Placeholder fixture 확인 |
| `./scripts/preview-visual-diff-harness.sh ... target` | OK | sandbox 밖 실행, `2/2` OK |
| `./scripts/preview-visual-diff-harness.sh ... regression` | OK | sandbox 밖 실행, `6/6` OK |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData-task121 CODE_SIGNING_ALLOWED=NO build` | OK | sandbox 내부 cache 권한 실패 후 sandbox 밖 재시도에서 `** BUILD SUCCEEDED **` |
| `git diff --check` | OK | 공백/patch 문제 없음 |
| `./scripts/check-no-appkit.sh` | OK | `RhwpCoreBridge` AppKit/UIKit 의존 없음 |
| `./scripts/check-extension-registration-hygiene.sh --check-only` | OK | Issues 없음 |

optional core SVG raster diff는 일부 render-debug에서 `qlmanage rasterize failed`로 생성되지 않았다. 이는 Stage 1부터 반복된 local `qlmanage` rasterize 한계이며 native renderer PNG 생성과 visual diff harness 결과와는 분리한다.

## 잔여 위험과 후속 작업

| 항목 | 판단 |
|------|------|
| 실제 RawSvg positive fixture 부재 | RawSvg는 synthetic smoke와 upstream contract 기반으로 검증했다. 실물 fixture 확보 시 추가 회귀 검증이 필요하다. |
| 복합 SVG chart/EMF rasterize | 현재는 CoreGraphics bridge 안에서 직접 rasterize하지 않고 `SVG` fallback으로 표시한다. |
| `143E433F503322BD33.hwp` chart 복원 | mac renderer가 아니라 upstream core의 OLE/BinData 해석 문제로 분리했다. upstream 이슈 [edwardkim/rhwp#1251](https://github.com/edwardkim/rhwp/issues/1251)을 생성했다. |
| visual diff harness sandbox readiness | sandbox 밖에서는 통과한다. harness 안정화는 별도 작업으로 분리하는 편이 맞다. |
| `qlmanage` SVG raster diff | optional debug diff 한계로 남아 있다. |

후속 후보:

- RawSvg positive HWP/HWPX fixture 확보 후 실물 fixture 기반 회귀 테스트 추가
- 복합 SVG chart/EMF raster backend 도입 여부 검토
- visual diff harness의 sandbox/WebKit readiness 안정화
- upstream `edwardkim/rhwp#1251` 결과가 나오면 core pin 갱신 또는 renderer 정책 재검토

## 작업지시자 승인 요청

이 보고서와 오늘할일 완료 처리를 커밋한 뒤 `publish/task121`로 push하고, `devel` 대상 PR을 생성한다.
