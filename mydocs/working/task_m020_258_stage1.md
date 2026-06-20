# Task #258 Stage 1 완료 보고서

## 단계 목적

Finder Thumbnail cache/provider와 Shared renderer contract를 조사해 Stage 2의 render signature source 반영 범위와 Stage 3의 thumbnail smoke helper 입력/출력 형식을 고정한다. 이번 단계는 inventory 단계이므로 Swift source는 변경하지 않는다.

## 산출물

| 파일 | 내용 |
|---|---|
| `mydocs/working/task_m020_258_stage1.md` | Stage 1 조사 결과와 다음 단계 입력 정리 |
| `mydocs/orders/20260603.md` | #258 상태를 Stage 1 완료 보고서 승인 대기로 갱신 |

Swift source 변경은 없다.

## 조사 결과

### Thumbnail cache key와 재사용 조건

현재 `HwpThumbnailRenderRequest`는 `maximumSize`와 `scale`을 pixel bucket으로 변환하고, `HwpThumbnailCacheKey`에 path, modification time, file size, pixel width, pixel height만 넣는다. `HwpThumbnailCacheKey`에는 backend policy, renderer option version, core provenance, `native-skia` feature 여부가 없다.

현재 cache exact hit, in-flight key, store key는 모두 같은 `HwpThumbnailCacheKey`를 사용한다. 큰 bucket 재사용도 path, modification time, file size가 같고 candidate pixel width/height가 요청 bucket 이상이면 허용한다. 따라서 backend 또는 render option이 바뀌어도 file metadata와 bucket이 같으면 stale thumbnail을 재사용할 수 있다.

Stage 2에서는 다음 구조를 추가하는 방향이 맞다.

- `HwpThumbnailRenderSignature: Hashable`
- `HwpThumbnailRenderRequest.policy: HwpPageRenderPolicy`
- `HwpThumbnailRenderRequest.renderSignature`
- `HwpThumbnailCacheKey.renderSignature`

큰 bucket 재사용 guard에는 `candidateKey.renderSignature == requestedKey.renderSignature`를 추가한다.

### Thumbnail provider 기본 정책과 fallback 순서

현재 `HwpThumbnailProvider`는 `HwpThumbnailRenderRequest(fileURL:maximumSize:scale:)`만 만들고 backend policy를 명시하지 않는다. `HwpThumbnailRenderCache`도 `HwpPageImageRenderer.renderFirstPage(..., embeddedThumbnailPolicy: .never)`를 호출하면서 policy를 넘기지 않는다. `HwpPageImageRenderer.renderFirstPage`의 기본값이 `.coreGraphicsOnly`이므로 Finder Thumbnail 제품 기본 경로는 CoreGraphics다.

Fallback 순서는 다음과 같다.

1. render cache가 `HwpPageImageRenderer.renderFirstPage`를 호출한다.
2. 렌더 성공 시 page image로 `QLThumbnailReply`를 만든다.
3. 렌더 실패 중 `HwpDocumentFallbackClassifier.shouldUseThumbnailFallback` 대상이면 provider fallback tile을 반환한다.
4. fallback 대상이 아니면 error를 그대로 반환한다.

Skia opt-in을 Stage 3 helper에서 추가할 때도 제품 provider 기본은 그대로 `.coreGraphicsOnly`로 유지해야 한다. Skia opt-in 실패는 Shared renderer가 CoreGraphics fallback을 먼저 반환하고, Shared renderer 자체가 error를 던지는 경우에만 provider fallback tile로 가는 구조가 맞다.

### Shared renderer contract

Shared renderer는 `HwpPageRenderPolicy.coreGraphicsOnly`와 `HwpPageRenderPolicy.skiaOptIn`을 제공한다. Diagnostics에는 policy, backendUsed, fallbackReason, pageSize, pixelSize, pngBytes, durationMs가 있다.

`.skiaOptIn`은 `renderSkiaPage`를 먼저 호출한다. Skia PNG가 성공하면 backendUsed는 `.skia`이고 pngBytes와 Skia/decode latency가 diagnostics에 남는다. Skia 실패나 PNG decode 실패 시 `renderCoreGraphicsPage`로 fallback하며, 이 경우 backendUsed는 `.coreGraphics`, policy는 `.skiaOptIn`, fallbackReason과 Skia 시도 latency가 함께 남는다.

현재 Skia ABI 호출은 `maxDimension: 0`을 넘긴다. Thumbnail에서 optional `maxDimension` 정책을 도입하려면 Stage 2 또는 Stage 3에서 별도 policy version을 signature에 넣어야 한다.

### Core provenance 입력

`rhwp-core.lock`에서 render signature에 사용할 수 있는 안정 입력은 다음과 같다.

