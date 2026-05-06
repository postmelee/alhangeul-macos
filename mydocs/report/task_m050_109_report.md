# Task M050 #109 최종 보고서

## 작업 개요

- 이슈: [#109 Swift native renderer 도형·텍스트 스타일 1차 parity 보강](https://github.com/postmelee/alhangeul-macos/issues/109)
- 마일스톤: M050 (`v0.5.0 Viewer 안정화`)
- 브랜치: `local/task109`
- 기준 통합 브랜치: `devel`
- 단계 수: Stage 1-6
- 핵심 변경: `CGTreeRenderer`가 render tree의 도형·텍스트 style 필드를 더 충실히 소비하도록 보강

## 완료 내용

이번 작업은 rhwp-studio/core renderer가 이미 표현하는 style 중 Swift native renderer에서 누락되던 1차 parity 항목을 보강했다. 도형 계열은 stroke/path/fill/shadow를, 텍스트 계열은 shadow, 위첨자/아래첨자, 강조점, 탭 리더, rotation/vertical run을 단계별로 나눠 처리했다.

HostApp native viewer(`devel`), Quick Look preview, Thumbnail extension은 모두 `CGTreeRenderer`를 공유하므로 같은 개선을 받는다. `devel-webview` HostApp 문서 화면은 WKWebView/rhwp-studio 기반이라 직접 영향은 없지만, 해당 브랜치의 Quick Look/Thumbnail에는 백포트 시 개선이 된다.

## 변경 파일과 영향 범위

| 파일 | 내용 |
| --- | --- |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | dash/arrow/arcTo, pattern/shadow, text style, rotation/vertical text drawing 보강 |
| `mydocs/plans/task_m050_109.md` | 수행 계획과 `devel-webview` 영향 판단 기록 |
| `mydocs/plans/task_m050_109_impl.md` | Stage 1-6 구현 계획과 검증 기준 기록 |
| `mydocs/working/task_m050_109_stage1.md` | rhwp-studio 기준 style 처리 현황 조사 |
| `mydocs/working/task_m050_109_stage2.md` | 도형 stroke/path style 구현 결과 |
| `mydocs/working/task_m050_109_stage3.md` | 도형 fill/shadow/pattern 구현 결과 |
| `mydocs/working/task_m050_109_stage4.md` | 텍스트 저위험 style 구현 결과 |
| `mydocs/working/task_m050_109_stage5.md` | 텍스트 rotation/vertical text 판단과 구현 결과 |
| `mydocs/working/task_m050_109_stage6.md` | 통합 검증 결과와 지원/fallback 요약 |
| `mydocs/report/task_m050_109_report.md` | 최종 결과, 검증, 잔여 위험 정리 |
| `mydocs/orders/20260506.md` | 오늘할일 #109 완료 상태 기록 |

`Sources/RhwpCoreBridge`에는 AppKit/UIKit/WebKit 직접 의존을 추가하지 않았다.

## Stage별 결과

| Stage | 결과 |
| --- | --- |
| Stage 1 | rhwp-studio/core 기준 style 항목과 Swift 누락 지점을 조사하고, `devel-webview` HostApp 직접 영향 없음과 Quick Look/Thumbnail 백포트 영향 가능성을 분리했다. |
| Stage 2 | line/path dash alias, arrow head, `PathCommand.arcTo` cubic conversion을 추가했다. |
| Stage 3 | shape/line/path shadow와 pattern fill type 0-5 hatch/cross 근사를 추가했다. |
| Stage 4 | text shadow, superscript/subscript, emphasis dot, tab leader fill type 1-11 근사를 추가했다. |
| Stage 5 | `TextRunNode.rotation` bbox 중심 회전과 `isVertical` run 중심 정렬 경로를 추가했다. |
| Stage 6 | renderer smoke, `xcodegen generate`, HostApp Debug build를 통합 검증했다. |

## 검증 요약

```text
./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

```text
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task109-final-smoke \
  samples/basic/BookReview.hwp samples/basic/KTX.hwp \
  samples/basic/request.hwp samples/exam_kor.hwp
OK BookReview.hwp: page=1 size=794x1123 textRuns=66 hangulRuns=28 hangulScalars=209 nonWhitePixels=386919
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=454823
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=67667
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=182000
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-final-bokhak samples/복학원서.hwp
NativePNGSize: 794x1123
NativeNonWhitePixels: 261878
TextRuns: 102
HangulRuns: 25
MissingHangulGlyphs: 0
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task109-final-hongbo samples/20250130-hongbo.hwp
NativePNGSize: 794x1123
NativeNonWhitePixels: 91412
TextRuns: 60
HangulRuns: 35
MissingHangulGlyphs: 0
```

```text
xcodegen generate
Created project at /tmp/rhwp-mac-task109/AlhangeulMac.xcodeproj
```

```text
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp \
  -configuration Debug -derivedDataPath build.noindex/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [14.146 sec]
```

`git diff --check`도 통과했다.

## 직접 비교 산출물

실제 저장소 후보 샘플에는 일부 style fixture가 부족해 synthetic render tree before/after PNG를 함께 생성했다.

| 단계 | Before | After | 확인 포인트 |
| --- | --- | --- | --- |
| Stage 3 | `/private/tmp/rhwp-task109-stage3-visual/stage3-before.png` | `/private/tmp/rhwp-task109-stage3-visual/stage3-after.png` | pattern fill, shape/line shadow |
| Stage 4 | `/private/tmp/rhwp-task109-stage4-visual/stage4-before.png` | `/private/tmp/rhwp-task109-stage4-visual/stage4-after.png` | text shadow, 위첨자, 강조점, tab leader |
| Stage 5 | `/private/tmp/rhwp-task109-stage5-visual/stage5-before.png` | `/private/tmp/rhwp-task109-stage5-visual/stage5-after.png` | text rotation, vertical run 중심 정렬 |

## 제한 사항

- WebCanvas/SVG와 CoreGraphics/CoreText의 rasterization 차이 때문에 픽셀 단위 완전 일치는 보장하지 않는다.
- pattern spacing, shadow blur, emphasis dot 위치, tab leader 굵기는 1차 근사다.
- rotated/vertical text의 underline, strike, tab leader는 실제 fixture 확보 후 추가 조정이 필요하다.
- Swift renderer는 vertical text layout을 새로 계산하지 않고 upstream render tree가 제공하는 문자 단위 `TextRun`과 `rotation`을 소비한다.
- core SVG rasterize는 로컬 `qlmanage` sandbox 오류로 실패해 pixel diff를 생성하지 못했다.

## 후속 작업

- upstream/repo 공용 style fixture를 별도 GitHub Issue로 등록한다.
- fixture 후보에는 pattern/shadow 도형, text shadow, emphasis dot, tab leader, rotation, vertical text를 포함한다.
- `devel-webview` Quick Look/Thumbnail 개선을 위해 이번 renderer 변경을 별도 백포트 PR로 게시한다.

## 결론

Issue #109의 Swift native renderer 도형·텍스트 style 1차 parity 보강은 `devel` 기준으로 완료됐다. HostApp native viewer, Quick Look, Thumbnail이 공유하는 renderer compile/link 검증과 대표 render smoke도 통과했다.

이 최종 보고서 기준으로 `devel` 대상 PR 게시와, 별도 `devel-webview` 백포트 PR 게시를 진행한다.
