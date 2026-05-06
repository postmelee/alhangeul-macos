# Task M050 #123 최종 보고서

## 작업 개요

- 이슈: #123 Swift native renderer Body clip overflow control 렌더링 보강
- 마일스톤: M050 (`v0.5.0 Viewer 안정화`)
- devel 브랜치: `local/task123`
- devel-webview 브랜치: `local/task123-webview`
- 핵심 변경: Swift native renderer의 `Body.clip_rect` 처리에서 텍스트 clip은 유지하고, body 좌우를 벗어나는 control replay pass와 `TableCell.clip` 우측 여유 폭을 추가
- 영향 경로:
  - `devel`: HostApp native viewer, Quick Look, Thumbnail, PDF/image export
  - `devel-webview`: WKWebView HostApp은 유지하되 Quick Look, Thumbnail, PDF export의 shared native renderer

## 완료 내용

### Body overflow control replay

기존 Swift renderer는 `Body.clip_rect`를 단순 clip으로 적용했다. 이 때문에 rhwp-studio Canvas renderer처럼 텍스트는 본문 영역 안에 유지하면서, 좌우 body 경계를 벗어나는 비-텍스트 control을 다시 그리는 정책이 없었다.

이번 작업에서는 `CGTreeRenderer`에 `renderBody(_:node:in:)` helper를 추가하고 다음 순서로 렌더링한다.

1. body clip 내부에서 기존 children 렌더링
2. body clip 복원
3. body 좌우를 벗어나는 control 후보만 page 폭 기준 clip으로 replay

replay 후보는 다음 계열로 제한했다.

- `Table`
- `Line`
- `Rectangle`
- `Ellipse`
- `Path`
- `Image`
- `Group`
- `TextBox`
- `Equation`
- `FormObject`

다음 계열은 replay 대상에서 제외했다.

- `Page`, `PageBackground`, `MasterPage`
- `Header`, `Footer`, `Body`, `Column`, `FootnoteArea`
- `TextLine`, `TextRun`, `FootnoteMarker`
- `TableCell`, `Unknown`

상하 overflow는 이번 범위에서 확장하지 않았다. `samples/복학원서.hwp` 하단 표 overflow diagnostic은 별도 vertical layout/core overflow 문제로 남긴다.

### TableCell clip 우측 여유

rhwp-studio `ClipKind::TableCell` 기준에 맞춰 `TableCell.clip`의 우측 폭에 `4.0pt` 여유를 추가했다.

- x/y/height는 기존 bbox 유지
- width만 `bbox.width + 4.0`
- 셀 상단/하단/좌측 overflow는 확장하지 않음

### qlmanage raster diff 환경 제한 문서화

Codex sandbox에서 `qlmanage` 기반 Core SVG raster diff가 다음 오류로 실패하는 현상을 `build_run_guide.md`에 문서화했다.

```text
sandbox initialization failed: invalid data type of path filter; expected pattern, got boolean
```

일반 Terminal에서 같은 SVG의 `qlmanage -t -x`가 성공하면 core/native renderer 실패가 아니라 Quick Look sandbox 초기화 실패로 분리한다.

## 변경 파일

### devel

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | Body overflow replay, control whitelist, TableCell 우측 clip 여유 |
| `mydocs/manual/build_run_guide.md` | Codex sandbox의 `qlmanage` raster diff 실패 원인과 판단 기준 문서화 |
| `mydocs/orders/20260505.md` | #123 완료 상태 갱신 |
| `mydocs/plans/task_m050_123.md` | 수행 계획 |
| `mydocs/plans/task_m050_123_impl.md` | 6단계 구현 계획 |
| `mydocs/working/task_m050_123_stage1.md` | rhwp-studio 기준과 Swift 현행 구조 조사 |
| `mydocs/working/task_m050_123_stage2.md` | Body overflow replay 구조 추가 |
| `mydocs/working/task_m050_123_stage3.md` | replay 대상 control whitelist 보강 |
| `mydocs/working/task_m050_123_stage4.md` | TableCell clip 정책 보강 |
| `mydocs/working/task_m050_123_stage5.md` | devel 기준 통합 검증 |
| `mydocs/working/task_m050_123_stage6.md` | devel-webview 선별 적용과 양쪽 브랜치 정리 |
| `mydocs/report/task_m050_123_report.md` | 최종 보고서 |

