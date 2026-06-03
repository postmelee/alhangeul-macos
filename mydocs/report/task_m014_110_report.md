# Task M014 #110 최종 보고서 - Swift native renderer Placeholder/FormObject 정적 프리뷰 보강

## 작업 개요

- 이슈: #110 Swift native renderer Placeholder/FormObject 정적 프리뷰 보강
- 마일스톤: M014 (`v0.1.4 Native Preview/Viewer Parity`)
- 브랜치: `local/task110`
- 기준 브랜치: `devel`
- core/studio 기준: rhwp `v0.7.13`, resolved commit `b3e16ef212af81ef37d973ddb86d6816d3804642`

이번 작업은 Quick Look preview, Finder thumbnail, PDF/CoreGraphics fallback이 공유하는 Swift/CoreGraphics native renderer에서 `FormObject`가 빈 영역으로 사라지지 않게 정적 preview를 추가하는 작업이다. 실제 form interaction, form mutation, upstream `rhwp` 수정, Skia 기본 경로 전환은 범위에서 제외했다.

## 최종 결론

#110은 완료 기준을 충족했다.

- `FormObjectNode`가 `fore_color`, `back_color`, `value`, `enabled`, `name` payload를 optional로 디코딩한다.
- `CGTreeRenderer`가 `PushButton`, `CheckBox`, `RadioButton`, `ComboBox`, `Edit`를 정적 preview로 그린다.
- unsupported form type은 no-op이 아니라 solid fallback box로 표시한다.
- `samples/form-01.hwp`에서 button, checkbox, combo box, radio button, edit box가 native PNG에 표시된다.
- `samples/hwpx/form-002.hwpx`에서 checkbox square/check/label이 native PNG에 표시된다.
- `RhwpCoreBridge`에 AppKit/UIKit/WebKit 직접 의존을 추가하지 않았다.
- Quick Look/PDF shared renderer smoke에서 target sample이 모두 fallback 없이 처리됐다.

`Placeholder`는 #121에서 이미 기본 fallback이 들어와 있었고, #110 target page에는 `Placeholder` node가 없었다. 따라서 이번 작업의 직접 구현 범위는 `FormObject` 정적 preview이며, 기존 `Placeholder`, `RawSvg`, `Image`, `Equation`, 일반 text rendering 경로는 의도적으로 변경하지 않았다.

## 변경 파일과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/RenderTree.swift` | `FormObjectNode`에 `foreColor`, `backColor`, `value`, `enabled`, `name` optional field 추가 |
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | `.formObject` no-op 제거, type dispatch, known type별 static preview, unsupported fallback, color/label helper 추가 |
| `mydocs/plans/task_m014_110.md` | 수행 계획서 |
| `mydocs/plans/task_m014_110_impl.md` | 구현 계획서 |
| `mydocs/working/task_m014_110_stage1.md` | current path inventory와 baseline |
| `mydocs/working/task_m014_110_stage2.md` | payload 모델과 static preview 정책 |
| `mydocs/working/task_m014_110_stage3.md` | 구현 결과와 smoke 검증 |
| `mydocs/working/task_m014_110_stage4.md` | visual diff와 regression/shared path 검증 |
| `mydocs/report/task_m014_110_report.md` | 최종 보고서 |
| `mydocs/orders/20260603.md` | 오늘할일 완료 상태 갱신 |

## 구현 요약

지원 type:

| Form type | Static preview |
|-----------|----------------|
| `PushButton` | gray rect + centered label |
| `CheckBox` | square + `value != 0` check mark + left label |
| `RadioButton` | circle + selected inner dot + left label |
| `ComboBox` | input rect + right button + down arrow + text label |
| `Edit` | empty input rect. text/caption이 없으면 name/type fallback을 표시하지 않음 |
| unsupported | solid fallback box + type/name label |

Label 정책:

1. `text`
2. `caption`
3. `name`
4. `formType`

단, `Edit`는 empty field가 `name` fallback으로 `Edit` label을 표시하지 않게 별도 정책을 적용했다. HTML/XML entity unescape는 적용하지 않았다. bundled `rhwp-studio v0.7.13` parity를 우선해 `R&amp;&amp;D` 계열 문자열을 Swift만 임의 변환하지 않는다.

Renderer 경계:

- `shouldRenderFlowContent` gate 유지
- `validTopLeftRect`와 bbox clipping 유지
- CoreText 기반 label drawing
- `#RRGGBB` string parser는 FormObject 전용 helper로 분리
- `RhwpCoreBridge` AppKit/UIKit/WebKit 직접 의존 없음

## 단계별 결과

### Stage 1. current path inventory와 baseline

Target page의 node count:

| 샘플 | FormObject | Placeholder |
|------|-----------:|------------:|
| `form-01.hwp` | 5 | 0 |
| `form-002.hwpx` | 36 | 0 |

Type 분포:

| 샘플 | type 분포 |
|------|-----------|
| `form-01.hwp` | `PushButton=1`, `CheckBox=1`, `ComboBox=1`, `RadioButton=1`, `Edit=1` |
| `form-002.hwpx` | `CheckBox=36` |

