# Task M020 #392 Stage 1 보고서

## 단계 목적

현행 Thumbnail Skia opt-in path가 `maxDimension: 0` scale-only 정책으로 동작한다는 사실을 코드와 smoke output으로 확인하고, #389에서 넘긴 1px size drift baseline이 현재 브랜치에서도 재현되는지 고정했다.

이번 단계는 source 변경 없이 inventory와 quick smoke 재측정만 수행했다.

## 산출물

| 파일/산출물 | 줄 수 | 내용 |
|------|------:|------|
| `Sources/Shared/HwpPageImageRenderer.swift` | 532 | `maximumPixelSize` 기반 scale 계산과 Skia `maxDimension: 0` 호출 경로 확인 |
| `Sources/RhwpCoreBridge/RhwpDocument.swift` | 260 | `renderPagePNG(at:scale:maxDimension:)` guard와 FFI 전달 계약 확인 |
| `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | 280 | pixel bucket, render signature, cache hit/reuse 조건 확인 |
| `scripts/thumbnail_skia_policy_smoke.swift` | 639 | summary/detail column과 cache signature separation 측정 항목 확인 |
| `scripts/smoke-thumbnail-skia-policy.sh` | 111 | DEBUG smoke compile path 확인 |
| `mydocs/report/task_m020_389_report.md` | 243 | #389 handoff의 1px drift baseline 확인 |
| `mydocs/tech/skia_quicklook_thumbnail_backend.md` | 453 | Thumbnail maxDimension 정책 문서 기준 확인 |
| `mydocs/tech/skia_preview_renderer_baseline.md` | 174 | Thumbnail surface 판단이 #392 입력을 기다리는 상태 확인 |
| `build.noindex/task392-stage1-scale-only/summary.txt` | 44 | Stage 1 quick smoke summary |

## 본문 변경 정도 / 본문 무손실 여부

소스 파일은 변경하지 않았다. 새로 추가한 문서는 이 Stage 1 보고서뿐이다.

## Inventory 결과

### Shared renderer

`HwpPageImageRenderer.renderPage`는 `maximumPixelSize`가 있으면 `renderScale(pageSize:maximumPixelSize:)`로 scale을 계산한다. 그러나 `.skiaOptIn` 분기에서 `renderSkiaPage`를 호출할 때는 scale만 넘기고, `renderSkiaPage` 내부 FFI 호출은 현재 `maxDimension: 0`으로 고정되어 있다.

현재 Skia 호출 형태:

```swift
document.renderPagePNG(
    at: pageIndex,
    scale: Double(scale),
    maxDimension: 0
)
```

따라서 현재 Thumbnail Skia path는 `maximumPixelSize`를 직접 upstream `max_dimension`에 전달하지 않는 scale-only 정책이다.

### RustBridge wrapper

`RhwpDocument.renderPagePNG(at:scale:maxDimension:)`는 `scale.isFinite`, `scale >= 0`, `maxDimension >= 0`, `maxDimension <= UInt32.max`를 확인한 뒤 `rhwp_render_page_png`에 `scale`과 `UInt32(maxDimension)`을 전달한다.

즉 Swift wrapper는 이미 maxDimension 전달 능력을 갖고 있으며, #392의 변경 지점은 Shared renderer에서 이 값을 계산해 넘길지 여부다.

### Thumbnail cache signature

`HwpThumbnailRenderRequest`는 Finder request `maximumSize`와 `scale`로 pixel bucket을 만든다. 기본 request sequence 기준:

| request | bucket |
|------|------|
| `large:512x512@2` | `1024x1024` |
| `large-repeat:512x512@2` | `1024x1024` |
| `medium-after-large:256x256@2` | `512x512` |
| `small-after-large:128x128@1` | `128x128` |

`HwpThumbnailRenderSignature`의 현재 maxDimension policy version은 `skia-max-dimension-0`이다. 이 값은 CoreGraphics와 Skia policy 양쪽 signature에 모두 포함된다.

Stage 2 입력:

- maxDimension mapping을 적용하면 signature version은 기존 `skia-max-dimension-0`과 분리해야 한다.
- 후보 값은 구현계획서의 `skia-max-dimension-thumbnail-v1`을 우선 검토한다.
- cache reuse 조건은 `candidateKey.renderSignature == requestedKey.renderSignature`를 포함하므로 version 변경은 stale cache 혼입을 차단한다.

### Smoke helper

현재 smoke summary/detail은 Stage 2/3 판단에 필요한 주요 값을 이미 출력한다.

| 항목 | 현재 출력 위치 |
|------|------|
| request bucket | `RequestedBucket`, `MatchedBucket` |
| cache event | `Cache` / `CacheEvent` |
| signature | detail `Signature`, summary cache separation |
| backend/fallback | `Backend`, `Fallback` |
| output pixel size | `Pixel` / `PixelSize` |
| bytes/timing | `OutputBytes`, `PNGBytes`, `RenderMs`, `Seconds` |

따라서 Stage 3에서 helper column을 반드시 늘릴 필요는 없다. 다만 signature version을 더 쉽게 읽게 하려면 detail 또는 summary에 policy version만 별도 column으로 뽑는 보강을 검토할 수 있다.

## Baseline smoke 결과

실행:

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-stage1-scale-only \
  samples/basic/request.hwp samples/basic/KTX.hwp
```

