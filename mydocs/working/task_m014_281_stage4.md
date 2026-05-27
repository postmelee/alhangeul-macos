# Task M014 #281 Stage 4 보고서 - overlay metadata handoff 정리

## 단계 개요

- 이슈: #281 PageLayerTree overlay image metadata를 Swift preview 입력으로 연결
- 단계: Stage 4. visual diff baseline과 #282 handoff
- 목표: #281이 renderer output을 직접 개선하지 않는 한계를 명확히 하고, #282가 사용할 입력 contract와 baseline 수치를 정리한다.

이번 단계에서는 production renderer/compositor 동작을 변경하지 않았다. Stage 2-3에서 만든 overlay metadata provider를 #282의 입력 contract로 고정하고, #286 harness로 #282 이전 visual baseline을 기록했다.

## visual diff baseline

공통 조건:

- Page: 1
- Native policy: `coreGraphicsOnly`
- Studio release: `v0.7.12`
- Studio resolved commit: `1899ef9bc2dfd1c6c0c4d18b192d253a2d0a1fb5`
- Viewport: `1400x1800`
- Settle: `120ms`
- Diff pixel threshold: `12`

기본 sample:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task281-stage4-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
```

image-heavy sample:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task281-stage4-images --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
```

결과:

| sample | Status | StudioSize | NativeSize | ChangedPixels | ChangedPercent | MeanRGBDelta | MaxRGBDelta | StudioCapture | NativeBackend | NativeMs |
|--------|--------|------------|------------|---------------|----------------|--------------|-------------|---------------|---------------|----------|
| `request.hwp` | OK | `1133x1587` | `567x794` | `325488/1798071` | `18.1021%` | `11.5796` | `255` | `canvasDataURL` | `coreGraphics` | `1004.2` |
| `hwpx-01.hwpx` | OK | `1587x2245` | `794x1123` | `540973/3562815` | `15.1839%` | `15.6722` | `255` | `canvasDataURL` | `coreGraphics` | `40.0` |
| `tac-img-02.hwp` | OK | `1587x2245` | `794x1123` | `147412/3562815` | `4.1375%` | `3.7228` | `255` | `canvasDataURL` | `coreGraphics` | `1029.2` |
| `tac-img-02.hwpx` | OK | `1587x2245` | `794x1123` | `129783/3562815` | `3.6427%` | `3.3924` | `255` | `canvasDataURL` | `coreGraphics` | `7.8` |
| `hwp-img-001.hwp` | OK | `1587x2245` | `794x1123` | `279494/3562815` | `7.8448%` | `8.2731` | `255` | `canvasDataURL` | `coreGraphics` | `19.3` |
| `img-start-001.hwp` | OK | `1587x2244` | `794x1123` | `514115/3561228` | `14.4365%` | `15.4773` | `255` | `canvasDataURL` | `coreGraphics` | `34.6` |

산출물:

- `build.noindex/task281-stage4-basic/summary.md`
- `build.noindex/task281-stage4-images/summary.md`
- 각 directory의 `studio/`, `native/`, `diff/` PNG/JSON

## Studio capture metadata와 Swift metadata 비교

`studio/*.json`의 `overlayCount`는 Studio snapshot rect 계산에서 사용한 DOM overlay 후보 수다. Stage 3의 Swift `overlayImageCount`는 upstream `get_page_overlay_images_native`의 `behind`/`front` image 수다. 두 값은 같은 개념이 아니다.

| sample | Studio overlayCount | Studio usedOverlayUnion | Swift upstream imageCount | Swift overlayImageCount | TreeImages | EmbeddedAvailable | Wraps |
|--------|---------------------|-------------------------|---------------------------|-------------------------|------------|-------------------|-------|
| `request.hwp` | 1 | true | 1 | 0 | 1 | 1/1 | `TopAndBottom:1` |
| `hwpx-01.hwpx` | 1 | true | 2 | 0 | 2 | 2/2 | `TopAndBottom:2` |
| `tac-img-02.hwp` | 0 | false | 1 | 0 | 1 | 1/1 | `TopAndBottom:1` |
| `tac-img-02.hwpx` | 1 | true | 1 | 0 | 1 | 1/1 | `TopAndBottom:1` |
| `hwp-img-001.hwp` | 1 | true | 4 | 0 | 4 | 4/4 | `Square:1, TopAndBottom:3` |
| `img-start-001.hwp` | 1 | true | 0 | 0 | 0 | 0/0 | `-` |

해석:

- #281 provider는 page별 overlay JSON 호출과 render tree supplemental scan을 정상 수행한다.
- 현재 sample set은 `BehindText`/`InFrontOfText` positive fixture가 아니므로 Swift overlay image array는 비어 있다.
- `imageCount`가 0보다 커도 wrap이 `TopAndBottom` 또는 `Square`이면 #282 overlay compositor 대상이 아니다.
- Studio capture의 DOM overlayCount는 canvas/snapshot union 보정용 metadata라 renderer overlay image count로 해석하면 안 된다.

