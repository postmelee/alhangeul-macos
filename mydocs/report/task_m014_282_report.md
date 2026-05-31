# Task M014 #282 최종 결과보고서

## 작업 요약

| 항목 | 내용 |
|------|------|
| 이슈 | [#282](https://github.com/postmelee/alhangeul-macos/issues/282) Quick Look/Thumbnail native compositor를 rhwp-studio flow·overlay 구조로 보강 |
| 마일스톤 | M014 — v0.1.4 Native Preview/Viewer Parity |
| 브랜치 | `local/task282` |
| 단계 수 | 5단계 |
| 최종 기준 | rhwp v0.7.13 기준, CoreGraphics compositor는 overlay image pass를 page content 이후에 합성 |

이번 작업은 Quick Look/Thumbnail native CoreGraphics preview가 rhwp-studio와 같은 overlay image 구조를 더 잘 반영하도록 compositor path를 보강했다. 기존에는 render tree drawing과 page image rendering이 서로 다른 위치에서 수행되어 overlay image를 별도 pass로 다루기 어려웠다. 이제 `HwpNativePageCompositor`가 page content pass와 overlay image pass를 명시적으로 합성하고, `CGTreeRenderer`는 upstream metadata overlay 또는 기존 tree image fallback을 그릴 수 있다.

## 변경 파일 목록과 영향 범위

| 파일 | 내용 |
|------|------|
| `Sources/RhwpCoreBridge/CGTreeRenderer.swift` | `renderOverlayImages` 경로를 추가해 metadata overlay image의 transform, alpha, embedded/bin data decoding을 CoreGraphics에 그리도록 보강했다. |
| `Sources/Shared/HwpNativePageCompositor.swift` | page content와 overlay image pass를 합성하는 compositor를 추가했다. renderable metadata overlay가 없으면 기존 render tree image fallback을 사용한다. |
| `Sources/Shared/HwpPageImageRenderer.swift` | Quick Look/Thumbnail native page rendering이 compositor를 통해 CoreGraphics output을 만들도록 연결했다. |
| `Alhangeul.xcodeproj/project.pbxproj` | 새 shared compositor source를 HostApp/QLExtension/ThumbnailExtension build target에 포함했다. |
| `scripts/preview-visual-diff-harness.sh` | Stage smoke에서 `RHWP_SWIFT_RENDERER_BACKEND=coreGraphicsOnly` 환경을 명시했다. |
| `scripts/smoke-quicklook-skia-policy.sh` | Quick Look Skia/CoreGraphics policy 비교 smoke에서 explicit renderer policy를 사용하도록 정리했다. |
| `scripts/compare-quicklook-pdf-renderers.sh` | PDF renderer 비교 smoke의 backend policy 전달을 정리했다. |
| `mydocs/plans/task_m014_282.md` | 수행계획서. |
| `mydocs/plans/task_m014_282_impl.md` | 구현계획서. |
| `mydocs/working/task_m014_282_stage1.md` | baseline 측정과 코드 inventory. |
| `mydocs/working/task_m014_282_stage2.md` | compositor pass 분리. |
| `mydocs/working/task_m014_282_stage3.md` | overlay image drawing 연결. |
| `mydocs/working/task_m014_282_stage4.md` | harness 보정 후 통합 smoke와 visual diff 측정. |
| `mydocs/working/task_m014_282_stage5.md` | 최종 handoff 정리. |
| `mydocs/orders/20260527.md`, `mydocs/orders/20260530.md` | 오늘할일 상태와 다음 실행 순서 기록. |

## 단계별 결과

### Stage 1. 기준 조사와 baseline 측정

Stage 1에서는 native preview path, render tree image drawing, Quick Look/Thumbnail renderer policy, visual diff harness를 확인했다. 당시 기준은 rhwp-studio v0.7.12와 기존 harness였다.

| Sample | ChangedPercent | MeanRGBDelta | 비고 |
|--------|----------------:|-------------:|------|
| `request.hwp` | 18.1021% | 11.2164 | basic HWP |
| `hwpx-01.hwpx` | 15.1839% | 15.2202 | basic HWPX |
| `tac-img-02.hwp` | 4.1375% | 3.7200 | image sample |
| `tac-img-02.hwpx` | 3.6427% | 3.1392 | image sample |
| `hwp-img-001.hwp` | 7.8448% | 8.3580 | image sample |
| `img-start-001.hwp` | 14.4365% | 18.6470 | image sample |

Stage 1의 중요한 발견은 기존 sample set에 BehindText/InFrontOfText overlay 양성 케이스가 없었다는 점이다. 따라서 overlay pass가 실제 양성 케이스에서 동작하는지 검증하려면 별도 fixture가 필요했다.

### Stage 2. Native compositor pass 분리

Stage 2에서는 `HwpNativePageCompositor`를 추가해 page content rendering과 overlay pass를 분리했다. 이 단계는 rendering order를 명확하게 만들기 위한 구조 작업이다. 아직 metadata overlay image drawing은 연결하지 않았고, 기존 render tree image fallback을 보존했다.

검증 결과:

- HostApp/QLExtension/ThumbnailExtension Debug build 성공
- extension registration hygiene 문제 없음
- `git diff --check` 통과

### Stage 3. Overlay image drawing 연결

Stage 3에서는 metadata overlay image drawing path를 `CGTreeRenderer.renderOverlayImages`로 연결했다. 우선순위는 다음과 같다.

1. upstream metadata overlay의 embedded `source.data`
2. metadata overlay의 `binDataId`
3. renderable metadata overlay가 없을 때 기존 render tree image fallback

이 단계에서 기존 sample set의 image smoke는 정상 종료했다. 다만 당시 visual diff harness는 `복학원서.hwp` 같은 overlay DOM을 studio reference에 포함하지 못해 positive overlay 판단에는 한계가 있었다.

Stage 3 image set 결과:

| Sample | ChangedPercent | MeanRGBDelta | StudioCapture |
|--------|----------------:|-------------:|---------------|
| `tac-img-02.hwp` | 4.1335% | 3.7157 | `canvasDataURL` |
| `tac-img-02.hwpx` | 4.2178% | 3.6095 | `domComposite` |
| `hwp-img-001.hwp` | 7.9015% | 8.3980 | `domComposite` |
| `img-start-001.hwp` | 18.0119% | 22.1834 | `domComposite` |

### Stage 4. Harness 보정 후 통합 smoke

#293에서 visual diff harness가 overlay DOM을 `domComposite`로 캡처하도록 수정된 뒤 Stage 4를 재측정했다. `복학원서.hwp`는 BehindText overlay positive fixture로 확인됐다.

Common condition:

- Page: 1
- Native policy: `coreGraphicsOnly`
- Studio release: `v0.7.13`
- Studio resolved commit: `b3e16ef212af81ef37d973ddb86d6816d3804642`
- Viewport: `1400x1800`
- Settle: `120ms`
- Diff pixel threshold: `12`

Basic/image sample set:

| Sample | Stage 1 | Stage 4 | 변화 | StudioCapture |
|--------|--------:|--------:|-----:|---------------|
| `request.hwp` | 18.1021% | 18.0172% | -0.0849pp | `domComposite` |
| `hwpx-01.hwpx` | 15.1839% | 15.0285% | -0.1554pp | `domComposite` |
| `tac-img-02.hwp` | 4.1375% | 4.1335% | -0.0040pp | `canvasDataURL` |
| `tac-img-02.hwpx` | 3.6427% | 4.2178% | +0.5751pp | `domComposite` |
| `hwp-img-001.hwp` | 7.8448% | 7.9015% | +0.0567pp | `domComposite` |
| `img-start-001.hwp` | 14.4365% | 18.0119% | +3.5754pp | `domComposite` |

Positive overlay fixture:

| Sample | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | StudioCapture | NativeBackend | NativeMs |
|--------|--------------:|---------------:|-------------:|------------:|---------------|---------------|---------:|
| `복학원서.hwp` | 1140407/3562815 | 32.0086% | 37.8181 | 255 | `domComposite` | `coreGraphics` | 1105.5 |

Overlay metadata smoke:

| Sample | UpstreamImages | Overlay | Behind | Front | Renderable | BinLinked | Wraps |
|--------|---------------:|--------:|-------:|------:|-----------:|----------:|-------|
| `복학원서.hwp` | 2 | 2 | 2 | 0 | 2 | 2 | BehindText:2 |

관찰:

- `복학원서.hwp`는 `BehindText` 두 이미지를 가진 positive fixture다.
- `front=0`이므로 InFrontOfText positive fixture는 아직 없다.
- studio reference는 `captureMode=domComposite`, `overlayCount=5`, `usedOverlayUnion=true`, `overlayIncluded=true`로 기록됐다.
- native output도 좌상단 로고와 중앙 워터마크를 그린다.
- 중앙 워터마크는 native에서 너무 진하고 gray rectangle이 남는다. 이 차이는 compositor pass보다는 watermark effect parity 문제다.

Quick Look Skia policy smoke:

| Sample | Reply | Pages | CGBackend | CGFallback | CGSeconds | SkiaBackend | SkiaFallback | SkiaSeconds |
|--------|------|------:|-----------|-----------:|----------:|-------------|-------------:|------------:|
| `request.hwp` | png | 1 | skia:0,cg:1,embedded:0 | 0 | 0.981999 | skia:1,cg:0,embedded:0 | 0 | 3.577944 |
| `hwpx-01.hwpx` | pdf | 9 | skia:0,cg:9,embedded:0 | 0 | 0.367728 | skia:9,cg:0,embedded:0 | 0 | 0.641190 |

해석:

- CoreGraphics-only policy는 Quick Look PNG/PDF path에서 CG renderer를 사용한다.
- Skia opt-in policy는 두 sample 모두 Skia backend를 사용했고 fallback은 0건이다.
- 따라서 #282 변경은 Thumbnail 기본 경로와 Quick Look CoreGraphics fallback/coreGraphicsOnly 측정에 직접 적용된다. Skia 성공 경로는 #282 compositor를 우회한다.

### Stage 5. 최종 보고와 handoff

Stage 5에서는 관찰, 수치 비교, 결론, 한계, 다음 작업 순서를 최종 보고서에 정리했다. 별도 compatibility follow-up으로 #296을 생성해 upstream rhwp #1016 release 반영 시 Swift fallback 중복 적용을 막는 작업을 추적하도록 했다.

## 결론

#282의 목표였던 native CoreGraphics compositor 구조 보강과 overlay image drawing 연결은 완료됐다. `복학원서.hwp` 기준으로 metadata overlay image가 native path에서 실제로 그려지는 것을 확인했으므로, 기존의 "overlay image pass가 없는 구조" 문제는 해소됐다.

남은 큰 visual gap은 compositor 순서 문제가 아니라 watermark/effect payload 처리 문제다. 특히 중앙 워터마크 payload는 `mime=image/jpeg`, `effect=grayScale`, `brightness=-50`, `contrast=70`, `watermarkPreset=custom`, `bakedWatermark=false`로 내려오며, native renderer는 rhwp-studio처럼 보정된 결과를 만들지 못한다. 이 부분은 #116에서 다루는 것이 맞다.

## 관찰과 얻은 교훈

- visual diff 숫자는 reference capture 방식에 매우 민감하다. #293 전에는 studio web 화면에는 보이는 overlay가 reference PNG에는 빠질 수 있었다.
- sample set에 양성 케이스가 없으면 구현 성공 여부를 수치만으로 판단하기 어렵다. `복학원서.hwp`가 BehindText positive fixture 역할을 하면서 #282의 실제 효과를 확인할 수 있었다.
- `overlayIncluded=true`와 `captureMode=domComposite` 같은 metadata를 함께 기록해야 visual diff 수치를 해석할 수 있다.
- Quick Look/Thumbnail preview parity 작업은 Skia 성공 경로와 CoreGraphics fallback 경로를 나눠 봐야 한다. #282는 CoreGraphics path의 의미 있는 작업이며, Skia path parity는 upstream renderer 진척과 별도로 추적해야 한다.
- upstream resolved payload가 release로 내려올 가능성이 있는 영역은 Swift fallback을 먼저 추가하더라도 compatibility gate를 별도로 남겨야 한다.

## 한계와 잔여 위험

- #282는 watermark grayscale/brightness/contrast를 구현하지 않았다.
- #282는 upstream #1016/#1017 resolved baked watermark payload를 소비하지 않는다.
- #282는 InFrontOfText positive fixture를 추가하지 않았다.
- partial overlay success에서 일부 overlay만 실패하는 경우 per-image fallback은 아직 없다. 현재 fallback은 renderable overlay가 없거나 attempted draw가 0건인 경우에 초점이 있다.
- `domComposite` reference는 canvas/img 중심의 harness 합성이다. CSS transform, blend mode, SVG, background-image까지 일반화한 browser paint capture는 아니다.
- fill/tile/placement residual diff는 #122, text/layout residual diff는 #121/#110 후속 영역으로 남는다.

## 검증 결과

Stage 4까지 수행한 주요 검증:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage4-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx

./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage4-images --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp

./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage4-overlay-positive --page 1 \
  samples/복학원서.hwp

./scripts/overlay-metadata-smoke.sh build.noindex/task282-stage4-overlay-metadata --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp \
  samples/복학원서.hwp

./scripts/smoke-quicklook-skia-policy.sh build.noindex/task282-stage4-skia-policy \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx

xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task282-stage4 CODE_SIGNING_ALLOWED=NO build

git diff --check
./scripts/check-extension-registration-hygiene.sh --check-only
```

결과:

- `xcodebuild`: `** BUILD SUCCEEDED ** [11.918 sec]`
- visual diff harness: 대상 sample 모두 OK
- overlay metadata smoke: 대상 sample 모두 OK
- Quick Look Skia policy smoke: CG/Skia policy 분기 확인, fallback 0
- `git diff --check`: 통과
- extension registration hygiene: Issues 없음

Stage 5 문서 검증:

```bash
rg -n "#116|#122|#121|#110|#282|#296|Skia|CoreGraphics|overlay|ChangedPercent" \
  mydocs/working/task_m014_282_stage*.md mydocs/report/task_m014_282_report.md
git diff --check
git status --short --branch
```

## Handoff

다음 순서:

1. #282 PR을 게시하고 review/merge한다.
2. #116에서 `복학원서.hwp` 중앙 watermark/effect parity를 진행한다.
3. #296은 upstream rhwp #1016 release가 내려온 뒤 Swift fallback 중복 적용 방지로 처리한다.
4. #122/#121/#110은 watermark parity 이후 남는 diff를 기준으로 분리한다.

#116에서 바로 확인할 기준:

- `복학원서.hwp` studio reference는 `captureMode=domComposite`, `overlayIncluded=true`여야 한다.
- native output의 중앙 watermark가 너무 진하고 gray rectangle이 남는 현상을 먼저 줄인다.
- 현재 upstream payload가 `bakedWatermark=false`이므로 Swift fallback bake를 적용하더라도, #296에서 향후 `bakedWatermark=true` 또는 resolved PNG payload가 내려올 때 중복 적용하지 않도록 해야 한다.

## PR 반영 메모

PR 본문에는 다음을 반드시 포함한다.

- Stage 4 smoke 측정값과 결론
- `복학원서.hwp`가 BehindText positive fixture이며 InFrontOfText positive fixture는 아직 없다는 점
- Quick Look Skia policy smoke에서 Skia 성공 경로가 #282 compositor를 우회한다는 점
- #116, #296, #122, #121, #110 handoff

