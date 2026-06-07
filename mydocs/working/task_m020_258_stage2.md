# Task #258 Stage 2 완료 보고서

## 단계 목적

Thumbnail cache key와 in-flight/reuse 조건에 render signature를 추가해 backend 또는 render option 변경 후 stale thumbnail을 재사용하지 않게 한다. Finder Thumbnail provider의 제품 기본 정책은 CoreGraphics로 유지한다.

## 산출물

| 파일 | 내용 |
|---|---|
| `Sources/ThumbnailExtension/HwpThumbnailRenderCache.swift` | render signature, cache event/result 타입, signature-aware cache reuse 적용 |
| `mydocs/working/task_m020_258_stage2.md` | Stage 2 변경과 검증 결과 기록 |
| `mydocs/orders/20260603.md` | #258 상태를 Stage 2 완료 보고서 승인 대기로 갱신 |

## Source 변경

### Render signature

`HwpThumbnailRenderSignature`를 추가했다. signature에는 다음 항목이 들어간다.

| 항목 | 값 |
|---|---|
| backend policy | `coreGraphicsOnly` 또는 `skiaOptIn` |
| renderer option version | `thumbnail-renderer-v1` |
| core release tag | `v0.7.13` |
| core commit | `b3e16ef212af81ef37d973ddb86d6816d3804642` |
| core enabled features | `native-skia` |
| max-dimension policy version | `skia-max-dimension-0` |

`HwpThumbnailRenderRequest`는 기본 policy를 `.coreGraphicsOnly`로 유지한다. 별도 signature가 주어지지 않으면 policy에서 기본 signature를 만든다.

### Cache key와 in-flight key

`HwpThumbnailCacheKey`에 `renderSignature`를 추가했다. 이 key는 다음 위치에 그대로 사용된다.

- memory cache dictionary key
- access order key
- in-flight render coalescing key
- render 성공 후 store key

따라서 backend policy나 render option signature가 다르면 exact hit와 in-flight join 모두 분리된다.

### 큰 bucket 재사용 조건

`cachedPage(for:)`의 larger bucket reuse guard에 `candidateKey.renderSignature == requestedKey.renderSignature` 조건을 추가했다. 기존 file metadata invalidation과 candidate pixel bucket 조건은 유지했다.

즉 같은 signature 안에서는 큰 bucket 결과를 작은 요청에 재사용할 수 있지만, signature가 다르면 같은 파일과 같은 pixel bucket이어도 재사용하지 않는다.

### Cache event diagnostics

Stage 3 helper가 cache hit/miss를 관측할 수 있도록 내부 결과 타입을 추가했다.

- `HwpThumbnailCacheEvent.miss`
- `HwpThumbnailCacheEvent.exactHit`
- `HwpThumbnailCacheEvent.largerBucketHit(pixelWidth:pixelHeight:)`
- `HwpThumbnailRenderResult`

기존 provider가 쓰는 `renderedPage(for:completion:)`는 유지하고, 새 `renderedPageResult(for:completion:)`가 cache event를 포함한 결과를 돌려준다. Provider의 public behavior는 바꾸지 않았다.

### Render policy 전달

`HwpThumbnailRenderCache`가 `HwpPageImageRenderer.renderFirstPage`를 호출할 때 `request.policy`를 넘기도록 했다. Provider가 만드는 request는 기본 `.coreGraphicsOnly`이므로 Finder Thumbnail 기본 renderer는 그대로 CoreGraphics다. Stage 3 helper는 같은 request 타입에서 `.skiaOptIn`을 명시할 수 있다.

## 본문 변경 정도 / 본문 무손실 여부

기존 cache key 구성과 larger bucket 재사용 구조는 유지하고, signature equality 조건만 추가했다. `HwpThumbnailProvider` source는 변경하지 않아 Finder Thumbnail reply 생성, fallback tile, error 처리 본문은 무손실이다.

## 검증 결과

| 검증 | 결과 |
|---|---|
| `./scripts/check-no-appkit.sh` | 통과: `OK: shared Swift code has no AppKit/UIKit dependencies` |
| `rg -n "HwpThumbnailRenderSignature\|HwpThumbnailCacheKey\|renderSignature\|coreGraphicsOnly\|skiaOptIn\|cachedPage\|matchedKey\|maximumPixelSize" Sources/ThumbnailExtension Sources/Shared` | 통과 |
| `xcodebuild -project Alhangeul.xcodeproj -scheme ThumbnailExtension -configuration Debug -derivedDataPath build.noindex/DerivedDataTask258 CODE_SIGNING_ALLOWED=NO build` | 통과: sandbox 밖 재실행에서 `** BUILD SUCCEEDED **` |
| `git diff --check` | 통과 |

Sandbox 제약:

- 최초 `xcodebuild`는 sandbox 내부에서 Sparkle package fetch가 `Could not resolve host: github.com`로 실패했다.
- 동일 명령을 네트워크 허용 상태로 재실행했고, Sparkle 2.9.1 resolved 후 build가 통과했다.

## 잔여 위험

| 항목 | 내용 |
|---|---|
| provenance constant drift | `rhwp-core.lock` 값을 source constant로 반영했다. core lock 변경 시 signature constant도 함께 갱신해야 한다. |
| maxDimension 정책 | 현재 signature는 `skia-max-dimension-0`을 고정한다. 실제 maxDimension 전달 정책을 바꾸면 signature version도 바꿔야 한다. |
| cache event granularity | in-flight join은 별도 event로 분리하지 않았다. Stage 3 helper가 필요로 하면 `inFlightJoin`을 추가할 수 있다. |
| system Finder cache | 이번 변경은 extension 내부 memory cache 기준이다. Finder/Quick Look 시스템 cache invalidation은 별도 smoke 범위다. |

## 다음 단계 영향

Stage 3는 새 `renderedPageResult(for:)`와 `HwpThumbnailCacheEvent`를 사용해 thumbnail smoke helper를 만들 수 있다. Helper는 같은 파일과 request bucket을 반복 호출해 `miss`, `exactHit`, `largerBucketHit`를 기록하고, policy를 `.coreGraphicsOnly`와 `.skiaOptIn`으로 나눠 backend/fallback/latency를 비교한다.

## 승인 요청

Stage 2 source 반영과 완료 보고를 승인하면 Stage 3 `Thumbnail Skia opt-in diagnostic smoke helper`로 진행한다.
