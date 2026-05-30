# Task #282 Stage 4 완료 보고서

## 작업 개요

- 이슈: #282
- 브랜치: `local/task282`
- 단계: Stage 4. Quick Look/Thumbnail 통합 smoke와 visual diff 측정
- 목표: #293 visual diff harness 수정이 반영된 상태에서 CoreGraphics compositor 결과, Quick Look Skia/CoreGraphics policy, overlay 양성 fixture 결과를 다시 측정한다.

## 기준 정렬

- #293 완료 후 `local/task282`가 `origin/devel` 대비 18커밋 behind 상태였다.
- 작업 트리가 clean인 상태에서 `git rebase origin/devel`을 수행했고 충돌 없이 완료했다.
- Stage 4 시작 기준 `origin/devel`은 `5966bd7`이며, #293 merge commit `fa75296`과 #292 merge commit `5966bd7`이 포함됐다.
- rebase 후 #282 커밋은 `origin/devel` 대비 4개 ahead 상태다.

## Stage 4 측정 범위

- Stage 1 baseline과 같은 basic/image sample set을 다시 측정했다.
- #293에서 수정된 harness가 overlay DOM을 포함하는지 확인하기 위해 `samples/복학원서.hwp`를 positive overlay fixture로 추가했다.
- Quick Look PNG/PDF smoke에서 CoreGraphics-only와 Skia opt-in policy를 비교했다.
- HostApp/QLExtension/ThumbnailExtension Debug build와 extension registration hygiene를 확인했다.

## Visual Diff 결과

공통 조건:

- Page: 1
- NativePolicy: `coreGraphicsOnly`
- Studio release: `v0.7.13`
- Studio resolved commit: `b3e16ef212af81ef37d973ddb86d6816d3804642`
- Viewport: `1400x1800`
- Settle: `120ms`
- Diff pixel threshold: `12`

### Basic sample set

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage4-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
```

| File | Status | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | StudioCapture | NativeBackend | NativeMs |
|---|---|---:|---:|---:|---:|---|---|---:|
| `request.hwp` | OK | 323962/1798071 | 18.0172% | 11.1875 | 255 | domComposite | coreGraphics | 1054.2 |
| `hwpx-01.hwpx` | OK | 535436/3562815 | 15.0285% | 15.2088 | 255 | domComposite | coreGraphics | 35.4 |

관찰:

- Stage 1 baseline은 `v0.7.12` / 기존 harness 기준이라 Stage 4 수치와 완전히 같은 조건은 아니다.
- 같은 sample set 기준으로 `request.hwp`는 18.1021%에서 18.0172%, `hwpx-01.hwpx`는 15.1839%에서 15.0285%로 소폭 낮아졌다.
- `request.hwp`에서 기존 Table layout overflow 4.0px 경고가 관찰됐다.

### Image sample set

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage4-images --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
```

| File | Status | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | StudioCapture | NativeBackend | NativeMs |
|---|---|---:|---:|---:|---:|---|---|---:|
| `tac-img-02.hwp` | OK | 147270/3562815 | 4.1335% | 3.7157 | 255 | canvasDataURL | coreGraphics | 941.4 |
| `tac-img-02.hwpx` | OK | 150272/3562815 | 4.2178% | 3.6095 | 255 | domComposite | coreGraphics | 8.0 |
| `hwp-img-001.hwp` | OK | 281516/3562815 | 7.9015% | 8.3980 | 255 | domComposite | coreGraphics | 17.9 |
| `img-start-001.hwp` | OK | 641445/3561228 | 18.0119% | 22.1834 | 255 | domComposite | coreGraphics | 36.9 |

관찰:

- Stage 3의 image set 수치와 같은 값을 유지했다.
- `tac-img-02.hwp`만 canvas-only capture를 유지했고, 나머지는 #293 이후 DOM composite capture로 기록됐다.
- `tac-img-02.hwpx`에서 기존 FullParagraph layout overflow 2.4px 경고가 관찰됐다.

### Positive overlay fixture

명령:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task282-stage4-overlay-positive --page 1 \
  samples/복학원서.hwp
```

| File | Status | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | StudioCapture | NativeBackend | NativeMs |
|---|---|---:|---:|---:|---:|---|---|---:|
| `복학원서.hwp` | OK | 1140407/3562815 | 32.0086% | 37.8181 | 255 | domComposite | coreGraphics | 1105.5 |

관찰:

- #293 이후 studio reference metadata는 `captureMode=domComposite`, `overlayCount=5`, `usedOverlayUnion=true`, `overlayIncluded=true`로 기록됐다.
- studio reference PNG에는 좌상단 로고와 중앙 BehindText 워터마크가 포함된다.
- native PNG도 두 이미지를 그리지만, 중앙 워터마크가 rhwp-studio보다 훨씬 진하고 gray rectangle이 남는다.
- 현재 v0.7.13 overlay payload는 중앙 워터마크를 `mime=image/jpeg`, `effect=grayScale`, `brightness=-50`, `contrast=70`, `watermarkPreset=custom`, `bakedWatermark=false`로 제공한다.
- 이 차이는 #282 compositor 순서보다는 #116 watermark/effect parity와 upstream #1016 resolved baked watermark payload 범위에 가깝다.

## Overlay Metadata Smoke

명령:

```bash
./scripts/overlay-metadata-smoke.sh build.noindex/task282-stage4-overlay-metadata --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp \
  samples/복학원서.hwp
