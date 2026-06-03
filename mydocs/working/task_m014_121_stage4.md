# Task M014 #121 Stage 4 완료보고서

## 개요

Stage 4에서는 Stage 3 구현을 기준으로 visual diff harness, render-debug, build/policy smoke를 다시 실행해 RawSvg/Placeholder renderer 보강이 기존 target sample과 M014 공통 sample set에 회귀를 만들지 않는지 확인했다.

소스 코드는 변경하지 않았고, 검증 산출물과 관찰값만 정리했다.

## 기준

| 항목 | 값 |
|------|----|
| 이슈 | #121 Swift native renderer RawSvg/OLE·차트 리소스 렌더링 보강 |
| 브랜치 | `local/task121` |
| 기준 브랜치 | `origin/devel` `1b767bd` |
| core/studio 기준 | `edwardkim/rhwp v0.7.13`, `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| Stage 3 커밋 | `b0c2e74` |
| 구현계획서 | `mydocs/plans/task_m014_121_impl.md` |

## Visual Diff Harness

계획서의 target set과 regression set을 먼저 sandbox 내부에서 실행했다. 두 실행 모두 Stage 1과 같은 readiness timeout을 재현했다.

```text
[phase:readiness] rhwp-studio page 1 readiness timed out: navigation=pending; events=[]; scheme={resourceRequests=0, documentRequests=0}
```

같은 명령을 sandbox 밖에서 재시도하자 target set과 regression set 모두 정상적으로 studio/native/diff PNG와 summary를 생성했다. 따라서 이번 실패는 renderer 회귀가 아니라 local sandbox/WebKit readiness 제한으로 분리한다.

### Target set

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task121-stage4-target-escalated --page 1 \
  samples/draw-group.hwp samples/eq-01.hwp
```

결과:

| 파일 | Status | ChangedPixels | ChangedPercent | MeanRGBDelta | NativeMs | 비고 |
|------|--------|--------------:|---------------:|-------------:|---------:|------|
| `draw-group.hwp` | OK | `28960/3561228` | `0.8132%` | `0.4881` | `1056.6` | 기존 image/group sample |
| `eq-01.hwp` | OK | `230538/3562815` | `6.4707%` | `5.9354` | `19.0` | equation sample |

산출물:

```text
build.noindex/task121-stage4-target-escalated/summary.md
build.noindex/task121-stage4-target-escalated/studio/
build.noindex/task121-stage4-target-escalated/native/
build.noindex/task121-stage4-target-escalated/diff/
```

### Regression set

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task121-stage4-regression-escalated --page 1 \
  samples/basic/request.hwp samples/복학원서.hwp samples/pic-crop-01.hwp \
  samples/form-01.hwp samples/hwpx/form-002.hwpx samples/hwpx/hwpx-01.hwpx
```

결과:

| 파일 | Status | ChangedPixels | ChangedPercent | MeanRGBDelta | NativeMs |
|------|--------|--------------:|---------------:|-------------:|---------:|
| `request.hwp` | OK | `321284/1798071` | `17.8683%` | `10.9606` | `1175.0` |
| `복학원서.hwp` | OK | `257941/3562815` | `7.2398%` | `6.7272` | `44.6` |
| `pic-crop-01.hwp` | OK | `72763/3562815` | `2.0423%` | `0.8092` | `4.6` |
| `form-01.hwp` | OK | `28739/3562815` | `0.8066%` | `0.4843` | `2.2` |
| `form-002.hwpx` | OK | `543087/3561228` | `15.2500%` | `17.3362` | `30.1` |
| `hwpx-01.hwpx` | OK | `505312/3562815` | `14.1829%` | `15.1348` | `32.0` |

산출물:

```text
build.noindex/task121-stage4-regression-escalated/summary.md
build.noindex/task121-stage4-regression-escalated/studio/
build.noindex/task121-stage4-regression-escalated/native/
build.noindex/task121-stage4-regression-escalated/diff/
```

## Render Debug 재측정

명령:

```bash
./scripts/render-debug-compare.sh build.noindex/task121-stage4-render-debug --page 1 \
  samples/draw-group.hwp samples/eq-01.hwp

./scripts/render-debug-compare.sh build.noindex/task121-stage4-download --page 1 \
  /Users/melee/Downloads/143E433F503322BD33.hwp