## #282 compositor 입력 contract

#282는 다음 네 계층을 명시적으로 다루는 compositor로 진행한다.

| 계층 | 입력 | #281 제공 여부 | #282 처리 |
|------|------|---------------|-----------|
| Background | render tree page background, existing `CGTreeRenderer` background path | 기존 renderer 제공 | 현행 동작 유지 또는 background pass 명시화 |
| BehindText overlay | `RhwpPageOverlayImageSet.behind` | 제공 | flow content 전에 image source를 합성 |
| Flow | 기존 render tree traversal | 기존 renderer 제공 | 현재 CoreGraphics render path 유지 |
| InFrontOfText overlay | `RhwpPageOverlayImageSet.front` | 제공 | flow content 후 image source를 합성 |

`RhwpPageOverlayImage`에서 #282가 우선 사용할 field:

| field | 목적 |
|-------|------|
| `layer`, `wrap` | behind/front 분리와 원본 wrap 의미 보존 |
| `bbox` | page coordinate 기준 draw rect |
| `source.data` | compact overlay JSON에서 온 resolved/converted image bytes |
| `source.binDataId`, `source.binDataAvailable` | render tree supplemental resource identity와 fallback bytes lookup |
| `effect`, `brightness`, `contrast` | image effect/filter 적용 판단 |
| `watermarkPreset`, `bakedWatermark` | watermark 이중 처리 방지, `v0.7.13` forward compatibility |
| `transform` | rotation/flip 적용 |
| `fillMode`, `originalSize`, `originalSizeHU`, `crop` | compact JSON에 없는 fill/crop/original size 보충 |

권장 합성 순서:

1. page background를 그린다.
2. `overlays.behind`를 bbox/transform/crop/fill 기준으로 그린다.
3. flow render tree를 그린다.
4. `overlays.front`를 그린다.
5. `bakedWatermark == true`인 image에는 별도 watermark/filter를 중복 적용하지 않는다.

## 제외 범위와 follow-up

이번 #281에서 제외한 항목:

| 항목 | 이유 | 후속 |
|------|------|------|
| 실제 CGContext 합성 변경 | #281은 input contract 작업 | #282 |
| `v0.7.13` core pin update | dependency update와 metadata contract 구현을 분리 | 별도 core update 또는 #282 초입 재판단 |
| `bakedWatermark` actual payload 검증 | 현재 lock `v0.7.12`에서는 field가 나오지 않음 | `v0.7.13` update 후 smoke 재측정 |
| external linked image discovery/injection | 앱 open contract/base directory 문제와 얽힘 | 별도 upstream/downstream task |
| filename/base directory 전달 개선 | #281 overlay metadata 범위 밖 | 별도 open contract task |
| positive overlay fixture 확보 | 현재 sample set에서 없음 | #282 전 fixture 추가 또는 upstream sample 확보 |

## 결론

#281은 #282가 사용할 metadata 입력을 준비했다. 하지만 renderer가 이 metadata를 아직 사용하지 않으므로 Stage 4 visual diff 수치는 개선 결과가 아니라 #282 이전 baseline이다.

현재 baseline의 `ChangedPercent` 범위는 `3.6427%`부터 `18.1021%`까지다. 이 차이에는 overlay compositor 미구현뿐 아니라 text/layout/image effect 차이도 포함될 수 있으므로, #282는 overlay-positive fixture를 확보한 뒤 before/after diff를 따로 측정해야 한다.

## Stage 4 검증

실행:

```bash
./scripts/preview-visual-diff-harness.sh build.noindex/task281-stage4-basic --page 1 \
  samples/basic/request.hwp samples/hwpx/hwpx-01.hwpx
./scripts/preview-visual-diff-harness.sh build.noindex/task281-stage4-images --page 1 \
  samples/tac-img-02.hwp samples/tac-img-02.hwpx \
  samples/hwp-img-001.hwp samples/img-start-001.hwp
sed -n '1,180p' build.noindex/task281-stage4-basic/summary.md
sed -n '1,220p' build.noindex/task281-stage4-images/summary.md
jq -r '[.fileName, .upstreamImageCount, .overlayImageCount, .behindCount, .frontCount, .treeImageCount] | @tsv' \
  build.noindex/task281-stage3-metadata/metadata.jsonl
git diff --check
```

결과:

- visual diff harness는 6개 sample 모두 OK.
- Stage 3 metadata artifact와 Stage 4 Studio capture artifact를 연결해 overlay count 개념 차이를 확인했다.
- `git diff --check` 통과.