```

| File | Status | UpstreamImages | Overlay | Behind | Front | Renderable | BinLinked | TreeImages | TreeEmbeddedAvailable | Wraps |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| `request.hwp` | OK | 1 | 0 | 0 | 0 | 0 | 0 | 1 | 1/1 | TopAndBottom:1 |
| `hwpx-01.hwpx` | OK | 2 | 0 | 0 | 0 | 0 | 0 | 2 | 2/2 | TopAndBottom:2 |
| `tac-img-02.hwp` | OK | 1 | 0 | 0 | 0 | 0 | 0 | 1 | 1/1 | TopAndBottom:1 |
| `tac-img-02.hwpx` | OK | 1 | 0 | 0 | 0 | 0 | 0 | 1 | 1/1 | TopAndBottom:1 |
| `hwp-img-001.hwp` | OK | 4 | 0 | 0 | 0 | 0 | 0 | 4 | 4/4 | Square:1, TopAndBottom:3 |
| `img-start-001.hwp` | OK | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0/0 | - |
| `복학원서.hwp` | OK | 2 | 2 | 2 | 0 | 2 | 2 | 2 | 2/2 | BehindText:2 |

결론:

- 기존 6개 sample은 여전히 BehindText/InFrontOfText positive fixture가 아니다.
- `복학원서.hwp`는 #282의 positive BehindText fixture로 사용할 수 있다.
- `front=0`이므로 InFrontOfText 양성 fixture는 아직 없다.

## Quick Look Skia Policy Smoke

명령:

```bash
./scripts/smoke-quicklook-skia-policy.sh build.noindex/task282-stage4-skia-policy \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
```

| File | Reply | Pages | CGBackend | CGFallback | CGSeconds | SkiaBackend | SkiaFallback | SkiaSeconds |
|---|---|---:|---|---:|---:|---|---:|---:|
| `request.hwp` | png | 1 | skia:0,cg:1,embedded:0 | 0 | 0.981999 | skia:1,cg:0,embedded:0 | 0 | 3.577944 |
| `hwpx-01.hwpx` | pdf | 9 | skia:0,cg:9,embedded:0 | 0 | 0.367728 | skia:9,cg:0,embedded:0 | 0 | 0.641190 |

해석:

- CoreGraphics-only policy는 Quick Look PNG/PDF 경로에서 CG renderer를 사용한다.
- Skia opt-in policy는 두 sample 모두 Skia backend를 사용했고 fallback은 0건이다.
- 따라서 #282 CoreGraphics compositor 변경은 Thumbnail 기본 경로와 Quick Look CoreGraphics fallback/coreGraphicsOnly 측정에 직접 적용된다. Skia 성공 경로는 #282 compositor를 우회한다.

## 빌드와 위생 검증

명령:

```bash
xcodebuild -project Alhangeul.xcodeproj -scheme HostApp -configuration Debug \
  -derivedDataPath build.noindex/DerivedData-task282-stage4 CODE_SIGNING_ALLOWED=NO build
git diff --check
./scripts/check-extension-registration-hygiene.sh --check-only
```

결과:

- `xcodebuild`: `** BUILD SUCCEEDED ** [11.918 sec]`
- `git diff --check`: 통과
- registration hygiene: Issues 없음
  - 개발 app bundle은 `build.noindex/DerivedData-task282-stage3`와 `build.noindex/DerivedData-task282-stage4` 아래에 남아 있지만 등록되지는 않았다.
  - Quick Look/Thumbnail provider path 미보고 warning은 기존 check output과 같은 형태다.

## 결론

- #293 반영 후 harness는 overlay DOM이 있는 rhwp-studio reference를 `domComposite`로 캡처하고, `복학원서.hwp`의 overlay를 포함한다.
- #282 Stage 3에서 연결한 metadata overlay image drawing path는 `복학원서.hwp`의 `BehindText` 두 이미지를 실제로 그리는 경로를 탄다.
- Stage 4 smoke에서 CoreGraphics compositor, Quick Look policy, HostApp/QLExtension/ThumbnailExtension build는 모두 통과했다.
- 남은 큰 visual gap은 compositor 순서가 아니라 watermark/effect payload 처리다. 현재 core payload가 `bakedWatermark=false`이므로 #116에서 Swift fallback bake 또는 #1016 release 반영 후 resolved payload 소비 정책을 결정해야 한다.

## Handoff

- #116: `복학원서.hwp` 중앙 JPEG 워터마크의 tone/gray rectangle 차이를 처리해야 한다. 현재 native는 원본 JPEG에 기존 effect/brightness/contrast를 적용해 rhwp-studio보다 훨씬 진하게 보인다.
- #1016 upstream: 향후 `bakedWatermark=true` / resolved PNG payload가 release로 내려오면 Swift renderer는 해당 payload에 effect/brightness/contrast를 중복 적용하지 않아야 한다.
- #122: fill/tile/placement는 Stage 4 image set 수치에서 계속 잔여 diff로 남는다.
- #282 Stage 5: positive fixture 부재 한계는 해소됐다. 최종 보고서에는 `복학원서.hwp`를 BehindText positive fixture로 명시하고, InFrontOfText fixture는 여전히 부재하다고 정리한다.