### devel-webview

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | devel과 같은 native renderer clip 정책을 `devel-webview` font/WKWebView 변경을 보존한 상태로 선별 적용 |

## 검증 요약

### devel

```text
./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

```text
./scripts/validate-stage3-render.sh
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452179
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=67667
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=182000
```

```text
./scripts/render-debug-compare.sh /private/tmp/rhwp-task123-stage5-bokhak samples/복학원서.hwp
OK 복학원서.hwp
NativePNGSize: 794x1123
NativeNonWhitePixels: 261878
MissingHangulGlyphs: 0
DiffReason: qlmanage rasterize failed
```

```text
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [12.242 sec]
```

### devel-webview

```text
./scripts/check-no-appkit.sh
OK: shared Swift code has no AppKit/UIKit dependencies
```

```text
./scripts/validate-stage3-render.sh
OK KTX.hwp: page=1 size=1123x794 textRuns=436 hangulRuns=76 hangulScalars=209 nonWhitePixels=452141
OK request.hwp: page=1 size=567x794 textRuns=104 hangulRuns=36 hangulScalars=309 nonWhitePixels=67892
OK exam_kor.hwp: page=1 size=1123x1588 textRuns=133 hangulRuns=86 hangulScalars=1368 nonWhitePixels=175781
```

```text
./scripts/validate-stage3-render.sh /private/tmp/rhwp-task123-webview-smoke samples/basic/KTX.hwp samples/basic/request.hwp samples/exam_kor.hwp
OK KTX.hwp: nonWhitePixels=452141
OK request.hwp: nonWhitePixels=67892
OK exam_kor.hwp: nonWhitePixels=175781
```

```text
xcodebuild -project AlhangeulMac.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData CODE_SIGNING_ALLOWED=NO build
** BUILD SUCCEEDED ** [13.213 sec]
```

## Before/After 확인

사용자 확인용으로 before/after native PNG와 diff overlay를 생성했다. 이미지는 저장소에 커밋하지 않았다.

- before: `/private/tmp/rhwp-task123-compare-before`
- after: `/private/tmp/rhwp-task123-compare-after`
- diff overlay: `/private/tmp/rhwp-task123-compare-diff`

비교 결과:

- `img-start-001`: 135px 변경
- `table-004`: 142px 변경
- `table-vpos-01`: 35px 변경
- `복학원서`: pixel-identical

이번 repository 샘플 page 1 기준에서는 body 좌우 overflow replay가 눈에 띄게 드러나는 샘플은 확인하지 못했다. 현재 차이는 주로 TableCell 우측 4pt 여유에 따른 edge/anti-aliasing 수준이다.

## 제한 사항

- 세로 overflow는 다루지 않는다. `복학원서.hwp` 하단 표 overflow와 `KTX.hwp` layout overflow diagnostic은 별도 core/layout 이슈로 유지한다.
- replay 후보 탐색은 body 직계 child와 column 직계 child 기준이다. 더 깊은 nested 구조의 좌우 overflow control은 후속 보강이 필요할 수 있다.
- group/table/textBox replay는 children 재렌더링을 동반하므로 문서별 z-order와 중복 drawing 리스크가 남는다.
- Codex sandbox 안에서는 `qlmanage` 기반 Core SVG raster diff가 실패할 수 있다.

## PR 게시 전략

대상 브랜치가 둘이라 게시 브랜치를 분리해야 한다.

- `publish/task123-devel` -> `devel`
- `publish/task123-webview` -> `devel-webview`

기본 브랜치명 `publish/task123` 하나로는 두 대상 PR을 동시에 유지할 수 없다.

## 결론

Issue #123의 목표였던 Swift native renderer Body clip overflow control 렌더링 보강은 `devel`과 `devel-webview` 양쪽에 적용 가능한 상태까지 완료됐다.

`devel`에서는 HostApp native viewer와 Quick Look/Thumbnail 공통 renderer 검증이 통과했고, `devel-webview`에서는 WKWebView HostApp 구조를 보존한 채 Quick Look/Thumbnail/PDF export가 사용하는 shared native renderer 경로 검증이 통과했다.