Stage 1 visual diff baseline:

| 샘플 | ChangedPixels | ChangedPercent | MeanRGBDelta | NativeNonWhitePixels |
|------|--------------:|---------------:|-------------:|---------------------:|
| `form-01.hwp` | `28739/3562815` | 0.8066% | 0.4843 | 352 |
| `form-002.hwpx` | `543087/3561228` | 15.2500% | 17.3362 | 173421 |

### Stage 2. 모델과 static preview 정책

구현 전 `FormObjectNode` 추가 필드와 type별 렌더링 정책을 문서로 고정했다.

주요 결정:

- 정적 preview에 필요한 payload만 optional field로 추가한다.
- `cell_location`은 payload shape 변동 가능성이 있어 이번 모델 확장에서 제외한다.
- known control chrome은 core SVG reference 기본값을 우선한다.
- unsupported fallback은 `Placeholder`와 구분하기 위해 dashed stroke를 쓰지 않는다.
- HTML/XML entity unescape는 하지 않는다.

### Stage 3. 구현과 smoke

변경 규모:

```text
Sources/RhwpCoreBridge/CGTreeRenderer.swift | 392 +++++++++++++++++++++++++++-
Sources/RhwpCoreBridge/RenderTree.swift     |   8 +
2 files changed, 396 insertions(+), 4 deletions(-)
```

Target render-debug 결과:

| 샘플 | NativePNGSize | NativeNonWhitePixels | TextRuns | HangulRuns | MissingHangulGlyphs |
|------|---------------|---------------------:|---------:|-----------:|--------------------:|
| `form-01.hwp` | `794x1123` | 4760 | 15 | 1 | 0 |
| `form-002.hwpx` | `794x1123` | 189203 | 135 | 62 | 0 |

Stage 1 대비 native non-white 변화:

| 샘플 | Stage 1 | Stage 3/4 | 변화 |
|------|--------:|----------:|-----:|
| `form-01.hwp` | 352 | 4760 | +4408 |
| `form-002.hwpx` | 173421 | 189203 | +15782 |

HostApp Debug build는 sandbox 안 첫 실행에서 Sparkle package fetch DNS 제한으로 실패했고, 승인 경로 재실행에서 성공했다.

```text
** BUILD SUCCEEDED ** [13.301 sec]
```

### Stage 4. visual diff와 shared path 검증

Target visual diff:

| 샘플 | Status | Stage 1 ChangedPercent | Stage 4 ChangedPercent | 변화 |
|------|--------|-----------------------:|-----------------------:|-----:|
| `form-01.hwp` | OK | 0.8066% | 0.6153% | -0.1913%p |
| `form-002.hwpx` | OK | 15.2500% | 16.1230% | +0.8730%p |

세부 수치:

| 샘플 | ChangedPixels | MeanRGBDelta | DiffBounds | NativeMs |
|------|--------------:|-------------:|------------|---------:|
| `form-01.hwp` | `21921/3562815` | 0.3370 | `197,234 1194x1814` | 996.9 |
| `form-002.hwpx` | `574177/3561228` | 17.0864 | `121,159 1345x1962` | 32.9 |

`form-01.hwp`는 rhwp-studio reference와 더 가까워졌다. `form-002.hwpx`는 checkbox 표시가 추가되며 diff percentage가 상승했다. 이는 no-op 제거에 따른 expected movement로 판단하며, crash나 blank regression은 아니다.

Regression visual diff:

| 샘플 | Status | ChangedPercent | MeanRGBDelta |
|------|--------|----------------:|-------------:|
| `request.hwp` | OK | 18.2346% | 10.8057 |
| `hwpx-01.hwpx` | OK | 14.1829% | 15.1348 |
| `복학원서.hwp` | OK | 7.2398% | 6.7272 |
| `pic-crop-01.hwp` | OK | 2.0423% | 0.8092 |
| `tac-img-02.hwp` | OK | 4.1085% | 3.6656 |
| `tac-img-02.hwpx` | OK | 4.1085% | 3.6656 |
| `draw-group.hwp` | OK | 0.8132% | 0.4881 |
| `eq-01.hwp` | OK | 6.4707% | 5.9354 |

Quick Look / PDF shared path smoke:

| 샘플 | PDF compare | Quick Look policy | CGFallback | SkiaFallback |
|------|-------------|-------------------|-----------:|-------------:|
| `form-01.hwp` | OK, `CurrentReply=png`, `Pages=1` | OK, `Reply=png`, `CGBackend=skia:0,cg:1,embedded:0` | 0 | 0 |
| `form-002.hwpx` | OK, `CurrentReply=pdf`, `Pages=10` | OK, `Reply=pdf`, `CGBackend=skia:0,cg:10,embedded:0` | 0 | 0 |

## PR visual diff PNG placeholder

