# Task M020 #392 Stage 2 보고서

## 단계 목적

Stage 1에서 고정한 scale-only baseline을 바탕으로, Stage 3에서 적용할 Thumbnail Skia `maximumPixelSize -> maxDimension` mapping contract와 cache signature 정책을 확정했다.

이번 단계는 source 변경 없이 설계만 확정했다.

## 산출물

| 파일/산출물 | 줄 수 | 내용 |
|------|------:|------|
| `RustBridge/src/lib.rs` | 307 | FFI `rhwp_render_page_png`의 `scale`, `max_dimension` guard와 option 변환 확인 |
| `/Users/melee/Documents/projects/forks/rhwp/src/document_core/queries/rendering.rs` | 4710 | upstream `PngExportOptions`와 scale 결정 우선순위 확인 |
| `/Users/melee/Documents/projects/forks/rhwp/src/renderer/skia/renderer.rs` | 3082 | raster scale/max_dimension validation 확인 |
| `Sources/Shared/HwpPageImageRenderer.swift` | 532 | Stage 3 변경 지점 확인 |
| `Sources/RhwpCoreBridge/RhwpDocument.swift` | 260 | Swift wrapper guard 확인 |
| `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | 280 | render signature version 변경 지점 확인 |
| `scripts/thumbnail_skia_policy_smoke.swift` | 639 | 기존 smoke output이 Stage 3 검증에 충분한지 확인 |
| `mydocs/working/task_m020_392_stage1.md` | 158 | scale-only baseline 입력 |

## 본문 변경 정도 / 본문 무손실 여부

소스 파일은 변경하지 않았다. 새로 추가한 문서는 이 Stage 2 보고서뿐이다.

## 확인한 upstream/bridge contract

### FFI 입력 contract

`RustBridge/src/lib.rs`의 `rhwp_render_page_png`는 다음 조건을 invalid option으로 처리한다.

- `scale`이 finite가 아니거나 음수
- `max_dimension > i32::MAX`

이후 `PngExportOptions`로 변환할 때:

```rust
scale: if scale == 0.0 { None } else { Some(scale) },
max_dimension: if max_dimension == 0 {
    None
} else {
    Some(max_dimension as i32)
}
```

즉 Swift에서 `maxDimension`을 meaningful하게 쓰려면 `0 < maxDimension <= Int32.max` 범위로 넘겨야 한다.

### upstream scale 결정 우선순위

upstream `PngExportOptions` 주석과 구현은 다음 우선순위를 가진다.

1. 명시 `scale`
2. `max_dimension` / VLM 기반 자동 계산
3. DPI 기반 scale
4. 기본 `1.0`

중요한 점은 **명시 `scale`이 있으면 `max_dimension` 기반 자동 scale 계산보다 우선**한다는 것이다. 또한 Skia raster renderer는 최종 scaled dimension이 `max_dimension`을 넘으면 render error로 처리한다.

따라서 Stage 3에서 현재 Swift scale을 그대로 넘기면서 `maxDimension`도 함께 넘기면, `1024` bucket에서 기존 `1025` 결과가 invalid/fallback으로 바뀔 가능성이 있다. 이 작업의 목표는 fallback 유도나 hard clamp가 아니라 upstream의 maxDimension 자동 scale 정책을 실험하는 것이므로, `maxDimension`이 유효할 때는 explicit scale을 넘기지 않는 계약으로 확정한다.

## 확정 설계

### Shared renderer contract

Stage 3 변경 방향:

1. `HwpPageImageRenderer.renderPage`는 기존처럼 `maximumPixelSize`로 CoreGraphics용 `scale`과 `pixelSize`를 계산한다.
2. `.coreGraphicsOnly` path는 변경하지 않는다.
3. `.skiaOptIn` path는 `maximumPixelSize`에서 `skiaMaxDimension`을 계산해 `renderSkiaPage`로 전달한다.
4. `renderSkiaPage`는 `skiaMaxDimension > 0`이면 `renderPagePNG(scale: 0, maxDimension: skiaMaxDimension)`을 호출한다.
5. `skiaMaxDimension == 0`이면 기존과 같이 `renderPagePNG(scale: Double(scale), maxDimension: 0)`을 호출한다.

개념 코드:

```swift
let skiaMaxDimension = Self.skiaMaxDimension(from: maximumPixelSize)
let skiaScale = skiaMaxDimension > 0 ? 0 : Double(scale)
let png = document.renderPagePNG(
    at: pageIndex,
    scale: skiaScale,
    maxDimension: skiaMaxDimension
)
```

이렇게 하면 Thumbnail 요청에서는 upstream이 `max_dimension` 기반 자동 scale을 계산하고, Quick Look처럼 `maximumPixelSize == nil`인 경로는 기존 scale-only 동작을 유지한다.

### maxDimension 계산 규칙

Stage 3 helper 후보:

```swift
private static func skiaMaxDimension(from maximumPixelSize: CGSize?) -> Int {
    guard let maximumPixelSize else {
        return 0
    }
    let longestEdge = max(maximumPixelSize.width, maximumPixelSize.height)
    guard longestEdge.isFinite, longestEdge > 0 else {
        return 0
    }
    return min(Int(ceil(longestEdge)), Int(Int32.max))
}
```

적용 이유:

- Thumbnail bucket은 현재 정수 bucket이지만 `CGSize`라서 finite/positive guard를 둔다.
- `ceil`은 `maximumPixelSize`가 소수로 들어와도 requested upper bound를 작게 만들지 않는다.
- RustBridge는 `i32::MAX` 초과를 invalid option으로 처리하므로 Swift에서 `Int32.max`로 clamp한다.
- `0`은 upstream `None` 의미이므로 fallback path가 아니라 기존 scale-only 의미로 둔다.

### Signature 정책

현재 signature suffix는 `skia-max-dimension-0`이다. Stage 3에서 Thumbnail Skia option semantics가 바뀌므로 새 suffix로 변경한다.

확정 값:

```text
skia-max-dimension-thumbnail-v1
```

정책:

- `HwpThumbnailRenderSignature.maxDimensionPolicyVersion`의 static value를 위 값으로 변경한다.
- 이 값은 `coreGraphicsOnly` signature에도 포함되지만, 현재 구조상 signature field는 Thumbnail renderer option version 묶음에 가까우므로 우선 전체 Thumbnail render signature를 갱신한다.
- `backendPolicy`가 signature 첫 항목이므로 CoreGraphics/Skia cache는 계속 분리된다.
- `candidateKey.renderSignature == requestedKey.renderSignature` 조건 때문에 이전 `skia-max-dimension-0`과 새 policy cache는 섞이지 않는다.

향후 per-policy signature가 필요하면 별도 리팩터링으로 분리한다. 이번 작업에서는 source surface를 줄이기 위해 static suffix 변경으로 충분하다.

### Smoke helper 정책

현재 smoke helper는 다음 값을 이미 출력한다.

- `RequestedBucket`
- `MatchedBucket`
- `Signature`
- `Pixel`
- `OutputBytes`
- `PNGBytes`
- `RenderMs`
- `Backend`
- `Fallback`

Stage 3에서는 helper column 추가 없이도 정책 변경 검증이 가능하다. 다만 Stage 3 구현 후 summary 해석이 불편하면 `Signature`에서 suffix를 별도 column으로 분리하는 최소 보강을 검토한다.

## Stage 3 변경 파일 확정

필수 변경:

| 파일 | 변경 |
|------|------|
| `Sources/Shared/HwpPageImageRenderer.swift` | Skia path에 `skiaMaxDimension` 계산과 `scale: 0` 자동 scale 호출 추가 |
| `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | `maxDimensionPolicyVersion`을 `skia-max-dimension-thumbnail-v1`로 갱신 |
| `mydocs/working/task_m020_392_stage3.md` | 구현 결과와 quick smoke 기록 |

