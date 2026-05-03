# Task M015 #120 최종 보고서

## 작업 개요

- 이슈: #120 Swift native renderer 텍스트 글자별 위치와 advance 재현 개선
- 마일스톤: M015 (`첫 출시 전 Swift 렌더 보강`)
- 브랜치: `local/task120`
- 핵심 변경: Swift native renderer의 텍스트 drawing을 run 단위 일괄 drawing에서 cluster 위치 계획 기반 drawing으로 보강하고, future core render tree의 `char_positions`를 우선 사용할 수 있도록 optional 계약을 추가
- 기준 샘플: `samples/20250130-hongbo.hwp`, `samples/re-align-center-hancom.hwp`, `samples/re-align-right-hancom.hwp`, `samples/re-align-justify-hancom.hwp`

## 완료 내용

`20250130-hongbo.hwp`에서 제목/날짜 계열 run의 `bbox.width`와 CoreText 조판 폭이 크게 달라 Swift native PNG가 core SVG 위치와 다르게 보이는 문제를 확인했다.

대표 차이는 다음이었다.

```text
id 39 text="2026. 1. 30.(" bbox.width=87.0  CoreTextWidth=72.5333
id 40 text="금)"             bbox.width=20.0  CoreTextWidth=16.08
id 50 text="혹한기 봉화댐 건설 현장점검 ‘안전 온도 높인다’"
      bbox.width=624.0 CoreTextWidth=496.8640
```

이번 작업에서는 CoreText를 버리지 않고 native drawing backend로 유지했다. 대신 run 내부의 cluster별 위치 계획을 만들어 HWP/rhwp core가 산출한 bbox, 자간, 단어/글자 추가 간격, 탭 정보를 더 적극적으로 반영하도록 했다.

구현 내용:

- `CGTreeRenderer.renderTextRun`에 텍스트 배치 계획 helper 추가
- CoreText line width와 render tree bbox width 차이를 계산해 position plan에 반영
- `TextStyle.ratio`, `letterSpacing`, `extraWordSpacing`, `extraCharSpacing` 반영
- 공백/탭/figure space를 drawing 없이 advance만 소비하도록 처리
- `inlineTabs`, `tabStops`, `autoTabRight`, `defaultTabWidth`의 안전한 범위 처리
- 한글 jamo, CJK/fullwidth, 반각 구두점의 fallback advance heuristic 추가
- bbox 보정이 필요한 경우 glyph outline stretch가 아니라 cluster x position scaling을 우선 적용
- 기존 JSON과 호환되는 optional `TextRun.char_positions` decoder 추가
- `char_positions`가 들어오면 Swift fallback 계산보다 우선 사용하고, bbox 기반 position normalization을 적용하지 않도록 처리

## rhwp-studio reference 기준 대응

사용자가 이슈에 추가한 구현 기준에 따라 rhwp-studio의 현재 렌더 결과와 `WebCanvasRenderer`/view 계층을 reference implementation으로 보았다.

이번 구현은 DOM/Canvas/TypeScript 구조를 이식하지 않았다. macOS native renderer로서 CoreGraphics/CoreText drawing 경로를 유지했고, rhwp-studio와 같은 결과를 내기 위해 필요한 입력 계약을 `TextRun.char_positions` optional field로 분리했다.

최종 방향은 다음이다.

- drawing backend: Swift/AppKit 공유 코드 경계에 맞게 CoreGraphics/CoreText 사용
- 위치 기준: Swift가 독자 metric을 최종 기준으로 삼지 않고, core/rhwp-studio가 계산한 글자별 x boundary를 우선 소비
- fallback: `char_positions`가 없는 현재 render tree에서는 Stage 3 Swift fallback advance 계산 사용
- 검증 기준: 동일 sample 문서의 rhwp-studio/core 산출물과 Swift native PNG를 비교

따라서 이번 작업은 “Swift 쪽에 완전히 새 조판 로직을 설계”한 방향이 아니라, 현재 JSON 계약의 한계에서는 Swift fallback을 두되 장기 기준은 rhwp-studio/core의 위치 계산 결과를 native renderer 입력으로 받는 방향이다.

## 변경 파일과 영향 범위

| 파일 | 내용 |
| --- | --- |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | 텍스트 cluster 배치 계획, spacing/tab/fallback advance 계산, `char_positions` 우선 drawing 경로 추가 |
| `Sources/RhwpCoreBridge/RenderTree.swift` | `TextRun.charPositions` optional decode 추가 |
| `mydocs/plans/task_m015_120.md` | Task #120 수행 계획과 승인 요청 사항 기록 |
| `mydocs/plans/task_m015_120_impl.md` | Stage 1-5 구현 계획, 검증 명령, 완료 기준 기록 |
| `mydocs/working/task_m015_120_stage1.md` | 기준 샘플 분석, bbox/CoreText 폭 차이, 계약 한계 정리 |
| `mydocs/working/task_m015_120_stage2.md` | run 배치 계산 보강과 provisional whole-run scale 한계 기록 |
| `mydocs/working/task_m015_120_stage3.md` | cluster drawing 적용 결과와 fallback 정책 기록 |
| `mydocs/working/task_m015_120_stage4.md` | 정렬 샘플 검증과 `char_positions` 계약 판단 기록 |
| `mydocs/working/task_m015_120_stage5.md` | 통합 검증 결과와 최종 보고 준비 상태 기록 |
| `mydocs/report/task_m015_120_report.md` | 최종 작업 결과, 구현 방향, 검증 결과, 잔여 위험 정리 |
| `mydocs/orders/20260502.md` | 오늘할일 #120 완료 상태 기록 |