결과 요약:

```text
resolver: OK
request.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
KTX.hwp: renders=8 failed=0 cache=miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024),miss,exactHit,largerBucketHit(1024x1024),largerBucketHit(1024x1024)
```

핵심 비교:

| sample | policy | large bucket | pixel | backend | fallback | signature suffix |
|------|------|------|------|------|------|------|
| `request.hwp` | `coreGraphicsOnly` | `1024x1024` | `732x1024` | `coreGraphics` | `-` | `skia-max-dimension-0` |
| `request.hwp` | `skiaOptIn` | `1024x1024` | `732x1025` | `skia` | `-` | `skia-max-dimension-0` |
| `KTX.hwp` | `coreGraphicsOnly` | `1024x1024` | `1024x725` | `coreGraphics` | `-` | `skia-max-dimension-0` |
| `KTX.hwp` | `skiaOptIn` | `1024x1024` | `1025x725` | `skia` | `-` | `skia-max-dimension-0` |

재현된 baseline:

- `request.hwp`: Skia가 긴 축 기준 CoreGraphics보다 `+1px` 크다. `732x1024 -> 732x1025`.
- `KTX.hwp`: Skia가 긴 축 기준 CoreGraphics보다 `+1px` 크다. `1024x725 -> 1025x725`.
- cache pattern은 두 policy 모두 `miss -> exactHit -> largerBucketHit -> largerBucketHit`로 정상이다.
- policy별 cache signature separation은 두 sample 모두 `OK`다.
- fallback은 모든 row에서 `-`다.

## 검증 결과

구현계획서 Stage 1 검증:

```bash
./scripts/smoke-thumbnail-skia-policy.sh build.noindex/task392-stage1-scale-only \
  samples/basic/request.hwp samples/basic/KTX.hwp
```

결과: 성공. resolver contract `OK`, render rows 16개 모두 `OK`, failed `0`.

추가 점검:

```bash
git diff --check
```

결과: 성공.

## 잔여 위험

| 항목 | 상태 | 다음 처리 |
|------|------|------|
| `maxDimension` semantics | 아직 미검증 | Stage 2에서 mapping contract를 정하고 Stage 3에서 적용 |
| signature version | 현재 `skia-max-dimension-0` | Stage 2에서 새 version 값 확정 |
| latency 절대값 | 로컬 실행 변동 가능 | Stage 4에서 대표 샘플 상대 비교 중심으로 해석 |
| visual 품질 | 이번 Stage 범위 밖 | #396 baseline과 Stage 4 결과를 후속 판단에 연결 |

## 다음 단계 영향

Stage 2는 다음 결정을 내려야 한다.

1. `HwpPageImageRenderer.renderSkiaPage`에 `maximumPixelSize` 또는 `maxDimension` 인자를 추가한다.
2. `max(maximumPixelSize.width, maximumPixelSize.height)`를 finite/positive일 때만 `maxDimension`으로 사용한다.
3. Thumbnail signature version을 `skia-max-dimension-0`에서 새 값으로 바꾼다.
4. smoke helper는 우선 기존 column으로 충분하다고 보고, 구현 후 부족할 때만 최소 보강한다.

## 승인 요청

Stage 1 inventory와 scale-only baseline 고정을 완료했다. Stage 2 `maxDimension mapping 설계와 signature 정책 확정`으로 진행 승인해 달라.
