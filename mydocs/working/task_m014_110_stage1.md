# Task M014 #110 Stage 1 완료 보고서

## 단계 목적

Stage 1은 소스 변경 없이 `Placeholder`/`FormObject` 입력과 현재 Swift/CoreGraphics renderer의 누락 지점을 고정하는 단계다. `samples/form-01.hwp`, `samples/hwpx/form-002.hwpx` page 1을 기준으로 render tree/debug output, rhwp-studio reference, native output, visual diff baseline을 생성했다.

## 산출물

| 산출물 | 요약 |
|--------|------|
| `build.noindex/task110-stage1-render-debug/` | render tree JSON, core SVG, native PNG, summary 생성 |
| `build.noindex/task110-stage1-baseline/summary.md` | rhwp-studio `v0.7.13` reference와 Swift native output visual diff 기준선 |
| `build.noindex/task110-stage1-baseline/studio/*.json` | studio capture metadata. 두 샘플 모두 `captureMode=domComposite`, `overlayIncluded=true` |
| `build.noindex/task110-stage1-baseline/native/*.json` | native CoreGraphics render metadata |
| `mydocs/working/task_m014_110_stage1.md` | Stage 1 관찰값과 다음 단계 입력 정리 |

`build.noindex/` 산출물은 재생성 가능한 검증 부산물이며 커밋 대상이 아니다.

## 본문 변경 정도 / 본문 무손실 여부

소스 코드와 기존 문서 본문은 변경하지 않았다. 이번 단계의 커밋 대상은 신규 단계 보고서뿐이다.

## current path 관찰

현재 `RenderTree.swift`는 `FormObject`와 `Placeholder`를 `.unknown` 전에 디코딩한다. 다만 `FormObjectNode`의 Swift 모델은 `form_type`, `caption`, `text`만 갖고 있고, 실제 payload에 존재하는 정적 표시용 필드는 아직 소비하지 않는다.

Target page의 node count:

| 샘플 | FormObject | Placeholder |
|------|-----------:|------------:|
| `form-01.hwp` | 5 | 0 |
| `form-002.hwpx` | 36 | 0 |

두 target page 모두 `Placeholder` node는 없었다. #121에서 들어온 `Placeholder` 기본 렌더링은 유지 검증 대상으로 남기되, #110 target sample의 직접 누락은 `FormObject` no-op이 원인이다.

`FormObject` payload key는 두 샘플에서 동일한 shape로 내려온다.

| key | `form-01.hwp` | `form-002.hwpx` | Swift 현재 소비 |
|-----|--------------:|----------------:|----------------|
| `form_type` | 5 | 36 | 소비 |
| `caption` | 5 | 36 | 소비 |
| `text` | 5 | 36 | 소비 |
| `fore_color` | 5 | 36 | 미소비 |
| `back_color` | 5 | 36 | 미소비 |
| `value` | 5 | 36 | 미소비 |
| `enabled` | 5 | 36 | 미소비 |
| `name` | 5 | 36 | 미소비 |
| `section_index` / `para_index` / `control_index` | 5 | 36 | 미소비 |
| `cell_location` | 5 | 36 | 미소비 |

Type 분포:

| 샘플 | type 분포 |
|------|-----------|
| `form-01.hwp` | `PushButton=1`, `CheckBox=1`, `ComboBox=1`, `RadioButton=1`, `Edit=1` |
| `form-002.hwpx` | `CheckBox=36` |

`value` 분포:

| 샘플 | `value=0` | `value=1` |
|------|----------:|----------:|
| `form-01.hwp` | 4 | 1 |
| `form-002.hwpx` | 29 | 7 |

모든 target `FormObject`의 `enabled`는 `true`였다.

## core SVG reference 관찰

core SVG에는 이미 static form preview가 포함되어 있다.

- `PushButton`: gray rect, centered caption
- `CheckBox`: 13pt square, `value=1`일 때 check polyline, caption label
- `ComboBox`: input rect, right-side button rect, down arrow polygon, text label
- `RadioButton`: circle, `value=0`이면 dot 없음
- `Edit`: white rect with gray stroke

Swift native output은 `FormObject`를 no-op으로 처리하기 때문에 `form-01.hwp`에서는 빨간 `여기에 입력` TextRun만 보이고, 버튼/체크박스/콤보박스/라디오/입력칸이 빠진다. `form-002.hwpx`에서는 표와 일반 텍스트는 보이나 checkbox square/check/label이 rhwp-studio 대비 빠진다.

## visual diff baseline

`preview-visual-diff-harness` 기준선:

| 샘플 | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | DiffBounds | StudioCapture | NativeBackend | NativeMs |
|------|--------------:|---------------:|-------------:|------------:|------------|---------------|---------------|---------:|
| `form-01.hwp` | `28739/3562815` | `0.8066%` | `0.4843` | `255` | `197,234 1194x1814` | `domComposite` | `coreGraphics` | `1125.6` |
| `form-002.hwpx` | `543087/3561228` | `15.2500%` | `17.3362` | `255` | `121,159 1345x1962` | `domComposite` | `coreGraphics` | `32.1` |

Native render metadata:

| 샘플 | NativePNGSize | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|------|---------------|---------------------:|---------:|-----------:|--------------------:|
| `form-01.hwp` | `794x1123` | 352 | 15 | 1 | 0 |
| `form-002.hwpx` | `794x1123` | 173421 | 135 | 62 | 0 |

## 검증 결과

`render-debug-compare`는 sandbox 안에서 성공했다.

```text
OK form-01.hwp: page=1 renderTreeJSON=.../form-01-page1-render-tree.json coreSVG=.../form-01-page1-core.svg nativePNG=.../form-01-page1-native.png summary=.../form-01-page1-summary.txt
OK form-002.hwpx: page=1 renderTreeJSON=.../form-002-page1-render-tree.json coreSVG=.../form-002-page1-core.svg nativePNG=.../form-002-page1-native.png summary=.../form-002-page1-summary.txt
```

`render-debug-compare`의 optional core SVG raster diff는 `qlmanage` sandbox initialization 실패로 생성되지 않았다. 이 실패는 optional SVG rasterization 구간이며 스크립트 exit code는 0이었다.

`preview-visual-diff-harness`는 sandbox 안에서 WebKit readiness timeout으로 실패한 뒤, 같은 명령을 승인 경로로 재실행해 성공했다.

```text
FAIL ... form-01.hwp: [phase:readiness] rhwp-studio page 1 readiness timed out: navigation=pending; events=[]; scheme={resourceRequests=0, documentRequests=0}
FAIL ... form-002.hwpx: [phase:readiness] rhwp-studio page 1 readiness timed out: navigation=pending; events=[]; scheme={resourceRequests=0, documentRequests=0}
```

승인 경로 재실행 결과:

```text
OK form-01.hwp: studioPNG=.../studio/form-01.hwp-page1-studio.png nativePNG=.../native/form-01.hwp-page1-native.png diffPNG=.../diff/form-01.hwp-page1-diff.png
OK form-002.hwpx: studioPNG=.../studio/form-002.hwpx-page1-studio.png nativePNG=.../native/form-002.hwpx-page1-native.png diffPNG=.../diff/form-002.hwpx-page1-diff.png
```

문서/whitespace 검증:

```text
git diff --check
```

통과했다.

## 잔여 위험

- Target page에는 `Placeholder` node가 없어서 #121 Placeholder 기본 구현은 별도 fixture나 기존 #121 보고서 결과에 기대어 회귀 확인해야 한다.
- `form-002.hwpx`의 `caption`에는 `R&amp;&amp;D`처럼 HTML entity가 이중 escape된 값이 보인다. Stage 2에서 label unescape 여부를 정책으로 정해야 한다.
- `form-01.hwp`의 visual diff percent는 낮지만 사용자-facing form object는 거의 전부 빠진다. Stage 2 이후 평가는 pixel diff와 non-blank 개선을 함께 봐야 한다.
- sandbox 환경에서는 WebKit reference capture가 readiness timeout을 일으킬 수 있어 visual diff harness는 승인 경로 실행이 필요할 수 있다.
- `NativeMs=1125.6` for `form-01.hwp`는 같은 페이지의 render-debug와 비교해 큰 값이다. Stage 4에서 재측정해 일시적 편차인지 확인한다.

## 다음 단계 영향

Stage 2는 `FormObjectNode` 모델과 정적 preview 정책을 다음 기준으로 고정하면 된다.

- optional field: `foreColor`, `backColor`, `value`, `enabled`, `name`, 필요 시 index/location metadata
- label 우선순위: `text`가 있으면 우선, 없으면 `caption`, fallback은 `name` 또는 `form_type`
- `CheckBox`: `value=1`이면 check mark, 그 외 empty square
- `RadioButton`: `value=1`이면 inner dot, 그 외 empty circle
- `PushButton`, `ComboBox`, `Edit`: core SVG reference의 최소 rect/text/arrow 표현을 CoreGraphics helper로 재해석
- unsupported type: bbox 안에 명확한 fallback box와 type/name label 표시

## 승인 요청

Stage 1 산출물과 기준선 확인을 완료했다. Stage 2에서 `FormObjectNode` payload 모델과 type별 static preview/fallback 정책 설계를 진행해도 되는지 승인 요청한다.