PR 본문 초안은 최종 커밋 이후 `build.noindex/task110-pr-body.md`로 생성한다. 사용자는 PR 편집 화면에서 아래 로컬 PNG를 업로드한 뒤, 초안의 `UPLOAD_..._URL_HERE` placeholder를 GitHub가 생성한 `https://github.com/user-attachments/assets/...` URL로 바꾸면 된다.

Target PNG 산출물:

| 샘플 | Studio reference PNG | Native after PNG | Diff PNG |
|------|----------------------|------------------|----------|
| `form-01.hwp` | `build.noindex/task110-stage4-target/studio/form-01.hwp-page1-studio.png` | `build.noindex/task110-stage4-target/native/form-01.hwp-page1-native.png` | `build.noindex/task110-stage4-target/diff/form-01.hwp-page1-diff.png` |
| `form-002.hwpx` | `build.noindex/task110-stage4-target/studio/form-002.hwpx-page1-studio.png` | `build.noindex/task110-stage4-target/native/form-002.hwpx-page1-native.png` | `build.noindex/task110-stage4-target/diff/form-002.hwpx-page1-diff.png` |

PR 본문에는 target 2개 sample에 대해 `Studio reference`, `Native after`, `Diff` 3개 image column을 둔다. 실제 PNG 파일은 GitHub PR 본문에 로컬 경로로 직접 표시되지 않으므로, GitHub upload URL로 교체하는 방식이 필요하다.

## 검증 요약

실행한 주요 검증:

```bash
./scripts/render-debug-compare.sh build.noindex/task110-stage1-render-debug --page 1 \
  samples/form-01.hwp samples/hwpx/form-002.hwpx

./scripts/preview-visual-diff-harness.sh build.noindex/task110-stage1-baseline --page 1 \
  samples/form-01.hwp samples/hwpx/form-002.hwpx

./scripts/render-debug-compare.sh build.noindex/task110-stage3-render-debug --page 1 \
  samples/form-01.hwp samples/hwpx/form-002.hwpx

xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task110 CODE_SIGNING_ALLOWED=NO build

./scripts/preview-visual-diff-harness.sh build.noindex/task110-stage4-target --page 1 \
  samples/form-01.hwp samples/hwpx/form-002.hwpx

./scripts/preview-visual-diff-harness.sh build.noindex/task110-stage4-regression --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/복학원서.hwp samples/pic-crop-01.hwp \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/draw-group.hwp samples/eq-01.hwp

./scripts/render-debug-compare.sh build.noindex/task110-stage4-render-debug --page 1 \
  samples/form-01.hwp samples/hwpx/form-002.hwpx

./scripts/compare-quicklook-pdf-renderers.sh build.noindex/task110-stage4-pdf-compare \
  samples/form-01.hwp samples/hwpx/form-002.hwpx

./scripts/smoke-quicklook-skia-policy.sh build.noindex/task110-stage4-quicklook-policy \
  samples/form-01.hwp samples/hwpx/form-002.hwpx

./scripts/check-extension-registration-hygiene.sh --check-only
./scripts/check-no-appkit.sh
git diff --check
```

검증 결과:

- target render-debug: OK
- target visual diff: OK
- regression visual diff: OK
- HostApp Debug build: OK
- Quick Look PDF/native renderer compare: OK
- Quick Look policy smoke: OK
- extension registration hygiene: Issues none
- shared Swift AppKit/UIKit dependency check: OK
- whitespace check: OK

환경상 특이사항:

- WebKit 기반 visual diff harness는 sandbox 내부에서 `navigation=pending; events=[]; scheme={resourceRequests=0, documentRequests=0}` readiness timeout을 일으켰고, 승인 경로 재실행에서 성공했다.
- `render-debug-compare`의 optional `qlmanage` SVG raster diff는 sandbox initialization 실패로 생성되지 않았다. 스크립트 exit code는 0이었다.
- Finder 실제 thumbnail 등록/캐시 smoke는 수행하지 않았다. 개발 extension 등록 오염을 피하기 위해 registration hygiene check만 수행했다.

## 남은 리스크와 후속 후보

- `form-002.hwpx` checkbox label fitting과 position parity는 아직 rhwp-studio/core SVG와 픽셀 단위로 맞지 않는다. 이번 작업은 no-op 제거와 static preview 표시를 완료 기준으로 삼았다.
- disabled control fixture가 없어 `enabled=false` tone은 target sample 실측으로 검증하지 못했다.
- HTML/XML entity unescape는 적용하지 않았다. 사용자-facing 문자열 품질 개선이 필요하면 upstream payload 정규화 또는 별도 Swift 표시 정책 이슈로 분리하는 것이 안전하다.
- Finder 실제 thumbnail smoke는 release/설치본 표준 smoke 단계에서 확인해야 한다.

후속 이슈 후보:

- FormObject checkbox/radio/combo label fitting과 위치 parity 정밀 보정
- FormObject disabled state fixture 추가 및 tone 검증
- HTML/XML entity 표시 정책 정리
- Finder 설치본 기준 form object thumbnail visual smoke