```

결과:

| 파일 | RenderTreeJSONBytes | CoreSVGBytes | NativePNGSize | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|------|--------------------:|-------------:|---------------|---------------------:|---------:|-----------:|--------------------:|
| `draw-group.hwp` | `13998` | `19539` | `794x1123` | `7324` | `2` | `1` | `0` |
| `eq-01.hwp` | `233539` | `262660` | `794x1123` | `45708` | `71` | `37` | `0` |
| `143E433F503322BD33.hwp` | `307461` | `628489` | `794x1123` | `136906` | `186` | `98` | `0` |

세 파일 모두 native PNG는 생성됐다. optional core SVG raster diff는 `qlmanage rasterize failed`로 생성되지 않았고, 이는 Stage 1/3과 같은 local `qlmanage` rasterize 한계다.

## Node Type 확인

Stage 4 render tree 기준 target sample의 node type은 Stage 1과 동일하게 유지됐다.

`draw-group.hwp`:

| NodeType | Count |
|----------|------:|
| `Image` | `17` |
| `Group` | `1` |
| `TextRun` | `2` |
| `RawSvg` | `0` |
| `Placeholder` | `0` |

`eq-01.hwp`:

| NodeType | Count |
|----------|------:|
| `Equation` | `3` |
| `TextRun` | `71` |
| `RawSvg` | `0` |
| `Placeholder` | `0` |

제공 fixture `143E433F503322BD33.hwp`:

| NodeType | Count |
|----------|------:|
| `Image` | `1` |
| `Placeholder` | `1` |
| `RawSvg` | `0` |

이 파일은 RawSvg positive가 아니라 OLE/chart-like object가 core에서 `Placeholder`로 내려오는 fixture다. 실제 OLE/chart payload 복원은 upstream core 정합성 작업으로 분리했고, 별도 upstream 이슈 `edwardkim/rhwp#1251`을 생성했다.

## Build / Policy Check

| 명령 | 결과 | 비고 |
|------|------|------|
| `git diff --check` | OK | 공백/patch 문제 없음 |
| `./scripts/check-no-appkit.sh` | OK | `RhwpCoreBridge` AppKit/UIKit 의존 없음 |
| `./scripts/check-extension-registration-hygiene.sh --check-only` | OK | Issues 없음 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug -derivedDataPath build.noindex/DerivedData-task121 CODE_SIGNING_ALLOWED=NO build` | OK | sandbox 내부 cache 권한 실패 후 sandbox 밖 재시도에서 `** BUILD SUCCEEDED **` |

extension hygiene warning:

```text
development/test Alhangeul.app bundles exist under build.noindex or DerivedData; this is only a problem if they are registered.
Quick Look preview provider path was not reported by PlugInKit.
Thumbnail provider path was not reported by PlugInKit.
```

등록된 development provider나 legacy candidate는 없었다.

## 수용 기준 점검

| 수용 기준 | 결과 | 근거 |
|-----------|------|------|
| RawSvg node가 `.unknown`으로 사라지지 않고 Swift model에서 식별된다 | OK | Stage 3 synthetic RenderTree JSON으로 `.rawSvg` decode/render smoke 확인 |
| 지원 가능한 RawSvg 또는 raster image data URL payload가 bbox 안에 표시된다 | OK | Stage 3 synthetic data image case에서 red pixels 확인 |
| 표시 불가 payload는 crash 없이 명확한 placeholder/fallback으로 보인다 | OK | Stage 3 synthetic complex SVG fallback, Stage 4 Placeholder fixture render-debug 확인 |
| OLE/chart/static resource bbox, transform, clipping이 기존 flow와 크게 어긋나지 않는다 | OK | `143E433F503322BD33.hwp` Placeholder가 body clip 안 visible 영역에 표시됨 |
| Quick Look preview, Finder thumbnail, PDF/CoreGraphics fallback이 같은 renderer path를 사용한다 | OK | `CGTreeRenderer` 공통 경로 변경, visual diff harness native backend `coreGraphics` |
| #122 image fill/tile/placement, #116 baked watermark gate, #282 compositor sample이 회귀하지 않는다 | OK | target/regression visual diff harness OK, render-debug native PNG 생성 |
| visual diff 수치와 fallback 여부가 stage 문서와 최종 보고서에 남는다 | OK | Stage 4 보고서에 target/regression metric과 Placeholder fallback 여부 기록 |

## 잔여 위험

- 실제 RawSvg positive HWP/HWPX fixture는 아직 확보하지 못했다. 현재 구현은 upstream source contract와 synthetic JSON으로 RawSvg를 검증했다.
- 복합 SVG chart/EMF는 Stage 3 정책대로 직접 rasterize하지 않고 `SVG` fallback으로 남긴다.
- visual diff harness는 sandbox 내부에서 readiness timeout이 재현된다. sandbox 밖 실행은 통과하므로, harness 안정화 자체는 후속 작업으로 분리하는 편이 맞다.
- `143E433F503322BD33.hwp`의 OLE/chart-like object는 현재 core에서 `Placeholder`로 내려온다. 실제 chart 복원은 upstream `edwardkim/rhwp#1251` 범위다.

## 다음 단계

Stage 5에서 최종 보고서를 작성하고 오늘할일을 완료로 갱신한 뒤 PR 게시 준비를 진행한다.