조건부 변경:

| 파일 | 조건 |
|------|------|
| `scripts/thumbnail_skia_policy_smoke.swift` | 기존 summary/detail만으로 signature suffix와 pixel drift 해석이 어렵다고 판단될 때만 최소 보강 |
| `scripts/smoke-thumbnail-skia-policy.sh` | compile list 변경이 필요할 때만 수정. 현재는 필요 없음 |

## Stage 3 예상 검증 포인트

Stage 3 quick smoke에서 확인할 값:

| 항목 | 기대 |
|------|------|
| resolver contract | `OK` |
| render rows | `request.hwp`, `KTX.hwp` 총 16 rows `OK` |
| cache pattern | policy별 `miss -> exactHit -> largerBucketHit -> largerBucketHit` 유지 |
| signature suffix | `skia-max-dimension-thumbnail-v1` |
| fallback | 모든 정상 row `-` 기대 |
| `request.hwp` Skia pixel | 현재 `732x1025`에서 긴 축 `<=1024`로 바뀌는지 확인 |
| `KTX.hwp` Skia pixel | 현재 `1025x725`에서 긴 축 `<=1024`로 바뀌는지 확인 |

## 검증 결과

구현계획서 Stage 2 검증:

```bash
rg -n "renderSkiaPage|renderPagePNG|maxDimensionPolicyVersion|HwpThumbnailRenderSignature|maximumPixelSize" \
  Sources/Shared/HwpPageImageRenderer.swift Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift \
  scripts/thumbnail_skia_policy_smoke.swift mydocs/working/task_m020_392_stage2.md
git diff --check
```

결과:

- `rg`: 관련 source/report 위치 확인 성공.
- `git diff --check`: 성공.

## 잔여 위험

| 항목 | 상태 | 다음 처리 |
|------|------|------|
| scale과 maxDimension 동시 전달 | upstream 우선순위상 부적합 | Stage 3에서 `maxDimension > 0`이면 `scale: 0`으로 적용 |
| Swift wrapper guard와 RustBridge guard 차이 | Swift는 `UInt32.max`, RustBridge는 `i32::MAX` | Stage 3 helper에서 `Int32.max` clamp |
| CoreGraphics signature suffix도 바뀜 | 구조상 전체 Thumbnail signature suffix 변경 | source surface를 줄이고 stale cache 방지를 우선 |
| visual 품질 판단 | 이번 Stage 범위 밖 | Stage 4/후속 #396 기준과 연결 |

## 다음 단계 영향

Stage 3는 바로 다음 순서로 구현한다.

1. `skiaMaxDimension(from:)` helper 추가.
2. `renderSkiaPage` 인자에 `maxDimension` 추가.
3. `maxDimension > 0`이면 `renderPagePNG(scale: 0, maxDimension: maxDimension)` 호출.
4. signature suffix를 `skia-max-dimension-thumbnail-v1`로 변경.
5. quick smoke로 pixel drift와 cache/signature를 확인.

## 승인 요청

Stage 2 설계와 signature 정책 확정을 완료했다. Stage 3 `opt-in 실험 구현과 smoke 보강`으로 진행 승인해 달라.