| 필드 | 현재 값 |
|---|---|
| `rhwp_ref_kind` | `release-tag` |
| `rhwp_release_tag` | `v0.7.13` |
| `rhwp_commit` | `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| `rhwp_enabled_features` | `native-skia` |

Stage 2 source에는 lock 파일을 runtime에서 직접 읽는 방식보다, 우선 compile-time constant 성격의 signature string을 Thumbnail source에 둔다. 값은 `rhwp-core.lock`과 일치하도록 보고서와 grep 검증으로 묶는다. 이후 build setting 또는 generated provenance constant가 필요하면 별도 후속으로 분리한다.

### Thumbnail smoke helper 입력/출력 형식

기존 Quick Look helper는 `CoreGraphics`와 `skiaOptIn`을 같은 입력 문서에서 측정하고 summary/detail 파일을 쓴다. 출력에는 backend page count, fallback count, PNG byte, elapsed seconds, renderMs가 포함된다.

Thumbnail helper는 Quick Look helper를 그대로 쓰기보다 다음 값을 추가해야 한다.

입력:

- output directory
- 요청 size/scale preset 또는 명시 값
- HWP/HWPX 파일 목록
- policy set: `.coreGraphicsOnly`, `.skiaOptIn`

출력:

- file name
- request size
- scale
- pixel bucket
- render signature
- policy
- backendUsed
- fallbackReason
- pageSize
- pixelSize
- pngBytes
- durationMs.totalMs
- output PNG bytes
- cache event: miss, exact hit, larger bucket hit
- matched bucket

cache hit/miss를 helper에서 관측하려면 Stage 2에서 `HwpThumbnailRenderCache`가 cache event를 completion 결과 또는 test-facing diagnostic으로 돌려줄 수 있어야 한다. 단, provider의 public behavior는 바꾸지 않는다.

### Gate 분리 초안

Quick Look 단일 PNG, Quick Look 다중 PDF, Finder Thumbnail은 같은 Shared renderer contract를 쓰지만 gate는 분리한다.

| Surface | 독립 gate가 필요한 이유 |
|---|---|
| Quick Look 단일 PNG | 단일 page image encode/decode latency와 visual output이 핵심이다. direct PNG reply 최적화 가능성이 따로 있다. |
| Quick Look 다중 PDF | page별 bitmap을 PDF container에 넣으므로 page count, PDF byte size, multi-page latency가 별도 위험이다. |
| Finder Thumbnail | request size/scale bucket, cache reuse, Finder cache interaction, small image latency가 핵심이다. |

PageLayerTree `displayText` 장기 전환은 #305 잔여 위험과 연결된다. #258에서는 Swift/CoreGraphics PUA 보정 추가가 아니라, Thumbnail/Quick Look surface가 backend/render signature와 gate를 분리해 PageLayerTree/Skia 소비 경로를 안전하게 실험할 수 있는 기반을 만든다.

## 본문 변경 정도 / 본문 무손실 여부

Swift source와 기존 기술 문서 본문은 변경하지 않았다. 오늘할일은 상태 문구만 갱신했다. 신규 Stage 1 보고서는 기존 문서 내용을 대체하지 않고 조사 결과를 별도 기록한다.

## 검증 결과

| 검증 | 결과 |
|---|---|
| `rg -n "HwpThumbnailRenderCache\|HwpThumbnailProvider\|HwpThumbnailCacheKey\|maximumPixelSize\|pixelBucket\|cachedPage\|fallbackReply" Sources/ThumbnailExtension` | 통과 |
| `rg -n "coreGraphicsOnly\|skiaOptIn\|backendUsed\|fallbackReason\|pngBytes\|durationMs\|renderFirstPage\|renderPage" Sources/Shared Sources/QLExtension scripts --glob '!**/Resources/**'` | 통과 |
| `rg -n "rhwp_commit\|rhwp_enabled_features\|native-skia" rhwp-core.lock scripts Sources` | 통과 |
| `rg -n "#258\|Stage 1\|Thumbnail\|cache\|signature\|Skia\|CoreGraphics" mydocs/plans/task_m020_258_impl.md mydocs/working/task_m020_258_stage1.md` | 통과 |
| `git diff --check` | 통과 |

## 잔여 위험

| 항목 | 내용 |
|---|---|
| runtime provenance | Stage 2에서 compile-time signature string을 먼저 쓰면 `rhwp-core.lock`과 source constant가 어긋날 수 있다. 보고서/grep 검증으로 묶되, generated provenance constant는 후속 후보로 둔다. |
| cache diagnostics API | cache hit/miss를 helper에서 관측하려면 provider behavior를 바꾸지 않는 내부 결과 타입이 필요하다. |
| `maxDimension` 정책 | 현재 Skia path는 `maxDimension: 0`이다. Thumbnail용 maxDimension을 실제로 넘길지 여부는 cache signature와 함께 고정해야 한다. |
| Finder integration smoke | Stage 3 helper smoke는 Debug/helper 기준이다. Finder 등록/시스템 cache smoke는 이번 task 범위에서 전체 재정리하지 않는다. |

## 다음 단계 영향

Stage 2는 `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift`를 중심으로 진행한다. 예상 source 변경은 다음과 같다.

- `HwpThumbnailRenderSignature` 추가
- `HwpThumbnailRenderRequest`에 `policy`, `renderSignature` 추가
- `HwpThumbnailCacheKey`에 `renderSignature` 추가
- `cachedPage(for:)` reuse guard에 signature equality 추가
- render 호출에 request policy 전달
- 필요 시 cache event diagnostics 타입 추가

Stage 3는 Stage 2에서 생긴 cache event diagnostics를 사용해 thumbnail smoke helper를 만든다.

## 승인 요청

Stage 1 조사와 완료 보고를 승인하면 Stage 2 `Render signature와 cache reuse source 반영`으로 진행한다.