`Sources/RhwpCoreBridge`에는 AppKit/UIKit/WebKit 직접 의존을 추가하지 않았다.

## 검증 요약

### Stage 1 기준 재현

```text
20250130-hongbo.hwp NativeNonWhitePixels: 84406
re-align-center-hancom.hwp NativeNonWhitePixels: 6559
re-align-right-hancom.hwp NativeNonWhitePixels: 6500
re-align-justify-hancom.hwp NativeNonWhitePixels: 6582
```

Stage 1에서 render tree에는 bbox와 일부 spacing style은 있었지만, rhwp-studio/core가 계산한 글자별 x boundary가 renderer 입력으로 전달되지 않는 한계를 확인했다.

### Stage 3/4 구현 후 샘플 검증

```text
20250130-hongbo.hwp NativeNonWhitePixels: 84306
re-align-center-hancom.hwp NativeNonWhitePixels: 6666
re-align-right-hancom.hwp NativeNonWhitePixels: 6615
re-align-justify-hancom.hwp NativeNonWhitePixels: 6652
```

Stage 2의 provisional whole-run scale은 non-white pixel이 증가했지만 glyph outline까지 늘리는 방식이었다. Stage 3 이후에는 glyph outline을 과도하게 늘리지 않고 cluster 위치를 조정하는 방식으로 바꿨다.

### Stage 5 통합 검증

```text
./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

```text
./scripts/validate-stage3-render.sh
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452397
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=67765
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=176233
```

```text
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task120-final-smoke samples/20250130-hongbo.hwp samples/re-align-center-hancom.hwp samples/re-align-right-hancom.hwp samples/re-align-justify-hancom.hwp
OK 20250130-hongbo.hwp: page=1 size=794x1123 textRuns=60 hangulRuns=35 hangulScalars=535 nonWhitePixels=84306
OK re-align-center-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6666
OK re-align-right-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6615
OK re-align-justify-hancom.hwp: page=1 size=794x1123 textRuns=3 hangulRuns=3 hangulScalars=100 nonWhitePixels=6652
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task120-final samples/20250130-hongbo.hwp
NativePNGSize: 794x1123
NativeNonWhitePixels: 84306
TextRuns: 60
HangulRuns: 35
HangulScalars: 535
MissingHangulGlyphs: 0
```

```text
xcodegen generate
Created project at /tmp/rhwp-mac-task120/AlhangeulMac.xcodeproj
```

```text
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [12.389 sec]
```

`git diff --check`도 통과했다.

## 제한 사항

- core render tree가 아직 `char_positions`를 내보내지 않으므로 현재 샘플에서는 Swift fallback 경로가 사용된다.
- 이번 작업은 PageLayerTree 기본 경로 전환이나 새 renderer 엔진 도입을 하지 않았다.
- proprietary font 번들, 한컴 viewer 직접 비교 자동화, release packaging은 범위가 아니다.
- vertical text, text effects, complex OpenType shaping edge case는 후속 검증 샘플이 필요하다.

## 잔여 위험

- CoreText font fallback과 rhwp-studio/core font metric 차이 때문에 일부 라틴/기호/옛한글 cluster에서 폭이 완전히 같지 않을 수 있다.
- `char_positions` upstream 추가 전까지 Swift fallback은 reference implementation의 근사치다.
- core SVG rasterize는 로컬 `qlmanage` sandbox 오류로 실패해 pixel diff를 생성하지 못했다.
- default smoke에서 `exam_kor.hwp` layout overflow 진단 로그가 출력됐지만 명령은 통과했다. 이번 작업 범위의 텍스트 advance regression으로 보지는 않았다.

## 결론

Issue #120의 Swift native renderer 텍스트 advance 재현 보강은 기준 샘플 범위에서 완료됐다.

현재 macOS native 표준에 가장 가까운 구현은 CoreGraphics/CoreText를 drawing backend로 유지하면서, rhwp-studio/core가 산출한 글자 위치를 renderer 입력 계약으로 받는 hybrid 방향이다. 이번 작업은 그 방향에 맞춰 Swift fallback을 개선하고 `TextRun.char_positions` optional 수용 경로를 준비했다.

HostApp, Quick Look, Thumbnail이 공유하는 renderer 경계 검증과 HostApp Debug build도 통과했다.
